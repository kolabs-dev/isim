/* isim CoreGraphics: the PDF object model (CGPDFParser.c, CGPDFScanner.c, CGPDFCrypt.c). isim reads a PDF's objects
 * itself (poppler only renders): every object of a document lives in its arena and stays valid as long as the
 * document, like Core Graphics' CGPDFDictionaryRef and friends. */
#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <stddef.h>
#include <stdint.h>

struct pdoc;
enum { PDF_REF = 100 };                       /* an unresolved indirect reference (never handed out) */

struct CGPDFObject {
    int32_t type;                             /* CGPDFObjectType, or PDF_REF */
    union {
        bool b; long i; double r; const char *name;
        struct CGPDFString *str; struct CGPDFArray *arr; struct CGPDFDictionary *dict; struct CGPDFStream *stream;
        struct { int num, gen; } ref;
    } v;
};
struct CGPDFString { size_t len; unsigned char *bytes; };
struct CGPDFArray { struct pdoc *doc; size_t n; struct CGPDFObject *items; };
struct CGPDFDictionary { struct pdoc *doc; size_t n; const char **keys; struct CGPDFObject *vals; };
struct CGPDFStream {
    struct pdoc *doc; struct CGPDFDictionary *dict;
    const unsigned char *raw; size_t len;     /* the encoded bytes (in the file, or an inline image's) */
    int num, gen;                             /* its object, for decryption (0: not encrypted) */
};

/* a document's objects: parsing, the cross-reference table, decryption */
struct pdoc *isim_pdf_doc_open(const unsigned char *data, size_t len);
void isim_pdf_doc_free(struct pdoc *d);
struct CGPDFDictionary *isim_pdf_doc_trailer(struct pdoc *d);
struct CGPDFDictionary *isim_pdf_doc_catalog(struct pdoc *d);
void isim_pdf_doc_version(struct pdoc *d, int *major, int *minor);
int isim_pdf_doc_encrypted(struct pdoc *d);
int isim_pdf_doc_unlocked(struct pdoc *d);
int isim_pdf_doc_owner(struct pdoc *d);                          /* unlocked with the owner password, or not encrypted */
int isim_pdf_doc_unlock(struct pdoc *d, const char *password);   /* 1 user, 2 owner password, 0 wrong */
uint32_t isim_pdf_doc_permissions(struct pdoc *d);               /* the /P bits (all set when not encrypted or owner) */
const char *isim_pdf_doc_password(struct pdoc *d);               /* the password that unlocked it (for poppler) */
/* the page dictionaries in order (the page tree flattened); count in *n */
struct CGPDFDictionary **isim_pdf_doc_pages(struct pdoc *d, int *n);
/* resolves an indirect reference (objects are returned resolved) */
struct CGPDFObject *isim_pdf_resolve(struct pdoc *d, struct CGPDFObject *o);
/* a dictionary value, inherited through /Parent (page attributes) */
struct CGPDFObject *isim_pdf_inherited(struct CGPDFDictionary *page, const char *key);
/* the decoded bytes of a stream (malloc'd); *format: CGPDFDataFormat; NULL when it cannot be decoded */
unsigned char *isim_pdf_stream_decode(struct CGPDFStream *s, size_t *n, CGPDFDataFormat *format);
/* parses a content stream's next token into *o (operators: type -1, v.name the operator); 0 at the end */
typedef struct pdflex { struct pdoc *doc; const unsigned char *p, *end; } pdflex;
int isim_pdf_lex_object(pdflex *lx, struct CGPDFObject *o);
void *isim_pdf_arena_alloc(struct pdoc *d, size_t n);

/* CGPDFCrypt.c */
void isim_pdf_md5(const uint8_t *data, size_t n, uint8_t out[16]);
void isim_pdf_rc4(const uint8_t *key, size_t keylen, uint8_t *buf, size_t n);
void isim_pdf_aes_cbc_decrypt(const uint8_t *key, int keylen, const uint8_t *iv, uint8_t *buf, size_t n);
void isim_pdf_aes_cbc_encrypt(const uint8_t *key, int keylen, const uint8_t *iv, uint8_t *buf, size_t n);
void isim_pdf_sha256(const uint8_t *data, size_t n, uint8_t out[32]);
void isim_pdf_sha512(const uint8_t *data, size_t n, uint8_t *out, int bits);
