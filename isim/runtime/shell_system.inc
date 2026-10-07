/* isim shell: system integration around apps (included by shell.inc).
 *
 * Messages: apps send SM_SYSTEM (isim_shell_request(ISIM_SHELL_SYSTEM, verb, b, c)); the shell sends apps
 * EV_SYSTEM events whose text is "<verb> <arguments>". Script commands that are not plain input arrive as
 * EV_SHELL_CMD (host.c script_step).
 *
 *   app -> shell   "appinfo PATH NAME\x1fICON"   the home screen tells the shell each app's name and icon
 *                  "openurl - URL"               open a URL in another app (the home screen resolves it)
 *                  "reload-home"                 an app changed something the home screen shows (alternate icon, shortcuts)
 *                  "launch-bg PATH EXE\x1fURL"   start an app in the background (BackgroundTasks) or deliver URL to it
 *   shell -> app   "openurl URL", "launchtask BUNDLE TASK", "reload" (to the home screen), "bgtask TASK" (to the app)
 */

#include <stdarg.h>

struct sys_appinfo { char path[512], name[128], icon[512]; };
static struct sys_appinfo appinfo[128]; static int nappinfo;

static struct sys_appinfo *sys_info(const char *path) {
    for (int i = 0; i < nappinfo; i++) if (!strcmp(appinfo[i].path, path)) return &appinfo[i];
    return NULL;
}
static void sys_send_text(int i, const char *fmt, ...) __attribute__((format(printf, 2, 3)));
static void sys_send_text(int i, const char *fmt, ...) {
    struct isim_event e = { .type = EV_SYSTEM };
    va_list ap; va_start(ap, fmt); vsnprintf(e.text, sizeof e.text, fmt, ap); va_end(ap);
    shell_forward(i, &e);
}

/* start (or wake) an app in the background; url: an isim-private marker such as isim-bgtask:ID */
static void sys_launch_background(const char *bundle, const char *exe, const char *url) {
    int i = shell_find(bundle);
    if (i >= 0) {
        if (url && !strncmp(url, "isim-bgtask:", 12)) sys_send_text(i, "bgtask %s", url + 12);
        else if (url && *url) { struct isim_event e = { .type = EV_OPEN_URL }; snprintf(e.text, sizeof e.text, "%s", url); shell_forward(i, &e); }
        return;
    }
    spawn_background = 1;
    i = shell_spawn(bundle, exe, url);
    spawn_background = 0;
    if (i >= 0) fprintf(stderr, "isim shell: %s launched in the background\n", bundle);
}

/* ======================= system UI drawn by the shell =======================
 * lock screen, app switcher, Notification Center, Control Center. Each is drawn into `comp` over the current screen;
 * its parts are registered as elements (id, text, rect) so scripts can `tapid` / `swipeid` them and `dump` lists them. */
enum { OV_NONE, OV_SWITCHER, OV_LOCK, OV_NC, OV_CC };
static int ov, locked;
static double ov_t0;                                  /* when the overlay opened (slide-in) */
static double last_active_t[32];                      /* app switcher order (most recent first) */
static int seen_active = -1;

struct nc_item { char path[512], id[256], title[256], body[512], icon[512]; time_t t; };
static struct nc_item ncl[64]; static int nnc;

struct sys_el { char id[128], text[192]; struct rectf r; int kind, arg; };
enum { EL_NONE, EL_CARD, EL_NC_ITEM, EL_NC_CLEAR, EL_CC_TOGGLE, EL_CC_SLIDER, EL_BG };
static struct sys_el els[96]; static int nels;

/* Control Center state */
enum { CC_AIRPLANE, CC_CELLULAR, CC_WIFI, CC_BLUETOOTH, CC_ORIENT, CC_MIRROR, CC_FOCUS, CC_FLASHLIGHT, CC_TIMER, CC_DARK, CC_CAMERA, CC_N };
static int cc_on[CC_N] = { 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 };
static double cc_brightness = 1.0, cc_volume = 0.6;
static const char *const cc_ids[CC_N] = { "cc-airplane", "cc-cellular", "cc-wifi", "cc-bluetooth", "cc-orientation", "cc-mirroring", "cc-focus",
                                         "cc-flashlight", "cc-timer", "cc-dark", "cc-camera" };
static const char *const cc_symbols[CC_N] = { "airplane", "antenna.radiowaves.left.and.right", "wifi", "dot.radiowaves.left.and.right", "lock.rotation",
                                             "rectangle.on.rectangle", "moon.fill", "flashlight.on.fill", "timer", "circle.lefthalf.filled", "camera.fill" };
static const char *const cc_names[CC_N] = { "Airplane Mode", "Cellular Data", "Wi-Fi", "Bluetooth", "Orientation Lock", "Screen Mirroring", "Focus",
                                           "Flashlight", "Timer", "Dark Mode", "Camera" };

static int sys_visible(void) { return ov != OV_NONE; }
static int sys_hides_banners(void) { return locked || ov != OV_NONE || cc_on[CC_FOCUS]; }

static const char *app_label(int i) {
    struct sys_appinfo *ai = i >= 0 ? sys_info(clients[i].bundle) : NULL;
    if (ai && ai->name[0]) return ai->name;
    const char *b = strrchr(clients[i].bundle, '/'); return b ? b + 1 : clients[i].bundle;
}
static void app_short_id(int i, char *out, size_t n) {          /* "HelloSystem" from ".../HelloSystem.app" */
    const char *b = strrchr(clients[i].bundle, '/'); b = b ? b + 1 : clients[i].bundle;
    snprintf(out, n, "%.*s", (int)(strcspn(b, ".")), b);
}

static void sys_round(cairo_t *c, double x, double y, double w, double h, double r);
/* ---- the look of the emulated iOS version (isim --os) ----
   iOS 17: Control Center modules are translucent platters with rounded-square buttons; the Lock Screen clock is bold.
   iOS 18: the Control Center redesign — round toggles, rounder modules, the "+" (edit) and power buttons at the top and
           the page column on the right (favorites, music, home, connectivity).
   iOS 26/27: Liquid Glass — glass modules, buttons and sliders (isim_gfx_glass), lighter dimming; the Lock Screen
           clock is tall glass numerals. Adapted: isim's own drawing, not Apple artwork. */
static int sys_os(void) { return isim_os_version() / 10000; }
static void sys_glass(cairo_t *c, double x, double y, double w, double h, double r, const double *tint, int flags) {
    cairo_t *saved = cr; cr = c; isim_gfx_glass(x, y, w, h, r, tint, flags); cr = saved;
}
/* a module / button background in the version's style */
static void sys_platter(cairo_t *c, double x, double y, double w, double h, double r, double alpha) {
    if (sys_os() >= 26) { sys_glass(c, x, y, w, h, r, NULL, 1 | 2 | 4); return; }
    cairo_new_path(c);
    sys_round(c, x, y, w, h, r); cairo_set_source_rgba(c, 1, 1, 1, alpha); cairo_fill(c);
}

