/* The simulator window around the device screen (issue #142): a toolbar, a device bezel (on by default), the device
 * menu with its restart confirmation, and the More menu's forms (Location, Open URL, Send push notification).
 *
 * Buttons only: every control runs a command isim already has, through the same script dispatcher as `--script` and
 * the control FIFO (chrome_run appends to the script buffer like control_poll), never a separate code path. What the
 * toolbar shows (light/dark, locked, the location) is read from the device's state each time it is drawn, so changes
 * from anywhere (a script, the FIFO, Control Center, Settings, a keyboard shortcut) show up.
 *
 * Everything is drawn with cairo and Pango into the SDL window surface; the device screen is drawn into a rect of the
 * window (screen points * zoom), and mouse events over it are mapped back to screen points. `shot` and F12 stay
 * screen-only; `windowshot PATH` writes the whole window (also headless), and `window ...` script commands open
 * menus, click and type in them, so scripts, agents and tests reach everything a click can.
 * ISIM_CHROME=0 turns the chrome off (the window is the screen alone, as before). */

#define CH_TB 44.0                       /* toolbar height (points) */
#define CH_MARGIN 7.0                    /* around the bezel */
#define CH_BTN 32.0                      /* toolbar button */
#define CH_STEP 36.0                     /* between toolbar buttons */

/* the mockups' dark neutral palette */
static const double C_BACK[3] = { 20, 21, 24 }, C_BAR[3] = { 34, 35, 39 }, C_BAR_LINE[3] = { 49, 50, 56 },
    C_BTN[3] = { 47, 48, 54 }, C_HOVER[3] = { 52, 53, 60 }, C_ON[3] = { 58, 59, 66 }, C_OUTLINE[3] = { 90, 91, 99 },
    C_PANEL[3] = { 42, 43, 48 }, C_PANEL_LINE[3] = { 62, 63, 70 }, C_ROW[3] = { 58, 59, 66 }, C_INSET[3] = { 31, 32, 36 },
    C_FIELD_LINE[3] = { 74, 75, 83 }, C_TEXT[3] = { 232, 232, 236 }, C_TEXT2[3] = { 154, 155, 164 }, C_TEXT3[3] = { 120, 121, 130 },
    C_ACCENT[3] = { 138, 180, 255 }, C_ACCENT_TEXT[3] = { 16, 32, 74 }, C_GREEN[3] = { 63, 185, 80 }, C_RIM[3] = { 74, 77, 84 },
    C_BEZEL[3] = { 5, 5, 6 }, C_TIP[3] = { 240, 240, 243 }, C_TIP_TEXT[3] = { 30, 30, 35 }, C_LINK[3] = { 38, 86, 187 },
    C_SEG_PICK[3] = { 232, 232, 236 }, C_SEG[3] = { 52, 53, 59 };
static void ch_rgb(cairo_t *c, const double v[3]) { cairo_set_source_rgb(c, v[0] / 255, v[1] / 255, v[2] / 255); }
static void ch_rgba(cairo_t *c, const double v[3], double a) { cairo_set_source_rgba(c, v[0] / 255, v[1] / 255, v[2] / 255, a); }

/* ---- state ---- */
enum { CH_POP_NONE, CH_POP_DEVICE, CH_POP_MORE, CH_POP_LOCATION, CH_POP_OPENURL, CH_POP_PUSH, CH_POP_PUSHHELP };
static struct {
    int init, on;                        /* on: the chrome is drawn (ISIM_CHROME != 0) */
    int bezel, ask_restart;              /* remembered in the device data (Library/isim/Window.conf) */
    char recent[5][512];                 /* Open URL's recent URLs */
    int pop, dialog, all_devices, app_list;
    double hover_x, hover_y, hover_t; char hover[48], pressed[48];
    int pick_dev; int pick_os; double pick_zoom;   /* the device menu's picks (pick_os: major) */
    int dialog_dontask;
    /* Location */
    int place;                           /* 0..3 presets, 4 custom, -1 none picked */
    /* Push */
    int push_tab, push_sound, push_mutable, push_available, push_app;
    /* toast after a screenshot */
    char shot_path[1024]; double shot_t, toast_until; int shot_ok;
    char focus[16];                      /* the focused text field */
    int select_all;
    double W, H;                         /* the last layout (window points) */
} ch;
struct ch_field { const char *id; char buf[4096]; int cur, multi, mono; };
static struct ch_field ch_fields[] = {
    { "lat", "", 0, 0, 1 }, { "lon", "", 0, 0, 1 }, { "url", "", 0, 0, 1 }, { "title", "", 0, 0, 0 },
    { "body", "", 0, 1, 0 }, { "badge", "", 0, 0, 0 }, { "json", "", 0, 1, 1 },
};
static struct ch_field *ch_field(const char *id) {
    for (size_t i = 0; i < sizeof ch_fields / sizeof *ch_fields; i++) if (!strcmp(ch_fields[i].id, id)) return &ch_fields[i];
    return NULL;
}
static void ch_field_set(const char *id, const char *v) {
    struct ch_field *f = ch_field(id); if (!f) return;
    snprintf(f->buf, sizeof f->buf, "%s", v); f->cur = (int)strlen(f->buf);
}

static const struct { const char *name; double lat, lon; } ch_places[] = {
    { "Apple Park, Cupertino", 37.334900, -122.009020 }, { "São Paulo", -23.550520, -46.633308 },
    { "London", 51.507351, -0.127758 }, { "Tokyo", 35.676192, 139.650311 },
};

static int ch_locked(void) { return shell_mode ? locked : 0; }

/* the device data's window preferences: bezel=1, ask-restart=1, url=... (recent first) */
static void ch_conf_path(char *p, size_t cap) {
    const char *d = getenv("ISIM_DATA"), *home = getenv("HOME");
    if (d && *d) snprintf(p, cap, "%s/Library/isim/Window.conf", d);
    else snprintf(p, cap, "%s/.local/share/isim/Library/isim/Window.conf", home ? home : "");
}
static void ch_save(void) {
    char p[1100]; ch_conf_path(p, sizeof p);
    char dir[1100]; snprintf(dir, sizeof dir, "%s", p); char *sl = strrchr(dir, '/'); if (sl) { *sl = 0; mkdir(dir, 0755); }
    FILE *f = fopen(p, "w"); if (!f) return;
    fprintf(f, "bezel=%d\nask-restart=%d\n", ch.bezel, ch.ask_restart);
    for (int i = 0; i < 5; i++) if (ch.recent[i][0]) fprintf(f, "url=%s\n", ch.recent[i]);
    fclose(f);
}
static void ch_init(void) {
    if (ch.init) return;
    ch.init = 1;
    const char *e = getenv("ISIM_CHROME");
    ch.on = !(e && !strcmp(e, "0"));
    ch.bezel = 1; ch.ask_restart = 1; ch.place = -1; ch.push_sound = 1; ch.push_app = 0;
    char p[1100]; ch_conf_path(p, sizeof p);
    FILE *f = fopen(p, "r");
    if (f) {
        char line[600]; int nr = 0;
        while (fgets(line, sizeof line, f)) {
            line[strcspn(line, "\r\n")] = 0;
            if (!strncmp(line, "bezel=", 6)) ch.bezel = atoi(line + 6) != 0;
            else if (!strncmp(line, "ask-restart=", 12)) ch.ask_restart = atoi(line + 12) != 0;
            else if (!strncmp(line, "url=", 4) && nr < 5) snprintf(ch.recent[nr++], sizeof ch.recent[0], "%s", line + 4);
        }
        fclose(f);
    }
    ch_field_set("title", "Hello from isim"); ch_field_set("body", "Sent from the simulator window."); ch_field_set("badge", "1");
}

/* ---- the device: presets, short names, iOS ---- */
static int ch_cur_dev(void) {
    const char *d = getenv("ISIM_DEVICE"); int i = d && *d ? device_index(d) : -1;
    if (i < 0) i = device_index("iphone15");
    if (!strcmp(devices[i].id, "ipad")) i = device_index("ipadair11");
    return i;
}
static int ch_cur_major(void) { int v = isim_os_version(); return v ? v / 10000 : ISIM_OS_DEFAULT_MAJOR; }
static void ch_short_name(int di, char *out, size_t cap) {   /* "iPhone SE", "iPad Air 11″", "iPad Pro 13″" */
    const char *n = devices[di].d.name;
    char b[64]; snprintf(b, sizeof b, "%s", n);
    char *paren = strstr(b, " ("); if (paren) *paren = 0;
    char *inch = strstr(b, "-inch"); if (inch) { *inch = 0; snprintf(out, cap, "%s″", b); return; }
    snprintf(out, cap, "%s", b);
}
static int ch_dev_ok(int di, int major) { return major >= devices[di].min_major; }   /* (17 on an iPad: 17.5) */
static int ch_dev_min_major(int di) {         /* the first supported major the device runs */
    for (size_t i = 0; i < sizeof isim_os_majors / sizeof *isim_os_majors; i++) if (ch_dev_ok(di, isim_os_majors[i])) return isim_os_majors[i];
    return 27;
}
static int ch_is_pad(int di) { return devices[di].d.width >= 700; }

/* ---- geometry (window points) ----
   The bezel is drawn upright (portrait) and turned with the screen: insets t, r, b, l around the screen. */
struct ch_geo { double W, H, sx, sy, sw, sh, bx, by, bw, bh, outer_r; int compact, rot; double it, ir, ib, il; };
static void ch_bezel_insets(double *t, double *r, double *b, double *l) {      /* portrait, in points */
    double z = zoom;
    if (portrait_dev.width >= 700) { *t = *r = *b = *l = fmax(10, 22 * z); return; }       /* iPad */
    if (portrait_dev.corner_radius <= 0) { *l = *r = fmax(8, 16 * z); *t = *b = fmax(30, 76 * z); return; }   /* Home button */
    *t = *r = *b = *l = fmax(8, 13 * z);
}
static double ch_toolbar_min(int compact);
static struct ch_geo ch_layout(void) {
    struct ch_geo g; memset(&g, 0, sizeof g);
    double sw = dev.width * zoom, sh = dev.height * zoom;
    g.sw = sw; g.sh = sh;
    if (!ch.on) { g.W = sw; g.H = sh; return g; }
    int o = dev.orientation ? dev.orientation : 1;
    g.rot = o;
    double t = 0, r = 0, b = 0, l = 0;
    if (ch.bezel) ch_bezel_insets(&t, &r, &b, &l);
    /* turned: o 3 (landscape right) = the top of the device on the left; 4 = on the right; 2 = upside down */
    if (o == 3) { g.it = r; g.ir = b; g.ib = l; g.il = t; }
    else if (o == 4) { g.it = l; g.ir = t; g.ib = r; g.il = b; }
    else if (o == 2) { g.it = b; g.ir = l; g.ib = t; g.il = r; }
    else { g.it = t; g.ir = r; g.ib = b; g.il = l; }
    double m = ch.bezel ? CH_MARGIN : 0;
    double inner_w = g.il + sw + g.ir + 2 * m, inner_h = g.it + sh + g.ib + 2 * m;
    g.compact = inner_w < ch_toolbar_min(0);
    g.W = fmax(inner_w, ch_toolbar_min(g.compact));
    g.H = CH_TB + inner_h;
    g.bx = (g.W - (g.il + sw + g.ir)) / 2; g.by = CH_TB + m;
    g.bw = g.il + sw + g.ir; g.bh = g.it + sh + g.ib;
    g.sx = g.bx + g.il; g.sy = g.by + g.it;
    double cr0 = dev.corner_radius * zoom;
    g.outer_r = cr0 > 0 ? cr0 + fmin(g.il, g.it) : (portrait_dev.width >= 700 ? 0 : fmax(14, 54 * zoom));
    return g;
}
/* a window bigger or smaller than its layout (maximized; or fitted to a small screen, window_size) shows the layout at one
   scale, the largest that fits, centred: never stretched (issue #652). Window points map back to layout points the same
   way (chrome_sdl_event). */
struct ch_view { double k, ox, oy; };
static struct ch_view ch_view_for(double ww, double wh, const struct ch_geo *g) {
    struct ch_view v = { fmin(ww / g->W, wh / g->H), 0, 0 };
    if (!(v.k > 0) || !isfinite(v.k)) v.k = 1;
    v.ox = (ww - g->W * v.k) / 2; v.oy = (wh - g->H * v.k) / 2;
    return v;
}
static struct ch_view ch_window_view(const struct ch_geo *g) {
    int w = 0, h = 0;
    if (win) SDL_GetWindowSize(win, &w, &h);
    if (w <= 0 || h <= 0) return (struct ch_view){ 1, 0, 0 };
    return ch_view_for(w, h, g);
}
#define CH_DECORATION 48     /* points left for the window manager's title bar and borders when fitting the window */
static void window_size(int *w, int *h) {
    ch_init();
    struct ch_geo g = ch_layout();
    *w = (int)ceil(g.W - 1e-6); *h = (int)ceil(g.H - 1e-6);
    /* never taller or wider than the screen's usable area (a 1366x768 screen and a 936-point window could not be
       resized: issue #652): the same layout, scaled down to fit */
    SDL_Rect r;
    SDL_DisplayID d = win ? SDL_GetDisplayForWindow(win) : SDL_GetPrimaryDisplay();
    if (!d || !SDL_GetDisplayUsableBounds(d, &r)) return;
    double f = fmin((double)r.w / *w, (double)(r.h - CH_DECORATION) / *h);
    if (f > 0 && f < 1) { *w = (int)floor(*w * f); *h = (int)floor(*h * f); }
}
static void window_resize(void) {
    if (!win) return;
    int w, h, cw = 0, ch_ = 0; window_size(&w, &h);
    SDL_GetWindowSize(win, &cw, &ch_);
    if (cw == w && ch_ == h) return;     /* unchanged: on X11 a fixed-size window is unmapped and mapped again to resize */
    if (getenv("ISIM_WINDOW_DEBUG")) fprintf(stderr, "isim window: resize %dx%d -> %dx%d (orientation %d)\n", cw, ch_, w, h, dev.orientation);
    SDL_SetWindowSize(win, w, h);
}
/* isim draws every frame in software (cairo) and copies it to the window surface. SDL's default backs that surface with
   an accelerated renderer, which on X11 destroys the new window and creates it again the first time it is drawn: the
   window flickered at every start and restart, and a click in those first ~100 ms went to a window that no longer
   existed. Only on X11: it is the only Linux video driver with a software window framebuffer, and on Wayland, without
   the renderer, the window has no surface at all, is never drawn, and so is never shown (isim 0.23.0). The environment
   variable SDL_FRAMEBUFFER_ACCELERATION still overrides this. */
static void window_sdl_hints(void) {
    const char *drv = SDL_GetCurrentVideoDriver();
    if (drv && !strcmp(drv, "x11")) SDL_SetHint(SDL_HINT_FRAMEBUFFER_ACCELERATION, "0");
}
static void window_title(void) {
    if (!win) return;
    char n[64], t[160]; ch_short_name(ch_cur_dev(), n, sizeof n);
    snprintf(t, sizeof t, "isim — %s · iOS %d", n, ch_cur_major());
    SDL_SetWindowTitle(win, t);
}

/* ---- drawing helpers ---- */
static void ch_round(cairo_t *c, double x, double y, double w, double h, double r) {
    r = fmin(r, fmin(w, h) / 2);
    cairo_new_sub_path(c);
    cairo_arc(c, x + w - r, y + r, r, -M_PI / 2, 0); cairo_arc(c, x + w - r, y + h - r, r, 0, M_PI / 2);
    cairo_arc(c, x + r, y + h - r, r, M_PI / 2, M_PI); cairo_arc(c, x + r, y + r, r, M_PI, 3 * M_PI / 2);
    cairo_close_path(c);
}
static void ch_fill_round(cairo_t *c, double x, double y, double w, double h, double r, const double col[3]) {
    ch_round(c, x, y, w, h, r); ch_rgb(c, col); cairo_fill(c);
}
static void ch_stroke_round(cairo_t *c, double x, double y, double w, double h, double r, const double col[3], double lw) {
    ch_round(c, x + lw / 2, y + lw / 2, w - lw, h - lw, r); ch_rgb(c, col); cairo_set_line_width(c, lw); cairo_stroke(c);
}
/* text: (x, y) is the top left of the line box (or its centre / right with align 1 / 2 against x..x+w);
   returns the width. weight: PangoWeight; mono: Adwaita Mono */
