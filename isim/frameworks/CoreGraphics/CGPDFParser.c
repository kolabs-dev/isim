/* isim CoreGraphics: reading a PDF's objects (adapted: isim's own parser; poppler, which renders pages, does not
 * expose them). It reads the cross-reference data (tables, xref streams, hybrid files, /Prev chains of incremental
 * updates; a damaged one is rebuilt by scanning for "n g obj"), objects in the file and in object streams, decodes
 * streams (Flate and LZW with PNG / TIFF predictors, ASCIIHex, ASCII85, RunLength; JPEG and JPEG 2000 data is returned
 * as is) and decrypts documents of the standard security handler (RC4 and AES, revisions 2 to 6). Objects are resolved
 * on access, as Core Graphics' accessors do. Also: the public CGPDFObject / Array / Dictionary / String / Stream API. */
#include "cg_pdf.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>

/* ---------------- arena ---------------- */
struct chunk { struct chunk *next; size_t used, cap; unsigned char mem[]; };
struct xent { int type; size_t off; int gen, stm, idx; struct CGPDFObject *obj; int loading; };   /* 1 in the file, 2 in a stream */
struct pdoc {
    const unsigned char *data; size_t len;
    struct chunk *arena;
    struct xent *x; int nx;
    struct CGPDFDictionary *trailer;
    int major, minor;
    /* encryption */
    struct CGPDFDictionary *encrypt; int encrypt_num;
    int encrypted, unlocked, V, R, keylen, owner;
    int stm_method, str_method;              /* 0 identity, 1 RC4, 2 AES-128, 3 AES-256 */
    uint8_t key[32];
    uint32_t P; int encrypt_metadata;
    char password[128];
    struct CGPDFDictionary **pages; int npages;
};

void *isim_pdf_arena_alloc(struct pdoc *d, size_t n) {
    n = (n + 15) & ~(size_t)15;
    if (!d->arena || d->arena->used + n > d->arena->cap) {
        size_t cap = n > 65536 ? n : 65536;
        struct chunk *c = malloc(sizeof *c + cap);
        if (!c) return NULL;
        c->next = d->arena; c->used = 0; c->cap = cap; d->arena = c;
    }
    void *p = d->arena->mem + d->arena->used;
    d->arena->used += n;
    memset(p, 0, n);
    return p;
}
static char *astrdup(struct pdoc *d, const char *s, size_t n) {
    char *r = isim_pdf_arena_alloc(d, n + 1);
    memcpy(r, s, n); r[n] = 0;
    return r;
}

/* ---------------- lexer ---------------- */
enum { T_EOF, T_INT, T_REAL, T_NAME, T_STR, T_LBRACK, T_RBRACK, T_LDICT, T_RDICT, T_WORD, T_LBRACE, T_RBRACE };
static int is_ws(int c) { return c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32; }
static int is_delim(int c) { return c == '(' || c == ')' || c == '<' || c == '>' || c == '[' || c == ']' || c == '{' || c == '}' || c == '/' || c == '%'; }
static int hexv(int c) { return c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1; }
typedef struct { int t; long i; double r; const unsigned char *s; size_t n; struct CGPDFString *str; } tok;

static void skip_ws(pdflex *lx) {
    while (lx->p < lx->end) {
        if (is_ws(*lx->p)) lx->p++;
        else if (*lx->p == '%') { while (lx->p < lx->end && *lx->p != '\n' && *lx->p != '\r') lx->p++; }
        else break;
    }
}
static struct CGPDFString *new_str(struct pdoc *d, size_t cap) {
    struct CGPDFString *s = isim_pdf_arena_alloc(d, sizeof *s);
    s->bytes = isim_pdf_arena_alloc(d, cap + 1);
    return s;
}
static int next_tok(pdflex *lx, tok *t) {
    skip_ws(lx);
    memset(t, 0, sizeof *t);
    if (lx->p >= lx->end) return t->t = T_EOF;
    int c = *lx->p;
    if (c == '[') { lx->p++; return t->t = T_LBRACK; }
    if (c == ']') { lx->p++; return t->t = T_RBRACK; }
    if (c == '{') { lx->p++; return t->t = T_LBRACE; }
    if (c == '}') { lx->p++; return t->t = T_RBRACE; }
    if (c == '<' && lx->p + 1 < lx->end && lx->p[1] == '<') { lx->p += 2; return t->t = T_LDICT; }
    if (c == '>' && lx->p + 1 < lx->end && lx->p[1] == '>') { lx->p += 2; return t->t = T_RDICT; }
    if (c == '/') {
        lx->p++;
        const unsigned char *s = lx->p;
        while (lx->p < lx->end && !is_ws(*lx->p) && !is_delim(*lx->p)) lx->p++;
        size_t n = (size_t)(lx->p - s);
        char *name = isim_pdf_arena_alloc(lx->doc, n + 1);
        size_t k = 0;
        for (size_t i = 0; i < n; i++) {                               /* #xx escapes */
            if (s[i] == '#' && i + 2 < n && hexv(s[i + 1]) >= 0 && hexv(s[i + 2]) >= 0) {
                name[k++] = (char)(hexv(s[i + 1]) * 16 + hexv(s[i + 2])); i += 2;
            } else name[k++] = (char)s[i];
        }
        name[k] = 0;
        t->s = (const unsigned char *)name; t->n = k;
        return t->t = T_NAME;
    }
    if (c == '(') {                                                    /* literal string */
        lx->p++;
        const unsigned char *start = lx->p;
        struct CGPDFString *s = new_str(lx->doc, (size_t)(lx->end - start));
        size_t k = 0; int depth = 1;
        while (lx->p < lx->end) {
            int ch = *lx->p++;
            if (ch == '(') { depth++; s->bytes[k++] = '('; }
            else if (ch == ')') { if (--depth == 0) break; s->bytes[k++] = ')'; }
            else if (ch == '\\' && lx->p < lx->end) {
                int e = *lx->p++;
                switch (e) {
                case 'n': s->bytes[k++] = '\n'; break;
                case 'r': s->bytes[k++] = '\r'; break;
                case 't': s->bytes[k++] = '\t'; break;
                case 'b': s->bytes[k++] = '\b'; break;
                case 'f': s->bytes[k++] = '\f'; break;
                case '\r': if (lx->p < lx->end && *lx->p == '\n') lx->p++; break;   /* line continuation */
                case '\n': break;
                default:
                    if (e >= '0' && e <= '7') {
                        int v = e - '0';
                        for (int i = 0; i < 2 && lx->p < lx->end && *lx->p >= '0' && *lx->p <= '7'; i++) v = v * 8 + (*lx->p++ - '0');
                        s->bytes[k++] = (unsigned char)v;
                    } else s->bytes[k++] = (unsigned char)e;
                }
            } else if (ch == '\r') {                                   /* end of line: one \n */
                if (lx->p < lx->end && *lx->p == '\n') lx->p++;
                s->bytes[k++] = '\n';
            } else s->bytes[k++] = (unsigned char)ch;
        }
        s->len = k;
        t->str = s;
        return t->t = T_STR;
    }
    if (c == '<') {                                                    /* hex string */
        lx->p++;
        struct CGPDFString *s = new_str(lx->doc, (size_t)(lx->end - lx->p) / 2 + 1);
        size_t k = 0; int hi = -1;
        while (lx->p < lx->end && *lx->p != '>') {
            int v = hexv(*lx->p++);
            if (v < 0) continue;
            if (hi < 0) hi = v; else { s->bytes[k++] = (unsigned char)(hi * 16 + v); hi = -1; }
        }
        if (hi >= 0) s->bytes[k++] = (unsigned char)(hi * 16);
        if (lx->p < lx->end) lx->p++;
        s->len = k;
        t->str = s;
        return t->t = T_STR;
    }
    if (c == '+' || c == '-' || c == '.' || (c >= '0' && c <= '9')) {
        const unsigned char *s = lx->p;
        int real = 0;
        lx->p++;
        while (lx->p < lx->end && ((*lx->p >= '0' && *lx->p <= '9') || *lx->p == '.' || *lx->p == '-')) { if (*lx->p == '.') real = 1; lx->p++; }
        if (*s == '.') real = 1;
        char buf[64]; size_t n = (size_t)(lx->p - s) < 63 ? (size_t)(lx->p - s) : 63;
        memcpy(buf, s, n); buf[n] = 0;
        if (real) { t->r = strtod(buf, NULL); return t->t = T_REAL; }
        t->i = strtol(buf, NULL, 10);
        return t->t = T_INT;
    }
    const unsigned char *s = lx->p;                                    /* a keyword */
    while (lx->p < lx->end && !is_ws(*lx->p) && !is_delim(*lx->p)) lx->p++;
    if (lx->p == s) lx->p++;                                           /* a stray delimiter (')' or '>') */
    t->s = s; t->n = (size_t)(lx->p - s);
    return t->t = T_WORD;
}
static int word_is(const tok *t, const char *w) { return t->t == T_WORD && t->n == strlen(w) && !memcmp(t->s, w, t->n); }

