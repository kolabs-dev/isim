/* isim shell system UI drawn over the apps: the Lock Screen and Control Center, in the look of the emulated iOS
 * version (isim --os). Included by shell.inc.
 *
 *   iOS 17     Lock Screen: bold white clock over the wallpaper, dark round flashlight/camera buttons.
 *              Control Center: one page of dark translucent rounded-square modules.
 *   iOS 18     Control Center redesign: rounder modules and circular toggles, the "+" (edit) and power buttons at
 *              the top, and the page column on the right (favorites, music, home, connectivity).
 *   iOS 26/27  Liquid Glass: the Lock Screen clock is tall glass numerals, buttons and Control Center modules are
 *              clear glass platters (lighter dimming, less blur).
 *
 * Adapted: what is drawn is isim's own approximation (no Apple artwork; symbols come from the host's symbol set),
 * the controls are not interactive (tap anywhere closes Control Center; a swipe up or tap unlocks).
 * Script: `lock`, `unlock`, `controlcenter` (open), `controlcenter off`. Window: Ctrl+L locks/unlocks, a swipe
 * down from the top-right corner opens Control Center. */

static struct { int lock, cc; double t0; } sysui;
static cairo_surface_t *sysui_wallpaper;
static int sysui_visible(void) { return (sysui.lock || sysui.cc) && anim.kind == ANIM_NONE; }