static PangoLayout *ch_layout_text(cairo_t *c, const char *s, double size, int weight, int mono, double wrap) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, mono ? SYSTEM_MONO : SYSTEM_SANS);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, (PangoWeight)weight);
    pango_layout_set_font_description(l, fd);
    pango_font_description_free(fd);
    if (wrap > 0) { pango_layout_set_width(l, (int)(wrap * PANGO_SCALE)); pango_layout_set_wrap(l, PANGO_WRAP_WORD_CHAR); }
    pango_layout_set_text(l, s, -1);
    return l;
}
static double ch_text_w(cairo_t *c, const char *s, double size, int weight, int mono) {
    PangoLayout *l = ch_layout_text(c, s, size, weight, mono, 0);
    int w, h; pango_layout_get_pixel_size(l, &w, &h); g_object_unref(l);
    PangoRectangle ink, log; (void)ink; (void)log;
    return w;
}
static double ch_text_at(cairo_t *c, const char *s, double x, double cy, double size, int weight, int mono, const double col[3], double alpha, int align, double w) {
    PangoLayout *l = ch_layout_text(c, s, size, weight, mono, 0);
    if (align == 3 && w > 0) { pango_layout_set_width(l, (int)(w * PANGO_SCALE)); pango_layout_set_ellipsize(l, PANGO_ELLIPSIZE_END); }
    PangoRectangle log; pango_layout_get_extents(l, NULL, &log);
    double tw = log.width / (double)PANGO_SCALE, th = log.height / (double)PANGO_SCALE;
    double tx = align == 1 ? x + (w - tw) / 2 : align == 2 ? x + w - tw : x;
    ch_rgba(c, col, alpha); cairo_move_to(c, tx, cy - th / 2); pango_cairo_show_layout(c, l); cairo_new_path(c);
    g_object_unref(l);
    return tw;
}
/* wrapped text from the top; returns the height */
static double ch_para(cairo_t *c, const char *s, double x, double y, double w, double size, int weight, int mono, const double col[3], int markup) {
    PangoLayout *l = ch_layout_text(c, "", size, weight, mono, w);
    if (markup) pango_layout_set_markup(l, s, -1); else pango_layout_set_text(l, s, -1);
    pango_layout_set_spacing(l, (int)(size * 0.28 * PANGO_SCALE));
    int pw, ph; pango_layout_get_pixel_size(l, &pw, &ph);
    PangoRectangle log; pango_layout_get_extents(l, NULL, &log);
    ch_rgb(c, col); cairo_move_to(c, x, y); pango_cairo_show_layout(c, l); cairo_new_path(c);
    double h = log.height / (double)PANGO_SCALE;
    g_object_unref(l);
    return h;
}

/* ---- icons (stroked outlines, 24-point design grid centred on cx, cy, s = size) ---- */
static void ch_icon_begin(cairo_t *c, double cx, double cy, double s, const double col[3], double alpha) {
    cairo_save(c); cairo_translate(c, cx - s / 2, cy - s / 2); cairo_scale(c, s / 24, s / 24);
    ch_rgba(c, col, alpha); cairo_set_line_width(c, 1.8); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_set_line_join(c, CAIRO_LINE_JOIN_ROUND);
}
static void ch_icon(cairo_t *c, const char *name, double cx, double cy, double s, const double col[3], double alpha) {
    ch_icon_begin(c, cx, cy, s, col, alpha);
    if (!strcmp(name, "home")) {
        cairo_move_to(c, 4, 10.5); cairo_line_to(c, 12, 3.8); cairo_line_to(c, 20, 10.5);
        cairo_move_to(c, 6, 9); cairo_line_to(c, 6, 20); cairo_line_to(c, 18, 20); cairo_line_to(c, 18, 9); cairo_stroke(c);
    } else if (!strcmp(name, "lock") || !strcmp(name, "lock.fill")) {
        ch_round(c, 5.5, 10.5, 13, 10, 2.2);
        if (name[4]) { cairo_fill_preserve(c); } cairo_stroke(c);
        cairo_move_to(c, 8.5, 10.5); cairo_line_to(c, 8.5, 7.5); cairo_arc(c, 12, 7.5, 3.5, M_PI, 2 * M_PI); cairo_line_to(c, 15.5, 10.5); cairo_stroke(c);
    } else if (!strcmp(name, "rotate")) {          /* a clockwise arrow, open at the top right */
        double e = -M_PI / 3, r = 7.5, ex = 12 + r * cos(e), ey = 12 + r * sin(e), tx = -sin(e), ty = cos(e);
        cairo_arc(c, 12, 12, r, 10 * M_PI / 180, e + 2 * M_PI); cairo_stroke(c);
        for (int sgn = -1; sgn <= 1; sgn += 2) {
            double a = 0.75 * sgn, dx = tx * cos(a) - ty * sin(a), dy = tx * sin(a) + ty * cos(a);
            cairo_move_to(c, ex + 1.2 * tx, ey + 1.2 * ty); cairo_line_to(c, ex + 1.2 * tx - 4.6 * dx, ey + 1.2 * ty - 4.6 * dy);
        }
        cairo_stroke(c);
    } else if (!strcmp(name, "camera")) {
        ch_round(c, 3.5, 7, 17, 12.5, 2.5); cairo_stroke(c);
        cairo_move_to(c, 8.5, 7); cairo_line_to(c, 9.8, 4.8); cairo_line_to(c, 14.2, 4.8); cairo_line_to(c, 15.5, 7); cairo_stroke(c);
        cairo_arc(c, 12, 13.2, 3.3, 0, 2 * M_PI); cairo_stroke(c);
    } else if (!strcmp(name, "moon") || !strcmp(name, "moon.fill")) {
        /* a crescent: the disc A minus the disc B, through their two intersections */
        double ax = 12, ay = 12.5, ar = 8, bx = 17, by = 7.5, br = 7;
        double dx = bx - ax, dy = by - ay, d = hypot(dx, dy), aa = (ar * ar - br * br + d * d) / (2 * d), th = atan2(dy, dx), ph = acos(aa / ar);
        double i1x = ax + ar * cos(th + ph), i1y = ay + ar * sin(th + ph), i2x = ax + ar * cos(th - ph), i2y = ay + ar * sin(th - ph);
        cairo_new_path(c);
        cairo_arc(c, ax, ay, ar, th + ph, th - ph + 2 * M_PI);
        cairo_arc_negative(c, bx, by, br, atan2(i2y - by, i2x - bx), atan2(i1y - by, i1x - bx));
        cairo_close_path(c);
        if (name[4]) cairo_fill_preserve(c);
        cairo_stroke(c);
    } else if (!strcmp(name, "sun")) {
        cairo_arc(c, 12, 12, 4, 0, 2 * M_PI); cairo_stroke(c);
        for (int i = 0; i < 8; i++) { double a = i * M_PI / 4; cairo_move_to(c, 12 + 6.8 * cos(a), 12 + 6.8 * sin(a)); cairo_line_to(c, 12 + 9 * cos(a), 12 + 9 * sin(a)); }
        cairo_stroke(c);
    } else if (!strcmp(name, "more")) {
        for (int i = -1; i <= 1; i++) { cairo_arc(c, 12 + i * 6, 12, 1.5, 0, 2 * M_PI); cairo_fill(c); }
    } else if (!strcmp(name, "chevron.down") || !strcmp(name, "chevron.up")) {
        double d = name[8] == 'd' ? 1 : -1;
        cairo_move_to(c, 7, 12 - 2.5 * d); cairo_line_to(c, 12, 12 + 2.5 * d); cairo_line_to(c, 17, 12 - 2.5 * d); cairo_stroke(c);
    } else if (!strcmp(name, "chevron.left")) {
        cairo_move_to(c, 14.5, 6.5); cairo_line_to(c, 9, 12); cairo_line_to(c, 14.5, 17.5); cairo_stroke(c);
    } else if (!strcmp(name, "check")) {
        cairo_move_to(c, 5.5, 12.5); cairo_line_to(c, 10, 17); cairo_line_to(c, 19, 7.5); cairo_stroke(c);
    } else if (!strcmp(name, "power")) {
        cairo_move_to(c, 12, 4); cairo_line_to(c, 12, 11.5); cairo_stroke(c);
        cairo_arc(c, 12, 13, 7.5, -M_PI / 2 + 0.75, 3 * M_PI / 2 - 0.75); cairo_stroke(c);
    } else if (!strcmp(name, "plus") || !strcmp(name, "minus")) {
        cairo_move_to(c, 6, 12); cairo_line_to(c, 18, 12);
        if (name[0] == 'p') { cairo_move_to(c, 12, 6); cairo_line_to(c, 12, 18); }
        cairo_stroke(c);
    } else if (!strcmp(name, "close")) {
        cairo_move_to(c, 7, 7); cairo_line_to(c, 17, 17); cairo_move_to(c, 17, 7); cairo_line_to(c, 7, 17); cairo_stroke(c);
    } else if (!strcmp(name, "arrow.right")) {
        cairo_move_to(c, 5, 12); cairo_line_to(c, 18.5, 12); cairo_move_to(c, 13.5, 7); cairo_line_to(c, 18.5, 12); cairo_line_to(c, 13.5, 17); cairo_stroke(c);
    }
    cairo_restore(c);
}

/* ---- the elements drawn this frame: ids and rects (window points) for clicks, hover and `window tap ID` ---- */
static struct { char id[48]; double x, y, w, h; } ch_els[160]; static int ch_nels;
static void ch_el(const char *id, double x, double y, double w, double h) {
    if (ch_nels >= 160) return;
    snprintf(ch_els[ch_nels].id, sizeof ch_els[0].id, "%s", id);
    ch_els[ch_nels].x = x; ch_els[ch_nels].y = y; ch_els[ch_nels].w = w; ch_els[ch_nels].h = h; ch_nels++;
}
static const char *ch_el_at(double x, double y) {
    for (int i = ch_nels - 1; i >= 0; i--)
        if (x >= ch_els[i].x && x < ch_els[i].x + ch_els[i].w && y >= ch_els[i].y && y < ch_els[i].y + ch_els[i].h) return ch_els[i].id;
    return NULL;
}
static int ch_is(const char *a, const char *b) { return a && !strcmp(a, b); }
static int ch_hot(const char *id) { return ch_is(ch.hover, id); }

/* ---- the device's state, read each time it is drawn (requirement 1) ---- */
static void ch_data_path(char *p, size_t cap, const char *rel) {          /* a path in the device data */
    const char *d = getenv("ISIM_DATA"), *home = getenv("HOME");
    if (d && *d) snprintf(p, cap, "%s/%s", d, rel); else snprintf(p, cap, "%s/.local/share/isim/%s", home ? home : "", rel);
}
static double ch_mtime(const char *p) { struct stat st; return stat(p, &st) ? 0 : st.st_mtim.tv_sec + st.st_mtim.tv_nsec / 1e9; }
static double ch_prefs_mtime0 = -1;            /* the global preferences when the window opened (--dark lasts until they change) */
static int ch_dark(void) {
    char p[1100]; ch_data_path(p, sizeof p, "Library/Preferences/.GlobalPreferences.plist");
    double mt = ch_mtime(p);
    if (ch_prefs_mtime0 < 0) ch_prefs_mtime0 = mt;
    const char *e = getenv("ISIM_APPEARANCE");
    if (e && *e && mt == ch_prefs_mtime0) return !strcmp(e, "dark");      /* --dark, until Settings or `appearance` change it */
    FILE *f = fopen(p, "rb"); if (!f) return 0;
    static char buf[65536]; size_t n = fread(buf, 1, sizeof buf - 1, f); fclose(f); buf[n] = 0;
    const char *k = memmem(buf, n, "AppleInterfaceStyle", 19);
    if (!k) return 0;
    if (!memcmp(buf, "bplist", 6)) return memmem(buf, n, "Dark", 4) != NULL;
    const char *v = k + 19; if (!strncmp(v, "</key>", 6)) v += 6;
    v += strspn(v, " \t\r\n");
    return !strncmp(v, "<string>Dark</string>", 21);
}
/* Features > Location: "LAT LON", or none */
static int ch_location(double *lat, double *lon) {
    char p[1100]; ch_data_path(p, sizeof p, "Library/isim/SimulatedLocation");
    FILE *f = fopen(p, "r"); if (!f) return 0;
    int ok = fscanf(f, "%lf %lf", lat, lon) == 2; fclose(f);
    return ok;
}
static const char *ch_orient_name(int o) {
    return o == 2 ? "upsidedown" : o == 3 ? "landscapeleft" : o == 4 ? "landscaperight" : "portrait";
}
/* a cairo context for measuring text outside a frame */
static cairo_t *ch_measure(void) {
    static cairo_t *c;
    if (!c) { cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 4, 4); c = cairo_create(s); cairo_surface_destroy(s); }
    return c;
}

/* ---- the toolbar ---- */
#define CH_FONT 13.5
static const struct { const char *id, *icon, *tip, *keys; } ch_tools[] = {
    { "home", "home", "Home", "Ctrl+Shift+H" }, { "lock", "lock", "Lock", "Ctrl+L" }, { "rotate", "rotate", "Rotate", "Ctrl+← / →" },
    { "shot", "camera", "Screenshot", "F12" }, { "appearance", "moon", "Dark appearance", "" }, { "more", "more", "More", "" },
};
static double ch_devbtn_w(cairo_t *c, int compact) {
    char n[64], os[16]; ch_short_name(ch_cur_dev(), n, sizeof n); snprintf(os, sizeof os, "iOS %d", ch_cur_major());
    double w = 22 + ch_text_w(c, n, CH_FONT, 600, 0) + 8 + 14 + 10;
    if (!compact) w += ch_text_w(c, os, CH_FONT, 400, 0) + 7;
    return w;
}
static int ch_ntools(int compact) { return compact ? 5 : 6; }            /* compact: no appearance button */
static double ch_toolbar_min(int compact) {
    return 6 + ch_devbtn_w(ch_measure(), compact) + 14 + (ch_ntools(compact) - 1) * CH_STEP + CH_BTN + 6;
}

/* ---- controls ---- */
static void ch_button(cairo_t *c, const char *id, double x, double y, double w, double h, const char *label, int primary, int enabled) {
    if (enabled) ch_el(id, x, y, w, h);
    if (primary == 1) ch_fill_round(c, x, y, w, h, 8, C_ACCENT);       /* 1: primary, 0: secondary, -1: text only */
    else if (primary == 0) ch_fill_round(c, x, y, w, h, 8, ch_hot(id) && enabled ? C_HOVER : C_BTN);
    if (primary == 1 && ch_hot(id) && enabled) { ch_round(c, x, y, w, h, 8); cairo_set_source_rgba(c, 1, 1, 1, 0.12); cairo_fill(c); }
    ch_text_at(c, label, x, y + h / 2, CH_FONT, primary == 1 ? 600 : 400, 0, primary == 1 ? C_ACCENT_TEXT : C_TEXT, enabled ? 1 : 0.4, 1, w);
    if (primary == 1 && !enabled) { ch_round(c, x, y, w, h, 8); ch_rgba(c, C_PANEL, 0.55); cairo_fill(c); }
}
static void ch_checkbox(cairo_t *c, double x, double y, int on) {          /* 16 x 16 at x, y */
    if (on) {
        ch_fill_round(c, x, y, 16, 16, 3, C_ACCENT);
        ch_icon(c, "check", x + 8, y + 8, 15, C_ACCENT_TEXT, 1);
    } else {
        ch_fill_round(c, x, y, 16, 16, 3, C_TEXT);
        ch_stroke_round(c, x, y, 16, 16, 3, C_FIELD_LINE, 1);
    }
}
static void ch_radio(cairo_t *c, double cx, double cy, int on) {
    cairo_arc(c, cx, cy, 6.5, 0, 2 * M_PI); ch_rgb(c, on ? C_ACCENT : C_TEXT); cairo_fill(c);
    if (on) { cairo_arc(c, cx, cy, 4.2, 0, 2 * M_PI); ch_rgb(c, C_TEXT); cairo_fill(c); cairo_arc(c, cx, cy, 3, 0, 2 * M_PI); ch_rgb(c, C_ACCENT); cairo_fill(c); }
}
static void ch_header(cairo_t *c, const char *s, double x, double y) {     /* "DEVICE": small caps, spaced */
    PangoLayout *l = ch_layout_text(c, s, 11, 700, 0, 0);
    PangoAttrList *al = pango_attr_list_new(); pango_attr_list_insert(al, pango_attr_letter_spacing_new((int)(0.9 * PANGO_SCALE)));
    pango_layout_set_attributes(l, al); pango_attr_list_unref(al);
    ch_rgb(c, C_TEXT2); cairo_move_to(c, x, y); pango_cairo_show_layout(c, l); cairo_new_path(c); g_object_unref(l);
}
static void ch_divider(cairo_t *c, double x, double y, double w) {
    cairo_rectangle(c, x, y, w, 1); ch_rgb(c, C_PANEL_LINE); cairo_fill(c);
}
/* a text field: focused fields show the cursor (never blinking: screenshots stay the same) */
static void ch_field_draw(cairo_t *c, const char *id, double x, double y, double w, double h) {
    struct ch_field *f = ch_field(id); if (!f) return;
    char eid[48]; snprintf(eid, sizeof eid, "field.%s", id);
    ch_el(eid, x, y, w, h);
    int focus = !strcmp(ch.focus, id);
    ch_fill_round(c, x, y, w, h, 7, C_INSET);
    if (focus) {
        ch_round(c, x - 2, y - 2, w + 4, h + 4, 9); ch_rgba(c, C_ACCENT, 0.3); cairo_set_line_width(c, 2); cairo_stroke(c);
        ch_stroke_round(c, x, y, w, h, 7, C_ACCENT, 1.5);
    } else ch_stroke_round(c, x, y, w, h, 7, C_FIELD_LINE, 1);
    double pad = 10, size = f->mono ? 13.5 : CH_FONT;
    PangoLayout *l = ch_layout_text(c, f->buf, size, 400, f->mono, f->multi ? w - 2 * pad : 0);
    if (f->multi) pango_layout_set_spacing(l, (int)(size * 0.2 * PANGO_SCALE));
    PangoRectangle log, cur; pango_layout_get_extents(l, NULL, &log);
    pango_layout_get_cursor_pos(l, f->cur, &cur, NULL);
    double th = log.height / (double)PANGO_SCALE, lh = cur.height / (double)PANGO_SCALE;
    double cx = cur.x / (double)PANGO_SCALE, cy = cur.y / (double)PANGO_SCALE;
    double ox = 0, oy = 0;
    if (!f->multi) {
        double tw = log.width / (double)PANGO_SCALE;
        if (focus && cx > w - 2 * pad) ox = cx - (w - 2 * pad);
        else if (!focus && tw > w - 2 * pad) ox = 0;
        oy = (h - (th > 0 ? th : lh)) / 2;
    } else {
        oy = pad - 1;
        if (focus && cy + lh > h - 2 * pad) oy -= cy + lh - (h - 2 * pad);
    }
    cairo_save(c); cairo_rectangle(c, x + 2, y + 2, w - 4, h - 4); cairo_clip(c);
    if (focus && ch.select_all && f->buf[0]) {
        cairo_rectangle(c, x + pad - ox, y + oy, log.width / (double)PANGO_SCALE, th); ch_rgba(c, C_ACCENT, 0.35); cairo_fill(c);
    }
    ch_rgb(c, C_TEXT); cairo_move_to(c, x + pad - ox, y + oy); pango_cairo_show_layout(c, l); cairo_new_path(c);
    if (focus) { cairo_rectangle(c, x + pad - ox + cx - 0.75, y + oy + cy + 1, 1.5, lh - 2); ch_rgb(c, C_ACCENT); cairo_fill(c); }
    cairo_restore(c);
    g_object_unref(l);
}
/* a popover panel: rounded, outlined, with a soft shadow */
static void ch_panel(cairo_t *c, double x, double y, double w, double h) {
    for (int i = 4; i >= 1; i--) { ch_round(c, x - i * 2, y - i * 2 + 6, w + i * 4, h + i * 4, 12 + i * 2); cairo_set_source_rgba(c, 0, 0, 0, 0.07); cairo_fill(c); }
    ch_fill_round(c, x, y, w, h, 12, C_PANEL);
    ch_stroke_round(c, x, y, w, h, 12, C_PANEL_LINE, 1);
}

