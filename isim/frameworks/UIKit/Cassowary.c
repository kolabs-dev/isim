/* Cassowary linear constraint solver for Auto Layout.
 *
 * The incremental simplex formulation follows the Kiwi solver (Chris Colbert, BSD) as described
 * in Badros, Borning & Stuckey, "The Cassowary Linear Arithmetic Constraint Solving Algorithm".
 * Symbols: external (user variables), slack (inequalities), error (non-required constraints,
 * weighted in the objective), dummy (required equalities). Constraints are only ever added;
 * isim rebuilds the solver for each layout pass. Bland's rule picks entering/leaving symbols
 * so pivoting cannot cycle. */
#include "Cassowary.h"
#include <float.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

enum { SYM_EXTERNAL = 1, SYM_SLACK, SYM_ERROR, SYM_DUMMY };
#define EPS 1e-8
static int near_zero(double v) { return v < EPS && v > -EPS; }

typedef struct { int sym; double c; } term;
typedef struct { double constant; term *t; int n, cap; } row;

struct cw_solver {
    unsigned char *type; int nsyms, capsyms;
    row **basic;            /* basic[sym] = row in which sym is basic, or NULL */
    row objective;
    row *artificial;
};

/* ---------------- rows ---------------- */
static row *row_new(double constant) { row *r = calloc(1, sizeof *r); r->constant = constant; return r; }
static void row_free(row *r) { if (r) { free(r->t); free(r); } }
static row *row_copy(const row *o) {
    row *r = row_new(o->constant);
    if (o->n) { r->t = malloc(o->n * sizeof *r->t); memcpy(r->t, o->t, o->n * sizeof *r->t); r->n = r->cap = o->n; }
    return r;
}
static int row_find(const row *r, int sym) { for (int i = 0; i < r->n; i++) if (r->t[i].sym == sym) return i; return -1; }
static double row_coeff(const row *r, int sym) { int i = row_find(r, sym); return i < 0 ? 0 : r->t[i].c; }
static void row_remove_at(row *r, int i) { r->t[i] = r->t[--r->n]; }
static void row_remove(row *r, int sym) { int i = row_find(r, sym); if (i >= 0) row_remove_at(r, i); }
static void row_add(row *r, int sym, double c) {
    int i = row_find(r, sym);
    if (i >= 0) { r->t[i].c += c; if (near_zero(r->t[i].c)) row_remove_at(r, i); return; }
    if (near_zero(c)) return;
    if (r->n == r->cap) { r->cap = r->cap ? r->cap * 2 : 8; r->t = realloc(r->t, r->cap * sizeof *r->t); }
    r->t[r->n++] = (term){ sym, c };
}
static void row_add_row(row *r, const row *o, double c) {
    r->constant += o->constant * c;
    for (int i = 0; i < o->n; i++) row_add(r, o->t[i].sym, o->t[i].c * c);
}
static void row_reverse(row *r) { r->constant = -r->constant; for (int i = 0; i < r->n; i++) r->t[i].c = -r->t[i].c; }
/* r: 0 = constant + sum + c_sym*sym  ->  sym = (constant + sum) * (-1/c_sym) */
static void row_solve_for(row *r, int sym) {
    int i = row_find(r, sym);
    double k = -1.0 / r->t[i].c;
    row_remove_at(r, i);
    r->constant *= k;
    for (int j = 0; j < r->n; j++) r->t[j].c *= k;
}
static void row_solve_for_ex(row *r, int lhs, int rhs) { row_add(r, lhs, -1.0); row_solve_for(r, rhs); }
static void row_substitute(row *r, int sym, const row *o) {
    int i = row_find(r, sym);
    if (i < 0) return;
    double c = r->t[i].c;
    row_remove_at(r, i);
    row_add_row(r, o, c);
}

/* ---------------- solver ---------------- */
static int new_sym(cw_solver *s, int type) {
    if (s->nsyms + 1 >= s->capsyms) {
        int cap = s->capsyms ? s->capsyms * 2 : 256;
        s->type = realloc(s->type, cap); s->basic = realloc(s->basic, cap * sizeof *s->basic);
        memset(s->type + s->capsyms, 0, cap - s->capsyms); memset(s->basic + s->capsyms, 0, (cap - s->capsyms) * sizeof *s->basic);
        s->capsyms = cap;
    }
    int sym = ++s->nsyms;
    s->type[sym] = (unsigned char)type;
    return sym;
}
cw_solver *cw_new(void) { cw_solver *s = calloc(1, sizeof *s); new_sym(s, SYM_DUMMY); s->nsyms = 0; return s; }
void cw_free(cw_solver *s) {
    if (!s) return;
    for (int i = 1; i <= s->nsyms; i++) row_free(s->basic[i]);
    free(s->objective.t); row_free(s->artificial); free(s->type); free(s->basic); free(s);
}
int cw_var(cw_solver *s) { return new_sym(s, SYM_EXTERNAL); }
double cw_value(cw_solver *s, int var) { return var > 0 && var <= s->nsyms && s->basic[var] ? s->basic[var]->constant : 0; }

static void substitute(cw_solver *s, int sym, const row *r) {
    for (int i = 1; i <= s->nsyms; i++) if (s->basic[i]) row_substitute(s->basic[i], sym, r);
    row_substitute(&s->objective, sym, r);
    if (s->artificial) row_substitute(s->artificial, sym, r);
}

