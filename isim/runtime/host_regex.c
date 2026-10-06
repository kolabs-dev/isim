/* isim host: regular expressions for Foundation's NSRegularExpression, backed by the host's PCRE2
 * (libpcre2-8, loaded on first use; it is installed with GLib on practically every Linux desktop).
 * PCRE2's syntax is close to ICU's, which NSRegularExpression uses on Apple platforms. Patterns and
 * subjects are UTF-8; offsets are byte offsets (Foundation converts them to UTF-16 indices). */
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/* PCRE2 ABI (pcre2.h, stable since 10.0) */
#define P_ALT_BSUX 0x00000002u
#define P_UTF 0x00080000u
#define P_UCP 0x00020000u
#define P_MATCH_INVALID_UTF 0x04000000u
#define P_EXTRA_ALT_BSUX 0x00000020u
#define P_NEWLINE_LF 2
#define P_NEWLINE_ANY 4
#define P_INFO_CAPTURECOUNT 4
typedef void pcode, pmatch, pctx;
static struct {
    pcode *(*compile)(const uint8_t *, size_t, uint32_t, int *, size_t *, pctx *);
    void (*code_free)(pcode *);
    pctx *(*ccontext_create)(void *);
    void (*ccontext_free)(pctx *);
    int (*set_newline)(pctx *, uint32_t);
    int (*set_extra)(pctx *, uint32_t);
    pmatch *(*md_create)(pcode *, void *);
    void (*md_free)(pmatch *);
    int (*match)(pcode *, const uint8_t *, size_t, size_t, uint32_t, pmatch *, void *);
    size_t *(*ovector)(pmatch *);
    uint32_t (*ovector_count)(pmatch *);
    int (*info)(pcode *, uint32_t, void *);
    int (*number_from_name)(pcode *, const uint8_t *);
    int (*error_message)(int, uint8_t *, size_t);
} P;
static int loaded = -1;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static void load(void) {
    void *h = dlopen("libpcre2-8.so.0", RTLD_NOW | RTLD_LOCAL);
    if (!h) h = dlopen("libpcre2-8.so", RTLD_NOW | RTLD_LOCAL);
    if (!h) { fprintf(stderr, "isim: NSRegularExpression needs libpcre2-8 on the host (not found)\n"); loaded = 0; return; }
#define L(f, n) *(void **)&P.f = dlsym(h, n)
    L(compile, "pcre2_compile_8"); L(code_free, "pcre2_code_free_8"); L(ccontext_create, "pcre2_compile_context_create_8");
    L(ccontext_free, "pcre2_compile_context_free_8"); L(set_newline, "pcre2_set_newline_8"); L(set_extra, "pcre2_set_compile_extra_options_8");
    L(md_create, "pcre2_match_data_create_from_pattern_8"); L(md_free, "pcre2_match_data_free_8"); L(match, "pcre2_match_8");
    L(ovector, "pcre2_get_ovector_pointer_8"); L(ovector_count, "pcre2_get_ovector_count_8"); L(info, "pcre2_pattern_info_8");
    L(number_from_name, "pcre2_substring_number_from_name_8"); L(error_message, "pcre2_get_error_message_8");
#undef L
    loaded = P.compile && P.match && P.md_create && P.ovector && P.ccontext_create && P.set_newline;
}

/* options: PCRE2 compile options (caseless, dotall, extended, multiline, literal); unix_lines: only \n ends lines.
 * Returns NULL on error (*err = PCRE2 error code, or 1 when PCRE2 is unavailable; *erroffset = byte offset). */
void *isim_regex_compile(const char *pattern, unsigned long len, unsigned int options, int unix_lines, int *err, unsigned long *erroffset) {
    pthread_once(&once, load);
    if (!loaded) { *err = 1; *erroffset = 0; return NULL; }
    pctx *ctx = P.ccontext_create(NULL);
    P.set_newline(ctx, unix_lines ? P_NEWLINE_LF : P_NEWLINE_ANY);
    if (P.set_extra) P.set_extra(ctx, P_EXTRA_ALT_BSUX);       /* ICU escapes: \uhhhh, \x{hhhh}, \x{h..} */
    size_t off = 0;
    pcode *code = P.compile((const uint8_t *)pattern, len, options | P_UTF | P_UCP | P_ALT_BSUX | P_MATCH_INVALID_UTF, err, &off, ctx);
    if (!code && P.set_extra) {  /* PCRE2 < 10.38: no EXTRA_ALT_BSUX */
        P.set_extra(ctx, 0);
        code = P.compile((const uint8_t *)pattern, len, options | P_UTF | P_UCP | P_ALT_BSUX | P_MATCH_INVALID_UTF, err, &off, ctx);
    }
    P.ccontext_free(ctx);
    *erroffset = off;
    return code;
}
void isim_regex_free(void *code) { if (code && loaded > 0) P.code_free(code); }
int isim_regex_capture_count(void *code) { uint32_t n = 0; if (code) P.info(code, P_INFO_CAPTURECOUNT, &n); return (int)n; }
int isim_regex_group_number(void *code, const char *name) { int n = P.number_from_name ? P.number_from_name(code, (const uint8_t *)name) : -1; return n < 0 ? -1 : n; }
void isim_regex_error_message(int err, char *buf, unsigned long n) {
    if (err == 1 && !loaded) { snprintf(buf, n, "regular expressions need libpcre2-8 on the host"); return; }
    if (!P.error_message || P.error_message(err, (uint8_t *)buf, n) < 0) snprintf(buf, n, "regex error %d", err);
}
/* Finds the next match at or after `start` in subject[0..len). ovector receives (start, end) byte pairs for
 * groups 0..pairs-1 (unset groups: -1). options: PCRE2 match options (anchored, notbol, noteol, notempty_atstart).
 * Returns the number of pairs set (> 0), 0 for no match, < 0 on error. */
int isim_regex_match(void *code, const char *subject, unsigned long len, unsigned long start, unsigned int options, long *ovector, int pairs) {
    if (!code) return -1;
    pmatch *md = P.md_create(code, NULL);
    int rc = P.match(code, (const uint8_t *)subject, len, start, options, md, NULL);
    if (rc > 0 || rc == 0) {
        size_t *ov = P.ovector(md);
        uint32_t cnt = P.ovector_count(md);
        for (int i = 0; i < pairs; i++) {
            if ((uint32_t)i < cnt && ov[2 * i] != ~(size_t)0) { ovector[2 * i] = (long)ov[2 * i]; ovector[2 * i + 1] = (long)ov[2 * i + 1]; }
            else ovector[2 * i] = ovector[2 * i + 1] = -1;
        }
        rc = pairs > 0 ? pairs : 1;
    } else if (rc == -1) rc = 0;   /* PCRE2_ERROR_NOMATCH */
    P.md_free(md);
    return rc;
}
