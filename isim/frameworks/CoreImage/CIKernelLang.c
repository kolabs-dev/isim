/* isim Core Image kernel interpreter: parses kernels written in the Core Image Kernel Language (GLSL-like:
 * `kernel vec4 k(sampler s) { ... }`) and Metal Core Image kernels (`float4 k(coreimage::sampler s,
 * coreimage::destination d)` in namespace coreimage) into a tree that is evaluated per pixel. Covers scalar, vector
 * and matrix math with swizzles, the usual control flow, helper functions, and the Core Image / GLSL / Metal
 * built-in functions. Sampling and destination coordinates are provided by the host (CIKernel.m) through ck_host. */
#include "CIKernelLang.h"
#include <ctype.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ================= tokens ================= */
enum { TK_EOF, TK_ID, TK_NUM, TK_STR, TK_OP };
typedef struct { int kind; char s[64]; double num; int isint; int line; } tok;
typedef struct { tok *t; int n, cap, pos; } toks;

static void push(toks *ts, tok t) {
    if (ts->n == ts->cap) { ts->cap = ts->cap ? ts->cap * 2 : 256; ts->t = realloc(ts->t, sizeof(tok) * ts->cap); }
    ts->t[ts->n++] = t;
}
static int lex(const char *src, toks *ts, char *err, size_t errlen) {
    int line = 1;
    const char *p = src;
    while (*p) {
        if (*p == '\n') { line++; p++; continue; }
        if (isspace((unsigned char)*p)) { p++; continue; }
        if (p[0] == '/' && p[1] == '/') { while (*p && *p != '\n') p++; continue; }
        if (p[0] == '/' && p[1] == '*') { p += 2; while (*p && !(p[0] == '*' && p[1] == '/')) { if (*p == '\n') line++; p++; } if (*p) p += 2; continue; }
        if (*p == '#') { while (*p && *p != '\n') { if (p[0] == '\\' && p[1] == '\n') { line++; p++; } p++; } continue; }   /* preprocessor lines */
        tok t; memset(&t, 0, sizeof t); t.line = line;
        if (isalpha((unsigned char)*p) || *p == '_') {
            int n = 0;
            while ((isalnum((unsigned char)*p) || *p == '_') && n < 63) t.s[n++] = *p++;
            while (isalnum((unsigned char)*p) || *p == '_') p++;
            t.kind = TK_ID;
        } else if (isdigit((unsigned char)*p) || (*p == '.' && isdigit((unsigned char)p[1]))) {
            char *end; t.num = strtod(p, &end);
            t.isint = 1;
            for (const char *q = p; q < end; q++) if (*q == '.' || *q == 'e' || *q == 'E') t.isint = 0;
            if (end == p) { snprintf(err, errlen, "line %d: bad number", line); return 0; }
            p = end;
            while (*p == 'f' || *p == 'F' || *p == 'h' || *p == 'H' || *p == 'u' || *p == 'U' || *p == 'l' || *p == 'L') { if (*p != 'u' && *p != 'U') t.isint = t.isint && 0; p++; }
            t.kind = TK_NUM;
        } else if (*p == '"') {
            int n = 0; p++;
            while (*p && *p != '"') { if (n < 63) t.s[n++] = *p; p++; }
            if (*p) p++;
            t.kind = TK_STR;
        } else {
            static const char *ops[] = { "<<=", ">>=", "::", "==", "!=", "<=", ">=", "&&", "||", "++", "--", "+=", "-=", "*=", "/=", "%=",
                                         "&=", "|=", "^=", "<<", ">>", "[[", "]]", "->", NULL };
            int m = 0;
            for (int i = 0; ops[i]; i++) { size_t l = strlen(ops[i]); if (!strncmp(p, ops[i], l)) { memcpy(t.s, ops[i], l); m = (int)l; break; } }
            if (!m) { t.s[0] = *p; m = 1; }
            p += m;
            t.kind = TK_OP;
        }
        push(ts, t);
    }
    tok e; memset(&e, 0, sizeof e); e.kind = TK_EOF; e.line = line; push(ts, e);
    return 1;
}

/* ================= types ================= */
typedef struct { const char *name; int kind, n; } tyname;
static const tyname TYPES[] = {
    { "float", CK_FLOAT, 1 }, { "vec2", CK_FLOAT, 2 }, { "vec3", CK_FLOAT, 3 }, { "vec4", CK_FLOAT, 4 },
    { "float2", CK_FLOAT, 2 }, { "float3", CK_FLOAT, 3 }, { "float4", CK_FLOAT, 4 }, { "half", CK_FLOAT, 1 }, { "half2", CK_FLOAT, 2 },
    { "half3", CK_FLOAT, 3 }, { "half4", CK_FLOAT, 4 }, { "double", CK_FLOAT, 1 },
    { "int", CK_INT, 1 }, { "ivec2", CK_INT, 2 }, { "ivec3", CK_INT, 3 }, { "ivec4", CK_INT, 4 }, { "int2", CK_INT, 2 }, { "int3", CK_INT, 3 },
    { "int4", CK_INT, 4 }, { "uint", CK_INT, 1 }, { "uint2", CK_INT, 2 }, { "uint3", CK_INT, 3 }, { "uint4", CK_INT, 4 }, { "short", CK_INT, 1 },
    { "ushort", CK_INT, 1 }, { "char", CK_INT, 1 }, { "uchar", CK_INT, 1 }, { "size_t", CK_INT, 1 },
    { "bool", CK_BOOL, 1 }, { "bvec2", CK_BOOL, 2 }, { "bvec3", CK_BOOL, 3 }, { "bvec4", CK_BOOL, 4 }, { "bool2", CK_BOOL, 2 },
    { "bool3", CK_BOOL, 3 }, { "bool4", CK_BOOL, 4 },
    { "mat2", CK_MAT, 2 }, { "mat3", CK_MAT, 3 }, { "mat4", CK_MAT, 4 }, { "float2x2", CK_MAT, 2 }, { "float3x3", CK_MAT, 3 },
    { "float4x4", CK_MAT, 4 }, { "half2x2", CK_MAT, 2 }, { "half3x3", CK_MAT, 3 }, { "half4x4", CK_MAT, 4 },
    { "sampler", CK_SAMPLER, 1 }, { "__sampler", CK_SAMPLER, 1 }, { "sampler_h", CK_SAMPLER, 1 }, { "__table", CK_SAMPLER, 1 },
    { "__sample", CK_SAMPLE, 4 }, { "sample_t", CK_SAMPLE, 4 }, { "sample_h", CK_SAMPLE, 4 }, { "__color", CK_COLOR, 4 },
    { "destination", CK_DEST, 1 }, { "destination_h", CK_DEST, 1 }, { "void", CK_VOID, 0 }, { NULL, 0, 0 },
};
static const tyname *type_named(const char *s) { for (int i = 0; TYPES[i].name; i++) if (!strcmp(TYPES[i].name, s)) return &TYPES[i]; return NULL; }
static int is_qualifier(const char *s) {
    static const char *q[] = { "const", "constant", "thread", "device", "threadgroup", "static", "inline", "__in", "in", "highp", "mediump",
                               "lowp", "uniform", "volatile", "constexpr", "unsigned", "signed", "__attribute__", "extern", "out", "inout",
                               "__out", "__inout", "precise", "typename", NULL };
    for (int i = 0; q[i]; i++) if (!strcmp(q[i], s)) return 1;
    return 0;
}