/* ---------------- objects ---------------- */
static int parse_value(pdflex *lx, tok *t, struct CGPDFObject *o, int refs, int depth);
static int parse_object(pdflex *lx, struct CGPDFObject *o, int refs, int depth) {
    tok t;
    if (next_tok(lx, &t) == T_EOF) return 0;
    return parse_value(lx, &t, o, refs, depth);
}
/* the value starting with token t; refs: "n g R" is a reference (not in content streams) */
static int parse_value(pdflex *lx, tok *t, struct CGPDFObject *o, int refs, int depth) {
    memset(o, 0, sizeof *o);
    if (depth > 64) return 0;
    switch (t->t) {
    case T_INT:
        if (refs) {                                                    /* n g R? */
            const unsigned char *save = lx->p;
            tok t2, t3;
            if (next_tok(lx, &t2) == T_INT && next_tok(lx, &t3) == T_WORD && word_is(&t3, "R")) {
                o->type = PDF_REF; o->v.ref.num = (int)t->i; o->v.ref.gen = (int)t2.i; return 1;
            }
            lx->p = save;
        }
        o->type = kCGPDFObjectTypeInteger; o->v.i = t->i; return 1;
    case T_REAL: o->type = kCGPDFObjectTypeReal; o->v.r = t->r; return 1;
    case T_NAME: o->type = kCGPDFObjectTypeName; o->v.name = (const char *)t->s; return 1;
    case T_STR: o->type = kCGPDFObjectTypeString; o->v.str = t->str; return 1;
    case T_LBRACK: {
        size_t cap = 8, n = 0;
        struct CGPDFObject *items = malloc(cap * sizeof *items);
        tok u;
        while (next_tok(lx, &u) != T_EOF && u.t != T_RBRACK) {
            if (n == cap) { cap *= 2; items = realloc(items, cap * sizeof *items); }
            if (!parse_value(lx, &u, &items[n], refs, depth + 1)) break;
            n++;
        }
        struct CGPDFArray *a = isim_pdf_arena_alloc(lx->doc, sizeof *a);
        a->doc = lx->doc; a->n = n; a->items = isim_pdf_arena_alloc(lx->doc, (n ? n : 1) * sizeof *items);
        memcpy(a->items, items, n * sizeof *items);
        free(items);
        o->type = kCGPDFObjectTypeArray; o->v.arr = a;
        return 1;
    }
    case T_LDICT: {
        size_t cap = 8, n = 0;
        const char **keys = malloc(cap * sizeof *keys);
        struct CGPDFObject *vals = malloc(cap * sizeof *vals);
        tok k;
        while (next_tok(lx, &k) != T_EOF && k.t != T_RDICT) {
            if (k.t != T_NAME) continue;                               /* tolerate junk */
            tok v;
            if (next_tok(lx, &v) == T_EOF || v.t == T_RDICT) break;
            if (n == cap) { cap *= 2; keys = realloc(keys, cap * sizeof *keys); vals = realloc(vals, cap * sizeof *vals); }
            if (!parse_value(lx, &v, &vals[n], refs, depth + 1)) break;
            if (vals[n].type == kCGPDFObjectTypeNull) continue;        /* a null value: the key is absent */
            keys[n++] = (const char *)k.s;
        }
        struct CGPDFDictionary *d = isim_pdf_arena_alloc(lx->doc, sizeof *d);
        d->doc = lx->doc; d->n = n;
        d->keys = isim_pdf_arena_alloc(lx->doc, (n ? n : 1) * sizeof *keys);
        d->vals = isim_pdf_arena_alloc(lx->doc, (n ? n : 1) * sizeof *vals);
        memcpy(d->keys, keys, n * sizeof *keys); memcpy(d->vals, vals, n * sizeof *vals);
        free(keys); free(vals);
        o->type = kCGPDFObjectTypeDictionary; o->v.dict = d;
        return 1;
    }
    case T_WORD:
        if (word_is(t, "true") || word_is(t, "false")) { o->type = kCGPDFObjectTypeBoolean; o->v.b = word_is(t, "true"); return 1; }
        if (word_is(t, "null")) { o->type = kCGPDFObjectTypeNull; return 1; }
        o->type = -1; o->v.name = astrdup(lx->doc, (const char *)t->s, t->n);   /* an operator (content streams) */
        return 1;
    case T_LBRACE: case T_RBRACE:                                      /* PostScript calculator braces: kept as operators */
        o->type = -1; o->v.name = t->t == T_LBRACE ? "{" : "}";
        return 1;
    default: return 0;
    }
}
int isim_pdf_lex_object(pdflex *lx, struct CGPDFObject *o) { return parse_object(lx, o, 0, 0); }

static struct CGPDFObject *dict_raw(struct CGPDFDictionary *d, const char *key) {
    if (!d) return NULL;
    for (size_t i = 0; i < d->n; i++) if (!strcmp(d->keys[i], key)) return &d->vals[i];
    return NULL;
}
static struct CGPDFObject *load_object(struct pdoc *d, int num);
struct CGPDFObject *isim_pdf_resolve(struct pdoc *d, struct CGPDFObject *o) {
    for (int hops = 0; o && o->type == PDF_REF && hops < 32; hops++) o = load_object(d, o->v.ref.num);
    return o && o->type != PDF_REF ? o : NULL;
}
static struct CGPDFObject *dget(struct CGPDFDictionary *d, const char *key) { return d ? isim_pdf_resolve(d->doc, dict_raw(d, key)) : NULL; }
static long dint(struct CGPDFDictionary *d, const char *key, long def) {
    struct CGPDFObject *o = dget(d, key);
    return o && o->type == kCGPDFObjectTypeInteger ? o->v.i : o && o->type == kCGPDFObjectTypeReal ? (long)o->v.r : def;
}
static struct CGPDFDictionary *ddict(struct CGPDFDictionary *d, const char *key) {
    struct CGPDFObject *o = dget(d, key);
    return o && o->type == kCGPDFObjectTypeDictionary ? o->v.dict : o && o->type == kCGPDFObjectTypeStream ? o->v.stream->dict : NULL;
}
static const char *dname(struct CGPDFDictionary *d, const char *key) {
    struct CGPDFObject *o = dget(d, key);
    return o && o->type == kCGPDFObjectTypeName ? o->v.name : NULL;
}

/* ---------------- decryption ---------------- */
static void object_key(struct pdoc *d, int num, int gen, int aes, uint8_t *key, int *keylen) {
    if (d->stm_method == 3 || d->str_method == 3) { memcpy(key, d->key, 32); *keylen = 32; return; }   /* AES-256: the file key */
    uint8_t buf[32 + 9];
    memcpy(buf, d->key, (size_t)d->keylen);
    size_t n = (size_t)d->keylen;
    buf[n++] = (uint8_t)num; buf[n++] = (uint8_t)(num >> 8); buf[n++] = (uint8_t)(num >> 16);
    buf[n++] = (uint8_t)gen; buf[n++] = (uint8_t)(gen >> 8);
    if (aes) { memcpy(buf + n, "sAlT", 4); n += 4; }
    uint8_t h[16];
    isim_pdf_md5(buf, n, h);
    *keylen = d->keylen + 5 > 16 ? 16 : d->keylen + 5;
    memcpy(key, h, (size_t)*keylen);
}
/* decrypts bytes of object num/gen with a method (1 RC4, 2/3 AES): returns the new length */
static size_t decrypt_bytes(struct pdoc *d, int method, int num, int gen, unsigned char *buf, size_t n) {
    if (!method) return n;
    uint8_t key[32]; int kl;
    object_key(d, num, gen, method >= 2, key, &kl);
    if (method == 1) { isim_pdf_rc4(key, (size_t)kl, buf, n); return n; }
    if (n < 32 || n % 16) return n < 16 ? 0 : n;                       /* IV + at least one block */
    isim_pdf_aes_cbc_decrypt(key, kl, buf, buf + 16, n - 16);
    size_t m = n - 16;
    int pad = buf[16 + m - 1];
    if (pad >= 1 && pad <= 16 && (size_t)pad <= m) m -= (size_t)pad;
    memmove(buf, buf + 16, m);
    return m;
}
static void decrypt_tree(struct pdoc *d, struct CGPDFObject *o, int num, int gen, int depth) {
    if (!o || depth > 64) return;
    if (o->type == kCGPDFObjectTypeString) o->v.str->len = decrypt_bytes(d, d->str_method, num, gen, o->v.str->bytes, o->v.str->len);
    else if (o->type == kCGPDFObjectTypeArray) for (size_t i = 0; i < o->v.arr->n; i++) decrypt_tree(d, &o->v.arr->items[i], num, gen, depth + 1);
    else if (o->type == kCGPDFObjectTypeDictionary) for (size_t i = 0; i < o->v.dict->n; i++) decrypt_tree(d, &o->v.dict->vals[i], num, gen, depth + 1);
    else if (o->type == kCGPDFObjectTypeStream) for (size_t i = 0; i < o->v.stream->dict->n; i++) decrypt_tree(d, &o->v.stream->dict->vals[i], num, gen, depth + 1);
}

