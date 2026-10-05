/* Cassowary linear constraint solver (incremental simplex, after the Kiwi formulation).
 * Private to isim UIKit; drives Auto Layout. */
#pragma once

typedef struct cw_solver cw_solver;
enum { CW_LE = -1, CW_EQ = 0, CW_GE = 1 };
#define CW_REQUIRED 1e30

cw_solver *cw_new(void);
void cw_free(cw_solver *s);
int cw_var(cw_solver *s);                 /* new external variable (handle >= 1) */
/* sum(coeffs[i] * vars[i]) + constant  OP  0, with the given strength (CW_REQUIRED = hard).
 * Returns 0 on success, -1 if a required constraint is unsatisfiable (nothing is added). */
int cw_add(cw_solver *s, const int *vars, const double *coeffs, int n, double constant, int op, double strength);
double cw_value(cw_solver *s, int var);
