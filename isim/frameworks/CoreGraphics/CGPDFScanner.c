/* isim CoreGraphics: content streams, operator tables and the scanner (adapted: isim's own parser, CGPDFParser.c).
 * A page's content streams are scanned as one (the PDF rule for an array of /Contents); each operator's callback finds
 * its operands on the scanner's stack, which is emptied after every operator. Inline images (BI ... ID ... EI) reach
 * the "BI" callback as a stream on the stack. */
#include "cg_pdf.h"
#include "cg_internal.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>
#include <string.h>

struct CGPDFContentStream {
    int refs;
    struct pdoc *doc;
    struct CGPDFStream **streams; size_t nstreams;
    struct CGPDFDictionary *resources;
    struct CGPDFContentStream *parent;
    CFArrayRef cfstreams;
};
struct opentry { char name[8]; CGPDFOperatorCallback cb; };
struct CGPDFOperatorTable { int refs; struct opentry *ops; size_t n, cap; };
struct CGPDFScanner {
    int refs;
    struct CGPDFContentStream *cs;
    struct CGPDFOperatorTable *table;
    void *info;
    struct CGPDFObject **stack; size_t n, cap;
    int stop;
};

static struct CGPDFContentStream *cs_new(struct pdoc *doc, struct CGPDFDictionary *resources, struct CGPDFContentStream *parent) {
    struct CGPDFContentStream *cs = calloc(1, sizeof *cs);
    cs->refs = 1; cs->doc = doc; cs->resources = resources;
    cs->parent = parent ? CGPDFContentStreamRetain(parent) : NULL;
    return cs;
}
static void cs_add(struct CGPDFContentStream *cs, struct CGPDFStream *s) {
    cs->streams = realloc(cs->streams, (cs->nstreams + 1) * sizeof *cs->streams);
    cs->streams[cs->nstreams++] = s;
}
CGPDFContentStreamRef CGPDFContentStreamCreateWithPage(CGPDFPageRef page) {
    struct CGPDFDictionary *pd = (struct CGPDFDictionary *)CGPDFPageGetDictionary(page);
    struct pdoc *doc = pd ? pd->doc : NULL;
    struct CGPDFObject *res = pd ? isim_pdf_inherited(pd, "Resources") : NULL;
    struct CGPDFContentStream *cs = cs_new(doc, res && res->type == kCGPDFObjectTypeDictionary ? res->v.dict : NULL, NULL);
    CGPDFObjectRef contents = NULL;
    if (pd && CGPDFDictionaryGetObject(pd, "Contents", &contents)) {
        if (contents->type == kCGPDFObjectTypeStream) cs_add(cs, contents->v.stream);
        else if (contents->type == kCGPDFObjectTypeArray)
            for (size_t i = 0; i < CGPDFArrayGetCount(contents->v.arr); i++) {
                CGPDFStreamRef s;
                if (CGPDFArrayGetStream(contents->v.arr, i, &s)) cs_add(cs, s);
            }
    }
    return cs;
}
CGPDFContentStreamRef CGPDFContentStreamCreateWithStream(CGPDFStreamRef stream, CGPDFDictionaryRef resources, CGPDFContentStreamRef parent) {
    struct CGPDFContentStream *cs = cs_new(stream ? stream->doc : NULL, (struct CGPDFDictionary *)resources, parent);
    if (stream) cs_add(cs, stream);
    return cs;
}
CGPDFContentStreamRef CGPDFContentStreamRetain(CGPDFContentStreamRef cs) { if (cs) cs->refs++; return cs; }
void CGPDFContentStreamRelease(CGPDFContentStreamRef cs) {
    if (!cs || --cs->refs > 0) return;
    if (cs->parent) CGPDFContentStreamRelease(cs->parent);
    if (cs->cfstreams) CFRelease(cs->cfstreams);
    free(cs->streams); free(cs);
}
CFArrayRef CGPDFContentStreamGetStreams(CGPDFContentStreamRef cs) {
    if (!cs) return NULL;
    if (!cs->cfstreams) cs->cfstreams = CFArrayCreate(NULL, (const void **)cs->streams, (CFIndex)cs->nstreams, NULL);
    return cs->cfstreams;
}
CGPDFObjectRef CGPDFContentStreamGetResource(CGPDFContentStreamRef cs, const char *category, const char *name) {
    for (; cs; cs = cs->parent) {
        CGPDFDictionaryRef cat; CGPDFObjectRef o;
        if (CGPDFDictionaryGetDictionary(cs->resources, category, &cat) && CGPDFDictionaryGetObject(cat, name, &o)) return o;
    }
    return NULL;
}

