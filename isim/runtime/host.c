/*
 * libisim_host: the simulator "device" — window, input, software rendering and
 * system chrome. Guest UIKit calls these isim-private functions (install name
 * /usr/lib/libisim_host.dylib). Rendering: cairo + pango into an ARGB surface
 * presented through an SDL3 window surface (no GPU path).
 *
 * Environment:
 *   ISIM_DEVICE    iphone15 (default) | iphonese | ipad
 *   ISIM_ZOOM      window zoom factor (default 1)
 *   ISIM_HEADLESS  1 = no window (use with ISIM_SCRIPT)
 *   ISIM_SCRIPT    "wait S; tap X Y; drag X1 Y1 X2 Y2; shot FILE.png; quit" (points)
 *                  "tapid ID; holdid ID S" (view by accessibilityIdentifier), "type TEXT", "key backspace|return|tab|escape", "dump" (view tree), "taptext TEXT" (view showing that text)
 *                  shell only: "home", "launch BUNDLE-ID"
 *
 * Shell mode (`isim boot`): isim_shell_main() owns the window; every app (home screen, Settings,
 * installed apps) is a child process ("client") that renders into a shared-memory surface and
 * receives input/lifecycle events over a socket (ISIM_CLIENT_SOCK / ISIM_CLIENT_SURFACE).
 */
#define _GNU_SOURCE
#include <SDL3/SDL.h>
#include <cairo.h>
#include <pango/pangocairo.h>
#include <pango/pangofc-fontmap.h>
#include <fontconfig/fontconfig.h>
#include <libgen.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/wait.h>

#include "runtime.h"

struct isim_device { double width, height, scale, safe_top, safe_bottom, corner_radius; int has_island; char name[48]; };
struct isim_event { int type, pad; double x, y, timestamp; int key, mods; char text[1024]; };
enum { EV_NONE, EV_TOUCH_DOWN, EV_TOUCH_MOVE, EV_TOUCH_UP, EV_QUIT, EV_KEY, EV_TEXT, EV_REDRAW, EV_ID_DOWN, EV_ID_UP, EV_DUMP, EV_TEXT_DOWN, EV_TEXT_UP,
       EV_BACKGROUND, EV_FOREGROUND, EV_SETTINGS, EV_LAUNCH_ID, EV_OPEN_URL, EV_HOME /* shell-internal */ };
/* shell <-> client protocol (SOCK_SEQPACKET, fixed-size messages) */
struct shell_msg { int type; struct isim_event ev; char a[512], b[512], c[512]; };
enum { SM_EVENT = 1, SM_FRAME, SM_LAUNCH, SM_SETTINGS, SM_HOME, SM_TERMINATE_OTHERS, SM_TERMINATE_APP, SM_ICON };
static int client_sock = -1, client_wake[2] = { -1, -1 };
static unsigned char *client_pixels;

static struct isim_device dev;
static double zoom = 1, px_scale = 1;
static int headless;
static SDL_Window *win;
static cairo_surface_t *surf;
static cairo_t *cr;
static PangoContext *pctx;
static int surf_w, surf_h;
static double t0;

/* ---------------- script ---------------- */
static char *script, *script_pos;
static double script_resume;
static struct isim_event pending[16]; static int npending;

static double now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
double isim_time(void) { return now() - t0; }

/* device presets (points, scale, safe areas, display corner radius, cutout: 0 none, 1 Dynamic Island, 2 notch) */
static const struct { const char *id; struct isim_device d; } devices[] = {
    { "iphonese",       { 375, 667, 2, 20, 0, 0, 0, "iPhone SE (3rd generation)" } },
    { "iphone13mini",   { 375, 812, 3, 50, 34, 44, 2, "iPhone 13 mini" } },
    { "iphone14",       { 390, 844, 3, 47, 34, 47, 2, "iPhone 14" } },
    { "iphone15",       { 393, 852, 3, 59, 34, 55, 1, "iPhone 15" } },
    { "iphone15plus",   { 430, 932, 3, 59, 34, 55, 1, "iPhone 15 Plus" } },
    { "iphone15promax", { 430, 932, 3, 59, 34, 55, 1, "iPhone 15 Pro Max" } },
    { "iphone16pro",    { 402, 874, 3, 62, 34, 62, 1, "iPhone 16 Pro" } },
    { "iphone16promax", { 440, 956, 3, 62, 34, 62, 1, "iPhone 16 Pro Max" } },
    { "iphone17",       { 402, 874, 3, 62, 34, 62, 1, "iPhone 17" } },
    { "iphoneair",      { 420, 912, 3, 62, 34, 62, 1, "iPhone Air" } },
    { "iphone17pro",    { 402, 874, 3, 62, 34, 62, 1, "iPhone 17 Pro" } },
    { "iphone17promax", { 440, 956, 3, 62, 34, 62, 1, "iPhone 17 Pro Max" } },
    { "ipadmini",       { 744, 1133, 2, 24, 20, 21, 0, "iPad mini (6th generation)" } },
    { "ipad",           { 820, 1180, 2, 24, 20, 18, 0, "iPad Air 11-inch" } },
    { "ipadair11",      { 820, 1180, 2, 24, 20, 18, 0, "iPad Air 11-inch" } },
    { "ipadpro11",      { 834, 1210, 2, 24, 20, 18, 0, "iPad Pro 11-inch" } },
    { "ipadpro13",      { 1032, 1376, 2, 24, 20, 18, 0, "iPad Pro 13-inch" } },
};
static void device_from_env(void) {
    const char *d = getenv("ISIM_DEVICE");
    dev = devices[3].d;                                   /* iPhone 15 */
    int found = !d;
    for (size_t i = 0; d && i < sizeof devices / sizeof *devices; i++) if (!strcmp(devices[i].id, d)) { dev = devices[i].d; found = 1; }
    if (!found) {
        fprintf(stderr, "isim: unknown device '%s'; available:", d);
        for (size_t i = 0; i < sizeof devices / sizeof *devices; i++) fprintf(stderr, " %s", devices[i].id);
        fprintf(stderr, " (using iPhone 15)\n");
    }
    const char *z = getenv("ISIM_ZOOM"); if (z) zoom = atof(z) > 0.1 ? atof(z) : 1;
}

