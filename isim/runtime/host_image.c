/*
 * libisim_host images: decoding (gdk-pixbuf for raster, librsvg for SVG) and drawing
 * into the current cairo context, optionally as a template tinted with one color.
 *
 * SF Symbols are Apple's proprietary artwork and are not shipped. isim_image_symbol()
 * substitutes: common symbols are drawn procedurally by isim's own simple path programs
 * (host_symbols.inc: fill / circle / square / triangle / rectangle / slash variants compose),
 * others map to the system's Adwaita symbolic icons. Unknown names draw a visible placeholder
 * and are reported once on stderr. Substitutes look different from the real symbols; layout
 * uses SF-like metrics so sizes match.
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

#include "host_symbols.inc"

enum { IMG_RASTER = 1, IMG_SVG, IMG_PROC };
enum { PROC_NUM_CIRCLE = 1, PROC_CHECK_CIRCLE, PROC_GRID, PROC_PLACEHOLDER, PROC_KB_DOWN, PROC_GLOBE, PROC_CIRCLE, PROC_MINUS_CIRCLE, PROC_UPDOWN, PROC_ELLIPSIS, PROC_GLYPH };
struct img { int kind; cairo_surface_t *surf; RsvgHandle *svg; double w, h; int proc, fill; char text[8];
             const struct glyph *g; int encl, slash; };      /* PROC_GLYPH: glyph, text or svg (Adwaita) + variants */
static int symbol_weight;                                     /* UIImage.SymbolWeight of the symbol being drawn */
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

