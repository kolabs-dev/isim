// isim Accelerate Sparse Solvers (issue #807): the iterative methods for one scalar type: conjugate gradients, GMRES
// (restarted GMRES and FGMRES, right-preconditioned; DQGMRES, truncated to nvec vectors), LSMR (Fong & Saunders,
// damped, right-preconditioned), the Diagonal and DiagScaling preconditioners, SparseSolve with a method and
// SparseIterate. Adapted: each method keeps its whole state (per right-hand side) in the state buffer, so SparseSolve
// is SparseIterate in a loop; LSMR's nvec (local reorthogonalization) is not used.
typedef void (^op_block)(bool, enum CBLAS_TRANSPOSE, DM, DM);
static const enum CBLAS_TRANSPOSE ADJ = CPLX ? CblasConjTrans : CblasTrans;

static DM vec_dm(T *v, int len) { DM d; memset(&d, 0, sizeof d); d.rowCount = len; d.columnCount = 1; d.columnStride = len; d.data = v; return d; }
static void apply_op(op_block op, enum CBLAS_TRANSPOSE t, T *x, int xl, T *y, int yl) { op(false, t, vec_dm(x, xl), vec_dm(y, yl)); }
static void apply_prec(const OP *P, enum CBLAS_TRANSPOSE t, T *x, T *y, int len) {
    if (P && P->apply && P->type != SparsePreconditionerNone) P->apply(P->mem, t, vec_dm(x, len), vec_dm(y, len));
    else if (x != y) memcpy(y, x, sizeof(T) * (size_t)len);
}
static R nrm2(const T *x, int n) { R s = 0; for (int i = 0; i < n; i++) { R a = ABSV(x[i]); s += a * a; } return SQRTR(s); }
static T dotc(const T *x, const T *y, int n) { T s = 0; for (int i = 0; i < n; i++) s += CONJ(x[i]) * y[i]; return s; }

/* ---- preconditioners ---- */
typedef struct { int n; T *d; } diag_prec;
static void diag_apply(void *mem, enum CBLAS_TRANSPOSE t, DM x, DM y) {
    diag_prec *p = mem;
    for (int c = 0; c < x.columnCount; c++) for (int i = 0; i < p->n; i++) *dm_at(y, i, c) = (t == CblasConjTrans ? CONJ(p->d[i]) : p->d[i]) * *dm_at(x, i, c);
}
typedef struct { T *d; } diag_acc;
static void diag_entry(void *ctx, int r, int c, T v) { diag_acc *a = ctx; if (r == c) a->d[r] += v; }
static void colnorm_entry(void *ctx, int r, int c, T v) { (void)r; diag_acc *a = ctx; R m = ABSV(v); a->d[c] += m * m; }
OP FN(_SparseCreatePreconditioner)(SparsePreconditioner_t type, SM A) {
    OP p; memset(&p, 0, sizeof p);
    p.type = type;
    if (type != SparsePreconditionerDiagonal && type != SparsePreconditionerDiagScaling) {
        if (type != SparsePreconditionerNone) sp_report(NULL, "SparseCreatePreconditioner: only Diagonal and DiagScaling are built in");
        p.type = SparsePreconditionerNone;
        return p;
    }
    int m, n; sm_dims(A, &m, &n);
    diag_prec *d = calloc(1, sizeof *d);
    if (d) d->d = calloc((size_t)(n ? n : 1), sizeof(T));
    if (!d || !d->d) { if (d) free(d); p.type = SparsePreconditionerNone; return p; }
    d->n = n;
    diag_acc acc = { d->d };
    if (type == SparsePreconditionerDiagonal) {
        sm_entries(A, diag_entry, &acc);
        for (int i = 0; i < n; i++) d->d[i] = is_zero(d->d[i]) ? (T)1 : (T)1 / d->d[i];
    } else {   /* DiagScaling: 1 / the 2-norm of each column (for LSMR) */
        sm_entries(A, colnorm_entry, &acc);
        for (int i = 0; i < n; i++) { R s = REALV(d->d[i]); d->d[i] = s > 0 ? (T)((R)1 / SQRTR(s)) : (T)1; }
    }
    p.mem = d; p.apply = diag_apply;
    return p;
}
void FN(_SparseCleanupPreconditioner)(OP P) {
    if (P.apply == diag_apply && P.mem) { free(((diag_prec *)P.mem)->d); free(P.mem); }
}