CGPDFOperatorTableRef CGPDFOperatorTableCreate(void) {
    struct CGPDFOperatorTable *t = calloc(1, sizeof *t);
    t->refs = 1;
    return t;
}
CGPDFOperatorTableRef CGPDFOperatorTableRetain(CGPDFOperatorTableRef t) { if (t) t->refs++; return t; }
void CGPDFOperatorTableRelease(CGPDFOperatorTableRef t) { if (t && --t->refs <= 0) { free(t->ops); free(t); } }
void CGPDFOperatorTableSetCallback(CGPDFOperatorTableRef t, const char *name, CGPDFOperatorCallback cb) {
    if (!t || !name || strlen(name) >= sizeof t->ops->name) return;
    for (size_t i = 0; i < t->n; i++) if (!strcmp(t->ops[i].name, name)) { t->ops[i].cb = cb; return; }
    if (t->n == t->cap) { t->cap = t->cap ? t->cap * 2 : 32; t->ops = realloc(t->ops, t->cap * sizeof *t->ops); }
    strcpy(t->ops[t->n].name, name); t->ops[t->n].cb = cb; t->n++;
}
static CGPDFOperatorCallback lookup(struct CGPDFOperatorTable *t, const char *name) {
    if (!t) return NULL;
    for (size_t i = 0; i < t->n; i++) if (!strcmp(t->ops[i].name, name)) return t->ops[i].cb;
    return NULL;
}