/* ---- painting ---- */
static int ch_form_open(void) { return ch.pop >= CH_POP_LOCATION; }
static void ch_paint_toolbar(cairo_t *c, struct ch_geo *g) {
    cairo_rectangle(c, 0, 0, g->W, CH_TB); ch_rgb(c, C_BAR); cairo_fill(c);
    cairo_rectangle(c, 0, CH_TB - 1, g->W, 1); ch_rgb(c, C_BAR_LINE); cairo_fill(c);
    /* the device button: status dot, name, iOS, chevron */
    int di = ch_cur_dev();
    char n[64], os[16]; ch_short_name(di, n, sizeof n); snprintf(os, sizeof os, "iOS %d", ch_cur_major());
    int chevron = !ch_form_open() && !ch.dialog;
    double bw = ch_devbtn_w(c, g->compact) - (chevron ? 0 : 22), bx = 6, by = 6;
    ch_el("device", bx, by, bw, CH_BTN);
    ch_fill_round(c, bx, by, bw, CH_BTN, 8, ch.pop == CH_POP_DEVICE ? C_ON : ch_hot("device") ? C_HOVER : C_BTN);
    if (ch.pop == CH_POP_DEVICE) ch_stroke_round(c, bx, by, bw, CH_BTN, 8, C_OUTLINE, 1);
    cairo_arc(c, bx + 13, by + CH_BTN / 2, 4, 0, 2 * M_PI); ch_rgb(c, C_GREEN); cairo_fill(c);
    double x = bx + 22;
    x += ch_text_at(c, n, x, by + CH_BTN / 2, CH_FONT, 600, 0, C_TEXT, 1, 0, 0);
    if (!g->compact) x += 7 + ch_text_at(c, os, x + 7, by + CH_BTN / 2, CH_FONT, 400, 0, C_TEXT2, 1, 0, 0);
    if (chevron) ch_icon(c, ch.pop == CH_POP_DEVICE ? "chevron.up" : "chevron.down", x + 8 + 7, by + CH_BTN / 2, 16, C_TEXT2, 1);
    /* the tools, right to left from the More button */
    int nt = ch_ntools(g->compact), k = 0;
    for (int i = 5; i >= 0; i--) {
        if (g->compact && i == 4) continue;
        double tx = g->W - 6 - CH_BTN - k * CH_STEP; k++;
        if (ch_form_open() && i != 5) continue;          /* a form open: only More (the mockups) */
        if (ch.dialog) continue;                         /* under the dialog: the device button alone */
        const char *id = ch_tools[i].id;
        int disabled = !strcmp(id, "lock") && !shell_mode;     /* the app alone (isim run) has no Lock Screen */
        int on = (i == 5 && (ch.pop == CH_POP_MORE || ch_form_open())) || (!strcmp(id, "shot") && ch.toast_until > now());
        if (!disabled) ch_el(id, tx, 6, CH_BTN, CH_BTN);
        if (on || (ch_hot(id) && !disabled)) ch_fill_round(c, tx, 6, CH_BTN, CH_BTN, 8, on ? C_ON : C_HOVER);
        if (i == 5 && (ch.pop == CH_POP_MORE || ch_form_open())) ch_stroke_round(c, tx, 6, CH_BTN, CH_BTN, 8, C_OUTLINE, 1);
        const char *icon = ch_tools[i].icon;
        if (!strcmp(id, "lock") && ch_locked()) icon = "lock.fill";
        if (!strcmp(id, "appearance")) icon = ch_dark() ? "moon.fill" : "moon";
        ch_icon(c, icon, tx + CH_BTN / 2, 6 + CH_BTN / 2, 19, C_TEXT, disabled ? 0.35 : 1);
    }
    (void)nt;
}

/* the bezel, drawn upright around (0, 0) and turned with the screen; hardware buttons register their rects */
struct ch_hw { const char *id; int side; double at, len; };      /* side: 0 left, 1 right, 2 top; at/len: points from the top (left) */
static int ch_hw_list(int di, struct ch_hw *hw) {
    const char *id = devices[di].id; int n = 0;
    if (ch_is_pad(di)) {
        hw[n++] = (struct ch_hw){ "hw.top", 2, -1, 50 };
        hw[n++] = (struct ch_hw){ "hw.volup", 1, 80, 46 }; hw[n++] = (struct ch_hw){ "hw.voldown", 1, 136, 46 };
        return n;
    }
    int se = devices[di].d.corner_radius <= 0;
    int action = !strcmp(id, "iphone15promax") || !strncmp(id, "iphone16", 8) || !strncmp(id, "iphone17", 8) || !strcmp(id, "iphoneair");
    int camctl = !strncmp(id, "iphone16", 8) || !strncmp(id, "iphone17", 8) || !strcmp(id, "iphoneair");
    if (se) {
        hw[n++] = (struct ch_hw){ "hw.silent", 0, 96, 22 };
        hw[n++] = (struct ch_hw){ "hw.volup", 0, 142, 42 }; hw[n++] = (struct ch_hw){ "hw.voldown", 0, 196, 42 };
        hw[n++] = (struct ch_hw){ "hw.side", 1, 142, 52 };
        return n;
    }
    hw[n++] = (struct ch_hw){ action ? "hw.action" : "hw.silent", 0, 112, 30 };
    hw[n++] = (struct ch_hw){ "hw.volup", 0, 168, 58 }; hw[n++] = (struct ch_hw){ "hw.voldown", 0, 238, 58 };
    hw[n++] = (struct ch_hw){ "hw.side", 1, 186, 94 };
    if (camctl) hw[n++] = (struct ch_hw){ "hw.camera", 1, 560, 40 };
    return n;
}
/* portrait bezel point (from its top left) -> window points */
static void ch_bz_xf(struct ch_geo *g, double PW, double PH, double px, double py, double *wx, double *wy) {
    double u = px - PW / 2, v = py - PH / 2, a = g->rot == 3 ? -M_PI / 2 : g->rot == 4 ? M_PI / 2 : g->rot == 2 ? M_PI : 0;
    *wx = g->bx + g->bw / 2 + u * cos(a) - v * sin(a); *wy = g->by + g->bh / 2 + u * sin(a) + v * cos(a);
}
static void ch_paint_bezel(cairo_t *c, struct ch_geo *g) {
    double t, r, b, l; ch_bezel_insets(&t, &r, &b, &l);
    double z = zoom, PW = l + portrait_dev.width * z + r, PH = t + portrait_dev.height * z + b;
    int di = ch_cur_dev();
    cairo_save(c);
    cairo_translate(c, g->bx + g->bw / 2, g->by + g->bh / 2);
    cairo_rotate(c, g->rot == 3 ? -M_PI / 2 : g->rot == 4 ? M_PI / 2 : g->rot == 2 ? M_PI : 0);
    cairo_translate(c, -PW / 2, -PH / 2);
    /* hardware buttons, behind the frame */
    struct ch_hw hw[8]; int nhw = ch_hw_list(di, hw);
    double out = fmax(2.5, 3.5 * fmin(1, z * 1.4)), thick = out + 3;
    for (int i = 0; i < nhw; i++) {
        double x, y, w, h, len = hw[i].len * z, at = hw[i].at * z;
        if (hw[i].side == 2) { x = PW - g->outer_r - 30 * z - len; y = -out; w = len; h = thick; if (ch_is_pad(di)) x = PW - 157 * z; }
        else { x = hw[i].side ? PW - 3 : -out; y = at; w = thick; h = len; }
        ch_fill_round(c, x, y, w, h, 1.5, ch_hot(hw[i].id) ? C_OUTLINE : C_RIM);
        double x0, y0, x1, y1; ch_bz_xf(g, PW, PH, x, y, &x0, &y0); ch_bz_xf(g, PW, PH, x + w, y + h, &x1, &y1);
        ch_el(hw[i].id, fmin(x0, x1) - 3, fmin(y0, y1) - 3, fabs(x1 - x0) + 6, fabs(y1 - y0) + 6);
    }
    /* the frame: black glass inside a metal rim */
    ch_fill_round(c, 0, 0, PW, PH, g->outer_r, C_BEZEL);
    ch_stroke_round(c, 0, 0, PW, PH, g->outer_r, C_RIM, fmax(1.5, 2.2 * fmin(1, z)));
    if (portrait_dev.corner_radius <= 0 && !ch_is_pad(di)) {           /* iPhone SE: earpiece, camera, Home button */
        ch_fill_round(c, PW / 2 - 24 * z, t * 0.5 - 2.5 * z, 48 * z, 5 * z, 2.5 * z, C_RIM);
        cairo_arc(c, PW / 2 - 44 * z, t * 0.5, 4 * z, 0, 2 * M_PI); ch_rgb(c, C_RIM); cairo_fill(c);
        double hr = b * 0.31, hy = PH - b / 2;
        cairo_arc(c, PW / 2, hy, hr, 0, 2 * M_PI); cairo_set_source_rgb(c, 0.06, 0.06, 0.07); cairo_fill_preserve(c);
        ch_rgb(c, ch_hot("hw.home") ? C_OUTLINE : C_RIM); cairo_set_line_width(c, fmax(1, 1.6 * z)); cairo_stroke(c);
        double x0, y0, x1, y1; ch_bz_xf(g, PW, PH, PW / 2 - hr, hy - hr, &x0, &y0); ch_bz_xf(g, PW, PH, PW / 2 + hr, hy + hr, &x1, &y1);
        ch_el("hw.home", fmin(x0, x1), fmin(y0, y1), fabs(x1 - x0), fabs(y1 - y0));
    }
    if (ch_is_pad(di)) {                                                /* the front camera on the long edge (iPad Air M2) */
        cairo_arc(c, PW - r / 2, PH / 2, fmax(1.2, 2.5 * z), 0, 2 * M_PI); ch_rgb(c, C_RIM); cairo_fill(c);
    }
    cairo_restore(c);
}
static void ch_paint_screen(cairo_t *c, struct ch_geo *g, cairo_surface_t *screen, double k) {
    if (!screen) { cairo_rectangle(c, g->sx, g->sy, g->sw, g->sh); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c); return; }
    cairo_surface_flush(screen);
    int pw = cairo_image_surface_get_width(screen), ph = cairo_image_surface_get_height(screen);
    cairo_save(c);
    if (ch.on && ch.bezel) { ch_round(c, g->sx, g->sy, g->sw, g->sh, dev.corner_radius * zoom); cairo_clip(c); }
    cairo_translate(c, g->sx, g->sy); cairo_scale(c, g->sw / pw, g->sh / ph);
    cairo_set_source_surface(c, screen, 0, 0);
    cairo_pattern_set_filter(cairo_get_source(c), fabs(g->sw * k - pw) < 0.5 ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_GOOD);
    cairo_paint(c);
    cairo_restore(c);
    cairo_save(c); cairo_translate(c, g->sx, g->sy); cairo_scale(c, zoom, zoom); present_overlay(c); cairo_restore(c);
}
static void ch_paint_toast(cairo_t *c, struct ch_geo *g) {
    if (ch.toast_until <= now() || !ch.shot_ok) return;
    double inset = fmax(10, 16 * zoom), w = g->sw - 2 * inset, h = 34, x = g->sx + inset;
    double y = g->sy + g->sh - h - fmax(10, (dev.safe_bottom ? 24 : 12) * zoom);
    ch_round(c, x, y + 2, w, h, 10); cairo_set_source_rgba(c, 0, 0, 0, 0.25); cairo_fill(c);
    ch_round(c, x, y, w, h, 10); ch_rgba(c, C_TIP, 0.98); cairo_fill(c);
    static const double G[3] = { 30, 130, 60 };
    ch_icon(c, "check", x + 18, y + h / 2, 16, G, 1);
    const char *base = strrchr(ch.shot_path, '/'); base = base ? base + 1 : ch.shot_path;
    double tx = x + 34; tx += ch_text_at(c, "Saved ", tx, y + h / 2, 12.5, 400, 0, C_TIP_TEXT, 1, 0, 0);
    double showw = ch_text_w(c, "Show", 12.5, 700, 0);
    ch_text_at(c, base, tx, y + h / 2, 12.5, 400, 1, C_TIP_TEXT, 1, 3, x + w - 16 - showw - 8 - tx);
    ch_el("toast.show", x + w - 16 - showw - 6, y, showw + 22, h);
    ch_text_at(c, "Show", x + w - 16 - showw, y + h / 2, 12.5, 700, 0, C_LINK, 1, 0, 0);
}
static void ch_paint_tooltip(cairo_t *c, struct ch_geo *g) {
    if (!ch.hover[0] || ch.pop || ch.dialog || now() - ch.hover_t < 0.5) return;
    for (int i = 0; i < 6; i++) {
        if (strcmp(ch.hover, ch_tools[i].id)) continue;
        const char *tip = ch_tools[i].tip;
        if (!strcmp(ch_tools[i].id, "lock")) tip = ch_locked() ? "Unlock" : "Lock";
        if (!strcmp(ch_tools[i].id, "appearance")) tip = ch_dark() ? "Light appearance" : "Dark appearance";
        double tw = ch_text_w(c, tip, 12.5, 400, 0), kw = ch_tools[i].keys[0] ? 6 + ch_text_w(c, ch_tools[i].keys, 12, 400, 1) : 0;
        double w = tw + kw + 16, h = 23;
        double bx = -1;
        for (int e = 0; e < ch_nels; e++) if (!strcmp(ch_els[e].id, ch.hover)) bx = ch_els[e].x + ch_els[e].w / 2;
        if (bx < 0) return;
        double x = fmin(fmax(4, bx - w / 2), g->W - w - 4), y = CH_TB - 4;
        ch_round(c, x, y + 1, w, h, 6); cairo_set_source_rgba(c, 0, 0, 0, 0.3); cairo_fill(c);
        ch_fill_round(c, x, y, w, h, 6, C_TIP);
        ch_text_at(c, tip, x + 8, y + h / 2, 12.5, 400, 0, C_TIP_TEXT, 1, 0, 0);
        if (kw) ch_text_at(c, ch_tools[i].keys, x + 8 + tw + 6, y + h / 2, 12, 400, 1, C_TEXT3, 1, 0, 0);
        return;
    }
}

