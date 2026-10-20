/* isim host: XML parsing for NSXMLParser (issue #265), with the host's libxml2 SAX2 push parser (loaded on first use),
 * the parser Apple's NSXMLParser is built on (so its error codes are libxml2's). The callbacks are recorded as a
 * stream the guest replays to its delegate; each record is a type byte, then fields separated by \x1f, then \x1e
 * (XML 1.0 text cannot contain either). The first two fields are the line and column. Records:
 *   'D'                                   document start            'd'   document end
 *   'S' local prefix uri nns [prefix uri]* natt [local prefix uri value]*   element start (namespaces it declares)
 *   'E' local prefix uri                  element end
 *   'T' text                              characters (an internal entity's replacement text comes as callbacks)
 *   'A' text                              CDATA
 *   'C' text                              comment
 *   'P' target data                       processing instruction
 *   'L' name model                        element declaration
 *   'B' element name type default         attribute declaration
 *   'N' name public system                notation declaration
 *   'U' name public system notation       unparsed entity declaration
 *   'I' name value                        internal entity declaration
 *   'J' name public system                external entity declaration
 *   'X' code message                      the first error (parsing stops there, like Apple's)
 * Returns the stream's length (written up to cap, NUL-terminated), or -1 without libxml2. */
#include "guest_abi.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* libxml2's SAX handler (version 2), error and entity structs (stable since libxml2 2.6) */
typedef void (*Fn)(void);
typedef struct {
    Fn internalSubset, isStandalone, hasInternalSubset, hasExternalSubset;
    void *(*resolveEntity)(void *, const char *, const char *);
    void *(*getEntity)(void *, const char *);
    void (*entityDecl)(void *, const char *, int, const char *, const char *, char *);
    void (*notationDecl)(void *, const char *, const char *, const char *);
    void (*attributeDecl)(void *, const char *, const char *, int, int, const char *, void *);
    void (*elementDecl)(void *, const char *, int, void *);
    void (*unparsedEntityDecl)(void *, const char *, const char *, const char *, const char *);
    Fn setDocumentLocator;
    void (*startDocument)(void *);
    void (*endDocument)(void *);
    Fn startElement, endElement;
    void (*reference)(void *, const char *);
    void (*characters)(void *, const char *, int);
    void (*ignorableWhitespace)(void *, const char *, int);
    void (*processingInstruction)(void *, const char *, const char *);
    void (*comment)(void *, const char *);
    Fn warning, error, fatalError, getParameterEntity;
    void (*cdataBlock)(void *, const char *, int);
    Fn externalSubset;
    unsigned initialized;
    void *_private;
    void (*startElementNs)(void *, const char *, const char *, const char *, int, const char **, int, int, const char **);
    void (*endElementNs)(void *, const char *, const char *, const char *);
    void (*serror)(void *, void *);
} SAX;
typedef struct { int domain, code; char *message; int level; char *file; int line; char *str1, *str2, *str3; int int1, int2; } XErr;
typedef struct {
    void *_private; int type; const char *name;
    void *children, *last, *parent, *next, *prev, *doc;
    char *orig, *content; int length, etype;
} XEntity;
enum { NOENT = 2, DTDLOAD = 4, NOERROR = 32, NOWARNING = 64, NONET = 2048 };
enum { ERR_ERROR = 2 };
static const char *const xml2_names[] = { "libxml2.so.2", "libxml2.so.16", NULL };   /* a table per host OS: Linux's */

static struct {
    int (*saxVersion)(SAX *, int);
    void *(*createPush)(SAX *, void *, const char *, int, const char *);
    int (*useOptions)(void *, int);
    int (*parseChunk)(void *, const char *, int, int);
    void (*freeCtxt)(void *);
    void (*freeDoc)(void *);
    void (*stop)(void *);
    int (*line)(void *), (*column)(void *);
    int (*contentString)(char *, int, void *, int);
} X;
static SAX defaults;                       /* libxml2's own SAX2 handlers, which keep the DTD's tables */
static int loaded;

