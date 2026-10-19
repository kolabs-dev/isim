/* isim host: HTML parsing for NSAttributedString's HTML import (issue #238), with the host's libxml2 (loaded on
 * first use; Linux distributions install it with practically every desktop). libxml2's HTML parser is forgiving like a
 * browser's: it decodes entities and the document's charset, closes implied elements and recovers from bad nesting.
 * The tree is flattened into a stream of records the guest maps to attributes:
 *   'S' name \x1f attr=value \x1f ...   an element starts (names lowercased)
 *   'E' name                            it ends
 *   'T' text                            text (UTF-8)
 * Records are separated by \x1e; \x1e and \x1f inside text become spaces. Comments and processing instructions are
 * dropped. Returns the length of the whole stream (written up to cap, NUL-terminated), or -1 without libxml2. */
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

/* libxml2's node and attribute structs (stable since libxml2 2.0; only the leading members are read) */
typedef struct HNode {
    void *_private; int type; const char *name;
    struct HNode *children, *last, *parent, *next, *prev;
    void *doc, *ns; char *content;
    struct HAttr *properties;
} HNode;
typedef struct HAttr {
    void *_private; int type; const char *name;
    HNode *children, *last, *parent;
    struct HAttr *next;
} HAttr;
enum { ELEMENT = 1, TEXT = 3, CDATA = 4, ENTITY_REF = 5 };
enum { RECOVER = 1, NOERROR = 32, NOWARNING = 64, NONET = 2048 };

static struct {
    void *(*readMemory)(const char *, int, const char *, const char *, int);
    HNode *(*root)(void *);
    void (*freeDoc)(void *);
} X;
static int loaded;

static void load(void) {
    void *h = dlopen("libxml2.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!h) h = dlopen("libxml2.so.16", RTLD_NOW | RTLD_LOCAL);
    if (!h) return;
    X.readMemory = dlsym(h, "htmlReadMemory");
    X.root = dlsym(h, "xmlDocGetRootElement");
    X.freeDoc = dlsym(h, "xmlFreeDoc");
    loaded = X.readMemory && X.root && X.freeDoc;
}

typedef struct { char *out; long cap, n; } Buf;
static void put(Buf *b, const char *s, long len) {
    for (long i = 0; i < len; i++) {
        char c = s[i] == '\x1e' || s[i] == '\x1f' ? ' ' : s[i];
        if (b->n < b->cap - 1) b->out[b->n] = c;
        b->n++;
    }
}
static void mark(Buf *b, char c) { if (b->n < b->cap - 1) b->out[b->n] = c; b->n++; }
static void lower(Buf *b, const char *s) {
    for (; s && *s; s++) { char c = *s >= 'A' && *s <= 'Z' ? *s + 32 : *s; put(b, &c, 1); }
}

static void walk(Buf *b, HNode *n) {
    for (; n; n = n->next) {
        if (n->type == ELEMENT) {
            mark(b, 'S'); lower(b, n->name);
            for (HAttr *a = n->properties; a; a = a->next) {
                mark(b, '\x1f'); lower(b, a->name); put(b, "=", 1);
                for (HNode *v = a->children; v; v = v->next) if (v->content) put(b, v->content, (long)strlen(v->content));
            }
            mark(b, '\x1e');
            walk(b, n->children);
            mark(b, 'E'); lower(b, n->name); mark(b, '\x1e');
        } else if ((n->type == TEXT || n->type == CDATA) && n->content) {
            mark(b, 'T'); put(b, n->content, (long)strlen(n->content)); mark(b, '\x1e');
        } else if (n->type == ENTITY_REF) {
            walk(b, n->children);
        }
    }
}

/* encoding: the document's charset ("UTF-8", "ISO-8859-1") or NULL to detect it (meta charset, else Latin-1) */
long isim_html_flatten(const char *html, long len, const char *encoding, char *out, long cap) {
    static pthread_once_t once = PTHREAD_ONCE_INIT;
    pthread_once(&once, load);
    if (!loaded) return -1;
    void *doc = X.readMemory(html, (int)len, NULL, encoding, RECOVER | NOERROR | NOWARNING | NONET);
    Buf b = { out, cap, 0 };
    if (doc) { walk(&b, X.root(doc)); X.freeDoc(doc); }
    if (cap > 0) out[b.n < cap ? b.n : cap - 1] = 0;
    return b.n;
}
