/* isim Accelerate: more of LAPACK (issue #543), adapted. The algorithms run in double precision (double complex for the
   complex drivers); the single-precision entry points convert in and out.
   - SVD (?gesvd, ?gesdd): one-sided Jacobi (Hestenes), accurate to working precision; signs may differ from
     Apple's (an SVD is unique only up to them).
   - ?geev: Householder reduction to Hessenberg form and the shifted double QR algorithm, with eigenvectors by back
     substitution (EISPACK's orthes / hqr2, as in JAMA); left eigenvectors from the inverse of the right ones.
     Eigenvectors are normalized as LAPACK's (unit norm, largest component real).
   - banded LU (?gbtrf, ?gbtrs, ?gbsv) and Cholesky (?pbtrf, ?pbtrs, ?pbsv), tridiagonal ?gtsv: LAPACK's unblocked
     algorithms and storage.
   - complex: c/z getrf, getrs, gesv, potrf, potrs, posv, and heev (complex Jacobi). */
#include <Accelerate/Accelerate.h>
#pragma STDC CX_LIMITED_RANGE ON
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef double _Complex zd;
#define CM(A, lda, i, j) (A)[(size_t)(j) * (lda) + (i)]
static inline int up(const char *c) { return c && (*c == 'U' || *c == 'u'); }
static inline int is(const char *c, char x) { return c && (*c == x || *c == x + 32); }
static double *dalloc(size_t n) { return calloc(n ? n : 1, sizeof(double)); }
static zd *zalloc(size_t n) { return calloc(n ? n : 1, sizeof(zd)); }
static inline double zabs1(zd z) { return fabs(__builtin_creal(z)) + fabs(__builtin_cimag(z)); }

/* ---------------- SVD ---------------- */
/* one-sided Jacobi on W (m x n, m >= n, column-major, ld m): W V = U S. V is n x n. Returns sorted singular values in s,
   W's columns become U's (zero columns for zero singular values). */
static void jacobi_svd(long m, long n, double *W, double *V, double *s) {
    for (long i = 0; i < n * n; i++) V[i] = 0;
    for (long i = 0; i < n; i++) V[i * n + i] = 1;
    for (int sweep = 0; sweep < 80; sweep++) {
        int rotated = 0;
        for (long p = 0; p < n - 1; p++)
            for (long q = p + 1; q < n; q++) {
                double alpha = 0, beta = 0, gamma = 0;
                for (long i = 0; i < m; i++) { double a = W[p * m + i], b = W[q * m + i]; alpha += a * a; beta += b * b; gamma += a * b; }
                if (gamma == 0 || fabs(gamma) <= 1e-15 * sqrt(alpha * beta)) continue;
                rotated = 1;
                double zeta = (beta - alpha) / (2 * gamma);
                double t = (zeta >= 0 ? 1 : -1) / (fabs(zeta) + sqrt(1 + zeta * zeta));
                double c = 1 / sqrt(1 + t * t), sn = c * t;
                for (long i = 0; i < m; i++) { double a = W[p * m + i], b = W[q * m + i]; W[p * m + i] = c * a - sn * b; W[q * m + i] = sn * a + c * b; }
                for (long i = 0; i < n; i++) { double a = V[p * n + i], b = V[q * n + i]; V[p * n + i] = c * a - sn * b; V[q * n + i] = sn * a + c * b; }
            }
        if (!rotated) break;
    }
    for (long j = 0; j < n; j++) {
        double nr = 0;
        for (long i = 0; i < m; i++) nr += W[j * m + i] * W[j * m + i];
        s[j] = sqrt(nr);
    }
    /* sort descending (selection sort keeps it simple) */
    for (long j = 0; j < n; j++) {
        long b = j;
        for (long k = j + 1; k < n; k++) if (s[k] > s[b]) b = k;
        if (b != j) {
            double t = s[j]; s[j] = s[b]; s[b] = t;
            for (long i = 0; i < m; i++) { t = W[j * m + i]; W[j * m + i] = W[b * m + i]; W[b * m + i] = t; }
            for (long i = 0; i < n; i++) { t = V[j * n + i]; V[j * n + i] = V[b * n + i]; V[b * n + i] = t; }
        }
    }
    double tiny = (s[0] > 0 ? s[0] : 1) * 1e-300;
    for (long j = 0; j < n; j++)
        for (long i = 0; i < m; i++) W[j * m + i] = s[j] > tiny ? W[j * m + i] / s[j] : 0;
}
/* completes the first k columns of Q (m x cols, ld m; zero columns are replaced) to orthonormal columns */
static void complete_basis(long m, long cols, double *Q, long k) {
    long e = 0;
    for (long j = 0; j < cols; j++) {
        double nr = 0;
        for (long i = 0; i < m; i++) nr += Q[j * m + i] * Q[j * m + i];
        if (j < k && nr > 0.5) continue;
        for (;;) {                                               /* the next unit vector, orthogonalized twice */
            for (long i = 0; i < m; i++) Q[j * m + i] = i == e % m ? 1 : 0;
            e++;
            for (int pass = 0; pass < 2; pass++)
                for (long c = 0; c < j; c++) {
                    double d = 0;
                    for (long i = 0; i < m; i++) d += Q[c * m + i] * Q[j * m + i];
                    for (long i = 0; i < m; i++) Q[j * m + i] -= d * Q[c * m + i];
                }
            nr = 0;
            for (long i = 0; i < m; i++) nr += Q[j * m + i] * Q[j * m + i];
            if (nr > 1e-6 || e > 2 * m + cols) break;
        }
        nr = sqrt(nr);
        for (long i = 0; i < m; i++) Q[j * m + i] /= nr;
    }
}
/* A (m x n, lda) = U S VT. ucols / vtrows: how many columns of U / rows of VT to produce (0, min(m,n), m / n).
   U: m x ucols (ldu), VT: vtrows x n (ldvt). Returns 0. */
static int svd(long m, long n, const double *A, long lda, double *s, double *U, long ldu, long ucols, double *VT, long ldvt, long vtrows) {
    int tr = m < n;
    long M = tr ? n : m, N = tr ? m : n, k = N;                 /* work on A or A^T, M >= N */
    double *W = dalloc((size_t)M * N), *V = dalloc((size_t)N * N);
    for (long j = 0; j < N; j++) for (long i = 0; i < M; i++) W[j * M + i] = tr ? CM(A, lda, j, i) : CM(A, lda, i, j);
    jacobi_svd(M, N, W, V, s);
    /* A' = W S V^T: the left factor is W (M x N), the right V (N x N) */
    long lcols = tr ? vtrows : ucols, rcols = tr ? ucols : vtrows;   /* columns wanted of W-side (M) and V-side (N) */
    double *L = dalloc((size_t)M * (lcols > N ? lcols : N));
    memcpy(L, W, sizeof(double) * M * N);
    if (lcols > 0) complete_basis(M, lcols, L, k);
    double *R = V;
    if (rcols > 0) complete_basis(N, rcols, R, N);
    /* U and VT */
    if (!tr) {
        for (long j = 0; j < ucols; j++) for (long i = 0; i < m; i++) CM(U, ldu, i, j) = L[j * M + i];
        for (long r = 0; r < vtrows; r++) for (long j = 0; j < n; j++) CM(VT, ldvt, r, j) = R[r * N + j];
    } else {                                                     /* A = V S W^T */
        for (long j = 0; j < ucols; j++) for (long i = 0; i < m; i++) CM(U, ldu, i, j) = R[j * N + i];
        for (long r = 0; r < vtrows; r++) for (long j = 0; j < n; j++) CM(VT, ldvt, r, j) = L[r * M + j];
    }
    free(W); free(V); free(L);
    return 0;
}
static long cols_for(char job, long m, long n, long full) {
    long k = m < n ? m : n;
    if (job == 'A' || job == 'a') return full;
    if (job == 'S' || job == 's' || job == 'O' || job == 'o') return k;
    return 0;
}
/* gesvd / gesdd in double, with the 'O' (overwrite A) choices */
static int gesvd_d(char ju, char jvt, long m, long n, double *a, long lda, double *s, double *u, long ldu, double *vt, long ldvt) {
    long k = m < n ? m : n;
    long uc = cols_for(ju, m, n, m), vr = cols_for(jvt, m, n, n);
    int uo = ju == 'O' || ju == 'o', vo = jvt == 'O' || jvt == 'o';
    double *U = uo ? dalloc((size_t)m * k) : u, *VT = vo ? dalloc((size_t)k * n) : vt;
    long lu = uo ? m : ldu, lv = vo ? k : ldvt;
    svd(m, n, a, lda, s, U, lu, uc, VT, lv, vr);
    if (uo) { for (long j = 0; j < k; j++) for (long i = 0; i < m; i++) CM(a, lda, i, j) = U[j * m + i]; free(U); }
    if (vo) { for (long j = 0; j < n; j++) for (long i = 0; i < k; i++) CM(a, lda, i, j) = VT[j * k + i]; free(VT); }
    return 0;
}