static void load(void) {
    void *h = NULL;
    for (int i = 0; !h && xml2_names[i]; i++) h = dlopen(xml2_names[i], RTLD_NOW | RTLD_LOCAL);
    if (!h) return;
    X.saxVersion = dlsym(h, "xmlSAXVersion");
    X.createPush = dlsym(h, "xmlCreatePushParserCtxt");
    X.useOptions = dlsym(h, "xmlCtxtUseOptions");
    X.parseChunk = dlsym(h, "xmlParseChunk");
    X.freeCtxt = dlsym(h, "xmlFreeParserCtxt");
    X.freeDoc = dlsym(h, "xmlFreeDoc");
    X.stop = dlsym(h, "xmlStopParser");
    X.line = dlsym(h, "xmlSAX2GetLineNumber");
    X.column = dlsym(h, "xmlSAX2GetColumnNumber");
    X.contentString = dlsym(h, "xmlSnprintfElementContent");
    loaded = X.saxVersion && X.createPush && X.useOptions && X.parseChunk && X.freeCtxt && X.freeDoc && X.stop && X.line &&
             X.column && X.saxVersion(&defaults, 2) == 0;
}

/* the parse in progress (parsing is synchronous, one per thread) */
typedef struct { char *out; long cap, n; void *ctxt; int failed; } Rec;
static __thread Rec *cur;

static void raw(const char *s, long len) {
    for (long i = 0; i < len; i++) {
        if (cur->n < cur->cap - 1) cur->out[cur->n] = s[i];
        cur->n++;
    }
}
static void field(const char *s) { raw("\x1f", 1); if (s) raw(s, (long)strlen(s)); }
static void fieldn(const char *s, int len) { raw("\x1f", 1); if (s) raw(s, len); }
static void num(long v) { char b[32]; snprintf(b, sizeof b, "%ld", v); field(b); }
static void begin(char type) {
    raw(&type, 1);
    char b[48]; int k = snprintf(b, sizeof b, "%d\x1f%d", X.line(cur->ctxt), X.column(cur->ctxt));
    raw(b, k);
}
static void end(void) { raw("\x1e", 1); }

static void on_start_document(void *ctx) { defaults.startDocument(ctx); begin('D'); end(); }
static void on_end_document(void *ctx) { begin('d'); end(); }
/* an attribute's value: libxml2 leaves "&" as "&#38;" and internal entities as references when it does not substitute */
static void value(const char *s, const char *e) {
    raw("\x1f", 1);
    while (s < e) {
        const char *semi = *s == '&' ? memchr(s, ';', (size_t)(e - s)) : NULL;
        if (semi && semi - s == 4 && !memcmp(s, "&#38", 4)) { raw("&", 1); s = semi + 1; continue; }
        if (semi && semi - s > 1 && semi - s < 128 && s[1] != '#') {
            char name[128];
            memcpy(name, s + 1, (size_t)(semi - s - 1)); name[semi - s - 1] = 0;
            XEntity *ent = defaults.getEntity(cur->ctxt, name);
            if (ent && ent->etype == 1 && ent->content) { raw(ent->content, (long)strlen(ent->content)); s = semi + 1; continue; }
        }
        raw(s, 1); s++;
    }
}
static void on_start(void *ctx, const char *local, const char *prefix, const char *uri, int nns, const char **ns, int natt,
                     int ndefaulted, const char **att) {
    begin('S'); field(local); field(prefix); field(uri);
    num(nns);
    for (int i = 0; i < nns; i++) { field(ns[2 * i]); field(ns[2 * i + 1]); }
    num(natt);
    for (int i = 0; i < natt; i++) {
        const char **a = att + 5 * i;
        field(a[0]); field(a[1]); field(a[2]); value(a[3], a[4]);
    }
    end();
}
static void on_end(void *ctx, const char *local, const char *prefix, const char *uri) { begin('E'); field(local); field(prefix); field(uri); end(); }
static void on_characters(void *ctx, const char *s, int len) { begin('T'); fieldn(s, len); end(); }
static void on_cdata(void *ctx, const char *s, int len) { begin('A'); fieldn(s, len); end(); }
static void on_comment(void *ctx, const char *s) { begin('C'); field(s); end(); }
static void on_pi(void *ctx, const char *target, const char *data) { begin('P'); field(target); field(data); end(); }
static void on_element_decl(void *ctx, const char *name, int type, void *content) {
    char model[4096] = "";
    if (type == 1 || type == 2) strcpy(model, type == 1 ? "EMPTY" : "ANY");    /* no content model */
    else if (content && X.contentString) X.contentString(model, sizeof model, content, 1);
    begin('L'); field(name); field(model); end();
    defaults.elementDecl(ctx, name, type, content);
}
static void on_attribute_decl(void *ctx, const char *elem, const char *name, int type, int def, const char *value, void *tree) {
    static const char *const types[] = { "", "CDATA", "ID", "IDREF", "IDREFS", "ENTITY", "ENTITIES", "NMTOKEN", "NMTOKENS",
                                         "ENUMERATION", "NOTATION" };
    begin('B'); field(elem); field(name); field(type >= 1 && type <= 10 ? types[type] : ""); field(value); end();
    defaults.attributeDecl(ctx, elem, name, type, def, value, tree);      /* frees tree */
}
static void on_notation_decl(void *ctx, const char *name, const char *pub, const char *sys) {
    begin('N'); field(name); field(pub); field(sys); end();
    defaults.notationDecl(ctx, name, pub, sys);
}
static void on_unparsed_decl(void *ctx, const char *name, const char *pub, const char *sys, const char *notation) {
    begin('U'); field(name); field(pub); field(sys); field(notation); end();
    defaults.unparsedEntityDecl(ctx, name, pub, sys, notation);
}
static void on_entity_decl(void *ctx, const char *name, int type, const char *pub, const char *sys, char *content) {
    if (type == 1) { begin('I'); field(name); field(content); end(); }                 /* internal general entity */
    else if (type == 2) { begin('J'); field(name); field(pub); field(sys); end(); }    /* external parsed entity */
    defaults.entityDecl(ctx, name, type, pub, sys, content);
}
static void *no_external(void *ctx, const char *pub, const char *sys) { return NULL; }
static void on_error(void *ctx, void *e) {
    XErr *err = e;
    if (cur->failed || !err || err->level < ERR_ERROR) return;
    cur->failed = 1;
    char msg[512] = "";
    if (err->message) snprintf(msg, sizeof msg, "%s", err->message);
    size_t k = strlen(msg);
    while (k && (msg[k - 1] == '\n' || msg[k - 1] == ' ')) msg[--k] = 0;
    char b[48]; int len = snprintf(b, sizeof b, "X%d\x1f%d", err->line, err->int2);
    raw(b, len); num(err->code); field(msg); end();
    X.stop(cur->ctxt);
}