void isim_device_metrics(struct isim_device *out) { if (!dev.width) device_from_env(); *out = dev; }

static void make_surface(void) {
    if (cr) { cairo_destroy(cr); cairo_surface_destroy(surf); }
    surf_w = (int)lround(dev.width * px_scale); surf_h = (int)lround(dev.height * px_scale);
    /* under the shell the app draws privately and publishes whole frames (no tearing while the shell reads) */
    surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, surf_w, surf_h);
    cr = cairo_create(surf);
    if (!pctx) { pctx = pango_cairo_create_context(cr); pango_cairo_context_set_resolution(pctx, 72); }
    cairo_font_options_t *fo = cairo_font_options_create();
    cairo_font_options_set_antialias(fo, CAIRO_ANTIALIAS_GRAY);
    cairo_font_options_set_hint_style(fo, CAIRO_HINT_STYLE_SLIGHT);
    cairo_font_options_set_hint_metrics(fo, CAIRO_HINT_METRICS_OFF);   /* advances independent of the pixel scale: measure == draw */
    pango_cairo_context_set_font_options(pctx, fo);
    cairo_font_options_destroy(fo);
}

int isim_display_open(const char *title) {
    if (!dev.width) device_from_env();
    t0 = now();
    if (getenv("ISIM_CLIENT_SOCK")) {              /* running under the shell: draw into its shared surface */
        client_sock = atoi(getenv("ISIM_CLIENT_SOCK"));
        px_scale = atof(getenv("ISIM_CLIENT_SCALE"));
        headless = 1;
        int w = (int)lround(dev.width * px_scale), h = (int)lround(dev.height * px_scale);
        client_pixels = mmap(NULL, (size_t)w * h * 4, PROT_READ | PROT_WRITE, MAP_SHARED, atoi(getenv("ISIM_CLIENT_SURFACE")), 0);
        if (client_pixels == MAP_FAILED) { perror("isim client: mmap surface"); exit(1); }
        if (pipe2(client_wake, O_NONBLOCK | O_CLOEXEC)) perror("isim client: pipe");
        make_surface();
        return 0;
    }
    headless = getenv("ISIM_HEADLESS") && atoi(getenv("ISIM_HEADLESS"));
    if (getenv("ISIM_SCRIPT")) { script = strdup(getenv("ISIM_SCRIPT")); script_pos = script; }
    if (!headless) {
        if (!SDL_Init(SDL_INIT_VIDEO)) { fprintf(stderr, "isim host: SDL_Init failed: %s (falling back to headless)\n", SDL_GetError()); headless = 1; }
    }
    if (!headless) {
        char t[256]; snprintf(t, sizeof t, "%s — %s (isim)", title ? title : "App", dev.name);
        win = SDL_CreateWindow(t, (int)lround(dev.width * zoom), (int)lround(dev.height * zoom), SDL_WINDOW_HIGH_PIXEL_DENSITY);
        if (!win) { fprintf(stderr, "isim host: SDL_CreateWindow failed: %s\n", SDL_GetError()); headless = 1; }
        else px_scale = SDL_GetWindowPixelDensity(win) * zoom;
        if (isim_verbose) fprintf(stderr, "isim host: video driver %s, pixel scale %.2f\n", SDL_GetCurrentVideoDriver(), px_scale);
    }
    if (headless) px_scale = getenv("ISIM_SHOT_SCALE") ? atof(getenv("ISIM_SHOT_SCALE")) : 2;
    make_surface();
    return 0;
}