/* ---- the device menu ---- */
static const char *ch_curated[] = { "iphone15", "iphone16promax", "iphone17", "iphonese", "ipadair11" };
static const double ch_zooms[] = { 0.5, 0.75, 1, 1.25, 1.5, 2 };
static int ch_ndevices(void) { int n = 0; for (size_t i = 0; i < sizeof devices / sizeof *devices; i++) n += strcmp(devices[i].id, "ipad") != 0; return n; }
static void ch_device_menu_open(void) {
    ch.pick_dev = ch_cur_dev(); ch.pick_os = ch_cur_major(); ch.pick_zoom = zoom; ch.all_devices = 0;
}
static int ch_picks_changed(void) { return ch.pick_dev != ch_cur_dev() || ch.pick_os != ch_cur_major() || fabs(ch.pick_zoom - zoom) > 1e-6; }
static void ch_dev_hint(int di, char *h, size_t cap) {
    h[0] = 0;
    if (!ch_dev_ok(di, ch.pick_os)) snprintf(h, cap, "iOS %d+", ch_dev_min_major(di));
    else if (devices[di].d.corner_radius <= 0 && !ch_is_pad(di)) snprintf(h, cap, "Home button");
    else if (di == ch.pick_dev && !ch_is_pad(di)) snprintf(h, cap, "%s", devices[di].d.has_island == 1 ? "Dynamic Island" : devices[di].d.has_island == 2 ? "Notch" : "");
}
static double ch_pop_device(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += 16;
    ch_header(c, "DEVICE", x + 16, y); y += 22;
    if (!ch.all_devices) {
        int rows[8], n = 0, cur = ch.pick_dev, in = 0;
        for (size_t i = 0; i < sizeof ch_curated / sizeof *ch_curated; i++) if (device_index(ch_curated[i]) == cur) in = 1;
        if (!in) rows[n++] = cur;
        for (size_t i = 0; i < sizeof ch_curated / sizeof *ch_curated; i++) rows[n++] = device_index(ch_curated[i]);
        for (int i = 0; i < n; i++) {
            int di = rows[i]; char id[48], name[64], hint[32]; snprintf(id, sizeof id, "dev.%s", devices[di].id);
            ch_short_name(di, name, sizeof name); ch_dev_hint(di, hint, sizeof hint);
            ch_el(id, x + 8, y, w - 16, 32);
            if (di == cur || ch_hot(id)) ch_fill_round(c, x + 8, y, w - 16, 32, 7, di == cur ? C_ROW : C_HOVER);
            if (di == cur) ch_icon(c, "check", x + 23, y + 16, 15, C_ACCENT, 1);
            ch_text_at(c, name, x + 38, y + 16, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
            if (hint[0]) ch_text_at(c, hint, x, y + 16, 12.5, 400, 0, C_TEXT2, 1, 2, w - 17);
            y += 36;
        }
        char all[48]; snprintf(all, sizeof all, "All %d devices…", ch_ndevices());
        ch_el("dev.all", x + 8, y, w - 16, 32);
        if (ch_hot("dev.all")) ch_fill_round(c, x + 8, y, w - 16, 32, 7, C_HOVER);
        ch_text_at(c, all, x + 38, y + 16, CH_FONT, 400, 0, C_TEXT2, 1, 0, 0);
        y += 36;
    } else {                                        /* every preset, two columns */
        int col = 0; double cw = (w - 16) / 2;
        for (size_t i = 0; i < sizeof devices / sizeof *devices; i++) {
            if (!strcmp(devices[i].id, "ipad")) continue;
            int di = (int)i; char id[48], name[64]; snprintf(id, sizeof id, "dev.%s", devices[di].id); ch_short_name(di, name, sizeof name);
            double rx = x + 8 + col * cw;
            ch_el(id, rx, y, cw, 26);
            if (di == ch.pick_dev || ch_hot(id)) ch_fill_round(c, rx, y, cw - 2, 26, 6, di == ch.pick_dev ? C_ROW : C_HOVER);
            ch_text_at(c, name, rx + 10, y + 13, 12.5, 400, 0, C_TEXT, ch_dev_ok(di, ch.pick_os) ? 1 : 0.5, 3, cw - 14);
            if (col) y += 28;
            col = !col;
        }
        if (col) y += 28;
        y += 6;
    }
    ch_divider(c, x + 8, y + 2, w - 16); y += 14;
    ch_header(c, "IOS VERSION", x + 16, y); y += 22;
    double sw = (w - 24 - 3 * 4) / 4;
    for (int i = 0; i < 4; i++) {
        int m = isim_os_majors[i]; char id[16], lab[8]; snprintf(id, sizeof id, "os.%d", m); snprintf(lab, sizeof lab, "%d", m);
        double sx = x + 12 + i * (sw + 4); int ok = ch_dev_ok(ch.pick_dev, m), pick = m == ch.pick_os, nowv = m == ch_cur_major();
        if (ok) ch_el(id, sx, y, sw, 30);
        ch_fill_round(c, sx, y, sw, 30, 7, pick ? C_SEG_PICK : ch_hot(id) && ok ? C_HOVER : C_SEG);
        if (nowv && !pick) ch_stroke_round(c, sx, y, sw, 30, 7, C_OUTLINE, 1);
        const double *col = pick ? C_BACK : C_TEXT;
        double lw = ch_text_w(c, lab, CH_FONT, pick ? 700 : 400, 0), nw = nowv ? 4 + ch_text_w(c, "now", 10.5, 400, 0) : 0;
        double lx = sx + (sw - lw - nw) / 2;
        ch_text_at(c, lab, lx, y + 15, CH_FONT, pick ? 700 : 400, 0, col, ok ? 1 : 0.35, 0, 0);
        if (nowv) ch_text_at(c, "now", lx + lw + 4, y + 16, 10.5, 400, 0, pick ? C_BACK : C_TEXT2, 1, 0, 0);
    }
    y += 30 + 12;
    ch_divider(c, x + 8, y, w - 16); y += 10;
    ch_text_at(c, "Zoom", x + 16, y + 15, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
    char zl[16]; snprintf(zl, sizeof zl, "%d%%", (int)lround(ch.pick_zoom * 100));
    double px = x + w - 16 - 30;
    ch_el("zoom.plus", px, y + 1, 30, 28); ch_fill_round(c, px, y + 1, 30, 28, 7, ch_hot("zoom.plus") ? C_HOVER : C_SEG);
    ch_icon(c, "plus", px + 15, y + 15, 16, C_TEXT, ch.pick_zoom < 2 ? 1 : 0.35);
    ch_text_at(c, zl, px - 60, y + 15, 12.5, 400, 1, C_TEXT, 1, 1, 60);
    double mx = px - 60 - 30;
    ch_el("zoom.minus", mx, y + 1, 30, 28); ch_fill_round(c, mx, y + 1, 30, 28, 7, ch_hot("zoom.minus") ? C_HOVER : C_SEG);
    ch_icon(c, "minus", mx + 15, y + 15, 16, C_TEXT, ch.pick_zoom > 0.5 ? 1 : 0.35);
    y += 36;
    ch_el("bezel", x + 8, y, w - 16, 30);
    double bw = ch_text_at(c, "Show device bezel", x + 16, y + 15, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
    ch_text_at(c, "(no restart)", x + 16 + bw + 4, y + 15, CH_FONT, 400, 0, C_TEXT2, 1, 0, 0);
    ch_checkbox(c, x + w - 16 - 16, y + 7, ch.bezel);
    y += 30 + 8;
    ch_divider(c, x + 8, y, w - 16); y += 12;
    char foot[200], parts[3][64]; int np = 0;
    if (ch.pick_dev != ch_cur_dev()) ch_short_name(ch.pick_dev, parts[np++], sizeof parts[0]);
    if (ch.pick_os != ch_cur_major()) snprintf(parts[np++], sizeof parts[0], "iOS %d", ch.pick_os);
    if (fabs(ch.pick_zoom - zoom) > 1e-6) snprintf(parts[np++], sizeof parts[0], "%d%% zoom", (int)lround(ch.pick_zoom * 100));
    if (np == 0) snprintf(foot, sizeof foot, "Device, iOS and zoom apply after a restart.");
    else if (np == 1) snprintf(foot, sizeof foot, "%s picked. Device, iOS and zoom apply after a restart.", parts[0]);
    else if (np == 2) snprintf(foot, sizeof foot, "%s and %s picked. They apply after a restart.", parts[0], parts[1]);
    else snprintf(foot, sizeof foot, "%s, %s and %s picked. They apply after a restart.", parts[0], parts[1], parts[2]);
    double fh = ch_para(c, foot, x + 16, y, w - 32 - 80 - 12, 12, 400, 0, C_TEXT2, 0);
    double ah = 32, ay = y + fmax(0, (fh - ah) / 2);
    ch_button(c, "apply", x + w - 12 - 80, ay, 80, ah, "Apply…", 1, ch_picks_changed());
    y += fmax(fh, ah) + 12;
    return y - y0;
}

/* ---- the More menu ---- */
static const struct { const char *id, *label, *cmd; } ch_more[] = {
    { "more.shake", "Shake", "shake" }, { "more.location", "Location…", "location" }, { "more.openurl", "Open URL…", "openurl" },
    { "more.push", "Send push notification…", "push" }, { "more.memorywarning", "Memory warning", "memorywarning" },
};
static double ch_pop_more(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += 16;
    if (ch_layout().compact) {                       /* the compact toolbar has no Appearance button: here instead */
        const char *lab = ch_dark() ? "Light appearance" : "Dark appearance";
        ch_el("more.appearance", x + 6, y - 6, w - 12, 32);
        if (ch_hot("more.appearance")) ch_fill_round(c, x + 6, y - 6, w - 12, 32, 7, C_ROW);
        ch_icon(c, ch_dark() ? "sun" : "moon", x + 24, y + 10, 17, C_TEXT, 1);
        ch_text_at(c, lab, x + 40, y + 10, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
        ch_text_at(c, "appearance", x, y + 10, 11.5, 400, 1, C_TEXT2, 1, 2, w - 16);
        y += 32;
        ch_divider(c, x + 8, y, w - 16); y += 12;
    }
    ch_header(c, "SIMULATE", x + 16, y); y += 20;
    for (size_t i = 0; i < sizeof ch_more / sizeof *ch_more; i++) {
        ch_el(ch_more[i].id, x + 6, y, w - 12, 32);
        if (ch_hot(ch_more[i].id)) ch_fill_round(c, x + 6, y, w - 12, 32, 7, C_ROW);
        ch_text_at(c, ch_more[i].label, x + 16, y + 16, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
        ch_text_at(c, ch_more[i].cmd, x, y + 16, 11.5, 400, 1, C_TEXT2, 1, 2, w - 16);
        y += 33;
    }
    return y - y0 + 6;
}
static double ch_form_title(cairo_t *c, const char *title, double x, double y) {
    ch_el("back", x + 8, y + 8, 30, 30);
    if (ch_hot("back")) ch_fill_round(c, x + 8, y + 8, 30, 30, 7, C_HOVER);
    ch_icon(c, "chevron.left", x + 23, y + 23, 18, C_TEXT, 1);
    ch_text_at(c, title, x + 46, y + 24, 14, 700, 0, C_TEXT, 1, 0, 0);
    return 48;
}

/* ---- More > Location ---- */
static double ch_pop_location(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += ch_form_title(c, "Location", x, y);
    double lat, lon; char nowl[160];
    ch_fill_round(c, x + 12, y, w - 24, 30, 7, C_INSET);
    double tx = x + 22; tx += ch_text_at(c, "Now: ", tx, y + 15, 12.5, 400, 0, C_TEXT2, 1, 0, 0);
    if (ch_location(&lat, &lon)) {
        const char *name = NULL;
        for (int i = 0; i < 4; i++) if (fabs(lat - ch_places[i].lat) < 1e-4 && fabs(lon - ch_places[i].lon) < 1e-4) name = ch_places[i].name;
        if (name) { char sn[64]; snprintf(sn, sizeof sn, "%s", name); char *cm = strchr(sn, ','); if (cm) *cm = 0; tx += 4 + ch_text_at(c, sn, tx, y + 15, 12.5, 400, 0, C_TEXT, 1, 0, 0); }
        snprintf(nowl, sizeof nowl, "%.4f, %.4f", lat, lon);
        ch_text_at(c, nowl, tx, y + 15, 12, 400, 1, C_TEXT2, 1, 3, x + w - 20 - tx);
    } else ch_text_at(c, "no location", tx, y + 15, 12.5, 400, 0, C_TEXT, 1, 0, 0);
    y += 30 + 14;
    ch_header(c, "PLACES", x + 12, y); y += 20;
    for (int i = 0; i < 5; i++) {
        char id[16]; snprintf(id, sizeof id, "place.%d", i);
        ch_el(id, x + 12, y, w - 24, 31);
        if (ch.place == i || ch_hot(id)) ch_fill_round(c, x + 12, y, w - 24, 31, 7, ch.place == i ? C_ROW : C_HOVER);
        ch_radio(c, x + 26, y + 15.5, ch.place == i);
        ch_text_at(c, i < 4 ? ch_places[i].name : "Custom", x + 44, y + 15.5, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
        y += 34;
    }
    y += 4;
    double fw = (w - 24 - 8) / 2;
    ch_text_at(c, "Latitude", x + 12, y + 8, 12.5, 400, 0, C_TEXT2, 1, 0, 0);
    ch_text_at(c, "Longitude", x + 12 + fw + 8, y + 8, 12.5, 400, 0, C_TEXT2, 1, 0, 0);
    y += 20;
    ch_field_draw(c, "lat", x + 12, y, fw, 33); ch_field_draw(c, "lon", x + 12 + fw + 8, y, fw, 33);
    y += 33 + 8;
    y += ch_para(c, "Paste “lat, lon” from a map into either field. Apps that track location get the new position at once.",
                 x + 12, y, w - 24, 12, 400, 0, C_TEXT2, 0) + 12;
    ch_divider(c, x + 12, y, w - 24); y += 10;
    ch_button(c, "loc.none", x + 12, y, 90, 32, "No location", -1, 1);
    ch_button(c, "loc.set", x + w - 12 - 100, y, 100, 32, "Set location", 1, 1);
    y += 32 + 12;
    return y - y0;
}

/* ---- installed apps: names, bundle ids, URL schemes (CFBundleURLSchemes) and universal-link domains (applinks:),
   read from their Info.plist and entitlements files; nothing runs ---- */
struct ch_app { char bundle[160], name[96], schemes[512], links[512], icon[1200]; };
static struct ch_app ch_apps[48]; static int ch_napps;
static char *ch_slurp(const char *p, size_t *len) {
    FILE *f = fopen(p, "rb"); if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    if (n < 0 || n > (8 << 20)) { fclose(f); return NULL; }
    char *b = malloc((size_t)n + 1); if (!b) { fclose(f); return NULL; }
    size_t r = fread(b, 1, (size_t)n, f); fclose(f); b[r] = 0; if (len) *len = r;
    return b;
}
static int ch_plist_string(const char *xml, const char *key, char *out, size_t cap) {    /* <key>K</key> <string>V</string> */
    char k[96]; snprintf(k, sizeof k, "<key>%s</key>", key);
    const char *p = strstr(xml, k); if (!p) return 0;
    p += strlen(k); p += strspn(p, " \t\r\n");
    if (strncmp(p, "<string>", 8)) return 0;
    p += 8; const char *e = strstr(p, "</string>"); if (!e) return 0;
    snprintf(out, cap, "%.*s", (int)(e - p), p);
    return 1;
}
static void ch_applinks(const char *buf, size_t n, char *links, size_t cap) {
    for (const char *p = buf; (p = memmem(p, n - (size_t)(p - buf), "applinks:", 9)); ) {
        p += 9; size_t l = strcspn(p, "<\"' \t\r\n?/");
        if (l && strlen(links) + l + 2 < cap) { snprintf(links + strlen(links), cap - strlen(links), "%s%.*s", links[0] ? " " : "", (int)l, p); }
    }
}
static void ch_scan_app(const char *dir) {
    if (ch_napps >= 48) return;
    char p[1200]; snprintf(p, sizeof p, "%s/Info.plist", dir);
    size_t n = 0; char *x = ch_slurp(p, &n); if (!x) return;
    struct ch_app *a = &ch_apps[ch_napps]; memset(a, 0, sizeof *a);
    if (!ch_plist_string(x, "CFBundleIdentifier", a->bundle, sizeof a->bundle)) { free(x); return; }
    for (int i = 0; i < ch_napps; i++) if (!strcmp(ch_apps[i].bundle, a->bundle)) { free(x); return; }
    if (!ch_plist_string(x, "CFBundleDisplayName", a->name, sizeof a->name) && !ch_plist_string(x, "CFBundleName", a->name, sizeof a->name)) {
        const char *b = strrchr(dir, '/'); snprintf(a->name, sizeof a->name, "%s", b ? b + 1 : dir);
        char *dot = strstr(a->name, ".app"); if (dot) *dot = 0;
    }
    for (const char *s = x; (s = strstr(s, "<key>CFBundleURLSchemes</key>")); ) {
        s += 30; const char *end = strstr(s, "</array>"); if (!end) break;
        for (const char *q = s; (q = strstr(q, "<string>")) && q < end; ) {
            q += 8; const char *qe = strstr(q, "</string>"); if (!qe || qe > end) break;
            if (strlen(a->schemes) + (size_t)(qe - q) + 2 < sizeof a->schemes)
                snprintf(a->schemes + strlen(a->schemes), sizeof a->schemes - strlen(a->schemes), "%s%.*s", a->schemes[0] ? " " : "", (int)(qe - q), q);
            q = qe;
        }
    }
    ch_applinks(x, n, a->links, sizeof a->links);
    free(x);
    DIR *d = opendir(dir); struct dirent *de;                /* entitlements: *.entitlements, *.xcent */
    while (d && (de = readdir(d))) {
        size_t l = strlen(de->d_name);
        if ((l > 13 && !strcmp(de->d_name + l - 13, ".entitlements")) || (l > 6 && !strcmp(de->d_name + l - 6, ".xcent"))) {
            snprintf(p, sizeof p, "%s/%s", dir, de->d_name);
            char *e = ch_slurp(p, &n); if (e) { ch_applinks(e, n, a->links, sizeof a->links); free(e); }
        }
    }
    if (d) closedir(d);
    d = opendir(dir);                                         /* its icon: the largest AppIcon*.png */
    long best = 0;
    while (d && (de = readdir(d))) {
        size_t l = strlen(de->d_name); struct stat st;
        if (strncmp(de->d_name, "AppIcon", 7) || l < 5 || strcmp(de->d_name + l - 4, ".png")) continue;
        snprintf(p, sizeof p, "%s/%s", dir, de->d_name);
        if (!stat(p, &st) && st.st_size > best) { best = st.st_size; snprintf(a->icon, sizeof a->icon, "%s", p); }
    }
    if (d) closedir(d);
    ch_napps++;
}
static void ch_scan_apps(void) {
    ch_napps = 0;
    if (!shell_mode) ch_scan_app(isim_bundle_path());              /* the app alone (isim run) */
    const char *apps = getenv("ISIM_APPS");
    char def[1100]; if (!apps || !*apps) { ch_data_path(def, sizeof def, "Applications"); apps = def; }
    DIR *d = opendir(apps); struct dirent *de;
    char names[48][256]; int nn = 0;
    while (d && (de = readdir(d)) && nn < 48) { size_t l = strlen(de->d_name); if (l > 4 && !strcmp(de->d_name + l - 4, ".app")) snprintf(names[nn++], 256, "%s", de->d_name); }
    if (d) closedir(d);
    qsort(names, (size_t)nn, sizeof names[0], (int (*)(const void *, const void *))strcmp);
    for (int i = 0; i < nn; i++) { char p[1400]; snprintf(p, sizeof p, "%s/%s", apps, names[i]); ch_scan_app(p); }
    if (ch.push_app >= ch_napps) ch.push_app = 0;
}
/* why iOS would show no alert for a push to this app (its notification permission, kept in its preferences like
   UNUserNotificationCenter does), or NULL when it may */
static const char *ch_push_blocked(const char *bundle) {
    char rel[600], p[1200]; snprintf(rel, sizeof rel, "Containers/%s/Library/Preferences/%s.plist", bundle, bundle);
    ch_data_path(p, sizeof p, rel);
    size_t n = 0; char *x = ch_slurp(p, &n);
    int status = 0;
    const char *k = x ? strstr(x, "<key>_ISIMNotificationAuthorization</key>") : NULL;
    if (k) { k += 41; k += strspn(k, " \t\r\n"); if (!strncmp(k, "<integer>", 9)) status = atoi(k + 9); }
    free(x);
    if (status >= 2) return NULL;                    /* authorized, provisional, ephemeral */
    return status == 1 ? "has notifications turned off (Settings › Notifications): the push reaches the app, but iOS shows nothing."
                       : "has not asked to send notifications yet (requestAuthorization): the push reaches the app, but iOS shows nothing.";
}
static int ch_word_in(const char *list, const char *w, int wildcard) {
    char b[512]; snprintf(b, sizeof b, "%s", list);
    for (char *s, *t = strtok_r(b, " ", &s); t; t = strtok_r(NULL, " ", &s)) {
        if (!strcasecmp(t, w)) return 1;
        if (wildcard && !strncmp(t, "*.", 2)) { size_t lw = strlen(w), lt = strlen(t + 1); if (lw > lt && !strcasecmp(w + lw - lt, t + 1)) return 1; }
    }
    return 0;
}
/* which app a URL opens in: an installed app's index, -2 Safari (other web links), -1 none; *why: "myapp://" or the domain */
static int ch_url_target(const char *url, char *why, size_t cap) {
    why[0] = 0;
    const char *colon = strchr(url, ':'); if (!colon || colon == url) return -1;
    char scheme[64]; snprintf(scheme, sizeof scheme, "%.*s", (int)(colon - url), url);
    int web = !strcasecmp(scheme, "http") || !strcasecmp(scheme, "https");
    if (web) {
        const char *h = colon + 1; while (*h == '/') h++;
        char host[256]; snprintf(host, sizeof host, "%.*s", (int)strcspn(h, "/:?#"), h);
        if (!strcasecmp(scheme, "https"))
            for (int i = 0; i < ch_napps; i++) if (ch_word_in(ch_apps[i].links, host, 1)) { snprintf(why, cap, "%s", host); return i; }
        snprintf(why, cap, "%s", host);
        return -2;
    }
    for (int i = 0; i < ch_napps; i++) if (ch_word_in(ch_apps[i].schemes, scheme, 0)) { snprintf(why, cap, "%s://", scheme); return i; }
    return -1;
}
static double ch_pop_openurl(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += ch_form_title(c, "Open URL", x, y);
    ch_text_at(c, "URL", x + 12, y + 7, 12.5, 400, 0, C_TEXT2, 1, 0, 0); y += 18;
    ch_field_draw(c, "url", x + 12, y, w - 24, 35); y += 35 + 10;
    char why[256]; const char *url = ch_field("url")->buf;
    int t = url[0] ? ch_url_target(url, why, sizeof why) : -3;
    ch_fill_round(c, x + 12, y, w - 24, 38, 8, C_INSET);
    char *m = NULL;
    if (t >= 0) {
        cairo_surface_t *ic = ch_apps[t].icon[0] ? cairo_image_surface_create_from_png(ch_apps[t].icon) : NULL;
        if (ic && cairo_surface_status(ic) == CAIRO_STATUS_SUCCESS && cairo_image_surface_get_width(ic) > 0) {
            cairo_save(c); ch_round(c, x + 22, y + 8, 22, 22, 5.5); cairo_clip(c);
            double s = 22.0 / cairo_image_surface_get_width(ic);
            cairo_translate(c, x + 22, y + 8); cairo_scale(c, s, s); cairo_set_source_surface(c, ic, 0, 0);
            cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c); cairo_restore(c);
        } else ch_fill_round(c, x + 22, y + 8, 22, 22, 6, C_ACCENT);
        if (ic) cairo_surface_destroy(ic);
        char *nm = g_markup_escape_text(ch_apps[t].name, -1), *wy = g_markup_escape_text(why, -1);
        m = g_strdup_printf("Opens in <span foreground='#E8E8EC' weight='600'>%s</span>, which %s <span font_family='%s'>%s</span>",
                            nm, strstr(why, "://") ? "claims" : "has universal links for", SYSTEM_MONO, wy);
        g_free(nm); g_free(wy);
    } else if (t == -2) m = g_strdup("Opens in <span foreground='#E8E8EC' weight='600'>Safari</span>: no installed app claims this link");
    else if (t == -1) m = g_strdup("No installed app claims this URL scheme");
    else m = g_strdup("Type a URL, or pick a recent one");
    PangoLayout *l = ch_layout_text(c, "", 12.5, 400, 0, 0);
    pango_layout_set_markup(l, m, -1); pango_layout_set_width(l, (int)((w - 24 - (t >= 0 ? 52 : 20)) * PANGO_SCALE)); pango_layout_set_ellipsize(l, PANGO_ELLIPSIZE_END);
    PangoRectangle lg; pango_layout_get_extents(l, NULL, &lg);
    ch_rgb(c, C_TEXT2); cairo_move_to(c, x + (t >= 0 ? 52 : 22), y + 19 - lg.height / 2.0 / PANGO_SCALE); pango_cairo_show_layout(c, l); cairo_new_path(c);
    g_object_unref(l); g_free(m);
    y += 38 + 10;
    y += ch_para(c, "Custom schemes and universal links go to the app that claims them; other web links open in Safari.",
                 x + 12, y, w - 24, 12, 400, 0, C_TEXT2, 0) + 12;
    if (ch.recent[0][0]) {
        ch_header(c, "RECENT", x + 12, y); y += 20;
        for (int i = 0; i < 5 && ch.recent[i][0]; i++) {
            char id[16]; snprintf(id, sizeof id, "recent.%d", i);
            ch_el(id, x + 8, y, w - 16, 30);
            if (ch_hot(id)) ch_fill_round(c, x + 8, y, w - 16, 30, 7, C_HOVER);
            ch_text_at(c, ch.recent[i], x + 18, y + 15, 12, 400, 1, C_TEXT, 1, 3, w - 36);
            y += 32;
        }
        y += 4;
    }
    ch_divider(c, x + 12, y, w - 24); y += 10;
    ch_button(c, "url.cancel", x + w - 12 - 60 - 8 - 80, y, 80, 32, "Cancel", -1, 1);
    ch_button(c, "url.open", x + w - 12 - 60, y, 60, 32, "Open", 1, url[0] != 0);
    y += 32 + 12;
    return y - y0;
}

/* ---- More > Send push notification, and its help ---- */
static double ch_pop_push(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += ch_form_title(c, "Send push notification", x, y);
    ch_text_at(c, "App", x + 12, y + 7, 12.5, 400, 0, C_TEXT2, 1, 0, 0); y += 18;
    char appl[300];
    if (ch_napps) snprintf(appl, sizeof appl, "%s — %s", ch_apps[ch.push_app].name, ch_apps[ch.push_app].bundle);
    else snprintf(appl, sizeof appl, "No installed apps");
    ch_el("push.app", x + 12, y, w - 24, 33);
    ch_fill_round(c, x + 12, y, w - 24, 33, 7, C_INSET); ch_stroke_round(c, x + 12, y, w - 24, 33, 7, C_FIELD_LINE, 1);
    ch_text_at(c, appl, x + 24, y + 16.5, CH_FONT, 400, 0, ch_napps ? C_TEXT : C_TEXT2, 1, 3, w - 24 - 46);
    ch_icon(c, ch.app_list ? "chevron.up" : "chevron.down", x + w - 12 - 16, y + 16.5, 18, C_TEXT, 1);
    double app_y = y + 33;
    y += 33 + 10;
    const char *why = ch_napps ? ch_push_blocked(ch_apps[ch.push_app].bundle) : NULL;
    if (why) {                                       /* iOS shows nothing for an app not allowed to notify */
        static const double C_WARN[3] = { 240, 186, 92 };
        char note[300]; snprintf(note, sizeof note, "%s %s", ch_apps[ch.push_app].name, why);
        y += ch_para(c, note, x + 12, y - 4, w - 24, 12, 400, 0, C_WARN, 0) + 6;
    }
    ch_fill_round(c, x + 12, y, w - 24, 32, 8, C_INSET);
    double tw = (w - 24 - 4) / 2;
    for (int i = 0; i < 2; i++) {
        const char *id = i ? "tab.json" : "tab.alert"; double tx = x + 14 + i * tw;
        ch_el(id, tx, y + 2, tw, 28);
        if (ch.push_tab == i) ch_fill_round(c, tx, y + 2, tw, 28, 7, C_ROW);
        ch_text_at(c, i ? "JSON payload" : "Alert", tx, y + 16, CH_FONT, ch.push_tab == i ? 600 : 400, 0, ch.push_tab == i ? C_TEXT : C_TEXT2, 1, 1, tw);
    }
    y += 32 + 10;
    if (ch.push_tab == 0) {
        ch_text_at(c, "Title", x + 12, y + 7, 12.5, 400, 0, C_TEXT2, 1, 0, 0); y += 18;
        ch_field_draw(c, "title", x + 12, y, w - 24, 33); y += 33 + 10;
        ch_text_at(c, "Body", x + 12, y + 7, 12.5, 400, 0, C_TEXT2, 1, 0, 0); y += 18;
        ch_field_draw(c, "body", x + 12, y, w - 24, 51); y += 51 + 10;
        ch_text_at(c, "Badge", x + 12, y + 7, 12.5, 400, 0, C_TEXT2, 1, 0, 0); y += 18;
        double bw = (w - 24) / 2;
        ch_field_draw(c, "badge", x + 12, y, bw, 33);
        ch_el("push.sound", x + 12 + bw + 8, y, w - 24 - bw - 8, 33);
        ch_checkbox(c, x + 12 + bw + 8, y + 8.5, ch.push_sound);
        ch_text_at(c, "Sound", x + 12 + bw + 32, y + 16.5, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
        y += 33 + 10;
        const char *ids[2] = { "push.mutable", "push.available" }, *labs[2] = { "Mutable content", "Content available" },
                   *notes[2] = { "(runs the service extension)", "(background)" };
        int on[2] = { ch.push_mutable, ch.push_available };
        for (int i = 0; i < 2; i++) {
            ch_el(ids[i], x + 12, y, w - 24, 22);
            ch_checkbox(c, x + 12, y + 3, on[i]);
            double lw = ch_text_at(c, labs[i], x + 36, y + 11, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
            ch_text_at(c, notes[i], x + 36 + lw + 8, y + 11, 12, 400, 0, C_TEXT2, 1, 3, w - 24 - 36 - lw - 8);
            y += 23;
        }
        y += 6;
    } else {
        ch_field_draw(c, "json", x + 12, y, w - 24, 226); y += 226 + 10;
    }
    ch_divider(c, x + 12, y, w - 24); y += 10;
    double lw = ch_text_w(c, "Load .apns file…", CH_FONT, 400, 0) + 20;
    ch_button(c, "push.load", x + 12, y, lw, 32, "Load .apns file…", -1, 1);
    ch_el("push.help", x + 12 + lw + 2, y + 5, 22, 22);
    cairo_arc(c, x + 12 + lw + 13, y + 16, 10.5, 0, 2 * M_PI); ch_rgb(c, ch_hot("push.help") ? C_TEXT : C_TEXT2); cairo_set_line_width(c, 1.2); cairo_stroke(c);
    ch_text_at(c, "?", x + 12 + lw + 2, y + 16, 12, 700, 0, C_TEXT, 1, 1, 22);
    ch_button(c, "push.send", x + w - 12 - 60, y, 60, 32, "Send", 1, ch_napps > 0);
    y += 32 + 12;
    if (ch.app_list && ch_napps) {                   /* the app picker's list, over the form */
        double ly = app_y + 4, lh = ch_napps * 30 + 8;
        ch_panel(c, x + 12, ly, w - 24, lh);
        for (int i = 0; i < ch_napps; i++) {
            char id[24], l[300]; snprintf(id, sizeof id, "pushapp.%d", i); snprintf(l, sizeof l, "%s — %s", ch_apps[i].name, ch_apps[i].bundle);
            ch_el(id, x + 16, ly + 4 + i * 30, w - 32, 30);
            if (ch_hot(id) || i == ch.push_app) ch_fill_round(c, x + 16, ly + 4 + i * 30, w - 32, 30, 6, i == ch.push_app ? C_ROW : C_HOVER);
            ch_text_at(c, l, x + 26, ly + 19 + i * 30, 12.5, 400, 0, C_TEXT, 1, 3, w - 52);
        }
    }
    return y - y0;
}
static const char *CH_PUSH_DOCS = "https://github.com/kolabs-dev/isim/blob/main/docs/SCRIPTING.md#push-notifications";
static double ch_pop_pushhelp(cairo_t *c, double x, double y, double w) {
    double y0 = y; y += ch_form_title(c, "About push payloads", x, y) - 4;
    y += ch_para(c, "<b>Loading a file is optional.</b> The Alert tab builds the payload from the title, body, badge and options.",
                 x + 12, y, w - 24, CH_FONT, 400, 0, C_TEXT, 1) + 10;
    y += ch_para(c, "Load a file when you already have a payload, for example one you tested with Xcode’s Simulator or copied from your "
                    "server. It is JSON with an aps dictionary:", x + 12, y, w - 24, CH_FONT, 400, 0, C_TEXT2, 0) + 10;
    const char *bundle = ch_napps ? ch_apps[ch.push_app].bundle : "dev.example.myapp";
    char code[1024];
    snprintf(code, sizeof code, "{\n  \"Simulator Target Bundle\": \"%s\",\n  \"aps\": {\n    \"alert\": { \"title\": \"Your order is on its way\",\n"
             "               \"body\": \"Arrives today.\" },\n    \"badge\": 3,\n    \"sound\": \"default\"\n  }\n}", bundle);
    PangoLayout *l = ch_layout_text(c, code, 11.5, 400, 1, 0);
    pango_layout_set_spacing(l, (int)(3 * PANGO_SCALE));
    PangoRectangle lg; pango_layout_get_extents(l, NULL, &lg);
    double ch_h = lg.height / (double)PANGO_SCALE + 24;
    ch_fill_round(c, x + 12, y, w - 24, ch_h, 8, C_INSET); ch_stroke_round(c, x + 12, y, w - 24, ch_h, 8, C_PANEL_LINE, 1);
    cairo_save(c); cairo_rectangle(c, x + 13, y + 1, w - 26, ch_h - 2); cairo_clip(c);
    ch_rgb(c, C_TEXT); cairo_move_to(c, x + 24, y + 12); pango_cairo_show_layout(c, l); cairo_new_path(c); cairo_restore(c);
    g_object_unref(l);
    y += ch_h + 10;
    char t[512], *bm = g_markup_escape_text(bundle, -1);
    snprintf(t, sizeof t, "The file fills the JSON payload tab. You can also drop it on the device window, or run "
             "<span font_family='%s' foreground='#E8E8EC'>isim push %s payload.apns</span>.", SYSTEM_MONO, bm);
    g_free(bm);
    y += ch_para(c, t, x + 12, y, w - 24, CH_FONT, 400, 0, C_TEXT2, 1) + 12;
    ch_divider(c, x + 12, y, w - 24); y += 10;
    double dw = ch_text_w(c, "Push notifications in the docs", CH_FONT, 600, 0);
    ch_el("help.docs", x + 12, y, dw + 24, 32);
    ch_text_at(c, "Push notifications in the docs", x + 12, y + 16, CH_FONT, 600, 0, C_ACCENT, 1, 0, 0);
    ch_icon(c, "arrow.right", x + 12 + dw + 12, y + 16, 15, C_ACCENT, 1);
    ch_button(c, "help.back", x + w - 12 - 108, y, 108, 32, "Back to form", 1, 1);
    y += 32 + 12;
    return y - y0;
}

/* ---- the restart confirmation (requirement 4) ---- */
static void ch_paint_dialog(cairo_t *c, struct ch_geo *g) {
    cairo_rectangle(c, 0, 0, g->W, g->H); cairo_set_source_rgba(c, 0, 0, 0, 0.55); cairo_fill(c);
    ch_el("scrim", 0, 0, g->W, g->H);
    double w = fmin(340, g->W - 24), x = (g->W - w) / 2;
    cairo_push_group(c);
    double y = 0;
    ch_fill_round(c, 20, 20, 32, 32, 8, C_BTN);
    ch_icon(c, "power", 36, 36, 18, C_ACCENT, 1);
    ch_text_at(c, "Restart the device?", 62, 36, 15, 700, 0, C_TEXT, 1, 0, 0);
    y = 66;
    y += ch_para(c, "The simulator shuts down and boots again with the new settings. Running apps quit. Installed apps, their data and settings stay.",
                 20, y, w - 40, CH_FONT, 400, 0, C_TEXT, 0) + 14;
    /* what changes */
    char n0[64], n1[64], dv[160], ov[64], zv[64], dn[64] = "unchanged", on[64] = "unchanged", zn[64] = "unchanged";
    ch_short_name(ch_cur_dev(), n0, sizeof n0); ch_short_name(ch.pick_dev, n1, sizeof n1);
    int o0 = ch_cur_major(), o1 = ch.pick_os, z0 = (int)lround(zoom * 100), z1 = (int)lround(ch.pick_zoom * 100);
    if (ch.pick_dev != ch_cur_dev()) { snprintf(dv, sizeof dv, "%s → <b>%s</b>", n0, n1); dn[0] = 0; } else snprintf(dv, sizeof dv, "%s", n0);
    if (o1 != o0) {
        snprintf(ov, sizeof ov, "%d → <b>%d</b>", o0, o1);
        snprintf(on, sizeof on, "%s", (o0 < 26) != (o1 < 26) ? (o1 >= 26 ? "Liquid Glass" : "the iOS 17–18 look") : "");
    } else snprintf(ov, sizeof ov, "%d", o0);
    if (z1 != z0) { snprintf(zv, sizeof zv, "%d%% → <b>%d%%</b>", z0, z1); zn[0] = 0; } else snprintf(zv, sizeof zv, "%d%%", z0);
    const char *labs[3] = { "Device", "iOS", "Zoom" }, *vals[3] = { dv, ov, zv }, *notes[3] = { dn, on, zn };
    double rows_h = 3 * 24 + 16;
    ch_fill_round(c, 20, y, w - 40, rows_h, 8, C_INSET);
    double vx = 20 + 12 + 52, nx = vx;
    for (int i = 0; i < 3; i++) {
        PangoLayout *l = ch_layout_text(c, "", CH_FONT, 400, 0, 0); pango_layout_set_markup(l, vals[i], -1);
        int pw, ph; pango_layout_get_pixel_size(l, &pw, &ph); g_object_unref(l);
        if (vx + pw + 14 > nx) nx = vx + pw + 14;
    }
    for (int i = 0; i < 3; i++) {
        double ry = y + 8 + i * 24 + 12;
        ch_text_at(c, labs[i], 32, ry, CH_FONT, 400, 0, C_TEXT2, 1, 0, 0);
        PangoLayout *l = ch_layout_text(c, "", CH_FONT, 400, 0, 0); pango_layout_set_markup(l, vals[i], -1);
        PangoRectangle lg; pango_layout_get_extents(l, NULL, &lg);
        ch_rgb(c, C_TEXT); cairo_move_to(c, vx, ry - lg.height / 2.0 / PANGO_SCALE); pango_cairo_show_layout(c, l); cairo_new_path(c); g_object_unref(l);
        if (notes[i][0]) ch_text_at(c, notes[i], nx, ry, CH_FONT, 400, 0, C_TEXT2, 1, 3, w - 20 - 12 - nx);
    }
    y += rows_h + 14;
    ch_checkbox(c, 20, y + 3, ch.dialog_dontask);
    ch_text_at(c, "Don’t ask again", 46, y + 11, CH_FONT, 400, 0, C_TEXT, 1, 0, 0);
    double cb_y = y;
    y += 22 + 18;
    double rw = 76, cw = 64;
    double by = y;
    y += 34 + 18;
    cairo_pattern_t *content = cairo_pop_group(c);
    double h = y, top = fmax(CH_TB + 10, fmin(g->H * 0.3, g->H - h - 12));
    ch_panel(c, x, top, w, h);
    cairo_save(c); cairo_translate(c, x, top); cairo_set_source(c, content); cairo_paint(c); cairo_restore(c);
    cairo_pattern_destroy(content);
    ch_el("dialog.dontask", x + 20, top + cb_y, 160, 22);
    ch_button(c, "dialog.cancel", x + w - 20 - rw - 10 - cw, top + by, cw, 34, "Cancel", 0, 1);
    ch_button(c, "dialog.restart", x + w - 20 - rw, top + by, rw, 34, "Restart", 1, 1);
}

/* ---- a popover: content drawn into a group first (its height), then the panel and the content ---- */
static void ch_paint_popover(cairo_t *c, struct ch_geo *g) {
    double w, x;
    switch (ch.pop) {
    case CH_POP_DEVICE: w = 300; x = 6; break;
    case CH_POP_MORE: w = 272; x = g->W - 6 - w; break;
    case CH_POP_LOCATION: w = 320; x = g->W - 6 - w; break;
    default: w = 340; x = g->W - 6 - w; break;
    }
    if (w > g->W - 12) w = g->W - 12;
    if (x < 6) x = 6;
    double y = CH_TB + 4;
    int n0 = ch_nels;
    cairo_push_group(c);
    double h = ch.pop == CH_POP_DEVICE ? ch_pop_device(c, 0, 0, w) : ch.pop == CH_POP_MORE ? ch_pop_more(c, 0, 0, w)
             : ch.pop == CH_POP_LOCATION ? ch_pop_location(c, 0, 0, w) : ch.pop == CH_POP_OPENURL ? ch_pop_openurl(c, 0, 0, w)
             : ch.pop == CH_POP_PUSH ? ch_pop_push(c, 0, 0, w) : ch_pop_pushhelp(c, 0, 0, w);
    cairo_pattern_t *content = cairo_pop_group(c);
    for (int i = n0; i < ch_nels; i++) { ch_els[i].x += x; ch_els[i].y += y; }
    /* the panel goes under its controls: move their rects after a "pop" rect that takes the other clicks */
    int nc = ch_nels - n0; char tmp[160 * sizeof ch_els[0]]; memcpy(tmp, &ch_els[n0], (size_t)nc * sizeof ch_els[0]); ch_nels = n0;
    ch_el("pop", x, y, w, h);
    memcpy(&ch_els[ch_nels], tmp, (size_t)nc * sizeof ch_els[0]); ch_nels += nc;
    ch_panel(c, x, y, w, h);
    cairo_save(c); cairo_translate(c, x, y); cairo_set_source(c, content); cairo_paint(c); cairo_restore(c);
    cairo_pattern_destroy(content);
}

/* the whole window, in window points (c scaled by k) */
static void ch_paint(cairo_t *c, cairo_surface_t *screen, double k) {
    ch_init();
    struct ch_geo g = ch_layout();
    ch.W = g.W; ch.H = g.H;
    ch_nels = 0;
    cairo_save(c); cairo_set_operator(c, CAIRO_OPERATOR_SOURCE); ch_rgb(c, C_BACK); cairo_paint(c); cairo_restore(c);
    if (!ch.on) { ch_paint_screen(c, &g, screen, k); return; }
    if (ch.bezel) ch_paint_bezel(c, &g);
    ch_paint_screen(c, &g, screen, k);
    ch_paint_toast(c, &g);
    ch_paint_toolbar(c, &g);
    if (ch.pop) ch_paint_popover(c, &g);
    if (ch.dialog) ch_paint_dialog(c, &g);
    ch_paint_tooltip(c, &g);
}
static cairo_surface_t *ch_canvas;                  /* the window's frame, blitted to the SDL window surface */
static void ch_present(cairo_surface_t *screen) {
    if (headless || !win) return;
    SDL_Surface *ws = SDL_GetWindowSurface(win);
    if (!ws) {                                      /* nothing can be drawn: say so (once), never fail silently */
        static int told;
        if (!told++) fprintf(stderr, "isim window: no window surface (video driver %s): %s\n", SDL_GetCurrentVideoDriver(), SDL_GetError());
        return;
    }
    if (!ch_canvas || cairo_image_surface_get_width(ch_canvas) != ws->w || cairo_image_surface_get_height(ch_canvas) != ws->h) {
        if (ch_canvas) cairo_surface_destroy(ch_canvas);
        ch_canvas = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, ws->w, ws->h);
    }
    struct ch_geo g = ch_layout();
    struct ch_view v = ch_view_for(ws->w, ws->h, &g);          /* in pixels: one scale, centred */
    cairo_t *c = cairo_create(ch_canvas);
    cairo_translate(c, v.ox, v.oy);
    cairo_scale(c, v.k, v.k);
    ch_paint(c, screen, v.k);
    cairo_destroy(c);
    cairo_surface_flush(ch_canvas);
    SDL_Surface *src = SDL_CreateSurfaceFrom(ws->w, ws->h, SDL_PIXELFORMAT_ARGB8888, cairo_image_surface_get_data(ch_canvas), cairo_image_surface_get_stride(ch_canvas));
    if (src) { SDL_BlitSurface(src, NULL, ws, NULL); SDL_DestroySurface(src); }
    SDL_UpdateWindowSurface(win);
}
static void window_show(cairo_surface_t *screen) { ch_present(screen); }
static void window_redraw(void) { if (surf) ch_present(surf); }
/* `windowshot PATH`: the whole window as a PNG (also headless: drawn offscreen) */
static int ch_window_png(const char *path) {
    ch_init();
    struct ch_geo g = ch_layout();
    double k = win ? SDL_GetWindowPixelDensity(win) : (getenv("ISIM_SHOT_SCALE") ? atof(getenv("ISIM_SHOT_SCALE")) : 2);
    if (k <= 0) k = 2;
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int)ceil(g.W * k - 1e-6), (int)ceil(g.H * k - 1e-6));
    cairo_t *c = cairo_create(s); cairo_scale(c, k, k);
    ch_paint(c, surf, k);
    cairo_destroy(c);
    cairo_status_t st = cairo_surface_write_to_png(s, path);
    fprintf(stderr, "isim window: windowshot %s (%dx%d px): %s\n", path, cairo_image_surface_get_width(s), cairo_image_surface_get_height(s), cairo_status_to_string(st));
    cairo_surface_destroy(s);
    return st == CAIRO_STATUS_SUCCESS;
}
/* the element ids and rects of the current frame (headless: drawn offscreen first) */
static void ch_refresh_els(void) {
    /* at the scale the window draws at (ch_present): text measures differently at other scales (font hinting), so a
       wrapped panel's controls would sit elsewhere than shown (a window fitted to the screen or maximized: #652) */
    double k = 1;
    int pw = 0, ph = 0;
    if (win && SDL_GetWindowSizeInPixels(win, &pw, &ph) && pw > 0 && ph > 0) { struct ch_geo g = ch_layout(); k = ch_view_for(pw, ph, &g).k; }
    cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 8, 8);
    cairo_t *c = cairo_create(s); cairo_scale(c, k, k); ch_paint(c, surf, k); cairo_destroy(c); cairo_surface_destroy(s);
}

/* ---- actions: every control runs a script command through the dispatcher (chrome_run) ---- */
static void chrome_run(const char *cmd) {
    fprintf(stderr, "isim window: %s\n", cmd);
    control_poll();                                           /* (sets up the script buffer's length the first time) */
    /* next: before the rest of a running script (a `window tap` in a script runs its command right after it) */
    size_t n = strlen(cmd), off = script_pos ? (size_t)(script_pos - script) : script_len;
    int fresh = !script;                                      /* no script yet (the CLI and the launcher start none) */
    script = realloc(script, script_len + n + 3);
    if (fresh) script[script_len] = 0;                        /* the buffer is always terminated at script_len */
    memmove(script + off + n + 2, script + off, script_len - off + 1);
    script[off] = ';'; memcpy(script + off + 1, cmd, n); script[off + n + 1] = ';';
    script_len += n + 2;
    script_pos = script + off;
}
static void ch_open_path(const char *what) {                 /* the desktop opens a folder or a link */
    fprintf(stderr, "isim window: open %s\n", what);
    if (headless || !win) return;
    isim_open_on_desktop(what);
}
static int ch_tip_shown;
static void ch_set_hover(const char *id) {
    if (!id) id = "";
    if (strcmp(ch.hover, id)) { snprintf(ch.hover, sizeof ch.hover, "%s", id); ch.hover_t = now(); ch_tip_shown = 0; window_redraw(); }
}
static void ch_close_pop(void) {
    ch.pop = CH_POP_NONE; ch.app_list = 0; ch.focus[0] = 0; ch.select_all = 0;
    if (win && !shell_mode && !text_input_on) SDL_StopTextInput(win);
}
static void ch_focus(const char *id) {
    snprintf(ch.focus, sizeof ch.focus, "%s", id ? id : ""); ch.select_all = 0;
    struct ch_field *f = ch_field(ch.focus); if (f) f->cur = (int)strlen(f->buf);
    if (win && f) SDL_StartTextInput(win);
}
static void ch_location_fields(void) {
    double lat, lon; ch.place = -1;
    if (ch_location(&lat, &lon)) {
        char b[32]; snprintf(b, sizeof b, "%.6f", lat); ch_field_set("lat", b); snprintf(b, sizeof b, "%.6f", lon); ch_field_set("lon", b);
        ch.place = 4;
        for (int i = 0; i < 4; i++) if (fabs(lat - ch_places[i].lat) < 1e-4 && fabs(lon - ch_places[i].lon) < 1e-4) ch.place = i;
    }
}
static void ch_open(int pop) {
    if (pop == CH_POP_DEVICE) ch_device_menu_open();
    if (pop == CH_POP_LOCATION) ch_location_fields();
    if (pop == CH_POP_OPENURL || pop == CH_POP_PUSH || pop == CH_POP_PUSHHELP) ch_scan_apps();
    ch.pop = pop; ch.app_list = 0; ch.focus[0] = 0;
    if (pop == CH_POP_OPENURL) ch_focus("url");
}
static void ch_json_escape(const char *s, char *out, size_t cap) {
    size_t o = 0;
    for (; *s && o + 7 < cap; s++) {
        unsigned char ch_ = (unsigned char)*s;
        if (ch_ == '"' || ch_ == '\\') { out[o++] = '\\'; out[o++] = (char)ch_; }
        else if (ch_ == '\n') { out[o++] = '\\'; out[o++] = 'n'; }
        else if (ch_ < 0x20) o += (size_t)snprintf(out + o, cap - o, "\\u%04x", ch_);
        else out[o++] = (char)ch_;
    }
    out[o] = 0;
}
static void ch_alert_payload(char *out, size_t cap) {          /* the Alert tab as an .apns payload */
    char t[1024], b[4200], bundle[200] = "";
    ch_json_escape(ch_field("title")->buf, t, sizeof t); ch_json_escape(ch_field("body")->buf, b, sizeof b);
    if (ch_napps) ch_json_escape(ch_apps[ch.push_app].bundle, bundle, sizeof bundle);
    size_t o = (size_t)snprintf(out, cap, "{\n  \"Simulator Target Bundle\": \"%s\",\n  \"aps\": {\n    \"alert\": { \"title\": \"%s\", \"body\": \"%s\" }", bundle, t, b);
    const char *badge = ch_field("badge")->buf;
    if (*badge && o < cap) o += (size_t)snprintf(out + o, cap - o, ",\n    \"badge\": %d", atoi(badge));
    if (ch.push_sound && o < cap) o += (size_t)snprintf(out + o, cap - o, ",\n    \"sound\": \"default\"");
    if (ch.push_mutable && o < cap) o += (size_t)snprintf(out + o, cap - o, ",\n    \"mutable-content\": 1");
    if (ch.push_available && o < cap) o += (size_t)snprintf(out + o, cap - o, ",\n    \"content-available\": 1");
    if (o < cap) snprintf(out + o, cap - o, "\n  }\n}\n");
}
static void ch_load_apns(const char *path) {
    size_t n = 0; char *b = ch_slurp(path, &n);
    if (!b || n >= sizeof ch_fields[0].buf) { fprintf(stderr, "isim window: cannot load %s\n", path); free(b); return; }
    ch_field_set("json", b); ch.push_tab = 1;
    char tb[200];
    const char *k = strstr(b, "\"Simulator Target Bundle\"");
    if (k && sscanf(k + 25, " : \"%199[^\"]\"", tb) == 1) {
        if (!ch_napps) ch_scan_apps();
        for (int i = 0; i < ch_napps; i++) if (!strcmp(ch_apps[i].bundle, tb)) ch.push_app = i;
    }
    free(b);
    fprintf(stderr, "isim window: loaded %s into the JSON payload\n", path);
}
static pthread_mutex_t ch_dlg_lock = PTHREAD_MUTEX_INITIALIZER; static char ch_dlg_path[1024]; static int ch_dlg_ready;
static void ch_dlg_done(void *ud, const char *const *files, int filter) {    /* (any thread) */
    (void)ud; (void)filter;
    if (!files || !files[0]) return;
    pthread_mutex_lock(&ch_dlg_lock); snprintf(ch_dlg_path, sizeof ch_dlg_path, "%s", files[0]); ch_dlg_ready = 1; pthread_mutex_unlock(&ch_dlg_lock);
    isim_post_wakeup();
}
static int ch_parse_latlon(double *lat, double *lon) {
    const char *a = ch_field("lat")->buf, *b = ch_field("lon")->buf;
    if (sscanf(a, " %lf , %lf", lat, lon) == 2) return 1;          /* "lat, lon" pasted into one field */
    if (sscanf(b, " %lf , %lf", lat, lon) == 2) return 1;
    return sscanf(a, " %lf", lat) == 1 && sscanf(b, " %lf", lon) == 1;
}
static void ch_shot(void) {
    char dir[1024]; const char *d = getenv("ISIM_SCREENSHOT_DIR"), *home = getenv("HOME");
    if (d && *d) snprintf(dir, sizeof dir, "%s", d); else { snprintf(dir, sizeof dir, "%s/Pictures", home ? home : "."); mkdir(dir, 0755); }
    time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm);
    char p[1100]; snprintf(p, sizeof p, "%s/isim-%02d%02d.png", dir, tm.tm_hour, tm.tm_min);
    for (int i = 2; access(p, F_OK) == 0 && i < 100; i++) snprintf(p, sizeof p, "%s/isim-%02d%02d-%d.png", dir, tm.tm_hour, tm.tm_min, i);
    snprintf(ch.shot_path, sizeof ch.shot_path, "%s", p); ch.shot_t = now(); ch.shot_ok = 0;
    char cmd[1200]; snprintf(cmd, sizeof cmd, "shot %s", p); chrome_run(cmd);
}
static void ch_restart(int di, int major, double z);
static void ch_click(const char *id, int mods) {
    char cmd[1200];
    if (!id) return;
    fprintf(stderr, "isim window: click %s\n", id);
    if (!strcmp(id, "device")) { if (ch.pop == CH_POP_DEVICE) ch_close_pop(); else { ch_close_pop(); ch_open(CH_POP_DEVICE); } }
    else if (!strcmp(id, "more")) { if (ch.pop >= CH_POP_MORE) ch_close_pop(); else { ch_close_pop(); ch_open(CH_POP_MORE); } }
    else if (!strcmp(id, "home") || !strcmp(id, "hw.home")) chrome_run("home");
    else if (!strcmp(id, "lock") || !strcmp(id, "hw.side") || !strcmp(id, "hw.top")) chrome_run(ch_locked() ? "unlock" : "lock");
    else if (!strcmp(id, "rotate")) chrome_run(mods & SDL_KMOD_SHIFT ? "rotate right" : "rotate left");
    else if (!strcmp(id, "shot")) ch_shot();
    else if (!strcmp(id, "appearance")) chrome_run(ch_dark() ? "appearance light" : "appearance dark");
    else if (!strcmp(id, "hw.volup")) chrome_run("volume up");
    else if (!strcmp(id, "hw.voldown")) chrome_run("volume down");
    else if (!strcmp(id, "hw.action")) chrome_run("actionbutton");
    else if (!strcmp(id, "hw.silent")) chrome_run("silent");
    else if (!strcmp(id, "toast.show")) { char d[1024]; snprintf(d, sizeof d, "%s", ch.shot_path); char *s = strrchr(d, '/'); if (s) *s = 0; ch_open_path(d); }
    /* the device menu */
    else if (!strncmp(id, "dev.", 4)) {
        if (!strcmp(id + 4, "all")) ch.all_devices = 1;
        else { int di = device_index(id + 4); if (di >= 0) { ch.pick_dev = di; if (!ch_dev_ok(di, ch.pick_os)) ch.pick_os = ch_dev_min_major(di); } }
    }
    else if (!strncmp(id, "os.", 3)) { int m = atoi(id + 3); if (ch_dev_ok(ch.pick_dev, m)) ch.pick_os = m; }
    else if (!strcmp(id, "zoom.minus") || !strcmp(id, "zoom.plus")) {
        int n = (int)(sizeof ch_zooms / sizeof *ch_zooms);
        if (id[5] == 'm') { for (int i = n - 1; i >= 0; i--) if (ch_zooms[i] < ch.pick_zoom - 1e-6) { ch.pick_zoom = ch_zooms[i]; break; } }
        else for (int i = 0; i < n; i++) if (ch_zooms[i] > ch.pick_zoom + 1e-6) { ch.pick_zoom = ch_zooms[i]; break; }
    }
    else if (!strcmp(id, "bezel")) {
        ch.bezel = !ch.bezel; ch_save(); window_resize();
        fprintf(stderr, "isim window: bezel %s\n", ch.bezel ? "on" : "off");
    }
    else if (!strcmp(id, "apply")) {
        if (!ch_picks_changed()) return;
        if (ch.ask_restart) { ch_close_pop(); ch.dialog = 1; ch.dialog_dontask = 0; fprintf(stderr, "isim window: restart dialog\n"); }
        else ch_restart(ch.pick_dev, ch.pick_os, ch.pick_zoom);
    }
    else if (!strcmp(id, "dialog.dontask")) ch.dialog_dontask = !ch.dialog_dontask;
    else if (!strcmp(id, "dialog.cancel")) { ch.dialog = 0; fprintf(stderr, "isim window: restart cancelled\n"); }
    else if (!strcmp(id, "dialog.restart")) {
        ch.dialog = 0;
        if (ch.dialog_dontask) { ch.ask_restart = 0; ch_save(); }
        ch_restart(ch.pick_dev, ch.pick_os, ch.pick_zoom);
    }
    /* the More menu and its forms */
    else if (!strcmp(id, "more.shake")) { ch_close_pop(); chrome_run("shake"); }
    else if (!strcmp(id, "more.appearance")) { ch_close_pop(); chrome_run(ch_dark() ? "appearance light" : "appearance dark"); }
    else if (!strcmp(id, "more.memorywarning")) { ch_close_pop(); chrome_run("memorywarning"); }
    else if (!strcmp(id, "more.location")) ch_open(CH_POP_LOCATION);
    else if (!strcmp(id, "more.openurl")) ch_open(CH_POP_OPENURL);
    else if (!strcmp(id, "more.push")) ch_open(CH_POP_PUSH);
    else if (!strcmp(id, "back")) ch_open(ch.pop == CH_POP_PUSHHELP ? CH_POP_PUSH : CH_POP_MORE);
    else if (!strncmp(id, "field.", 6)) ch_focus(id + 6);
    else if (!strncmp(id, "place.", 6)) {
        ch.place = atoi(id + 6);
        if (ch.place < 4) { char b[32]; snprintf(b, sizeof b, "%.6f", ch_places[ch.place].lat); ch_field_set("lat", b); snprintf(b, sizeof b, "%.6f", ch_places[ch.place].lon); ch_field_set("lon", b); ch.focus[0] = 0; }
        else ch_focus("lat");
    }
    else if (!strcmp(id, "loc.none")) { ch_close_pop(); chrome_run("location none"); }
    else if (!strcmp(id, "loc.set")) {
        double lat, lon;
        if (!ch_parse_latlon(&lat, &lon) || fabs(lat) > 90 || fabs(lon) > 180) { fprintf(stderr, "isim window: enter a latitude and longitude\n"); return; }
        ch_close_pop(); snprintf(cmd, sizeof cmd, "location %.6f %.6f", lat, lon); chrome_run(cmd);
    }
    else if (!strncmp(id, "recent.", 7)) { int i = atoi(id + 7); if (i >= 0 && i < 5) { ch_field_set("url", ch.recent[i]); ch_focus("url"); } }
    else if (!strcmp(id, "url.cancel")) ch_close_pop();
    else if (!strcmp(id, "url.open")) {
        char url[512]; snprintf(url, sizeof url, "%s", ch_field("url")->buf);
        char *u = url; while (*u == ' ') u++;
        for (char *e = u + strlen(u) - 1; e >= u && (*e == ' ' || *e == '\n'); e--) *e = 0;
        if (!*u || strpbrk(u, " ;")) { fprintf(stderr, "isim window: not a URL: %s\n", u); return; }
        int k = 4; for (int i = 0; i < 5; i++) if (!strcmp(ch.recent[i], u)) k = i;            /* most recent first */
        memmove(ch.recent[1], ch.recent[0], (size_t)k * sizeof ch.recent[0]); snprintf(ch.recent[0], sizeof ch.recent[0], "%s", u);
        ch_save(); ch_close_pop();
        snprintf(cmd, sizeof cmd, "openurl %s", u); chrome_run(cmd);
    }
    else if (!strcmp(id, "push.app")) ch.app_list = !ch.app_list;
    else if (!strncmp(id, "pushapp.", 8)) { int i = atoi(id + 8); if (i >= 0 && i < ch_napps) ch.push_app = i; ch.app_list = 0; }
    else if (!strcmp(id, "tab.alert")) { ch.push_tab = 0; ch.focus[0] = 0; }
    else if (!strcmp(id, "tab.json")) {
        ch.push_tab = 1; ch.focus[0] = 0;
        if (!ch_field("json")->buf[0]) { char p[4096]; ch_alert_payload(p, sizeof p); ch_field_set("json", p); }
    }
    else if (!strcmp(id, "push.sound")) ch.push_sound = !ch.push_sound;
    else if (!strcmp(id, "push.mutable")) ch.push_mutable = !ch.push_mutable;
    else if (!strcmp(id, "push.available")) ch.push_available = !ch.push_available;
    else if (!strcmp(id, "push.load")) {
        static const SDL_DialogFileFilter flt[] = { { "Push payloads", "apns;json" } };
        if (win) SDL_ShowOpenFileDialog(ch_dlg_done, NULL, win, flt, 1, NULL, false);
        else fprintf(stderr, "isim window: no window for a file dialog (use `window load FILE`)\n");
    }
    else if (!strcmp(id, "push.help")) ch_open(CH_POP_PUSHHELP);
    else if (!strcmp(id, "help.back")) ch_open(CH_POP_PUSH);
    else if (!strcmp(id, "help.docs")) ch_open_path(CH_PUSH_DOCS);
    else if (!strcmp(id, "push.send")) {
        if (!ch_napps) return;
        char p[4096], path[1100];
        if (ch.push_tab) snprintf(p, sizeof p, "%s", ch_field("json")->buf); else ch_alert_payload(p, sizeof p);
        ch_data_path(path, sizeof path, "Library/isim"); mkdir(path, 0755);
        ch_data_path(path, sizeof path, "Library/isim/WindowPush.apns");
        FILE *f = fopen(path, "w"); if (!f) { fprintf(stderr, "isim window: cannot write %s\n", path); return; }
        fputs(p, f); fclose(f);
        ch_close_pop();
        const char *why = ch_push_blocked(ch_apps[ch.push_app].bundle);
        if (why) fprintf(stderr, "isim window: note: %s %s\n", ch_apps[ch.push_app].name, why);
        snprintf(cmd, sizeof cmd, "push %s %s", ch_apps[ch.push_app].bundle, path); chrome_run(cmd);
    }
    window_redraw();
}

/* ---- text fields ---- */
static const char *ch_form_fields(void) {
    return ch.pop == CH_POP_LOCATION ? "lat lon" : ch.pop == CH_POP_OPENURL ? "url" : ch.pop == CH_POP_PUSH ? (ch.push_tab ? "json" : "title body badge") : "";
}
static void ch_field_insert(const char *text) {
    struct ch_field *f = ch_field(ch.focus); if (!f) return;
    if (ch.select_all) { f->buf[0] = 0; f->cur = 0; ch.select_all = 0; }
    char t[2048]; size_t o = 0;
    for (const char *s = text; *s && o + 1 < sizeof t; s++) { if ((*s == '\n' || *s == '\r') && !f->multi) continue; t[o++] = *s; }
    t[o] = 0;
    size_t len = strlen(f->buf);
    if (len + o + 1 > sizeof f->buf) return;
    memmove(f->buf + f->cur + o, f->buf + f->cur, len - (size_t)f->cur + 1);
    memcpy(f->buf + f->cur, t, o); f->cur += (int)o;
    if (!strcmp(ch.focus, "lat") || !strcmp(ch.focus, "lon")) {           /* "lat, lon" pasted: split into both fields */
        double a, b; char x[64];
        if (sscanf(f->buf, " %lf , %lf %1s", &a, &b, x) == 2) {
            char v[32]; snprintf(v, sizeof v, "%.6f", a); ch_field_set("lat", v); snprintf(v, sizeof v, "%.6f", b); ch_field_set("lon", v);
        }
        ch.place = 4;
    }
}
static int ch_utf8_prev(const char *s, int i) { do i--; while (i > 0 && ((unsigned char)s[i] & 0xC0) == 0x80); return i < 0 ? 0 : i; }
static int ch_utf8_next(const char *s, int i) { if (!s[i]) return i; do i++; while (s[i] && ((unsigned char)s[i] & 0xC0) == 0x80); return i; }
/* a key in a form; returns 1 when handled */
static int ch_field_key(const char *key, int mods) {
    struct ch_field *f = ch_field(ch.focus);
    if (!strcmp(key, "escape")) { if (ch.app_list) ch.app_list = 0; else ch_close_pop(); return 1; }
    if (!strcmp(key, "tab")) {
        char list[64]; snprintf(list, sizeof list, "%s", ch_form_fields());
        char *names[4]; int n = 0; for (char *s, *t = strtok_r(list, " ", &s); t && n < 4; t = strtok_r(NULL, " ", &s)) names[n++] = t;
        if (!n) return 1;
        int i = 0; while (i < n && strcmp(names[i], ch.focus)) i++;
        ch_focus(names[i >= n ? 0 : (i + ((mods & SDL_KMOD_SHIFT) ? n - 1 : 1)) % n]);
        if (ch_field(ch.focus)) ch.select_all = 1;
        return 1;
    }
    if (!strcmp(key, "return")) {
        if (f && f->multi && !(mods & SDL_KMOD_CTRL)) { ch_field_insert("\n"); return 1; }
        ch_click(ch.pop == CH_POP_LOCATION ? "loc.set" : ch.pop == CH_POP_OPENURL ? "url.open" : ch.pop == CH_POP_PUSH ? "push.send" : NULL, 0);
        return 1;
    }
    if (!f) return 1;
    if (!strcmp(key, "selectall")) { ch.select_all = 1; f->cur = (int)strlen(f->buf); }
    else if (!strcmp(key, "backspace") || !strcmp(key, "delete")) {
        if (ch.select_all) { f->buf[0] = 0; f->cur = 0; ch.select_all = 0; return 1; }
        int a = key[0] == 'b' ? ch_utf8_prev(f->buf, f->cur) : f->cur, b = key[0] == 'b' ? f->cur : ch_utf8_next(f->buf, f->cur);
        if (b > a) { memmove(f->buf + a, f->buf + b, strlen(f->buf) - (size_t)b + 1); f->cur = a; }
        if (!strcmp(ch.focus, "lat") || !strcmp(ch.focus, "lon")) ch.place = 4;
    }
    else if (!strcmp(key, "left")) { ch.select_all = 0; f->cur = ch_utf8_prev(f->buf, f->cur); }
    else if (!strcmp(key, "right")) { ch.select_all = 0; f->cur = ch_utf8_next(f->buf, f->cur); }
    else if (!strcmp(key, "home")) { ch.select_all = 0; f->cur = 0; }
    else if (!strcmp(key, "end")) { ch.select_all = 0; f->cur = (int)strlen(f->buf); }
    else if (!strcmp(key, "paste")) { char *t = SDL_GetClipboardText(); if (t) { ch_field_insert(t); SDL_free(t); } }
    else if (!strcmp(key, "copy")) { if (ch.select_all) SDL_SetClipboardText(f->buf); }
    else if (!strcmp(key, "cut")) { if (ch.select_all) { SDL_SetClipboardText(f->buf); f->buf[0] = 0; f->cur = 0; ch.select_all = 0; } }
    else return 0;
    return 1;
}
static const char *ch_key_name(SDL_Keycode k, int mods) {
    int ctrl = (mods & SDL_KMOD_CTRL) != 0;
    if (ctrl && k == SDLK_A) return "selectall";
    if (ctrl && k == SDLK_V) return "paste";
    if (ctrl && k == SDLK_C) return "copy";
    if (ctrl && k == SDLK_X) return "cut";
    switch (k) {
    case SDLK_ESCAPE: return "escape"; case SDLK_TAB: return "tab"; case SDLK_RETURN: case SDLK_KP_ENTER: return "return";
    case SDLK_BACKSPACE: return "backspace"; case SDLK_DELETE: return "delete"; case SDLK_LEFT: return "left"; case SDLK_RIGHT: return "right";
    case SDLK_HOME: return "home"; case SDLK_END: return "end"; default: return NULL;
    }
}

/* ---- window input: the chrome first; the rest is mapped from window points to the screen's ---- */
static int ch_capture;                     /* the press began on the chrome: its moves and release stay here */
static int ch_in_popover_id(const char *id) {    /* drawn in the open popover (after its "pop" rect) */
    int p = -1;
    for (int i = 0; i < ch_nels; i++) { if (!strcmp(ch_els[i].id, "pop")) p = i; else if (p >= 0 && !strcmp(ch_els[i].id, id)) return 1; }
    return 0;
}
/* a click on an element (or on nothing: id NULL) */
static void ch_press(const char *id, int mods) {
    if (!id) { if (ch.pop) { ch_close_pop(); window_redraw(); } return; }      /* a click outside closes the menu */
    if (!strcmp(id, "pop") || !strcmp(id, "scrim")) { if (ch.app_list) { ch.app_list = 0; window_redraw(); } return; }
    if (ch.pop && strcmp(id, "device") && strcmp(id, "more") && !ch_in_popover_id(id)) ch_close_pop();
    ch_click(id, mods);
}
static int ch_in_screen(struct ch_geo *g, double x, double y) { return x >= g->sx && x < g->sx + g->sw && y >= g->sy && y < g->sy + g->sh; }
static const char *ch_hit(double x, double y) {
    const char *id = ch_el_at(x, y);
    return id;
}
static int chrome_sdl_event(SDL_Event *e, struct isim_event *ev) {
    (void)ev;
    ch_init();
    struct ch_geo g = ch_layout();
    struct ch_view v = ch_window_view(&g);                     /* window points -> layout points, as ch_present draws */
    switch (e->type) {
    case SDL_EVENT_MOUSE_MOTION:
        e->motion.x = (float)((e->motion.x - v.ox) / v.k); e->motion.y = (float)((e->motion.y - v.oy) / v.k);
        e->motion.xrel = (float)(e->motion.xrel / v.k); e->motion.yrel = (float)(e->motion.yrel / v.k); break;
    case SDL_EVENT_MOUSE_BUTTON_DOWN: case SDL_EVENT_MOUSE_BUTTON_UP:
        e->button.x = (float)((e->button.x - v.ox) / v.k); e->button.y = (float)((e->button.y - v.oy) / v.k); break;
    case SDL_EVENT_MOUSE_WHEEL:
        e->wheel.mouse_x = (float)((e->wheel.mouse_x - v.ox) / v.k); e->wheel.mouse_y = (float)((e->wheel.mouse_y - v.oy) / v.k); break;
    default: break;
    }
    int modal = ch.pop || ch.dialog;
    static int dbg = -1;
    if (dbg < 0) dbg = getenv("ISIM_WINDOW_DEBUG") && *getenv("ISIM_WINDOW_DEBUG") == '1';
    if (dbg && e->type != SDL_EVENT_USER)
        fprintf(stderr, "isim window: event %#x at %.0f,%.0f (on %s)\n", e->type, e->button.x, e->button.y,
                e->type == SDL_EVENT_MOUSE_BUTTON_DOWN || e->type == SDL_EVENT_MOUSE_BUTTON_UP ? (ch_el_at(e->button.x, e->button.y) ?: "-") : "-");
    switch (e->type) {
    case SDL_EVENT_MOUSE_MOTION: {
        double x = e->motion.x, y = e->motion.y;
        if (ch_capture) { const char *id = ch_hit(x, y); ch_set_hover(id && strcmp(id, "pop") && strcmp(id, "scrim") ? id : NULL); return 1; }
        if (button_down) { e->motion.x -= (float)g.sx; e->motion.y -= (float)g.sy; return 0; }   /* a drag on the screen */
        const char *id = ch_hit(x, y);
        ch_set_hover(id && strcmp(id, "pop") && strcmp(id, "scrim") ? id : NULL);
        if (!modal && !id && ch_in_screen(&g, x, y)) { e->motion.x -= (float)g.sx; e->motion.y -= (float)g.sy; return 0; }
        return 1; }
    case SDL_EVENT_MOUSE_BUTTON_DOWN: {
        double x = e->button.x, y = e->button.y;
        const char *id = ch_hit(x, y);
        if (!modal && !id && ch_in_screen(&g, x, y)) { e->button.x -= (float)g.sx; e->button.y -= (float)g.sy; return 0; }
        if (e->button.button == SDL_BUTTON_LEFT) { ch_capture = 1; snprintf(ch.pressed, sizeof ch.pressed, "%s", id ? id : ""); }
        return 1; }
    case SDL_EVENT_MOUSE_BUTTON_UP: {
        double x = e->button.x, y = e->button.y;
        if (!ch_capture) { e->button.x -= (float)g.sx; e->button.y -= (float)g.sy; return 0; }
        if (e->button.button != SDL_BUTTON_LEFT) return 1;
        ch_capture = 0;
        const char *id = ch_hit(x, y);
        if (id ? !strcmp(id, ch.pressed) : !ch.pressed[0]) ch_press(id, (int)SDL_GetModState());
        return 1; }
    case SDL_EVENT_MOUSE_WHEEL:
        if (!modal && ch_in_screen(&g, e->wheel.mouse_x, e->wheel.mouse_y)) { e->wheel.mouse_x -= (float)g.sx; e->wheel.mouse_y -= (float)g.sy; return 0; }
        return 1;
    case SDL_EVENT_WINDOW_MOUSE_LEAVE: ch_set_hover(NULL); return 0;
    case SDL_EVENT_KEY_DOWN: {
        if (ch.dialog) {
            if (e->key.key == SDLK_ESCAPE) ch_click("dialog.cancel", 0);
            else if (e->key.key == SDLK_RETURN || e->key.key == SDLK_KP_ENTER) ch_click("dialog.restart", 0);
            return 1;
        }
        if (!ch.pop) return 0;
        const char *k = ch_key_name(e->key.key, e->key.mod);
        if (k && ch_field_key(k, e->key.mod)) window_redraw();
        return 1; }
    case SDL_EVENT_KEY_UP: return modal;
    case SDL_EVENT_TEXT_INPUT:
        if (!modal) return 0;
        if (ch.pop && ch.focus[0] && e->text.text) { ch_field_insert(e->text.text); window_redraw(); }
        return 1;
    case SDL_EVENT_TEXT_EDITING: return modal;
    default: return 0;
    }
}

/* ---- restart with a new device, iOS version or zoom (the device menu's Apply…, `restart`): the device data stays ---- */
static void ch_restart(int di, int major, double z) {
    if (di < 0) di = ch_cur_dev();
    if (!ch_dev_ok(di, major)) { fprintf(stderr, "isim window: %s needs iOS %d or later\n", devices[di].d.name, ch_dev_min_major(di)); return; }
    char ver[16];
    const char *cur = getenv("ISIM_OS_VERSION");
    if (major == ch_cur_major() && cur && *cur) snprintf(ver, sizeof ver, "%s", cur);              /* keeps a point release */
    else if (major == devices[di].min_major && devices[di].min_minor) snprintf(ver, sizeof ver, "%d.%d", major, devices[di].min_minor);
    else snprintf(ver, sizeof ver, "%d.0", major);
    if (z < 0.25 || z > 4) z = zoom;
    char zs[32]; snprintf(zs, sizeof zs, "%g", z);
    fprintf(stderr, "isim window: restart: device %s, iOS %s, zoom %s\n", devices[di].id, ver, zs);
    setenv("ISIM_DEVICE", devices[di].id, 1); setenv("ISIM_OS_VERSION", ver, 1); setenv("ISIM_ZOOM", zs, 1);
    unsetenv("ISIM_SCRIPT"); unsetenv("ISIM_DEVICE_ORIENTATION"); unsetenv("ISIM_OS_DEFAULT");
    char p[1100]; ch_data_path(p, sizeof p, "Library/isim"); mkdir(p, 0755);
    ch_data_path(p, sizeof p, "Library/isim/os-version");               /* what `isim boot` remembers for the device data */
    FILE *f = fopen(p, "w"); if (f) { fprintf(f, "%s\n", ver); fclose(f); }
    ch_save();
    char args[8192]; char *argv[128];
    int argc = isim_self_args(args, sizeof args, argv, 128);
    if (argc <= 0) { fprintf(stderr, "isim window: cannot read the command line to restart\n"); return; }
    if (shell_mode) shell_quit();                                       /* running apps quit */
    if (win) { SDL_DestroyWindow(win); win = NULL; }
    SDL_Quit();
    isim_restart_self(argv);                                            /* (the control FIFO stays open across it) */
    fprintf(stderr, "isim window: restart failed: %s\n", strerror(errno));
    _exit(1);
}

/* ---- script commands: `window ...`, `windowshot PATH`, `restart [device=ID] [os=N] [zoom=Z]` ---- */
static void ch_trim(char *s) { char *b = s; while (*b == ' ') b++; memmove(s, b, strlen(b) + 1); for (char *e = s + strlen(s) - 1; e >= s && *e == ' '; e--) *e = 0; }
static void ch_log_state(void) {
    double lat, lon; char loc[64] = "none";
    if (ch_location(&lat, &lon)) snprintf(loc, sizeof loc, "%.6f %.6f", lat, lon);
    static const char *pops[] = { "none", "device", "more", "location", "openurl", "push", "pushhelp" };
    char n[64]; ch_short_name(ch_cur_dev(), n, sizeof n);
    struct ch_geo g = ch_layout();
    struct ch_view v = ch_window_view(&g);       /* the window shows the layout (points) at scale, centred (#652) */
    fprintf(stderr, "isim window: state appearance=%s locked=%d orientation=%s location=%s bezel=%d menu=%s dialog=%d device=%s ios=%d zoom=%g layout=%.0fx%.0f scale=%.3f\n",
            ch_dark() ? "dark" : "light", ch_locked(), ch_orient_name(dev.orientation ? dev.orientation : 1), loc, ch.bezel,
            pops[ch.pop], ch.dialog, devices[ch_cur_dev()].id, ch_cur_major(), zoom, g.W, g.H, v.k);
}
static int chrome_script_cmd(const char *cmd, const char *args) {
    char a[1024]; snprintf(a, sizeof a, "%.*s", (int)strcspn(args, ";"), args); ch_trim(a);
    if (!strcmp(cmd, "windowshot")) {
        if (!a[0]) { fprintf(stderr, "isim window: windowshot PATH\n"); return 1; }
        ch_window_png(a); return 1;
    }
    if (!strcmp(cmd, "restart")) {
        int di = ch_cur_dev(), major = ch_cur_major(); double z = zoom;
        char *s, *t, b[1024]; snprintf(b, sizeof b, "%s", a);
        for (t = strtok_r(b, " ", &s); t; t = strtok_r(NULL, " ", &s)) {
            if (!strncmp(t, "device=", 7)) { di = device_index(t + 7); if (di < 0) { fprintf(stderr, "isim window: unknown device %s\n", t + 7); return 1; } if (!strcmp(devices[di].id, "ipad")) di = device_index("ipadair11"); }
            else if (!strncmp(t, "os=", 3)) major = atoi(t + 3);
            else if (!strncmp(t, "zoom=", 5)) z = atof(t + 5);
        }
        int okm = 0; for (int i = 0; i < 4; i++) okm |= isim_os_majors[i] == major;
        if (!okm) { fprintf(stderr, "isim window: iOS %d is not supported (17, 18, 26 or 27)\n", major); return 1; }
        ch_restart(di, major, z);
        return 1;
    }
    if (strcmp(cmd, "window")) return 0;
    ch_init();
    char sub[32] = ""; int n = 0; sscanf(a, "%31s%n", sub, &n);
    char *rest = a + n; while (*rest == ' ') rest++;
    if (!strcmp(sub, "menu")) {
        static const char *pops[] = { "none", "device", "more", "location", "openurl", "push", "pushhelp" };
        int k = -1; for (int i = 0; i < 7; i++) if (!strcmp(rest, pops[i])) k = i;
        if (k < 0) fprintf(stderr, "isim window: menu none|device|more|location|openurl|push|pushhelp\n");
        else { ch_close_pop(); ch.dialog = 0; if (k) ch_open(k); }
    } else if (!strcmp(sub, "tap")) {
        ch_refresh_els();
        int found = 0; for (int i = 0; i < ch_nels; i++) found |= !strcmp(ch_els[i].id, rest);
        if (found) ch_press(rest, 0); else fprintf(stderr, "isim window: no control '%s' (`window els` lists them)\n", rest);
    } else if (!strcmp(sub, "click") || !strcmp(sub, "hover")) {
        double x, y; int shift = strstr(rest, "shift") != NULL;
        if (sscanf(rest, "%lf %lf", &x, &y) != 2) { fprintf(stderr, "isim window: %s X Y (window points)\n", sub); return 1; }
        ch_refresh_els();
        const char *id = ch_el_at(x, y);
        struct ch_geo g = ch_layout();
        if (!strcmp(sub, "hover")) { snprintf(ch.hover, sizeof ch.hover, "%s", id && strcmp(id, "pop") && strcmp(id, "scrim") ? id : ""); ch.hover_t = now() - 1; ch_tip_shown = 1; }
        else if (!id && !ch.pop && !ch.dialog && ch_in_screen(&g, x, y)) {        /* on the screen: a tap there */
            double px = (x - g.sx) / zoom, py = (y - g.sy) / zoom;
            pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = px, .y = py };
            pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = px, .y = py };
        } else { char idc[48]; snprintf(idc, sizeof idc, "%s", id ? id : ""); ch_press(id ? idc : NULL, shift ? SDL_KMOD_SHIFT : 0); }
    } else if (!strcmp(sub, "type")) {
        if (!ch_field(ch.focus)) fprintf(stderr, "isim window: no text field has focus\n");
        else { char t[1024]; size_t o = 0; for (const char *s = rest; *s && o + 1 < sizeof t; s++) { if (s[0] == '\\' && s[1] == ';') continue; t[o++] = *s; } t[o] = 0; ch_field_insert(t); }
    } else if (!strcmp(sub, "key")) {
        if (!ch.pop && !ch.dialog) fprintf(stderr, "isim window: no menu is open\n");
        else if (ch.dialog) ch_click(!strcmp(rest, "escape") ? "dialog.cancel" : "dialog.restart", 0);
        else if (!ch_field_key(rest, 0)) fprintf(stderr, "isim window: unknown key '%s'\n", rest);
    } else if (!strcmp(sub, "bezel")) {
        int on = !strcmp(rest, "on") ? 1 : !strcmp(rest, "off") ? 0 : !ch.bezel;
        if (on != ch.bezel) ch_click("bezel", 0);
    } else if (!strcmp(sub, "load")) {
        if (ch.pop != CH_POP_PUSH) ch_open(CH_POP_PUSH);
        ch_load_apns(rest);
    } else if (!strcmp(sub, "state")) ch_log_state();
    else if (!strcmp(sub, "els")) {
        ch_refresh_els();
        fprintf(stderr, "isim window: controls");
        for (int i = 0; i < ch_nels; i++) if (strcmp(ch_els[i].id, "pop") && strcmp(ch_els[i].id, "scrim"))
            fprintf(stderr, " %s@%.0f,%.0f", ch_els[i].id, ch_els[i].x + ch_els[i].w / 2, ch_els[i].y + ch_els[i].h / 2);
        fprintf(stderr, "\n");
    } else {
        fprintf(stderr, "isim window: unknown command '%s' (menu, tap, click, hover, type, key, bezel, load, state, els)\n", sub);
        return 1;
    }
    window_redraw();
    return 1;
}

