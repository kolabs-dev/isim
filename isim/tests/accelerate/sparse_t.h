// Sparse Solvers from C (issue #807) for one scalar type (X, T, R, CPLX, ABSV, CONJ, MK set by sparse.c): matrices
// from coordinates, products, every direct factorization with its solve, subfactors, refactoring, the iterative
// methods and SparseIterate, checked against solutions worked out from dense arithmetic.
#define S_CAT_(a, b) a##_##b
#define S_CAT(a, b) S_CAT_(a, b)
#define S_CAT2_(a, b) a##b
#define S_CAT2(a, b) S_CAT2_(a, b)
#define TN(name) S_CAT(name, X)
#define DMx S_CAT(DenseMatrix, X)
#define DVx S_CAT(DenseVector, X)
#define SMx S_CAT(SparseMatrix, X)
#define OFx S_CAT(SparseOpaqueFactorization, X)
#define OSx S_CAT(SparseOpaqueSubfactor, X)

static R TN(err)(const T *a, const T *b, int n) { R e = 0; for (int i = 0; i < n; i++) { R d = ABSV(a[i] - b[i]); if (d > e) e = d; } return e; }
/* y = A x for a dense column-major m x n matrix */
static void TN(dgemv)(const T *A, int m, int n, const T *x, T *y) { for (int i = 0; i < m; i++) { T s = 0; for (int j = 0; j < n; j++) s += A[j * m + i] * x[j]; y[i] = s; } }
static DMx TN(dm)(T *data, int rows, int cols) { DMx d; memset(&d, 0, sizeof d); d.rowCount = rows; d.columnCount = cols; d.columnStride = rows; d.data = data; return d; }
/* a sparse matrix of the nonzeros of a dense one (lower triangle only when kind is symmetric / Hermitian) */
static SMx TN(sparse_of)(const T *A, int m, int n, int kind) {
    int rows[64], cols[64]; T vals[64]; long k = 0;
    for (int j = 0; j < n; j++) for (int i = 0; i < m; i++) {
        if (kind != SparseOrdinary && i < j) continue;
        if (A[j * m + i] != (T)0) { rows[k] = i; cols[k] = j; vals[k] = A[j * m + i]; k++; }
    }
    S_CAT2(Sparse, ATTRT) at; memset(&at, 0, sizeof at);
    at.kind = kind; at.triangle = SparseLowerTriangle;
    return SparseConvertFromCoordinate(m, n, k, 1, at, rows, cols, vals);
}