/* ================= AST ================= */
enum {
    N_NUM, N_VAR, N_ASSIGN, N_OPASSIGN, N_BIN, N_NEG, N_NOT, N_BNOT, N_CALL, N_CTOR, N_SWZ, N_INDEX, N_TERN, N_PREINC, N_POSTINC,
    N_BUILTIN, N_AND, N_OR, N_COMMA,
    S_BLOCK, S_DECL, S_EXPR, S_IF, S_FOR, S_WHILE, S_DO, S_RETURN, S_BREAK, S_CONTINUE, S_NOP,
};
typedef struct node node;
struct node {
    int op, iv, kind, n;          /* iv: slot / operator / function / builtin id; kind, n: static type for ctors and decls */
    float num;
    int sw[4], nsw;               /* swizzle */
    int nk; node **k;
    int line;
};
static node *mk(int op, int line) { node *n = calloc(1, sizeof *n); n->op = op; n->line = line; return n; }
static void add(node *p, node *c) { p->k = realloc(p->k, sizeof(node *) * (p->nk + 1)); p->k[p->nk++] = c; }
static void free_node(node *n) { if (!n) return; for (int i = 0; i < n->nk; i++) free_node(n->k[i]); free(n->k); free(n); }

typedef struct { char name[64]; int kind, n; } param;
struct ck_func {
    char name[64];
    int retkind, retn, iskernel;
    int nparams; param params[24];
    int nslots;
    node *body;
};
struct ck_program { ck_func *f[64]; int nf; };

/* ================= parser ================= */
typedef struct {
    toks *ts; char *err; size_t errlen; int failed;
    ck_program *prog; ck_func *cur;
    /* scopes: names -> slots */
    char names[256][64]; int slots[256]; int nnames; int scope_mark[64]; int nscope;
} parser;
static tok *peek(parser *p) { return &p->ts->t[p->ts->pos]; }
static tok *peek2(parser *p, int k) { int i = p->ts->pos + k; return &p->ts->t[i < p->ts->n ? i : p->ts->n - 1]; }
static tok *next(parser *p) { tok *t = &p->ts->t[p->ts->pos]; if (t->kind != TK_EOF) p->ts->pos++; return t; }
static void fail(parser *p, const char *fmt, ...) {
    if (p->failed) return;
    p->failed = 1;
    int l = snprintf(p->err, p->errlen, "line %d: ", peek(p)->line);
    va_list ap; va_start(ap, fmt); vsnprintf(p->err + l, p->errlen - (size_t)l, fmt, ap); va_end(ap);
}
static int is_op(tok *t, const char *s) { return t->kind == TK_OP && !strcmp(t->s, s); }
static int is_id(tok *t, const char *s) { return t->kind == TK_ID && !strcmp(t->s, s); }
static int accept(parser *p, const char *s) { if (is_op(peek(p), s)) { next(p); return 1; } return 0; }
static void expect(parser *p, const char *s) { if (!accept(p, s)) fail(p, "expected '%s' near '%s'", s, peek(p)->s); }
static void skip_ns(parser *p) {     /* coreimage::, metal:: */
    while (peek(p)->kind == TK_ID && is_op(peek2(p, 1), "::")) { next(p); next(p); }
}
static void skip_attr(parser *p) {
    while (is_op(peek(p), "[[")) { while (!is_op(peek(p), "]]") && peek(p)->kind != TK_EOF) next(p); next(p); }
}
static int lookup(parser *p, const char *name) {
    for (int i = p->nnames - 1; i >= 0; i--) if (!strcmp(p->names[i], name)) return p->slots[i];
    return -1;
}
static int declare(parser *p, const char *name) {
    if (p->nnames >= 256) { fail(p, "too many variables"); return 0; }
    strcpy(p->names[p->nnames], name);
    int s = p->cur->nslots++;
    p->slots[p->nnames++] = s;
    return s;
}
static void push_scope(parser *p) { p->scope_mark[p->nscope++] = p->nnames; }
static void pop_scope(parser *p) { p->nnames = p->scope_mark[--p->nscope]; }
/* a type at the cursor (after qualifiers / namespaces): returns it or NULL */
static const tyname *parse_type(parser *p) {
    int save = p->ts->pos;
    while (peek(p)->kind == TK_ID && is_qualifier(peek(p)->s)) next(p);
    skip_ns(p);
    tok *t = peek(p);
    const tyname *ty = t->kind == TK_ID ? type_named(t->s) : NULL;
    if (!ty) { p->ts->pos = save; return NULL; }
    next(p);
    while (is_op(peek(p), "&") || is_op(peek(p), "*")) next(p);
    return ty;
}

enum { B_NONE = -1 };
static const char *BUILTINS[] = {
    "radians", "degrees", "sin", "cos", "tan", "asin", "acos", "atan", "atan2", "sinh", "cosh", "tanh", "pow", "powr", "exp", "exp2", "log",
    "log2", "sqrt", "rsqrt", "inversesqrt", "abs", "fabs", "sign", "floor", "ceil", "fract", "mod", "fmod", "min", "max", "fmin", "fmax", "clamp",
    "saturate", "mix", "step", "smoothstep", "length", "distance", "dot", "cross", "normalize", "faceforward", "reflect", "round", "trunc",
    "any", "all", "not", "sample", "samplerCoord", "samplerTransform", "samplerExtent", "samplerOrigin", "samplerSize", "destCoord",
    "premultiply", "unpremultiply", "compare", "srgb_to_linear", "linear_to_srgb", "isnan", "isinf", "select", "fma", "exp10",
    /* methods (sampler / destination): */ "m_sample", "m_transform", "m_coord", "m_extent", "m_origin", "m_size", "m_dcoord",
    "length_squared", "rint", "log10", "copysign", "mad", "divide", NULL,
};
static int builtin_id(const char *s) { for (int i = 0; BUILTINS[i]; i++) if (!strcmp(BUILTINS[i], s)) return i; return B_NONE; }
#define BID(name) builtin_id(name)