/* ---- drawing helpers ---- */
static void sys_round(cairo_t *c, double x, double y, double w, double h, double r) {
    r = fmin(r, fmin(w, h) / 2);
    cairo_new_sub_path(c);
    cairo_arc(c, x + w - r, y + r, r, -M_PI / 2, 0); cairo_arc(c, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(c, x + r, y + h - r, r, M_PI / 2, M_PI); cairo_arc(c, x + r, y + r, r, M_PI, 1.5 * M_PI);
    cairo_close_path(c);
}
static double sys_text(cairo_t *c, const char *utf8, double x, double y, double w, double size, int weight, int align, int lines, double r, double g, double b, double a) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, SYSTEM_SANS);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, weight);
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
    pango_layout_set_text(l, utf8, -1);
    if (w > 0) { pango_layout_set_width(l, (int)(w * PANGO_SCALE)); pango_layout_set_wrap(l, PANGO_WRAP_WORD_CHAR); }
    if (lines) { pango_layout_set_height(l, -lines); pango_layout_set_ellipsize(l, PANGO_ELLIPSIZE_END); }
    pango_layout_set_alignment(l, align == 1 ? PANGO_ALIGN_CENTER : align == 2 ? PANGO_ALIGN_RIGHT : PANGO_ALIGN_LEFT);
    cairo_set_source_rgba(c, r, g, b, a); cairo_move_to(c, x, y); pango_cairo_show_layout(c, l);
    int pw, ph; pango_layout_get_pixel_size(l, &pw, &ph);
    g_object_unref(l);
    return ph;
}
/* SF-Symbol-like glyphs from the host's symbol table, drawn with the host image code (which draws into `cr`) */
static void sys_symbol(cairo_t *c, const char *name, double cx, double cy, double size, double r, double g, double b) {
    static const struct { const char *sf, *adw; } map[] = {
        { "airplane", "status/airplane-mode-symbolic" }, { "antenna.radiowaves.left.and.right", "status/network-cellular-signal-excellent-symbolic" },
        { "wifi", "status/network-wireless-signal-excellent-symbolic" }, { "dot.radiowaves.left.and.right", "status/bluetooth-active-symbolic" },
        { "lock.rotation", "status/rotation-locked-symbolic" }, { "rectangle.on.rectangle", "devices/video-joined-displays-symbolic" },
        { "timer", "legacy/preferences-system-time-symbolic" }, { "camera.fill", "devices/camera-photo-symbolic" },
        { "sun.max.fill", "status/display-brightness-symbolic" }, { "speaker.wave.2.fill", "status/audio-volume-medium-symbolic" },
        { "lock.fill", "status/changes-prevent-symbolic" }, { "moon.fill", "status/weather-clear-night-symbolic" },
        { "play.fill", "actions/media-playback-start-symbolic" }, { "forward.fill", "actions/media-seek-forward-symbolic" },
        { "backward.fill", "actions/media-seek-backward-symbolic" } };
    if (!strncmp(name, "flashlight", 10) || !strcmp(name, "circle.lefthalf.filled")) {      /* drawn here */
        cairo_save(c); cairo_set_source_rgb(c, r, g, b); cairo_set_line_width(c, size * 0.09);
        if (name[0] == 'f') {
            double s = size;
            cairo_move_to(c, cx - s * 0.28, cy - s * 0.45); cairo_line_to(c, cx + s * 0.28, cy - s * 0.45);
            cairo_line_to(c, cx + s * 0.2, cy - s * 0.12); cairo_line_to(c, cx + s * 0.13, cy + s * 0.48);
            cairo_line_to(c, cx - s * 0.13, cy + s * 0.48); cairo_line_to(c, cx - s * 0.2, cy - s * 0.12); cairo_close_path(c);
            if (strstr(name, ".on")) cairo_fill(c); else cairo_stroke(c);
        } else {
            cairo_arc(c, cx, cy, size * 0.42, 0, 2 * M_PI); cairo_stroke(c);
            cairo_arc(c, cx, cy, size * 0.42, M_PI / 2, 1.5 * M_PI); cairo_close_path(c); cairo_fill(c);
        }
        cairo_restore(c); return;
    }
    double w = 0, h = 0; int hd = 0;
    for (size_t k = 0; k < sizeof map / sizeof *map && !hd; k++) if (!strcmp(map[k].sf, name)) {
        char p[256]; snprintf(p, sizeof p, "/usr/share/icons/Adwaita/symbolic/%s.svg", map[k].adw);
        double sw, sh; hd = isim_image_load(p, &sw, &sh);
        if (hd) { w = 1.1; h = 1.1 * sh / sw; }
    }
    if (!hd) hd = isim_image_symbol(name, &w, &h);
    if (!hd || w <= 0 || h <= 0) { cairo_set_source_rgb(c, r, g, b); cairo_arc(c, cx, cy, size * 0.3, 0, 2 * M_PI); cairo_fill(c); return; }
    double sw = w * size, sh = h * size;
    cairo_t *saved = cr; cr = c;
    double tint[4] = { r, g, b, 1 };
    isim_image_draw(hd, cx - sw / 2, cy - sh / 2, sw, sh, tint, 1);
    cr = saved;
    isim_image_free(hd);
}
static void sys_icon(cairo_t *c, const char *path, double x, double y, double s) {
    cairo_save(c);
    sys_round(c, x, y, s, s, s * 0.225); cairo_clip(c);
    cairo_surface_t *img = path && *path ? cairo_image_surface_create_from_png(path) : NULL;
    if (img && cairo_surface_status(img) == CAIRO_STATUS_SUCCESS && cairo_image_surface_get_width(img) > 0) {
        double k = s / cairo_image_surface_get_width(img);
        cairo_translate(c, x, y); cairo_scale(c, k, k);
        cairo_set_source_surface(c, img, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BILINEAR); cairo_paint(c);
    } else { cairo_set_source_rgb(c, 0.0, 0.48, 1.0); cairo_paint(c); }
    if (img) cairo_surface_destroy(img);
    cairo_restore(c);
}
/* a strongly blurred copy of a device-pixel surface (down- and up-scaling) */
static void sys_paint_blurred(cairo_t *c, cairo_surface_t *src, int w, int h, double dim) {
    int sw = w / 24 > 0 ? w / 24 : 1, sh = h / 24 > 0 ? h / 24 : 1;
    cairo_surface_t *small = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, sw, sh);
    cairo_t *k = cairo_create(small);
    cairo_scale(k, (double)sw / w, (double)sh / h);
    cairo_set_source_surface(k, src, 0, 0); cairo_pattern_set_filter(cairo_get_source(k), CAIRO_FILTER_GOOD);
    cairo_pattern_set_extend(cairo_get_source(k), CAIRO_EXTEND_PAD); cairo_paint(k);
    cairo_destroy(k);
    cairo_save(c);
    cairo_identity_matrix(c);
    cairo_scale(c, (double)surf_w / sw, (double)surf_h / sh);
    cairo_set_source_surface(c, small, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BILINEAR);
    cairo_pattern_set_extend(cairo_get_source(c), CAIRO_EXTEND_PAD); cairo_paint(c);
    cairo_restore(c);
    cairo_surface_destroy(small);
    if (dim > 0) { cairo_set_source_rgba(c, 0, 0, 0, dim); cairo_paint(c); }
}
static void el_add(const char *id, const char *text, struct rectf r, int kind, int arg) {
    if (nels >= (int)(sizeof els / sizeof *els)) return;
    struct sys_el *e = &els[nels++];
    snprintf(e->id, sizeof e->id, "%s", id); snprintf(e->text, sizeof e->text, "%s", text ? text : "");
    e->r = r; e->kind = kind; e->arg = arg;
}
static void sys_time_strings(char *tm_s, size_t n1, char *date_s, size_t n2) {
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    int h = tm.tm_hour % 12; if (!h) h = 12;
    snprintf(tm_s, n1, "%d:%02d", h, tm.tm_min);
    strftime(date_s, n2, "%A, %B %e", &tm);
    char *dbl = strstr(date_s, "  "); if (dbl) memmove(dbl, dbl + 1, strlen(dbl));
}

/* ---- app switcher ---- */
static int sw_order[32], sw_n;
static double sw_scroll;                           /* points; 0 = most recent card centred */
static struct { int on, card; double x0, y0, x, y, scroll0, t0; } sw_drag;
static double sw_kill_dy[32];                      /* cards being swiped away (points) */
static void sw_collect(void) {
    sw_n = 0;
    for (int i = 1; i < nclients; i++) if (clients[i].alive && clients[i].has_frame) sw_order[sw_n++] = i;
    for (int a = 0; a < sw_n; a++) for (int b = a + 1; b < sw_n; b++)
        if (last_active_t[sw_order[b]] > last_active_t[sw_order[a]]) { int t = sw_order[a]; sw_order[a] = sw_order[b]; sw_order[b] = t; }
}
static struct rectf sw_card_rect(int k, double *radius) {
    double s = dev.width >= 700 ? 0.42 : 0.62;
    double w = dev.width * s, h = dev.height * s, spacing = w * 0.72;
    double cx = dev.width / 2 - k * spacing + sw_scroll;
    *radius = dev.corner_radius * s + 6;
    return (struct rectf){ cx - w / 2, dev.height * 0.47 - h / 2, w, h };
}