/* ---------------- nonsymmetric eigenproblem ---------------- */
static void cdiv(double xr, double xi, double yr, double yi, double *cr, double *ci) {
    double r, d;
    if (fabs(yr) > fabs(yi)) { r = yi / yr; d = yr + r * yi; *cr = (xr + r * xi) / d; *ci = (xi - r * xr) / d; }
    else { r = yr / yi; d = yi + r * yr; *cr = (r * xr + xi) / d; *ci = (r * xi - xr) / d; }
}
/* H (row-major n x n) -> real Schur form; V the Schur vectors, then the eigenvectors (JAMA's orthes + hqr2).
   d + i e: the eigenvalues. Returns 0, or > 0 when the QR iteration did not converge. */
#define HH(i, j) H[(size_t)(i) * nn + (j)]
#define VV(i, j) V[(size_t)(i) * nn + (j)]
static int hqr2(long nn, double *H, double *V, double *d, double *e) {
    double *ort = dalloc(nn);
    long low = 0, high = nn - 1;
    for (long m = low + 1; m <= high - 1; m++) {
        double scale = 0;
        for (long i = m; i <= high; i++) scale += fabs(HH(i, m - 1));
        if (scale != 0) {
            double h = 0;
            for (long i = high; i >= m; i--) { ort[i] = HH(i, m - 1) / scale; h += ort[i] * ort[i]; }
            double g = sqrt(h);
            if (ort[m] > 0) g = -g;
            h -= ort[m] * g; ort[m] -= g;
            for (long j = m; j < nn; j++) {
                double f = 0;
                for (long i = high; i >= m; i--) f += ort[i] * HH(i, j);
                f /= h;
                for (long i = m; i <= high; i++) HH(i, j) -= f * ort[i];
            }
            for (long i = 0; i <= high; i++) {
                double f = 0;
                for (long j = high; j >= m; j--) f += ort[j] * HH(i, j);
                f /= h;
                for (long j = m; j <= high; j++) HH(i, j) -= f * ort[j];
            }
            ort[m] *= scale; HH(m, m - 1) = scale * g;
        }
    }
    for (long i = 0; i < nn; i++) for (long j = 0; j < nn; j++) VV(i, j) = i == j;
    for (long m = high - 1; m >= low + 1; m--)
        if (HH(m, m - 1) != 0) {
            for (long i = m + 1; i <= high; i++) ort[i] = HH(i, m - 1);
            for (long j = m; j <= high; j++) {
                double g = 0;
                for (long i = m; i <= high; i++) g += ort[i] * VV(i, j);
                g = (g / ort[m]) / HH(m, m - 1);
                for (long i = m; i <= high; i++) VV(i, j) += g * ort[i];
            }
        }
    free(ort);

    long n = nn - 1;
    double eps = 2.220446049250313e-16, exshift = 0, p = 0, q = 0, r = 0, s = 0, z = 0, t, w, x, y, norm = 0;
    for (long i = 0; i < nn; i++) for (long j = i > 0 ? i - 1 : 0; j < nn; j++) norm += fabs(HH(i, j));
    int iter = 0, total = 0;
    while (n >= low) {
        long l = n;
        while (l > low) {
            s = fabs(HH(l - 1, l - 1)) + fabs(HH(l, l));
            if (s == 0) s = norm;
            if (fabs(HH(l, l - 1)) < eps * s) break;
            l--;
        }
        if (l == n) {
            HH(n, n) += exshift; d[n] = HH(n, n); e[n] = 0; n--; iter = 0;
        } else if (l == n - 1) {
            w = HH(n, n - 1) * HH(n - 1, n);
            p = (HH(n - 1, n - 1) - HH(n, n)) / 2;
            q = p * p + w;
            z = sqrt(fabs(q));
            HH(n, n) += exshift; HH(n - 1, n - 1) += exshift;
            x = HH(n, n);
            if (q >= 0) {
                z = p >= 0 ? p + z : p - z;
                d[n - 1] = x + z; d[n] = d[n - 1];
                if (z != 0) d[n] = x - w / z;
                e[n - 1] = 0; e[n] = 0;
                x = HH(n, n - 1);
                s = fabs(x) + fabs(z); p = x / s; q = z / s; r = sqrt(p * p + q * q); p /= r; q /= r;
                for (long j = n - 1; j < nn; j++) { z = HH(n - 1, j); HH(n - 1, j) = q * z + p * HH(n, j); HH(n, j) = q * HH(n, j) - p * z; }
                for (long i = 0; i <= n; i++) { z = HH(i, n - 1); HH(i, n - 1) = q * z + p * HH(i, n); HH(i, n) = q * HH(i, n) - p * z; }
                for (long i = low; i <= high; i++) { z = VV(i, n - 1); VV(i, n - 1) = q * z + p * VV(i, n); VV(i, n) = q * VV(i, n) - p * z; }
            } else {
                d[n - 1] = x + p; d[n] = x + p; e[n - 1] = z; e[n] = -z;
            }
            n -= 2; iter = 0;
        } else {
            x = HH(n, n); y = 0; w = 0;
            if (l < n) { y = HH(n - 1, n - 1); w = HH(n, n - 1) * HH(n - 1, n); }
            if (iter == 10) {
                exshift += x;
                for (long i = low; i <= n; i++) HH(i, i) -= x;
                s = fabs(HH(n, n - 1)) + fabs(HH(n - 1, n - 2));
                x = y = 0.75 * s; w = -0.4375 * s * s;
            }
            if (iter == 30) {
                s = (y - x) / 2; s = s * s + w;
                if (s > 0) {
                    s = sqrt(s);
                    if (y < x) s = -s;
                    s = x - w / ((y - x) / 2 + s);
                    for (long i = low; i <= n; i++) HH(i, i) -= s;
                    exshift += s; x = y = w = 0.964;
                }
            }
            iter++;
            if (++total > 100 * (int)nn + 1000) return (int)n + 1;
            long m = n - 2;
            while (m >= l) {
                z = HH(m, m); r = x - z; s = y - z;
                p = (r * s - w) / HH(m + 1, m) + HH(m, m + 1);
                q = HH(m + 1, m + 1) - z - r - s;
                r = HH(m + 2, m + 1);
                s = fabs(p) + fabs(q) + fabs(r); p /= s; q /= s; r /= s;
                if (m == l) break;
                if (fabs(HH(m, m - 1)) * (fabs(q) + fabs(r)) < eps * (fabs(p) * (fabs(HH(m - 1, m - 1)) + fabs(z) + fabs(HH(m + 1, m + 1))))) break;
                m--;
            }
            for (long i = m + 2; i <= n; i++) { HH(i, i - 2) = 0; if (i > m + 2) HH(i, i - 3) = 0; }
            for (long k = m; k <= n - 1; k++) {
                int notlast = k != n - 1;
                if (k != m) {
                    p = HH(k, k - 1); q = HH(k + 1, k - 1); r = notlast ? HH(k + 2, k - 1) : 0;
                    x = fabs(p) + fabs(q) + fabs(r);
                    if (x == 0) continue;
                    p /= x; q /= x; r /= x;
                }
                s = sqrt(p * p + q * q + r * r);
                if (p < 0) s = -s;
                if (s != 0) {
                    if (k != m) HH(k, k - 1) = -s * x;
                    else if (l != m) HH(k, k - 1) = -HH(k, k - 1);
                    p += s; x = p / s; y = q / s; z = r / s; q /= p; r /= p;
                    for (long j = k; j < nn; j++) {
                        p = HH(k, j) + q * HH(k + 1, j);
                        if (notlast) { p += r * HH(k + 2, j); HH(k + 2, j) -= p * z; }
                        HH(k, j) -= p * x; HH(k + 1, j) -= p * y;
                    }
                    for (long i = 0; i <= (n < k + 3 ? n : k + 3); i++) {
                        p = x * HH(i, k) + y * HH(i, k + 1);
                        if (notlast) { p += z * HH(i, k + 2); HH(i, k + 2) -= p * r; }
                        HH(i, k) -= p; HH(i, k + 1) -= p * q;
                    }
                    for (long i = low; i <= high; i++) {
                        p = x * VV(i, k) + y * VV(i, k + 1);
                        if (notlast) { p += z * VV(i, k + 2); VV(i, k + 2) -= p * r; }
                        VV(i, k) -= p; VV(i, k + 1) -= p * q;
                    }
                }
            }
        }
    }
    if (norm == 0) return 0;
    for (n = nn - 1; n >= 0; n--) {
        p = d[n]; q = e[n];
        if (q == 0) {
            long l = n;
            HH(n, n) = 1;
            for (long i = n - 1; i >= 0; i--) {
                w = HH(i, i) - p; r = 0;
                for (long j = l; j <= n; j++) r += HH(i, j) * HH(j, n);
                if (e[i] < 0) { z = w; s = r; }
                else {
                    l = i;
                    if (e[i] == 0) HH(i, n) = w != 0 ? -r / w : -r / (eps * norm);
                    else {
                        x = HH(i, i + 1); y = HH(i + 1, i);
                        q = (d[i] - p) * (d[i] - p) + e[i] * e[i];
                        t = (x * s - z * r) / q;
                        HH(i, n) = t;
                        HH(i + 1, n) = fabs(x) > fabs(z) ? (-r - w * t) / x : (-s - y * t) / z;
                    }
                    t = fabs(HH(i, n));
                    if ((eps * t) * t > 1) for (long j = i; j <= n; j++) HH(j, n) /= t;
                }
            }
        } else if (q < 0) {
            long l = n - 1;
            if (fabs(HH(n, n - 1)) > fabs(HH(n - 1, n))) {
                HH(n - 1, n - 1) = q / HH(n, n - 1);
                HH(n - 1, n) = -(HH(n, n) - p) / HH(n, n - 1);
            } else cdiv(0, -HH(n - 1, n), HH(n - 1, n - 1) - p, q, &HH(n - 1, n - 1), &HH(n - 1, n));
            HH(n, n - 1) = 0; HH(n, n) = 1;
            for (long i = n - 2; i >= 0; i--) {
                double ra = 0, sa = 0, vr, vi;
                for (long j = l; j <= n; j++) { ra += HH(i, j) * HH(j, n - 1); sa += HH(i, j) * HH(j, n); }
                w = HH(i, i) - p;
                if (e[i] < 0) { z = w; r = ra; s = sa; }
                else {
                    l = i;
                    if (e[i] == 0) cdiv(-ra, -sa, w, q, &HH(i, n - 1), &HH(i, n));
                    else {
                        x = HH(i, i + 1); y = HH(i + 1, i);
                        vr = (d[i] - p) * (d[i] - p) + e[i] * e[i] - q * q;
                        vi = (d[i] - p) * 2 * q;
                        if (vr == 0 && vi == 0) vr = eps * norm * (fabs(w) + fabs(q) + fabs(x) + fabs(y) + fabs(z));
                        cdiv(x * r - z * ra + q * sa, x * s - z * sa - q * ra, vr, vi, &HH(i, n - 1), &HH(i, n));
                        if (fabs(x) > fabs(z) + fabs(q)) {
                            HH(i + 1, n - 1) = (-ra - w * HH(i, n - 1) + q * HH(i, n)) / x;
                            HH(i + 1, n) = (-sa - w * HH(i, n) - q * HH(i, n - 1)) / x;
                        } else cdiv(-r - y * HH(i, n - 1), -s - y * HH(i, n), z, q, &HH(i + 1, n - 1), &HH(i + 1, n));
                    }
                    t = fmax(fabs(HH(i, n - 1)), fabs(HH(i, n)));
                    if ((eps * t) * t > 1) for (long j = i; j <= n; j++) { HH(j, n - 1) /= t; HH(j, n) /= t; }
                }
            }
        }
    }
    for (long j = nn - 1; j >= low; j--)
        for (long i = low; i <= high; i++) {
            z = 0;
            for (long k = low; k <= (j < high ? j : high); k++) z += VV(i, k) * HH(k, j);
            VV(i, j) = z;
        }
    return 0;
}
#undef HH
#undef VV
/* complex LU with partial pivoting, in place (column-major, ld lda); 0 or the 1-based index of a zero pivot */
static long zlu(long m, long n, zd *a, long lda, long *piv) {
    long info = 0, k = m < n ? m : n;
    for (long j = 0; j < k; j++) {
        long p = j;
        for (long i = j + 1; i < m; i++) if (zabs1(CM(a, lda, i, j)) > zabs1(CM(a, lda, p, j))) p = i;
        piv[j] = p;
        if (CM(a, lda, p, j) == 0) { if (!info) info = j + 1; continue; }
        if (p != j) for (long c = 0; c < n; c++) { zd t = CM(a, lda, j, c); CM(a, lda, j, c) = CM(a, lda, p, c); CM(a, lda, p, c) = t; }
        for (long i = j + 1; i < m; i++) {
            zd f = CM(a, lda, i, j) /= CM(a, lda, j, j);
            for (long c = j + 1; c < n; c++) CM(a, lda, i, c) -= f * CM(a, lda, j, c);
        }
    }
    return info;
}
/* solves op(A) X = B with zlu's factors; t: 'N', 'T' or 'C' */
static void zlu_solve(char t, long n, long nrhs, const zd *a, long lda, const long *piv, zd *b, long ldb) {
    for (long r = 0; r < nrhs; r++) {
        zd *x = b + (size_t)r * ldb;
        if (t == 'N' || t == 'n') {
            for (long i = 0; i < n; i++) if (piv[i] != i) { zd tt = x[i]; x[i] = x[piv[i]]; x[piv[i]] = tt; }
            for (long i = 0; i < n; i++) for (long j = 0; j < i; j++) x[i] -= CM(a, lda, i, j) * x[j];
            for (long i = n - 1; i >= 0; i--) { for (long j = i + 1; j < n; j++) x[i] -= CM(a, lda, i, j) * x[j]; x[i] /= CM(a, lda, i, i); }
        } else {
            int cj = t == 'C' || t == 'c';
#define AT(i, j) (cj ? __builtin_conj(CM(a, lda, j, i)) : CM(a, lda, j, i))
            for (long i = 0; i < n; i++) { for (long j = 0; j < i; j++) x[i] -= AT(i, j) * x[j]; x[i] /= AT(i, i); }
            for (long i = n - 1; i >= 0; i--) for (long j = i + 1; j < n; j++) x[i] -= AT(i, j) * x[j];
#undef AT
            for (long i = n - 1; i >= 0; i--) if (piv[i] != i) { zd tt = x[i]; x[i] = x[piv[i]]; x[piv[i]] = tt; }
        }
    }
}
/* normalizes a real or complex eigenvector (LAPACK: Euclidean norm 1, largest component real) */
static void normalize_vec(long n, double *re, double *im) {
    double nr = 0, big = -1; long b = 0;
    for (long i = 0; i < n; i++) {
        double m2 = re[i] * re[i] + (im ? im[i] * im[i] : 0);
        nr += m2;
        if (m2 > big) { big = m2; b = i; }
    }
    nr = sqrt(nr);
    if (nr == 0) return;
    if (!im) { for (long i = 0; i < n; i++) re[i] /= nr; return; }
    zd ph = __builtin_conj(re[b] + im[b] * (zd)1.0i) / sqrt(big);
    for (long i = 0; i < n; i++) {
        zd v = (re[i] + im[i] * (zd)1.0i) * ph / nr;
        re[i] = __builtin_creal(v); im[i] = __builtin_cimag(v);
    }
    im[b] = 0;
}
static int geev_d(char jl, char jr, long n, const double *a, long lda, double *wr, double *wi, double *vl, long ldvl, double *vr, long ldvr) {
    int wantl = jl == 'V' || jl == 'v', wantr = jr == 'V' || jr == 'v';
    double *H = dalloc((size_t)n * n), *V = dalloc((size_t)n * n);
    for (long i = 0; i < n; i++) for (long j = 0; j < n; j++) H[i * n + j] = CM(a, lda, i, j);
    int info = n > 0 ? hqr2(n, H, V, wr, wi) : 0;
    if (info) { free(H); free(V); return info; }
    /* V (row-major) holds the right eigenvectors: column j real, or columns j, j+1 the real and imaginary parts */
    double *R = dalloc((size_t)n * n);                          /* column-major, normalized */
    for (long j = 0; j < n; j++) for (long i = 0; i < n; i++) R[j * n + i] = V[i * n + j];
    for (long j = 0; j < n; j++) {
        if (wi[j] == 0) normalize_vec(n, R + j * n, NULL);
        else if (wi[j] > 0 && j + 1 < n) { normalize_vec(n, R + j * n, R + (j + 1) * n); j++; }
    }
    if (wantr) for (long j = 0; j < n; j++) for (long i = 0; i < n; i++) CM(vr, ldvr, i, j) = R[j * n + i];
    if (wantl) {
        /* rows of X^-1 (X the complex eigenvector matrix) are the left eigenvectors' conjugate transposes */
        zd *X = zalloc((size_t)n * n), *I = zalloc((size_t)n * n);
        long *piv = calloc(n ? n : 1, sizeof(long));
        for (long j = 0; j < n; j++) {
            if (wi[j] == 0) for (long i = 0; i < n; i++) X[j * n + i] = R[j * n + i];
            else if (wi[j] > 0 && j + 1 < n) {
                for (long i = 0; i < n; i++) {
                    X[j * n + i] = R[j * n + i] + R[(j + 1) * n + i] * (zd)1.0i;
                    X[(j + 1) * n + i] = R[j * n + i] - R[(j + 1) * n + i] * (zd)1.0i;
                }
                j++;
            }
        }
        for (long i = 0; i < n; i++) I[i * n + i] = 1;
        zlu(n, n, X, n, piv);
        zlu_solve('N', n, n, X, n, piv, I, n);                  /* I = X^-1 */
        double *ure = dalloc(n), *uim = dalloc(n);
        for (long j = 0; j < n; j++) {
            for (long i = 0; i < n; i++) { zd u = __builtin_conj(I[i * n + j]); ure[i] = __builtin_creal(u); uim[i] = __builtin_cimag(u); }
            if (wi[j] == 0) { normalize_vec(n, ure, NULL); for (long i = 0; i < n; i++) CM(vl, ldvl, i, j) = ure[i]; }
            else if (wi[j] > 0 && j + 1 < n) {
                normalize_vec(n, ure, uim);
                for (long i = 0; i < n; i++) { CM(vl, ldvl, i, j) = ure[i]; CM(vl, ldvl, i, j + 1) = uim[i]; }
                j++;
            }
        }
        free(X); free(I); free(piv); free(ure); free(uim);
    }
    free(H); free(V); free(R);
    return 0;
}

