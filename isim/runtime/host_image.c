/*
 * libisim_host images: decoding (gdk-pixbuf for raster, librsvg for SVG) and drawing
 * into the current cairo context, optionally as a template tinted with one color.
 *
 * SF Symbols are Apple's proprietary artwork and are not shipped. isim_image_symbol()
 * substitutes: a few common shapes are drawn procedurally (N.circle, checkmark.circle,
 * circle.grid.3x3), others map to the system's Adwaita symbolic icons. Unknown names
 * draw a visible placeholder and are reported once on stderr. Substitutes look different
 * from the real symbols; layout uses SF-like metrics so sizes match.
 */
#define _GNU_SOURCE
#include <cairo.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <librsvg/rsvg.h>
#include <math.h>
#include <pango/pangocairo.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

cairo_t *isim_host_cairo(void);

enum { IMG_RASTER = 1, IMG_SVG, IMG_PROC };
enum { PROC_NUM_CIRCLE = 1, PROC_CHECK_CIRCLE, PROC_GRID, PROC_PLACEHOLDER, PROC_KB_DOWN, PROC_GLOBE, PROC_CIRCLE, PROC_MINUS_CIRCLE };
struct img { int kind; cairo_surface_t *surf; RsvgHandle *svg; double w, h; int proc, fill; char text[8]; };
static struct img *imgs; static int nimgs, capimgs;

static int new_img(struct img v) {
    for (int i = 0; i < nimgs; i++) if (!imgs[i].kind) { imgs[i] = v; return i + 1; }
    if (nimgs == capimgs) { capimgs = capimgs ? capimgs * 2 : 32; imgs = realloc(imgs, capimgs * sizeof *imgs); }
    imgs[nimgs++] = v; return nimgs;
}
static struct img *get(int h) { return h > 0 && h <= nimgs && imgs[h - 1].kind ? &imgs[h - 1] : NULL; }

static cairo_surface_t *surface_from_pixbuf(GdkPixbuf *pb) {
    int w = gdk_pixbuf_get_width(pb), h = gdk_pixbuf_get_height(pb), nc = gdk_pixbuf_get_n_channels(pb);
    int rs = gdk_pixbuf_get_rowstride(pb); const guchar *src = gdk_pixbuf_get_pixels(pb);
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    unsigned char *dst = cairo_image_surface_get_data(s); int ds = cairo_image_surface_get_stride(s);
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        const guchar *p = src + y * rs + x * nc; unsigned a = nc == 4 ? p[3] : 255;
        uint32_t px = a << 24 | (p[0] * a / 255) << 16 | (p[1] * a / 255) << 8 | (p[2] * a / 255);
        memcpy(dst + y * ds + x * 4, &px, 4);
    }
    cairo_surface_mark_dirty(s);
    return s;
}

static int load_svg(RsvgHandle *svg, double *w, double *h) {
    gdouble sw = 16, sh = 16;
    if (!rsvg_handle_get_intrinsic_size_in_pixels(svg, &sw, &sh)) { sw = 16; sh = 16; }
    struct img v = { IMG_SVG, NULL, svg, sw, sh };
    *w = sw; *h = sh;
    return new_img(v);
}

/* Returns a handle (>0) or 0. Size is in pixels of the source (the caller applies @2x/@3x). */
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h) {
    if (len > 5 && (!memcmp(data, "<?xml", 5) || !memcmp(data, "<svg", 4))) {
        RsvgHandle *svg = rsvg_handle_new_from_data(data, len, NULL);
        return svg ? load_svg(svg, w, h) : 0;
    }
    GdkPixbufLoader *l = gdk_pixbuf_loader_new();
    int ok = gdk_pixbuf_loader_write(l, data, len, NULL);
    ok = gdk_pixbuf_loader_close(l, NULL) && ok;
    GdkPixbuf *pb = ok ? gdk_pixbuf_loader_get_pixbuf(l) : NULL;
    int handle = 0;
    if (pb) {
        struct img v = { IMG_RASTER, surface_from_pixbuf(pb), NULL, gdk_pixbuf_get_width(pb), gdk_pixbuf_get_height(pb) };
        *w = v.w; *h = v.h; handle = new_img(v);
    }
    g_object_unref(l);
    return handle;
}

int isim_image_load(const char *path, double *w, double *h) {
    gchar *data; gsize len;
    if (!g_file_get_contents(path, &data, &len, NULL)) return 0;
    int r = isim_image_load_data(data, len, w, h);
    g_free(data);
    return r;
}