/* ---- Notification Center list ---- */
static void nc_add(const char *path, const char *id, const char *icon, const char *title, const char *body) {
    for (int i = 0; i < nnc; i++) if (!strcmp(ncl[i].path, path) && !strcmp(ncl[i].id, id)) { memmove(&ncl[i], &ncl[i + 1], (nnc - i - 1) * sizeof *ncl); nnc--; break; }
    if (nnc >= 64) { memmove(&ncl[0], &ncl[1], 63 * sizeof *ncl); nnc--; }
    struct nc_item *n = &ncl[nnc++];
    snprintf(n->path, sizeof n->path, "%s", path); snprintf(n->id, sizeof n->id, "%s", id); snprintf(n->icon, sizeof n->icon, "%s", icon ? icon : "");
    snprintf(n->title, sizeof n->title, "%s", title); snprintf(n->body, sizeof n->body, "%s", body); n->t = time(NULL);
}
static void nc_draw_list(cairo_t *c, double top, int lock_style) {
    double w = fmin(dev.width - 16, 400), x = (dev.width - w) / 2, y = top;
    if (!lock_style) {
        sys_text(c, "Notification Center", x + 6, y, w - 60, 20, PANGO_WEIGHT_BOLD, 0, 1, 1, 1, 1, 1);
        if (nnc) {
            struct rectf r = { x + w - 34, y, 28, 28 };
            cairo_set_source_rgba(c, 1, 1, 1, 0.22); cairo_arc(c, r.x + 14, r.y + 14, 14, 0, 2 * M_PI); cairo_fill(c);
            cairo_set_source_rgb(c, 1, 1, 1); cairo_set_line_width(c, 2);
            cairo_move_to(c, r.x + 9, r.y + 9); cairo_line_to(c, r.x + 19, r.y + 19); cairo_move_to(c, r.x + 19, r.y + 9); cairo_line_to(c, r.x + 9, r.y + 19); cairo_stroke(c);
            el_add("nc-clear", "Clear", r, EL_NC_CLEAR, 0);
        }
        y += 40;
    }
    if (!nnc) {
        if (!lock_style) sys_text(c, "No Older Notifications", 0, y + 20, dev.width, 15, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.75);
        return;
    }
    for (int i = nnc - 1; i >= 0 && y < dev.height - 120; i--) {
        struct nc_item *n = &ncl[i];
        struct rectf r = { x, y, w, 76 };
        sys_round(c, r.x, r.y, r.w, r.h, 22);
        cairo_set_source_rgba(c, 0.95, 0.95, 0.97, 0.88); cairo_fill(c);
        sys_icon(c, n->icon, r.x + 12, r.y + 19, 38);
        sys_text(c, n->title, r.x + 60, r.y + 12, r.w - 130, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 0, 0, 0, 1);
        long ago = (long)(time(NULL) - n->t) / 60; char when[32];
        if (ago < 1) snprintf(when, sizeof when, "now"); else snprintf(when, sizeof when, "%ldm ago", ago);
        sys_text(c, when, r.x + r.w - 70, r.y + 13, 56, 13, PANGO_WEIGHT_NORMAL, 2, 1, 0.45, 0.45, 0.45, 1);
        sys_text(c, n->body, r.x + 60, r.y + 33, r.w - 74, 15, PANGO_WEIGHT_NORMAL, 0, 2, 0, 0, 0, 1);
        char id[300]; snprintf(id, sizeof id, "nc-item-%s", n->id);
        el_add(id, n->title, r, EL_NC_ITEM, i);
        y += r.h + 8;
    }
}

/* ---- Control Center ---- */
static void cc_button(cairo_t *c, int k, struct rectf r, int circle) {
    int on = cc_on[k];
    double bg_on[3] = { 0, 0.48, 1 };
    if (k == CC_AIRPLANE) { bg_on[0] = 1; bg_on[1] = 0.58; bg_on[2] = 0; }
    if (k == CC_CELLULAR) { bg_on[0] = 0.2; bg_on[1] = 0.78; bg_on[2] = 0.35; }
    if (k == CC_FOCUS) { bg_on[0] = 0.37; bg_on[1] = 0.36; bg_on[2] = 0.9; }
    if (k == CC_ORIENT || k == CC_FLASHLIGHT || k == CC_DARK) { bg_on[0] = bg_on[1] = bg_on[2] = 1; }
    int os = sys_os();
    if (os >= 18 && fabs(r.w - r.h) < 1) circle = 1;               /* iOS 18: round toggles */
    double rad = circle ? r.w / 2 : os >= 26 ? r.h / 2 : os >= 18 ? r.h * 0.42 : 18;
    if (!on && os >= 26) sys_glass(c, r.x, r.y, r.w, r.h, rad, NULL, 1 | 2 | 4);
    else {
        cairo_new_path(c);
        if (circle) cairo_arc(c, r.x + r.w / 2, r.y + r.h / 2, r.w / 2, 0, 2 * M_PI);
        else sys_round(c, r.x, r.y, r.w, r.h, rad);
        if (on) cairo_set_source_rgb(c, bg_on[0], bg_on[1], bg_on[2]); else cairo_set_source_rgba(c, 1, 1, 1, 0.18);
        cairo_fill(c);
    }
    int dark_glyph = on && bg_on[0] == 1 && bg_on[1] == 1;
    double fg = dark_glyph ? 0.1 : 1;
    if (k == CC_FOCUS) {
        sys_symbol(c, cc_symbols[k], r.x + 26, r.y + r.h / 2, 20, fg, fg, fg);
        sys_text(c, on ? "Do Not Disturb" : "Focus", r.x + 46, r.y + r.h / 2 - 10, r.w - 52, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, fg, fg, fg, 1);
    } else sys_symbol(c, cc_symbols[k], r.x + r.w / 2, r.y + r.h / 2, circle ? 22 : 24, fg, fg, fg);
    el_add(cc_ids[k], on ? "on" : "off", r, EL_CC_TOGGLE, k);
}
static void cc_slider(cairo_t *c, const char *id, const char *sym, double v, struct rectf r, int arg) {
    double rad = sys_os() >= 18 ? r.w * 0.46 : 22;
    sys_platter(c, r.x, r.y, r.w, r.h, rad, 0.18);
    cairo_save(c); cairo_new_path(c); sys_round(c, r.x, r.y, r.w, r.h, rad); cairo_clip(c);
    cairo_rectangle(c, r.x, r.y + r.h * (1 - v), r.w, r.h * v); cairo_set_source_rgb(c, 1, 1, 1); cairo_fill(c);
    cairo_restore(c);
    sys_symbol(c, sym, r.x + r.w / 2, r.y + r.h - 26, 22, 0.45, 0.45, 0.47);
    char t[16]; snprintf(t, sizeof t, "%d%%", (int)lround(v * 100));
    el_add(id, t, r, EL_CC_SLIDER, arg);
}
static void cc_draw(cairo_t *c) {
    double m = dev.width >= 700 ? (dev.width - 420) / 2 : 30, gap = 14;
    int os = sys_os();
    double u = (dev.width - 2 * m - 3 * gap) / 4, top = fmax(dev.safe_top, 20) + (os >= 18 ? 64 : 36);
    double big = 2 * u + gap, prad = os >= 26 ? 34 : os >= 18 ? 30 : 24;
    if (os >= 18) {                                   /* iOS 18: edit (+) and power at the top, the page column */
        double by = fmax(dev.safe_top, 20) + 10, d = 34;
        struct rectf edit = { m, by, d, d }, power = { dev.width - m - d, by, d, d };
        for (int i = 0; i < 2; i++) {
            struct rectf b = i ? power : edit;
            if (os >= 26) sys_glass(c, b.x, b.y, d, d, d / 2, NULL, 1 | 2 | 4);
            else { cairo_new_path(c); cairo_arc(c, b.x + d / 2, b.y + d / 2, d / 2, 0, 2 * M_PI); cairo_set_source_rgba(c, 1, 1, 1, 0.22); cairo_fill(c); }
        }
        cairo_save(c); cairo_set_source_rgb(c, 1, 1, 1); cairo_set_line_width(c, 2); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND);
        double ex = edit.x + d / 2, ey = edit.y + d / 2;
        cairo_new_path(c); cairo_move_to(c, ex - 7, ey); cairo_line_to(c, ex + 7, ey); cairo_move_to(c, ex, ey - 7); cairo_line_to(c, ex, ey + 7); cairo_stroke(c);
        double px = power.x + d / 2, py = power.y + d / 2;
        cairo_new_path(c); cairo_arc(c, px, py + 1, 6.5, -M_PI / 2 + 0.75, 1.5 * M_PI - 0.75);
        cairo_move_to(c, px, py - 7.5); cairo_line_to(c, px, py); cairo_stroke(c);
        cairo_restore(c);
        el_add("cc-edit", "Edit", edit, EL_NONE, 0); el_add("cc-power", "Power", power, EL_NONE, 0);
        const char *pages[4] = { "star.fill", "play.fill", "house", "wifi" };
        for (int i = 0; i < 4; i++) sys_symbol(c, pages[i], dev.width - m / 2, top + big * 0.55 + i * 28, 13, 1, 1, 1);
    }
    /* connectivity */
    struct rectf conn = { m, top, big, big };
    sys_platter(c, conn.x, conn.y, conn.w, conn.h, prad, 0.14);
    double d = u * 0.78, pad = (big - 2 * d) / 3;
    int ks[4] = { CC_AIRPLANE, CC_CELLULAR, CC_WIFI, CC_BLUETOOTH };
    for (int i = 0; i < 4; i++) cc_button(c, ks[i], (struct rectf){ conn.x + pad + (i % 2) * (d + pad), conn.y + pad + (i / 2) * (d + pad), d, d }, 1);
    /* now playing */
    struct rectf np = { m + big + gap, top, big, big };
    sys_platter(c, np.x, np.y, np.w, np.h, prad, 0.14);
    sys_text(c, "Not Playing", np.x + 16, np.y + 16, np.w - 32, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 0.85);
    sys_symbol(c, "backward.fill", np.x + np.w * 0.22, np.y + np.h - 34, 20, 1, 1, 1);
    sys_symbol(c, "play.fill", np.x + np.w * 0.5, np.y + np.h - 34, 24, 1, 1, 1);
    sys_symbol(c, "forward.fill", np.x + np.w * 0.78, np.y + np.h - 34, 20, 1, 1, 1);
    el_add("cc-nowplaying", "Not Playing", np, EL_NONE, 0);
    /* row 2: orientation lock, mirroring | brightness, volume (tall) ; focus under the first two */
    double y2 = top + big + gap;
    cc_button(c, CC_ORIENT, (struct rectf){ m, y2, u, u }, 0);
    cc_button(c, CC_MIRROR, (struct rectf){ m + u + gap, y2, u, u }, 0);
    cc_button(c, CC_FOCUS, (struct rectf){ m, y2 + u + gap, big, u }, 0);
    cc_slider(c, "cc-brightness", "sun.max.fill", cc_brightness, (struct rectf){ m + big + gap, y2, u, big }, 0);
    cc_slider(c, "cc-volume", "speaker.wave.2.fill", cc_volume, (struct rectf){ m + big + gap + u + gap, y2, u, big }, 1);
    /* row 4 */
    double y4 = y2 + big + gap;
    int r4[4] = { CC_FLASHLIGHT, CC_TIMER, CC_DARK, CC_CAMERA };
    for (int i = 0; i < 4; i++) cc_button(c, r4[i], (struct rectf){ m + i * (u + gap), y4, u, u }, 0);
}