/* ---- the state ---- */
typedef struct {
    int done, j, itn, istop;
    R beta, resid, normb;
    T rz, gamma;
    /* LSMR */
    R alpha, alphabar, rho, rhobar, cbar, sbar, zetabar, zeta, betadd, betad, rhodold, tautildeold, thetatilde, d, normA2,
      maxrbar, minrbar, normr, normar, condA, normx;
} col_state;
typedef struct { int magic, method, variant, nvec, m, n, nrhs, prec; long colsize; } it_head;
#define IT_MAGIC 0x53505253
static int it_method(SparseIterativeMethod me) { return me.method; }
static int it_nvec(SparseIterativeMethod me) {
    int v = me.method == 1 ? me.options.gmres.nvec : 0;
    return v > 0 ? v : 16;
}
/* vectors per right-hand side, in T units */
static long col_vectors(SparseIterativeMethod me, int m, int n) {
    long L = m > n ? m : n, k = it_nvec(me);
    switch (it_method(me)) {
    case 0: return 4 * L;
    case 1: return (k + 1) * L + k * L + (k + 1) * (k + 2) + 4 * (k + 2) + 3 * L;
    default: return 6 * L;
    }
}
size_t FN(SparseGetStateSize)(SparseIterativeMethod method, bool preconditioner, int m, int n, int nrhs) {
    (void)preconditioner;
    long per = sizeof(col_state) + sizeof(T) * col_vectors(method, m, n) + 16;
    return sizeof(it_head) + 16 + (size_t)per * (size_t)(nrhs > 0 ? nrhs : 1);
}
static col_state *col_of(void *state, int c, T **vec) {
    it_head *h = state;
    char *base = (char *)state + ((sizeof(it_head) + 15) & ~(size_t)15) + (size_t)c * (size_t)h->colsize;
    col_state *s = (col_state *)base;
    *vec = (T *)(base + ((sizeof(col_state) + 15) & ~(size_t)15));
    return s;
}

static R tol_of(SparseIterativeMethod me) {
    R rtol = it_method(me) == 0 ? (R)me.options.cg.rtol : it_method(me) == 1 ? (R)me.options.gmres.rtol : (R)me.options.lsmr.rtol;
    return rtol > 0 ? rtol : SQRTR(EPS);
}
static R atol_of(SparseIterativeMethod me) {
    return it_method(me) == 0 ? (R)me.options.cg.atol : it_method(me) == 1 ? (R)me.options.gmres.atol : (R)me.options.lsmr.atol;
}
static void report_status(SparseIterativeMethod me, const char *fmt, int it, double v) {
    void (*rs)(const char *) = it_method(me) == 0 ? me.options.cg.reportStatus : it_method(me) == 1 ? me.options.gmres.reportStatus : me.options.lsmr.reportStatus;
    if (!rs) return;
    char msg[160]; snprintf(msg, sizeof msg, fmt, it, v); rs(msg);
}
static void report_error(SparseIterativeMethod me, const char *msg) {
    void (*re)(const char *) = it_method(me) == 0 ? me.options.cg.reportError : it_method(me) == 1 ? me.options.gmres.reportError : me.options.lsmr.reportError;
    sp_report(re, "%s", msg);
}

/* complex Givens: [c s; -conj(s) c] [a; b] = [r; 0] */
static void givens(T a, T b, R *c, T *s) {
    R aa = ABSV(a), ab = ABSV(b);
    if (ab == 0) { *c = 1; *s = 0; return; }
    if (aa == 0) { *c = 0; *s = CONJ(b) / ab; return; }
    R r = SQRTR(aa * aa + ab * ab);
    *c = aa / r; *s = (a / aa) * CONJ(b) / r;
}
static void rot(R c, T s, T *a, T *b) { T x = *a, y = *b; *a = c * x + s * y; *b = -CONJ(s) * x + c * y; }
static void sym_ortho(R a, R b, R *c, R *s, R *r) {
    if (b == 0) { *c = a < 0 ? -1 : 1; *s = 0; *r = a < 0 ? -a : a; }
    else if (a == 0) { *c = 0; *s = b < 0 ? -1 : 1; *r = b < 0 ? -b : b; }
    else if ((b < 0 ? -b : b) > (a < 0 ? -a : a)) { R t = a / b; *s = (b < 0 ? -1 : 1) / SQRTR(1 + t * t); *c = *s * t; *r = b / *s; }
    else { R t = b / a; *c = (a < 0 ? -1 : 1) / SQRTR(1 + t * t); *s = *c * t; *r = a / *c; }
}