/* ---------------- banded and tridiagonal ---------------- */
#define BAND(i, j) ab[(size_t)(kv + (i) - (j)) + (size_t)(j) * ldab]
static long gbtrf_d(long m, long n, long kl, long ku, double *ab, long ldab, long *piv) {
    long kv = ku + kl, info = 0, ju = 0;
    for (long j = ku + 1; j < (kv < n ? kv : n); j++) for (long i = kv - j; i < kl; i++) ab[i + (size_t)j * ldab] = 0;
    for (long j = 0; j < (m < n ? m : n); j++) {
        if (j + kv < n) for (long i = 0; i < kl; i++) ab[i + (size_t)(j + kv) * ldab] = 0;
        long km = kl < m - 1 - j ? kl : m - 1 - j, jp = 0;
        for (long i = 1; i <= km; i++) if (fabs(BAND(j + i, j)) > fabs(BAND(j + jp, j))) jp = i;
        piv[j] = j + jp;
        if (BAND(j + jp, j) != 0) {
            long c1 = j + ku + jp < n - 1 ? j + ku + jp : n - 1;
            if (c1 > ju) ju = c1;
            if (jp) for (long c = j; c <= ju; c++) { double t = BAND(j, c); BAND(j, c) = BAND(j + jp, c); BAND(j + jp, c) = t; }
            for (long i = 1; i <= km; i++) BAND(j + i, j) /= BAND(j, j);
            for (long c = j + 1; c <= ju; c++) for (long i = 1; i <= km; i++) BAND(j + i, c) -= BAND(j + i, j) * BAND(j, c);
        } else if (!info) info = j + 1;
    }
    return info;
}
static void gbtrs_d(char t, long n, long kl, long ku, long nrhs, const double *ab, long ldab, const long *piv, double *b, long ldb) {
    long kv = ku + kl;
    for (long r = 0; r < nrhs; r++) {
        double *x = b + (size_t)r * ldb;
        if (t == 'N' || t == 'n') {
            for (long j = 0; j < n - 1 && kl > 0; j++) {
                long lm = kl < n - 1 - j ? kl : n - 1 - j;
                if (piv[j] != j) { double tt = x[j]; x[j] = x[piv[j]]; x[piv[j]] = tt; }
                for (long i = 1; i <= lm; i++) x[j + i] -= BAND(j + i, j) * x[j];
            }
            for (long j = n - 1; j >= 0; j--) {
                x[j] /= BAND(j, j);
                for (long i = j - kv > 0 ? j - kv : 0; i < j; i++) x[i] -= BAND(i, j) * x[j];
            }
        } else {
            for (long j = 0; j < n; j++) {
                for (long i = j - kv > 0 ? j - kv : 0; i < j; i++) x[j] -= BAND(i, j) * x[i];
                x[j] /= BAND(j, j);
            }
            for (long j = n - 2; j >= 0 && kl > 0; j--) {
                long lm = kl < n - 1 - j ? kl : n - 1 - j;
                for (long i = 1; i <= lm; i++) x[j] -= BAND(j + i, j) * x[j + i];
                if (piv[j] != j) { double tt = x[j]; x[j] = x[piv[j]]; x[piv[j]] = tt; }
            }
        }
    }
}
#undef BAND
/* band Cholesky: upper, A(i, j) at ab[kd + i - j, j]; lower at ab[i - j, j] */
static long pbtrf_d(int upper, long n, long kd, double *ab, long ldab) {
#define U_(i, j) ab[(size_t)(kd + (i) - (j)) + (size_t)(j) * ldab]
#define L_(i, j) ab[(size_t)((i) - (j)) + (size_t)(j) * ldab]
    for (long j = 0; j < n; j++) {
        double s = upper ? U_(j, j) : L_(j, j);
        for (long k = j - kd > 0 ? j - kd : 0; k < j; k++) { double v = upper ? U_(k, j) : L_(j, k); s -= v * v; }
        if (!(s > 0)) return j + 1;
        double djj = sqrt(s);
        if (upper) U_(j, j) = djj; else L_(j, j) = djj;
        for (long c = j + 1; c <= (j + kd < n - 1 ? j + kd : n - 1); c++) {
            double v = upper ? U_(j, c) : L_(c, j);
            for (long k = c - kd > 0 ? c - kd : 0; k < j; k++) v -= upper ? U_(k, j) * U_(k, c) : L_(j, k) * L_(c, k);
            if (upper) U_(j, c) = v / djj; else L_(c, j) = v / djj;
        }
    }
    return 0;
}
static void pbtrs_d(int upper, long n, long kd, long nrhs, const double *ab, long ldab, double *b, long ldb) {
    for (long r = 0; r < nrhs; r++) {
        double *x = b + (size_t)r * ldb;
        /* forward: R^T y = b (R = U, or L^T) */
        for (long i = 0; i < n; i++) {
            for (long k = i - kd > 0 ? i - kd : 0; k < i; k++) x[i] -= (upper ? U_(k, i) : L_(i, k)) * x[k];
            x[i] /= upper ? U_(i, i) : L_(i, i);
        }
        for (long i = n - 1; i >= 0; i--) {
            for (long k = i + 1; k <= (i + kd < n - 1 ? i + kd : n - 1); k++) x[i] -= (upper ? U_(i, k) : L_(k, i)) * x[k];
            x[i] /= upper ? U_(i, i) : L_(i, i);
        }
    }
#undef U_
#undef L_
}
static long gtsv_d(long n, long nrhs, double *dl, double *d, double *du, double *b, long ldb) {
    for (long i = 0; i < n - 1; i++) {
        if (fabs(d[i]) >= fabs(dl[i])) {
            if (d[i] == 0) return i + 1;
            double f = dl[i] / d[i];
            d[i + 1] -= f * du[i];
            for (long r = 0; r < nrhs; r++) b[r * ldb + i + 1] -= f * b[r * ldb + i];
            if (i < n - 2) dl[i] = 0;
        } else {
            double f = d[i] / dl[i], t;
            d[i] = dl[i]; t = d[i + 1]; d[i + 1] = du[i] - f * t;
            if (i < n - 2) { dl[i] = du[i + 1]; du[i + 1] = -f * dl[i]; }
            du[i] = t;
            for (long r = 0; r < nrhs; r++) { double *x = b + r * ldb; t = x[i]; x[i] = x[i + 1]; x[i + 1] = t - f * x[i + 1]; }
        }
    }
    if (n > 0 && d[n - 1] == 0) return n;
    for (long r = 0; r < nrhs; r++) {
        double *x = b + r * ldb;
        if (n == 0) break;
        x[n - 1] /= d[n - 1];
        if (n > 1) x[n - 2] = (x[n - 2] - du[n - 2] * x[n - 1]) / d[n - 2];
        for (long i = n - 3; i >= 0; i--) x[i] = (x[i] - du[i] * x[i + 1] - dl[i] * x[i + 2]) / d[i];
    }
    return 0;
}