static const struct { const char *sf, *adw; } symbol_map[] = {
    { "delete.left", "actions/edit-clear-symbolic" }, { "delete.backward", "actions/edit-clear-symbolic" },
    { "network", "legacy/web-browser-symbolic" },
    { "clock", "legacy/preferences-system-time-symbolic" }, { "sun.max", "status/weather-clear-symbolic" },
    { "textformat.size", "legacy/preferences-desktop-font-symbolic" }, { "textformat", "legacy/preferences-desktop-font-symbolic" },
    { "accessibility", "legacy/preferences-desktop-accessibility-symbolic" }, { "character.bubble", "legacy/preferences-desktop-locale-symbolic" },
    { "square.grid.2x2", "legacy/preferences-desktop-apps-symbolic" }, { "iphone", "devices/phone-symbolic" }, { "info.circle", "status/dialog-information-symbolic" },
    { "keyboard", "devices/input-keyboard-symbolic" },
    { "gear", "legacy/emblem-system-symbolic" }, { "gearshape", "legacy/emblem-system-symbolic" },
    { "lock.shield", "status/channel-secure-symbolic" }, { "lock", "status/system-lock-screen-symbolic" },
    { "xmark", "ui/window-close-symbolic" }, { "plus", "actions/list-add-symbolic" }, { "minus", "actions/list-remove-symbolic" },
    { "magnifyingglass", "actions/edit-find-symbolic" }, { "trash", "places/user-trash-symbolic" },
    { "star", "status/non-starred-symbolic" }, { "star.fill", "status/starred-symbolic" },
    { "info.circle", "status/dialog-information-symbolic" }, { "exclamationmark.triangle", "status/dialog-warning-symbolic" },
    { "chevron.right", "actions/go-next-symbolic" }, { "chevron.left", "actions/go-previous-symbolic" },
    { "chevron.down", "actions/go-down-symbolic" }, { "chevron.up", "actions/go-up-symbolic" },
    { "house", "places/user-home-symbolic" }, { "person", "status/avatar-default-symbolic" },
    { "person.crop.circle", "status/avatar-default-symbolic" }, { "doc.on.doc", "actions/edit-copy-symbolic" },
    { "pencil", "actions/document-edit-symbolic" }, { "square.and.pencil", "actions/document-edit-symbolic" },
    { "bell", "legacy/preferences-system-notifications-symbolic" }, { "envelope", "status/mail-unread-symbolic" },
    { "camera", "devices/camera-photo-symbolic" }, { "photo", "mimetypes/image-x-generic-symbolic" },
    { "play", "actions/media-playback-start-symbolic" }, { "pause", "actions/media-playback-pause-symbolic" },
    { "folder", "places/folder-symbolic" }, { "arrow.clockwise", "actions/view-refresh-symbolic" },
    { "square.and.arrow.up", "actions/send-to-symbolic" }, { "checkmark", "actions/object-select-symbolic" },
};

static int proc_symbol(int proc, int fill, const char *text, double *w, double *h) {
    struct img v = { IMG_PROC, NULL, NULL, 1.2, 1.2, proc, fill };
    if (proc == PROC_KB_DOWN) { v.w = 1.45; v.h = 1.2; }
    snprintf(v.text, sizeof v.text, "%s", text ? text : "");
    *w = v.w; *h = v.h;
    return new_img(v);
}