/* ---------------- indirect objects ---------------- */
static const unsigned char *find_bytes(const unsigned char *p, const unsigned char *end, const char *s) {
    size_t n = strlen(s);
    for (; p + n <= end; p++) if (*p == (unsigned char)s[0] && !memcmp(p, s, n)) return p;
    return NULL;
}
/* "num gen obj <object> [stream ... endstream]" at off; 0 if it is not one */
static int parse_indirect(struct pdoc *d, size_t off, int *num, int *gen, struct CGPDFObject *o) {
    if (off >= d->len) return 0;
    pdflex lx = { d, d->data + off, d->data + d->len };
    tok a, b, c;
    if (next_tok(&lx, &a) != T_INT || next_tok(&lx, &b) != T_INT || next_tok(&lx, &c) != T_WORD || !word_is(&c, "obj")) return 0;
    *num = (int)a.i; *gen = (int)b.i;
    if (!parse_object(&lx, o, 1, 0)) return 0;
    if (o->type == kCGPDFObjectTypeDictionary) {
        const unsigned char *save = lx.p;
        tok s;
        if (next_tok(&lx, &s) == T_WORD && word_is(&s, "stream")) {
            const unsigned char *p = lx.p;
            if (p < lx.end && *p == '\r') p++;
            if (p < lx.end && *p == '\n') p++;
            struct CGPDFStream *st = isim_pdf_arena_alloc(d, sizeof *st);
            st->doc = d; st->dict = o->v.dict; st->raw = p; st->num = *num; st->gen = *gen;
            struct CGPDFObject *lo = dict_raw(o->v.dict, "Length");
            long len = -1;
            if (lo && lo->type == kCGPDFObjectTypeInteger) len = lo->v.i;
            else if (lo && lo->type == PDF_REF && lo->v.ref.num != *num) {
                struct CGPDFObject *r = isim_pdf_resolve(d, lo);
                if (r && r->type == kCGPDFObjectTypeInteger) len = r->v.i;
            }
            const unsigned char *end = len >= 0 && p + len <= lx.end ? p + len : NULL;
            if (end) {                                                 /* check that endstream follows */
                pdflex chk = { d, end, lx.end };
                tok e;
                if (next_tok(&chk, &e) != T_WORD || !word_is(&e, "endstream")) end = NULL;
            }
            if (!end) {                                                /* a wrong /Length: up to endstream */
                const unsigned char *e = find_bytes(p, lx.end, "endstream");
                end = e ? e : lx.end;
                while (end > p && (end[-1] == '\n' || end[-1] == '\r')) end--;
            }
            st->len = (size_t)(end - p);
            o->type = kCGPDFObjectTypeStream; o->v.stream = st;
        } else lx.p = save;
    }
    return 1;
}
static struct CGPDFObject *load_from_objstm(struct pdoc *d, int stmnum, int num);
static struct CGPDFObject *load_object(struct pdoc *d, int num) {
    if (num <= 0 || num >= d->nx) return NULL;
    struct xent *e = &d->x[num];
    if (e->obj) return e->obj;
    if (e->loading || !e->type) return NULL;
    e->loading = 1;
    struct CGPDFObject *o = NULL;
    if (e->type == 1) {
        struct CGPDFObject tmp; int n, g;
        if (parse_indirect(d, e->off, &n, &g, &tmp) && n == num) {
            o = isim_pdf_arena_alloc(d, sizeof *o); *o = tmp;
            if (d->encrypted && d->unlocked && num != d->encrypt_num) {
                int xref = o->type == kCGPDFObjectTypeStream && dname(o->v.stream->dict, "Type") && !strcmp(dname(o->v.stream->dict, "Type"), "XRef");
                if (!xref) decrypt_tree(d, o, n, g, 0);
            }
        }
    } else if (e->type == 2) {
        o = load_from_objstm(d, e->stm, num);
    }
    e->loading = 0;
    e->obj = o;
    return o;
}

/* ---------------- streams: filters ---------------- */
typedef struct { unsigned char *p; size_t n, cap; } buf;
static void bput(buf *b, const unsigned char *p, size_t n) {
    if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 256; b->p = realloc(b->p, b->cap); }
    memcpy(b->p + b->n, p, n); b->n += n;
}
static void bputc(buf *b, unsigned char c) { bput(b, &c, 1); }
static int flate(const unsigned char *in, size_t n, buf *out) {
    z_stream z; memset(&z, 0, sizeof z);
    if (inflateInit(&z) != Z_OK) return 0;
    z.next_in = (Bytef *)in; z.avail_in = (uInt)n;
    unsigned char chunk[16384];
    int r;
    do {
        z.next_out = chunk; z.avail_out = sizeof chunk;
        r = inflate(&z, Z_NO_FLUSH);
        bput(out, chunk, sizeof chunk - z.avail_out);
    } while (r == Z_OK && (z.avail_in > 0 || z.avail_out == 0));
    inflateEnd(&z);
    return r == Z_STREAM_END || r == Z_OK || r == Z_BUF_ERROR || out->n > 0;     /* truncated data: what decoded */
}
static int lzw(const unsigned char *in, size_t n, int early, buf *out) {
    int *prefix = malloc(4096 * sizeof *prefix), *len = malloc(4096 * sizeof *len);
    unsigned char *suffix = malloc(4096), *first = malloc(4096);
    for (int i = 0; i < 256; i++) { prefix[i] = -1; suffix[i] = first[i] = (unsigned char)i; len[i] = 1; }
    int next = 258, bits = 9, prev = -1;
    unsigned long acc = 0; int nacc = 0;
    for (size_t i = 0;;) {
        while (nacc < bits && i < n) { acc = (acc << 8 | in[i++]) & 0xFFFFFFul; nacc += 8; }
        if (nacc < bits) break;
        int code = (int)((acc >> (nacc - bits)) & ((1u << bits) - 1)); nacc -= bits;
        if (code == 256) { next = 258; bits = 9; prev = -1; continue; }
        if (code == 257) break;
        if (code > next || (code == next && prev < 0) || (code >= 256 && code < 258)) break;   /* bad data */
        if (code == next && next < 4096) {                             /* KwKwK: the entry being defined */
            prefix[next] = prev; suffix[next] = first[prev]; first[next] = first[prev]; len[next] = len[prev] + 1; next++;
        } else if (prev >= 0 && next < 4096) {
            prefix[next] = prev; suffix[next] = first[code]; first[next] = first[prev]; len[next] = len[prev] + 1; next++;
        }
        size_t l = (size_t)len[code];
        if (out->n + l > out->cap) { out->cap = (out->n + l) * 2 + 256; out->p = realloc(out->p, out->cap); }
        for (int k = code, at = (int)l - 1; at >= 0 && k >= 0; at--, k = prefix[k]) out->p[out->n + (size_t)at] = suffix[k];
        out->n += l;
        prev = code;
        if (next + early >= (1 << bits) && bits < 12) bits++;
    }
    free(prefix); free(len); free(suffix); free(first);
    return 1;
}
static int ahx(const unsigned char *in, size_t n, buf *out) {
    int hi = -1;
    for (size_t i = 0; i < n && in[i] != '>'; i++) {
        int v = hexv(in[i]);
        if (v < 0) continue;
        if (hi < 0) hi = v; else { bputc(out, (unsigned char)(hi * 16 + v)); hi = -1; }
    }
    if (hi >= 0) bputc(out, (unsigned char)(hi * 16));
    return 1;
}
static int a85(const unsigned char *in, size_t n, buf *out) {
    uint32_t v = 0; int k = 0;
    size_t i = 0;
    if (n >= 2 && in[0] == '<' && in[1] == '~') i = 2;
    for (; i < n; i++) {
        int c = in[i];
        if (c == '~') break;
        if (is_ws(c)) continue;
        if (c == 'z' && k == 0) { unsigned char z4[4] = { 0 }; bput(out, z4, 4); continue; }
        if (c < '!' || c > 'u') return 0;
        v = v * 85 + (uint32_t)(c - '!');
        if (++k == 5) { unsigned char b[4] = { (unsigned char)(v >> 24), (unsigned char)(v >> 16), (unsigned char)(v >> 8), (unsigned char)v }; bput(out, b, 4); v = 0; k = 0; }
    }
    if (k > 1) {
        for (int j = k; j < 5; j++) v = v * 85 + 84;
        unsigned char b[4] = { (unsigned char)(v >> 24), (unsigned char)(v >> 16), (unsigned char)(v >> 8), (unsigned char)v };
        bput(out, b, (size_t)(k - 1));
    }
    return 1;
}
static int rle(const unsigned char *in, size_t n, buf *out) {
    for (size_t i = 0; i < n;) {
        int len = in[i++];
        if (len == 128) break;
        if (len < 128) { size_t m = (size_t)len + 1; if (i + m > n) m = n - i; bput(out, in + i, m); i += m; }
        else if (i < n) { for (int j = 0; j < 257 - len; j++) bputc(out, in[i]); i++; }
    }
    return 1;
}
/* PNG (10-15) and TIFF (2) predictors */
static int predict(buf *b, struct CGPDFDictionary *parms) {
    long pred = dint(parms, "Predictor", 1);
    if (pred <= 1) return 1;
    long colors = dint(parms, "Colors", 1), bpc = dint(parms, "BitsPerComponent", 8), cols = dint(parms, "Columns", 1);
    if (colors < 1 || colors > 32 || bpc < 1 || bpc > 16 || cols < 1 || cols > (1 << 24)) return 0;
    size_t bpp = (size_t)((colors * bpc + 7) / 8), row = (size_t)((colors * bpc * cols + 7) / 8);
    buf out = { 0 };
    if (pred == 2) {                                                   /* TIFF: 8-bit components only */
        if (bpc != 8) return 1;
        for (size_t r = 0; r + row <= b->n; r += row)
            for (size_t i = bpp; i < row; i++) b->p[r + i] = (unsigned char)(b->p[r + i] + b->p[r + i - bpp]);
        return 1;
    }
    unsigned char *prior = calloc(row, 1), *cur = malloc(row);
    for (size_t at = 0; at + 1 + row <= b->n; at += row + 1) {
        int f = b->p[at];
        const unsigned char *src = b->p + at + 1;
        for (size_t i = 0; i < row; i++) {
            int a = i >= bpp ? cur[i - bpp] : 0, up = prior[i], c = i >= bpp ? prior[i - bpp] : 0, v = src[i];
            switch (f) {
            case 1: v += a; break;
            case 2: v += up; break;
            case 3: v += (a + up) / 2; break;
            case 4: { int p = a + up - c, pa = abs(p - a), pb = abs(p - up), pc = abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c; break; }
            default: break;
            }
            cur[i] = (unsigned char)v;
        }
        bput(&out, cur, row);
        memcpy(prior, cur, row);
    }
    free(prior); free(cur); free(b->p);
    *b = out;
    return 1;
}
unsigned char *isim_pdf_stream_decode(struct CGPDFStream *s, size_t *outlen, CGPDFDataFormat *format) {
    struct pdoc *d = s->doc;
    if (format) *format = CGPDFDataFormatRaw;
    buf cur = { 0 };
    bput(&cur, s->raw, s->len);
    if (s->num && d->encrypted && d->unlocked) {
        const char *type = dname(s->dict, "Type");
        int skip = type && (!strcmp(type, "XRef") || (!strcmp(type, "Metadata") && !d->encrypt_metadata));
        if (!skip) cur.n = decrypt_bytes(d, d->stm_method, s->num, s->gen, cur.p, cur.n);
    }
    struct CGPDFObject *f = dget(s->dict, "Filter");
    if (!f) f = dget(s->dict, "F");
    struct CGPDFObject *parms = dget(s->dict, "DecodeParms");
    if (!parms) parms = dget(s->dict, "DP");
    size_t nf = !f ? 0 : f->type == kCGPDFObjectTypeArray ? f->v.arr->n : 1;
    for (size_t i = 0; i < nf; i++) {
        struct CGPDFObject *fo = f->type == kCGPDFObjectTypeArray ? isim_pdf_resolve(d, &f->v.arr->items[i]) : f;
        const char *name = fo && fo->type == kCGPDFObjectTypeName ? fo->v.name : "";
        struct CGPDFObject *po = !parms ? NULL : parms->type == kCGPDFObjectTypeArray ? (i < parms->v.arr->n ? isim_pdf_resolve(d, &parms->v.arr->items[i]) : NULL) : parms;
        struct CGPDFDictionary *p = po && po->type == kCGPDFObjectTypeDictionary ? po->v.dict : NULL;
        buf next = { 0 };
        int ok;
        if (!strcmp(name, "FlateDecode") || !strcmp(name, "Fl")) ok = flate(cur.p, cur.n, &next) && predict(&next, p);
        else if (!strcmp(name, "LZWDecode") || !strcmp(name, "LZW")) ok = lzw(cur.p, cur.n, (int)dint(p, "EarlyChange", 1), &next) && predict(&next, p);
        else if (!strcmp(name, "ASCIIHexDecode") || !strcmp(name, "AHx")) ok = ahx(cur.p, cur.n, &next);
        else if (!strcmp(name, "ASCII85Decode") || !strcmp(name, "A85")) ok = a85(cur.p, cur.n, &next);
        else if (!strcmp(name, "RunLengthDecode") || !strcmp(name, "RL")) ok = rle(cur.p, cur.n, &next);
        else if (!strcmp(name, "Crypt")) { free(next.p); continue; }  /* Identity crypt filter */
        else {
            free(next.p);
            if (!strcmp(name, "DCTDecode") || !strcmp(name, "DCT")) { if (format) *format = CGPDFDataFormatJPEGEncoded; }
            else if (!strcmp(name, "JPXDecode")) { if (format) *format = CGPDFDataFormatJPEG2000; }
            break;                                                     /* image codecs (and CCITT, JBIG2): the data as is */
        }
        free(cur.p);
        if (!ok) { free(next.p); return NULL; }
        cur = next;
    }
    *outlen = cur.n;
    if (!cur.p) cur.p = malloc(1);
    return cur.p;
}