/* ---------------- drawing (all coordinates in points) ---------------- */
void isim_frame_begin(void) {
    cairo_identity_matrix(cr);
    cairo_reset_clip(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgb(cr, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
    cairo_scale(cr, px_scale, px_scale);
}
void isim_gfx_save(void) { cairo_save(cr); }
void isim_gfx_restore(void) { cairo_restore(cr); }
void isim_gfx_translate(double x, double y) { cairo_translate(cr, x, y); }
void isim_gfx_scale(double sx, double sy) { cairo_scale(cr, sx, sy); }

static void rounded(double x, double y, double w, double h, double r) {
    if (r <= 0) { cairo_rectangle(cr, x, y, w, h); return; }
    r = fmin(r, fmin(w, h) / 2);
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - r, y + r, r, -M_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, M_PI / 2, M_PI);
    cairo_arc(cr, x + r, y + r, r, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);
}
void isim_gfx_clip_rounded(double x, double y, double w, double h, double r) { rounded(x, y, w, h, r); cairo_clip(cr); }
void isim_gfx_fill_rounded(double x, double y, double w, double h, double r, const double *rgba) {
    rounded(x, y, w, h, r); cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_fill(cr);
}
void isim_gfx_stroke_rounded(double x, double y, double w, double h, double r, double lw, const double *rgba) {
    rounded(x + lw / 2, y + lw / 2, w - lw, h - lw, r - lw / 2);
    cairo_set_line_width(cr, lw); cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_stroke(cr);
}
void isim_gfx_fill_ellipse(double x, double y, double w, double h, const double *rgba) {
    cairo_save(cr); cairo_translate(cr, x + w / 2, y + h / 2); cairo_scale(cr, w / 2, h / 2);
    cairo_arc(cr, 0, 0, 1, 0, 2 * M_PI); cairo_restore(cr);
    cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_fill(cr);
}
void isim_gfx_rotate(double radians) { cairo_rotate(cr, radians); }
/* multiplies the current transform by [a b c d tx ty] (CGAffineTransform layout) */
void isim_gfx_concat(double a, double b, double c, double d, double tx, double ty) {
    cairo_matrix_t m; cairo_matrix_init(&m, a, b, c, d, tx, ty); cairo_transform(cr, &m);
}
/* clips to the current path (then clears it) */
void isim_gfx_clip_path(void) { cairo_clip(cr); }
double isim_gfx_get_alpha(void) { return 1; }
void isim_gfx_push_group(void) { cairo_push_group(cr); }
void isim_gfx_pop_group(double alpha) { cairo_pop_group_to_source(cr); cairo_paint_with_alpha(cr, alpha); }

/* path API for UIBezierPath / CGContext subset */
void isim_path_begin(void) { cairo_new_path(cr); }
void isim_path_move(double x, double y) { cairo_move_to(cr, x, y); }
void isim_path_line(double x, double y) { cairo_line_to(cr, x, y); }
void isim_path_curve(double x1, double y1, double x2, double y2, double x, double y) { cairo_curve_to(cr, x1, y1, x2, y2, x, y); }
void isim_path_arc(double cx, double cy, double r, double a0, double a1, int cw) {
    if (cw) cairo_arc(cr, cx, cy, r, a0, a1); else cairo_arc_negative(cr, cx, cy, r, a0, a1);
}
void isim_path_close(void) { cairo_close_path(cr); }
void isim_path_rect(double x, double y, double w, double h, double r) { rounded(x, y, w, h, r); }
void isim_path_fill(const double *rgba) { cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_fill_preserve(cr); }
void isim_path_stroke(double lw, const double *rgba) { cairo_set_line_width(cr, lw); cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]); cairo_stroke_preserve(cr); }

/* ---------------- text ---------------- */
static int pango_weight(double w) {
    if (w < -0.6) return 100; if (w < -0.3) return 200; if (w < -0.1) return 300; if (w < 0.1) return 400;
    if (w < 0.26) return 500; if (w < 0.35) return 600; if (w < 0.5) return 700; if (w < 0.6) return 800; return 900;
}
/* fonts: system UI font, or a family registered by the app (UIAppFonts) / installed on the host.
 * A missing glyph falls back to the system fonts, like iOS's font cascade. */
#define SYSTEM_SANS "Adwaita Sans,Inter,Noto Sans,sans-serif"
#define SYSTEM_MONO "Adwaita Mono,Noto Sans Mono,monospace"
static PangoLayout *layout_for_family(const char *utf8, const char *family, double size, double weight, int mono, double maxw, int lines, int align) {
    PangoLayout *l = pango_layout_new(pctx);
    PangoFontDescription *fd = pango_font_description_new();
    char fam[512];
    if (family && *family) snprintf(fam, sizeof fam, "%s,%s", family, mono ? SYSTEM_MONO : SYSTEM_SANS);
    else snprintf(fam, sizeof fam, "%s", mono ? SYSTEM_MONO : SYSTEM_SANS);
    pango_font_description_set_family(fd, fam);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, pango_weight(weight));
    pango_layout_set_font_description(l, fd);
    pango_font_description_free(fd);
    pango_layout_set_text(l, utf8 ? utf8 : "", -1);
    if (maxw > 0) { pango_layout_set_width(l, (int)(maxw * PANGO_SCALE)); pango_layout_set_wrap(l, PANGO_WRAP_WORD_CHAR); }
    if (lines > 0 && maxw > 0) { pango_layout_set_height(l, -lines); pango_layout_set_ellipsize(l, PANGO_ELLIPSIZE_END); }
    pango_layout_set_alignment(l, align == 1 ? PANGO_ALIGN_CENTER : align == 2 ? PANGO_ALIGN_RIGHT : PANGO_ALIGN_LEFT);
    return l;
}
void isim_text_measure_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, int lines, double *w, double *h) {
    PangoLayout *l = layout_for_family(utf8, family, size, weight, mono, maxw, lines, 0);
    PangoRectangle log; pango_layout_get_extents(l, NULL, &log);
    *w = ceil((double)log.width / PANGO_SCALE); *h = ceil((double)log.height / PANGO_SCALE);
    g_object_unref(l);
}
void isim_text_end_point_f(const char *utf8, const char *family, double size, double weight, int mono, double maxw, double *x, double *y) {
    PangoLayout *l = layout_for_family(utf8, family, size, weight, mono, maxw, 0, 0);
    PangoRectangle pos; pango_layout_index_to_pos(l, (int)strlen(utf8), &pos);
    *x = pos.x / (double)PANGO_SCALE; *y = pos.y / (double)PANGO_SCALE;
    g_object_unref(l);
}
void isim_text_draw_f(const char *utf8, const char *family, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba) {
    PangoLayout *l = layout_for_family(utf8, family, size, weight, mono, w, lines, align);
    pango_cairo_update_context(cr, pctx);
    cairo_set_source_rgba(cr, rgba[0], rgba[1], rgba[2], rgba[3]);
    cairo_move_to(cr, x, y);
    pango_cairo_show_layout(cr, l);
    g_object_unref(l);
}
void isim_text_measure(const char *utf8, double size, double weight, int mono, double maxw, int lines, double *w, double *h) { isim_text_measure_f(utf8, NULL, size, weight, mono, maxw, lines, w, h); }
void isim_text_end_point(const char *utf8, double size, double weight, int mono, double maxw, double *x, double *y) { isim_text_end_point_f(utf8, NULL, size, weight, mono, maxw, x, y); }
void isim_text_draw(const char *utf8, double x, double y, double w, double size, double weight, int mono, int align, int lines, const double *rgba) { isim_text_draw_f(utf8, NULL, x, y, w, size, weight, mono, align, lines, rgba); }

