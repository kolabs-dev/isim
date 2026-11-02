/* libisim_host braille (issue #426): Accessibility's AXBrailleTranslator over the host's liblouis (dlopen'd when an app
   first translates). The tables are liblouis's: those whose header names a language (#+language), read from the
   liblouis table directory (LOUIS_TABLEPATH, else /usr/share/liblouis/tables). Translation gives Unicode braille
   (U+2800...) and, per output character, the input character it came from; back-translation reads Unicode braille.
   Without liblouis there are no tables and translations fail (0). */
#include "guest_abi.h"
#include <dirent.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef int (*lou_tr_fn)(const char *, const void *, int *, void *, int *, void *, char *, int *, int *, int *, int);
static struct { int state, wsize; lou_tr_fn translate, back; int (*char_size)(void); } lou;
static pthread_mutex_t lou_lock = PTHREAD_MUTEX_INITIALIZER;

static int load(void) {
    if (lou.state) return lou.state > 0;
    lou.state = -1;
    void *lib = dlopen("liblouis.so.20", RTLD_NOW | RTLD_LOCAL);   /* linux-only: liblouis's soname (until #491's library table) */
    if (!lib) lib = dlopen("liblouis.so", RTLD_NOW | RTLD_LOCAL);  /* linux-only: liblouis's soname (until #491's library table) */
    if (!lib) return 0;
    lou.translate = (lou_tr_fn)dlsym(lib, "lou_translate");
    lou.back = (lou_tr_fn)dlsym(lib, "lou_backTranslate");
    lou.char_size = (int (*)(void))dlsym(lib, "lou_charSize");
    if (!lou.translate || !lou.back || !lou.char_size) return 0;
    lou.wsize = lou.char_size();
    if (lou.wsize != 2 && lou.wsize != 4) return 0;
    lou.state = 1;
    return 1;
}

static const char *table_dir(void) {
    const char *p = getenv("LOUIS_TABLEPATH");
    return p && *p ? p : "/usr/share/liblouis/tables";
}

ISIM_GUEST_ABI int isim_braille_available(void) { pthread_mutex_lock(&lou_lock); int ok = load(); pthread_mutex_unlock(&lou_lock); return ok; }

/* one line per table: file \t language \t display name \t dots (6 or 8) \t contraction (no, partial, full) \t grade
   \t direction (both, forward) \t region \t system (ueb, ...); the caller frees it (isim_media_free). NULL without liblouis. */