/* ---- lock screen ---- */
static double la_draw_lock(cairo_t *c, double top);
static cairo_surface_t *wallpaper;
static void wallpaper_draw(cairo_t *c, cairo_surface_t *home, int hw, int hh) {
    if (!wallpaper && shell_springboard) {                     /* the home screen's wallpaper image */
        char p[1024]; snprintf(p, sizeof p, "%s/wallpaper.png", shell_springboard);
        wallpaper = cairo_image_surface_create_from_png(p);
        if (cairo_surface_status(wallpaper) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(wallpaper); wallpaper = NULL; shell_springboard = NULL; }
    }
    if (wallpaper) {
        double ww = cairo_image_surface_get_width(wallpaper), wh = cairo_image_surface_get_height(wallpaper);
        double k = fmax(dev.width / ww, dev.height / wh);
        cairo_save(c); cairo_scale(c, k, k); cairo_set_source_surface(c, wallpaper, 0, 0); cairo_paint(c); cairo_restore(c);
    } else sys_paint_blurred(c, home, hw, hh, 0.12);
}
static void lock_draw(cairo_t *c, cairo_surface_t *home, int hw, int hh) {
    wallpaper_draw(c, home, hw, hh);
    char t[16], dstr[64]; sys_time_strings(t, sizeof t, dstr, sizeof dstr);
    double top = fmax(dev.safe_top, 20);
    sys_symbol(c, "lock.fill", dev.width / 2, top + 12, 18, 1, 1, 1);
    sys_text(c, dstr, 0, top + 30, dev.width, 19, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.9);
    const char *fixed = getenv("ISIM_LOCK_TIME");                 /* tests: a fixed "H:MM" */
    if (fixed && *fixed) snprintf(t, sizeof t, "%s", fixed);
    if (sys_os() >= 26) {                                          /* iOS 26: tall glass numerals */
        double size = dev.width * 0.40;
        PangoLayout *l = pango_cairo_create_layout(c);
        PangoFontDescription *fd = pango_font_description_new();
        pango_font_description_set_family(fd, SYSTEM_SANS); pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
        pango_font_description_set_weight(fd, PANGO_WEIGHT_HEAVY);
        pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
        pango_layout_set_text(l, t, -1); pango_layout_set_width(l, (int)(dev.width * PANGO_SCALE)); pango_layout_set_alignment(l, PANGO_ALIGN_CENTER);
        cairo_save(c); cairo_new_path(c); cairo_move_to(c, 0, top + 40); pango_cairo_layout_path(c, l); g_object_unref(l);
        cairo_path_t *glyphs = cairo_copy_path(c); cairo_new_path(c);
        cairo_save(c); cairo_translate(c, 0, 3); cairo_append_path(c, glyphs); cairo_set_source_rgba(c, 0, 0, 0, 0.18); cairo_fill(c); cairo_restore(c);
        cairo_append_path(c, glyphs); cairo_clip(c);
        cairo_pattern_t *g = cairo_pattern_create_linear(0, top + 40, 0, top + 40 + size * 1.1);
        cairo_pattern_add_color_stop_rgba(g, 0, 1, 1, 1, 0.62); cairo_pattern_add_color_stop_rgba(g, 1, 1, 1, 1, 0.30);
        cairo_set_source(c, g); cairo_paint(c); cairo_pattern_destroy(g);
        cairo_reset_clip(c);
        cairo_push_group(c);                                       /* the rim: outside the glyphs only */
        cairo_new_path(c); cairo_append_path(c, glyphs); cairo_set_line_width(c, 3.2); cairo_set_source_rgba(c, 1, 1, 1, 0.9); cairo_stroke(c);
        cairo_set_operator(c, CAIRO_OPERATOR_DEST_OUT); cairo_append_path(c, glyphs); cairo_set_source_rgba(c, 0, 0, 0, 1); cairo_fill(c);
        cairo_pop_group_to_source(c); cairo_paint(c);
        cairo_path_destroy(glyphs); cairo_restore(c);
    } else sys_text(c, t, 0, top + 50, dev.width, 92, PANGO_WEIGHT_BOLD, 1, 1, 1, 1, 1, 0.95);
    el_add("lock-clock", t, (struct rectf){ 0, top + 50, dev.width, 100 }, EL_NONE, 0);
    double lt = dev.height * 0.30;
    lt += la_draw_lock(c, lt);
    nc_draw_list(c, fmax(lt, dev.height * 0.42), 1);
    cairo_set_source_rgba(c, 1, 1, 1, 0.9);
    sys_text(c, "Swipe up to open", 0, dev.height - 62, dev.width, 15, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 0.85);
    struct rectf bl = { 46, dev.height - 108, 50, 50 }, br = { dev.width - 96, dev.height - 108, 50, 50 };
    if (sys_os() >= 26) { sys_glass(c, bl.x, bl.y, 50, 50, 25, NULL, 1 | 2); sys_glass(c, br.x, br.y, 50, 50, 25, NULL, 1 | 2); }
    else {
        cairo_new_path(c);
        cairo_set_source_rgba(c, 0, 0, 0, 0.32); cairo_arc(c, bl.x + 25, bl.y + 25, 25, 0, 2 * M_PI); cairo_fill(c);
        cairo_arc(c, br.x + 25, br.y + 25, 25, 0, 2 * M_PI); cairo_fill(c);
    }
    sys_symbol(c, "flashlight.off.fill", bl.x + 25, bl.y + 25, 20, 1, 1, 1);
    sys_symbol(c, "camera.fill", br.x + 25, br.y + 25, 20, 1, 1, 1);
}