static node *expr(parser *p);
static node *assign_expr(parser *p);
static int swizzle(const char *s, int *sw) {
    int n = (int)strlen(s);
    if (n < 1 || n > 4) return 0;
    for (int i = 0; i < n; i++) {
        const char *c = strchr("xyzw", s[i]); if (!c) c = strchr("rgba", s[i]) ? strchr("rgba", s[i]) : NULL;
        int idx = -1;
        if (strchr("xyzw", s[i])) idx = (int)(strchr("xyzw", s[i]) - "xyzw");
        else if (strchr("rgba", s[i])) idx = (int)(strchr("rgba", s[i]) - "rgba");
        else if (strchr("stpq", s[i])) idx = (int)(strchr("stpq", s[i]) - "stpq");
        (void)c;
        if (idx < 0) return 0;
        sw[i] = idx;
    }
    return n;
}
static ck_func *func_named(ck_program *pg, const char *s) { for (int i = 0; i < pg->nf; i++) if (!strcmp(pg->f[i]->name, s)) return pg->f[i]; return NULL; }
static node *primary(parser *p) {
    tok *t = peek(p);
    int line = t->line;
    if (t->kind == TK_NUM) { next(p); node *n = mk(N_NUM, line); n->num = (float)t->num; n->kind = t->isint ? CK_INT : CK_FLOAT; return n; }
    if (accept(p, "(")) {
        /* C-style cast: (float)x */
        int save = p->ts->pos;
        const tyname *ty = parse_type(p);
        if (ty && accept(p, ")")) {
            node *n = mk(N_CTOR, line); n->kind = ty->kind == CK_SAMPLE || ty->kind == CK_COLOR ? CK_FLOAT : ty->kind; n->n = ty->n;
            node *e = primary(p);
            add(n, e);
            return n;
        }
        p->ts->pos = save;
        node *e = expr(p); expect(p, ")"); return e;
    }
    if (t->kind == TK_ID) {
        if (is_id(t, "true") || is_id(t, "false")) { next(p); node *n = mk(N_NUM, line); n->num = is_id(t, "true"); n->kind = CK_BOOL; return n; }
        if (is_id(t, "M_PI_F") || is_id(t, "M_PI") || is_id(t, "M_PI_H")) { next(p); node *n = mk(N_NUM, line); n->num = (float)M_PI; n->kind = CK_FLOAT; return n; }
        skip_ns(p); t = peek(p);
        const tyname *ty = type_named(t->s);
        if (ty && is_op(peek2(p, 1), "(")) {     /* constructor */
            next(p); next(p);
            node *n = mk(N_CTOR, line); n->kind = ty->kind == CK_SAMPLE || ty->kind == CK_COLOR ? CK_FLOAT : ty->kind; n->n = ty->n;
            if (!accept(p, ")")) { do add(n, assign_expr(p)); while (accept(p, ",")); expect(p, ")"); }
            return n;
        }
        next(p);
        if (accept(p, "(")) {
            node *n;
            ck_func *f = func_named(p->prog, t->s);
            int b = builtin_id(t->s);
            if (f) { n = mk(N_CALL, line); n->iv = -1; }
            else if (b != B_NONE) { n = mk(N_BUILTIN, line); n->iv = b; }
            else { fail(p, "unknown function '%s'", t->s); return mk(N_NUM, line); }
            if (!accept(p, ")")) { do add(n, assign_expr(p)); while (accept(p, ",")); expect(p, ")"); }
            if (f) { for (int i = 0; i < p->prog->nf; i++) if (p->prog->f[i] == f) n->iv = i; }
            return n;
        }
        int s = lookup(p, t->s);
        if (s < 0) { fail(p, "unknown identifier '%s'", t->s); return mk(N_NUM, line); }
        node *n = mk(N_VAR, line); n->iv = s;
        return n;
    }
    fail(p, "unexpected '%s'", t->s);
    next(p);
    return mk(N_NUM, line);
}
static node *postfix(parser *p) {
    node *e = primary(p);
    for (;;) {
        int line = peek(p)->line;
        if (accept(p, ".")) {
            tok *m = next(p);
            if (is_op(peek(p), "(")) {           /* method call: s.sample(p), s.transform(p), d.coord() ... */
                next(p);
                const char *mn = !strcmp(m->s, "sample") ? "m_sample" : !strcmp(m->s, "transform") ? "m_transform" : !strcmp(m->s, "coord") ? "m_coord"
                               : !strcmp(m->s, "extent") ? "m_extent" : !strcmp(m->s, "origin") ? "m_origin" : !strcmp(m->s, "size") ? "m_size" : NULL;
                if (!mn) { fail(p, "unknown method '%s'", m->s); return e; }
                node *n = mk(N_BUILTIN, line); n->iv = builtin_id(mn); add(n, e);
                if (!accept(p, ")")) { do add(n, assign_expr(p)); while (accept(p, ",")); expect(p, ")"); }
                e = n; continue;
            }
            node *n = mk(N_SWZ, line);
            n->nsw = swizzle(m->s, n->sw);
            if (!n->nsw) { fail(p, "bad swizzle '%s'", m->s); }
            add(n, e); e = n; continue;
        }
        if (accept(p, "[")) { node *n = mk(N_INDEX, line); add(n, e); add(n, expr(p)); expect(p, "]"); e = n; continue; }
        if (is_op(peek(p), "++") || is_op(peek(p), "--")) { node *n = mk(N_POSTINC, line); n->iv = next(p)->s[0] == '+' ? 1 : -1; add(n, e); e = n; continue; }
        break;
    }
    return e;
}
static node *unary(parser *p) {
    int line = peek(p)->line;
    if (accept(p, "-")) { node *n = mk(N_NEG, line); add(n, unary(p)); return n; }
    if (accept(p, "+")) return unary(p);
    if (accept(p, "!")) { node *n = mk(N_NOT, line); add(n, unary(p)); return n; }
    if (accept(p, "~")) { node *n = mk(N_BNOT, line); add(n, unary(p)); return n; }
    if (is_op(peek(p), "++") || is_op(peek(p), "--")) { node *n = mk(N_PREINC, line); n->iv = next(p)->s[0] == '+' ? 1 : -1; add(n, unary(p)); return n; }
    return postfix(p);
}
static int prec(tok *t) {
    if (t->kind != TK_OP) return -1;
    static const struct { const char *s; int p; } T[] = { { "||", 1 }, { "&&", 2 }, { "|", 3 }, { "^", 4 }, { "&", 5 }, { "==", 6 }, { "!=", 6 },
        { "<", 7 }, { ">", 7 }, { "<=", 7 }, { ">=", 7 }, { "<<", 8 }, { ">>", 8 }, { "+", 9 }, { "-", 9 }, { "*", 10 }, { "/", 10 }, { "%", 10 }, { NULL, 0 } };
    for (int i = 0; T[i].s; i++) if (!strcmp(T[i].s, t->s)) return T[i].p;
    return -1;
}
static node *binary(parser *p, int minp) {
    node *l = unary(p);
    for (;;) {
        tok *t = peek(p); int pr = prec(t);
        if (pr < minp) break;
        next(p);
        node *r = binary(p, pr + 1);
        node *n = mk(!strcmp(t->s, "&&") ? N_AND : !strcmp(t->s, "||") ? N_OR : N_BIN, t->line);
        n->iv = (t->s[0] << 8) | t->s[1];
        add(n, l); add(n, r); l = n;
    }
    return l;
}
static node *ternary(parser *p) {
    node *c = binary(p, 1);
    if (accept(p, "?")) {
        node *n = mk(N_TERN, c->line); add(n, c); add(n, assign_expr(p)); expect(p, ":"); add(n, assign_expr(p));
        return n;
    }
    return c;
}
static node *assign_expr(parser *p) {
    node *l = ternary(p);
    tok *t = peek(p);
    if (is_op(t, "=")) { next(p); node *n = mk(N_ASSIGN, t->line); add(n, l); add(n, assign_expr(p)); return n; }
    if (t->kind == TK_OP && strlen(t->s) == 2 && t->s[1] == '=' && strchr("+-*/%&|^", t->s[0])) {
        next(p); node *n = mk(N_OPASSIGN, t->line); n->iv = t->s[0] << 8; add(n, l); add(n, assign_expr(p)); return n;
    }
    return l;
}
static node *expr(parser *p) {
    node *e = assign_expr(p);
    while (is_op(peek(p), ",")) { next(p); node *n = mk(N_COMMA, e->line); add(n, e); add(n, assign_expr(p)); e = n; }
    return e;
}
static node *statement(parser *p);
static node *decl_rest(parser *p, const tyname *ty, int line) {
    node *blk = mk(S_BLOCK, line); blk->iv = 1;        /* iv 1: no new scope (declarations belong to the enclosing one) */
    do {
        tok *nm = next(p);
        if (nm->kind != TK_ID) { fail(p, "expected a name"); return blk; }
        int arr = 0;
        if (accept(p, "[")) { if (!is_op(peek(p), "]")) { tok *c = next(p); arr = (int)c->num; } expect(p, "]"); }
        node *d = mk(S_DECL, line); d->kind = ty->kind == CK_SAMPLE || ty->kind == CK_COLOR ? CK_FLOAT : ty->kind; d->n = ty->n;
        if (arr) d->n = -arr;                         /* arrays of scalars only */
        node *init = NULL;
        if (accept(p, "=")) {
            if (accept(p, "{")) {                     /* array initializer */
                init = mk(N_CTOR, line); init->kind = CK_FLOAT; init->n = 16;
                if (!accept(p, "}")) { do add(init, assign_expr(p)); while (accept(p, ",")); expect(p, "}"); }
            } else init = assign_expr(p);
        }
        d->iv = declare(p, nm->s);
        if (init) add(d, init);
        add(blk, d);
    } while (accept(p, ","));
    return blk;
}
static node *block(parser *p) {
    node *b = mk(S_BLOCK, peek(p)->line);
    expect(p, "{");
    push_scope(p);
    while (!is_op(peek(p), "}") && peek(p)->kind != TK_EOF && !p->failed) add(b, statement(p));
    pop_scope(p);
    expect(p, "}");
    return b;
}
static node *statement(parser *p) {
    tok *t = peek(p);
    int line = t->line;
    if (is_op(t, "{")) return block(p);
    if (accept(p, ";")) return mk(S_NOP, line);
    if (is_id(t, "if")) {
        next(p); expect(p, "("); node *n = mk(S_IF, line); add(n, expr(p)); expect(p, ")");
        push_scope(p); add(n, statement(p)); pop_scope(p);
        if (is_id(peek(p), "else")) { next(p); push_scope(p); add(n, statement(p)); pop_scope(p); }
        return n;
    }
    if (is_id(t, "for")) {
        next(p); expect(p, "(");
        push_scope(p);
        node *n = mk(S_FOR, line);
        const tyname *ty = parse_type(p);
        add(n, ty ? decl_rest(p, ty, line) : is_op(peek(p), ";") ? mk(S_NOP, line) : (node *)({ node *e = mk(S_EXPR, line); add(e, expr(p)); e; }));
        expect(p, ";");
        add(n, is_op(peek(p), ";") ? NULL : expr(p)); expect(p, ";");
        add(n, is_op(peek(p), ")") ? NULL : expr(p)); expect(p, ")");
        add(n, statement(p));
        pop_scope(p);
        return n;
    }
    if (is_id(t, "while")) { next(p); expect(p, "("); node *n = mk(S_WHILE, line); add(n, expr(p)); expect(p, ")"); push_scope(p); add(n, statement(p)); pop_scope(p); return n; }
    if (is_id(t, "do")) { next(p); node *n = mk(S_DO, line); push_scope(p); add(n, statement(p)); pop_scope(p); if (!is_id(peek(p), "while")) fail(p, "expected while"); next(p); expect(p, "("); add(n, expr(p)); expect(p, ")"); expect(p, ";"); return n; }
    if (is_id(t, "return")) { next(p); node *n = mk(S_RETURN, line); if (!is_op(peek(p), ";")) add(n, expr(p)); expect(p, ";"); return n; }
    if (is_id(t, "break")) { next(p); expect(p, ";"); return mk(S_BREAK, line); }
    if (is_id(t, "continue")) { next(p); expect(p, ";"); return mk(S_CONTINUE, line); }
    int save = p->ts->pos;
    const tyname *ty = parse_type(p);
    if (ty && peek(p)->kind == TK_ID && !is_op(peek2(p, 1), "(")) { node *d = decl_rest(p, ty, line); expect(p, ";"); return d; }
    if (ty) p->ts->pos = save;
    node *n = mk(S_EXPR, line); add(n, expr(p)); expect(p, ";");
    return n;
}
static void parse_function(parser *p, int iskernel) {
    const tyname *rt = parse_type(p);
    if (!rt) { fail(p, "expected a return type near '%s'", peek(p)->s); return; }
    skip_attr(p);
    tok *nm = next(p);
    if (nm->kind != TK_ID) { fail(p, "expected a function name"); return; }
    ck_func *f = calloc(1, sizeof *f);
    strncpy(f->name, nm->s, 63);
    f->retkind = rt->kind == CK_SAMPLE || rt->kind == CK_COLOR ? CK_FLOAT : rt->kind; f->retn = rt->n; f->iskernel = iskernel;
    p->cur = f; p->nnames = 0; p->nscope = 0;
    expect(p, "(");
    if (!accept(p, ")")) {
        do {
            if (is_id(peek(p), "void") && is_op(peek2(p, 1), ")")) { next(p); break; }
            const tyname *pt = parse_type(p);
            if (!pt) { fail(p, "expected a parameter type near '%s'", peek(p)->s); free(f); return; }
            tok *pn = next(p);
            skip_attr(p);
            if (f->nparams >= 24) { fail(p, "too many parameters"); free(f); return; }
            param *pa = &f->params[f->nparams++];
            strncpy(pa->name, pn->s, 63); pa->kind = pt->kind; pa->n = pt->n;
            declare(p, pn->s);
        } while (accept(p, ","));
        expect(p, ")");
    }
    skip_attr(p);
    if (accept(p, ";")) { free(f); return; }          /* a prototype */
    /* register before the body so the function can call itself / be called by later ones */
    ck_func *old = func_named(p->prog, f->name);
    if (old) { fail(p, "function '%s' defined twice", f->name); free(f); return; }
    if (p->prog->nf >= 64) { fail(p, "too many functions"); free(f); return; }
    p->prog->f[p->prog->nf++] = f;
    f->body = block(p);
}
ck_program *ck_parse(const char *src, char *err, size_t errlen) {
    toks ts = { 0 };
    if (!lex(src, &ts, err, errlen)) { free(ts.t); return NULL; }
    parser p; memset(&p, 0, sizeof p);
    p.ts = &ts; p.err = err; p.errlen = errlen;
    p.prog = calloc(1, sizeof *p.prog);
    int wrap = 0;
    while (peek(&p)->kind != TK_EOF && !p.failed) {
        tok *t = peek(&p);
        if (is_id(t, "extern") && peek2(&p, 1)->kind == TK_STR) { next(&p); next(&p); if (accept(&p, "{")) wrap++; continue; }
        if (is_id(t, "namespace")) { next(&p); if (peek(&p)->kind == TK_ID) next(&p); expect(&p, "{"); wrap++; continue; }
        if (is_id(t, "using") || is_id(t, "typedef") || is_id(t, "struct")) { while (!is_op(peek(&p), ";") && peek(&p)->kind != TK_EOF) next(&p); next(&p); continue; }
        if (is_op(t, "}") && wrap > 0) { next(&p); wrap--; continue; }
        if (accept(&p, ";")) continue;
        skip_attr(&p);
        int iskernel = 0;
        while (peek(&p)->kind == TK_ID && (is_id(peek(&p), "kernel") || is_id(peek(&p), "stitchable") || is_qualifier(peek(&p)->s))) {
            if (is_id(peek(&p), "kernel")) iskernel = 1;
            next(&p);
            skip_attr(&p);
        }
        parse_function(&p, iskernel);
    }
    free(ts.t);
    if (p.failed) { ck_free(p.prog); return NULL; }
    if (!p.prog->nf) { snprintf(err, errlen, "no functions"); ck_free(p.prog); return NULL; }
    return p.prog;
}
void ck_free(ck_program *pg) {
    if (!pg) return;
    for (int i = 0; i < pg->nf; i++) { free_node(pg->f[i]->body); free(pg->f[i]); }
    free(pg);
}
int ck_count(const ck_program *pg) { return pg->nf; }
ck_func *ck_func_at(const ck_program *pg, int i) { return i >= 0 && i < pg->nf ? pg->f[i] : NULL; }
ck_func *ck_find(const ck_program *pg, const char *name) { return func_named((ck_program *)pg, name); }
const char *ck_name(const ck_func *f) { return f->name; }
int ck_is_kernel(const ck_func *f) { return f->iskernel; }
int ck_ret(const ck_func *f, int *n) { if (n) *n = f->retn; return f->retkind; }
int ck_nparams(const ck_func *f) { return f->nparams; }
int ck_param(const ck_func *f, int i, int *n) { if (n) *n = f->params[i].n; return f->params[i].kind; }