static void TN(sparse_tests)(int *checks, int *failures, const char *ty, R tol) {
    char what[160];
    #define C(cond, fmt) do { snprintf(what, sizeof what, "Sparse %s: " fmt, ty); CHECK(cond, what); } while (0)
    /* a symmetric (Hermitian) positive definite 5 x 5 matrix */
    T spd[25] = { 0 };
    for (int i = 0; i < 5; i++) spd[i * 5 + i] = 4;
    int off[][2] = { { 1, 0 }, { 2, 1 }, { 3, 2 }, { 4, 3 }, { 4, 0 } };
    for (int k = 0; k < 5; k++) { int i = off[k][0], j = off[k][1]; T v = MK(1, 0.5 * (k + 1)); spd[j * 5 + i] = v; spd[i * 5 + j] = CONJ(v); }
    T xt[6] = { MK(1, 0), MK(2, -1), MK(3, 0.5), MK(4, 0), MK(5, 2), MK(-1, 1) }, b[6], x[6];
    TN(dgemv)(spd, 5, 5, xt, b);
    SMx A = TN(sparse_of)(spd, 5, 5, CPLX ? 4 : SparseSymmetric);
    T y[5];
    SparseMultiply(A, (DVx){ 5, xt }, (DVx){ 5, y });
    C(TN(err)(y, b, 5) < tol * 10, "SparseConvertFromCoordinate (one triangle), SparseMultiply");
    SparseMultiplyAdd(A, (DVx){ 5, xt }, (DVx){ 5, y });
    { T b2[5]; for (int i = 0; i < 5; i++) b2[i] = b[i] + b[i]; C(TN(err)(y, b2, 5) < tol * 20, "SparseMultiplyAdd"); }
    const SparseFactorization_t symtypes[] = { SparseFactorizationCholesky, SparseFactorizationLDLT, SparseFactorizationLDLTUnpivoted,
                                              SparseFactorizationLDLTSBK, SparseFactorizationLDLTTPP };
    const char *symnames[] = { "Cholesky", "LDLT", "LDLTUnpivoted", "LDLTSBK", "LDLTTPP" };
    for (int t = 0; t < 5; t++) {
        OFx F = SparseFactor(symtypes[t], A);
        memcpy(x, b, sizeof(T) * 5);
        if (F.status == SparseStatusOK) SparseSolve(F, (DVx){ 5, x });
        snprintf(what, sizeof what, "Sparse %s: SparseFactor(%s) and SparseSolve in place", ty, symnames[t]);
        CHECK(F.status == SparseStatusOK && TN(err)(x, xt, 5) < tol * 100, what);
        SparseCleanup(F);
    }
    /* the symbolic / numeric split, refactoring, subfactors and inertia */
    {
        SparseOpaqueSymbolicFactorization sym = SparseFactor(SparseFactorizationLDLT, A.structure);
        OFx F = SparseFactor(sym, A);
        SparseSolve(F, (DVx){ 5, b }, (DVx){ 5, x });
        C(sym.status == SparseStatusOK && F.status == SparseStatusOK && TN(err)(x, xt, 5) < tol * 100, "SparseFactor(symbolic) then SparseFactor(symbolic, A)");
        int z = -1, ng = -1, ps = -1;
        C(SparseGetInertia(F, &z, &ng, &ps) == 0 && z == 0 && ng == 0 && ps == 5, "SparseGetInertia: positive definite");
        /* A = PLPS D PLPS^H */
        OSx plps = SparseCreateSubfactor(SparseSubfactorPLPS, F), d = SparseCreateSubfactor(SparseSubfactorD, F);
        memcpy(y, xt, sizeof(T) * 5);
        SparseMultiply(S_CAT(SparseGetConjugateTranspose_or_transpose, X)(plps), (DVx){ 5, y });
        SparseMultiply(d, (DVx){ 5, y });
        SparseMultiply(plps, (DVx){ 5, y });
        C(plps.contents == SparseSubfactorPLPS && TN(err)(y, b, 5) < tol * 100, "subfactors: PLPS D PLPS^H x == A x");
        SparseSolve(plps, (DVx){ 5, y });
        SparseSolve(d, (DVx){ 5, y });
        SparseSolve(S_CAT(SparseGetConjugateTranspose_or_transpose, X)(plps), (DVx){ 5, y });
        C(TN(err)(y, xt, 5) < tol * 100, "subfactors: SparseSolve undoes them");
        SparseCleanup(plps); SparseCleanup(d);
        /* refactor with 2A: the solution halves */
        for (long p = 0; p < A.structure.columnStarts[5]; p++) A.data[p] *= 2;
        SparseRefactor(A, &F);
        SparseSolve(F, (DVx){ 5, b }, (DVx){ 5, x });
        T half[5]; for (int i = 0; i < 5; i++) half[i] = xt[i] * (R)0.5;
        C(F.status == SparseStatusOK && TN(err)(x, half, 5) < tol * 100, "SparseRefactor");
        for (long p = 0; p < A.structure.columnStarts[5]; p++) A.data[p] /= 2;
        SparseCleanup(F); SparseCleanup(sym);
    }
    /* a symmetric indefinite matrix with zeros on the diagonal: pivoted LDLT, and the inertia */
    {
        T ind[16] = { 0 };
        ind[1] = ind[4] = 1; ind[6] = ind[9] = 2; ind[11] = ind[14] = 3; ind[15] = 1;   /* [[0,1,0,0],[1,0,2,0],[0,2,0,3],[0,0,3,1]] */
        SMx B = TN(sparse_of)(ind, 4, 4, SparseSymmetric);
        T bi[4];
        TN(dgemv)(ind, 4, 4, xt, bi);
        OFx F = SparseFactor(SparseFactorizationLDLT, B);
        if (F.status == SparseStatusOK) SparseSolve(F, (DVx){ 4, bi }, (DVx){ 4, x });
        C(F.status == SparseStatusOK && TN(err)(x, xt, 4) < tol * 100, "LDLT of an indefinite matrix with a zero diagonal");
        int z = -1, ng = -1, ps = -1;
        SparseGetInertia(F, &z, &ng, &ps);
        C(z == 0 && ng + ps == 4 && ng >= 1, "SparseGetInertia: an indefinite matrix");
        OFx U = SparseFactor(SparseFactorizationLDLTUnpivoted, B);
        C(U.status == SparseMatrixIsSingular, "LDLTUnpivoted reports the zero pivot");
        SparseCleanup(F); SparseCleanup(B);
    }
    /* an unsymmetric 5 x 5 matrix: LU, QR, CholeskyAtA, transposes */
    {
        T g[25] = { 0 };
        for (int i = 0; i < 5; i++) g[i * 5 + i] = MK(3 + i, 0);
        g[0 * 5 + 2] = MK(1, 1); g[1 * 5 + 0] = MK(-2, 0); g[3 * 5 + 1] = MK(0.5, -1); g[2 * 5 + 4] = MK(1, 0); g[4 * 5 + 3] = MK(2, 2); g[0 * 5 + 4] = MK(-1, 0);
        g[0] = 0;   /* a zero on the diagonal: LU must pivot */
        SMx G = TN(sparse_of)(g, 5, 5, SparseOrdinary);
        T bg[5];
        TN(dgemv)(g, 5, 5, xt, bg);
        const SparseFactorization_t lus[] = { SparseFactorizationLU, SparseFactorizationLUSPP, SparseFactorizationLUTPP, SparseFactorizationQR, SparseFactorizationCholeskyAtA };
        const char *lun[] = { "LU", "LUSPP", "LUTPP", "QR", "CholeskyAtA" };
        for (int t = 0; t < 5; t++) {
            OFx F = SparseFactor(lus[t], G);
            if (F.status == SparseStatusOK) SparseSolve(F, (DVx){ 5, bg }, (DVx){ 5, x });
            snprintf(what, sizeof what, "Sparse %s: SparseFactor(%s) of an unsymmetric matrix", ty, lun[t]);
            CHECK(F.status == SparseStatusOK && TN(err)(x, xt, 5) < tol * 1000, what);
            /* A^T x = c */
            T gt[25], ct[5];
            for (int i = 0; i < 5; i++) for (int j = 0; j < 5; j++) gt[j * 5 + i] = g[i * 5 + j];
            TN(dgemv)(gt, 5, 5, xt, ct);
            if (F.status == SparseStatusOK) SparseSolve(SparseGetTranspose(F), (DVx){ 5, ct }, (DVx){ 5, x });
            snprintf(what, sizeof what, "Sparse %s: SparseGetTranspose(%s) solves A^T x = b", ty, lun[t]);
            CHECK(F.status == SparseStatusOK && TN(err)(x, xt, 5) < tol * 1000, what);
            SparseCleanup(F);
        }
        OFx U = SparseFactor(SparseFactorizationLUUnpivoted, G);
        C(U.status != SparseStatusOK, "LUUnpivoted fails on the zero diagonal");
        /* QR's subfactors: A = Q RP */
        OFx Q = SparseFactor(SparseFactorizationQR, G);
        OSx q = SparseCreateSubfactor(SparseSubfactorQ, Q), rp = SparseCreateSubfactor(SparseSubfactorRP, Q);
        memcpy(y, xt, sizeof(T) * 5);
        SparseMultiply(rp, (DVx){ 5, y });
        T qy[5];
        SparseMultiply(q, (DVx){ 5, y }, (DVx){ 5, qy });
        C(TN(err)(qy, bg, 5) < tol * 100, "QR subfactors: Q (RP x) == A x");
        SparseCleanup(q); SparseCleanup(rp); SparseCleanup(Q);
        /* the iterative methods on the unsymmetric matrix: GMRES variants */
        const SparseGMRESVariant_t vars[] = { SparseVariantDQGMRES, SparseVariantGMRES, SparseVariantFGMRES };
        for (int v = 0; v < 3; v++) {
            SparseGMRESOptions o = { 0 }; o.variant = vars[v]; o.nvec = 5; o.rtol = tol;
            for (int i = 0; i < 5; i++) x[i] = 0;
            SparseIterativeStatus_t st = SparseSolve(SparseGMRES(o), G, (DVx){ 5, bg }, (DVx){ 5, x });
            snprintf(what, sizeof what, "Sparse %s: SparseSolve(GMRES variant %d, nvec 5) [status %d, error %g]", ty, v, (int)st, (double)TN(err)(x, xt, 5));
            CHECK(st == SparseIterativeConverged && TN(err)(x, xt, 5) < tol * 1e4, what);
        }
        SparseCleanup(G);
    }
    /* least squares (6 x 4) and minimum norm (4 x 6) */
    {
        T a[24];
        for (int j = 0; j < 4; j++) for (int i = 0; i < 6; i++) a[j * 6 + i] = (i + 2 * j) % 3 == 0 ? (T)0 : MK(1 + i - j, (i + j) % 2);
        a[0] = MK(2, 0);
        SMx L = TN(sparse_of)(a, 6, 4, SparseOrdinary);
        T bl[6];
        TN(dgemv)(a, 6, 4, xt, bl);   /* consistent: the least-squares solution is xt */
        const SparseFactorization_t qs[] = { SparseFactorizationQR, SparseFactorizationCholeskyAtA };
        for (int t = 0; t < 2; t++) {
            OFx F = SparseFactor(qs[t], L);
            if (F.status == SparseStatusOK) SparseSolve(F, (DVx){ 6, bl }, (DVx){ 4, x });
            snprintf(what, sizeof what, "Sparse %s: %s least squares of a 6 x 4 system", ty, t ? "CholeskyAtA" : "QR");
            CHECK(F.status == SparseStatusOK && TN(err)(x, xt, 4) < tol * 1000, what);
            /* minimum norm: A^T z = c has the solution z = A w for some w; check A^T z == c */
            T c4[4], z6[6], back[4];
            for (int i = 0; i < 4; i++) c4[i] = MK(1 + i, 0);
            if (F.status == SparseStatusOK) {
                SparseSolve(SparseGetTranspose(F), (DVx){ 4, c4 }, (DVx){ 6, z6 });
                T at[24]; for (int i = 0; i < 6; i++) for (int j = 0; j < 4; j++) at[i * 4 + j] = a[j * 6 + i];
                TN(dgemv)(at, 4, 6, z6, back);
            }
            snprintf(what, sizeof what, "Sparse %s: %s minimum norm of the transpose", ty, t ? "CholeskyAtA" : "QR");
            CHECK(F.status == SparseStatusOK && TN(err)(back, c4, 4) < tol * 1000, what);
            SparseCleanup(F);
        }
        /* LSMR, with and without the column scaling preconditioner */
        SparseLSMROptions o = { 0 }; o.atol = tol; o.btol = tol;
        for (int i = 0; i < 4; i++) x[i] = 0;
        SparseIterativeStatus_t st = SparseSolve(SparseLSMR(o), L, (DVx){ 6, bl }, (DVx){ 4, x });
        C(st == SparseIterativeConverged && TN(err)(x, xt, 4) < tol * 1e4, "SparseSolve(LSMR) least squares");
        for (int i = 0; i < 4; i++) x[i] = 0;
        st = SparseSolve(SparseLSMR(o), L, (DVx){ 6, bl }, (DVx){ 4, x }, SparsePreconditionerDiagScaling);
        C(st == SparseIterativeConverged && TN(err)(x, xt, 4) < tol * 1e4, "SparseSolve(LSMR, DiagScaling)");
        SparseCleanup(L);
    }
    /* CG on the positive definite matrix, with a diagonal preconditioner, an operator block, and SparseIterate */
    {
        SparseCGOptions o = { 0 }; o.rtol = tol;
        for (int i = 0; i < 5; i++) x[i] = 0;
        SparseIterativeStatus_t st = SparseSolve(SparseConjugateGradient(o), A, (DVx){ 5, b }, (DVx){ 5, x }, SparsePreconditionerDiagonal);
        C(st == SparseIterativeConverged && TN(err)(x, xt, 5) < tol * 1e4, "SparseSolve(CG, Diagonal)");
        for (int i = 0; i < 5; i++) x[i] = 0;
        __block int calls = 0;
        st = SparseSolve(SparseConjugateGradient(o), ^(bool acc, enum CBLAS_TRANSPOSE tr, DVx u, DVx v) {
            calls++;
            if (acc) SparseMultiplyAdd(A, u, v); else SparseMultiply(A, u, v);
        }, (DVx){ 5, b }, (DVx){ 5, x });
        C(st == SparseIterativeConverged && calls > 1 && TN(err)(x, xt, 5) < tol * 1e4, "SparseSolve(CG) with an operator block");
        SparseIterativeMethod cg = SparseConjugateGradient(o);
        size_t sz = TN(SparseGetStateSize)(cg, false, 5, 5, 1);
        void *state = malloc(sz);
        T r[5]; bool conv = false;
        for (int i = 0; i < 5; i++) x[i] = 0;
        DMx Bm = TN(dm)(b, 5, 1), Rm = TN(dm)(r, 5, 1), Xm = TN(dm)(x, 5, 1);
        for (int it = 0; it < 30; it++) {
            SparseIterate(cg, it, &conv, state, ^(bool acc, enum CBLAS_TRANSPOSE tr, DMx u, DMx v) { TN(_SparseMultiply)(1, A, u, v, acc); }, Bm, Rm, Xm);
            R nr = 0; for (int i = 0; i < 5; i++) nr += ABSV(r[i]);
            if (it > 0 && nr < tol) conv = true;
        }
        SparseIterate(cg, -1, &conv, state, ^(bool acc, enum CBLAS_TRANSPOSE tr, DMx u, DMx v) { TN(_SparseMultiply)(1, A, u, v, acc); }, Bm, Rm, Xm);
        C(sz > 0 && conv && TN(err)(x, xt, 5) < tol * 1e4, "SparseIterate(CG) with SparseGetStateSize");
        free(state);
    }
    /* block matrices: 2 x 2 blocks give the same products as their expansion */
    {
        int br[] = { 0, 1, 1 }, bc[] = { 0, 0, 1 };
        T bv[12] = { MK(1, 0), MK(2, 0), MK(3, 0), MK(4, 0),  MK(5, 0), MK(6, 0), MK(7, 0), MK(8, 0),  MK(9, 0), MK(1, 0), MK(2, 0), MK(3, 0) };
        S_CAT2(Sparse, ATTRT) at; memset(&at, 0, sizeof at);
        SMx Bk = SparseConvertFromCoordinate(2, 2, 3, 2, at, br, bc, bv);
        T in[4] = { MK(1, 0), MK(1, 0), MK(1, 0), MK(1, 0) }, out[4];
        SparseMultiply(Bk, (DVx){ 4, in }, (DVx){ 4, out });
        /* the expansion: [[1,3,0,0],[2,4,0,0],[5,7,9,2],[6,8,1,3]] */
        T want[4] = { MK(4, 0), MK(6, 0), MK(23, 0), MK(18, 0) };
        C(TN(err)(out, want, 4) < tol, "block matrices (blockSize 2)");
        OFx F = SparseFactor(SparseFactorizationLU, Bk);
        SparseSolve(F, (DVx){ 4, want }, (DVx){ 4, out });
        C(F.status == SparseStatusOK && TN(err)(out, in, 4) < tol * 100, "LU of a block matrix");
        SparseCleanup(F); SparseCleanup(Bk);
    }
    SparseCleanup(A);
    #undef C
}
#undef TN
#undef DMx
#undef DVx
#undef SMx
#undef OFx
#undef OSx