/* SF Symbol substitute. Size is relative to a 1pt font (multiply by the point size). */
int isim_image_symbol(const char *name, double *w, double *h) {
    char base[128]; snprintf(base, sizeof base, "%s", name);
    int fill = 0; size_t n = strlen(base);
    if (n > 5 && !strcmp(base + n - 5, ".fill")) { fill = 1; base[n - 5] = 0; n -= 5; }
    if (n > 7 && !strcmp(base + n - 7, ".circle") && n - 7 <= 2) {               /* "1.circle" ... "50.circle" */
        char num[4] = {0}; memcpy(num, base, n - 7);
        if (strspn(num, "0123456789") == strlen(num)) return proc_symbol(PROC_NUM_CIRCLE, fill, num, w, h);
    }
    if (!strcmp(base, "checkmark.circle")) return proc_symbol(PROC_CHECK_CIRCLE, fill, NULL, w, h);
    if (!strcmp(base, "circle")) return proc_symbol(PROC_CIRCLE, fill, NULL, w, h);
    if (!strcmp(base, "minus.circle")) return proc_symbol(PROC_MINUS_CIRCLE, fill, NULL, w, h);
    if (!strncmp(base, "circle.grid.3x3", 15)) return proc_symbol(PROC_GRID, 1, NULL, w, h);
    if (!strcmp(base, "globe")) return proc_symbol(PROC_GLOBE, 0, NULL, w, h);
    if (!strcmp(base, "keyboard.chevron.compact.down")) return proc_symbol(PROC_KB_DOWN, 0, NULL, w, h);
    for (int pass = 0; pass < 2; pass++)
        for (size_t i = 0; i < sizeof symbol_map / sizeof *symbol_map; i++)
            if (!strcmp(symbol_map[i].sf, pass ? base : name)) {
                char path[256]; snprintf(path, sizeof path, "/usr/share/icons/Adwaita/symbolic/%s.svg", symbol_map[i].adw);
                double sw, sh; int hd = isim_image_load(path, &sw, &sh);
                if (hd) { struct img *im = get(hd); im->w = 1.2; im->h = 1.2 * sh / sw; *w = im->w; *h = im->h; return hd; }
            }
    static char reported[64][64]; static int nrep;
    int seen = 0; for (int i = 0; i < nrep; i++) if (!strcmp(reported[i], name)) seen = 1;
    if (!seen) { fprintf(stderr, "isim: SF Symbol '%s' has no substitute; drawing a placeholder\n", name); if (nrep < 64) snprintf(reported[nrep++], 64, "%s", name); }
    return proc_symbol(PROC_PLACEHOLDER, 0, NULL, w, h);
}

static void draw_proc(cairo_t *c, struct img *im, double w, double h) {
    double s = fmin(w, h), cx = w / 2, cy = h / 2, r = s / 2 - s * 0.06, lw = s * 0.085;
    cairo_set_line_width(c, lw); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_set_line_join(c, CAIRO_LINE_JOIN_ROUND);
    switch (im->proc) {
    case PROC_NUM_CIRCLE: case PROC_CHECK_CIRCLE:
        cairo_new_sub_path(c); cairo_arc(c, cx, cy, r, 0, 2 * M_PI);
        if (im->fill) cairo_fill(c); else cairo_stroke(c);
        if (im->fill) cairo_set_operator(c, CAIRO_OPERATOR_CLEAR);
        if (im->proc == PROC_CHECK_CIRCLE) {
            cairo_move_to(c, cx - r * 0.45, cy + r * 0.02); cairo_line_to(c, cx - r * 0.1, cy + r * 0.38); cairo_line_to(c, cx + r * 0.48, cy - r * 0.38);
            cairo_stroke(c);
        } else {
            PangoLayout *l = pango_cairo_create_layout(c);
            PangoFontDescription *fd = pango_font_description_from_string("Adwaita Sans Semi-Bold");
            pango_font_description_set_absolute_size(fd, r * 1.15 * PANGO_SCALE);
            pango_layout_set_font_description(l, fd); pango_layout_set_text(l, im->text, -1);
            int tw, th; pango_layout_get_pixel_size(l, &tw, &th);
            PangoRectangle ink, logical; pango_layout_get_pixel_extents(l, &ink, &logical);
            cairo_move_to(c, cx - (ink.x + ink.width / 2.0), cy - (ink.y + ink.height / 2.0));
            pango_cairo_show_layout(c, l);
            pango_font_description_free(fd); g_object_unref(l);
        }
        cairo_set_operator(c, CAIRO_OPERATOR_OVER);
        break;
    case PROC_GRID:
        for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) {
            cairo_new_sub_path(c); cairo_arc(c, cx + (i - 1) * s * 0.34, cy + (j - 1) * s * 0.34, s * 0.13, 0, 2 * M_PI);
        }
        cairo_fill(c);
        break;
    case PROC_KB_DOWN: {
        double kw = w * 0.9, kh = h * 0.52, kx = (w - kw) / 2, ky = h * 0.04, rr = kh * 0.18;
        cairo_set_line_width(c, lw * 0.8);
        cairo_new_sub_path(c);
        cairo_arc(c, kx + kw - rr, ky + rr, rr, -M_PI / 2, 0); cairo_arc(c, kx + kw - rr, ky + kh - rr, rr, 0, M_PI / 2);
        cairo_arc(c, kx + rr, ky + kh - rr, rr, M_PI / 2, M_PI); cairo_arc(c, kx + rr, ky + rr, rr, M_PI, 3 * M_PI / 2); cairo_close_path(c);
        cairo_stroke(c);
        for (int row = 0; row < 2; row++) for (int k = 0; k < 5; k++)
            cairo_rectangle(c, kx + kw * (0.14 + k * 0.165) - lw * 0.4, ky + kh * (0.3 + row * 0.28) - lw * 0.4, lw * 0.8, lw * 0.8);
        cairo_fill(c);
        cairo_move_to(c, w / 2 - w * 0.12, h * 0.72); cairo_line_to(c, w / 2, h * 0.84); cairo_line_to(c, w / 2 + w * 0.12, h * 0.72);
        cairo_stroke(c);
        break; }
    case PROC_MINUS_CIRCLE:
        cairo_new_sub_path(c); cairo_arc(c, cx, cy, r, 0, 2 * M_PI);
        if (im->fill) { cairo_fill(c); cairo_set_operator(c, CAIRO_OPERATOR_CLEAR); } else cairo_stroke(c);
        cairo_move_to(c, cx - r * 0.5, cy); cairo_line_to(c, cx + r * 0.5, cy); cairo_stroke(c);
        cairo_set_operator(c, CAIRO_OPERATOR_OVER);
        break;
    case PROC_CIRCLE:
        cairo_new_sub_path(c); cairo_arc(c, cx, cy, r, 0, 2 * M_PI);
        if (im->fill) cairo_fill(c); else cairo_stroke(c);
        break;
    case PROC_GLOBE:
        cairo_set_line_width(c, lw * 0.85);
        cairo_new_sub_path(c); cairo_arc(c, cx, cy, r, 0, 2 * M_PI); cairo_stroke(c);
        cairo_save(c); cairo_translate(c, cx, cy); cairo_scale(c, 0.45, 1);
        cairo_new_sub_path(c); cairo_arc(c, 0, 0, r, 0, 2 * M_PI); cairo_restore(c); cairo_stroke(c);
        cairo_move_to(c, cx, cy - r); cairo_line_to(c, cx, cy + r);
        cairo_move_to(c, cx - r, cy); cairo_line_to(c, cx + r, cy);
        { double yy = r * 0.5, xx = sqrt(r * r - yy * yy);
          cairo_move_to(c, cx - xx, cy - yy); cairo_line_to(c, cx + xx, cy - yy);
          cairo_move_to(c, cx - xx, cy + yy); cairo_line_to(c, cx + xx, cy + yy); }
        cairo_stroke(c);
        break;
    default:   /* placeholder: dashed rounded square */
        cairo_set_line_width(c, lw * 0.7);
        { double d[] = { lw, lw }; cairo_set_dash(c, d, 2, 0); }
        cairo_rectangle(c, s * 0.12, s * 0.12, w - s * 0.24, h - s * 0.24); cairo_stroke(c);
        cairo_set_dash(c, NULL, 0, 0);
    }
}