/* UIFont weights (-1...1) <-> OpenType weights (100...900) */
static double uifont_weight(int ot) {
    static const struct { int ot; double w; } t[] = { {100, -0.8}, {200, -0.6}, {300, -0.4}, {400, 0}, {500, 0.23}, {600, 0.3}, {700, 0.4}, {800, 0.56}, {900, 0.62} };
    double best = 0; int bd = 10000;
    for (unsigned i = 0; i < sizeof t / sizeof *t; i++) { int d = abs(t[i].ot - ot); if (d < bd) { bd = d; best = t[i].w; } }
    return best;
}
/* Adds a font file for this process (UIAppFonts / CTFontManagerRegisterFontsForURL). */
int isim_font_register(const char *path) {
    if (!FcConfigAppFontAddFile(FcConfigGetCurrent(), (const FcChar8 *)path)) return 0;
    PangoFontMap *fm = pango_cairo_font_map_get_default();
    if (PANGO_IS_FC_FONT_MAP(fm)) pango_fc_font_map_config_changed(PANGO_FC_FONT_MAP(fm));
    return 1;
}
/* Resolves a PostScript name ("Silkscreen-Bold") or a family name ("Sora") to family + UIFont weight.
 * Returns 0 when no such font is available. */
int isim_font_lookup(const char *name, char *family, int famlen, double *weight, int *italic) {
    const char *keys[] = { FC_POSTSCRIPT_NAME, FC_FULLNAME, FC_FAMILY };
    for (int k = 0; k < 3; k++) {
        FcPattern *p = FcPatternCreate();
        FcPatternAddString(p, keys[k], (const FcChar8 *)name);
        FcObjectSet *os = FcObjectSetBuild(FC_FAMILY, FC_WEIGHT, FC_SLANT, FC_POSTSCRIPT_NAME, (char *)0);
        FcFontSet *fs = FcFontList(FcConfigGetCurrent(), p, os);
        int found = 0;
        if (fs && fs->nfont > 0) {
            /* for a family name prefer the regular style */
            FcPattern *best = fs->fonts[0];
            if (k == 2) {
                int bestd = 1 << 30;
                for (int i = 0; i < fs->nfont; i++) {
                    int w = FC_WEIGHT_REGULAR, sl = FC_SLANT_ROMAN;
                    FcPatternGetInteger(fs->fonts[i], FC_WEIGHT, 0, &w);
                    FcPatternGetInteger(fs->fonts[i], FC_SLANT, 0, &sl);
                    int d = abs(w - FC_WEIGHT_REGULAR) + (sl != FC_SLANT_ROMAN ? 1000 : 0);
                    if (d < bestd) { bestd = d; best = fs->fonts[i]; }
                }
            }
            FcChar8 *fam = NULL; int w = FC_WEIGHT_REGULAR, sl = FC_SLANT_ROMAN;
            double wr;
            FcPatternGetString(best, FC_FAMILY, 0, &fam);
            if (FcPatternGetInteger(best, FC_WEIGHT, 0, &w) != FcResultMatch && FcPatternGetDouble(best, FC_WEIGHT, 0, &wr) == FcResultMatch) w = (int)wr;
            FcPatternGetInteger(best, FC_SLANT, 0, &sl);
            if (fam) {
                snprintf(family, famlen, "%s", (const char *)fam);
                /* variable fonts list a weight range; a PostScript name like "Sora-Bold" names the instance */
                int ot = (int)FcWeightToOpenType(w);
                const char *dash = strrchr(name, '-');
                if (dash && k < 2) {
                    static const struct { const char *s; int ot; } styles[] = { {"Thin", 100}, {"ExtraLight", 200}, {"UltraLight", 200}, {"Light", 300},
                        {"Regular", 400}, {"Medium", 500}, {"SemiBold", 600}, {"Semibold", 600}, {"DemiBold", 600}, {"Bold", 700},
                        {"ExtraBold", 800}, {"UltraBold", 800}, {"Black", 900}, {"Heavy", 900} };
                    for (unsigned i = 0; i < sizeof styles / sizeof *styles; i++) if (!strncmp(dash + 1, styles[i].s, strlen(styles[i].s))) ot = styles[i].ot;
                }
                if (weight) *weight = uifont_weight(ot ? ot : 400);
                if (italic) *italic = sl != FC_SLANT_ROMAN;
                found = 1;
            }
        }
        if (fs) FcFontSetDestroy(fs);
        FcObjectSetDestroy(os);
        FcPatternDestroy(p);
        if (found) return 1;
    }
    /* families typed as "Sora Variable"/"Sora-VariableFont_wght" etc. are not guessed */
    return 0;
}
/* Whether the given family (exactly, not a fallback) has a glyph for the code point. */
int isim_font_has_char(const char *family, unsigned cp) {
    FcPattern *p = FcPatternCreate();
    FcPatternAddString(p, FC_FAMILY, (const FcChar8 *)family);
    FcObjectSet *os = FcObjectSetBuild(FC_CHARSET, (char *)0);
    FcFontSet *fs = FcFontList(FcConfigGetCurrent(), p, os);
    int has = 0;
    if (fs) {
        for (int i = 0; i < fs->nfont && !has; i++) {
            FcCharSet *cs = NULL;
            if (FcPatternGetCharSet(fs->fonts[i], FC_CHARSET, 0, &cs) == FcResultMatch && cs) has = FcCharSetHasChar(cs, cp);
        }
        FcFontSetDestroy(fs);
    }
    FcObjectSetDestroy(os);
    FcPatternDestroy(p);
    return has;
}