/* flags: 1 resolve external entities (the DTD and parsed entities, never from the network) */
ISIM_GUEST_ABI long isim_xml_sax(const char *xml, long len, int flags, char *out, long cap) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, load);
    if (!loaded) return -1;
    SAX sax = defaults;
    sax.startDocument = on_start_document; sax.endDocument = on_end_document;
    sax.startElementNs = on_start; sax.endElementNs = on_end;
    sax.characters = on_characters; sax.ignorableWhitespace = on_characters; sax.cdataBlock = on_cdata;
    sax.comment = on_comment; sax.processingInstruction = on_pi; sax.reference = NULL;   /* libxml2 parses an internal entity's text through the callbacks above */
    sax.elementDecl = on_element_decl; sax.attributeDecl = on_attribute_decl; sax.notationDecl = on_notation_decl;
    sax.unparsedEntityDecl = on_unparsed_decl; sax.entityDecl = on_entity_decl;
    sax.serror = on_error; sax.warning = sax.error = sax.fatalError = NULL;
    if (!(flags & 1)) sax.resolveEntity = no_external;
    Rec r = { out, cap, 0, NULL, 0 };
    Rec *saved = cur;
    cur = &r;
    void *ctxt = X.createPush(&sax, NULL, NULL, 0, NULL);
    if (ctxt) {
        r.ctxt = ctxt;
        X.useOptions(ctxt, NOERROR | NOWARNING | NONET | (flags & 1 ? DTDLOAD | NOENT : 0));
        for (long at = 0; !r.failed && at < len; at += 1 << 20) {
            long n = len - at < 1 << 20 ? len - at : 1 << 20;
            X.parseChunk(ctxt, xml + at, (int)n, 0);
        }
        if (!r.failed) X.parseChunk(ctxt, NULL, 0, 1);
        void *doc = ((void **)ctxt)[2];                   /* xmlParserCtxt.myDoc (after sax and userData) */
        if (doc) X.freeDoc(doc);
        X.freeCtxt(ctxt);
    }
    cur = saved;
    if (cap > 0) out[r.n < cap ? r.n : cap - 1] = 0;
    return r.n;
}