static struct CGPDFObject *load_from_objstm(struct pdoc *d, int stmnum, int num) {
    struct CGPDFObject *so = load_object(d, stmnum);
    if (!so || so->type != kCGPDFObjectTypeStream) return NULL;
    size_t n; CGPDFDataFormat fmt;
    unsigned char *data = isim_pdf_stream_decode(so->v.stream, &n, &fmt);
    if (!data) return NULL;
    long count = dint(so->v.stream->dict, "N", 0), first = dint(so->v.stream->dict, "First", 0);
    unsigned char *copy = isim_pdf_arena_alloc(d, n + 1);              /* objects point into it */
    memcpy(copy, data, n); free(data);
    pdflex hdr = { d, copy, copy + n };
    struct CGPDFObject *found = NULL;
    for (long k = 0; k < count && k < 1000000; k++) {
        tok a, b;
        if (next_tok(&hdr, &a) != T_INT || next_tok(&hdr, &b) != T_INT) break;
        if (first + b.i < 0 || (size_t)(first + b.i) >= n) continue;
        int on = (int)a.i;
        if (on <= 0 || on >= d->nx) continue;
        struct xent *e = &d->x[on];
        if (e->obj || e->type != 2 || e->stm != stmnum) continue;        /* only objects this stream holds now */
        pdflex lx = { d, copy + first + b.i, copy + n };
        struct CGPDFObject *o = isim_pdf_arena_alloc(d, sizeof *o);
        if (!parse_object(&lx, o, 1, 0)) continue;
        e->obj = o;
        if (on == num) found = o;
    }
    return found;
}

/* ---------------- cross-reference data ---------------- */
static void xref_grow(struct pdoc *d, int n) {
    if (n <= d->nx) return;
    if (n > 8 * 1024 * 1024) n = 8 * 1024 * 1024;
    d->x = realloc(d->x, (size_t)n * sizeof *d->x);
    memset(d->x + d->nx, 0, (size_t)(n - d->nx) * sizeof *d->x);
    d->nx = n;
}
static void xref_set(struct pdoc *d, int num, int type, size_t off, int gen, int stm, int idx) {
    if (num < 0 || num >= 8 * 1024 * 1024) return;
    xref_grow(d, num + 1);
    struct xent *e = &d->x[num];
    if (e->type || e->stm < 0) return;                                 /* the newest section wins (read first) */
    if (type == 0) { e->stm = -1; return; }                            /* free: hides older entries */
    e->type = type; e->off = off; e->gen = gen; e->stm = stm; e->idx = idx;
}
static int read_xref_at(struct pdoc *d, size_t off, int depth);
static int read_xref_stream(struct pdoc *d, size_t off, struct CGPDFDictionary **trailer) {
    struct CGPDFObject o; int num, gen;
    if (!parse_indirect(d, off, &num, &gen, &o) || o.type != kCGPDFObjectTypeStream) return 0;
    struct CGPDFDictionary *sd = o.v.stream->dict;
    const char *type = dname(sd, "Type");
    if (!type || strcmp(type, "XRef")) return 0;
    struct CGPDFObject *w = dget(sd, "W");
    if (!w || w->type != kCGPDFObjectTypeArray || w->v.arr->n < 3) return 0;
    long ws[3];
    for (int i = 0; i < 3; i++) { struct CGPDFObject *wi = &w->v.arr->items[i]; ws[i] = wi->type == kCGPDFObjectTypeInteger ? wi->v.i : 0; if (ws[i] < 0 || ws[i] > 8) return 0; }
    o.v.stream->num = 0;                                              /* xref streams are never encrypted */
    size_t n; CGPDFDataFormat fmt;
    unsigned char *data = isim_pdf_stream_decode(o.v.stream, &n, &fmt);
    if (!data) return 0;
    long size = dint(sd, "Size", 0);
    struct CGPDFObject *idx = dget(sd, "Index");
    long ranges[2 * 256]; int nr = 0;
    if (idx && idx->type == kCGPDFObjectTypeArray) {
        for (size_t i = 0; i + 1 < idx->v.arr->n && nr < 256; i += 2) {
            ranges[2 * nr] = idx->v.arr->items[i].v.i; ranges[2 * nr + 1] = idx->v.arr->items[i + 1].v.i; nr++;
        }
    } else { ranges[0] = 0; ranges[1] = size; nr = 1; }
    size_t rec = (size_t)(ws[0] + ws[1] + ws[2]), at = 0;
    for (int r = 0; r < nr; r++)
        for (long k = 0; k < ranges[2 * r + 1] && at + rec <= n; k++, at += rec) {
            unsigned long f[3]; size_t p = at;
            for (int j = 0; j < 3; j++) { f[j] = 0; for (long b = 0; b < ws[j]; b++) f[j] = f[j] << 8 | data[p++]; }
            unsigned long type1 = ws[0] ? f[0] : 1;
            int objn = (int)(ranges[2 * r] + k);
            if (type1 == 1) xref_set(d, objn, 1, f[1], (int)f[2], 0, 0);
            else if (type1 == 2) xref_set(d, objn, 2, 0, 0, (int)f[1], (int)f[2]);
            else if (type1 == 0) xref_set(d, objn, 0, 0, 0, 0, 0);
        }
    free(data);
    *trailer = sd;
    return 1;
}
static int read_xref_table(struct pdoc *d, size_t off, struct CGPDFDictionary **trailer) {
    pdflex lx = { d, d->data + off, d->data + d->len };
    tok t;
    if (next_tok(&lx, &t) != T_WORD || !word_is(&t, "xref")) return 0;
    for (;;) {
        tok a, b;
        const unsigned char *save = lx.p;
        if (next_tok(&lx, &a) != T_INT) { lx.p = save; break; }
        if (next_tok(&lx, &b) != T_INT) return 0;
        for (long k = 0; k < b.i; k++) {
            tok o, g, ty;
            if (next_tok(&lx, &o) != T_INT || next_tok(&lx, &g) != T_INT || next_tok(&lx, &ty) != T_WORD) return 0;
            int num = (int)(a.i + k);
            if (ty.n == 1 && ty.s[0] == 'n') { if (o.i > 0 || num) xref_set(d, num, 1, (size_t)o.i, (int)g.i, 0, 0); }
            else xref_set(d, num, 0, 0, 0, 0, 0);
        }
    }
    if (next_tok(&lx, &t) != T_WORD || !word_is(&t, "trailer")) return 0;
    struct CGPDFObject tr;
    if (!parse_object(&lx, &tr, 1, 0) || tr.type != kCGPDFObjectTypeDictionary) return 0;
    *trailer = tr.v.dict;
    long xstm = dint(tr.v.dict, "XRefStm", -1);                       /* hybrid files */
    if (xstm > 0 && (size_t)xstm < d->len) { struct CGPDFDictionary *ignored; read_xref_stream(d, (size_t)xstm, &ignored); }
    return 1;
}
static int read_xref_at(struct pdoc *d, size_t off, int depth) {
    if (off >= d->len || depth > 64) return 0;
    struct CGPDFDictionary *tr = NULL;
    if (!read_xref_table(d, off, &tr) && !read_xref_stream(d, off, &tr)) return 0;
    if (!d->trailer) d->trailer = tr;
    long prev = dint(tr, "Prev", -1);
    if (prev >= 0 && (size_t)prev != off) read_xref_at(d, (size_t)prev, depth + 1);
    return 1;
}
/* a damaged file: every "n g obj" in it (the last one of each number wins), and its last trailer */
static void rebuild_xref(struct pdoc *d) {
    free(d->x); d->x = NULL; d->nx = 0; d->trailer = NULL;
    const unsigned char *p = d->data, *end = d->data + d->len;
    struct { int num; size_t off; } *found = NULL; size_t nf = 0, cap = 0;
    for (const unsigned char *q = p; (q = find_bytes(q, end, "obj")); q += 3) {
        const unsigned char *s = q;                                    /* back over "num gen " */
        while (s > p && is_ws(s[-1])) s--;
        const unsigned char *g = s; while (g > p && g[-1] >= '0' && g[-1] <= '9') g--;
        if (g == s) continue;
        const unsigned char *s2 = g; while (s2 > p && is_ws(s2[-1])) s2--;
        const unsigned char *n = s2; while (n > p && n[-1] >= '0' && n[-1] <= '9') n--;
        if (n == s2 || (n > p && !is_ws(n[-1]) && !is_delim(n[-1]))) continue;
        if (nf == cap) { cap = cap ? cap * 2 : 256; found = realloc(found, cap * sizeof *found); }
        found[nf].num = atoi((const char *)n); found[nf].off = (size_t)(n - p); nf++;
    }
    for (size_t i = nf; i-- > 0;) xref_set(d, found[i].num, 1, found[i].off, 0, 0, 0);
    free(found);
    for (const unsigned char *q = end; q > p;) {                        /* the last trailer */
        const unsigned char *t = NULL;
        for (const unsigned char *s = p; (s = find_bytes(s, q, "trailer")); s += 7) t = s;
        if (!t) break;
        pdflex lx = { d, t + 7, end };
        struct CGPDFObject tr;
        if (parse_object(&lx, &tr, 1, 0) && tr.type == kCGPDFObjectTypeDictionary && dict_raw(tr.v.dict, "Root")) { d->trailer = tr.v.dict; break; }
        q = t;
    }
    if (!d->trailer)                                                   /* xref-stream files: an XRef object's dictionary */
        for (int i = 1; i < d->nx && !d->trailer; i++) {
            struct CGPDFObject *o = load_object(d, i);
            if (o && o->type == kCGPDFObjectTypeStream && dict_raw(o->v.stream->dict, "Root")) d->trailer = o->v.stream->dict;
        }
    if (!d->trailer)                                                   /* or the catalog itself */
        for (int i = 1; i < d->nx && !d->trailer; i++) {
            struct CGPDFObject *o = load_object(d, i);
            const char *ty = o && o->type == kCGPDFObjectTypeDictionary ? dname(o->v.dict, "Type") : NULL;
            if (ty && !strcmp(ty, "Catalog")) {
                struct CGPDFDictionary *tr = isim_pdf_arena_alloc(d, sizeof *tr);
                tr->doc = d; tr->n = 1;
                tr->keys = isim_pdf_arena_alloc(d, sizeof *tr->keys); tr->vals = isim_pdf_arena_alloc(d, sizeof *tr->vals);
                tr->keys[0] = "Root"; tr->vals[0].type = PDF_REF; tr->vals[0].v.ref.num = i;
                d->trailer = tr;
            }
        }
}