/* ================= evaluation ================= */
typedef struct { int kind, n; float v[16]; } val;
typedef struct {
    val *slots;
    const ck_program *pg;
    ck_host *host;
    int ret, brk, cont;
    val retv;
    int depth;
} frame;

static val scalar(float f) { val v; v.kind = CK_FLOAT; v.n = 1; v.v[0] = f; return v; }
static int width(const val *v) { return v->kind == CK_MAT ? v->n * v->n : v->n; }
static float comp(const val *v, int i) { return v->n == 1 && v->kind != CK_MAT ? v->v[0] : v->v[i]; }
static val eval(frame *fr, node *n);
static val call_func(frame *fr, const ck_func *f, val *args, int nargs);

static val *lvalue(frame *fr, node *n) { return n->op == N_VAR ? &fr->slots[n->iv] : NULL; }
static void store(frame *fr, node *target, val v) {
    if (target->op == N_VAR) {
        val *d = &fr->slots[target->iv];
        if (d->kind == CK_INT && v.kind == CK_FLOAT) for (int i = 0; i < width(&v); i++) v.v[i] = truncf(v.v[i]);
        int keep = d->kind; int keepn = d->n;
        if (keep != CK_VOID && keepn > 0 && v.n == 1 && v.kind != CK_MAT && (keepn > 1 || keep == CK_MAT)) {   /* scalar to vector: broadcast */
            for (int i = 0; i < (keep == CK_MAT ? keepn * keepn : keepn); i++) d->v[i] = v.v[0];
            return;
        }
        *d = v;
        if (keep != CK_VOID && keep != v.kind && keep != CK_MAT) d->kind = keep;
        return;
    }
    if (target->op == N_SWZ) {
        node *base = target->k[0];
        val b = eval(fr, base);
        for (int i = 0; i < target->nsw; i++) b.v[target->sw[i]] = comp(&v, i);
        store(fr, base, b);
        return;
    }
    if (target->op == N_INDEX) {
        node *base = target->k[0];
        val b = eval(fr, base), ix = eval(fr, target->k[1]);
        int i = (int)ix.v[0];
        if (b.kind == CK_MAT) { if (i >= 0 && i < b.n) for (int r = 0; r < b.n; r++) b.v[i * b.n + r] = comp(&v, r); }
        else if (i >= 0 && i < 16) b.v[i] = v.v[0];
        store(fr, base, b);
    }
}
static int truthy(const val *v) { return v->v[0] != 0; }
static val binop(int op, val a, val b) {
    val r;
    /* matrix products (column-major) */
    if (op == ('*' << 8) && (a.kind == CK_MAT || b.kind == CK_MAT)) {
        if (a.kind == CK_MAT && b.kind == CK_MAT) {
            int n = a.n; r.kind = CK_MAT; r.n = n;
            for (int c = 0; c < n; c++) for (int rr = 0; rr < n; rr++) { float s = 0; for (int k = 0; k < n; k++) s += a.v[k * n + rr] * b.v[c * n + k]; r.v[c * n + rr] = s; }
            return r;
        }
        if (a.kind == CK_MAT && b.n == a.n) {
            int n = a.n; r.kind = CK_FLOAT; r.n = n;
            for (int rr = 0; rr < n; rr++) { float s = 0; for (int k = 0; k < n; k++) s += a.v[k * n + rr] * b.v[k]; r.v[rr] = s; }
            return r;
        }
        if (b.kind == CK_MAT && a.n == b.n) {
            int n = b.n; r.kind = CK_FLOAT; r.n = n;
            for (int c = 0; c < n; c++) { float s = 0; for (int k = 0; k < n; k++) s += a.v[k] * b.v[c * n + k]; r.v[c] = s; }
            return r;
        }
        if (a.kind == CK_MAT) { r = a; for (int i = 0; i < a.n * a.n; i++) r.v[i] *= b.v[0]; return r; }
        r = b; for (int i = 0; i < b.n * b.n; i++) r.v[i] *= a.v[0]; return r;
    }
    int n = a.n > b.n ? a.n : b.n;
    if (a.kind == CK_MAT || b.kind == CK_MAT) n = (a.kind == CK_MAT ? a.n * a.n : b.n * b.n);
    int isint = a.kind == CK_INT && b.kind == CK_INT;
    int cmp = op == ('=' << 8 | '=') || op == ('!' << 8 | '=') || op == ('<' << 8) || op == ('>' << 8) || op == ('<' << 8 | '=') || op == ('>' << 8 | '=');
    r.kind = cmp ? CK_BOOL : (a.kind == CK_MAT || b.kind == CK_MAT) ? CK_MAT : isint ? CK_INT : a.kind == CK_BOOL && b.kind == CK_BOOL ? CK_BOOL : CK_FLOAT;
    r.n = r.kind == CK_MAT ? (a.kind == CK_MAT ? a.n : b.n) : n;
    for (int i = 0; i < n; i++) {
        float x = comp(&a, i), y = comp(&b, i), z = 0;
        switch (op) {
        case '+' << 8: z = x + y; break;
        case '-' << 8: z = x - y; break;
        case '*' << 8: z = x * y; break;
        case '/' << 8: z = isint ? (y != 0 ? truncf(x / y) : 0) : x / y; break;
        case '%' << 8: z = y != 0 ? fmodf(x, y) : 0; break;
        case '&' << 8: z = (float)((long)x & (long)y); break;
        case '|' << 8: z = (float)((long)x | (long)y); break;
        case '^' << 8: z = (float)((long)x ^ (long)y); break;
        case ('<' << 8 | '<'): z = (float)((long)x << (long)y); break;
        case ('>' << 8 | '>'): z = (float)((long)x >> (long)y); break;
        case ('=' << 8 | '='): z = x == y; break;
        case ('!' << 8 | '='): z = x != y; break;
        case '<' << 8: z = x < y; break;
        case '>' << 8: z = x > y; break;
        case ('<' << 8 | '='): z = x <= y; break;
        case ('>' << 8 | '='): z = x >= y; break;
        }
        r.v[i] = z;
    }
    /* scalar comparisons of vectors in GLSL are not allowed; == on vectors is "all equal" */
    if (cmp && n > 1 && (op == ('=' << 8 | '=') || op == ('!' << 8 | '='))) {
        int all = 1; for (int i = 0; i < n; i++) all &= op == ('=' << 8 | '=') ? r.v[i] != 0 : r.v[i] == 0;
        if (op == ('!' << 8 | '=')) { int anyd = 0; for (int i = 0; i < n; i++) anyd |= comp(&a, i) != comp(&b, i); r.n = 1; r.v[0] = anyd; return r; }
        r.n = 1; r.v[0] = all;
    }
    return r;
}
static float clampf_(float x, float a, float b) { return x < a ? a : x > b ? b : x; }
static val builtin(frame *fr, node *n) {
    int id = n->iv;
    val a[8]; int na = n->nk < 8 ? n->nk : 8;
    const char *name = BUILTINS[id];
    /* sampler arguments are not evaluated to values */
    int sampler_fn = !strcmp(name, "sample") || !strncmp(name, "sampler", 7) || !strncmp(name, "m_", 2);
    for (int i = 0; i < na; i++) a[i] = eval(fr, n->k[i]);
    val r; memset(&r, 0, sizeof r); r.kind = CK_FLOAT; r.n = na ? a[0].n : 1;
    if (r.n < 1) r.n = 1;
    if (sampler_fn) {
        ck_host *h = fr->host;
        int s = na ? (int)a[0].v[0] : 0;
        double x, y;
        if (!strcmp(name, "destCoord") || (!strcmp(name, "m_coord") && na && a[0].kind == CK_DEST) || !strcmp(name, "m_dcoord")) { h->dest(h, &x, &y); r.n = 2; r.v[0] = (float)x; r.v[1] = (float)y; return r; }
        if (!strcmp(name, "sample") || !strcmp(name, "m_sample")) {
            r.n = 4;
            if (na >= 2) h->sample(h, s, a[1].v[0], a[1].v[1], r.v);
            return r;
        }
        if (!strcmp(name, "samplerCoord") || !strcmp(name, "m_coord")) { h->dest(h, &x, &y); h->transform(h, s, x, y, &x, &y); r.n = 2; r.v[0] = (float)x; r.v[1] = (float)y; return r; }
        if (!strcmp(name, "samplerTransform") || !strcmp(name, "m_transform")) { h->transform(h, s, na > 1 ? a[1].v[0] : 0, na > 1 ? a[1].v[1] : 0, &x, &y); r.n = 2; r.v[0] = (float)x; r.v[1] = (float)y; return r; }
        double e[4]; h->extent(h, s, e);
        if (!strcmp(name, "samplerExtent") || !strcmp(name, "m_extent")) { r.n = 4; for (int i = 0; i < 4; i++) r.v[i] = (float)e[i]; return r; }
        if (!strcmp(name, "samplerOrigin") || !strcmp(name, "m_origin")) { r.n = 2; r.v[0] = (float)e[0]; r.v[1] = (float)e[1]; return r; }
        r.n = 2; r.v[0] = (float)e[2]; r.v[1] = (float)e[3]; return r;      /* size */
    }
    int w = width(&a[0]);
#define EACH(expr_) do { for (int i_ = 0; i_ < w; i_++) { float x = a[0].v[i_]; (void)x; r.v[i_] = (expr_); } } while (0)
#define EACH2(expr_) do { int w2_ = na > 1 && width(&a[1]) > w ? width(&a[1]) : w; r.n = w2_; for (int i_ = 0; i_ < w2_; i_++) { float x = comp(&a[0], i_), y = comp(&a[1], i_); (void)x; (void)y; r.v[i_] = (expr_); } } while (0)
    if (!strcmp(name, "radians")) EACH(x * (float)M_PI / 180);
    else if (!strcmp(name, "degrees")) EACH(x * 180 / (float)M_PI);
    else if (!strcmp(name, "sin")) EACH(sinf(x));
    else if (!strcmp(name, "cos")) EACH(cosf(x));
    else if (!strcmp(name, "tan")) EACH(tanf(x));
    else if (!strcmp(name, "asin")) EACH(asinf(x));
    else if (!strcmp(name, "acos")) EACH(acosf(x));
    else if (!strcmp(name, "atan")) { if (na > 1) EACH2(atan2f(x, y)); else EACH(atanf(x)); }
    else if (!strcmp(name, "atan2")) EACH2(atan2f(x, y));
    else if (!strcmp(name, "sinh")) EACH(sinhf(x));
    else if (!strcmp(name, "cosh")) EACH(coshf(x));
    else if (!strcmp(name, "tanh")) EACH(tanhf(x));
    else if (!strcmp(name, "pow") || !strcmp(name, "powr")) EACH2(powf(x, y));
    else if (!strcmp(name, "exp")) EACH(expf(x));
    else if (!strcmp(name, "exp2")) EACH(exp2f(x));
    else if (!strcmp(name, "exp10")) EACH(powf(10, x));
    else if (!strcmp(name, "log")) EACH(logf(x));
    else if (!strcmp(name, "log2")) EACH(log2f(x));
    else if (!strcmp(name, "log10")) EACH(log10f(x));
    else if (!strcmp(name, "sqrt")) EACH(sqrtf(x));
    else if (!strcmp(name, "rsqrt") || !strcmp(name, "inversesqrt")) EACH(1 / sqrtf(x));
    else if (!strcmp(name, "abs") || !strcmp(name, "fabs")) { EACH(fabsf(x)); r.kind = a[0].kind; }
    else if (!strcmp(name, "sign")) EACH(x > 0 ? 1.0f : x < 0 ? -1.0f : 0.0f);
    else if (!strcmp(name, "floor")) EACH(floorf(x));
    else if (!strcmp(name, "ceil")) EACH(ceilf(x));
    else if (!strcmp(name, "round") || !strcmp(name, "rint")) EACH(roundf(x));
    else if (!strcmp(name, "trunc")) EACH(truncf(x));
    else if (!strcmp(name, "fract")) EACH(x - floorf(x));
    else if (!strcmp(name, "mod")) EACH2(x - y * floorf(x / y));
    else if (!strcmp(name, "fmod")) EACH2(fmodf(x, y));
    else if (!strcmp(name, "min") || !strcmp(name, "fmin")) { EACH2(fminf(x, y)); if (a[0].kind == CK_INT && a[1].kind == CK_INT) r.kind = CK_INT; }
    else if (!strcmp(name, "max") || !strcmp(name, "fmax")) { EACH2(fmaxf(x, y)); if (a[0].kind == CK_INT && a[1].kind == CK_INT) r.kind = CK_INT; }
    else if (!strcmp(name, "copysign")) EACH2(copysignf(x, y));
    else if (!strcmp(name, "clamp")) { for (int i = 0; i < w; i++) r.v[i] = clampf_(a[0].v[i], comp(&a[1], i), comp(&a[2], i)); r.n = a[0].n; }
    else if (!strcmp(name, "saturate")) EACH(clampf_(x, 0, 1));
    else if (!strcmp(name, "mix")) { int ww = w; for (int k = 1; k < 3 && k < na; k++) if (width(&a[k]) > ww) ww = width(&a[k]); r.n = ww; for (int i = 0; i < ww; i++) { float x = comp(&a[0], i), y = comp(&a[1], i), t = comp(&a[2], i); r.v[i] = x + (y - x) * t; } }
    else if (!strcmp(name, "select")) { r = a[0]; for (int i = 0; i < w; i++) r.v[i] = comp(&a[2], i) != 0 ? comp(&a[1], i) : comp(&a[0], i); r.n = a[0].n > a[1].n ? a[0].n : a[1].n; }
    else if (!strcmp(name, "step")) { int ww = width(&a[1]) > w ? width(&a[1]) : w; r.n = ww; for (int i = 0; i < ww; i++) r.v[i] = comp(&a[1], i) < comp(&a[0], i) ? 0 : 1; }
    else if (!strcmp(name, "smoothstep")) { int ww = width(&a[2]); r.n = ww; for (int i = 0; i < ww; i++) { float e0 = comp(&a[0], i), e1 = comp(&a[1], i), t = clampf_((comp(&a[2], i) - e0) / (e1 - e0), 0, 1); r.v[i] = t * t * (3 - 2 * t); } }
    else if (!strcmp(name, "fma") || !strcmp(name, "mad")) { for (int i = 0; i < w; i++) r.v[i] = a[0].v[i] * comp(&a[1], i) + comp(&a[2], i); }
    else if (!strcmp(name, "length")) { float s = 0; for (int i = 0; i < w; i++) s += a[0].v[i] * a[0].v[i]; r.n = 1; r.v[0] = sqrtf(s); }
    else if (!strcmp(name, "length_squared")) { float s = 0; for (int i = 0; i < w; i++) s += a[0].v[i] * a[0].v[i]; r.n = 1; r.v[0] = s; }
    else if (!strcmp(name, "distance")) { float s = 0; for (int i = 0; i < w; i++) { float d = a[0].v[i] - comp(&a[1], i); s += d * d; } r.n = 1; r.v[0] = sqrtf(s); }
    else if (!strcmp(name, "dot")) { float s = 0; for (int i = 0; i < w; i++) s += a[0].v[i] * comp(&a[1], i); r.n = 1; r.v[0] = s; }
    else if (!strcmp(name, "cross")) { r.n = 3; r.v[0] = a[0].v[1] * a[1].v[2] - a[0].v[2] * a[1].v[1]; r.v[1] = a[0].v[2] * a[1].v[0] - a[0].v[0] * a[1].v[2]; r.v[2] = a[0].v[0] * a[1].v[1] - a[0].v[1] * a[1].v[0]; }
    else if (!strcmp(name, "normalize")) { float s = 0; for (int i = 0; i < w; i++) s += a[0].v[i] * a[0].v[i]; s = sqrtf(s); for (int i = 0; i < w; i++) r.v[i] = s > 0 ? a[0].v[i] / s : 0; }
    else if (!strcmp(name, "faceforward")) { float d = 0; for (int i = 0; i < w; i++) d += a[1].v[i] * a[2].v[i]; for (int i = 0; i < w; i++) r.v[i] = d < 0 ? a[0].v[i] : -a[0].v[i]; }
    else if (!strcmp(name, "reflect")) { float d = 0; for (int i = 0; i < w; i++) d += a[0].v[i] * a[1].v[i]; for (int i = 0; i < w; i++) r.v[i] = a[0].v[i] - 2 * d * a[1].v[i]; }
    else if (!strcmp(name, "any")) { float s = 0; for (int i = 0; i < w; i++) s = s || a[0].v[i] != 0; r.n = 1; r.kind = CK_BOOL; r.v[0] = s; }
    else if (!strcmp(name, "all")) { float s = 1; for (int i = 0; i < w; i++) s = s && a[0].v[i] != 0; r.n = 1; r.kind = CK_BOOL; r.v[0] = s; }
    else if (!strcmp(name, "not")) { EACH(x == 0); r.kind = CK_BOOL; }
    else if (!strcmp(name, "isnan")) { EACH(isnan(x)); r.kind = CK_BOOL; }
    else if (!strcmp(name, "isinf")) { EACH(isinf(x)); r.kind = CK_BOOL; }
    else if (!strcmp(name, "premultiply")) { r = a[0]; r.kind = CK_FLOAT; for (int i = 0; i < 3; i++) r.v[i] *= a[0].v[3]; }
    else if (!strcmp(name, "unpremultiply")) { r = a[0]; r.kind = CK_FLOAT; if (a[0].v[3] > 0) for (int i = 0; i < 3; i++) r.v[i] /= a[0].v[3]; }
    else if (!strcmp(name, "compare")) { r.n = a[1].n > a[2].n ? a[1].n : a[2].n; for (int i = 0; i < r.n; i++) r.v[i] = comp(&a[0], i) < 0 ? comp(&a[1], i) : comp(&a[2], i); }
    else if (!strcmp(name, "srgb_to_linear")) EACH(x <= 0.04045f ? x / 12.92f : powf((x + 0.055f) / 1.055f, 2.4f));
    else if (!strcmp(name, "linear_to_srgb")) EACH(x <= 0.0031308f ? x * 12.92f : 1.055f * powf(x, 1 / 2.4f) - 0.055f);
    else if (!strcmp(name, "divide")) EACH2(x / y);
#undef EACH
#undef EACH2
    return r;
}
static val ctor(frame *fr, node *n) {
    val r; memset(&r, 0, sizeof r);
    r.kind = n->kind; r.n = n->n;
    int want = n->kind == CK_MAT ? n->n * n->n : n->n, k = 0;
    if (n->kind == CK_MAT && n->nk == 1) {
        val a = eval(fr, n->k[0]);
        if (a.kind != CK_MAT && a.n == 1) { for (int i = 0; i < n->n; i++) r.v[i * n->n + i] = a.v[0]; return r; }
        if (a.kind == CK_MAT) { for (int c = 0; c < n->n; c++) for (int rr = 0; rr < n->n; rr++) r.v[c * n->n + rr] = c < a.n && rr < a.n ? a.v[c * a.n + rr] : c == rr; return r; }
    }
    for (int i = 0; i < n->nk && k < want; i++) {
        val a = eval(fr, n->k[i]);
        int w = width(&a);
        if (n->nk == 1 && w == 1 && want > 1) { for (int j = 0; j < want; j++) r.v[j] = a.v[0]; k = want; break; }
        for (int j = 0; j < w && k < want; j++) r.v[k++] = a.v[j];
    }
    if (n->kind == CK_INT) for (int i = 0; i < want; i++) r.v[i] = truncf(r.v[i]);
    if (n->kind == CK_BOOL) for (int i = 0; i < want; i++) r.v[i] = r.v[i] != 0;
    if (want == 16 && n->kind == CK_FLOAT) r.n = 16;      /* array initializer */
    return r;
}
static val eval(frame *fr, node *n) {
    switch (n->op) {
    case N_NUM: { val v = scalar(n->num); v.kind = n->kind; return v; }
    case N_VAR: return fr->slots[n->iv];
    case N_CTOR: return ctor(fr, n);
    case N_SWZ: {
        val b = eval(fr, n->k[0]), r; r.kind = b.kind == CK_MAT ? CK_FLOAT : b.kind; r.n = n->nsw;
        for (int i = 0; i < n->nsw; i++) r.v[i] = b.v[n->sw[i]];
        return r;
    }
    case N_INDEX: {
        val b = eval(fr, n->k[0]), ix = eval(fr, n->k[1]); int i = (int)ix.v[0];
        if (b.kind == CK_MAT) { val r; r.kind = CK_FLOAT; r.n = b.n; for (int k = 0; k < b.n; k++) r.v[k] = i >= 0 && i < b.n ? b.v[i * b.n + k] : 0; return r; }
        val r = scalar(i >= 0 && i < 16 ? b.v[i] : 0); r.kind = b.kind; return r;
    }
    case N_ASSIGN: { val v = eval(fr, n->k[1]); store(fr, n->k[0], v); return lvalue(fr, n->k[0]) ? *lvalue(fr, n->k[0]) : v; }
    case N_OPASSIGN: {
        val a = eval(fr, n->k[0]), b = eval(fr, n->k[1]), v = binop(n->iv, a, b);
        if (a.kind == CK_INT) v.kind = CK_INT;
        if (a.n > v.n && a.kind != CK_MAT) { val t = a; for (int i = 0; i < a.n; i++) t.v[i] = comp(&v, i); v = t; }
        store(fr, n->k[0], v); return v;
    }
    case N_PREINC: case N_POSTINC: {
        val a = eval(fr, n->k[0]), b = a;
        for (int i = 0; i < width(&a); i++) b.v[i] += (float)n->iv;
        store(fr, n->k[0], b);
        return n->op == N_PREINC ? b : a;
    }
    case N_BIN: return binop(n->iv, eval(fr, n->k[0]), eval(fr, n->k[1]));
    case N_AND: { val a = eval(fr, n->k[0]); if (!truthy(&a)) { val r = scalar(0); r.kind = CK_BOOL; return r; } val b = eval(fr, n->k[1]); val r = scalar(truthy(&b)); r.kind = CK_BOOL; return r; }
    case N_OR: { val a = eval(fr, n->k[0]); if (truthy(&a)) { val r = scalar(1); r.kind = CK_BOOL; return r; } val b = eval(fr, n->k[1]); val r = scalar(truthy(&b)); r.kind = CK_BOOL; return r; }
    case N_NEG: { val a = eval(fr, n->k[0]); for (int i = 0; i < width(&a); i++) a.v[i] = -a.v[i]; return a; }
    case N_NOT: { val a = eval(fr, n->k[0]); for (int i = 0; i < width(&a); i++) a.v[i] = a.v[i] == 0; a.kind = CK_BOOL; return a; }
    case N_BNOT: { val a = eval(fr, n->k[0]); for (int i = 0; i < width(&a); i++) a.v[i] = (float)~(long)a.v[i]; return a; }
    case N_TERN: { val c = eval(fr, n->k[0]); return eval(fr, truthy(&c) ? n->k[1] : n->k[2]); }
    case N_COMMA: eval(fr, n->k[0]); return eval(fr, n->k[1]);
    case N_BUILTIN: return builtin(fr, n);
    case N_CALL: {
        const ck_func *f = fr->pg->f[n->iv];
        val args[24]; int na = n->nk < 24 ? n->nk : 24;
        for (int i = 0; i < na; i++) args[i] = eval(fr, n->k[i]);
        val r = call_func(fr, f, args, na);
        /* out / inout parameters are not written back (value semantics) */
        return r;
    }
    default: { val v = scalar(0); return v; }
    }
}
static void exec(frame *fr, node *s) {
    if (fr->ret || fr->brk || fr->cont) return;
    switch (s->op) {
    case S_BLOCK: for (int i = 0; i < s->nk && !fr->ret && !fr->brk && !fr->cont; i++) exec(fr, s->k[i]); break;
    case S_DECL: {
        val *d = &fr->slots[s->iv];
        if (s->nk) {
            val v = eval(fr, s->k[0]);
            if (s->kind != CK_MAT && s->n > 1 && v.n == 1) { val t; t.kind = s->kind; t.n = s->n; for (int i = 0; i < s->n; i++) t.v[i] = v.v[0]; v = t; }
            if (s->kind == CK_INT) for (int i = 0; i < width(&v); i++) v.v[i] = truncf(v.v[i]);
            if (s->kind != CK_SAMPLER && s->kind != CK_DEST) v.kind = s->kind == CK_SAMPLE ? CK_FLOAT : v.kind == CK_MAT ? CK_MAT : s->kind;
            if (s->n < 0) v.n = -s->n;
            *d = v;
        } else { memset(d, 0, sizeof *d); d->kind = s->kind; d->n = s->n < 0 ? -s->n : s->n; }
        break;
    }
    case S_EXPR: eval(fr, s->k[0]); break;
    case S_IF: { val c = eval(fr, s->k[0]); if (truthy(&c)) exec(fr, s->k[1]); else if (s->nk > 2) exec(fr, s->k[2]); break; }
    case S_FOR: {
        exec(fr, s->k[0]);
        for (int guard = 0; guard < 1000000; guard++) {
            if (s->k[1]) { val c = eval(fr, s->k[1]); if (!truthy(&c)) break; }
            exec(fr, s->k[3]);
            if (fr->ret) break;
            if (fr->brk) { fr->brk = 0; break; }
            fr->cont = 0;
            if (s->k[2]) eval(fr, s->k[2]);
        }
        break;
    }
    case S_WHILE:
        for (int guard = 0; guard < 1000000; guard++) {
            val c = eval(fr, s->k[0]); if (!truthy(&c)) break;
            exec(fr, s->k[1]);
            if (fr->ret) break;
            if (fr->brk) { fr->brk = 0; break; }
            fr->cont = 0;
        }
        break;
    case S_DO:
        for (int guard = 0; guard < 1000000; guard++) {
            exec(fr, s->k[0]);
            if (fr->ret) break;
            if (fr->brk) { fr->brk = 0; break; }
            fr->cont = 0;
            val c = eval(fr, s->k[1]); if (!truthy(&c)) break;
        }
        break;
    case S_RETURN: fr->retv = s->nk ? eval(fr, s->k[0]) : scalar(0); fr->ret = 1; break;
    case S_BREAK: fr->brk = 1; break;
    case S_CONTINUE: fr->cont = 1; break;
    default: break;
    }
}
static val call_func(frame *caller, const ck_func *f, val *args, int nargs) {
    val slots[f->nslots > 0 ? f->nslots : 1];
    memset(slots, 0, sizeof slots);
    for (int i = 0; i < f->nparams && i < nargs; i++) {
        slots[i] = args[i];
        int k = f->params[i].kind;
        if (k == CK_FLOAT || k == CK_INT || k == CK_BOOL) {
            if (args[i].n == 1 && f->params[i].n > 1) { for (int j = 0; j < f->params[i].n; j++) slots[i].v[j] = args[i].v[0]; slots[i].n = f->params[i].n; }
            slots[i].kind = k;
        }
    }
    frame fr = { slots, caller->pg, caller->host, 0, 0, 0, { 0 }, caller->depth + 1 };
    if (fr.depth < 64) exec(&fr, f->body);
    return fr.retv;
}

