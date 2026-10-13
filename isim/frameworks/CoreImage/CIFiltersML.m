// isim Core Image filters that iOS backs with machine-learning models.
//   CISaliencyMapFilter (adapted): the spectral residual saliency of Hou & Zhang (2007) instead of Apple's model.
//   CIPersonSegmentation, CICoreMLModelFilter (stub): they need Apple's models / Core ML runtime, which isim does not
//   have; their output is nil and the reason is logged once.
#import "CIFilterImpl.h"

typedef struct { float re, im; } cpx;
static void fft(cpx *a, int n, int inverse) {
    for (int i = 1, j = 0; i < n; i++) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) j ^= bit;
        j ^= bit;
        if (i < j) { cpx t = a[i]; a[i] = a[j]; a[j] = t; }
    }
    for (int len = 2; len <= n; len <<= 1) {
        double ang = 2 * M_PI / len * (inverse ? 1 : -1);
        for (int i = 0; i < n; i += len)
            for (int k = 0; k < len / 2; k++) {
                float wr = (float)cos(ang * k), wi = (float)sin(ang * k);
                cpx u = a[i + k], v = a[i + k + len / 2];
                cpx t = { v.re * wr - v.im * wi, v.re * wi + v.im * wr };
                a[i + k] = (cpx){ u.re + t.re, u.im + t.im };
                a[i + k + len / 2] = (cpx){ u.re - t.re, u.im - t.im };
            }
    }
    if (inverse) for (int i = 0; i < n; i++) { a[i].re /= n; a[i].im /= n; }
}
static void fft2(cpx *a, int n, int inverse) {
    cpx col[256];
    for (int y = 0; y < n; y++) fft(a + y * n, n, inverse);
    for (int x = 0; x < n; x++) {
        for (int y = 0; y < n; y++) col[y] = a[y * n + x];
        fft(col, n, inverse);
        for (int y = 0; y < n; y++) a[y * n + x] = col[y];
    }
}

void ci_register_ml_filters(void) {
    REG(@"CISaliencyMapFilter", {
        CIImage *im = IMG(kCIInputImageKey); if (!im) return nil;
        CGRect e = im.extent;
        if (ci_infinite(e) || CGRectIsEmpty(e)) return nil;
        enum { N = 64 };
        CIImage *small = [im imageByApplyingTransform:CGAffineTransformMake(N / e.size.width, 0, 0, N / e.size.height, -e.origin.x * N / e.size.width, -e.origin.y * N / e.size.height)
                                    highQualityDownsample:YES];
        id key = [NSObject new];
        CIImage *map = ci_op(CGRectMake(0, 0, N, N), ^(CGRect r, float *out, const ci_rctx *rc) {
            NSData *sal = ci_cache_get(rc, key, ^id {
                float *px = ci_render_new([small imageByClampingToExtent], CGRectMake(0, 0, N, N), rc);
                cpx *f = calloc(N * N, sizeof(cpx));
                for (int i = 0; i < N * N; i++) f[i].re = px[i * 4 + 3] > 0 ? lumaf(px + i * 4) / px[i * 4 + 3] : 0;
                free(px);
                fft2(f, N, 0);
                float *la = malloc(sizeof(float) * N * N), *ph = malloc(sizeof(float) * N * N);
                for (int i = 0; i < N * N; i++) { la[i] = logf(hypotf(f[i].re, f[i].im) + 1e-6f); ph[i] = atan2f(f[i].im, f[i].re); }
                for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {      /* residual = log amplitude - its 3x3 mean */
                    float s = 0; for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) s += la[((y + j + N) % N) * N + (x + i + N) % N];
                    float res = la[y * N + x] - s / 9, m = expf(res);
                    f[y * N + x] = (cpx){ m * cosf(ph[y * N + x]), m * sinf(ph[y * N + x]) };
                }
                fft2(f, N, 1);
                float *s = malloc(sizeof(float) * 4 * N * N), mx = 1e-12f;
                for (int i = 0; i < N * N; i++) { float v = f[i].re * f[i].re + f[i].im * f[i].im; s[i * 4] = s[i * 4 + 1] = s[i * 4 + 2] = v; s[i * 4 + 3] = 1; }
                ci_blur_buf(s, N, N, 2.5);
                for (int i = 0; i < N * N; i++) mx = fmaxf(mx, s[i * 4]);
                for (int i = 0; i < N * N; i++) { float v = s[i * 4] / mx; s[i * 4] = s[i * 4 + 1] = s[i * 4 + 2] = v; }
                free(f); free(la); free(ph);
                return [NSData dataWithBytesNoCopy:s length:sizeof(float) * 4 * N * N];
            });
            const float *s = sal.bytes;
            int W = (int)r.size.width, H = (int)r.size.height;
            for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) {
                int x = (int)r.origin.x + i, y = (int)ci_px_y(r, j);
                if (x >= 0 && y >= 0 && x < N && y < N) memcpy(out + ((size_t)j * W + i) * 4, s + ((size_t)(N - 1 - y) * N + x) * 4, 16);
            }
        });
        /* the map is low resolution like Apple's; shown over the input's extent */
        return [[[map imageByClampingToExtent] imageByApplyingTransform:CGAffineTransformMake(e.size.width / N, 0, 0, e.size.height / N, e.origin.x, e.origin.y)] imageByCroppingToRect:e];
    });
    REG(@"CIPersonSegmentation", {
        static BOOL told;
        if (!told) { told = YES; NSLog(@"isim: CIPersonSegmentation needs Apple's person segmentation model, which isim does not have: no output"); }
        return nil;
    });
    REG(@"CICoreMLModelFilter", {
        static BOOL told;
        if (!told) { told = YES; NSLog(@"isim: CICoreMLModelFilter needs Apple's Core ML runtime for image models, which isim does not have: no output"); }
        return nil;
    });
}