/* ---------------- the standard security handler ---------------- */
static const uint8_t pad32[32] = { 0x28, 0xBF, 0x4E, 0x5E, 0x4E, 0x75, 0x8A, 0x41, 0x64, 0x00, 0x4E, 0x56, 0xFF, 0xFA, 0x01, 0x08,
                                   0x2E, 0x2E, 0x00, 0xB6, 0xD0, 0x68, 0x3E, 0x80, 0x2F, 0x0C, 0xA9, 0xFE, 0x64, 0x53, 0x69, 0x7A };
static struct CGPDFString *dstr(struct CGPDFDictionary *d, const char *key) {
    struct CGPDFObject *o = dget(d, key);
    return o && o->type == kCGPDFObjectTypeString ? o->v.str : NULL;
}
static void padded(const char *pw, uint8_t out[32]) {
    size_t n = pw ? strlen(pw) : 0;
    if (n > 32) n = 32;
    memcpy(out, pw, n); memcpy(out + n, pad32, 32 - n);
}
static struct CGPDFString *first_id(struct pdoc *d) {
    struct CGPDFObject *ido = dget(d->trailer, "ID");
    struct CGPDFObject *e = ido && ido->type == kCGPDFObjectTypeArray && ido->v.arr->n > 0 ? isim_pdf_resolve(d, &ido->v.arr->items[0]) : NULL;
    return e && e->type == kCGPDFObjectTypeString ? e->v.str : NULL;
}
/* algorithm 2: the file key from a (user) password, revisions 2-4 */
static void key_r4(struct pdoc *d, const uint8_t pw[32], uint8_t *key) {
    struct CGPDFString *o = dstr(d->encrypt, "O");
    struct CGPDFString *id0 = first_id(d);
    size_t cap = 32 + 32 + 4 + (id0 ? id0->len : 0) + 4, n = 0;
    uint8_t *b = malloc(cap);
    memcpy(b, pw, 32); n = 32;
    if (o) { size_t m = o->len < 32 ? o->len : 32; memcpy(b + n, o->bytes, m); n += m; }
    b[n++] = (uint8_t)d->P; b[n++] = (uint8_t)(d->P >> 8); b[n++] = (uint8_t)(d->P >> 16); b[n++] = (uint8_t)(d->P >> 24);
    if (id0) { memcpy(b + n, id0->bytes, id0->len); n += id0->len; }
    if (d->R >= 4 && !d->encrypt_metadata) { memset(b + n, 0xFF, 4); n += 4; }
    uint8_t h[16];
    isim_pdf_md5(b, n, h);
    free(b);
    if (d->R >= 3) for (int i = 0; i < 50; i++) isim_pdf_md5(h, (size_t)d->keylen, h);
    memcpy(key, h, (size_t)d->keylen);
}
/* algorithms 4 / 5: does this key open the document as its user? */
static int check_user_r4(struct pdoc *d, const uint8_t *key) {
    struct CGPDFString *u = dstr(d->encrypt, "U");
    if (!u || u->len < 16) return 0;
    uint8_t out[32];
    if (d->R == 2) { memcpy(out, pad32, 32); isim_pdf_rc4(key, (size_t)d->keylen, out, 32); return !memcmp(out, u->bytes, 32 > u->len ? u->len : 32); }
    struct CGPDFString *id0 = first_id(d);
    size_t n = 32 + (id0 ? id0->len : 0);
    uint8_t *b = malloc(n);
    memcpy(b, pad32, 32);
    if (id0) memcpy(b + 32, id0->bytes, id0->len);
    isim_pdf_md5(b, n, out);
    free(b);
    for (int i = 0; i < 20; i++) {
        uint8_t k[16];
        for (int j = 0; j < d->keylen; j++) k[j] = key[j] ^ (uint8_t)i;
        isim_pdf_rc4(k, (size_t)d->keylen, out, 16);
    }
    return !memcmp(out, u->bytes, 16);
}
static int try_r4(struct pdoc *d, const char *password) {
    uint8_t pw[32], key[16];
    padded(password, pw);
    key_r4(d, pw, key);
    if (check_user_r4(d, key)) { memcpy(d->key, key, (size_t)d->keylen); return 1; }
    /* the owner password: it decrypts O into the user password (algorithm 7) */
    uint8_t h[16];
    isim_pdf_md5(pw, 32, h);
    if (d->R >= 3) for (int i = 0; i < 50; i++) isim_pdf_md5(h, 16, h);
    struct CGPDFString *o = dstr(d->encrypt, "O");
    if (!o || o->len < 32) return 0;
    uint8_t user[32];
    memcpy(user, o->bytes, 32);
    if (d->R == 2) isim_pdf_rc4(h, (size_t)d->keylen, user, 32);
    else for (int i = 19; i >= 0; i--) {
        uint8_t k[16];
        for (int j = 0; j < d->keylen; j++) k[j] = h[j] ^ (uint8_t)i;
        isim_pdf_rc4(k, (size_t)d->keylen, user, 32);
    }
    key_r4(d, user, key);
    if (check_user_r4(d, key)) { memcpy(d->key, key, (size_t)d->keylen); return 2; }
    return 0;
}
/* revision 5 / 6 hashes (algorithm 2.A / 2.B) */
static void hash_r6(struct pdoc *d, const char *pw, size_t pwlen, const uint8_t *salt, const uint8_t *udata, uint8_t out[32]) {
    size_t un = udata ? 48 : 0;
    uint8_t *b = malloc(pwlen + 8 + un);
    memcpy(b, pw, pwlen); memcpy(b + pwlen, salt, 8); if (un) memcpy(b + pwlen + 8, udata, un);
    uint8_t k[64];
    isim_pdf_sha256(b, pwlen + 8 + un, k);
    free(b);
    if (d->R == 5) { memcpy(out, k, 32); return; }
    size_t klen = 32;
    uint8_t *k1 = malloc((pwlen + 64 + un) * 64), *e = malloc((pwlen + 64 + un) * 64);
    for (int round = 0;; round++) {
        size_t one = pwlen + klen + un, n = one * 64;
        for (int r = 0; r < 64; r++) {
            memcpy(k1 + r * one, pw, pwlen); memcpy(k1 + r * one + pwlen, k, klen);
            if (un) memcpy(k1 + r * one + pwlen + klen, udata, un);
        }
        memcpy(e, k1, n);
        isim_pdf_aes_cbc_encrypt(k, 16, k + 16, e, n);
        unsigned sum = 0;
        for (int i = 0; i < 16; i++) sum += e[i];
        switch (sum % 3) {
        case 0: isim_pdf_sha256(e, n, k); klen = 32; break;
        case 1: isim_pdf_sha512(e, n, k, 384); klen = 48; break;
        default: isim_pdf_sha512(e, n, k, 512); klen = 64; break;
        }
        if (round + 1 >= 64 && (int)e[n - 1] <= round + 1 - 32) break;
    }
    free(k1); free(e);
    memcpy(out, k, 32);
}
static int try_r6(struct pdoc *d, const char *password) {
    struct CGPDFString *u = dstr(d->encrypt, "U"), *o = dstr(d->encrypt, "O"), *ue = dstr(d->encrypt, "UE"), *oe = dstr(d->encrypt, "OE");
    if (!u || !o || u->len < 48 || o->len < 48) return 0;
    size_t pwlen = password ? strlen(password) : 0;
    if (pwlen > 127) pwlen = 127;
    uint8_t h[32];
    hash_r6(d, password, pwlen, o->bytes + 32, u->bytes, h);           /* owner */
    if (!memcmp(h, o->bytes, 32) && oe && oe->len >= 32) {
        hash_r6(d, password, pwlen, o->bytes + 40, u->bytes, h);
        memcpy(d->key, oe->bytes, 32);
        isim_pdf_aes_cbc_decrypt(h, 32, NULL, d->key, 32);
        return 2;
    }
    hash_r6(d, password, pwlen, u->bytes + 32, NULL, h);               /* user */
    if (!memcmp(h, u->bytes, 32) && ue && ue->len >= 32) {
        hash_r6(d, password, pwlen, u->bytes + 40, NULL, h);
        memcpy(d->key, ue->bytes, 32);
        isim_pdf_aes_cbc_decrypt(h, 32, NULL, d->key, 32);
        return 1;
    }
    return 0;
}
static int crypt_method(struct pdoc *d, const char *filter) {
    if (d->V < 4) return 1;
    if (!filter || !strcmp(filter, "Identity")) return 0;
    struct CGPDFDictionary *cf = ddict(ddict(d->encrypt, "CF"), filter);
    const char *cfm = dname(cf, "CFM");
    if (!cfm || !strcmp(cfm, "None")) return 0;
    if (!strcmp(cfm, "V2")) return 1;
    if (!strcmp(cfm, "AESV2")) return 2;
    if (!strcmp(cfm, "AESV3")) return 3;
    return 0;
}
static void setup_encryption(struct pdoc *d) {
    struct CGPDFObject *eo = dict_raw(d->trailer, "Encrypt");
    if (!eo) return;
    if (eo->type == PDF_REF) d->encrypt_num = eo->v.ref.num;
    struct CGPDFObject *e = isim_pdf_resolve(d, eo);
    if (!e || e->type != kCGPDFObjectTypeDictionary) return;
    d->encrypt = e->v.dict;
    d->encrypted = 1;
    const char *filter = dname(d->encrypt, "Filter");
    d->V = (int)dint(d->encrypt, "V", 0); d->R = (int)dint(d->encrypt, "R", 0);
    d->P = (uint32_t)dint(d->encrypt, "P", 0);
    struct CGPDFObject *em = dget(d->encrypt, "EncryptMetadata");
    d->encrypt_metadata = !(em && em->type == kCGPDFObjectTypeBoolean && !em->v.b);
    if (!filter || strcmp(filter, "Standard") || d->R < 2 || d->R > 6) return;    /* other handlers: locked */
    d->keylen = d->R == 2 ? 5 : (int)dint(d->encrypt, "Length", 40) / 8;
    if (d->keylen < 5 || d->keylen > 16) d->keylen = 16;
    d->stm_method = crypt_method(d, dname(d->encrypt, "StmF"));
    d->str_method = crypt_method(d, dname(d->encrypt, "StrF"));
    if (d->R >= 5) { d->keylen = 32; if (d->stm_method) d->stm_method = 3; if (d->str_method) d->str_method = 3; }
    isim_pdf_doc_unlock(d, "");                                        /* the empty user password */
}
int isim_pdf_doc_unlock(struct pdoc *d, const char *password) {
    if (!d || !d->encrypted || !d->encrypt) return 0;
    int r = d->R >= 5 ? try_r6(d, password) : try_r4(d, password);
    if (!r) return 0;
    int was = d->unlocked;
    d->unlocked = 1; d->owner = r == 2;
    snprintf(d->password, sizeof d->password, "%s", password ? password : "");
    if (!was)                                                          /* objects read while locked: read again, decrypted */
        for (int i = 0; i < d->nx; i++) if (i != d->encrypt_num) d->x[i].obj = NULL;
    if (!was) { free(d->pages); d->pages = NULL; d->npages = 0; }
    return r;
}