/* Bland's rule: lowest-numbered symbol with a negative objective coefficient */
static int entering_symbol(cw_solver *s, const row *obj) {
    int best = 0;
    for (int i = 0; i < obj->n; i++)
        if (s->type[obj->t[i].sym] != SYM_DUMMY && obj->t[i].c < 0 && (!best || obj->t[i].sym < best)) best = obj->t[i].sym;
    return best;
}
static int leaving_symbol(cw_solver *s, int entering) {
    double ratio = DBL_MAX; int found = 0;
    for (int i = 1; i <= s->nsyms; i++) {
        row *r = s->basic[i];
        if (!r || s->type[i] == SYM_EXTERNAL) continue;
        double c = row_coeff(r, entering);
        if (c < 0) {
            double q = -r->constant / c;
            if (q < ratio - EPS || (q < ratio + EPS && found && i < found)) { ratio = q; found = i; }
        }
    }
    return found;
}
static int optimize(cw_solver *s, row *obj) {
    for (int guard = 0; guard < 100000; guard++) {
        int entering = entering_symbol(s, obj);
        if (!entering) return 0;
        int leaving = leaving_symbol(s, entering);
        if (!leaving) return -1;                              /* unbounded objective */
        row *r = s->basic[leaving]; s->basic[leaving] = NULL;
        row_solve_for_ex(r, leaving, entering);
        substitute(s, entering, r);
        s->basic[entering] = r;
    }
    return -1;
}

static int choose_subject(cw_solver *s, const row *r, int marker, int other) {
    for (int i = 0; i < r->n; i++) if (s->type[r->t[i].sym] == SYM_EXTERNAL) return r->t[i].sym;
    if (marker && (s->type[marker] == SYM_SLACK || s->type[marker] == SYM_ERROR) && row_coeff(r, marker) < 0) return marker;
    if (other && (s->type[other] == SYM_SLACK || s->type[other] == SYM_ERROR) && row_coeff(r, other) < 0) return other;
    return 0;
}
static int all_dummies(cw_solver *s, const row *r) {
    for (int i = 0; i < r->n; i++) if (s->type[r->t[i].sym] != SYM_DUMMY) return 0;
    return 1;
}
static int add_with_artificial(cw_solver *s, row *r) {
    int art = new_sym(s, SYM_SLACK);
    s->basic[art] = row_copy(r);
    s->artificial = row_copy(r);
    optimize(s, s->artificial);
    int ok = near_zero(s->artificial->constant);
    row_free(s->artificial); s->artificial = NULL;
    row *ar = s->basic[art];
    if (ar) {
        s->basic[art] = NULL;
        if (ar->n == 0) { row_free(ar); return ok; }
        int entering = 0;
        for (int i = 0; i < ar->n; i++) { int t = s->type[ar->t[i].sym]; if (t == SYM_SLACK || t == SYM_ERROR) { entering = ar->t[i].sym; break; } }
        if (!entering) { row_free(ar); return 0; }
        row_solve_for_ex(ar, art, entering);
        substitute(s, entering, ar);
        s->basic[entering] = ar;
    }
    for (int i = 1; i <= s->nsyms; i++) if (s->basic[i]) row_remove(s->basic[i], art);
    row_remove(&s->objective, art);
    return ok;
}

int cw_add(cw_solver *s, const int *vars, const double *coeffs, int n, double constant, int op, double strength) {
    int required = strength >= CW_REQUIRED;
    row *r = row_new(constant);
    for (int i = 0; i < n; i++) {
        if (near_zero(coeffs[i])) continue;
        if (s->basic[vars[i]]) row_add_row(r, s->basic[vars[i]], coeffs[i]);
        else row_add(r, vars[i], coeffs[i]);
    }
    int marker = 0, other = 0;
    /* objective terms are only committed once the constraint is known to be satisfiable */
    int obj_syms[2] = { 0, 0 };
    if (op != CW_EQ) {
        double c = op == CW_LE ? 1.0 : -1.0;
        marker = new_sym(s, SYM_SLACK); row_add(r, marker, c);
        if (!required) { other = new_sym(s, SYM_ERROR); row_add(r, other, -c); obj_syms[0] = other; }
    } else if (!required) {
        marker = new_sym(s, SYM_ERROR); other = new_sym(s, SYM_ERROR);
        row_add(r, marker, -1.0); row_add(r, other, 1.0);
        obj_syms[0] = marker; obj_syms[1] = other;
    } else {
        marker = new_sym(s, SYM_DUMMY); row_add(r, marker, 1.0);
    }
    for (int i = 0; i < 2; i++) if (obj_syms[i]) row_add(&s->objective, obj_syms[i], strength);
    if (r->constant < 0) row_reverse(r);

    int subject = choose_subject(s, r, marker, other);
    if (!subject && all_dummies(s, r)) {
        if (!near_zero(r->constant)) { row_free(r); return -1; }      /* redundant & conflicting required equality */
        subject = marker;
    }
    if (!subject) {
        int ok = add_with_artificial(s, r);
        row_free(r);
        if (!ok) return -1;
    } else {
        row_solve_for(r, subject);
        substitute(s, subject, r);
        s->basic[subject] = r;
    }
    optimize(s, &s->objective);
    return 0;
}