/* ---------------- system chrome (drawn by the "device", not the app) ---------------- */
static int status_dark_content = 1, status_hidden;
void isim_set_status_bar_style(int dark_content) { status_dark_content = dark_content; }
void isim_set_status_bar_hidden(int hidden) { status_hidden = hidden; }

static void draw_chrome(void) {
    double c = status_dark_content ? 0 : 1;
    double fg[4] = { c, c, c, 1 };
    if (status_hidden) goto hardware;
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    char clock[16]; snprintf(clock, sizeof clock, "%d:%02d", tm.tm_hour % 12 ? tm.tm_hour % 12 : 12, tm.tm_min);
    double sb = dev.safe_top >= 44 ? 54 : dev.safe_top;   /* status bar band height */
    double cy = dev.has_island ? 18 + 11 : sb / 2;          /* text baseline centre */
    double tw, th; isim_text_measure(clock, 17, 0.3, 0, 0, 1, &tw, &th);
    isim_text_draw(clock, dev.has_island ? 51 - tw / 2 + 26 : 8, cy - th / 2, 0, 17, 0.3, 0, 0, 1, fg);
    double rx = dev.width - (dev.has_island ? 34 : 10);
    /* battery */
    double bw = 25, bh = 12, bx = rx - bw, by = cy - bh / 2;
    double dim[4] = { c, c, c, 0.4 };
    isim_gfx_stroke_rounded(bx, by, bw, bh, 3.5, 1, dim);
    isim_gfx_fill_rounded(bx + 2, by + 2, (bw - 4) * 0.8, bh - 4, 2, fg);
    isim_gfx_fill_rounded(bx + bw + 1, by + 4, 1.5, 4, 0.75, dim);
    /* wifi (three arcs) */
    double wx = bx - 16, wy = cy + 4.5;
    cairo_set_source_rgba(cr, c, c, c, 1);
    for (int i = 0; i < 3; i++) {
        cairo_new_path(cr);
        cairo_arc(cr, wx, wy, 3 + i * 3.6, -M_PI * 0.75, -M_PI * 0.25);
        cairo_set_line_width(cr, 2.0); cairo_stroke(cr);
    }
    /* cellular bars */
    double cx0 = wx - 30;
    for (int i = 0; i < 4; i++) isim_gfx_fill_rounded(cx0 + i * 4.5, cy + 5 - (4 + i * 2.6), 3, 4 + i * 2.6, 1, fg);
hardware:                                                          /* island, notch and home indicator stay */
    if (dev.has_island == 1) { double k[4] = { 0, 0, 0, 1 }; isim_gfx_fill_rounded(dev.width / 2 - 62.5, 11, 125, 37, 18.5, k); }
    if (dev.has_island == 2) {                                     /* notch: flat top, rounded bottom corners */
        double k[4] = { 0, 0, 0, 1 };
        isim_gfx_fill_rounded(dev.width / 2 - 81, -20, 162, 52, 20, k);
    }
    if (dev.safe_bottom > 0) isim_gfx_fill_rounded(dev.width / 2 - 67, dev.height - 8 - 5, 134, 5, 2.5, fg);
}

static void apply_corner_mask(void) {
    if (dev.corner_radius <= 0) return;
    cairo_save(cr);
    cairo_rectangle(cr, 0, 0, dev.width, dev.height);
    rounded(0, 0, dev.width, dev.height, dev.corner_radius);
    cairo_set_fill_rule(cr, CAIRO_FILL_RULE_EVEN_ODD);
    cairo_set_source_rgb(cr, 0.09, 0.09, 0.1);
    cairo_fill(cr);
    cairo_restore(cr);
}

void isim_frame_end(void) {
    cairo_identity_matrix(cr); cairo_reset_clip(cr); cairo_scale(cr, px_scale, px_scale);
    draw_chrome();
    apply_corner_mask();
    cairo_surface_flush(surf);
    if (client_sock >= 0) {
        memcpy(client_pixels, cairo_image_surface_get_data(surf), (size_t)surf_w * surf_h * 4);
        struct shell_msg m = { .type = SM_FRAME }; send(client_sock, &m, sizeof m, MSG_NOSIGNAL); return;
    }
    if (headless || !win) return;
    SDL_Surface *ws = SDL_GetWindowSurface(win);
    if (!ws) return;
    SDL_Surface *src = SDL_CreateSurfaceFrom(surf_w, surf_h, SDL_PIXELFORMAT_ARGB8888,
                                             cairo_image_surface_get_data(surf), cairo_image_surface_get_stride(surf));
    if (ws->w == surf_w && ws->h == surf_h) SDL_BlitSurface(src, NULL, ws, NULL);
    else SDL_BlitSurfaceScaled(src, NULL, ws, NULL, SDL_SCALEMODE_LINEAR);
    SDL_DestroySurface(src);
    SDL_UpdateWindowSurface(win);
}

static void screenshot(const char *path) {
    cairo_surface_flush(surf);
    cairo_status_t st = cairo_surface_write_to_png(surf, path);
    fprintf(stderr, "isim host: screenshot %s (%dx%d px): %s\n", path, surf_w, surf_h, cairo_status_to_string(st));
}