/* ---------------- documents ---------------- */
struct pdoc *isim_pdf_doc_open(const unsigned char *data, size_t len) {
    if (!data || len < 8) return NULL;
    const unsigned char *hdr = find_bytes(data, data + (len < 1024 ? len : 1024), "%PDF-");
    if (!hdr) return NULL;
    struct pdoc *d = calloc(1, sizeof *d);
    d->data = data; d->len = len;
    d->major = hdr[5] >= '0' && hdr[5] <= '9' ? hdr[5] - '0' : 1;
    d->minor = hdr + 7 < data + len && hdr[7] >= '0' && hdr[7] <= '9' ? hdr[7] - '0' : 0;
    const unsigned char *sx = NULL;                                    /* the last startxref */
    for (const unsigned char *s = data + (len > 4096 ? len - 4096 : 0); (s = find_bytes(s, data + len, "startxref")); s += 9) sx = s;
    int ok = 0;
    if (sx) {
        pdflex lx = { d, sx + 9, data + len };
        tok t;
        if (next_tok(&lx, &t) == T_INT && t.i > 0 && (size_t)t.i < len) ok = read_xref_at(d, (size_t)t.i, 0);
    }
    if (!ok || !d->trailer || !dict_raw(d->trailer, "Root") || !isim_pdf_doc_catalog(d)) rebuild_xref(d);
    if (!d->trailer || !isim_pdf_doc_catalog(d)) {
        setup_encryption(d);                                           /* the catalog may need decrypting... */
        if (!isim_pdf_doc_catalog(d) && !d->encrypted) { isim_pdf_doc_free(d); return NULL; }
        return d;
    }
    setup_encryption(d);
    struct CGPDFDictionary *cat = isim_pdf_doc_catalog(d);            /* a /Version in the catalog overrides the header */
    const char *v = dname(cat, "Version");
    if (v && v[0] >= '1' && v[0] <= '9' && v[1] == '.') { d->major = v[0] - '0'; d->minor = atoi(v + 2); }
    return d;
}
void isim_pdf_doc_free(struct pdoc *d) {
    if (!d) return;
    for (struct chunk *c = d->arena, *n; c; c = n) { n = c->next; free(c); }
    free(d->x); free(d->pages);
    free(d);
}
struct CGPDFDictionary *isim_pdf_doc_trailer(struct pdoc *d) { return d ? d->trailer : NULL; }
struct CGPDFDictionary *isim_pdf_doc_catalog(struct pdoc *d) { return d && d->trailer ? ddict(d->trailer, "Root") : NULL; }
void isim_pdf_doc_version(struct pdoc *d, int *major, int *minor) { if (major) *major = d ? d->major : 0; if (minor) *minor = d ? d->minor : 0; }
int isim_pdf_doc_encrypted(struct pdoc *d) { return d && d->encrypted; }
int isim_pdf_doc_unlocked(struct pdoc *d) { return d && (!d->encrypted || d->unlocked); }
int isim_pdf_doc_owner(struct pdoc *d) { return d && (!d->encrypted || (d->unlocked && d->owner)); }
uint32_t isim_pdf_doc_permissions(struct pdoc *d) { return !d || !d->encrypted || d->owner ? 0xFFFFFFFFu : d->P; }
const char *isim_pdf_doc_password(struct pdoc *d) { return d && d->encrypted && d->unlocked ? d->password : NULL; }
static void collect_pages(struct pdoc *d, struct CGPDFDictionary *node, int depth, struct CGPDFDictionary ***out, int *n, int *cap) {
    if (!node || depth > 64 || *n > 1000000) return;
    struct CGPDFObject *kids = dget(node, "Kids");
    const char *type = dname(node, "Type");
    if (kids && kids->type == kCGPDFObjectTypeArray && !(type && !strcmp(type, "Page"))) {
        for (size_t i = 0; i < kids->v.arr->n; i++) {
            struct CGPDFObject *k = isim_pdf_resolve(d, &kids->v.arr->items[i]);
            if (k && k->type == kCGPDFObjectTypeDictionary && k->v.dict != node) collect_pages(d, k->v.dict, depth + 1, out, n, cap);
        }
        return;
    }
    if (*n == *cap) { *cap = *cap ? *cap * 2 : 16; *out = realloc(*out, (size_t)*cap * sizeof **out); }
    (*out)[(*n)++] = node;
}
struct CGPDFDictionary **isim_pdf_doc_pages(struct pdoc *d, int *n) {
    *n = 0;
    if (!d) return NULL;
    if (!d->pages) {
        int cap = 0;
        collect_pages(d, ddict(isim_pdf_doc_catalog(d), "Pages"), 0, &d->pages, &d->npages, &cap);
    }
    *n = d->npages;
    return d->pages;
}
struct CGPDFObject *isim_pdf_inherited(struct CGPDFDictionary *page, const char *key) {
    for (int depth = 0; page && depth < 64; depth++) {
        struct CGPDFObject *o = dget(page, key);
        if (o) return o;
        page = ddict(page, "Parent");
    }
    return NULL;
}

/* ---------------- the public object API ---------------- */
CGPDFObjectType CGPDFObjectGetType(CGPDFObjectRef o) { return o ? (CGPDFObjectType)o->type : kCGPDFObjectTypeNull; }
bool CGPDFObjectGetValue(CGPDFObjectRef o, CGPDFObjectType type, void *value) {
    if (!o) return false;
    if (o->type == kCGPDFObjectTypeInteger && type == kCGPDFObjectTypeReal) { if (value) *(CGPDFReal *)value = (CGPDFReal)o->v.i; return true; }
    if ((CGPDFObjectType)o->type != type) return false;
    if (!value) return true;
    switch (type) {
    case kCGPDFObjectTypeNull: return true;
    case kCGPDFObjectTypeBoolean: *(CGPDFBoolean *)value = o->v.b; return true;
    case kCGPDFObjectTypeInteger: *(CGPDFInteger *)value = o->v.i; return true;
    case kCGPDFObjectTypeReal: *(CGPDFReal *)value = (CGPDFReal)o->v.r; return true;
    case kCGPDFObjectTypeName: *(const char **)value = o->v.name; return true;
    case kCGPDFObjectTypeString: *(CGPDFStringRef *)value = o->v.str; return true;
    case kCGPDFObjectTypeArray: *(CGPDFArrayRef *)value = o->v.arr; return true;
    case kCGPDFObjectTypeDictionary: *(CGPDFDictionaryRef *)value = o->v.dict; return true;
    case kCGPDFObjectTypeStream: *(CGPDFStreamRef *)value = o->v.stream; return true;
    }
    return false;
}