/* ---- every turn of the event loop ---- */
static double ch_poll_t; static unsigned ch_sig;
static void chrome_tick(void) {
    if (!ch.init) return;
    double t = now();
    if (ch.shot_t && !ch.shot_ok) {
        if (access(ch.shot_path, F_OK) == 0) { ch.shot_ok = 1; ch.toast_until = t + 4; window_redraw(); }
        else if (t - ch.shot_t > 10) ch.shot_t = 0;
    }
    if (ch.toast_until && t >= ch.toast_until) { ch.toast_until = 0; ch.shot_t = 0; window_redraw(); }
    if (ch.hover[0] && !ch_tip_shown && t - ch.hover_t >= 0.5) { ch_tip_shown = 1; window_redraw(); }
    if (ch_dlg_ready) {
        char p[1024]; pthread_mutex_lock(&ch_dlg_lock); snprintf(p, sizeof p, "%s", ch_dlg_path); ch_dlg_ready = 0; pthread_mutex_unlock(&ch_dlg_lock);
        ch_load_apns(p); window_redraw();
    }
    if (win && t - ch_poll_t > 0.4) {               /* state changed elsewhere (Control Center, Settings, a file): draw it */
        ch_poll_t = t;
        char p[1100]; ch_data_path(p, sizeof p, "Library/isim/SimulatedLocation");
        unsigned sig = (unsigned)ch_dark() | (unsigned)ch_locked() << 1 | (unsigned)(ch_mtime(p) * 1000) << 2;
        if (sig != ch_sig) { ch_sig = sig; window_redraw(); }
    }
}
static int chrome_wait_ms(int ms) {
    if (!ch.init || !win) return ms;
    int cap = (ch.hover[0] && !ch_tip_shown) || ch.toast_until || (ch.shot_t && !ch.shot_ok) ? 50 : 400;
    return ms > cap ? cap : ms;
}