/* ---------------- events ---------------- */
static char held_id[64]; static double held_until;
/* live control: ISIM_CONTROL names a FIFO; lines written to it are appended to the script while isim runs */
static int ctl_fd = -2;
static size_t script_len;
static void control_poll(void) {
    if (ctl_fd == -2) {
        const char *p = getenv("ISIM_CONTROL");
        ctl_fd = p && *p ? open(p, O_RDWR | O_NONBLOCK) : -1;     /* O_RDWR: no EOF when writers come and go */
        script_len = script ? strlen(script) : 0;                  /* (first call: nothing consumed yet) */
        if (p && *p && ctl_fd < 0) fprintf(stderr, "isim: cannot open control FIFO %s\n", p);
    }
    if (ctl_fd < 0) return;
    char buf[4096]; ssize_t n;
    while ((n = read(ctl_fd, buf, sizeof buf)) > 0) {
        size_t off = script_pos ? (size_t)(script_pos - script) : script_len;
        script = realloc(script, script_len + n + 2);
        memcpy(script + script_len, buf, n); script_len += n;
        script[script_len] = ';'; script[script_len + 1] = 0;  /* a line always ends a command */
        script_len++;
        script_pos = script + off;
    }
}
/* "drag x1 y1 x2 y2 seconds": a timed drag, one move per ~16 ms */
static struct { int on; double a, b, c, d, t0, dur, last; } sdrag;
static int script_step(struct isim_event *ev) {
    control_poll();
    if (sdrag.on && !npending) {
        double t = now();
        if (t - sdrag.last >= 0.016) {
            double p = fmin(1, (t - sdrag.t0) / sdrag.dur);
            sdrag.last = t;
            pending[npending++] = (struct isim_event){ .type = EV_TOUCH_MOVE, .x = sdrag.a + (sdrag.c - sdrag.a) * p, .y = sdrag.b + (sdrag.d - sdrag.b) * p };
            if (p >= 1) { pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = sdrag.c, .y = sdrag.d }; sdrag.on = 0; }
        }
        if (npending) { *ev = pending[0]; memmove(pending, pending + 1, --npending * sizeof *pending); ev->timestamp = isim_time(); return 1; }
        return 0;
    }
    if (held_until && now() >= held_until) {
        held_until = 0; pending[npending++] = (struct isim_event){ .type = EV_ID_UP };
        snprintf(pending[npending - 1].text, sizeof pending->text, "%s", held_id);
    }
    if (npending) { *ev = pending[0]; memmove(pending, pending + 1, --npending * sizeof *pending); ev->timestamp = isim_time(); return 1; }
    if (!script_pos) return 0;
    if (now() < script_resume) return 0;
    while (*script_pos == ' ' || *script_pos == ';' || *script_pos == '\n' || *script_pos == '\r') script_pos++;
    if (!*script_pos) { if (ctl_fd < 0) script_pos = NULL; return 0; }
    char cmd[16] = {0}, arg[512] = {0}; double a, b, c, d; int n = 0;
    sscanf(script_pos, "%15[^;\n ]%n", cmd, &n);
    char *args = script_pos + n;
    char *end = strpbrk(script_pos, ";\n");
    if (end) *end = 0;                      /* arguments end at the separator */
    script_pos = end ? end + 1 : script_pos + strlen(script_pos);
    if (!strcmp(cmd, "wait") && sscanf(args, "%lf", &a) == 1) script_resume = now() + a;
    else if (!strcmp(cmd, "tap") && sscanf(args, "%lf %lf", &a, &b) == 2) {
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = a, .y = b };
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = a, .y = b };
        script_resume = now() + 0.05;
    } else if (!strcmp(cmd, "drag") && sscanf(args, "%lf %lf %lf %lf %lf", &a, &b, &c, &d, &sdrag.dur) == 5 && sdrag.dur > 0) {
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = a, .y = b };
        sdrag.on = 1; sdrag.a = a; sdrag.b = b; sdrag.c = c; sdrag.d = d; sdrag.t0 = sdrag.last = now();
        script_resume = now() + sdrag.dur + 0.02;
    } else if (!strcmp(cmd, "drag") && sscanf(args, "%lf %lf %lf %lf", &a, &b, &c, &d) == 4) {
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = a, .y = b };
        for (int i = 1; i <= 5; i++) pending[npending++] = (struct isim_event){ .type = EV_TOUCH_MOVE, .x = a + (c - a) * i / 5, .y = b + (d - b) * i / 5 };
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = c, .y = d };
    } else if (!strcmp(cmd, "tapid") && sscanf(args, " %63[^; ]", arg) == 1) {
        pending[npending++] = (struct isim_event){ .type = EV_ID_DOWN }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        pending[npending++] = (struct isim_event){ .type = EV_ID_UP }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        script_resume = now() + 0.05;
    } else if (!strcmp(cmd, "holdid") && sscanf(args, " %63[^; ] %lf", arg, &a) == 2) {
        pending[npending++] = (struct isim_event){ .type = EV_ID_DOWN }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        snprintf(held_id, sizeof held_id, "%s", arg); held_until = now() + a; script_resume = held_until + 0.05;
    } else if (!strcmp(cmd, "type") && sscanf(args, " %511[^;]", arg) == 1) {
        for (char *t = arg; *t && npending < 8; t += strlen(pending[npending - 1].text)) {
            pending[npending++] = (struct isim_event){ .type = EV_TEXT };
            snprintf(pending[npending - 1].text, 32, "%s", t);       /* 31-byte chunks (ASCII-safe) */
        }
        script_resume = now() + 0.05;
    } else if (!strcmp(cmd, "key") && sscanf(args, " %63[^; ]", arg) == 1) {
        int k = !strcmp(arg, "backspace") ? 8 : !strcmp(arg, "return") ? 13 : !strcmp(arg, "tab") ? 9 : !strcmp(arg, "escape") ? 27 : 0;
        if (k) pending[npending++] = (struct isim_event){ .type = EV_KEY, .key = k };
        else fprintf(stderr, "isim host: unknown key '%s'\n", arg);
    } else if (!strcmp(cmd, "shot") && sscanf(args, " %511[^;]", arg) == 1) {
        for (char *e = arg + strlen(arg) - 1; e >= arg && *e == ' '; e--) *e = 0;
        screenshot(arg);
    } else if (!strcmp(cmd, "taptext") && sscanf(args, " %63[^;]", arg) == 1) {
        for (char *e = arg + strlen(arg) - 1; e >= arg && *e == ' '; e--) *e = 0;
        pending[npending++] = (struct isim_event){ .type = EV_TEXT_DOWN }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        pending[npending++] = (struct isim_event){ .type = EV_TEXT_UP }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        script_resume = now() + 0.05;
    } else if (!strcmp(cmd, "home")) { pending[npending++] = (struct isim_event){ .type = EV_HOME }; script_resume = now() + 0.3; }
    else if (!strcmp(cmd, "launch") && sscanf(args, " %63[^; ]", arg) == 1) {
        pending[npending++] = (struct isim_event){ .type = EV_LAUNCH_ID }; snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        script_resume = now() + 0.5;
    } else if (!strcmp(cmd, "dump")) { pending[npending++] = (struct isim_event){ .type = EV_DUMP }; }
    else if (!strcmp(cmd, "quit")) { pending[npending++] = (struct isim_event){ .type = EV_QUIT }; }
    else fprintf(stderr, "isim host: bad script command near '%s'\n", cmd);
    return script_step(ev);
}