size_t CGPDFArrayGetCount(CGPDFArrayRef a) { return a ? a->n : 0; }
static CGPDFObjectRef array_at(CGPDFArrayRef a, size_t i) { return a && i < a->n ? isim_pdf_resolve(a->doc, &a->items[i]) : NULL; }
bool CGPDFArrayGetObject(CGPDFArrayRef a, size_t i, CGPDFObjectRef *v) { CGPDFObjectRef o = array_at(a, i); if (o && v) *v = o; return o != NULL; }
bool CGPDFArrayGetNull(CGPDFArrayRef a, size_t i) { CGPDFObjectRef o = array_at(a, i); return a && i < a->n && (!o || o->type == kCGPDFObjectTypeNull); }
bool CGPDFArrayGetBoolean(CGPDFArrayRef a, size_t i, CGPDFBoolean *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeBoolean, v); }
bool CGPDFArrayGetInteger(CGPDFArrayRef a, size_t i, CGPDFInteger *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeInteger, v); }
bool CGPDFArrayGetNumber(CGPDFArrayRef a, size_t i, CGPDFReal *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeReal, v); }
bool CGPDFArrayGetName(CGPDFArrayRef a, size_t i, const char **v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeName, v); }
bool CGPDFArrayGetString(CGPDFArrayRef a, size_t i, CGPDFStringRef *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeString, v); }
bool CGPDFArrayGetArray(CGPDFArrayRef a, size_t i, CGPDFArrayRef *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeArray, v); }
bool CGPDFArrayGetDictionary(CGPDFArrayRef a, size_t i, CGPDFDictionaryRef *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeDictionary, v); }
bool CGPDFArrayGetStream(CGPDFArrayRef a, size_t i, CGPDFStreamRef *v) { return CGPDFObjectGetValue(array_at(a, i), kCGPDFObjectTypeStream, v); }
void CGPDFArrayApplyBlock(CGPDFArrayRef a, CGPDFArrayApplierBlock block, void *info) {
    if (!a || !block) return;
    for (size_t i = 0; i < a->n; i++) {
        CGPDFObjectRef o = array_at(a, i);
        if (o && !block(i, o, info)) break;
    }
}

size_t CGPDFDictionaryGetCount(CGPDFDictionaryRef d) { return d ? d->n : 0; }
static CGPDFObjectRef dict_at(CGPDFDictionaryRef d, const char *key) { return d && key ? dget((struct CGPDFDictionary *)d, key) : NULL; }
bool CGPDFDictionaryGetObject(CGPDFDictionaryRef d, const char *k, CGPDFObjectRef *v) { CGPDFObjectRef o = dict_at(d, k); if (o && v) *v = o; return o != NULL; }
bool CGPDFDictionaryGetBoolean(CGPDFDictionaryRef d, const char *k, CGPDFBoolean *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeBoolean, v); }
bool CGPDFDictionaryGetInteger(CGPDFDictionaryRef d, const char *k, CGPDFInteger *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeInteger, v); }
bool CGPDFDictionaryGetNumber(CGPDFDictionaryRef d, const char *k, CGPDFReal *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeReal, v); }
bool CGPDFDictionaryGetName(CGPDFDictionaryRef d, const char *k, const char **v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeName, v); }
bool CGPDFDictionaryGetString(CGPDFDictionaryRef d, const char *k, CGPDFStringRef *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeString, v); }
bool CGPDFDictionaryGetArray(CGPDFDictionaryRef d, const char *k, CGPDFArrayRef *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeArray, v); }
bool CGPDFDictionaryGetDictionary(CGPDFDictionaryRef d, const char *k, CGPDFDictionaryRef *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeDictionary, v); }
bool CGPDFDictionaryGetStream(CGPDFDictionaryRef d, const char *k, CGPDFStreamRef *v) { return CGPDFObjectGetValue(dict_at(d, k), kCGPDFObjectTypeStream, v); }
void CGPDFDictionaryApplyFunction(CGPDFDictionaryRef d, CGPDFDictionaryApplierFunction f, void *info) {
    if (!d || !f) return;
    for (size_t i = 0; i < d->n; i++) {
        CGPDFObjectRef o = isim_pdf_resolve(d->doc, &d->vals[i]);
        if (o) f(d->keys[i], o, info);
    }
}
void CGPDFDictionaryApplyBlock(CGPDFDictionaryRef d, CGPDFDictionaryApplierBlock block, void *info) {
    if (!d || !block) return;
    for (size_t i = 0; i < d->n; i++) {
        CGPDFObjectRef o = isim_pdf_resolve(d->doc, &d->vals[i]);
        if (o && !block(d->keys[i], o, info)) break;
    }
}

size_t CGPDFStringGetLength(CGPDFStringRef s) { return s ? s->len : 0; }
const unsigned char *CGPDFStringGetBytePtr(CGPDFStringRef s) { return s ? s->bytes : NULL; }
/* PDFDocEncoding where it differs from Latin-1 (0x18-0x1F, 0x80-0xA0) */
static const uint16_t pdfdoc_low[8] = { 0x02D8, 0x02C7, 0x02C6, 0x02D9, 0x02DD, 0x02DB, 0x02DA, 0x02DC };
static const uint16_t pdfdoc_high[33] = { 0x2022, 0x2020, 0x2021, 0x2026, 0x2014, 0x2013, 0x0192, 0x2044, 0x2039, 0x203A, 0x2212,
                                          0x2030, 0x201E, 0x201C, 0x201D, 0x2018, 0x2019, 0x201A, 0x2122, 0xFB01, 0xFB02, 0x0141,
                                          0x0152, 0x0160, 0x0178, 0x017D, 0x0131, 0x0142, 0x0153, 0x0161, 0x017E, 0xFFFD, 0x20AC };
