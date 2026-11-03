/* isim Accelerate: Quadrature (issue #543), adapted. Each interval is integrated with the Gauss-Legendre rules of n and
   2n + 1 points (the "points per interval" rule has 2n + 1); the larger rule is the estimate, their difference the error
   estimate. QNG tries the rules of 15, 21, 31, 41, 51 and 61 points on the whole interval; QAG bisects the interval
   with the largest error until the total error meets the tolerance; QAGS does the same with a 21-point rule and is meant
   for integrable end-point singularities (the rules never evaluate the ends). Results agree with Apple's to the
   tolerances; error estimates are isim's. */
#include <Accelerate/Quadrature.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

/* the n-point Gauss-Legendre rule on [-1, 1] */
static void gauss_legendre(int n, double *x, double *w) {
    for (int i = 0; i < (n + 1) / 2; i++) {
        double z = cos(M_PI * (i + 0.75) / (n + 0.5)), dp = 1;
        for (int it = 0; it < 100; it++) {
            double p0 = 1, p1 = z;
            for (int k = 2; k <= n; k++) { double p2 = ((2 * k - 1) * z * p1 - (k - 1) * p0) / k; p0 = p1; p1 = p2; }
            if (n == 1) { p1 = z; p0 = 1; }
            dp = n * (z * p1 - p0) / (z * z - 1);
            double dz = p1 / dp;
            z -= dz;
            if (fabs(dz) < 1e-16) break;
        }
        double p0 = 1, p1 = z;
        for (int k = 2; k <= n; k++) { double p2 = ((2 * k - 1) * z * p1 - (k - 1) * p0) / k; p0 = p1; p1 = p2; }
        dp = n * (z * p1 - p0) / (z * z - 1);
        x[i] = -z; x[n - 1 - i] = z;
        w[i] = w[n - 1 - i] = 2 / ((1 - z * z) * dp * dp);
    }
    if (n == 1) { x[0] = 0; w[0] = 2; }
}

typedef struct { int n; double xa[31], wa[31], xb[63], wb[63]; } rule;   /* n and 2n + 1 points */

static void make_rule(rule *r, int points) {
    r->n = (points - 1) / 2;
    gauss_legendre(r->n, r->xa, r->wa);
    gauss_legendre(2 * r->n + 1, r->xb, r->wb);
}

/* integrates over [a, b]: returns the estimate, *err the error estimate; 0, or -1 when the function gives non-finite values */
static int apply(const quadrature_integrate_function *f, const rule *r, double a, double b, double *res, double *err) {
    int n = r->n, m = 2 * n + 1;
    double x[94], y[94], c = (a + b) / 2, h = (b - a) / 2;
    for (int i = 0; i < n; i++) x[i] = c + h * r->xa[i];
    for (int i = 0; i < m; i++) x[n + i] = c + h * r->xb[i];
    f->fun(f->fun_arg, (size_t)(n + m), x, y);
    double ga = 0, gb = 0;
    for (int i = 0; i < n; i++) ga += r->wa[i] * y[i];
    for (int i = 0; i < m; i++) gb += r->wb[i] * y[n + i];
    *res = h * gb; *err = fabs(h * (gb - ga));
    return isfinite(*res) ? 0 : -1;
}

static int valid_points(size_t p) { return p == 15 || p == 21 || p == 31 || p == 41 || p == 51 || p == 61; }

double quadrature_integrate(const quadrature_integrate_function *f, double a, double b, const quadrature_integrate_options *options,
                            quadrature_status *status, double *abs_error, size_t workspace_size, void *workspace) {
    (void)workspace_size; (void)workspace;
    quadrature_status st = QUADRATURE_SUCCESS;
    double result = 0, error = 0;
    if (!f || !f->fun || !options || !isfinite(a) || !isfinite(b) || options->abs_tolerance < 0 || options->rel_tolerance < 0) {
        st = QUADRATURE_INVALID_ARG_ERROR; goto done;
    }
    if (a == b) goto done;
    double sign = 1;
    if (a > b) { double t = a; a = b; b = t; sign = -1; }
    rule r;
    if (options->integrator == QUADRATURE_INTEGRATE_QNG) {
        static const int pts[] = {15, 21, 31, 41, 51, 61};
        st = QUADRATURE_INTEGRATE_MAX_EVAL_ERROR;
        for (int i = 0; i < 6; i++) {
            make_rule(&r, pts[i]);
            if (apply(f, &r, a, b, &result, &error)) { st = QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR; break; }
            if (error <= fmax(options->abs_tolerance, options->rel_tolerance * fabs(result))) { st = QUADRATURE_SUCCESS; break; }
        }
        result *= sign;
        goto done;
    }
    if (options->integrator != QUADRATURE_INTEGRATE_QAG && options->integrator != QUADRATURE_INTEGRATE_QAGS) { st = QUADRATURE_INVALID_ARG_ERROR; goto done; }
    size_t points = options->integrator == QUADRATURE_INTEGRATE_QAGS ? 21 : options->qag_points_per_interval;
    if (!valid_points(points) || options->max_intervals < 1) { st = QUADRATURE_INVALID_ARG_ERROR; goto done; }
    make_rule(&r, (int)points);
    size_t cap = options->max_intervals;
    double *iv = malloc(sizeof(double) * 4 * cap);               /* a, b, result, error */
    if (!iv) { st = QUADRATURE_ALLOC_ERROR; goto done; }
    size_t count = 1;
    iv[0] = a; iv[1] = b;
    if (apply(f, &r, a, b, &iv[2], &iv[3])) { free(iv); st = QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR; goto done; }
    for (;;) {
        result = 0; error = 0;
        size_t worst = 0;
        for (size_t i = 0; i < count; i++) {
            result += iv[4 * i + 2]; error += iv[4 * i + 3];
            if (iv[4 * i + 3] > iv[4 * worst + 3]) worst = i;
        }
        if (error <= fmax(options->abs_tolerance, options->rel_tolerance * fabs(result))) break;
        if (count >= cap) { st = QUADRATURE_INTEGRATE_MAX_EVAL_ERROR; break; }
        double lo = iv[4 * worst], hi = iv[4 * worst + 1], mid = (lo + hi) / 2;
        if (!(mid > lo && mid < hi)) { st = QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR; break; }   /* no more resolution */
        double *left = &iv[4 * worst], *right = &iv[4 * count];
        right[0] = mid; right[1] = hi;
        left[1] = mid;
        if (apply(f, &r, lo, mid, &left[2], &left[3]) || apply(f, &r, mid, hi, &right[2], &right[3])) {
            st = QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR; break;
        }
        count++;
    }
    free(iv);
    result *= sign;
done:
    if (status) *status = st;
    if (abs_error) *abs_error = error;
    return result;
}