/* per method, per column; b: m, x: n */
static void cg_init(col_state *s, T *v, op_block op, const OP *P, const T *b, T *x, int n) {
    T *r = v, *z = v + n, *p = v + 2 * n;
    apply_op(op, CblasNoTrans, x, n, r, n);
    for (int i = 0; i < n; i++) r[i] = b[i] - r[i];
    apply_prec(P, CblasNoTrans, r, z, n);
    memcpy(p, z, sizeof(T) * (size_t)n);
    s->rz = dotc(r, z, n); s->resid = nrm2(r, n); s->normb = nrm2(b, n);
}
static void cg_step(col_state *s, T *v, op_block op, const OP *P, T *x, int n) {
    T *r = v, *z = v + n, *p = v + 2 * n, *q = v + 3 * n;
    apply_op(op, CblasNoTrans, p, n, q, n);
    T pq = dotc(p, q, n);
    if (is_zero(pq)) { s->done = 1; return; }
    T alpha = s->rz / pq;
    for (int i = 0; i < n; i++) { x[i] += alpha * p[i]; r[i] -= alpha * q[i]; }
    apply_prec(P, CblasNoTrans, r, z, n);
    T rz = dotc(r, z, n), beta = is_zero(s->rz) ? (T)0 : rz / s->rz;
    for (int i = 0; i < n; i++) p[i] = z[i] + beta * p[i];
    s->rz = rz; s->resid = nrm2(r, n); s->itn++;
}