CFStringRef CGPDFStringCopyTextString(CGPDFStringRef s) {
    if (!s) return NULL;
    if (s->len >= 2 && s->bytes[0] == 0xFE && s->bytes[1] == 0xFF)
        return CFStringCreateWithBytes(NULL, s->bytes + 2, (CFIndex)((s->len - 2) & ~(size_t)1), kCFStringEncodingUTF16BE, false);
    if (s->len >= 3 && s->bytes[0] == 0xEF && s->bytes[1] == 0xBB && s->bytes[2] == 0xBF)
        return CFStringCreateWithBytes(NULL, s->bytes + 3, (CFIndex)(s->len - 3), kCFStringEncodingUTF8, false);
    uint8_t *u = malloc(s->len ? s->len * 2 : 1);                    /* UTF-16LE */
    for (size_t i = 0; i < s->len; i++) {
        unsigned c = s->bytes[i];
        c = c >= 0x18 && c <= 0x1F ? pdfdoc_low[c - 0x18] : c >= 0x80 && c <= 0xA0 ? pdfdoc_high[c - 0x80] : c;
        u[2 * i] = (uint8_t)c; u[2 * i + 1] = (uint8_t)(c >> 8);
    }
    CFStringRef r = CFStringCreateWithBytes(NULL, u, (CFIndex)(s->len * 2), kCFStringEncodingUTF16LE, false);
    free(u);
    return r;
}
/* "D:YYYYMMDDHHmmSSOHH'mm'" */
CFDateRef CGPDFStringCopyDate(CGPDFStringRef s) {
    if (!s || s->len < 4) return NULL;
    const unsigned char *p = s->bytes, *end = s->bytes + s->len;
    if (end - p >= 2 && p[0] == 'D' && p[1] == ':') p += 2;
    int f[6] = { 0, 1, 1, 0, 0, 0 }, widths[6] = { 4, 2, 2, 2, 2, 2 };
    for (int k = 0; k < 6; k++) {
        if (end - p < widths[k] || p[0] < '0' || p[0] > '9') { if (k == 0) return NULL; break; }
        int v = 0;
        for (int j = 0; j < widths[k]; j++) { if (p[j] < '0' || p[j] > '9') return NULL; v = v * 10 + (p[j] - '0'); }
        f[k] = v; p += widths[k];
    }
    long tz = 0;
    if (p < end && (*p == '+' || *p == '-')) {
        int sign = *p == '-' ? -1 : 1; p++;
        int hh = 0, mm = 0;
        if (end - p >= 2) { hh = (p[0] - '0') * 10 + (p[1] - '0'); p += 2; }
        if (p < end && *p == '\'') p++;
        if (end - p >= 2 && p[0] >= '0' && p[0] <= '9') { mm = (p[0] - '0') * 10 + (p[1] - '0'); }
        tz = sign * (hh * 3600L + mm * 60L);
    }
    /* days from 2001-01-01 (Howard Hinnant's days_from_civil) */
    int y = f[0], m = f[1], dd = f[2];
    y -= m <= 2;
    long era = (y >= 0 ? y : y - 399) / 400;
    unsigned yoe = (unsigned)(y - era * 400), doy = (unsigned)((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + dd - 1), doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    long days = era * 146097 + (long)doe - 719468 - 11323;              /* 11323: 1970-01-01 to 2001-01-01 */
    double t = (double)days * 86400 + f[3] * 3600 + f[4] * 60 + f[5] - (double)tz;
    return CFDateCreate(NULL, t);
}

CGPDFDictionaryRef CGPDFStreamGetDictionary(CGPDFStreamRef s) { return s ? s->dict : NULL; }
CFDataRef CGPDFStreamCopyData(CGPDFStreamRef s, CGPDFDataFormat *format) {
    if (!s) return NULL;
    size_t n; CGPDFDataFormat f;
    unsigned char *p = isim_pdf_stream_decode((struct CGPDFStream *)s, &n, &f);
    if (!p) return NULL;
    if (format) *format = f;
    CFDataRef d = CFDataCreate(NULL, p, (CFIndex)n);
    free(p);
    return d;
}

/* ---------------- rewriting (PDFKit's annotations) ---------------- */
/* isim (PDFKit, issue #358): a document rewritten with every object it has (object streams and cross-reference
 * streams written out as plain objects, a cross-reference table) plus new objects: the PDF sources `sources[k]`, each
 * added to the /Annots of page `page_of[k]` (from 0). In a source, "@P<n>@" stands for page n's reference and
 * "@A<n>@" for new object n's. Returns malloc'd bytes (*out_len), or NULL. */
typedef struct { char *p; size_t n, cap; } obuf;
static void ob_put(obuf *b, const void *s, size_t n) {
    if (b->n + n + 1 > b->cap) { b->cap = (b->n + n + 1) * 2; b->p = realloc(b->p, b->cap); }
    memcpy(b->p + b->n, s, n); b->n += n; b->p[b->n] = 0;
}
static void ob_str(obuf *b, const char *s) { ob_put(b, s, strlen(s)); }
static void ob_fmt(obuf *b, const char *fmt, ...) {
    char tmp[256]; va_list ap; va_start(ap, fmt); int n = vsnprintf(tmp, sizeof tmp, fmt, ap); va_end(ap);
    if (n > 0) ob_put(b, tmp, (size_t)(n < (int)sizeof tmp ? n : (int)sizeof tmp - 1));
}
static void ob_name(obuf *b, const char *name) {
    ob_str(b, "/");
    for (const unsigned char *p = (const unsigned char *)name; *p; p++) {
        if (*p > 32 && *p < 127 && !strchr("#()<>[]{}/%", *p)) ob_put(b, p, 1);
        else ob_fmt(b, "#%02X", *p);
    }
}
static void ob_real(obuf *b, double v) {
    if (v == (double)(long)v && v < 1e12 && v > -1e12) { ob_fmt(b, "%ld", (long)v); return; }
    char tmp[64]; snprintf(tmp, sizeof tmp, "%.6f", v);
    size_t n = strlen(tmp);
    while (n > 1 && tmp[n - 1] == '0') tmp[--n] = 0;
    if (n > 1 && tmp[n - 1] == '.') tmp[--n] = 0;
    ob_str(b, tmp);
}
static void ob_object(obuf *b, struct CGPDFObject *o, struct CGPDFDictionary *page_dict, const char *annots, int depth);
static void ob_dict(obuf *b, struct CGPDFDictionary *d, const char *annots, int skip_length, int depth) {
    ob_str(b, "<<");
    int had_annots = 0;
    for (size_t i = 0; i < d->n; i++) {
        if (skip_length && !strcmp(d->keys[i], "Length")) continue;
        ob_str(b, " "); ob_name(b, d->keys[i]); ob_str(b, " ");
        if (annots && !strcmp(d->keys[i], "Annots")) {                /* the page's annotations, then the new ones */
            had_annots = 1;
            struct CGPDFObject *a = isim_pdf_resolve(d->doc, &d->vals[i]);
            ob_str(b, "[");
            if (a && a->type == kCGPDFObjectTypeArray)
                for (size_t k = 0; k < a->v.arr->n; k++) { ob_str(b, " "); ob_object(b, &a->v.arr->items[k], NULL, NULL, depth + 1); }
            ob_str(b, annots); ob_str(b, " ]");
            continue;
        }
        ob_object(b, &d->vals[i], NULL, NULL, depth + 1);
    }
    if (annots && !had_annots) { ob_str(b, " /Annots ["); ob_str(b, annots); ob_str(b, " ]"); }
    ob_str(b, " >>");
}
static void ob_object(obuf *b, struct CGPDFObject *o, struct CGPDFDictionary *page_dict, const char *annots, int depth) {
    if (!o || depth > 64) { ob_str(b, "null"); return; }
    switch (o->type) {
        case PDF_REF: ob_fmt(b, "%d %d R", o->v.ref.num, o->v.ref.gen); break;
        case kCGPDFObjectTypeBoolean: ob_str(b, o->v.b ? "true" : "false"); break;
        case kCGPDFObjectTypeInteger: ob_fmt(b, "%ld", o->v.i); break;
        case kCGPDFObjectTypeReal: ob_real(b, o->v.r); break;
        case kCGPDFObjectTypeName: ob_name(b, o->v.name); break;
        case kCGPDFObjectTypeString:
            ob_str(b, "<");
            for (size_t i = 0; i < o->v.str->len; i++) ob_fmt(b, "%02X", o->v.str->bytes[i]);
            ob_str(b, ">");
            break;
        case kCGPDFObjectTypeArray:
            ob_str(b, "[");
            for (size_t i = 0; i < o->v.arr->n; i++) { ob_str(b, " "); ob_object(b, &o->v.arr->items[i], NULL, NULL, depth + 1); }
            ob_str(b, " ]");
            break;
        case kCGPDFObjectTypeDictionary: ob_dict(b, o->v.dict, o->v.dict == page_dict ? annots : NULL, 0, depth); break;
        case kCGPDFObjectTypeStream:
            ob_dict(b, o->v.stream->dict, NULL, 1, depth);
            b->n -= 2;                                                  /* reopen it for the length */
            ob_fmt(b, "/Length %zu >>\nstream\n", o->v.stream->len);
            ob_put(b, o->v.stream->raw, o->v.stream->len);
            ob_str(b, "\nendstream");
            break;
        default: ob_str(b, "null");
    }
}
/* a source with its placeholders replaced */
static void ob_source(obuf *b, const char *s, const int *page_nums, int npages, int first_new) {
    while (*s) {
        if (*s == '@' && (s[1] == 'P' || s[1] == 'A')) {
            char *end; long n = strtol(s + 2, &end, 10);
            if (end != s + 2 && *end == '@') {
                if (s[1] == 'P') { if (n >= 0 && n < npages) ob_fmt(b, "%d 0 R", page_nums[n]); else ob_str(b, "null"); }
                else ob_fmt(b, "%ld 0 R", first_new + n);
                s = end + 1;
                continue;
            }
        }
        ob_put(b, s, 1); s++;
    }
}
void *isim_CGPDFDataCopyAddingAnnotations(const void *data, size_t len, int count, const char *const *sources, const int *page_of, size_t *out_len) {
    *out_len = 0;
    struct pdoc *d = isim_pdf_doc_open(data, len);
    if (!d || d->encrypted) { isim_pdf_doc_free(d); return NULL; }
    int npages = 0;
    struct CGPDFDictionary **pages = isim_pdf_doc_pages(d, &npages);
    int *page_nums = calloc((size_t)(npages ? npages : 1), sizeof *page_nums);
    for (int num = 1; num < d->nx; num++) {                            /* each page's object number */
        struct CGPDFObject *o = load_object(d, num);
        if (o && o->type == kCGPDFObjectTypeDictionary)
            for (int p = 0; p < npages; p++) if (pages[p] == o->v.dict) page_nums[p] = num;
    }
    int first_new = d->nx, total = d->nx + count;
    size_t *offsets = calloc((size_t)total, sizeof *offsets);
    obuf b = {0};
    ob_fmt(&b, "%%PDF-%d.%d\n%%\xE2\xE3\xCF\xD3\n", d->major, d->minor);
    for (int num = 1; num < d->nx; num++) {
        struct CGPDFObject *o = load_object(d, num);
        if (!o) continue;
        if (o->type == kCGPDFObjectTypeStream) {
            const char *type = dname(o->v.stream->dict, "Type");
            if (type && (!strcmp(type, "ObjStm") || !strcmp(type, "XRef"))) continue;
        }
        char *annots = NULL;
        if (o->type == kCGPDFObjectTypeDictionary)
            for (int p = 0; p < npages; p++) {
                if (page_nums[p] != num) continue;
                obuf a = {0};
                for (int k = 0; k < count; k++) if (page_of[k] == p) ob_fmt(&a, " %d 0 R", first_new + k);
                annots = a.p;
            }
        offsets[num] = b.n;
        ob_fmt(&b, "%d %d obj\n", num, d->x[num].type == 1 ? d->x[num].gen : 0);
        ob_object(&b, o, o->type == kCGPDFObjectTypeDictionary ? o->v.dict : NULL, annots, 0);
        ob_str(&b, "\nendobj\n");
        free(annots);
    }
    for (int k = 0; k < count; k++) {
        offsets[first_new + k] = b.n;
        ob_fmt(&b, "%d 0 obj\n", first_new + k);
        ob_source(&b, sources[k], page_nums, npages, first_new);
        ob_str(&b, "\nendobj\n");
    }
    size_t xref = b.n;
    ob_fmt(&b, "xref\n0 %d\n0000000000 65535 f \n", total);
    for (int num = 1; num < total; num++) {
        if (offsets[num]) ob_fmt(&b, "%010zu 00000 n \n", offsets[num]);
        else ob_str(&b, "0000000000 65535 f \n");
    }
    ob_fmt(&b, "trailer\n<< /Size %d", total);
    const char *keys[] = { "Root", "Info", "ID" };
    for (int i = 0; i < 3; i++) {
        struct CGPDFObject *o = dict_raw(d->trailer, keys[i]);
        if (o) { ob_str(&b, " "); ob_name(&b, keys[i]); ob_str(&b, " "); ob_object(&b, o, NULL, NULL, 0); }
    }
    ob_fmt(&b, " >>\nstartxref\n%zu\n%%%%EOF\n", xref);
    free(offsets); free(page_nums);
    isim_pdf_doc_free(d);
    *out_len = b.n;
    return b.p;
}