static int button_down;
static volatile int wakeup_pending;
/* thread-safe: makes a pending isim_next_event return early (no event) so the app loop runs */
/* opens a URL on the host desktop when ISIM_OPEN_URLS=1 (xdg-open); returns 1 if launched */
int isim_open_url(const char *url) {
    const char *e = getenv("ISIM_OPEN_URLS");
    if (!e || strcmp(e, "1") || !url) return 0;
    pid_t pid = fork();
    if (pid == 0) { execlp("xdg-open", "xdg-open", url, (char *)NULL); _exit(127); }
    return pid > 0;
}
void isim_post_wakeup(void) {
    if (client_sock >= 0) { if (write(client_wake[1], "w", 1) < 0) {} return; }
    if (win) { SDL_Event e; SDL_zero(e); e.type = SDL_EVENT_USER; SDL_PushEvent(&e); }
    else __atomic_store_n(&wakeup_pending, 1, __ATOMIC_RELEASE);
}
int isim_next_event(struct isim_event *ev, double timeout) {
    memset(ev, 0, sizeof *ev);
    double deadline = now() + timeout;
    if (client_sock >= 0) {
        struct pollfd p[2] = { { client_sock, POLLIN, 0 }, { client_wake[0], POLLIN, 0 } };
        int r = poll(p, 2, timeout <= 0 ? 0 : (int)(timeout * 1000) + 1);
        if (r <= 0) return 0;
        if (p[1].revents) { char buf[64]; while (read(client_wake[0], buf, sizeof buf) > 0) {} if (!p[0].revents) return 0; }
        struct shell_msg m;
        ssize_t n = recv(client_sock, &m, sizeof m, 0);
        if (n <= 0) { ev->type = EV_QUIT; return 1; }        /* the shell went away */
        *ev = m.ev; ev->timestamp = isim_time();
        return 1;
    }
    for (;;) {
        if (script_step(ev)) return 1;
        if (headless || !win) {
            double left = deadline - now();
            if (left <= 0) return 0;
            double step = script_pos && script_resume > now() ? fmin(left, script_resume - now()) : fmin(left, 0.01);
            if (__atomic_exchange_n(&wakeup_pending, 0, __ATOMIC_ACQ_REL)) return 0;
            if (step > 0.002) step = 0.002;           /* poll the wakeup flag */
            struct timespec ts = { 0, (long)(fmax(step, 0.0005) * 1e9) }; nanosleep(&ts, NULL);
            if (!script_pos && !npending && ctl_fd < 0 && now() >= deadline) return 0;
            continue;
        }
        SDL_Event e;
        double left = deadline - now();
        int wait_ms = left <= 0 ? 0 : (int)(left * 1000);
        if ((script_pos || ctl_fd >= 0) && wait_ms > 10) wait_ms = 10;
        if (!SDL_WaitEventTimeout(&e, wait_ms)) { if (now() >= deadline) return 0; continue; }
        ev->timestamp = isim_time();
        switch (e.type) {
        case SDL_EVENT_USER: return 0;
        case SDL_EVENT_QUIT: case SDL_EVENT_WINDOW_CLOSE_REQUESTED: ev->type = EV_QUIT; return 1;
        case SDL_EVENT_MOUSE_BUTTON_DOWN:
            if (e.button.button != SDL_BUTTON_LEFT) break;
            button_down = 1; ev->type = EV_TOUCH_DOWN; ev->x = e.button.x / zoom; ev->y = e.button.y / zoom; return 1;
        case SDL_EVENT_MOUSE_MOTION:
            if (!button_down) break;
            ev->type = EV_TOUCH_MOVE; ev->x = e.motion.x / zoom; ev->y = e.motion.y / zoom; return 1;
        case SDL_EVENT_MOUSE_BUTTON_UP:
            if (e.button.button != SDL_BUTTON_LEFT || !button_down) break;
            button_down = 0; ev->type = EV_TOUCH_UP; ev->x = e.button.x / zoom; ev->y = e.button.y / zoom; return 1;
        case SDL_EVENT_KEY_DOWN:
            if (e.key.key == SDLK_F12) { screenshot("isim-screenshot.png"); break; }
            ev->type = EV_KEY; ev->key = (int)e.key.key; ev->mods = e.key.mod; return 1;
        case SDL_EVENT_TEXT_INPUT:
            ev->type = EV_TEXT; snprintf(ev->text, sizeof ev->text, "%s", e.text.text); return 1;
        case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED: case SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED: case SDL_EVENT_WINDOW_EXPOSED:
            if (e.type != SDL_EVENT_WINDOW_EXPOSED) { px_scale = SDL_GetWindowPixelDensity(win) * zoom; make_surface(); }
            ev->type = EV_REDRAW; return 1;
        default: break;
        }
    }
}