/* GMRES / FGMRES: V (k+1) x n, Z k x n, H (k+1) x k, c, s, g; restarted after k steps */
#define G_V(i) (v + (long)(i) * n)
#define G_Z(i) (v + (long)(k + 1) * n + (long)(i) * n)
#define G_H(i, j) (v[(long)(2 * k + 1) * n + (long)(j) * (k + 1) + (i)])
#define G_C(i) (v[(long)(2 * k + 1) * n + (long)(k + 1) * (k + 2) + (i)])
#define G_S(i) (v[(long)(2 * k + 1) * n + (long)(k + 1) * (k + 2) + (k + 2) + (i)])
#define G_G(i) (v[(long)(2 * k + 1) * n + (long)(k + 1) * (k + 2) + 2 * (k + 2) + (i)])
#define G_W (v + (long)(2 * k + 1) * n + (long)(k + 1) * (k + 2) + 4 * (k + 2))
static void gm_restart(col_state *s, T *v, int k, op_block op, const T *b, const T *x, int n) {
    T *w = G_W;
    apply_op(op, CblasNoTrans, (T *)x, n, w, n);
    for (int i = 0; i < n; i++) w[i] = b[i] - w[i];
    s->beta = nrm2(w, n); s->resid = s->beta; s->j = 0;
    for (int i = 0; i <= k; i++) G_G(i) = 0;
    G_G(0) = s->beta;
    if (s->beta > 0) for (int i = 0; i < n; i++) G_V(0)[i] = w[i] / s->beta;
}
/* x += Z y with H(0:j,0:j) y = g(0:j); into x (commit) or into out */
static void gm_update(col_state *s, T *v, int k, const T *x, T *out, int n) {
    int j = s->j;
    T y[j > 0 ? j : 1];
    for (int i = j - 1; i >= 0; i--) {
        T t = G_G(i);
        for (int l = i + 1; l < j; l++) t -= G_H(i, l) * y[l];
        y[i] = is_zero(G_H(i, i)) ? (T)0 : t / G_H(i, i);
    }
    if (out != x) memcpy(out, x, sizeof(T) * (size_t)n);
    for (int l = 0; l < j; l++) for (int i = 0; i < n; i++) out[i] += y[l] * G_Z(l)[i];
}
static void gm_step(col_state *s, T *v, int k, op_block op, const OP *P, const T *b, T *x, int n) {
    int j = s->j;
    if (s->beta == 0) { s->done = 1; return; }
    T *w = G_W;
    apply_prec(P, CblasNoTrans, G_V(j), G_Z(j), n);
    apply_op(op, CblasNoTrans, G_Z(j), n, w, n);
    for (int i = 0; i <= j; i++) { T h = dotc(G_V(i), w, n); G_H(i, j) = h; for (int l = 0; l < n; l++) w[l] -= h * G_V(i)[l]; }
    R hn = nrm2(w, n);
    G_H(j + 1, j) = hn;
    if (hn > 0) for (int l = 0; l < n; l++) G_V(j + 1)[l] = w[l] / hn;
    for (int i = 0; i < j; i++) { T ci = G_C(i); rot(REALV(ci), G_S(i), &G_H(i, j), &G_H(i + 1, j)); }
    R c; T sn;
    givens(G_H(j, j), G_H(j + 1, j), &c, &sn);
    G_C(j) = c; G_S(j) = sn;
    rot(c, sn, &G_H(j, j), &G_H(j + 1, j));
    rot(c, sn, &G_G(j), &G_G(j + 1));
    s->resid = ABSV(G_G(j + 1));
    s->j = j + 1; s->itn++;
    if (s->j == k || hn == 0) {   /* the Krylov space is full (or exact): commit and restart */
        gm_update(s, v, k, x, x, n);
        gm_restart(s, v, k, op, b, x, n);
    }
}
/* DQGMRES: windows of k + 1 basis vectors and k directions, ring-indexed by step */
#define Q_V(i) (v + (long)((i) % (k + 1)) * n)
#define Q_P(i) (v + (long)(k + 1) * n + (long)((i) % k) * n)
#define Q_C(i) (v[(long)(2 * k + 1) * n + ((i) % (k + 1))])
#define Q_S(i) (v[(long)(2 * k + 1) * n + (k + 1) + ((i) % (k + 1))])
#define Q_H(o) (v[(long)(2 * k + 1) * n + 2 * (k + 1) + (o)])
#define Q_W (v + (long)(2 * k + 1) * n + 2 * (k + 1) + (k + 2))
#define Q_Z (Q_W + n)
static void dq_init(col_state *s, T *v, int k, op_block op, const T *b, const T *x, int n) {
    T *w = Q_W;
    apply_op(op, CblasNoTrans, (T *)x, n, w, n);
    for (int i = 0; i < n; i++) w[i] = b[i] - w[i];
    s->beta = nrm2(w, n); s->resid = s->beta; s->gamma = s->beta; s->j = 0;
    if (s->beta > 0) for (int i = 0; i < n; i++) Q_V(0)[i] = w[i] / s->beta;
}
static void dq_step(col_state *s, T *v, int k, op_block op, const OP *P, T *x, int n) {
    int m = s->j;
    if (s->beta == 0) { s->done = 1; return; }
    T *w = Q_W, *z = Q_Z;
    int lo = m - k + 1 > 0 ? m - k + 1 : 0, rlo = m - k > 0 ? m - k : 0;
    apply_prec(P, CblasNoTrans, Q_V(m), z, n);
    apply_op(op, CblasNoTrans, z, n, w, n);
    for (int o = 0; o < k + 2; o++) Q_H(o) = 0;   /* Q_H(i - rlo) = h(i, m) */
    for (int i = lo; i <= m; i++) { T h = dotc(Q_V(i), w, n); Q_H(i - rlo) = h; for (int l = 0; l < n; l++) w[l] -= h * Q_V(i)[l]; }
    R hn = nrm2(w, n);
    Q_H(m + 1 - rlo) = hn;
    if (hn > 0) for (int l = 0; l < n; l++) Q_V(m + 1)[l] = w[l] / hn;
    for (int i = rlo; i < m; i++) rot(REALV(Q_C(i)), Q_S(i), &Q_H(i - rlo), &Q_H(i + 1 - rlo));
    R c; T sn;
    givens(Q_H(m - rlo), Q_H(m + 1 - rlo), &c, &sn);
    Q_C(m) = c; Q_S(m) = sn;
    rot(c, sn, &Q_H(m - rlo), &Q_H(m + 1 - rlo));
    T gm = s->gamma, g_next = -CONJ(sn) * gm;
    gm = c * gm;
    /* p_m = (z - sum h(i,m) p_i) / h(m,m) */
    T *pm = Q_P(m);
    T hmm = Q_H(m - rlo);
    for (int l = 0; l < n; l++) w[l] = z[l];
    for (int i = rlo; i < m; i++) { T h = Q_H(i - rlo); if (!is_zero(h)) for (int l = 0; l < n; l++) w[l] -= h * Q_P(i)[l]; }
    if (!is_zero(hmm)) for (int l = 0; l < n; l++) { pm[l] = w[l] / hmm; x[l] += gm * pm[l]; }
    s->gamma = g_next; s->resid = ABSV(g_next); s->j = m + 1; s->itn++;
    if (hn == 0) s->done = 1;
}
/* LSMR on A M (M: a right preconditioner), y internal, x = M y */
#define L_U v
#define L_V (v + L)
#define L_H (v + 2 * L)
#define L_HB (v + 3 * L)
#define L_Y (v + 4 * L)
#define L_T (v + 5 * L)
static void lsmr_op(op_block op, const OP *P, int adjoint, T *in, T *out, T *tmp, int m, int n) {
    if (!adjoint) { apply_prec(P, CblasNoTrans, in, tmp, n); apply_op(op, CblasNoTrans, tmp, n, out, m); }
    else { apply_op(op, ADJ, in, m, tmp, n); apply_prec(P, ADJ, tmp, out, n); }
}
static void lsmr_init(col_state *s, T *v, long L, op_block op, const OP *P, const T *b, T *x, int m, int n) {
    T *u = L_U, *vv = L_V, *h = L_H, *hb = L_HB, *y = L_Y, *t = L_T;
    /* y0 = M^-1 x0 for a diagonal preconditioner; otherwise start from 0 */
    int diag = P && P->apply == diag_apply;
    for (int i = 0; i < n; i++) y[i] = diag ? x[i] / ((diag_prec *)P->mem)->d[i] : (T)0;
    if (!diag) for (int i = 0; i < n; i++) x[i] = 0;
    lsmr_op(op, P, 0, y, u, t, m, n);
    for (int i = 0; i < m; i++) u[i] = b[i] - u[i];
    s->normb = nrm2(b, m);
    R beta = nrm2(u, m);
    if (beta > 0) for (int i = 0; i < m; i++) u[i] /= beta;
    lsmr_op(op, P, 1, u, vv, t, m, n);
    R alpha = nrm2(vv, n);
    if (alpha > 0) for (int i = 0; i < n; i++) vv[i] /= alpha;
    s->beta = beta; s->alpha = alpha;
    s->zetabar = alpha * beta; s->alphabar = alpha; s->rho = 1; s->rhobar = 1; s->cbar = 1; s->sbar = 0;
    memcpy(h, vv, sizeof(T) * (size_t)n);
    for (int i = 0; i < n; i++) hb[i] = 0;
    s->betadd = beta; s->betad = 0; s->rhodold = 1; s->tautildeold = 0; s->thetatilde = 0; s->zeta = 0; s->d = 0;
    s->normA2 = alpha * alpha; s->maxrbar = 0; s->minrbar = (R)1e30; s->normr = beta; s->normar = alpha * beta; s->condA = 1; s->normx = 0;
    s->resid = beta; s->itn = 0; s->istop = 0;
    if (s->normar == 0) s->done = 1;
}
static void lsmr_step(col_state *s, T *v, long L, op_block op, const OP *P, R damp, T *x, int m, int n) {
    T *u = L_U, *vv = L_V, *h = L_H, *hb = L_HB, *y = L_Y, *t = L_T;
    s->itn++;
    /* u = A M v - alpha u */
    T *av = malloc(sizeof(T) * (size_t)(m > n ? m : n) + sizeof(T));
    T *tmp = malloc(sizeof(T) * (size_t)(m > n ? m : n) + sizeof(T));
    if (!av || !tmp) { free(av); free(tmp); s->done = 1; return; }
    lsmr_op(op, P, 0, vv, av, tmp, m, n);
    for (int i = 0; i < m; i++) u[i] = av[i] - s->alpha * u[i];
    R beta = nrm2(u, m);
    if (beta > 0) {
        for (int i = 0; i < m; i++) u[i] /= beta;
        lsmr_op(op, P, 1, u, av, tmp, m, n);
        for (int i = 0; i < n; i++) vv[i] = av[i] - beta * vv[i];
        s->alpha = nrm2(vv, n);
        if (s->alpha > 0) for (int i = 0; i < n; i++) vv[i] /= s->alpha;
    }
    free(av); free(tmp);
    R alpha = s->alpha, chat, shat, alphahat, c, sn, rho, rhoold = s->rho;
    sym_ortho(s->alphabar, damp, &chat, &shat, &alphahat);
    sym_ortho(alphahat, beta, &c, &sn, &rho);
    s->rho = rho;
    R thetanew = sn * alpha;
    s->alphabar = c * alpha;
    R rhobarold = s->rhobar, zetaold = s->zeta, thetabar = s->sbar * rho, rhotemp = s->cbar * rho;
    R cbar, sbar, rhobar;
    sym_ortho(s->cbar * rho, thetanew, &cbar, &sbar, &rhobar);
    s->cbar = cbar; s->sbar = sbar; s->rhobar = rhobar;
    s->zeta = cbar * s->zetabar;
    s->zetabar = -sbar * s->zetabar;
    R f1 = thetabar * rho / (rhoold * rhobarold), f2 = s->zeta / (rho * rhobar), f3 = thetanew / rho;
    for (int i = 0; i < n; i++) { hb[i] = h[i] - f1 * hb[i]; y[i] += f2 * hb[i]; h[i] = vv[i] - f3 * h[i]; }
    /* estimates of |r|, |A' r|, |A|, cond(A) */
    R betaacute = chat * s->betadd, betacheck = -shat * s->betadd, betahat = c * betaacute;
    s->betadd = -sn * betaacute;
    R thetatildeold = s->thetatilde, ctildeold, stildeold, rhotildeold;
    sym_ortho(s->rhodold, thetabar, &ctildeold, &stildeold, &rhotildeold);
    s->thetatilde = stildeold * rhobar;
    s->rhodold = ctildeold * rhobar;
    s->betad = -stildeold * s->betad + ctildeold * betahat;
    s->tautildeold = (zetaold - thetatildeold * s->tautildeold) / rhotildeold;
    R taud = (s->zeta - s->thetatilde * s->tautildeold) / s->rhodold;
    s->d += betacheck * betacheck;
    R dd = s->betad - taud;
    s->normr = SQRTR(s->d + dd * dd + s->betadd * s->betadd);
    s->normA2 += beta * beta;
    R normA = SQRTR(s->normA2);
    s->normA2 += alpha * alpha;
    if (rhobarold > s->maxrbar) s->maxrbar = rhobarold;
    if (s->itn > 1 && rhobarold < s->minrbar) s->minrbar = rhobarold;
    R mx = s->maxrbar > rhotemp ? s->maxrbar : rhotemp, mn = s->minrbar < rhotemp ? s->minrbar : rhotemp;
    s->condA = mn > 0 ? mx / mn : (R)1e30;
    s->normar = s->zetabar < 0 ? -s->zetabar : s->zetabar;
    /* x = M y */
    apply_prec(P, CblasNoTrans, y, x, n);
    s->normx = nrm2(x, n);
    s->resid = s->normr;
    (void)normA; (void)t;
}
static void lsmr_tests(col_state *s, SparseIterativeMethod me) {
    R atol = me.options.lsmr.atol > 0 ? (R)me.options.lsmr.atol : SQRTR(EPS);
    R btol = me.options.lsmr.btol > 0 ? (R)me.options.lsmr.btol : SQRTR(EPS);
    R conlim = me.options.lsmr.conditionLimit > 0 ? (R)me.options.lsmr.conditionLimit : (R)1 / (10 * SQRTR(EPS));
    R normA = SQRTR(s->normA2);
    R test1 = s->normb > 0 ? s->normr / s->normb : 0;
    R test2 = normA * s->normr > 0 ? s->normar / (normA * s->normr) : 0;
    R test3 = 1 / s->condA;
    R rtol = btol + (s->normb > 0 ? atol * normA * s->normx / s->normb : 0);
    if (s->normr == 0 || s->normar == 0) s->istop = 1;
    else if (test3 <= 1 / conlim) s->istop = 3;
    else if (test2 <= atol) s->istop = 2;
    else if (test1 <= rtol) s->istop = 1;
    if (s->istop) s->done = 1;
}

