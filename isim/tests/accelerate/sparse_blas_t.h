// Sparse BLAS from C (issue #819) for one scalar type (P = the name suffix, M = the matrix type, T, R, ABSV, MK set by
// sparse_blas.c), checked against dense arithmetic.
#define B__(a, b) a##_##b
#define B_(a, b) B__(a, b)
#define BB(name) B_(name, P)
static void BB(blas_tests)(int *checks, int *failures, const char *ty, R tol) {
    char what[160];
    #define C(cond, fmt) do { snprintf(what, sizeof what, "Sparse BLAS %s: " fmt, ty); CHECK(cond, what); } while (0)
    #define NEAR(a, b) (ABSV((T)(a) - (T)(b)) < tol)
    /* A = [[1,0,2],[0,3,0],[4,0,5],[0,6,0]] (4 x 3) */
    M A = BB(sparse_matrix_create)(4, 3);
    sparse_index ri[] = { 0, 2, 1, 3, 0, 2 }, ci[] = { 0, 0, 1, 1, 2, 2 };
    T av[] = { MK(1, 1), MK(4, 0), MK(3, 0), MK(6, -1), MK(2, 0), MK(5, 0) };
    C(BB(sparse_insert_entries)(A, 5, av, ri, ci) == SPARSE_SUCCESS && BB(sparse_insert_entry)(A, MK(5, 0), 2, 2) == SPARSE_SUCCESS,
      "sparse_matrix_create, sparse_insert_entries, sparse_insert_entry");
    C(sparse_set_matrix_property(A, SPARSE_UPPER_TRIANGULAR) == SPARSE_CANNOT_SET_PROPERTY, "sparse_set_matrix_property after inserting");
    C(sparse_commit(A) == SPARSE_SUCCESS && sparse_get_matrix_nonzero_count(A) == 6 && sparse_get_matrix_number_of_rows(A) == 4
      && sparse_get_matrix_number_of_columns(A) == 3 && sparse_get_matrix_nonzero_count_for_row(A, 0) == 2
      && sparse_get_matrix_nonzero_count_for_column(A, 1) == 2, "sparse_commit and the counts");
    T x[3] = { MK(1, 0), MK(2, 0), MK(3, 1) }, y[4] = { 0 }, yd[4];
    T dense[12] = { MK(1, 1), 0, MK(4, 0), 0,  0, MK(3, 0), 0, MK(6, -1),  MK(2, 0), 0, MK(5, 0), 0 };
    for (int i = 0; i < 4; i++) { yd[i] = 0; for (int j = 0; j < 3; j++) yd[i] += dense[j * 4 + i] * x[j]; }
    C(BB(sparse_matrix_vector_product_dense)(CblasNoTrans, MK(1, 0), A, x, 1, y, 1) == SPARSE_SUCCESS
      && NEAR(y[0], yd[0]) && NEAR(y[1], yd[1]) && NEAR(y[2], yd[2]) && NEAR(y[3], yd[3]), "sparse_matrix_vector_product_dense");
    T xt[4] = { MK(1, 0), MK(1, 0), MK(1, 0), MK(1, 0) }, yt[3] = { 0 };
    BB(sparse_matrix_vector_product_dense)(CblasTrans, MK(2, 0), A, xt, 1, yt, 1);
    C(NEAR(yt[0], MK(10, 2)) && NEAR(yt[1], MK(18, -2)) && NEAR(yt[2], MK(14, 0)), "sparse_matrix_vector_product_dense, transposed and scaled");
    /* C = A B, B = 3 x 2 dense (column-major) */
    T Bd[6] = { MK(1, 0), MK(0, 0), MK(1, 0),  MK(0, 0), MK(1, 0), MK(2, 0) }, Cd[8] = { 0 };
    BB(sparse_matrix_product_dense)(CblasColMajor, CblasNoTrans, 2, MK(1, 0), A, Bd, 3, Cd, 4);
    C(NEAR(Cd[0], MK(3, 1)) && NEAR(Cd[2], MK(9, 0)) && NEAR(Cd[5], MK(3, 0)) && NEAR(Cd[6], MK(10, 0)) && NEAR(Cd[7], MK(6, -1)),
      "sparse_matrix_product_dense");
    /* the same with B sparse */
    M Bs = BB(sparse_matrix_create)(3, 2);
    BB(sparse_insert_entry)(Bs, MK(1, 0), 0, 0); BB(sparse_insert_entry)(Bs, MK(1, 0), 2, 0); BB(sparse_insert_entry)(Bs, MK(1, 0), 1, 1); BB(sparse_insert_entry)(Bs, MK(2, 0), 2, 1);
    T Cs[8] = { 0 };
    C(BB(sparse_matrix_product_sparse)(CblasColMajor, CblasNoTrans, MK(1, 0), A, Bs, Cs, 4) == SPARSE_SUCCESS && NEAR(Cs[0], Cd[0]) && NEAR(Cs[6], Cd[6]),
      "sparse_matrix_product_sparse");
    /* extraction */
    T rv[3]; sparse_index rj[3], end = -1;
    C(BB(sparse_extract_sparse_row)(A, 2, 0, &end, 3, rv, rj) == SPARSE_SUCCESS && rj[0] == 0 && rj[1] == 2 && NEAR(rv[1], MK(5, 0)) && end == 3,
      "sparse_extract_sparse_row");
    T cv[3]; sparse_index cr[3];
    C(BB(sparse_extract_sparse_column)(A, 1, 2, &end, 3, cv, cr) == SPARSE_SUCCESS && cr[0] == 3 && NEAR(cv[0], MK(6, -1)), "sparse_extract_sparse_column from a row");
    /* norms and trace */
    C(fabs(BB(sparse_operator_norm)(A, SPARSE_NORM_INF) - (double)(ABSV(MK(4, 0)) + ABSV(MK(5, 0)))) < 1e-4
      && fabs(BB(sparse_elementwise_norm)(A, SPARSE_NORM_INF) - (double)ABSV(MK(6, -1))) < 1e-4, "sparse_operator_norm, sparse_elementwise_norm");
    C(NEAR(BB(sparse_matrix_trace)(A, 0), MK(9, 1)), "sparse_matrix_trace");
    /* permutation: rows (3, 2, 1, 0) */
    sparse_index perm[4] = { 3, 2, 1, 0 };
    C(BB(sparse_permute_rows)(A, perm) == SPARSE_SUCCESS && BB(sparse_extract_sparse_row)(A, 0, 0, &end, 3, rv, rj) == SPARSE_SUCCESS
      && rj[0] == 1 && NEAR(rv[0], MK(6, -1)), "sparse_permute_rows");
    B_(SparseMatrix, X) So = SparseConvertFromOpaque(A);
    C(So.structure.rowCount == 4 && So.structure.columnCount == 3 && So.structure.columnStarts[3] == 6, "SparseConvertFromOpaque");
    SparseCleanup(So);
    sparse_matrix_destroy(A); sparse_matrix_destroy(Bs);
    /* a lower triangular matrix: solves */
    M Lm = BB(sparse_matrix_create)(3, 3);
    C(sparse_set_matrix_property(Lm, SPARSE_LOWER_TRIANGULAR) == SPARSE_SUCCESS && sparse_get_matrix_property(Lm, SPARSE_LOWER_TRIANGULAR) == 1,
      "sparse_set_matrix_property / sparse_get_matrix_property");
    sparse_index lj[] = { 0, 1, 2 }; T lv[] = { MK(2, 0), MK(1, 0), MK(1, 1) };
    BB(sparse_insert_col)(Lm, 0, 3, lv, lj);
    sparse_index li2[] = { 1, 2 }; T lv2[] = { MK(4, 0), MK(3, 0) };
    BB(sparse_insert_col)(Lm, 1, 2, lv2, li2);
    sparse_index li3[] = { 2 }; T lv3[] = { MK(5, 0) };
    BB(sparse_insert_row)(Lm, 2, 1, lv3, (sparse_index[]){ 2 });
    (void)li3;
    T b[3] = { MK(2, 0), MK(9, 0), MK(22, 1) };   /* L (1, 2, 3) */
    C(BB(sparse_vector_triangular_solve_dense)(CblasNoTrans, MK(1, 0), Lm, b, 1) == SPARSE_SUCCESS && NEAR(b[0], MK(1, 0)) && NEAR(b[1], MK(2, 0)) && NEAR(b[2], MK(3, 0)),
      "sparse_vector_triangular_solve_dense");
    T bm[6] = { MK(2, 0), MK(9, 0), MK(22, 1),  MK(4, 0), MK(18, 0), MK(44, 2) };
    C(BB(sparse_matrix_triangular_solve_dense)(CblasColMajor, CblasNoTrans, 2, MK(1, 0), Lm, bm, 3) == SPARSE_SUCCESS && NEAR(bm[2], MK(3, 0)) && NEAR(bm[5], MK(6, 0)),
      "sparse_matrix_triangular_solve_dense");
    /* L^T x = c with x = (1, 1, 1): c = (2+1+(1+i), 4+3, 5) */
    T c[3] = { MK(4, 1), MK(7, 0), MK(5, 0) };
    C(BB(sparse_vector_triangular_solve_dense)(CblasTrans, MK(1, 0), Lm, c, 1) == SPARSE_SUCCESS && NEAR(c[0], MK(1, 0)) && NEAR(c[2], MK(1, 0)),
      "sparse_vector_triangular_solve_dense, transposed");
    sparse_matrix_destroy(Lm);
    /* block matrices */
    M Bk = BB(sparse_matrix_block_create)(2, 2, 2, 2);
    T blk[4] = { MK(1, 0), MK(2, 0), MK(3, 0), MK(4, 0) }, ex[4] = { 0 };
    C(BB(sparse_insert_block)(Bk, blk, 2, 1, 1, 0) == SPARSE_SUCCESS && BB(sparse_extract_block)(Bk, 1, 0, 2, 1, ex) == SPARSE_SUCCESS
      && NEAR(ex[3], MK(4, 0)) && sparse_get_block_dimension_for_row(Bk, 1) == 2 && sparse_get_matrix_nonzero_count(Bk) == 4,
      "sparse_matrix_block_create, sparse_insert_block, sparse_extract_block");
    sparse_matrix_destroy(Bk);
    sparse_dimension K[] = { 1, 2 }, Lb[] = { 2, 1 };
    M Vb = BB(sparse_matrix_variable_block_create)(2, 2, K, Lb);
    C(Vb && sparse_get_matrix_number_of_rows(Vb) == 3 && sparse_get_block_dimension_for_col(Vb, 0) == 2, "sparse_matrix_variable_block_create");
    sparse_matrix_destroy(Vb);
    /* sparse vectors */
    T dv[6] = { 0, MK(1, 0), 0, MK(2, 1), 0, MK(3, 0) }, pk[6]; sparse_index pi[6];
    long nz = BB(sparse_pack_vector)(6, 6, dv, 1, pk, pi);
    C(BB(sparse_get_vector_nonzero_count)(6, dv, 1) == 3 && nz == 3 && pi[1] == 3 && NEAR(pk[1], MK(2, 1)), "sparse_pack_vector, sparse_get_vector_nonzero_count");
    T un[6]; BB(sparse_unpack_vector)(6, 3, true, pk, pi, un, 1);
    C(NEAR(un[3], MK(2, 1)) && NEAR(un[2], 0), "sparse_unpack_vector");
    T ones[6] = { MK(1, 0), MK(1, 0), MK(1, 0), MK(1, 0), MK(1, 0), MK(1, 0) };
    C(NEAR(BB(sparse_inner_product_dense)(3, pk, pi, ones, 1), MK(6, 1)), "sparse_inner_product_dense");
    T qv[2] = { MK(2, 0), MK(1, 0) }; sparse_index qi[2] = { 3, 5 };
    C(NEAR(BB(sparse_inner_product_sparse)(3, 2, pk, pi, qv, qi), MK(7, 2)), "sparse_inner_product_sparse");
    BB(sparse_vector_add_with_scale_dense)(3, MK(2, 0), pk, pi, ones, 1);
    C(NEAR(ones[5], MK(7, 0)) && NEAR(ones[0], MK(1, 0)), "sparse_vector_add_with_scale_dense");
    C(fabs(BB(sparse_vector_norm)(3, pk, pi, SPARSE_NORM_INF) - 3) < 1e-4 && fabs(BB(sparse_vector_norm)(3, pk, pi, SPARSE_NORM_ONE) - (4 + (double)ABSV(MK(2, 1)))) < 1e-4,
      "sparse_vector_norm");
    /* outer product into a new matrix */
    M O = NULL;
    T xo[2] = { MK(1, 0), MK(2, 0) };
    C(BB(sparse_outer_product_dense)(2, 6, 3, MK(1, 0), xo, 1, pk, pi, &O) == SPARSE_SUCCESS && O && sparse_get_matrix_nonzero_count(O) == 6,
      "sparse_outer_product_dense creates the matrix");
    sparse_matrix_destroy(O);
    #undef C
    #undef NEAR
}
#undef BB
#undef B_
#undef B__