/* ---- Live Activities: drawn on the lock screen and around the Dynamic Island (images rendered by the app's widget
   extension; the home screen sends "la-show APP DIR" with lock.png, leading.png, trailing.png, minimal.png, expanded.png) ---- */
static struct { int on, expanded; char app[512]; cairo_surface_t *lock, *leading, *trailing, *minimal, *exp; } la;
static cairo_surface_t *la_png(const char *dir, const char *name) {
    char p[1100]; snprintf(p, sizeof p, "%s/%s.png", dir, name);
    cairo_surface_t *s = cairo_image_surface_create_from_png(p);
    if (cairo_surface_status(s) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(s); return NULL; }
    return s;
}
static void la_clear(void) {
    cairo_surface_t **ss[5] = { &la.lock, &la.leading, &la.trailing, &la.minimal, &la.exp };
    for (int i = 0; i < 5; i++) if (*ss[i]) { cairo_surface_destroy(*ss[i]); *ss[i] = NULL; }
    la.on = la.expanded = 0;
}
static void la_set(const char *app, const char *dir) {
    la_clear();
    snprintf(la.app, sizeof la.app, "%s", app);
    la.lock = la_png(dir, "lock"); la.leading = la_png(dir, "leading"); la.trailing = la_png(dir, "trailing");
    la.minimal = la_png(dir, "minimal"); la.exp = la_png(dir, "expanded");
    la.on = la.lock != NULL;
    fprintf(stderr, "isim shell: Live Activity from %s %s\n", app, la.on ? "shown" : "(no images)");
}
static int la_island_visible(void) {
    if (!la.on || dev.has_island != 1 || locked || ov != OV_NONE || anim.kind != ANIM_NONE) return 0;
    return la.expanded || active != shell_find(la.app);           /* compact while the app is not in the foreground */
}
static struct rectf la_compact_rect(void) { return (struct rectf){ dev.width / 2 - 62.5 - 64, 11, 125 + 128, 37 }; }
static struct rectf la_expanded_rect(void) { return (struct rectf){ 8, 8, dev.width - 16, 176 }; }
static void la_img(cairo_t *c, cairo_surface_t *s, double x, double y, double w, double h) {
    if (!s) return;
    double iw = cairo_image_surface_get_width(s), ih = cairo_image_surface_get_height(s);
    cairo_save(c); cairo_translate(c, x, y); cairo_scale(c, w / iw, h / ih);
    cairo_set_source_surface(c, s, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
    cairo_restore(c);
}
static void la_draw_island(cairo_t *c) {
    if (la.expanded) {
        struct rectf r = la_expanded_rect();
        sys_round(c, r.x, r.y, r.w, r.h, 44); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        double w = fmin(370, r.w - 8);
        la_img(c, la.exp, r.x + (r.w - w) / 2, r.y + 10, w, w * 160 / 370);
        el_add("dynamic-island", "expanded", r, EL_NONE, 1);
    } else {
        struct rectf r = la_compact_rect();
        sys_round(c, r.x, r.y, r.w, r.h, 18.5); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        la_img(c, la.leading, r.x + 2, r.y, 64, 37);
        la_img(c, la.trailing, r.x + r.w - 66, r.y, 64, 37);
        el_add("dynamic-island", "compact", r, EL_NONE, 1);
    }
}
static double la_draw_lock(cairo_t *c, double top) {           /* returns the height used */
    if (!la.on || !la.lock) return 0;
    double w = fmin(dev.width - 16, 400), x = (dev.width - w) / 2, h = w * 160 / 370;
    cairo_save(c);
    sys_round(c, x, top, w, h, 22); cairo_clip_preserve(c);
    cairo_set_source_rgba(c, 0.95, 0.95, 0.97, 0.88); cairo_fill(c);
    la_img(c, la.lock, x, top, w, h);
    cairo_restore(c);
    el_add("live-activity", "Live Activity", (struct rectf){ x, top, w, h }, EL_NONE, 0);
    return h + 10;
}

/* ---- widget extension helpers (WidgetKit): short-lived processes the home screen asks for ---- */
static struct { pid_t pid; char req[512]; } helpers[16];
static void sys_run_helper(const char *exe, const char *req) {
    int slot = -1;
    for (int i = 0; i < 16; i++) if (!helpers[i].pid) { slot = i; break; }
    if (slot < 0) { fprintf(stderr, "isim shell: too many widget extension processes\n"); return; }
    pid_t pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        for (int fd = 3; fd < 256; fd++) close(fd);
        unsetenv("ISIM_CLIENT_SOCK"); unsetenv("ISIM_CLIENT_SURFACE"); unsetenv("ISIM_SCRIPT"); unsetenv("ISIM_CONTROL");
        unsetenv("ISIM_LAUNCH_URL"); unsetenv("ISIM_LAUNCH_BACKGROUND");
        setenv("ISIM_HEADLESS", "1", 1); setenv("ISIM_WIDGET_REQUEST", req, 1); setenv("ISIM_MUTE", "1", 1);
        execl(shell_self, shell_self, "--root", shell_root, exe, (char *)NULL);
        _exit(127);
    }
    helpers[slot].pid = pid; snprintf(helpers[slot].req, sizeof helpers[slot].req, "%s", req);
}
static void sys_reaped(pid_t pid, int status) {
    for (int i = 0; i < 16; i++) if (helpers[i].pid == pid) {
        helpers[i].pid = 0;
        sys_send_text(0, "widget-done %d %s", WIFEXITED(status) ? WEXITSTATUS(status) : 128, helpers[i].req);
    }
}