/* ---------------- complex Hermitian ---------------- */
static long zpotrf(int upper, long n, zd *a, long lda) {
    for (long j = 0; j < n; j++) {
        double s = __builtin_creal(CM(a, lda, j, j));
        for (long k = 0; k < j; k++) { zd v = upper ? CM(a, lda, k, j) : CM(a, lda, j, k); s -= __builtin_creal(v * __builtin_conj(v)); }
        if (!(s > 0)) return j + 1;
        double djj = sqrt(s);
        CM(a, lda, j, j) = djj;
        for (long c = j + 1; c < n; c++) {
            if (upper) {                                         /* A = U^H U: U(j, c) */
                zd v = CM(a, lda, j, c);
                for (long k = 0; k < j; k++) v -= __builtin_conj(CM(a, lda, k, j)) * CM(a, lda, k, c);
                CM(a, lda, j, c) = v / djj;
            } else {                                             /* A = L L^H: L(c, j) */
                zd v = CM(a, lda, c, j);
                for (long k = 0; k < j; k++) v -= CM(a, lda, c, k) * __builtin_conj(CM(a, lda, j, k));
                CM(a, lda, c, j) = v / djj;
            }
        }
    }
    return 0;
}
static void zpotrs(int upper, long n, long nrhs, const zd *a, long lda, zd *b, long ldb) {
    for (long r = 0; r < nrhs; r++) {
        zd *x = b + (size_t)r * ldb;
        /* L y = b with L = U^H or L; then L^H x = y */
        for (long i = 0; i < n; i++) {
            for (long k = 0; k < i; k++) x[i] -= (upper ? __builtin_conj(CM(a, lda, k, i)) : CM(a, lda, i, k)) * x[k];
            x[i] /= __builtin_creal(CM(a, lda, i, i));
        }
        for (long i = n - 1; i >= 0; i--) {
            for (long k = i + 1; k < n; k++) x[i] -= (upper ? CM(a, lda, i, k) : __builtin_conj(CM(a, lda, k, i))) * x[k];
            x[i] /= __builtin_creal(CM(a, lda, i, i));
        }
    }
}
/* eigenvalues (ascending) and optionally eigenvectors (into a) of a Hermitian matrix: cyclic complex Jacobi */
static void zheev(int vectors, int upper, long n, zd *a, long lda, double *w) {
    zd *A = zalloc((size_t)n * n), *V = zalloc((size_t)n * n);
    for (long j = 0; j < n; j++)
        for (long i = 0; i < n; i++) {
            int stored = upper ? i <= j : i >= j;
            A[j * n + i] = stored ? CM(a, lda, i, j) : __builtin_conj(CM(a, lda, j, i));
        }
    for (long i = 0; i < n; i++) { A[i * n + i] = __builtin_creal(A[i * n + i]); V[i * n + i] = 1; }
    for (int sweep = 0; sweep < 100; sweep++) {
        double off = 0, tot = 0;
        for (long j = 0; j < n; j++) for (long i = 0; i < n; i++) { double m2 = __builtin_creal(A[j * n + i] * __builtin_conj(A[j * n + i])); tot += m2; if (i != j) off += m2; }
        if (off <= 1e-30 * tot || off == 0) break;
        for (long p = 0; p < n - 1; p++)
            for (long q = p + 1; q < n; q++) {
                zd g = A[q * n + p];                             /* A(p, q) */
                double ag = sqrt(__builtin_creal(g * __builtin_conj(g)));
                if (ag == 0) continue;
                double app = __builtin_creal(A[p * n + p]), aqq = __builtin_creal(A[q * n + q]);
                double theta = (aqq - app) / (2 * ag);
                double t = (theta >= 0 ? 1 : -1) / (fabs(theta) + sqrt(theta * theta + 1));
                double c = 1 / sqrt(t * t + 1), s = t * c;
                zd e = g / ag, ec = __builtin_conj(e);
                /* J = [[c, s], [-s conj(e), c conj(e)]] on (p, q): A = J^H A J, V = V J */
                for (long k = 0; k < n; k++) {
                    zd akp = A[p * n + k], akq = A[q * n + k];
                    A[p * n + k] = c * akp - s * ec * akq; A[q * n + k] = s * akp + c * ec * akq;
                    zd vkp = V[p * n + k], vkq = V[q * n + k];
                    V[p * n + k] = c * vkp - s * ec * vkq; V[q * n + k] = s * vkp + c * ec * vkq;
                }
                for (long k = 0; k < n; k++) {
                    zd apk = A[k * n + p], aqk = A[k * n + q];
                    A[k * n + p] = c * apk - s * e * aqk; A[k * n + q] = s * apk + c * e * aqk;
                }
                A[q * n + p] = 0; A[p * n + q] = 0;
                A[p * n + p] = __builtin_creal(A[p * n + p]); A[q * n + q] = __builtin_creal(A[q * n + q]);
            }
    }
    long *ord = calloc(n ? n : 1, sizeof(long));
    for (long i = 0; i < n; i++) { w[i] = __builtin_creal(A[i * n + i]); ord[i] = i; }
    for (long i = 0; i < n; i++)                                 /* ascending */
        for (long j = i + 1; j < n; j++) if (w[ord[j]] < w[ord[i]]) { long t = ord[i]; ord[i] = ord[j]; ord[j] = t; }
    double *ws = dalloc(n);
    for (long i = 0; i < n; i++) ws[i] = w[ord[i]];
    memcpy(w, ws, sizeof(double) * n);
    if (vectors) for (long j = 0; j < n; j++) for (long i = 0; i < n; i++) CM(a, lda, i, j) = V[ord[j] * n + i];
    free(A); free(V); free(ord); free(ws);
}