/* ---- SparseIterate ---- */
static int it_check(SparseIterativeMethod me, DM B, DM Xm, int *m, int *n) {
    *m = B.rowCount; *n = Xm.rowCount;
    if (B.columnCount != Xm.columnCount || B.columnCount < 1) { report_error(me, "SparseSolve: B and X have different numbers of columns"); return 0; }
    if (it_method(me) != 2 && *m != *n) { report_error(me, "SparseSolve: CG and GMRES need a square system"); return 0; }
    if (it_method(me) < 0 || it_method(me) > 2) { report_error(me, "SparseSolve: unknown iterative method"); return 0; }
    return 1;
}
static void col_init(SparseIterativeMethod me, void *state, int c, op_block op, const OP *P, DM B, DM Xm, int m, int n) {
    T *v; col_state *s = col_of(state, c, &v);
    memset(s, 0, sizeof *s);
    T *b = dm_at(B, 0, c), *x = dm_at(Xm, 0, c);
    int k = it_nvec(me);
    long L = m > n ? m : n;
    switch (it_method(me)) {
    case 0: cg_init(s, v, op, P, b, x, n); break;
    case 1:
        if (me.options.gmres.variant == SparseVariantDQGMRES) dq_init(s, v, k, op, b, x, n);
        else gm_restart(s, v, k, op, b, x, n);
        s->normb = nrm2(b, m);
        break;
    default: lsmr_init(s, v, L, op, P, b, x, m, n); break;
    }
}
static void col_step(SparseIterativeMethod me, void *state, int c, op_block op, const OP *P, DM B, DM Xm, int m, int n) {
    T *v; col_state *s = col_of(state, c, &v);
    if (s->done) return;
    T *b = dm_at(B, 0, c), *x = dm_at(Xm, 0, c);
    int k = it_nvec(me);
    long L = m > n ? m : n;
    switch (it_method(me)) {
    case 0: cg_step(s, v, op, P, x, n); break;
    case 1:
        if (me.options.gmres.variant == SparseVariantDQGMRES) dq_step(s, v, k, op, P, x, n);
        else gm_step(s, v, k, op, P, b, x, n);
        break;
    default: lsmr_step(s, v, L, op, P, (R)me.options.lsmr.lambda, x, m, n); lsmr_tests(s, me); break;
    }
}
static void col_finalize(SparseIterativeMethod me, void *state, int c, DM Xm, int n) {
    T *v; col_state *s = col_of(state, c, &v);
    int k = it_nvec(me);
    if (it_method(me) == 1 && me.options.gmres.variant != SparseVariantDQGMRES && s->j > 0) {
        T *x = dm_at(Xm, 0, c);
        gm_update(s, v, k, x, x, n);
        s->j = 0;
    }
}
/* the residual b - A x of the current iterate (GMRES's x includes its uncommitted Krylov correction) */
static void col_residual(SparseIterativeMethod me, void *state, int c, op_block op, DM B, DM Xm, DM Rm, int m, int n) {
    T *v; col_state *s = col_of(state, c, &v);
    int k = it_nvec(me);
    T *x = dm_at(Xm, 0, c), *b = dm_at(B, 0, c);
    T *xt = malloc(sizeof(T) * (size_t)(n ? n : 1)), *r = malloc(sizeof(T) * (size_t)(m ? m : 1));
    if (!xt || !r) { free(xt); free(r); return; }
    if (it_method(me) == 1 && me.options.gmres.variant != SparseVariantDQGMRES && s->j > 0) gm_update(s, v, k, x, xt, n);
    else memcpy(xt, x, sizeof(T) * (size_t)n);
    apply_op(op, CblasNoTrans, xt, n, r, m);
    for (int i = 0; i < m; i++) *dm_at(Rm, i, c) = b[i] - r[i];
    free(xt); free(r);
}
void FN(_SparseIterate)(SparseIterativeMethod method, int iteration, const bool *converged, void *state, op_block op,
                        DM B, DM Rm, DM Xm, const OP *P) {
    int m, n;
    if (!state || !it_check(method, B, Xm, &m, &n)) return;
    it_head *h = state;
    if (iteration == 0) {
        h->magic = IT_MAGIC; h->method = it_method(method); h->nvec = it_nvec(method); h->m = m; h->n = n; h->nrhs = B.columnCount; h->prec = P != NULL;
        h->colsize = (long)(((sizeof(col_state) + 15) & ~(size_t)15) + sizeof(T) * (size_t)col_vectors(method, m, n) + 15) & ~15L;
        for (int c = 0; c < B.columnCount; c++) col_init(method, state, c, op, P, B, Xm, m, n);
        for (int c = 0; c < B.columnCount; c++) col_residual(method, state, c, op, B, Xm, Rm, m, n);
        return;
    }
    if (h->magic != IT_MAGIC || h->nrhs != B.columnCount || h->m != m || h->n != n) { report_error(method, "SparseIterate: the state was not initialized for this system"); return; }
    if (iteration < 0) { for (int c = 0; c < B.columnCount; c++) col_finalize(method, state, c, Xm, n); return; }
    for (int c = 0; c < B.columnCount; c++) {
        if (converged && converged[c]) continue;
        col_step(method, state, c, op, P, B, Xm, m, n);
        col_residual(method, state, c, op, B, Xm, Rm, m, n);
    }
}