ISIM_GUEST_ABI char *isim_braille_tables(void) {
    if (!isim_braille_available()) return NULL;
    char dirpath[1024];
    snprintf(dirpath, sizeof dirpath, "%s", table_dir());
    char *colon = strchr(dirpath, ':');
    if (colon) *colon = 0;                                   /* the first directory of a path list */
    DIR *d = opendir(dirpath);
    if (!d) return NULL;
    size_t cap = 4096, len = 0;
    char *out = malloc(cap);
    out[0] = 0;
    struct dirent *e;
    while ((e = readdir(d))) {
        const char *n = e->d_name, *dot = strrchr(n, '.');
        if (!dot || (strcmp(dot, ".ctb") && strcmp(dot, ".utb") && strcmp(dot, ".tbl"))) continue;
        char path[2048];
        snprintf(path, sizeof path, "%s/%s", dirpath, n);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        char line[512], lang[64] = "", name[256] = "", dots[8] = "6", contraction[16] = "no", grade[8] = "", dir[16] = "both", region[32] = "", sys[32] = "";
        for (int i = 0; i < 80 && fgets(line, sizeof line, f); i++) {
            if (line[0] != '#' || (line[1] != '+' && line[1] != '-')) continue;
            char *key = line + 2, *val = strchr(key, ':');
            if (!val) continue;
            *val++ = 0;
            while (*val == ' ') val++;
            val[strcspn(val, "\r\n")] = 0;
            if (!strcmp(key, "language")) snprintf(lang, sizeof lang, "%s", val);
            else if (!strcmp(key, "display-name") || (!name[0] && !strcmp(key, "index-name"))) snprintf(name, sizeof name, "%s", val);
            else if (!strcmp(key, "dots")) snprintf(dots, sizeof dots, "%s", val);
            else if (!strcmp(key, "contraction")) snprintf(contraction, sizeof contraction, "%s", val);
            else if (!strcmp(key, "grade")) snprintf(grade, sizeof grade, "%s", val);
            else if (!strcmp(key, "direction")) snprintf(dir, sizeof dir, "%s", val);
            else if (!strcmp(key, "region")) snprintf(region, sizeof region, "%s", val);
            else if (!strcmp(key, "system")) snprintf(sys, sizeof sys, "%s", val);
        }
        fclose(f);
        if (!lang[0] || !name[0]) continue;
        char row[1024];
        int k = snprintf(row, sizeof row, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", n, lang, name, dots, contraction, grade, dir, region, sys);
        if (k <= 0) continue;
        if (len + (size_t)k + 1 > cap) { cap = (cap + (size_t)k) * 2; out = realloc(out, cap); }
        memcpy(out + len, row, (size_t)k + 1);
        len += (size_t)k;
    }
    closedir(d);
    return out;
}

/* UTF-8 <-> code points */
static uint32_t *decode(const char *s, int *n) {
    size_t len = strlen(s);
    uint32_t *out = malloc(sizeof(uint32_t) * (len + 1));
    int k = 0;
    for (size_t i = 0; i < len;) {
        unsigned char c = (unsigned char)s[i];
        uint32_t cp; int extra;
        if (c < 0x80) { cp = c; extra = 0; } else if ((c & 0xE0) == 0xC0) { cp = c & 0x1F; extra = 1; }
        else if ((c & 0xF0) == 0xE0) { cp = c & 0x0F; extra = 2; } else { cp = c & 0x07; extra = 3; }
        i++;
        for (int j = 0; j < extra && i < len; j++, i++) cp = (cp << 6) | ((unsigned char)s[i] & 0x3F);
        out[k++] = cp;
    }
    *n = k;
    return out;
}
static char *encode(const uint32_t *cp, int n) {
    char *out = malloc((size_t)n * 4 + 1), *p = out;
    for (int i = 0; i < n; i++) {
        uint32_t c = cp[i];
        if (c < 0x80) *p++ = (char)c;
        else if (c < 0x800) { *p++ = (char)(0xC0 | (c >> 6)); *p++ = (char)(0x80 | (c & 0x3F)); }
        else if (c < 0x10000) { *p++ = (char)(0xE0 | (c >> 12)); *p++ = (char)(0x80 | ((c >> 6) & 0x3F)); *p++ = (char)(0x80 | (c & 0x3F)); }
        else { *p++ = (char)(0xF0 | (c >> 18)); *p++ = (char)(0x80 | ((c >> 12) & 0x3F)); *p++ = (char)(0x80 | ((c >> 6) & 0x3F)); *p++ = (char)(0x80 | (c & 0x3F)); }
    }
    *p = 0;
    return out;
}

/* Translates UTF-8 `text` with `table` (a liblouis table file name) to Unicode braille, or back from Unicode braille
   when `back`. Returns the UTF-8 result (free with isim_media_free) and, in *positions (also freed by the caller), the
   input character index of each output character; NULL on failure. */
ISIM_GUEST_ABI char *isim_braille_translate(const char *table, const char *text, int back, int **positions, int *count) {
    if (positions) *positions = NULL;
    if (count) *count = 0;
    if (!table || !text || !isim_braille_available()) return NULL;
    int n = 0;
    uint32_t *in32 = decode(text, &n);
    int cap = n * 8 + 64, inlen = n, outlen = cap;
    void *in = malloc((size_t)(n + 1) * (size_t)lou.wsize), *out = malloc((size_t)cap * (size_t)lou.wsize);
    for (int i = 0; i < n; i++) {
        if (lou.wsize == 4) ((uint32_t *)in)[i] = in32[i];
        else ((uint16_t *)in)[i] = (uint16_t)(in32[i] > 0xFFFF ? 0xFFFD : in32[i]);
    }
    int *inputPos = calloc((size_t)cap, sizeof(int));
    char tables[1100];                                       /* liblouis's Unicode braille display table, then the table */
    snprintf(tables, sizeof tables, "unicode.dis,%s", table);
    pthread_mutex_lock(&lou_lock);
    int ok = (back ? lou.back : lou.translate)(tables, in, &inlen, out, &outlen, NULL, NULL, NULL, inputPos, NULL, 0);
    pthread_mutex_unlock(&lou_lock);
    char *res = NULL;
    if (ok) {
        uint32_t *o32 = malloc(sizeof(uint32_t) * (size_t)(outlen + 1));
        for (int i = 0; i < outlen; i++) o32[i] = lou.wsize == 4 ? ((uint32_t *)out)[i] : ((uint16_t *)out)[i];
        res = encode(o32, outlen);
        free(o32);
        if (positions) { *positions = inputPos; inputPos = NULL; }
        if (count) *count = outlen;
    }
    free(inputPos); free(in); free(out); free(in32);
    return res;
}