static void sysui_text(cairo_t *c, const char *utf8, double x, double y, double w, double size, int weight, double rgba[4], int center) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, SYSTEM_SANS);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, (PangoWeight)weight);
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
    pango_layout_set_text(l, utf8, -1);
    pango_layout_set_width(l, (int)(w * PANGO_SCALE));
    if (center) pango_layout_set_alignment(l, PANGO_ALIGN_CENTER);
    cairo_set_source_rgba(c, rgba[0], rgba[1], rgba[2], rgba[3]);
    cairo_move_to(c, x, y); pango_cairo_show_layout(c, l);
    g_object_unref(l);
}
/* the clock's glyph outlines (for the iOS 26 glass numerals) */
static void sysui_text_path(cairo_t *c, const char *utf8, double x, double y, double w, double size, int weight) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, SYSTEM_SANS);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, (PangoWeight)weight);
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
    pango_layout_set_text(l, utf8, -1);
    pango_layout_set_width(l, (int)(w * PANGO_SCALE)); pango_layout_set_alignment(l, PANGO_ALIGN_CENTER);
    cairo_move_to(c, x, y); pango_cairo_layout_path(c, l);
    g_object_unref(l);
}
static void sysui_rrect(cairo_t *c, double x, double y, double w, double h, double r) {
    r = fmin(r, fmin(w, h) / 2);
    cairo_new_sub_path(c);
    cairo_arc(c, x + w - r, y + r, r, -M_PI / 2, 0); cairo_arc(c, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(c, x + r, y + h - r, r, M_PI / 2, M_PI); cairo_arc(c, x + r, y + r, r, M_PI, 1.5 * M_PI);
    cairo_close_path(c);
}
/* a symbol from the host's symbol set, tinted (drawn through the global cairo context) */
static void sysui_symbol(cairo_t *c, const char *name, double cx, double cy, double size, const double tint[4]) {
    double w = 0, h = 0; int hd = isim_image_symbol(name, &w, &h);
    if (hd <= 0 || w <= 0 || h <= 0) return;
    double k = size / fmax(w, h);
    cairo_t *saved = cr; cr = c;
    isim_image_draw(hd, cx - w * k / 2, cy - h * k / 2, w * k, h * k, tint, 1);
    cr = saved;
}
static void sysui_glass(cairo_t *c, double x, double y, double w, double h, double r, const double *tint, int flags) {
    cairo_t *saved = cr; cr = c;
    isim_gfx_glass(x, y, w, h, r, tint, flags);
    cr = saved;
}
static void sysui_blur(cairo_t *c, double x, double y, double w, double h, double r, double radius) {
    cairo_t *saved = cr; cr = c;
    isim_gfx_backdrop_blur(x, y, w, h, r, radius);
    cr = saved;
}

/* ---- Lock Screen ---- */
static void sysui_draw_lock(cairo_t *c, int os) {
    double W = dev.width, H = dev.height;
    if (!sysui_wallpaper) {
        char p[1200]; snprintf(p, sizeof p, "%s/Applications/SpringBoard.app/wallpaper.png", shell_root ? shell_root : "");
        sysui_wallpaper = cairo_image_surface_create_from_png(p);
    }
    if (sysui_wallpaper && cairo_surface_status(sysui_wallpaper) == CAIRO_STATUS_SUCCESS && cairo_image_surface_get_width(sysui_wallpaper) > 0) {
        double iw = cairo_image_surface_get_width(sysui_wallpaper), ih = cairo_image_surface_get_height(sysui_wallpaper);
        double k = fmax(W / iw, H / ih);
        cairo_save(c); cairo_translate(c, (W - iw * k) / 2, (H - ih * k) / 2); cairo_scale(c, k, k);
        cairo_set_source_surface(c, sysui_wallpaper, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
        cairo_restore(c);
    } else { cairo_set_source_rgb(c, 0.16, 0.2, 0.42); cairo_paint(c); }
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    const char *fixed = getenv("ISIM_LOCK_TIME");                    /* tests: a fixed "H:MM" */
    char hm[16], date[64];
    if (fixed && *fixed) snprintf(hm, sizeof hm, "%s", fixed); else strftime(hm, sizeof hm, "%-H:%M", &tm);
    strftime(date, sizeof date, "%A, %B %-d", &tm);
    double white[4] = { 1, 1, 1, 0.92 };
    double top = fmax(dev.safe_top, 20);
    if (os >= 26) {
        /* iOS 26: the date above tall glass numerals (glass body, bright rim, soft shadow) */
        sysui_text(c, date, 0, top + 18, W, 19, PANGO_WEIGHT_SEMIBOLD, white, 1);
        double size = W * 0.42;
        cairo_save(c);
        sysui_text_path(c, hm, 0, top + 34, W, size, PANGO_WEIGHT_HEAVY);
        cairo_path_t *glyphs = cairo_copy_path(c);
        cairo_new_path(c);
        cairo_save(c); cairo_translate(c, 0, 3); cairo_append_path(c, glyphs); cairo_set_source_rgba(c, 0, 0, 0, 0.18); cairo_fill(c); cairo_restore(c);
        cairo_append_path(c, glyphs); cairo_clip_preserve(c);
        cairo_pattern_t *g = cairo_pattern_create_linear(0, top + 34, 0, top + 34 + size * 1.1);
        cairo_pattern_add_color_stop_rgba(g, 0, 1, 1, 1, 0.62); cairo_pattern_add_color_stop_rgba(g, 1, 1, 1, 1, 0.30);
        cairo_set_source(c, g); cairo_paint(c); cairo_pattern_destroy(g);
        cairo_reset_clip(c);
        /* the rim: a stroke outside the glyphs only (overlapping glyph contours stay inside the fill) */
        cairo_push_group(c);
        cairo_new_path(c); cairo_append_path(c, glyphs);
        cairo_set_line_width(c, 3.2); cairo_set_source_rgba(c, 1, 1, 1, 0.9); cairo_stroke(c);
        cairo_set_operator(c, CAIRO_OPERATOR_DEST_OUT);
        cairo_append_path(c, glyphs); cairo_set_source_rgba(c, 0, 0, 0, 1); cairo_fill(c);
        cairo_pop_group_to_source(c); cairo_paint(c);
        cairo_path_destroy(glyphs);
        cairo_restore(c);
    } else {
        /* iOS 17/18: the date, then the bold clock */
        sysui_text(c, date, 0, top + 22, W, 20, PANGO_WEIGHT_SEMIBOLD, white, 1);
        double solid[4] = { 1, 1, 1, 0.95 };
        sysui_text(c, hm, 0, top + 40, W, 92, PANGO_WEIGHT_BOLD, solid, 1);
    }
    /* flashlight and camera */
    double by = H - fmax(dev.safe_bottom, 20) - 62, bs = 50;
    double xs[2] = { 46, W - 46 - bs }; const char *names[2] = { "lightbulb", "camera.fill" };
    for (int i = 0; i < 2; i++) {
        if (os >= 26) sysui_glass(c, xs[i], by, bs, bs, bs / 2, NULL, 1 | 2);
        else { sysui_blur(c, xs[i], by, bs, bs, bs / 2, 20); sysui_rrect(c, xs[i], by, bs, bs, bs / 2); cairo_set_source_rgba(c, 0.1, 0.1, 0.12, 0.42); cairo_fill(c); }
        double wt[4] = { 1, 1, 1, 1 }; sysui_symbol(c, names[i], xs[i] + bs / 2, by + bs / 2, 21, wt);
    }
    double ind[4] = { 1, 1, 1, 0.9 };
    if (dev.safe_bottom > 0) { sysui_rrect(c, (W - 134) / 2, H - 8 - 5, 134, 5, 2.5); cairo_set_source_rgba(c, ind[0], ind[1], ind[2], ind[3]); cairo_fill(c); }
}

/* ---- Control Center ---- */
struct sysui_module { double x, y, w, h; };
static void sysui_platter(cairo_t *c, int os, struct sysui_module m, double r) {
    if (os >= 26) { sysui_glass(c, m.x, m.y, m.w, m.h, r, NULL, 1 | 2 | 4); return; }
    sysui_rrect(c, m.x, m.y, m.w, m.h, r);
    cairo_set_source_rgba(c, 0.08, 0.08, 0.1, os >= 18 ? 0.36 : 0.44); cairo_fill(c);
}
static void sysui_toggle(cairo_t *c, int os, double cx, double cy, double d, int on, const double on_rgb[3], const char *sym) {
    if (os >= 26 && !on) sysui_glass(c, cx - d / 2, cy - d / 2, d, d, d / 2, NULL, 1 | 2 | 4);
    else {
        cairo_arc(c, cx, cy, d / 2, 0, 2 * M_PI);
        if (on) cairo_set_source_rgb(c, on_rgb[0], on_rgb[1], on_rgb[2]); else cairo_set_source_rgba(c, 0.5, 0.5, 0.52, 0.45);
        cairo_fill(c);
    }
    double wt[4] = { 1, 1, 1, 1 }; sysui_symbol(c, sym, cx, cy, d * 0.42, wt);
}
static void sysui_draw_cc(cairo_t *c, int os) {
    double W = dev.width, H = dev.height;
    /* what is behind: blurred and dimmed (iOS 26: lighter) */
    sysui_blur(c, 0, 0, W, H, 0, os >= 26 ? 14 : 30);
    cairo_set_source_rgba(c, 0, 0, 0, os >= 26 ? 0.22 : 0.38); cairo_paint(c);
    double margin = W > 600 ? (W - 4 * 80 - 3 * 18) / 2 : 26, gap = W > 600 ? 18 : 15;
    double u = (W - 2 * margin - 3 * gap) / 4;                    /* one module unit */
    double y0 = fmax(dev.safe_top, 20) + (os >= 18 ? 64 : 42);
    double r = os >= 26 ? u * 0.42 : os >= 18 ? u * 0.36 : u * 0.28;
    double white[4] = { 1, 1, 1, 1 }, dim[4] = { 1, 1, 1, 0.6 };
    if (os >= 18) {                                               /* iOS 18: edit (+) and power at the top, page column on the right */
        double by = fmax(dev.safe_top, 20) + 10, d = 34;
        if (os >= 26) { sysui_glass(c, margin, by, d, d, d / 2, NULL, 1 | 2 | 4); sysui_glass(c, W - margin - d, by, d, d, d / 2, NULL, 1 | 2 | 4); }
        else for (int i = 0; i < 2; i++) { cairo_arc(c, i ? W - margin - d / 2 : margin + d / 2, by + d / 2, d / 2, 0, 2 * M_PI); cairo_set_source_rgba(c, 0.5, 0.5, 0.52, 0.4); cairo_fill(c); }
        sysui_symbol(c, "plus", margin + d / 2, by + d / 2, 16, white);
        { double px = W - margin - d / 2, py = by + d / 2;   /* power glyph */
          cairo_new_path(c); cairo_arc(c, px, py + 1, 6.5, -M_PI / 2 + 0.75, 1.5 * M_PI - 0.75);
          cairo_move_to(c, px, py - 7.5); cairo_line_to(c, px, py);
          cairo_set_line_width(c, 2); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_set_source_rgba(c, 1, 1, 1, 1); cairo_stroke(c); }
        const char *pages[4] = { "star.fill", "music.note", "house.fill", "wifi" };
        for (int i = 0; i < 4; i++) sysui_symbol(c, pages[i], W - margin / 2 + 2, y0 + u * 1.2 + i * 30, 13, i == 0 ? white : dim);
    }
    /* connectivity (2 x 2) */
    struct sysui_module conn = { margin, y0, 2 * u + gap, 2 * u + gap };
    sysui_platter(c, os, conn, r);
    double d = os >= 18 ? u * 0.78 : u * 0.72;
    double cxs[2] = { conn.x + conn.w * 0.27, conn.x + conn.w * 0.73 }, cys[2] = { conn.y + conn.h * 0.27, conn.y + conn.h * 0.73 };
    const double orange[3] = { 1, 0.58, 0 }, green[3] = { 0.2, 0.78, 0.35 }, blue[3] = { 0, 0.48, 1 };
    sysui_toggle(c, os, cxs[0], cys[0], d, 0, orange, "paperplane");
    sysui_toggle(c, os, cxs[1], cys[0], d, 1, green, "phone");
    sysui_toggle(c, os, cxs[0], cys[1], d, 1, blue, "wifi");
    sysui_toggle(c, os, cxs[1], cys[1], d, 1, blue, "link");
    /* now playing (2 x 2) */
    struct sysui_module music = { margin + 2 * (u + gap), y0, 2 * u + gap, 2 * u + gap };
    sysui_platter(c, os, music, r);
    sysui_text(c, "Not Playing", music.x + 14, music.y + 14, music.w - 28, 15, PANGO_WEIGHT_SEMIBOLD, dim, 0);
    const char *ctl[3] = { "backward.fill", "play.fill", "forward.fill" };
    for (int i = 0; i < 3; i++) sysui_symbol(c, ctl[i], music.x + music.w * (0.25 + 0.25 * i), music.y + music.h * 0.72, 22, white);
    /* orientation lock + focus (row 2), brightness + volume sliders (2 units tall) */
    double y2 = y0 + 2 * (u + gap);
    struct sysui_module orient = { margin, y2, u, u }, focus = { margin, y2 + u + gap, 2 * u + gap, u };
    struct sysui_module mirror = { margin + u + gap, y2, u, u };
    struct sysui_module bright = { margin + 2 * (u + gap), y2, u, 2 * u + gap }, vol = { margin + 3 * (u + gap), y2, u, 2 * u + gap };
    sysui_platter(c, os, orient, os >= 18 ? u / 2 : r);
    sysui_symbol(c, "lock", orient.x + u / 2, orient.y + u / 2, u * 0.42, white);
    sysui_platter(c, os, mirror, os >= 18 ? u / 2 : r);
    sysui_symbol(c, "rectangle.stack", mirror.x + u / 2, mirror.y + u / 2, u * 0.42, white);
    sysui_platter(c, os, focus, r);
    sysui_symbol(c, "moon.fill", focus.x + u / 2, focus.y + u / 2, u * 0.36, white);
    sysui_text(c, "Focus", focus.x + u * 0.85, focus.y + u / 2 - 10, focus.w - u, 16, PANGO_WEIGHT_SEMIBOLD, white, 0);
    struct sysui_module sl[2] = { bright, vol }; const char *slsym[2] = { "sun.max.fill", "speaker.wave.2.fill" }; double level[2] = { 0.6, 0.45 };
    for (int i = 0; i < 2; i++) {
        double sr = os >= 18 ? u * 0.46 : r;
        sysui_platter(c, os, sl[i], sr);
        cairo_save(c); sysui_rrect(c, sl[i].x, sl[i].y, sl[i].w, sl[i].h, sr); cairo_clip(c);
        cairo_rectangle(c, sl[i].x, sl[i].y + sl[i].h * (1 - level[i]), sl[i].w, sl[i].h * level[i]);
        cairo_set_source_rgba(c, 1, 1, 1, os >= 26 ? 0.85 : 0.95); cairo_fill(c);
        cairo_restore(c);
        double gray[4] = { 0.45, 0.45, 0.47, 1 }; sysui_symbol(c, slsym[i], sl[i].x + u / 2, sl[i].y + sl[i].h - u * 0.45, u * 0.38, gray);
    }
    /* bottom row: flashlight, timer, calculator, camera */
    double y3 = y2 + 2 * (u + gap) + (os >= 18 ? gap : 0);
    const char *row[4] = { "lightbulb", "alarm", "tablecells", "camera.fill" };
    for (int i = 0; i < 4; i++) {
        struct sysui_module m = { margin + i * (u + gap), y3, u, u };
        if (os >= 18) sysui_platter(c, os, m, u / 2); else sysui_platter(c, os, m, r);
        sysui_symbol(c, row[i], m.x + u / 2, m.y + u / 2, u * 0.4, white);
    }
}

static void sysui_draw(void) {
    if (!comp) comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, surf_w, surf_h);
    cairo_t *c = cairo_create(comp);
    int base = sysui.lock ? -1 : active;
    if (base >= 0 && clients[base].alive) {
        cairo_surface_t *s = client_surface(base);
        cairo_set_operator(c, CAIRO_OPERATOR_SOURCE); cairo_set_source_surface(c, s, 0, 0); cairo_paint(c);
        cairo_surface_destroy(s);
    } else { cairo_set_operator(c, CAIRO_OPERATOR_SOURCE); cairo_set_source_rgb(c, 0, 0, 0); cairo_paint(c); }
    cairo_set_operator(c, CAIRO_OPERATOR_OVER);
    cairo_scale(c, px_scale, px_scale);
    int os = isim_os_version() / 10000;
    if (sysui.lock) sysui_draw_lock(c, os);
    if (sysui.cc) sysui_draw_cc(c, os);
    cairo_destroy(c);
    present_comp();
}
static void sysui_set(int lock, int cc) {
    if (lock >= 0 && lock != sysui.lock) {
        sysui.lock = lock;
        fprintf(stderr, "isim shell: %s (iOS %d look)\n", lock ? "locked" : "unlocked", isim_os_version() / 10000);
        if (active >= 0) shell_send(active, lock ? EV_BACKGROUND : EV_FOREGROUND);
    }
    if (cc >= 0 && cc != sysui.cc) { sysui.cc = cc; fprintf(stderr, "isim shell: control center %s (iOS %d look)\n", cc ? "shown" : "closed", isim_os_version() / 10000); }
    sysui.t0 = now();
    if (sysui.lock || sysui.cc) sysui_draw(); else shell_show(active);
}
/* input while the Lock Screen / Control Center is up; returns 1 when the event was theirs */
static int sysui_input(const struct isim_event *ev) {
    static int down; static double y0, x0;
    /* swipe down from the top-right corner opens Control Center */
    if (!sysui.lock && !sysui.cc) {
        if (ev->type == EV_TOUCH_DOWN && ev->y < 24 && ev->x > dev.width * 0.66) { down = 2; y0 = ev->y; x0 = ev->x; return 1; }
        if (down == 2 && ev->type == EV_TOUCH_MOVE) return 1;
        if (down == 2 && ev->type == EV_TOUCH_UP) { down = 0; if (ev->y - y0 > 40) sysui_set(-1, 1); else { struct isim_event d = *ev; d.type = EV_TOUCH_DOWN; d.x = x0; d.y = y0; shell_forward(active, &d); shell_forward(active, ev); } return 1; }
        return 0;
    }
    if (ev->type == EV_TOUCH_DOWN) { down = 1; y0 = ev->y; return 1; }
    if (ev->type == EV_TOUCH_MOVE) return 1;
    if (ev->type == EV_TOUCH_UP && down == 1) {
        down = 0;
        if (sysui.cc) sysui_set(-1, 0);                            /* tap or swipe: close */
        else if (sysui.lock) sysui_set(0, -1);                     /* swipe up / tap: unlock */
        (void)y0;
        return 1;
    }
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP || ev->type == EV_TEXT_DOWN || ev->type == EV_TEXT_UP) return 1;
    return 0;
}