/* ---- SparseSolve with a method ---- */
SparseIterativeStatus_t FN(_SparseSolveIterative)(SparseIterativeMethod method, op_block op, DM B, DM Xm, const OP *P) {
    int m, n;
    if (!it_check(method, B, Xm, &m, &n)) return SparseIterativeParameterError;
    size_t sz = FN(SparseGetStateSize)(method, P != NULL, m, n, B.columnCount);
    void *state = calloc(1, sz);
    if (!state) return SparseIterativeInternalError;
    it_head *h = state;
    h->magic = IT_MAGIC; h->method = it_method(method); h->nvec = it_nvec(method); h->m = m; h->n = n; h->nrhs = B.columnCount;
    h->colsize = (long)(((sizeof(col_state) + 15) & ~(size_t)15) + sizeof(T) * (size_t)col_vectors(method, m, n) + 15) & ~15L;
    int maxit = it_method(method) == 0 ? method.options.cg.maxIterations : it_method(method) == 1 ? method.options.gmres.maxIterations : method.options.lsmr.maxIterations;
    if (maxit <= 0) maxit = it_method(method) == 2 ? (4 * (m < n ? m : n) > 100 ? 4 * (m < n ? m : n) : 100) : (n > 100 ? n : 100);
    R rtol = tol_of(method), atol = atol_of(method);
    SparseIterativeStatus_t status = SparseIterativeConverged;
    for (int c = 0; c < B.columnCount; c++) {
        col_init(method, state, c, op, P, B, Xm, m, n);
        T *v; col_state *s = col_of(state, c, &v);
        R target = atol > rtol * s->normb ? atol : rtol * s->normb;
        int it = 0;
        while (1) {
            int conv = it_method(method) == 2 ? s->done && s->istop != 3 : (s->resid <= target || s->done);
            if (it_method(method) == 2 && s->istop == 3) { status = SparseIterativeIllConditioned; break; }
            if (conv) break;
            if (it >= maxit) { if (status == SparseIterativeConverged) status = SparseIterativeMaxIterations; break; }
            col_step(method, state, c, op, P, B, Xm, m, n);
            it++;
            report_status(method, "iteration %d: residual %g", it, (double)s->resid);
            if (it_method(method) == 1 && method.options.gmres.variant != SparseVariantDQGMRES && s->resid <= target) break;
        }
        col_finalize(method, state, c, Xm, n);
    }
    free(state);
    return status;
}