CGPDFScannerRef CGPDFScannerCreate(CGPDFContentStreamRef cs, CGPDFOperatorTableRef table, void *info) {
    struct CGPDFScanner *s = calloc(1, sizeof *s);
    s->refs = 1; s->cs = CGPDFContentStreamRetain(cs); s->table = CGPDFOperatorTableRetain(table); s->info = info;
    return s;
}
CGPDFScannerRef CGPDFScannerRetain(CGPDFScannerRef s) { if (s) s->refs++; return s; }
void CGPDFScannerRelease(CGPDFScannerRef s) {
    if (!s || --s->refs > 0) return;
    if (s->cs) CGPDFContentStreamRelease(s->cs);
    if (s->table) CGPDFOperatorTableRelease(s->table);
    free(s->stack); free(s);
}
CGPDFContentStreamRef CGPDFScannerGetContentStream(CGPDFScannerRef s) { return s ? s->cs : NULL; }
void CGPDFScannerStop(CGPDFScannerRef s) { if (s) s->stop = 1; }
static void push(struct CGPDFScanner *s, struct CGPDFObject *o) {
    if (s->n == s->cap) { s->cap = s->cap ? s->cap * 2 : 16; s->stack = realloc(s->stack, s->cap * sizeof *s->stack); }
    s->stack[s->n++] = o;
}
/* an inline image after BI: its dictionary up to ID, then its data up to EI (white space around) */
static struct CGPDFObject *inline_image(pdflex *lx) {
    struct pdoc *d = lx->doc;
    size_t cap = 8, n = 0;
    const char **keys = malloc(cap * sizeof *keys);
    struct CGPDFObject *vals = malloc(cap * sizeof *vals);
    for (;;) {
        struct CGPDFObject k;
        if (!isim_pdf_lex_object(lx, &k)) break;
        if (k.type == -1 && !strcmp(k.v.name, "ID")) break;
        if (k.type != kCGPDFObjectTypeName) continue;
        if (n == cap) { cap *= 2; keys = realloc(keys, cap * sizeof *keys); vals = realloc(vals, cap * sizeof *vals); }
        if (!isim_pdf_lex_object(lx, &vals[n])) break;
        keys[n++] = k.v.name;
    }
    if (lx->p < lx->end) lx->p++;                                       /* the single white-space byte after ID */
    const unsigned char *start = lx->p, *e = start;
    for (; e + 2 <= lx->end; e++)
        if (e[0] == 'E' && e[1] == 'I' && (e == start || e[-1] <= ' ') && (e + 2 == lx->end || e[2] <= ' ')) break;
    if (e + 2 > lx->end) e = lx->end;
    const unsigned char *data_end = e;
    if (data_end > start && (data_end[-1] == '\n' || data_end[-1] == ' ')) data_end--;      /* the white space before EI */
    if (data_end > start && data_end[-1] == '\r') data_end--;
    lx->p = e + 2 <= lx->end ? e + 2 : lx->end;
    struct CGPDFDictionary *dict = isim_pdf_arena_alloc(d, sizeof *dict);
    dict->doc = d; dict->n = n;
    dict->keys = isim_pdf_arena_alloc(d, (n ? n : 1) * sizeof *keys); dict->vals = isim_pdf_arena_alloc(d, (n ? n : 1) * sizeof *vals);
    memcpy(dict->keys, keys, n * sizeof *keys); memcpy(dict->vals, vals, n * sizeof *vals);
    free(keys); free(vals);
    struct CGPDFStream *st = isim_pdf_arena_alloc(d, sizeof *st);
    st->doc = d; st->dict = dict; st->raw = start; st->len = (size_t)(data_end - start);
    struct CGPDFObject *o = isim_pdf_arena_alloc(d, sizeof *o);
    o->type = kCGPDFObjectTypeStream; o->v.stream = st;
    return o;
}
bool CGPDFScannerScan(CGPDFScannerRef s) {
    if (!s || !s->cs) return false;
    struct CGPDFContentStream *cs = s->cs;
    if (!cs->doc) return cs->nstreams == 0;
    size_t total = 0, cap = 0;
    unsigned char *all = NULL;
    for (size_t i = 0; i < cs->nstreams; i++) {                         /* the streams, concatenated */
        size_t n; CGPDFDataFormat f;
        unsigned char *p = isim_pdf_stream_decode(cs->streams[i], &n, &f);
        if (!p) continue;
        if (total + n + 1 > cap) { cap = (total + n + 1) * 2; all = realloc(all, cap); }
        memcpy(all + total, p, n); total += n; all[total++] = '\n';
        free(p);
    }
    unsigned char *text = isim_pdf_arena_alloc(cs->doc, total + 1);    /* operands point into it */
    if (all) memcpy(text, all, total);
    free(all);
    pdflex lx = { cs->doc, text, text + total };
    s->stop = 0; s->n = 0;
    int depth = 0;
    while (!s->stop) {
        struct CGPDFObject tmp;
        if (!isim_pdf_lex_object(&lx, &tmp)) break;
        if (tmp.type == -1) {
            const char *op = tmp.v.name;
            if (!strcmp(op, "{") || !strcmp(op, "}")) { s->n = 0; continue; }
            if (!strcmp(op, "BI")) push(s, inline_image(&lx));
            if (!strcmp(op, "BX")) depth++;
            if (!strcmp(op, "EX") && depth > 0) depth--;
            CGPDFOperatorCallback cb = lookup(s->table, op);
            if (cb) cb(s, s->info);
            s->n = 0;
            continue;
        }
        struct CGPDFObject *o = isim_pdf_arena_alloc(cs->doc, sizeof *o);
        *o = tmp;
        push(s, o);
    }
    return !s->stop;                          /* false when a callback stopped it */
}
static struct CGPDFObject *top(struct CGPDFScanner *s) { return s && s->n ? s->stack[s->n - 1] : NULL; }
bool CGPDFScannerPopObject(CGPDFScannerRef s, CGPDFObjectRef *v) {
    struct CGPDFObject *o = top(s);
    if (!o) return false;
    s->n--;
    if (v) *v = o;
    return true;
}
static bool pop_typed(struct CGPDFScanner *s, CGPDFObjectType type, void *v) {
    struct CGPDFObject *o = top(s);
    if (!o || !CGPDFObjectGetValue(o, type, v)) return false;
    s->n--;
    return true;
}
bool CGPDFScannerPopBoolean(CGPDFScannerRef s, CGPDFBoolean *v) { return pop_typed(s, kCGPDFObjectTypeBoolean, v); }
bool CGPDFScannerPopInteger(CGPDFScannerRef s, CGPDFInteger *v) { return pop_typed(s, kCGPDFObjectTypeInteger, v); }
bool CGPDFScannerPopNumber(CGPDFScannerRef s, CGPDFReal *v) { return pop_typed(s, kCGPDFObjectTypeReal, v); }
bool CGPDFScannerPopName(CGPDFScannerRef s, const char **v) { return pop_typed(s, kCGPDFObjectTypeName, v); }
bool CGPDFScannerPopString(CGPDFScannerRef s, CGPDFStringRef *v) { return pop_typed(s, kCGPDFObjectTypeString, v); }
bool CGPDFScannerPopArray(CGPDFScannerRef s, CGPDFArrayRef *v) { return pop_typed(s, kCGPDFObjectTypeArray, v); }
bool CGPDFScannerPopDictionary(CGPDFScannerRef s, CGPDFDictionaryRef *v) { return pop_typed(s, kCGPDFObjectTypeDictionary, v); }
bool CGPDFScannerPopStream(CGPDFScannerRef s, CGPDFStreamRef *v) { return pop_typed(s, kCGPDFObjectTypeStream, v); }