/* Draws image `h` into (x, y, w, h) in current user space. tint (rgba) != NULL renders it as a template. */
void isim_image_draw(int hd, double x, double y, double w, double h, const double *tint, double alpha) {
    struct img *im = get(hd); cairo_t *c = isim_host_cairo();
    if (!im || !c || w <= 0 || h <= 0) return;
    cairo_save(c);
    cairo_translate(c, x, y);
    cairo_push_group(c);
    if (im->kind == IMG_PROC) {
        cairo_set_source_rgba(c, 0, 0, 0, 1);
        draw_proc(c, im, w, h);
    } else if (im->kind == IMG_SVG) {
        RsvgRectangle vp = { 0, 0, w, h };
        rsvg_handle_render_document(im->svg, c, &vp, NULL);
    } else {
        cairo_scale(c, w / im->w, h / im->h);
        cairo_set_source_surface(c, im->surf, 0, 0);
        cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD);
        cairo_paint(c);
    }
    cairo_pattern_t *pat = cairo_pop_group(c);
    if (tint) { cairo_set_source_rgba(c, tint[0], tint[1], tint[2], tint[3] * alpha); cairo_mask(c, pat); }
    else { cairo_set_source(c, pat); cairo_paint_with_alpha(c, alpha); }
    cairo_pattern_destroy(pat);
    cairo_restore(c);
}

/* Is the image a symbol/template by nature (single-color art)? */
int isim_image_is_template(int hd) { struct img *im = get(hd); return im && im->kind == IMG_PROC; }

void isim_image_free(int hd) {
    struct img *im = get(hd); if (!im) return;
    if (im->surf) cairo_surface_destroy(im->surf);
    if (im->svg) g_object_unref(im->svg);
    memset(im, 0, sizeof *im);
}