/* ---------------- the entry points ---------------- */
static int query(__CLPK_integer *lwork, void *work, int dbl, long size) {
    if (*lwork != -1) return 0;
    if (dbl) ((double *)work)[0] = size; else ((float *)work)[0] = size;
    return 1;
}
static double *f2d(const float *a, long lda, long m, long n) {
    double *d = dalloc((size_t)(lda > 0 ? lda : 1) * (n > 0 ? n : 1));
    for (long j = 0; j < n; j++) for (long i = 0; i < m; i++) d[j * lda + i] = a[(size_t)j * lda + i];
    return d;
}
static void d2f(float *a, long lda, const double *d, long m, long n) {
    for (long j = 0; j < n; j++) for (long i = 0; i < m; i++) a[(size_t)j * lda + i] = (float)d[j * lda + i];
}

int dgesvd_(char *jobu, char *jobvt, __CLPK_integer *m, __CLPK_integer *n, __CLPK_doublereal *a, __CLPK_integer *lda, __CLPK_doublereal *s,
            __CLPK_doublereal *u, __CLPK_integer *ldu, __CLPK_doublereal *vt, __CLPK_integer *ldvt, __CLPK_doublereal *work,
            __CLPK_integer *lwork, __CLPK_integer *info) {
    *info = 0;
    if (*m < 0) *info = -3; else if (*n < 0) *info = -4; else if (*lda < (*m > 1 ? *m : 1)) *info = -6;
    if (*info) return 0;
    if (query(lwork, work, 1, 5 * (*m > *n ? *m : *n) + 1)) return 0;
    gesvd_d(*jobu, *jobvt, *m, *n, a, *lda, s, u, *ldu, vt, *ldvt);
    return 0;
}
int sgesvd_(char *jobu, char *jobvt, __CLPK_integer *m, __CLPK_integer *n, __CLPK_real *a, __CLPK_integer *lda, __CLPK_real *s,
            __CLPK_real *u, __CLPK_integer *ldu, __CLPK_real *vt, __CLPK_integer *ldvt, __CLPK_real *work, __CLPK_integer *lwork,
            __CLPK_integer *info) {
    *info = 0;
    if (*m < 0) *info = -3; else if (*n < 0) *info = -4; else if (*lda < (*m > 1 ? *m : 1)) *info = -6;
    if (*info) return 0;
    if (query(lwork, work, 0, 5 * (*m > *n ? *m : *n) + 1)) return 0;
    long k = *m < *n ? *m : *n, uc = cols_for(*jobu, *m, *n, *m), vr = cols_for(*jobvt, *m, *n, *n);
    double *A = f2d(a, *lda, *m, *n), *S = dalloc(k), *U = dalloc((size_t)*m * (*m > 0 ? *m : 1)), *VT = dalloc((size_t)*n * (*n > 0 ? *n : 1));
    char ju = (*jobu == 'O' || *jobu == 'o') ? 'S' : *jobu, jv = (*jobvt == 'O' || *jobvt == 'o') ? 'S' : *jobvt;
    gesvd_d(ju, jv, *m, *n, A, *lda, S, U, *m, VT, *n);
    for (long i = 0; i < k; i++) s[i] = (float)S[i];
    if (*jobu == 'O' || *jobu == 'o') for (long j = 0; j < k; j++) for (long i = 0; i < *m; i++) a[(size_t)j * *lda + i] = (float)U[j * *m + i];
    else for (long j = 0; j < uc; j++) for (long i = 0; i < *m; i++) u[(size_t)j * *ldu + i] = (float)U[j * *m + i];
    if (*jobvt == 'O' || *jobvt == 'o') for (long j = 0; j < *n; j++) for (long i = 0; i < k; i++) a[(size_t)j * *lda + i] = (float)VT[j * *n + i];
    else for (long j = 0; j < *n; j++) for (long i = 0; i < vr; i++) vt[(size_t)j * *ldvt + i] = (float)VT[j * *n + i];
    free(A); free(S); free(U); free(VT);
    return 0;
}
/* gesdd: jobz 'A' (all), 'S' (min(m, n)), 'O' (overwrite A with U if m >= n, else with VT) or 'N' */
int dgesdd_(char *jobz, __CLPK_integer *m, __CLPK_integer *n, __CLPK_doublereal *a, __CLPK_integer *lda, __CLPK_doublereal *s,
            __CLPK_doublereal *u, __CLPK_integer *ldu, __CLPK_doublereal *vt, __CLPK_integer *ldvt, __CLPK_doublereal *work,
            __CLPK_integer *lwork, __CLPK_integer *iwork, __CLPK_integer *info) {
    *info = 0;
    if (*m < 0) *info = -2; else if (*n < 0) *info = -3; else if (*lda < (*m > 1 ? *m : 1)) *info = -5;
    if (*info) return 0;
    if (query(lwork, work, 1, 7 * (*m > *n ? *m : *n) + 1)) return 0;
    char j = *jobz;
    if (j == 'O' || j == 'o') { if (*m >= *n) gesvd_d('O', 'S', *m, *n, a, *lda, s, u, *ldu, vt, *ldvt); else gesvd_d('S', 'O', *m, *n, a, *lda, s, u, *ldu, vt, *ldvt); }
    else gesvd_d(j, j, *m, *n, a, *lda, s, u, *ldu, vt, *ldvt);
    return 0;
}
int sgesdd_(char *jobz, __CLPK_integer *m, __CLPK_integer *n, __CLPK_real *a, __CLPK_integer *lda, __CLPK_real *s, __CLPK_real *u,
            __CLPK_integer *ldu, __CLPK_real *vt, __CLPK_integer *ldvt, __CLPK_real *work, __CLPK_integer *lwork, __CLPK_integer *iwork,
            __CLPK_integer *info) {
    char j = *jobz, ju = j, jv = j;
    if (j == 'O' || j == 'o') { if (*m >= *n) { ju = 'O'; jv = 'S'; } else { ju = 'S'; jv = 'O'; } }
    __CLPK_integer lw = *lwork;
    sgesvd_(&ju, &jv, m, n, a, lda, s, u, ldu, vt, ldvt, work, &lw, info);
    if (*info == -3 || *info == -4) (*info)++;
    else if (*info == -6) *info = -5;
    return 0;
}
int dgeev_(char *jobvl, char *jobvr, __CLPK_integer *n, __CLPK_doublereal *a, __CLPK_integer *lda, __CLPK_doublereal *wr,
           __CLPK_doublereal *wi, __CLPK_doublereal *vl, __CLPK_integer *ldvl, __CLPK_doublereal *vr, __CLPK_integer *ldvr,
           __CLPK_doublereal *work, __CLPK_integer *lwork, __CLPK_integer *info) {
    *info = 0;
    if (*n < 0) *info = -3; else if (*lda < (*n > 1 ? *n : 1)) *info = -5;
    if (*info) return 0;
    if (query(lwork, work, 1, 4 * *n + 1)) return 0;
    *info = geev_d(*jobvl, *jobvr, *n, a, *lda, wr, wi, vl, *ldvl, vr, *ldvr);
    return 0;
}
int sgeev_(char *jobvl, char *jobvr, __CLPK_integer *n, __CLPK_real *a, __CLPK_integer *lda, __CLPK_real *wr, __CLPK_real *wi,
           __CLPK_real *vl, __CLPK_integer *ldvl, __CLPK_real *vr, __CLPK_integer *ldvr, __CLPK_real *work, __CLPK_integer *lwork,
           __CLPK_integer *info) {
    *info = 0;
    if (*n < 0) *info = -3; else if (*lda < (*n > 1 ? *n : 1)) *info = -5;
    if (*info) return 0;
    if (query(lwork, work, 0, 4 * *n + 1)) return 0;
    long N = *n;
    double *A = f2d(a, *lda, N, N), *WR = dalloc(N), *WI = dalloc(N), *VL = dalloc((size_t)N * N), *VR = dalloc((size_t)N * N);
    *info = geev_d(*jobvl, *jobvr, N, A, *lda, WR, WI, VL, N, VR, N);
    for (long i = 0; i < N; i++) { wr[i] = (float)WR[i]; wi[i] = (float)WI[i]; }
    if (*jobvl == 'V' || *jobvl == 'v') for (long j = 0; j < N; j++) for (long i = 0; i < N; i++) vl[(size_t)j * *ldvl + i] = (float)VL[j * N + i];
    if (*jobvr == 'V' || *jobvr == 'v') for (long j = 0; j < N; j++) for (long i = 0; i < N; i++) vr[(size_t)j * *ldvr + i] = (float)VR[j * N + i];
    free(A); free(WR); free(WI); free(VL); free(VR);
    return 0;
}