void isim_text_input(int on) { if (win) { if (on) SDL_StartTextInput(win); else SDL_StopTextInput(win); } }

/* main bundle path = directory of the main executable */
const char *isim_bundle_path(void) {
    static char *p;
    if (!p) { char *e = strdup(isim_main_executable_path()); p = strdup(dirname(e)); free(e); }
    return p;
}

cairo_t *isim_host_cairo(void) { return cr; }

int isim_image_load(const char *path, double *w, double *h);
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h);
int isim_image_symbol(const char *name, double *w, double *h);
void isim_image_draw(int hd, double x, double y, double w, double h, const double *tint, double alpha);
int isim_image_is_template(int hd);
void isim_image_free(int hd);
void isim_image_draw_part(int hd, double sx, double sy, double sw, double sh, double x, double y, double w, double h, int nearest, const double *blend, double factor, double alpha);
void isim_image_pixel_size(int hd, double *w, double *h);
int isim_audio_available(void);
int isim_audio_buffer_create(const float *pcm, long frames, int channels, double rate);
void isim_audio_buffer_release(int b);
long isim_audio_play(int b, double volume, int loops);
void isim_audio_stop(long h);
void isim_audio_pause(long h, int paused);
void isim_audio_set_volume(long h, double volume);
int isim_audio_is_playing(long h);
double isim_audio_position(long h);
void isim_audio_seek(long h, double seconds);
void isim_audio_suspend(int s);

/* ---------------- client side of the shell protocol (guest API) ---------------- */
int isim_shell_present(void) { return getenv("ISIM_CLIENT_SOCK") != NULL; }
/* type: 3 launch (a = bundle path, b = executable, c = URL to open), 4 settings changed, 5 go home, 6 terminate other apps */
void isim_shell_request(int type, const char *a, const char *b, const char *c) {
    if (client_sock < 0) return;
    struct shell_msg m = { .type = type };
    snprintf(m.a, sizeof m.a, "%s", a ? a : ""); snprintf(m.b, sizeof m.b, "%s", b ? b : ""); snprintf(m.c, sizeof m.c, "%s", c ? c : "");
    send(client_sock, &m, sizeof m, MSG_NOSIGNAL);
}

#include "shell.inc"

#define H(n) { "_" #n, (void *)n, "isim" }
static const struct shim isim_table[] = {
    H(isim_device_metrics), H(isim_display_open), H(isim_frame_begin), H(isim_frame_end), H(isim_time),
    H(isim_gfx_save), H(isim_gfx_restore), H(isim_gfx_translate), H(isim_gfx_scale), H(isim_gfx_clip_rounded),
    H(isim_gfx_fill_rounded), H(isim_gfx_stroke_rounded), H(isim_gfx_fill_ellipse), H(isim_gfx_push_group), H(isim_gfx_pop_group),
    H(isim_path_begin), H(isim_path_move), H(isim_path_line), H(isim_path_curve), H(isim_path_arc), H(isim_path_close),
    H(isim_path_rect), H(isim_path_fill), H(isim_path_stroke),
    H(isim_text_measure), H(isim_text_end_point), H(isim_text_draw), H(isim_text_measure_f), H(isim_text_end_point_f), H(isim_text_draw_f),
    H(isim_font_register), H(isim_font_lookup), H(isim_font_has_char), H(isim_set_status_bar_style), H(isim_set_status_bar_hidden), H(isim_next_event), H(isim_text_input),
    H(isim_bundle_path), H(isim_post_wakeup), H(isim_open_url), H(isim_shell_present), H(isim_shell_request),
    H(isim_image_load), H(isim_image_load_data), H(isim_image_symbol), H(isim_image_draw), H(isim_image_is_template), H(isim_image_free), H(isim_image_draw_part), H(isim_image_pixel_size),
    H(isim_gfx_rotate), H(isim_gfx_concat), H(isim_gfx_clip_path), H(isim_gfx_get_alpha),
    H(isim_audio_available), H(isim_audio_buffer_create), H(isim_audio_buffer_release), H(isim_audio_play), H(isim_audio_stop),
    H(isim_audio_pause), H(isim_audio_set_volume), H(isim_audio_is_playing), H(isim_audio_position), H(isim_audio_seek), H(isim_audio_suspend),
};
const struct host_lib host_isim = { "/usr/lib/libisim_host.dylib", isim_table, sizeof isim_table / sizeof *isim_table };