int ck_run(const ck_program *pg, const ck_func *f, const ck_arg *args, int nargs, ck_host *host, float out[4]) {
    val a[24]; int na = 0;
    for (int i = 0; i < f->nparams && na < 24; i++) {
        val *v = &a[na++]; memset(v, 0, sizeof *v);
        int k = f->params[i].kind;
        v->kind = k == CK_SAMPLE || k == CK_COLOR ? CK_FLOAT : k; v->n = f->params[i].n;
        if (k == CK_DEST) { v->kind = CK_DEST; continue; }
        const ck_arg *src = i < nargs ? &args[i] : NULL;
        if (!src) continue;
        if (k == CK_SAMPLER) { v->kind = CK_SAMPLER; v->v[0] = (float)src->sampler; continue; }
        int w = k == CK_MAT ? f->params[i].n * f->params[i].n : f->params[i].n;
        for (int j = 0; j < w && j < 16; j++) v->v[j] = src->n == 1 ? src->v[0] : j < src->n ? src->v[j] : 0;
    }
    frame fr = { NULL, pg, host, 0, 0, 0, { 0 }, 0 };
    val r = call_func(&fr, f, a, na);
    for (int i = 0; i < 4; i++) out[i] = i < width(&r) ? r.v[i] : (i == 3 ? 1 : 0);
    if (width(&r) == 2) { out[2] = 0; out[3] = 0; }
    return width(&r);
}