/* banded: the entry points share these through a precision macro */
#define BANDED(T, p, F2D, D2F) \
int p##gbtrf_(__CLPK_integer *m, __CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, T *ab, __CLPK_integer *ldab, __CLPK_integer *ipiv, \
              __CLPK_integer *info) { \
    *info = 0; \
    if (*m < 0) *info = -1; else if (*n < 0) *info = -2; else if (*kl < 0) *info = -3; else if (*ku < 0) *info = -4; \
    else if (*ldab < 2 * *kl + *ku + 1) *info = -6; \
    if (*info) return 0; \
    double *AB = F2D(ab, *ldab, *ldab, *n); long *piv = calloc(*m > 0 ? *m : 1, sizeof(long)); \
    *info = gbtrf_d(*m, *n, *kl, *ku, AB, *ldab, piv); \
    D2F(ab, *ldab, AB, *ldab, *n); \
    for (long i = 0; i < (*m < *n ? *m : *n); i++) ipiv[i] = (__CLPK_integer)piv[i] + 1; \
    free(AB); free(piv); return 0; \
} \
int p##gbtrs_(char *trans, __CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, \
              __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, __CLPK_integer *info) { \
    *info = 0; \
    if (!is(trans, 'N') && !is(trans, 'T') && !is(trans, 'C')) *info = -1; else if (*n < 0) *info = -2; \
    else if (*ldab < 2 * *kl + *ku + 1) *info = -7; else if (*ldb < (*n > 1 ? *n : 1)) *info = -10; \
    if (*info) return 0; \
    double *AB = F2D(ab, *ldab, *ldab, *n), *B = F2D(b, *ldb, *n, *nrhs); long *piv = calloc(*n > 0 ? *n : 1, sizeof(long)); \
    for (long i = 0; i < *n; i++) piv[i] = ipiv[i] - 1; \
    gbtrs_d(is(trans, 'N') ? 'N' : 'T', *n, *kl, *ku, *nrhs, AB, *ldab, piv, B, *ldb); \
    D2F(b, *ldb, B, *n, *nrhs); \
    free(AB); free(B); free(piv); return 0; \
} \
int p##gbsv_(__CLPK_integer *n, __CLPK_integer *kl, __CLPK_integer *ku, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, \
             __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, __CLPK_integer *info) { \
    *info = 0; \
    if (*n < 0) *info = -1; else if (*kl < 0) *info = -2; else if (*ku < 0) *info = -3; else if (*nrhs < 0) *info = -4; \
    else if (*ldab < 2 * *kl + *ku + 1) *info = -6; else if (*ldb < (*n > 1 ? *n : 1)) *info = -9; \
    if (*info) return 0; \
    p##gbtrf_(n, n, kl, ku, ab, ldab, ipiv, info); \
    if (*info == 0) p##gbtrs_("N", n, kl, ku, nrhs, ab, ldab, ipiv, b, ldb, info); \
    return 0; \
} \
int p##pbtrf_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, T *ab, __CLPK_integer *ldab, __CLPK_integer *info) { \
    *info = 0; \
    if (!is(uplo, 'U') && !is(uplo, 'L')) *info = -1; else if (*n < 0) *info = -2; else if (*kd < 0) *info = -3; \
    else if (*ldab < *kd + 1) *info = -5; \
    if (*info) return 0; \
    double *AB = F2D(ab, *ldab, *ldab, *n); \
    *info = pbtrf_d(up(uplo), *n, *kd, AB, *ldab); \
    D2F(ab, *ldab, AB, *ldab, *n); free(AB); return 0; \
} \
int p##pbtrs_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, T *b, __CLPK_integer *ldb, \
              __CLPK_integer *info) { \
    *info = 0; \
    if (!is(uplo, 'U') && !is(uplo, 'L')) *info = -1; else if (*n < 0) *info = -2; else if (*ldab < *kd + 1) *info = -6; \
    else if (*ldb < (*n > 1 ? *n : 1)) *info = -8; \
    if (*info) return 0; \
    double *AB = F2D(ab, *ldab, *ldab, *n), *B = F2D(b, *ldb, *n, *nrhs); \
    pbtrs_d(up(uplo), *n, *kd, *nrhs, AB, *ldab, B, *ldb); \
    D2F(b, *ldb, B, *n, *nrhs); free(AB); free(B); return 0; \
} \
int p##pbsv_(char *uplo, __CLPK_integer *n, __CLPK_integer *kd, __CLPK_integer *nrhs, T *ab, __CLPK_integer *ldab, T *b, __CLPK_integer *ldb, \
             __CLPK_integer *info) { \
    p##pbtrf_(uplo, n, kd, ab, ldab, info); \
    if (*info < 0) { if (*info == -5) *info = -6; return 0; } \
    if (*info == 0) p##pbtrs_(uplo, n, kd, nrhs, ab, ldab, b, ldb, info); \
    return 0; \
} \
int p##gtsv_(__CLPK_integer *n, __CLPK_integer *nrhs, T *dl, T *d, T *du, T *b, __CLPK_integer *ldb, __CLPK_integer *info) { \
    *info = 0; \
    if (*n < 0) *info = -1; else if (*nrhs < 0) *info = -2; else if (*ldb < (*n > 1 ? *n : 1)) *info = -7; \
    if (*info) return 0; \
    long N = *n; \
    double *DL = F2D(dl, N, N > 1 ? N - 1 : 0, 1), *D = F2D(d, N, N, 1), *DU = F2D(du, N, N > 1 ? N - 1 : 0, 1), *B = F2D(b, *ldb, N, *nrhs); \
    *info = (__CLPK_integer)gtsv_d(N, *nrhs, DL, D, DU, B, *ldb); \
    D2F(dl, N, DL, N > 1 ? N - 1 : 0, 1); D2F(d, N, D, N, 1); D2F(du, N, DU, N > 1 ? N - 1 : 0, 1); D2F(b, *ldb, B, N, *nrhs); \
    free(DL); free(D); free(DU); free(B); return 0; \
}
/* double: the conversions copy (so the shared code above works unchanged) */
static double *d2d(const double *a, long lda, long m, long n) {
    double *d = dalloc((size_t)(lda > 0 ? lda : 1) * (n > 0 ? n : 1));
    for (long j = 0; j < n; j++) for (long i = 0; i < m; i++) d[j * lda + i] = a[(size_t)j * lda + i];
    return d;
}
static void dd2(double *a, long lda, const double *d, long m, long n) {
    for (long j = 0; j < n; j++) for (long i = 0; i < m; i++) a[(size_t)j * lda + i] = d[j * lda + i];
}
BANDED(__CLPK_real, s, f2d, d2f)
BANDED(__CLPK_doublereal, d, d2d, dd2)
#undef BANDED