static cairo_status_t png_read(void *closure, unsigned char *buf, unsigned int n) {
    struct { const unsigned char *p; unsigned long left; } *rd = closure;
    if (n > rd->left) return CAIRO_STATUS_READ_ERROR;
    memcpy(buf, rd->p, n); rd->p += n; rd->left -= n;
    return CAIRO_STATUS_SUCCESS;
}
/* Returns a handle (>0) or 0. Size is in pixels of the source (the caller applies @2x/@3x). */
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h) {
    if (len > 5 && (!memcmp(data, "<?xml", 5) || !memcmp(data, "<svg", 4))) {
        RsvgHandle *svg = rsvg_handle_new_from_data(data, len, NULL);
        return svg ? load_svg(svg, w, h) : 0;
    }
    /* PNG through cairo (no gdk-pixbuf loader modules needed); other formats through gdk-pixbuf */
    if (len > 8 && !memcmp(data, "\x89PNG\r\n\x1a\n", 8)) {
        struct { const unsigned char *p; unsigned long left; } rd = { data, len };
        cairo_surface_t *png = cairo_image_surface_create_from_png_stream(png_read, &rd);
        if (cairo_surface_status(png) == CAIRO_STATUS_SUCCESS) {
            struct img v = { IMG_RASTER, png, NULL, cairo_image_surface_get_width(png), cairo_image_surface_get_height(png) };
            *w = v.w; *h = v.h;
            return new_img(v);
        }
        cairo_surface_destroy(png);
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
    { "square.grid.2x2", "legacy/preferences-desktop-apps-symbolic" }, { "iphone", "devices/phone-symbolic" }, { "info.circle", "actions/help-about-symbolic" },
    { "keyboard", "devices/input-keyboard-symbolic" },
    { "gear", "legacy/emblem-system-symbolic" }, { "gearshape", "legacy/emblem-system-symbolic" },
    { "lock.shield", "status/channel-secure-symbolic" }, { "lock", "status/system-lock-screen-symbolic" },
    { "xmark", "ui/window-close-symbolic" }, { "plus", "actions/list-add-symbolic" }, { "minus", "actions/list-remove-symbolic" },
    { "magnifyingglass", "actions/edit-find-symbolic" }, { "trash", "places/user-trash-symbolic" },
    { "star", "status/non-starred-symbolic" }, { "star.fill", "status/starred-symbolic" },
    { "info.circle", "actions/help-about-symbolic" }, { "exclamationmark.triangle", "status/dialog-warning-symbolic" },
    { "chevron.right", "actions/go-next-symbolic" }, { "chevron.left", "actions/go-previous-symbolic" },
    { "chevron.down", "actions/go-down-symbolic" }, { "chevron.up", "actions/go-up-symbolic" },
    { "house", "places/user-home-symbolic" }, { "person", "status/avatar-default-symbolic" },
    { "person.crop.circle", "status/avatar-default-symbolic" }, { "doc.on.doc", "actions/edit-copy-symbolic" }, { "square.stack", "actions/edit-copy-symbolic" }, { "rectangle.stack", "actions/edit-copy-symbolic" },
    { "pencil", "actions/document-edit-symbolic" }, { "square.and.pencil", "actions/document-edit-symbolic" },
    { "bell", "legacy/preferences-system-notifications-symbolic" }, { "envelope", "status/mail-unread-symbolic" },
    { "camera", "devices/camera-photo-symbolic" }, { "photo", "mimetypes/image-x-generic-symbolic" },
    { "play", "actions/media-playback-start-symbolic" }, { "pause", "actions/media-playback-pause-symbolic" },
    { "folder", "places/folder-symbolic" }, { "arrow.clockwise", "actions/view-refresh-symbolic" },
    { "square.and.arrow.up", "actions/send-to-symbolic" }, { "checkmark", "actions/object-select-symbolic" },
    { "gamecontroller", "categories/applications-games-symbolic" }, { "list.number", "actions/view-list-ordered-symbolic" },
    { "trophy", "status/starred-symbolic" }, { "rosette", "status/starred-symbolic" }, { "medal", "status/starred-symbolic" },
    { "book", "legacy/accessories-dictionary-symbolic" }, { "books.vertical", "legacy/accessories-dictionary-symbolic" },
    { "bookmark", "places/user-bookmarks-symbolic" }, { "doc", "mimetypes/x-office-document-symbolic" }, { "doc.text", "mimetypes/x-office-document-symbolic" },
    { "calendar", "mimetypes/x-office-calendar-symbolic" }, { "person.2", "legacy/system-users-symbolic" }, { "person.3", "legacy/system-users-symbolic" },
    { "person.circle", "status/avatar-default-symbolic" }, { "music.note", "mimetypes/audio-x-generic-symbolic" }, { "phone", "actions/call-start-symbolic" },
    { "paperplane", "actions/mail-send-symbolic" }, { "link", "actions/insert-link-symbolic" }, { "eye", "actions/view-reveal-symbolic" },
    { "questionmark.circle", "status/dialog-question-symbolic" }, { "wifi", "devices/network-wireless-symbolic" }, { "stop", "actions/media-playback-stop-symbolic" },
    { "list.bullet", "actions/view-list-bullet-symbolic" }, { "location", "actions/find-location-symbolic" }, { "mappin", "actions/mark-location-symbolic" },
    { "printer", "actions/document-print-symbolic" }, { "moon", "status/weather-clear-night-symbolic" }, { "battery.100", "legacy/battery-full-symbolic" },
    { "alarm", "status/alarm-symbolic" }, { "fork.knife", "categories/emoji-food-symbolic" }, { "face.smiling", "emotes/face-smile-symbolic" },
    { "lightbulb", "categories/emoji-objects-symbolic" }, { "tablecells", "mimetypes/x-office-spreadsheet-symbolic" }, { "doc.on.clipboard", "actions/edit-paste-symbolic" },
    { "scissors", "actions/edit-cut-symbolic" }, { "arrow.uturn.backward", "actions/edit-undo-symbolic" }, { "arrow.uturn.forward", "actions/edit-redo-symbolic" },
    { "plus.magnifyingglass", "actions/zoom-in-symbolic" }, { "minus.magnifyingglass", "actions/zoom-out-symbolic" }, { "exclamationmark.circle", "actions/mail-mark-important-symbolic" },
    { "checkmark.shield", "status/security-high-symbolic" }, { "arrow.right", "actions/go-next-symbolic" }, { "arrow.left", "actions/go-previous-symbolic" },
    { "speaker.wave.2", "status/audio-volume-high-symbolic" }, { "speaker.slash", "status/audio-volume-muted-symbolic" }, { "mic", "status/microphone-sensitivity-high-symbolic" },
    { "record.circle", "actions/media-record-symbolic" }, { "arrowshape.turn.up.left", "actions/mail-reply-sender-symbolic" },
    { "backward", "actions/media-seek-backward-symbolic" }, { "forward", "actions/media-seek-forward-symbolic" },
    { "backward.end", "actions/media-skip-backward-symbolic" }, { "forward.end", "actions/media-skip-forward-symbolic" },
    { "square.grid.3x3", "actions/view-grid-symbolic" }, { "line.3.horizontal", "actions/open-menu-symbolic" }, { "video", "devices/camera-video-symbolic" },
    { "arrow.down.circle", "actions/go-down-symbolic" }, { "clock.arrow.circlepath", "actions/document-open-recent-symbolic" },
    /* more stand-ins (drawn glyphs in host_symbols.inc take precedence over these) */
    { "airplane", "status/airplane-mode-symbolic" }, { "bluetooth", "devices/bluetooth-symbolic" },
    { "desktopcomputer", "devices/video-display-symbolic" }, { "display", "devices/video-display-symbolic" },
    { "laptopcomputer", "devices/computer-symbolic" }, { "ipad", "devices/computer-apple-ipad-symbolic" }, { "tv", "devices/tv-symbolic" },
    { "hifispeaker", "devices/audio-speakers-symbolic" }, { "scanner", "devices/scanner-symbolic" },
    { "externaldrive", "devices/drive-harddisk-symbolic" }, { "internaldrive", "devices/drive-harddisk-solidstate-symbolic" },
    { "opticaldisc", "devices/media-optical-symbolic" }, { "terminal", "legacy/utilities-terminal-symbolic" },
    { "paintbrush", "categories/applications-graphics-symbolic" }, { "paintpalette", "legacy/preferences-color-symbolic" },
    { "wrench.and.screwdriver", "categories/applications-engineering-symbolic" },
    { "hammer", "categories/applications-engineering-symbolic" }, { "puzzlepiece", "mimetypes/application-x-addon-symbolic" },
    { "puzzlepiece.extension", "mimetypes/application-x-addon-symbolic" }, { "shippingbox", "mimetypes/package-x-generic-symbolic" },
    { "cube.box", "mimetypes/package-x-generic-symbolic" }, { "archivebox", "mimetypes/package-x-generic-symbolic" },
    { "tray.and.arrow.down", "places/folder-download-symbolic" }, { "film", "mimetypes/video-x-generic-symbolic" },
    { "music.note.list", "places/folder-music-symbolic" }, { "photo.on.rectangle", "places/folder-pictures-symbolic" },
    { "photo.stack", "places/folder-pictures-symbolic" }, { "rectangle.portrait.and.arrow.right", "actions/system-log-out-symbolic" },
    { "cloud.rain", "status/weather-showers-symbolic" }, { "cloud.drizzle", "status/weather-showers-scattered-symbolic" },
    { "cloud.sun", "status/weather-few-clouds-symbolic" }, { "cloud.moon", "status/weather-few-clouds-night-symbolic" },
    { "cloud.bolt", "status/weather-storm-symbolic" }, { "cloud.bolt.rain", "status/weather-storm-symbolic" },
    { "snowflake", "status/weather-snow-symbolic" }, { "cloud.snow", "status/weather-snow-symbolic" },
    { "wind", "status/weather-windy-symbolic" }, { "tornado", "status/weather-tornado-symbolic" },
    { "cloud.fog", "status/weather-fog-symbolic" }, { "sunrise", "status/daytime-sunrise-symbolic" },
    { "sunset", "status/daytime-sunset-symbolic" }, { "repeat", "status/media-playlist-repeat-symbolic" },
    { "repeat.1", "status/media-playlist-repeat-song-symbolic" }, { "shuffle", "status/media-playlist-shuffle-symbolic" },
    { "eject", "actions/media-eject-symbolic" }, { "faceid", "devices/auth-face-symbolic" },
    { "touchid", "devices/auth-fingerprint-symbolic" }, { "simcard", "devices/auth-sim-symbolic" },
    { "server.rack", "places/network-server-symbolic" }, { "camera.rotate", "actions/camera-switch-symbolic" },
    { "rotate.left", "actions/object-rotate-left-symbolic" }, { "rotate.right", "actions/object-rotate-right-symbolic" },
    { "bold", "actions/format-text-bold-symbolic" }, { "italic", "actions/format-text-italic-symbolic" },
    { "underline", "actions/format-text-underline-symbolic" }, { "strikethrough", "actions/format-text-strikethrough-symbolic" },
    { "text.alignleft", "actions/format-justify-left-symbolic" }, { "text.aligncenter", "actions/format-justify-center-symbolic" },
    { "text.alignright", "actions/format-justify-right-symbolic" }, { "text.justify", "actions/format-justify-fill-symbolic" },
    { "increase.indent", "actions/format-indent-more-symbolic" }, { "decrease.indent", "actions/format-indent-less-symbolic" },
    { "paperclip", "status/mail-attachment-symbolic" }, { "arrowshape.turn.up.right", "actions/mail-forward-symbolic" },
    { "arrowshape.turn.up.left.2", "actions/mail-reply-all-symbolic" }, { "folder.badge.plus", "actions/folder-new-symbolic" },
    { "doc.badge.plus", "actions/document-new-symbolic" }, { "person.badge.plus", "actions/contact-new-symbolic" },
    { "sidebar.left", "actions/sidebar-show-symbolic" }, { "sidebar.right", "actions/sidebar-show-right-symbolic" },
    { "square.on.square", "actions/edit-copy-symbolic" }, { "arrow.up.left.and.arrow.down.right", "actions/view-fullscreen-symbolic" },
    { "arrow.down.right.and.arrow.up.left", "actions/view-restore-symbolic" }, { "pin", "actions/view-pin-symbolic" },
    { "calendar.badge.plus", "actions/appointment-new-symbolic" }, { "phone.down", "actions/call-stop-symbolic" },
    { "phone.arrow.up.right", "status/call-outgoing-symbolic" }, { "phone.arrow.down.left", "status/call-incoming-symbolic" },
    { "bubble.left.and.bubble.right", "actions/chat-message-new-symbolic" },
    { "personalhotspot", "status/network-wireless-hotspot-symbolic" },
    { "antenna.radiowaves.left.and.right", "status/network-wireless-hotspot-symbolic" },
    { "star.leadinghalf.filled", "status/semi-starred-symbolic" }, { "lock.rotation", "status/rotation-locked-symbolic" },
    { "hand.raised", "status/changes-prevent-symbolic" }, { "calculator", "legacy/accessories-calculator-symbolic" },
    { "questionmark.app", "legacy/help-browser-symbolic" }, { "doc.richtext", "mimetypes/x-office-document-symbolic" },
    { "newspaper", "mimetypes/x-office-document-symbolic" }, { "tray", "places/folder-symbolic" },
    { "tray.full", "places/folder-documents-symbolic" }, { "cpu", "devices/media-flash-symbolic" },
    { "memorychip", "devices/media-flash-symbolic" }, { "square.and.arrow.down.on.square", "places/folder-download-symbolic" },
    { "figure.walk", "categories/emoji-people-symbolic" }, { "car", "categories/emoji-travel-symbolic" },
    { "tram", "categories/emoji-travel-symbolic" }, { "bus", "categories/emoji-travel-symbolic" },
    { "sportscourt", "categories/emoji-activities-symbolic" }, { "figure.run", "categories/emoji-activities-symbolic" },
    { "tshirt", "categories/emoji-objects-symbolic" }, { "hare", "categories/emoji-nature-symbolic" },
    { "tortoise", "categories/emoji-nature-symbolic" }, { "ant", "categories/emoji-nature-symbolic" },
    { "ladybug", "categories/emoji-nature-symbolic" }, { "tree", "categories/emoji-nature-symbolic" },
    { "cup.and.saucer", "categories/emoji-food-symbolic" }, { "takeoutbag.and.cup.and.straw", "categories/emoji-food-symbolic" },
    { "flag.checkered", "categories/emoji-flags-symbolic" }, { "face.smiling.inverse", "emotes/face-smile-symbolic" },
    { "hand.wave", "categories/emoji-body-symbolic" }, { "brain", "categories/emoji-body-symbolic" },
    { "dice", "categories/applications-games-symbolic" }, { "graduationcap", "legacy/accessories-dictionary-symbolic" },
    { "studentdesk", "legacy/accessories-dictionary-symbolic" }, { "building.columns", "places/network-workgroup-symbolic" },
    { "building.2", "places/network-workgroup-symbolic" }, { "storefront", "places/network-workgroup-symbolic" },
    { "qrcode", "actions/view-app-grid-symbolic" }, { "barcode", "actions/view-continuous-symbolic" },
};

static int proc_symbol(int proc, int fill, const char *text, double *w, double *h) {
    struct img v = { IMG_PROC, NULL, NULL, 1.2, 1.2, proc, fill };
    if (proc == PROC_KB_DOWN) { v.w = 1.45; v.h = 1.2; }
    if (proc == PROC_UPDOWN) { v.w = 0.62; v.h = 1.0; }
    if (proc == PROC_ELLIPSIS && fill < 2) { v.w = 1.2; v.h = 0.3; }
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
    if (!strcmp(base, "chevron.up.chevron.down")) return proc_symbol(PROC_UPDOWN, 0, NULL, w, h);    /* menu pickers */
    if (!strcmp(base, "ellipsis")) return proc_symbol(PROC_ELLIPSIS, 0, NULL, w, h);
    if (!strcmp(base, "ellipsis.circle")) return proc_symbol(PROC_ELLIPSIS, fill ? 3 : 2, NULL, w, h);
    /* procedural glyphs: the whole name, then glyph + enclosure / slash */
    const struct glyph *g = find_glyph(base);
    const char *text = g ? NULL : find_text_glyph(base);
    if (text && strlen(base) == 1) text = NULL;                  /* single letters only in enclosures */
    int encl = 0, slash = 0;
    char inner[128] = "";
    if (!g && !text) {
        parse_symbol_name(name, inner, sizeof inner, &fill, &encl, &slash);
        if (encl || slash) { g = find_glyph(inner); text = g ? NULL : find_text_glyph(inner); }
        if (text && strlen(inner) == 1 && !encl) text = NULL;
    }
    if (g || text) {
        int hd = proc_symbol(PROC_GLYPH, fill, text, w, h);
        struct img *im = get(hd); im->g = g; im->encl = encl; im->slash = slash;
        return hd;
    }
    /* Adwaita: the whole name, the name without .fill, then the inner name in a drawn enclosure */
    for (int pass = 0; pass < 3; pass++) {
        const char *want = pass == 0 ? name : pass == 1 ? base : inner;
        if (pass == 2 && !(*inner && (encl || slash))) break;
        for (size_t i = 0; i < sizeof symbol_map / sizeof *symbol_map; i++)
            if (!strcmp(symbol_map[i].sf, want)) {
                char path[256]; snprintf(path, sizeof path, "/usr/share/icons/Adwaita/symbolic/%s.svg", symbol_map[i].adw);
                if (pass == 2) {
                    RsvgHandle *svg = rsvg_handle_new_from_file(path, NULL);
                    if (!svg) continue;
                    int hd = proc_symbol(PROC_GLYPH, fill, NULL, w, h);
                    struct img *im = get(hd); im->svg = svg; im->encl = encl; im->slash = slash;
                    return hd;
                }
                double sw, sh; int hd = isim_image_load(path, &sw, &sh);
                if (hd) { struct img *im = get(hd); im->w = 1.2; im->h = 1.2 * sh / sw; *w = im->w; *h = im->h; return hd; }
            }
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
    case PROC_GLYPH:
        draw_symbol(c, im->g, im->text[0] ? im->text : NULL, im->svg, im->fill, im->encl, im->slash, w, h, symbol_weight_factor(symbol_weight));
        break;
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
    case PROC_ELLIPSIS: {                       /* fill: 0 dots, 2 circle outline, 3 filled circle with cut-out dots */
        double r = w * 0.075, cy = h / 2;
        if (im->fill >= 2) {
            cairo_arc(c, w / 2, cy, w * 0.44, 0, 2 * M_PI);
            if (im->fill == 3) { cairo_fill(c); cairo_set_operator(c, CAIRO_OPERATOR_CLEAR); }
            else { cairo_set_line_width(c, lw); cairo_stroke(c); }
        } else r = w * 0.09;
        double gap = im->fill >= 2 ? w * 0.22 : w * 0.34;
        for (int k = -1; k <= 1; k++) { cairo_new_sub_path(c); cairo_arc(c, w / 2 + k * gap, cy, r, 0, 2 * M_PI); }
        cairo_fill(c);
        cairo_set_operator(c, CAIRO_OPERATOR_OVER);
        break; }
    case PROC_UPDOWN:
        cairo_set_line_width(c, lw * 1.1);
        cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_set_line_join(c, CAIRO_LINE_JOIN_ROUND);
        cairo_move_to(c, w * 0.12, h * 0.38); cairo_line_to(c, w * 0.5, h * 0.14); cairo_line_to(c, w * 0.88, h * 0.38);
        cairo_move_to(c, w * 0.12, h * 0.62); cairo_line_to(c, w * 0.5, h * 0.86); cairo_line_to(c, w * 0.88, h * 0.62);
        cairo_stroke(c);
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

/* isim_image_draw for symbol images with a UIImage.SymbolWeight (0 unspecified, 1 ultraLight ... 9 black):
   procedural symbols draw their strokes at that weight */
void isim_image_draw_symbol(int hd, double x, double y, double w, double h, const double *tint, double alpha, int weight) {
    int saved = symbol_weight;
    symbol_weight = weight;
    isim_image_draw(hd, x, y, w, h, tint, alpha);
    symbol_weight = saved;
}

/* Draws the source rectangle (sx, sy, sw, sh in image pixels) of a raster image into (x, y, w, h).
 * nearest: pixel-art filtering. blend: mix the color into the image's opaque pixels by factor (SpriteKit's
 * colorBlendFactor). Vector/procedural images are drawn whole. */
void isim_image_draw_part(int hd, double sx, double sy, double sw, double sh, double x, double y, double w, double h,
                          int nearest, const double *blend, double factor, double alpha) {
    struct img *im = get(hd); cairo_t *c = isim_host_cairo();
    if (!im || !c || w == 0 || h == 0 || sw <= 0 || sh <= 0) return;
    if (im->kind != IMG_RASTER) { isim_image_draw(hd, x, y, w, h, NULL, alpha); return; }
    cairo_save(c);
    cairo_translate(c, x, y);
    cairo_rectangle(c, 0, 0, w, h);
    cairo_clip(c);
    if (!blend || factor <= 0) {                     /* fast path: no group */
        cairo_scale(c, w / sw, h / sh);
        cairo_set_source_surface(c, im->surf, -sx, -sy);
        cairo_pattern_set_filter(cairo_get_source(c), nearest ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_GOOD);
        cairo_pattern_set_extend(cairo_get_source(c), CAIRO_EXTEND_PAD);
        if (alpha >= 0.999) cairo_paint(c); else cairo_paint_with_alpha(c, alpha);
        cairo_restore(c);
        return;
    }
    cairo_push_group(c);
    cairo_save(c);
    cairo_scale(c, w / sw, h / sh);
    cairo_set_source_surface(c, im->surf, -sx, -sy);
    cairo_pattern_set_filter(cairo_get_source(c), nearest ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_GOOD);
    cairo_pattern_set_extend(cairo_get_source(c), CAIRO_EXTEND_PAD);
    cairo_paint(c);
    cairo_restore(c);
    if (blend && factor > 0) {
        cairo_set_operator(c, CAIRO_OPERATOR_ATOP);
        cairo_set_source_rgba(c, blend[0], blend[1], blend[2], factor > 1 ? 1 : factor);
        cairo_paint(c);
    }
    cairo_pattern_t *pat = cairo_pop_group(c);
    cairo_set_source(c, pat);
    cairo_paint_with_alpha(c, alpha);
    cairo_pattern_destroy(pat);
    cairo_restore(c);
}
/* Pixel size of an image (vector images: their intrinsic size). */
void isim_image_pixel_size(int hd, double *w, double *h) {
    struct img *im = get(hd);
    *w = im ? im->w : 0; *h = im ? im->h : 0;
}

/* Is the image a symbol/template by nature (single-color art)? */
int isim_image_is_template(int hd) { struct img *im = get(hd); return im && im->kind == IMG_PROC; }

void isim_image_free(int hd) {
    struct img *im = get(hd); if (!im) return;
    if (im->surf) cairo_surface_destroy(im->surf);
    if (im->svg) g_object_unref(im->svg);
    memset(im, 0, sizeof *im);
}

/* ---------------- offscreen results and encoding (UIGraphicsImageRenderer, pngData/jpegData) ---------------- */
/* a copy of a cairo surface as a raster image handle */
int isim_image_from_surface(cairo_surface_t *src) {
    cairo_surface_flush(src);
    int w = cairo_image_surface_get_width(src), h = cairo_image_surface_get_height(src);
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    cairo_t *c = cairo_create(s);
    cairo_set_source_surface(c, src, 0, 0); cairo_set_operator(c, CAIRO_OPERATOR_SOURCE); cairo_paint(c);
    cairo_destroy(c);
    struct img v = { IMG_RASTER, s, NULL, w, h };
    return new_img(v);
}
static cairo_status_t png_write(void *closure, const unsigned char *data, unsigned int n) {
    GByteArray *a = closure; g_byte_array_append(a, data, n); return CAIRO_STATUS_SUCCESS;
}
/* encodes a raster image: fmt 0 PNG, 1 JPEG (quality 0..1). Returns the byte count (0 on failure); *out is malloc'd */
long isim_image_encode(int hd, int fmt, double quality, unsigned char **out) {
    struct img *im = get(hd);
    *out = NULL;
    if (!im || im->kind != IMG_RASTER || !im->surf) return 0;
    cairo_surface_flush(im->surf);
    GByteArray *a = g_byte_array_new();
    if (fmt == 0) {
        if (cairo_surface_write_to_png_stream(im->surf, png_write, a) != CAIRO_STATUS_SUCCESS) { g_byte_array_free(a, TRUE); return 0; }
    } else {
        int w = cairo_image_surface_get_width(im->surf), h = cairo_image_surface_get_height(im->surf), ss = cairo_image_surface_get_stride(im->surf);
        const unsigned char *src = cairo_image_surface_get_data(im->surf);
        GdkPixbuf *pb = gdk_pixbuf_new(GDK_COLORSPACE_RGB, FALSE, 8, w, h);
        int rs = gdk_pixbuf_get_rowstride(pb); guchar *dst = gdk_pixbuf_get_pixels(pb);
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            uint32_t px; memcpy(&px, src + y * ss + x * 4, 4);
            /* JPEG has no alpha: premultiplied values are the image over black, as iOS encodes transparent pixels */
            guchar *p = dst + y * rs + x * 3;
            p[0] = px >> 16 & 255; p[1] = px >> 8 & 255; p[2] = px & 255;
        }
        char q[8]; snprintf(q, sizeof q, "%d", (int)fmax(1, fmin(100, quality * 100)));
        gchar *buf = NULL; gsize len = 0;
        gboolean ok = gdk_pixbuf_save_to_buffer(pb, &buf, &len, "jpeg", NULL, "quality", q, NULL);
        g_object_unref(pb);
        if (!ok) { g_byte_array_free(a, TRUE); return 0; }
        g_byte_array_append(a, (const guint8 *)buf, (guint)len); g_free(buf);
    }
    long n = a->len;
    *out = malloc(n ? n : 1); memcpy(*out, a->data, n);
    g_byte_array_free(a, TRUE);
    return n;
}
void isim_image_bytes_free(unsigned char *p) { free(p); }
/* Raster image from 32-bit BGRA pixels (cairo ARGB32 byte order on little-endian; opaque video frames).
 * Used by host_media.c for video frames: created once, then updated in place on the UI thread. */
int isim_image_create_bgra(int w, int h) {
    if (w <= 0 || h <= 0) return 0;
    struct img v = { IMG_RASTER, cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h), NULL, w, h };
    return new_img(v);
}
void isim_image_update_bgra(int hd, const unsigned char *px, int w, int h) {
    struct img *im = get(hd);
    if (!im || im->kind != IMG_RASTER || (int)im->w != w || (int)im->h != h) return;
    cairo_surface_flush(im->surf);
    unsigned char *dst = cairo_image_surface_get_data(im->surf); int ds = cairo_image_surface_get_stride(im->surf);
    for (int y = 0; y < h; y++) memcpy(dst + y * ds, px + (size_t)y * w * 4, (size_t)w * 4);
    cairo_surface_mark_dirty(im->surf);
}

/* ---------------- surfaces for host_cg.c (Core Graphics pixel access, ImageIO, Core Image) ---------------- */
/* the pixels of an image: raster images give their surface (*owned = 0); vector/procedural images are
   rasterized at their intrinsic size into a new surface (*owned = 1, destroy it) */
cairo_surface_t *isim_image_get_surface(int hd, int *owned) {
    struct img *im = get(hd);
    *owned = 0;
    if (!im) return NULL;
    if (im->kind == IMG_RASTER) { cairo_surface_flush(im->surf); return im->surf; }
    int w = (int)ceil(im->w), h = (int)ceil(im->h);
    if (im->kind == IMG_PROC) { w = (int)ceil(im->w * 64); h = (int)ceil(im->h * 64); }
    if (w <= 0 || h <= 0) return NULL;
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    cairo_t *c = cairo_create(s);
    if (im->kind == IMG_SVG) { RsvgRectangle vp = { 0, 0, w, h }; rsvg_handle_render_document(im->svg, c, &vp, NULL); }
    else { cairo_set_source_rgba(c, 0, 0, 0, 1); draw_proc(c, im, w, h); }
    cairo_destroy(c);
    cairo_surface_flush(s);
    *owned = 1;
    return s;
}
/* a new raster image that takes over an ARGB32 surface */
int isim_image_adopt_surface(cairo_surface_t *s) {
    struct img v = { IMG_RASTER, s, NULL, cairo_image_surface_get_width(s), cairo_image_surface_get_height(s) };
    return new_img(v);
}
/* the raster surface behind a handle (NULL for vector/procedural images); used by host_ca.c */
cairo_surface_t *isim_image_surface(int hd) { struct img *im = get(hd); return im && im->kind == IMG_RASTER ? im->surf : NULL; }