static void sys_draw(void) {
    if (!comp) comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, surf_w, surf_h);
    nels = 0;
    cairo_t *c = cairo_create(comp);
    cairo_set_source_rgb(c, 0, 0, 0); cairo_paint(c);
    int base = active >= 0 && clients[active].alive ? active : 0;
    int bw, bh; client_dims(base, &bw, &bh);
    cairo_surface_t *bs = client_surface(base);
    cairo_surface_t *home = client_surface(0); int hw, hh; client_dims(0, &hw, &hh);
    double slide = fmin(1, (now() - ov_t0) / 0.28), e = 1 - pow(1 - slide, 3);
    if (ov == OV_NONE) {                                              /* the app, with the Dynamic Island over it */
        cairo_save(c); cairo_identity_matrix(c);
        cairo_scale(c, (double)surf_w / bw, (double)surf_h / bh);
        cairo_set_source_surface(c, bs, 0, 0); cairo_paint(c);
        cairo_restore(c);
        cairo_scale(c, px_scale, px_scale);
        la_draw_island(c);
    } else if (ov == OV_LOCK) {
        cairo_scale(c, px_scale, px_scale);
        lock_draw(c, home, hw, hh);
    } else if (ov == OV_SWITCHER) {
        sys_paint_blurred(c, home, hw, hh, 0.35);
        cairo_scale(c, px_scale, px_scale);
        el_add("switcher-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_BG, 0);
        if (!sw_n) sys_text(c, "No Recent Apps", 0, dev.height / 2 - 12, dev.width, 17, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.8);
        for (int k = sw_n - 1; k >= 0; k--) {
            int i = sw_order[k]; double rad;
            struct rectf r = sw_card_rect(k, &rad);
            r.y += sw_kill_dy[i];
            if (r.x > dev.width + 20 || r.x + r.w < -dev.width) continue;
            cairo_save(c);
            sys_round(c, r.x, r.y, r.w, r.h, rad);
            cairo_set_source_rgba(c, 0, 0, 0, 0.35); cairo_set_line_width(c, 6); cairo_stroke_preserve(c);
            cairo_clip(c);
            int aw, ah; client_dims(i, &aw, &ah);
            cairo_surface_t *as = client_surface(i);
            cairo_translate(c, r.x, r.y); cairo_scale(c, r.w / aw, r.h / ah);
            cairo_set_source_surface(c, as, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
            cairo_surface_destroy(as);
            cairo_restore(c);
            struct sys_appinfo *ai = sys_info(clients[i].bundle);
            sys_icon(c, ai ? ai->icon : NULL, r.x + 4, r.y - 38, 30);
            sys_text(c, app_label(i), r.x + 42, r.y - 31, r.w - 46, 14, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
            char sid[64], id[96]; app_short_id(i, sid, sizeof sid); snprintf(id, sizeof id, "switcher-%s", sid);
            el_add(id, app_label(i), r, EL_CARD, i);
        }
    } else {                                                            /* Notification Center / Control Center over the screen */
        cairo_save(c); cairo_identity_matrix(c);
        cairo_scale(c, (double)surf_w / bw, (double)surf_h / bh);
        cairo_set_source_surface(c, bs, 0, 0); cairo_paint(c);
        cairo_restore(c);
        cairo_push_group(c);
        if (ov == OV_CC) sys_paint_blurred(c, bs, bw, bh, sys_os() >= 26 ? 0.22 : 0.4);   /* iOS 26: lighter dimming */
        cairo_scale(c, px_scale, px_scale);
        if (ov == OV_NC) { wallpaper_draw(c, home, hw, hh); cairo_set_source_rgba(c, 0, 0, 0, 0.15); cairo_paint(c); }
        cairo_translate(c, 0, -dev.height * (1 - e) * (ov == OV_NC ? 1 : 0.15));
        el_add(ov == OV_NC ? "nc-background" : "cc-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_BG, 0);
        if (ov == OV_NC) {
            char t[16], dstr[64]; sys_time_strings(t, sizeof t, dstr, sizeof dstr);
            double top = fmax(dev.safe_top, 20);
            sys_text(c, dstr, 0, top + 10, dev.width, 18, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.9);
            sys_text(c, t, 0, top + 30, dev.width, 76, PANGO_WEIGHT_BOLD, 1, 1, 1, 1, 1, 0.95);
            nc_draw_list(c, top + 140, 0);
        } else cc_draw(c);
        cairo_pop_group_to_source(c);
        cairo_paint_with_alpha(c, ov == OV_CC ? e : 1);
    }
    cairo_surface_destroy(bs); cairo_surface_destroy(home);
    if (cc_brightness < 0.999) { cairo_identity_matrix(c); cairo_set_source_rgba(c, 0, 0, 0, (1 - cc_brightness) * 0.7); cairo_paint(c); }
    cairo_destroy(c);
    present_comp();
}

/* ---- opening / closing ---- */
static void sys_open(int which) {
    if (anim.kind != ANIM_NONE) anim.kind = ANIM_NONE;
    if (win_orient != 1) shell_apply_orient(1);
    ov = which; ov_t0 = now();
    if (which == OV_SWITCHER) {
        sw_collect(); sw_scroll = 0; memset(sw_kill_dy, 0, sizeof sw_kill_dy);
        if (active > 0) shell_send(active, EV_BACKGROUND);
        fprintf(stderr, "isim shell: app switcher (%d app%s)\n", sw_n, sw_n == 1 ? "" : "s");
    } else if (which == OV_NC) fprintf(stderr, "isim shell: Notification Center (%d notification%s)\n", nnc, nnc == 1 ? "" : "s");
    else if (which == OV_CC) fprintf(stderr, "isim shell: Control Center (iOS %d look)\n", sys_os());
    sys_draw();
}
static void sys_close(void) {
    int was = ov; ov = OV_NONE;
    if (was == OV_SWITCHER) {                      /* back to the home screen */
        int app = active; active = 0;
        if (app > 0 && clients[app].alive) shell_send(app, EV_BACKGROUND);
        shell_send(0, EV_FOREGROUND);
    }
    shell_show(active >= 0 ? active : 0);
}
static void sys_lock(void) {
    if (locked) return;
    locked = 1; ov = OV_LOCK; ov_t0 = now(); nb.on = 0;
    if (active >= 0) shell_send(active, EV_BACKGROUND);       /* like iOS: the foreground app resigns and goes to the background */
    fprintf(stderr, "isim shell: locked (iOS %d look)\n", sys_os());
    if (win_orient != 1) shell_apply_orient(1);
    sys_draw();
}
static void sys_unlock(void) {
    if (!locked) return;
    locked = 0; ov = OV_NONE;
    fprintf(stderr, "isim shell: unlocked\n");
    if (active >= 0) shell_send(active, EV_FOREGROUND);
    shell_show(active >= 0 ? active : 0);
}
/* open an app from the switcher (zooming from its card) */
static void sw_activate(int i, struct rectf from, double radius) {
    ov = OV_NONE;
    fprintf(stderr, "isim shell: switched to %s\n", clients[i].bundle);
    if (active >= 0 && active != i) shell_send(active, EV_BACKGROUND);
    active = i;
    shell_send(i, EV_FOREGROUND);
    start_anim(ANIM_OPEN, i, from, full_rect(), radius, dev.corner_radius, 0.35);
}
static void sw_kill(int i) {
    fprintf(stderr, "isim shell: closed %s from the app switcher\n", clients[i].bundle);
    clients[i].sysquit = 1;
    sys_send_text(i, "discard-scenes");
    shell_send(i, EV_QUIT);
    if (i == active) active = 0;
    for (int k = 0; k < sw_n; k++) if (sw_order[k] == i) { memmove(&sw_order[k], &sw_order[k + 1], (sw_n - k - 1) * sizeof *sw_order); sw_n--; break; }
    double w = dev.width * (dev.width >= 700 ? 0.42 : 0.62) * 0.72;
    if (sw_scroll > (sw_n - 1) * w) sw_scroll = fmax(0, (sw_n - 1) * w);
    sys_draw();
}
/* open a notification from Notification Center / the lock screen: the app gets the response, like a banner tap */
static void nc_open(int idx) {
    if (idx < 0 || idx >= nnc) return;
    struct nc_item n = ncl[idx];
    memmove(&ncl[idx], &ncl[idx + 1], (nnc - idx - 1) * sizeof *ncl); nnc--;
    int i = shell_find(n.path);
    fprintf(stderr, "isim shell: opened notification %s from %s\n", n.id, locked ? "the lock screen" : "Notification Center");
    if (locked) { locked = 0; fprintf(stderr, "isim shell: unlocked\n"); }
    ov = OV_NONE;
    if (i < 0) { shell_show(active); return; }
    if (active != i) { if (active >= 0) shell_send(active, EV_BACKGROUND); active = i; }
    shell_send(i, EV_FOREGROUND);
    struct isim_event e = { .type = EV_NOTIFICATION_RESPONSE }; snprintf(e.text, sizeof e.text, "%s", n.id);
    shell_forward(i, &e);
    double r0; struct rectf from = icon_target(i, &r0);
    start_anim(ANIM_OPEN, i, from, full_rect(), r0, dev.corner_radius, 0.45);
}
static void cc_set_network(void) {
    const char *d = getenv("ISIM_DATA"); if (!d || !*d) return;
    char p[1024]; snprintf(p, sizeof p, "%s/Library", d); mkdir(p, 0755);
    snprintf(p, sizeof p, "%s/Library/isim", d); mkdir(p, 0755);
    snprintf(p, sizeof p, "%s/Library/isim/NetworkOffline", d);
    int off = cc_on[CC_AIRPLANE] || !cc_on[CC_WIFI];
    if (off) { FILE *f = fopen(p, "w"); if (f) fclose(f); } else unlink(p);
    fprintf(stderr, "isim shell: network %s\n", off ? "offline (Control Center)" : "online");
}
static void cc_toggle(int k) {
    cc_on[k] = !cc_on[k];
    fprintf(stderr, "isim shell: Control Center %s %s\n", cc_names[k], cc_on[k] ? "on" : "off");
    if (k == CC_AIRPLANE) { if (cc_on[k]) cc_on[CC_CELLULAR] = cc_on[CC_WIFI] = cc_on[CC_BLUETOOTH] = 0; else cc_on[CC_CELLULAR] = cc_on[CC_WIFI] = cc_on[CC_BLUETOOTH] = 1; cc_set_network(); }
    if (k == CC_WIFI) cc_set_network();
    if (k == CC_DARK) sys_send_text(0, "set-appearance %s", cc_on[k] ? "dark" : "light");     /* the home screen saves the setting */
    if (k == CC_CAMERA) cc_on[k] = 0;
    sys_draw();
}

static struct sys_el *el_at(double x, double y) {
    for (int k = nels - 1; k >= 0; k--) { struct rectf r = els[k].r; if (x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) return &els[k]; }
    return NULL;
}
static struct sys_el *el_named(const char *id) {
    for (int k = nels - 1; k >= 0; k--) if (!strcmp(els[k].id, id)) return &els[k];
    return NULL;
}
static void el_tap(struct sys_el *e, double y) {
    if (!e) return;
    switch (e->kind) {
    case EL_CARD: {
        double rad; int k = 0; for (; k < sw_n && sw_order[k] != e->arg; k++) {}
        struct rectf r = sw_card_rect(k, &rad);
        sw_activate(e->arg, r, rad); break; }
    case EL_NC_ITEM: nc_open(e->arg); break;
    case EL_NC_CLEAR: fprintf(stderr, "isim shell: cleared %d notification(s)\n", nnc); nnc = 0; sys_draw(); break;
    case EL_CC_TOGGLE: cc_toggle(e->arg); break;
    case EL_CC_SLIDER: {
        double v = fmin(1, fmax(0, 1 - (y - e->r.y) / e->r.h));
        if (e->arg == 0) cc_brightness = fmax(0.05, v); else cc_volume = v;
        fprintf(stderr, "isim shell: Control Center %s %d%%\n", e->arg ? "volume" : "brightness", (int)lround(v * 100));
        sys_draw(); break; }
    case EL_BG: if (ov == OV_LOCK) break; sys_close(); break;
    default: break;
    }
}
static void sys_dump(void) {
    static const char *const names[] = { "", "IsimAppSwitcher", "IsimLockScreen", "IsimNotificationCenter", "IsimControlCenter" };
    fprintf(stderr, "%s (0 0; %g x %g)\n", names[ov], dev.width, dev.height);
    for (int k = 0; k < nels; k++)
        fprintf(stderr, "  %s (%g %g; %g x %g) id=%s%s%s\n", els[k].kind == EL_CARD ? "IsimAppCard" : els[k].kind == EL_NC_ITEM ? "IsimNotification" :
                els[k].kind == EL_CC_TOGGLE ? "IsimControlButton" : els[k].kind == EL_CC_SLIDER ? "IsimControlSlider" : "IsimSystemView",
                els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text[0] ? " text=" : "", els[k].text);
}

/* input while an overlay is up, and the gestures / keys that open them. Returns 1 when the event was the system's. */
static struct { int on, sys; double x0, y0, t0; } top_drag;     /* a touch that started at the top edge */
static double last_home_key;
static int sys_input(const struct isim_event *ev) {
    if (ev->type == EV_KEY && (ev->mods & SDL_KMOD_CTRL) && !(ev->mods & SDL_KMOD_SHIFT) && (ev->key == 'l' || ev->key == 'L')) {
        if (locked) sys_unlock(); else sys_lock(); return 1;
    }
    if (ev->type == EV_KEY && (ev->mods & SDL_KMOD_CTRL) && (ev->mods & SDL_KMOD_SHIFT) && (ev->key == 'h' || ev->key == 'H')) {
        if (locked) { sys_unlock(); return 1; }
        if (now() - last_home_key < 0.6) { last_home_key = 0; sys_open(OV_SWITCHER); return 1; }    /* twice: app switcher (Simulator) */
        last_home_key = now();
        if (ov != OV_NONE) { sys_close(); return 1; }
        return 0;
    }
    if (ev->type == EV_DEVICE_ORIENTATION && cc_on[CC_ORIENT]) { device_orient = 1; fprintf(stderr, "isim shell: rotation ignored (orientation lock)\n"); return 1; }
    if (ov == OV_NONE && la_island_visible()) {                 /* the Dynamic Island: tap expands / collapses */
        struct rectf r = la.expanded ? la_expanded_rect() : la_compact_rect();
        if ((ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) && !strcmp(ev->text, "dynamic-island")) {
            if (ev->type == EV_ID_UP) { la.expanded = !la.expanded; fprintf(stderr, "isim shell: Dynamic Island %s\n", la.expanded ? "expanded" : "compact"); shell_show(active); }
            return 1;
        }
        if (ev->type == EV_DUMP) {
            fprintf(stderr, "IsimDynamicIsland (%g %g; %g x %g) id=dynamic-island text=%s\n", r.x, r.y, r.w, r.h, la.expanded ? "expanded" : "compact");
            return 0;
        }
        int inside = ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h;
        if (ev->type == EV_TOUCH_DOWN && (inside || la.expanded)) { top_drag.on = 0; return 1; }
        if (ev->type == EV_TOUCH_UP && (inside || la.expanded)) { la.expanded = inside ? !la.expanded : 0; shell_show(active); return 1; }
        if (ev->type == EV_TOUCH_MOVE && la.expanded) return 1;
    }
    if (ov == OV_NONE) {
        /* pull down from the top edge: Notification Center (left / middle) or Control Center (right corner) */
        if (ev->type == EV_TOUCH_DOWN && ev->y < 24 && active >= 0) { top_drag.on = 1; top_drag.sys = 0; top_drag.x0 = ev->x; top_drag.y0 = ev->y; top_drag.t0 = now(); return 1; }
        if (top_drag.on && ev->type == EV_TOUCH_MOVE) {
            if (!top_drag.sys && ev->y - top_drag.y0 > 30) { top_drag.sys = 1; sys_open(top_drag.x0 > dev.width * 0.62 ? OV_CC : OV_NC); }
            return 1;
        }
        if (top_drag.on && ev->type == EV_TOUCH_UP) {
            top_drag.on = 0;
            if (!top_drag.sys) {                         /* a tap on the status bar: the app's */
                struct isim_event d = { .type = EV_TOUCH_DOWN, .x = top_drag.x0, .y = top_drag.y0, .timestamp = ev->timestamp };
                shell_forward(active, &d); shell_forward(active, ev);
            }
            return 1;
        }
        return 0;
    }
    if (ev->type == EV_DUMP) { sys_dump(); return 1; }
    if (ev->type == EV_KEY && ev->key == 27 && ov != OV_LOCK) { sys_close(); return 1; }
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no system element '%s'\n", ev->text); return 1; }
        if (ev->type == EV_ID_DOWN && ev->mods == 1) {                 /* swipeid ID dx dy s */
            if (e->kind == EL_CARD && ev->y < -50) sw_kill(e->arg);
            else if (e->kind == EL_CARD && fabs(ev->x) > 20) { sw_scroll = fmax(0, sw_scroll + ev->x); sys_draw(); }
            else if (e->kind == EL_BG && ev->y < -50) { if (ov == OV_LOCK) sys_unlock(); else sys_close(); }
            return 1;
        }
        if (ev->type == EV_ID_UP) el_tap(e, e->r.y + e->r.h / 2);
        return 1;
    }
    if (ev->type == EV_TOUCH_DOWN) {
        sw_drag.on = 1; sw_drag.x0 = sw_drag.x = ev->x; sw_drag.y0 = sw_drag.y = ev->y; sw_drag.scroll0 = sw_scroll; sw_drag.t0 = now();
        struct sys_el *e = el_at(ev->x, ev->y); sw_drag.card = e && e->kind == EL_CARD ? e->arg : -1;
        return 1;
    }
    if (ev->type == EV_TOUCH_MOVE && sw_drag.on) {
        sw_drag.x = ev->x; sw_drag.y = ev->y;
        double dx = ev->x - sw_drag.x0, dy = ev->y - sw_drag.y0;
        if (ov == OV_SWITCHER) {
            if (sw_drag.card >= 0 && dy < -10 && fabs(dy) > fabs(dx)) sw_kill_dy[sw_drag.card] = fmin(0, dy);
            else sw_scroll = fmax(0, sw_drag.scroll0 + dx);
            sys_draw();
        } else if (ov == OV_CC) {
            struct sys_el *e = el_at(sw_drag.x0, sw_drag.y0);
            if (e && e->kind == EL_CC_SLIDER) el_tap(e, ev->y);
        }
        return 1;
    }
    if (ev->type == EV_TOUCH_UP && sw_drag.on) {
        sw_drag.on = 0;
        double dx = ev->x - sw_drag.x0, dy = ev->y - sw_drag.y0;
        int moved = fabs(dx) > 8 || fabs(dy) > 8;
        if (ov == OV_SWITCHER && sw_drag.card >= 0 && sw_kill_dy[sw_drag.card] < -70) { sw_kill(sw_drag.card); return 1; }
        if (ov == OV_SWITCHER && sw_drag.card >= 0) sw_kill_dy[sw_drag.card] = 0;
        if (ov == OV_LOCK && sw_drag.y0 > dev.height - 120 && dy < -80) { sys_unlock(); return 1; }
        if ((ov == OV_NC || ov == OV_CC) && dy < -60) { sys_close(); return 1; }
        if (!moved) el_tap(el_at(ev->x, ev->y), ev->y);
        else if (ov == OV_SWITCHER) sys_draw();
        return 1;
    }
    return ov != OV_NONE;
}
/* per loop iteration: slide-in animation, lock clock, switcher bookkeeping */
static void sys_tick(void) {
    if (active != seen_active) { seen_active = active; if (active > 0) last_active_t[active] = now(); }
    if (ov == OV_NONE) return;
    static double last_draw;
    double t = now();
    if (t - ov_t0 < 0.32 || t - last_draw > 1.0) { last_draw = t; if (anim.kind == ANIM_NONE) sys_draw(); }
}

static void sys_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (!strcmp(verb, "appinfo")) {
        struct sys_appinfo *ai = sys_info(m->b);
        if (!ai) { if (nappinfo >= 128) return; ai = &appinfo[nappinfo++]; snprintf(ai->path, sizeof ai->path, "%s", m->b); }
        const char *sep = strchr(m->c, '\x1f');
        snprintf(ai->name, sizeof ai->name, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        snprintf(ai->icon, sizeof ai->icon, "%s", sep ? sep + 1 : "");
    } else if (!strcmp(verb, "notified")) {                 /* delivered while the app was in the foreground */
        const char *s1 = strchr(m->b, '\x1f'), *s2 = strchr(m->c, '\x1f');
        char id[256], title[256]; snprintf(id, sizeof id, "%.*s", s1 ? (int)(s1 - m->b) : (int)strlen(m->b), m->b);
        snprintf(title, sizeof title, "%.*s", s2 ? (int)(s2 - m->c) : (int)strlen(m->c), m->c);
        nc_add(clients[from].bundle, id, s1 ? s1 + 1 : "", title, s2 ? s2 + 1 : "");
        if (ov != OV_NONE) sys_draw();
    } else if (!strcmp(verb, "nc-remove")) {                /* removeDeliveredNotifications: c = ids (empty: all) */
        for (int k = nnc - 1; k >= 0; k--) {
            if (strcmp(ncl[k].path, clients[from].bundle)) continue;
            int match = !m->c[0];
            for (const char *p = m->c; *p && !match; ) { size_t l = strcspn(p, "\x1f"); if (l == strlen(ncl[k].id) && !strncmp(p, ncl[k].id, l)) match = 1; p += l; if (*p) p++; }
            if (match) { memmove(&ncl[k], &ncl[k + 1], (nnc - k - 1) * sizeof *ncl); nnc--; }
        }
        if (ov != OV_NONE) sys_draw();
    } else if (!strcmp(verb, "widget-run")) {               /* the home screen runs a widget extension */
        sys_run_helper(m->b, m->c);
    } else if (!strcmp(verb, "widget-reload")) {            /* WidgetCenter.reloadTimelines(ofKind:) */
        sys_send_text(0, "widget-reload %s", m->c);
    } else if (!strcmp(verb, "live-activity")) {            /* ActivityKit: the home screen renders it */
        sys_send_text(0, "live-activity %s %s", m->b, m->c);
    } else if (!strcmp(verb, "la-show")) {
        la_set(m->b, m->c);
        shell_show(active >= 0 ? active : 0);
    } else if (!strcmp(verb, "la-hide")) {
        if (!strcmp(la.app, m->b)) { la_clear(); fprintf(stderr, "isim shell: Live Activity ended\n"); shell_show(active >= 0 ? active : 0); }
    } else if (!strcmp(verb, "openurl")) {
        sys_send_text(0, "openurl %s", m->c);
    } else if (!strcmp(verb, "reload-home")) {
        sys_send_text(0, "reload");
    } else if (!strcmp(verb, "launch-bg")) {
        const char *sep = strchr(m->c, '\x1f');
        char exe[512]; snprintf(exe, sizeof exe, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        sys_launch_background(m->b, exe, sep ? sep + 1 : NULL);
    } else fprintf(stderr, "isim shell: unknown system request '%s' from %s\n", verb, clients[from].bundle);
}

/* script commands for the system (EV_SHELL_CMD); returns 1 when handled */
static int sys_command(const char *text) {
    char verb[32] = {0}; int n = 0;
    sscanf(text, "%31s%n", verb, &n);
    const char *args = text + n; while (*args == ' ') args++;
    if (!strcmp(verb, "bgtask")) { sys_send_text(0, "launchtask %s", args); return 1; }  /* the home screen resolves the bundle id */
    if (!strcmp(verb, "openurl")) { sys_send_text(0, "openurl %s", args); return 1; }
    if (!strcmp(verb, "lock")) { sys_lock(); return 1; }
    if (!strcmp(verb, "unlock")) { sys_unlock(); return 1; }
    if (!strcmp(verb, "switcher")) { if (!locked) sys_open(OV_SWITCHER); return 1; }
    if (!strcmp(verb, "notifications")) { if (!locked) sys_open(OV_NC); return 1; }
    if (!strcmp(verb, "controlcenter")) { if (!locked) sys_open(OV_CC); return 1; }
    if (!strcmp(verb, "island")) {
        if (la.on) { la.expanded = !la.expanded; fprintf(stderr, "isim shell: Dynamic Island %s\n", la.expanded ? "expanded" : "compact"); shell_show(active); }
        else fprintf(stderr, "isim shell: no Live Activity\n");
        return 1;
    }
    if (!strcmp(verb, "homepage")) { if (!locked && active == 0) sys_send_text(0, "homepage %s", args); return 1; }
    if (!strcmp(verb, "spotlight")) { if (!locked && active == 0) sys_send_text(0, "spotlight"); return 1; }
    fprintf(stderr, "isim shell: '%s' is not available\n", verb);
    return 1;
}

/* a notification delivered to a background app: Notification Center / lock screen list, and a banner unless hidden */
static void sys_notify(int i, const struct shell_msg *m) {
    const char *sep = strchr(m->a, '\x1f');
    char id[256]; snprintf(id, sizeof id, "%.*s", sep ? (int)(sep - m->a) : (int)strlen(m->a), m->a);
    nc_add(clients[i].bundle, id, sep ? sep + 1 : "", m->b, m->c);
    if (sys_hides_banners()) {
        fprintf(stderr, "isim shell: notification from %s listed%s: %s\n", clients[i].bundle, locked ? " on the lock screen" : "", m->b);
        if (ov != OV_NONE) sys_draw();
        return;
    }
    nb_post(i, m);
}