/* complex: c (float pairs) and z (double pairs) through double complex copies */
static zd *c2z(const void *a, int single, long lda, long m, long n) {
    zd *z = zalloc((size_t)(lda > 0 ? lda : 1) * (n > 0 ? n : 1));
    for (long j = 0; j < n; j++)
        for (long i = 0; i < m; i++) {
            size_t k = (size_t)j * lda + i;
            z[k] = single ? ((const float *)a)[2 * k] + ((const float *)a)[2 * k + 1] * (zd)1.0i
                          : ((const double *)a)[2 * k] + ((const double *)a)[2 * k + 1] * (zd)1.0i;
        }
    return z;
}
static void z2c(void *a, int single, long lda, const zd *z, long m, long n) {
    for (long j = 0; j < n; j++)
        for (long i = 0; i < m; i++) {
            size_t k = (size_t)j * lda + i;
            if (single) { ((float *)a)[2 * k] = (float)__builtin_creal(z[k]); ((float *)a)[2 * k + 1] = (float)__builtin_cimag(z[k]); }
            else { ((double *)a)[2 * k] = __builtin_creal(z[k]); ((double *)a)[2 * k + 1] = __builtin_cimag(z[k]); }
        }
}
#define COMPLEX(T, R, p, single) \
int p##getrf_(__CLPK_integer *m, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, __CLPK_integer *info) { \
    *info = 0; \
    if (*m < 0) *info = -1; else if (*n < 0) *info = -2; else if (*lda < (*m > 1 ? *m : 1)) *info = -4; \
    if (*info) return 0; \
    zd *A = c2z(a, single, *lda, *m, *n); long k = *m < *n ? *m : *n, *piv = calloc(k > 0 ? k : 1, sizeof(long)); \
    *info = (__CLPK_integer)zlu(*m, *n, A, *lda, piv); \
    z2c(a, single, *lda, A, *m, *n); \
    for (long i = 0; i < k; i++) ipiv[i] = (__CLPK_integer)piv[i] + 1; \
    free(A); free(piv); return 0; \
} \
int p##getrs_(char *trans, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, \
              __CLPK_integer *info) { \
    *info = 0; \
    if (!is(trans, 'N') && !is(trans, 'T') && !is(trans, 'C')) *info = -1; else if (*n < 0) *info = -2; else if (*nrhs < 0) *info = -3; \
    else if (*lda < (*n > 1 ? *n : 1)) *info = -5; else if (*ldb < (*n > 1 ? *n : 1)) *info = -8; \
    if (*info) return 0; \
    zd *A = c2z(a, single, *lda, *n, *n), *B = c2z(b, single, *ldb, *n, *nrhs); long *piv = calloc(*n > 0 ? *n : 1, sizeof(long)); \
    for (long i = 0; i < *n; i++) piv[i] = ipiv[i] - 1; \
    zlu_solve(*trans, *n, *nrhs, A, *lda, piv, B, *ldb); \
    z2c(b, single, *ldb, B, *n, *nrhs); free(A); free(B); free(piv); return 0; \
} \
int p##gesv_(__CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, __CLPK_integer *ipiv, T *b, __CLPK_integer *ldb, \
             __CLPK_integer *info) { \
    *info = 0; \
    if (*n < 0) *info = -1; else if (*nrhs < 0) *info = -2; else if (*lda < (*n > 1 ? *n : 1)) *info = -4; \
    else if (*ldb < (*n > 1 ? *n : 1)) *info = -7; \
    if (*info) return 0; \
    p##getrf_(n, n, a, lda, ipiv, info); \
    if (*info == 0) p##getrs_("N", n, nrhs, a, lda, ipiv, b, ldb, info); \
    return 0; \
} \
int p##potrf_(char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, __CLPK_integer *info) { \
    *info = 0; \
    if (!is(uplo, 'U') && !is(uplo, 'L')) *info = -1; else if (*n < 0) *info = -2; else if (*lda < (*n > 1 ? *n : 1)) *info = -4; \
    if (*info) return 0; \
    zd *A = c2z(a, single, *lda, *n, *n); \
    *info = (__CLPK_integer)zpotrf(up(uplo), *n, A, *lda); \
    z2c(a, single, *lda, A, *n, *n); free(A); return 0; \
} \
int p##potrs_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, __CLPK_integer *info) { \
    *info = 0; \
    if (!is(uplo, 'U') && !is(uplo, 'L')) *info = -1; else if (*n < 0) *info = -2; else if (*nrhs < 0) *info = -3; \
    else if (*lda < (*n > 1 ? *n : 1)) *info = -5; else if (*ldb < (*n > 1 ? *n : 1)) *info = -7; \
    if (*info) return 0; \
    zd *A = c2z(a, single, *lda, *n, *n), *B = c2z(b, single, *ldb, *n, *nrhs); \
    zpotrs(up(uplo), *n, *nrhs, A, *lda, B, *ldb); \
    z2c(b, single, *ldb, B, *n, *nrhs); free(A); free(B); return 0; \
} \
int p##posv_(char *uplo, __CLPK_integer *n, __CLPK_integer *nrhs, T *a, __CLPK_integer *lda, T *b, __CLPK_integer *ldb, __CLPK_integer *info) { \
    p##potrf_(uplo, n, a, lda, info); \
    if (*info < 0) { if (*info == -4) *info = -5; return 0; } \
    if (*info == 0) p##potrs_(uplo, n, nrhs, a, lda, b, ldb, info); \
    return 0; \
} \
int p##heev_(char *jobz, char *uplo, __CLPK_integer *n, T *a, __CLPK_integer *lda, R *w, T *work, __CLPK_integer *lwork, R *rwork, \
             __CLPK_integer *info) { \
    *info = 0; \
    if (!is(jobz, 'N') && !is(jobz, 'V')) *info = -1; else if (!is(uplo, 'U') && !is(uplo, 'L')) *info = -2; \
    else if (*n < 0) *info = -3; else if (*lda < (*n > 1 ? *n : 1)) *info = -5; \
    if (*info) return 0; \
    if (*lwork == -1) { ((R *)work)[0] = 2 * *n + 1; ((R *)work)[1] = 0; return 0; } \
    zd *A = c2z(a, single, *lda, *n, *n); double *W = dalloc(*n); \
    zheev(is(jobz, 'V'), up(uplo), *n, A, *lda, W); \
    for (long i = 0; i < *n; i++) w[i] = (R)W[i]; \
    if (is(jobz, 'V')) z2c(a, single, *lda, A, *n, *n); \
    free(A); free(W); return 0; \
}
COMPLEX(__CLPK_complex, __CLPK_real, c, 1)
COMPLEX(__CLPK_doublecomplex, __CLPK_doublereal, z, 0)
#undef COMPLEX
