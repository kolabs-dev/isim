/* isim shell ("SpringBoard host"): owns the window, runs every app as a child process.
 * Included by host.c (shares the device, window, script and screenshot code).
 *
 * - Each client renders into its own shared-memory surface (memfd) and tells the shell when a
 *   frame is ready; the shell shows the foreground client's surface.
 * - Input goes to the foreground client. Touches that start in the bottom 34 pt and swipe up
 *   (or Ctrl+Shift+H, or the script command "home") go to the home screen.
 * - Leaving an app sends it EV_BACKGROUND; a few seconds later the app is suspended (SIGSTOP) unless it reported
 *   something that keeps it running (shell_system.inc: background tasks, audio, location); any event for it resumes
 *   it (SIGCONT), so does a pending local notification coming due. ISIM_SUSPEND=0 never suspends.
 * - Clients ask to launch apps (SM_LAUNCH), report settings changes (broadcast as EV_SETTINGS),
 *   go home, or terminate the other apps (language changes). */

struct shell_client { pid_t pid; int sock; unsigned char *pixels; char bundle[512]; int alive, has_frame; char exe[512]; int relaunch, sysquit; int orient; int defer_edges; double defer_armed;
                      int bg, bg_seen, suspended; double bg_t, wake_at; char reasons[128];   /* background execution (shell_system.inc) */
                      int idle_disabled; };                                                    /* UIApplication.isIdleTimerDisabled (auto-lock) */
static struct shell_client clients[32];
static int nclients, active = -1;
static const char *shell_self, *shell_root, *shell_springboard;
static size_t surface_bytes;

/* the window takes the shape of the foreground client's interface orientation (the home screen is portrait) */
static int win_orient = 1;
static cairo_surface_t *comp;          /* composited frame (device pixels) */
static void client_dims(int i, int *w, int *h) {
    struct isim_device d = oriented(clients[i].orient > 0 ? clients[i].orient : 1);
    *w = (int)lround(d.width * px_scale); *h = (int)lround(d.height * px_scale);
}
static void shell_apply_orient(int o) {
    if (o < 1) o = 1;
    if (o == win_orient) return;
    win_orient = o;
    dev = oriented(o);
    surf_w = (int)lround(dev.width * px_scale); surf_h = (int)lround(dev.height * px_scale);
    if (comp) { cairo_surface_destroy(comp); comp = NULL; }
    if (win) SDL_SetWindowSize(win, (int)lround(dev.width * zoom), (int)lround(dev.height * zoom));
}
static void bg_track(int i, int type);           /* shell_system.inc: background state, suspension; resumes a suspended app */
static void shell_send(int i, int type) {
    if (i < 0 || i >= nclients || !clients[i].alive) return;
    bg_track(i, type);
    struct shell_msg m = { .type = SM_EVENT }; m.ev.type = type;
    send(clients[i].sock, &m, sizeof m, MSG_NOSIGNAL | (clients[i].suspended ? MSG_DONTWAIT : 0));
}
static void shell_forward(int i, const struct isim_event *ev) {
    if (i < 0 || i >= nclients || !clients[i].alive) return;
    bg_track(i, ev->type);
    struct shell_msg m = { .type = SM_EVENT }; m.ev = *ev;
    send(clients[i].sock, &m, sizeof m, MSG_NOSIGNAL | (clients[i].suspended ? MSG_DONTWAIT : 0));
}
static int nb_visible(void); static void nb_draw(void);
static int sys_visible(void); static void sys_draw(void); static int sys_hides_banners(void);   /* shell_system.inc */
static int la_island_visible(void); static int pill_visible(void);
static void shell_show(int i) {
    if (i < 0 || !clients[i].alive) return;
    if (sys_visible() || la_island_visible() || pill_visible()) { sys_draw(); return; }  /* lock screen, app switcher, Notification/Control Center, Dynamic Island, location indicator */
    shell_apply_orient(clients[i].orient);
    if (i == active && nb_visible()) { nb_draw(); return; }       /* a notification banner is on top */
    /* the screenshot / blit source is the foreground client's surface */
    if (cr) { cairo_destroy(cr); cr = NULL; }
    if (surf) cairo_surface_destroy(surf);
    surf = cairo_image_surface_create_for_data(clients[i].pixels, CAIRO_FORMAT_ARGB32, surf_w, surf_h, surf_w * 4);
    cr = cairo_create(surf);
    if (headless || !win) return;
    SDL_Surface *ws = SDL_GetWindowSurface(win);
    if (!ws) return;
    SDL_Surface *src = SDL_CreateSurfaceFrom(surf_w, surf_h, SDL_PIXELFORMAT_ARGB8888, clients[i].pixels, surf_w * 4);
    if (ws->w == surf_w && ws->h == surf_h) SDL_BlitSurface(src, NULL, ws, NULL);
    else SDL_BlitSurfaceScaled(src, NULL, ws, NULL, SDL_SCALEMODE_LINEAR);
    SDL_DestroySurface(src);
    present_overlay(ws);
    SDL_UpdateWindowSurface(win);
}

/* ---- app open / close animations (like iOS: apps zoom out of and back into their icons) ---- */
struct rectf { double x, y, w, h; };
struct icon_rect { char path[512]; struct rectf r; double radius; };
static struct icon_rect icons[256]; static int nicons;
enum { ANIM_NONE, ANIM_OPEN, ANIM_CLOSE, ANIM_BACK };
static struct { int kind, client; double t0, dur; struct rectf from, to; double rfrom, rto; } anim;
static int drag_active; static double drag_x0, drag_y0, drag_x, drag_y, drag_t, drag_vy, drag_moved_t;

static const struct icon_rect *icon_for(const char *path) {
    for (int i = 0; i < nicons; i++) if (!strcmp(icons[i].path, path)) return &icons[i];
    return NULL;
}
static void set_icon(const char *path, const char *geo) {
    struct icon_rect *ic = (struct icon_rect *)icon_for(path);
    if (!ic) { if (nicons >= 256) return; ic = &icons[nicons++]; snprintf(ic->path, sizeof ic->path, "%s", path); }
    sscanf(geo, "%lf %lf %lf %lf %lf", &ic->r.x, &ic->r.y, &ic->r.w, &ic->r.h, &ic->radius);
}
static struct rectf full_rect(void) { return (struct rectf){ 0, 0, dev.width, dev.height }; }
/* where an app's card ends up when it closes / starts when it opens */
static struct rectf icon_target(int i, double *radius) {
    const struct icon_rect *ic = i >= 0 ? icon_for(clients[i].bundle) : NULL;
    if (ic) { *radius = ic->radius; return ic->r; }
    *radius = 14;                        /* unknown icon: zoom to/from the screen centre */
    return (struct rectf){ dev.width / 2 - 30, dev.height / 2 - 30, 60, 60 };
}
static double ease_out(double t) { t = t < 0 ? 0 : t > 1 ? 1 : t; double u = 1 - t; return 1 - u * u * u * u; }
/* a lightly under-damped spring, like iOS app launches */
static double spring(double t) { t = t < 0 ? 0 : t > 1 ? 1 : t; return 1 - exp(-7.5 * t) * cos(4.0 * t); }
static struct rectf lerp_rect(struct rectf a, struct rectf b, double p) {
    return (struct rectf){ a.x + (b.x - a.x) * p, a.y + (b.y - a.y) * p, a.w + (b.w - a.w) * p, a.h + (b.h - a.h) * p };
}
static cairo_surface_t *client_surface(int i) {
    int w, h; client_dims(i, &w, &h);
    return cairo_image_surface_create_for_data(clients[i].pixels, CAIRO_FORMAT_ARGB32, w, h, w * 4);
}
static void present_comp(void) {
    if (cr) { cairo_destroy(cr); cr = NULL; }
    if (surf) cairo_surface_destroy(surf);
    surf = cairo_surface_reference(comp);           /* screenshots show the composited frame */
    cr = cairo_create(surf);
    if (headless || !win) return;
    SDL_Surface *ws = SDL_GetWindowSurface(win);
    if (!ws) return;
    SDL_Surface *src = SDL_CreateSurfaceFrom(surf_w, surf_h, SDL_PIXELFORMAT_ARGB8888, cairo_image_surface_get_data(comp), surf_w * 4);
    if (ws->w == surf_w && ws->h == surf_h) SDL_BlitSurface(src, NULL, ws, NULL);
    else SDL_BlitSurfaceScaled(src, NULL, ws, NULL, SDL_SCALEMODE_LINEAR);
    SDL_DestroySurface(src);
    present_overlay(ws);
    SDL_UpdateWindowSurface(win);
}
/* Home screen behind; the app as a rounded card in r (points). icon_alpha crossfades the icon in. */
static void compose(int app, struct rectf r, double radius, double app_alpha, double icon_alpha, double home_scale, struct rectf iconr) {
    if (!comp) comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, surf_w, surf_h);
    cairo_t *c = cairo_create(comp);
    cairo_set_source_rgb(c, 0, 0, 0); cairo_paint(c);
    cairo_scale(c, px_scale, px_scale);
    cairo_surface_t *home = client_surface(0);
    cairo_save(c);
    cairo_translate(c, dev.width / 2, dev.height / 2); cairo_scale(c, home_scale, home_scale); cairo_translate(c, -dev.width / 2, -dev.height / 2);
    cairo_scale(c, 1 / px_scale, 1 / px_scale);
    cairo_set_source_surface(c, home, 0, 0); cairo_paint(c);
    cairo_restore(c);
    if (app > 0 && r.w > 1 && r.h > 1) {
        cairo_save(c);
        double rad = fmin(radius, fmin(r.w, r.h) / 2);
        cairo_new_sub_path(c);
        cairo_arc(c, r.x + r.w - rad, r.y + rad, rad, -M_PI / 2, 0);
        cairo_arc(c, r.x + r.w - rad, r.y + r.h - rad, rad, 0, M_PI / 2);
        cairo_arc(c, r.x + rad, r.y + r.h - rad, rad, M_PI / 2, M_PI);
        cairo_arc(c, r.x + rad, r.y + rad, rad, M_PI, 1.5 * M_PI);
        cairo_close_path(c);
        cairo_clip(c);
        if (icon_alpha > 0.01 && iconr.w > 0) {          /* the icon, stretched to the card */
            cairo_save(c);
            cairo_translate(c, r.x, r.y); cairo_scale(c, r.w / iconr.w, r.h / iconr.h); cairo_translate(c, -iconr.x, -iconr.y);
            cairo_scale(c, 1 / px_scale, 1 / px_scale);
            cairo_set_source_surface(c, home, 0, 0);
            cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BILINEAR);
            cairo_paint_with_alpha(c, icon_alpha);
            cairo_restore(c);
        }
        if (app_alpha > 0.01 && clients[app].has_frame) {
            cairo_surface_t *as = client_surface(app);
            int aw, ah; client_dims(app, &aw, &ah);            /* the app may be turned while the screen is not */
            cairo_translate(c, r.x, r.y); cairo_scale(c, r.w / (aw / px_scale), r.h / (ah / px_scale));
            cairo_scale(c, 1 / px_scale, 1 / px_scale);
            cairo_set_source_surface(c, as, 0, 0);
            cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BILINEAR);
            cairo_paint_with_alpha(c, app_alpha);
            cairo_surface_destroy(as);
        }
        cairo_restore(c);
    }
    cairo_surface_destroy(home);
    cairo_destroy(c);
    present_comp();
}

static void start_anim(int kind, int client, struct rectf from, struct rectf to, double rfrom, double rto, double dur) {
    anim.kind = kind; anim.client = client; anim.t0 = now(); anim.dur = dur;
    anim.from = from; anim.to = to; anim.rfrom = rfrom; anim.rto = rto;
}
/* ---- notification banners posted by apps in the background (UserNotifications), drawn over the screen ---- */
/* client: the app's process, or -1 for an app that is not running (path: its bundle; a remote notification the system shows) */
static struct { int on, client; char path[512], id[512], title[512], body[512], icon[512], thumb[512]; double t0, hide_t0, down_t; struct rectf r; } nb;
#define NB_SHOW 5.0
static int nb_visible(void) { return nb.on && anim.kind == ANIM_NONE && active >= 0 && !sys_hides_banners(); }
/* field k (0-based) of a "\x1f"-separated string */
static void field(const char *s, int k, char *out, size_t n) {
    for (; k > 0 && s; k--) { s = strchr(s, '\x1f'); if (s) s++; }
    if (!s) { out[0] = 0; return; }
    size_t l = strcspn(s, "\x1f"); if (l >= n) l = n - 1;
    memcpy(out, s, l); out[l] = 0;
}
static void nb_show(int i, const char *path, const char *id, const char *icon, const char *title, const char *body, const char *thumb) {
    snprintf(nb.path, sizeof nb.path, "%s", path); snprintf(nb.id, sizeof nb.id, "%s", id); snprintf(nb.icon, sizeof nb.icon, "%s", icon ? icon : "");
    snprintf(nb.title, sizeof nb.title, "%s", title); snprintf(nb.body, sizeof nb.body, "%s", body); snprintf(nb.thumb, sizeof nb.thumb, "%s", thumb ? thumb : "");
    nb.on = 1; nb.client = i; nb.t0 = now(); nb.hide_t0 = 0; nb.down_t = 0;
    double w = fmin(dev.width - 16, 400);
    nb.r = (struct rectf){ (dev.width - w) / 2, fmax(dev.safe_top, 20) + 2, w, 76 };
    fprintf(stderr, "isim shell: notification banner from %s: %s\n", path, nb.title);
}
static void nb_post(int i, const struct shell_msg *m) {
    char id[512], icon[512], thumb[512];
    field(m->a, 0, id, sizeof id); field(m->a, 1, icon, sizeof icon); field(m->a, 3, thumb, sizeof thumb);
    nb_show(i, clients[i].bundle, id, icon, m->b, m->c, thumb);
}
static void nb_thumb(cairo_t *c, const char *path, double x, double y, double s);   /* shell_system.inc */
static void nb_text(cairo_t *c, const char *utf8, double x, double y, double w, double size, int bold, int lines, double gray, int center) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, SYSTEM_SANS);
    pango_font_description_set_absolute_size(fd, size * PANGO_SCALE);
    pango_font_description_set_weight(fd, bold ? PANGO_WEIGHT_SEMIBOLD : PANGO_WEIGHT_NORMAL);
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd);
    pango_layout_set_text(l, utf8, -1);
    pango_layout_set_width(l, (int)(w * PANGO_SCALE)); pango_layout_set_wrap(l, PANGO_WRAP_WORD_CHAR);
    pango_layout_set_height(l, -lines); pango_layout_set_ellipsize(l, PANGO_ELLIPSIZE_END);
    if (center) pango_layout_set_alignment(l, PANGO_ALIGN_CENTER);
    cairo_set_source_rgb(c, gray, gray, gray); cairo_move_to(c, x, y); pango_cairo_show_layout(c, l);
    g_object_unref(l);
}
static void nb_draw(void) {
    if (!comp) comp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, surf_w, surf_h);
    cairo_t *c = cairo_create(comp);
    cairo_surface_t *s = client_surface(active);
    cairo_set_operator(c, CAIRO_OPERATOR_SOURCE); cairo_set_source_surface(c, s, 0, 0); cairo_paint(c);
    cairo_surface_destroy(s);
    cairo_set_operator(c, CAIRO_OPERATOR_OVER);
    cairo_scale(c, px_scale, px_scale);
    double t = now() - nb.t0, off;                                   /* slide in, stay, slide out */
    if (nb.hide_t0 > 0) off = -(nb.r.y + nb.r.h + 12) * ease_out((now() - nb.hide_t0) / 0.3);
    else off = -(nb.r.y + nb.r.h + 12) * (1 - spring(t / 0.55));
    struct rectf r = nb.r; r.y += off;
    cairo_new_sub_path(c);
    double rad = 22;
    cairo_arc(c, r.x + r.w - rad, r.y + rad, rad, -M_PI / 2, 0); cairo_arc(c, r.x + r.w - rad, r.y + r.h - rad, rad, 0, M_PI / 2);
    cairo_arc(c, r.x + rad, r.y + r.h - rad, rad, M_PI / 2, M_PI); cairo_arc(c, r.x + rad, r.y + rad, rad, M_PI, 1.5 * M_PI);
    cairo_close_path(c);
    cairo_set_source_rgba(c, 0.96, 0.96, 0.97, 0.97); cairo_fill(c);
    double ix = r.x + 12, iy = r.y + (r.h - 38) / 2;
    cairo_surface_t *icon = nb.icon[0] ? cairo_image_surface_create_from_png(nb.icon) : NULL;
    cairo_save(c);
    cairo_new_sub_path(c);
    cairo_arc(c, ix + 38 - 9, iy + 9, 9, -M_PI / 2, 0); cairo_arc(c, ix + 38 - 9, iy + 38 - 9, 9, 0, M_PI / 2);
    cairo_arc(c, ix + 9, iy + 38 - 9, 9, M_PI / 2, M_PI); cairo_arc(c, ix + 9, iy + 9, 9, M_PI, 1.5 * M_PI);
    cairo_close_path(c); cairo_clip(c);
    if (icon && cairo_surface_status(icon) == CAIRO_STATUS_SUCCESS && cairo_image_surface_get_width(icon) > 0) {
        double sc = 38.0 / cairo_image_surface_get_width(icon);
        cairo_translate(c, ix, iy); cairo_scale(c, sc, sc);
        cairo_set_source_surface(c, icon, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_BILINEAR); cairo_paint(c);
    } else {
        cairo_set_source_rgb(c, 0.0, 0.48, 1.0); cairo_paint(c);
        nb_text(c, (const char[]){ nb.title[0] ? nb.title[0] : '?', 0 }, ix, iy + 8, 38, 18, 1, 1, 1, 1);
    }
    cairo_restore(c);
    if (icon) cairo_surface_destroy(icon);
    int th = nb.thumb[0] != 0;
    nb_text(c, nb.title, r.x + 60, r.y + 12, r.w - 120, 15, 1, 1, 0.0, 0);
    nb_text(c, "now", r.x + r.w - 54, r.y + 13, 40, 13, 0, 1, 0.45, 0);
    nb_text(c, nb.body, r.x + 60, r.y + 33, r.w - 74 - (th ? 46 : 0), 15, 0, 2, 0.0, 0);
    if (th) nb_thumb(c, nb.thumb, r.x + r.w - 14 - 38, r.y + r.h - 14 - 38, 38);
    cairo_destroy(c);
    present_comp();
}
static void nb_hide(void) { if (nb.on && !nb.hide_t0) nb.hide_t0 = now(); }
/* per loop iteration: animate, expire */
static void nb_tick(void) {
    if (!nb.on) return;
    if (nb.client >= nclients || (nb.client >= 0 && !clients[nb.client].alive)) { nb.on = 0; shell_show(active); return; }
    double t = now() - nb.t0;
    if (!nb.hide_t0 && t > NB_SHOW) nb_hide();
    if (nb.hide_t0 && now() - nb.hide_t0 > 0.3) { nb.on = 0; if (anim.kind == ANIM_NONE) shell_show(active); return; }
    if (nb_visible() && (t < 0.8 || nb.hide_t0)) nb_draw();
}
/* tapping the banner opens the app and delivers the response */
static int nc_find(const char *path, const char *id);
static void nc_open(int idx); static void nx_open_item(int idx);
static void nb_open(void) {
    int i = nb.client;
    nb.on = 0;
    if (i < 0) { int k = nc_find(nb.path, nb.id); if (k >= 0) nc_open(k); else shell_show(active); return; }   /* the app is not running */
    if (i >= nclients || !clients[i].alive) { shell_show(active); return; }
    fprintf(stderr, "isim shell: opened notification %s\n", nb.id);
    int from_home = active == 0;
    if (active != i) { if (active >= 0) shell_send(active, EV_BACKGROUND); active = i; shell_send(i, EV_FOREGROUND); }
    struct isim_event e = { .type = EV_NOTIFICATION_RESPONSE }; snprintf(e.text, sizeof e.text, "%s", nb.id);
    shell_forward(i, &e);
    double r0; struct rectf from = icon_target(i, &r0);
    if (from_home) start_anim(ANIM_OPEN, i, from, full_rect(), r0, dev.corner_radius, 0.5);
    else shell_show(i);
}
/* input over the banner: tap opens, swipe up dismisses; returns 1 when the event was the banner's */
static int nb_input(const struct isim_event *ev) {
    static int down; static double y0;
    if (!nb_visible() || nb.hide_t0) { down = 0; return 0; }
    if (ev->type == EV_DUMP) {          /* "dump" lists the banner too (the app's view tree follows); one line each */
        char title[512], body[512];
        snprintf(title, sizeof title, "%s", nb.title); snprintf(body, sizeof body, "%s", nb.body);
        for (char *q = title; *q; q++) if (*q == '\n') *q = ' ';
        for (char *q = body; *q; q++) if (*q == '\n') *q = ' ';
        fprintf(stderr, "IsimNotificationBanner (%g %g; %g x %g) id=isim-notification-banner notification=%s text=%s body=%s\n",
                nb.r.x, nb.r.y, nb.r.w, nb.r.h, nb.id, title, body);
        return 0;
    }
    /* a long press expands the notification (its actions, a Content extension's view) */
    if ((ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) && !strcmp(ev->text, "isim-notification-banner")) {
        if (ev->type == EV_ID_DOWN) nb.down_t = now();
        else if (nb.down_t && now() - nb.down_t >= 0.5) { nb.on = 0; int k = nc_find(nb.path, nb.id); if (k >= 0) nx_open_item(k); }
        else nb_open();
        return 1;
    }
    int inside = ev->x >= nb.r.x && ev->x <= nb.r.x + nb.r.w && ev->y >= nb.r.y && ev->y <= nb.r.y + nb.r.h;
    if (ev->type == EV_TOUCH_DOWN && inside) { down = 1; y0 = ev->y; nb.down_t = now(); return 1; }
    if (down && ev->type == EV_TOUCH_MOVE) return 1;
    if (down && ev->type == EV_TOUCH_UP) {
        down = 0;
        if (y0 - ev->y > 10) nb_hide();
        else if (now() - nb.down_t >= 0.5) { nb.on = 0; int k = nc_find(nb.path, nb.id); if (k >= 0) nx_open_item(k); }
        else nb_open();
        return 1;
    }
    return 0;
}
/* one animation frame; returns 0 when the animation has finished */
static int anim_frame(void) {
    if (anim.kind == ANIM_NONE) return 0;
    double t = (now() - anim.t0) / anim.dur;
    int app = anim.client;
    if (app < 0 || app >= nclients || !clients[app].alive) { anim.kind = ANIM_NONE; shell_show(active); return 0; }
    double iconr_dummy; struct rectf iconr = icon_target(app, &iconr_dummy);
    if (t >= 1) {
        int kind = anim.kind; anim.kind = ANIM_NONE;
        shell_show(kind == ANIM_CLOSE ? 0 : app);
        return 0;
    }
    if (anim.kind == ANIM_OPEN) {
        double p = spring(t);
        compose(app, lerp_rect(anim.from, anim.to, p), anim.rfrom + (anim.rto - anim.rfrom) * p,
                fmin(1, t * 3.5), 1 - fmin(1, t * 3.5), 1 + 0.06 * ease_out(t), iconr);
    } else if (anim.kind == ANIM_CLOSE) {
        double p = ease_out(t);
        compose(app, lerp_rect(anim.from, anim.to, p), anim.rfrom + (anim.rto - anim.rfrom) * p,
                1 - fmax(0, (t - 0.55) / 0.45), fmax(0, (t - 0.45) / 0.55), 1.06 - 0.06 * p, iconr);
    } else {   /* spring back to full screen after an aborted swipe */
        double p = ease_out(t);
        compose(app, lerp_rect(anim.from, anim.to, p), anim.rfrom + (anim.rto - anim.rfrom) * p, 1, 0, 1.06, iconr);
    }
    return 1;
}
/* card geometry while the home gesture follows the finger */
static struct rectf drag_rect(double *radius) {
    double d = fmax(0, drag_y0 - drag_y);
    double p = fmin(1, d / (dev.height * 0.55));
    double scale = 1 - 0.55 * p;
    double w = dev.width * scale, h = dev.height * scale;
    double cx = dev.width / 2 + (drag_x - drag_x0) * 0.6;
    double bottom = dev.height - d * 1.05;
    *radius = dev.corner_radius + (28 - dev.corner_radius) * p;
    return (struct rectf){ cx - w / 2, bottom - h, w, h };
}
static int shell_find(const char *bundle) {
    for (int i = 0; i < nclients; i++) if (clients[i].alive && !strcmp(clients[i].bundle, bundle)) return i;
    return -1;
}
static void shell_activate(int i) {
    if (i == active) { shell_send(i, EV_REDRAW); return; }
    if (active >= 0) shell_send(active, EV_BACKGROUND);
    active = i;
    shell_send(i, EV_FOREGROUND);
    shell_show(i);
}
static int spawn_background;  /* shell_system.inc: the next spawn starts the app in the background */
static char **open_args;      /* launch arguments for the app opened at boot (isim run) */
static int open_slot = -1;    /* that app: when it exits by itself, the run ends with its exit code */
static int shell_spawn_at(int slot, const char *bundle, const char *exe, const char *url) {
    if (slot < 0 && nclients >= (int)(sizeof clients / sizeof *clients)) { fprintf(stderr, "isim shell: too many apps\n"); return -1; }
    int sv[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, sv)) { perror("isim shell: socketpair"); return -1; }
    int mfd = memfd_create("isim-surface", MFD_CLOEXEC);
    if (mfd < 0 || ftruncate(mfd, (off_t)surface_bytes)) { perror("isim shell: memfd"); return -1; }
    unsigned char *px = mmap(NULL, surface_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, mfd, 0);
    if (px == MAP_FAILED) { perror("isim shell: mmap"); return -1; }
    memset(px, 0, surface_bytes);
    pid_t pid = fork();
    if (pid < 0) { perror("isim shell: fork"); return -1; }
    if (pid == 0) {
        close(sv[0]);
        fcntl(sv[1], F_SETFD, 0); fcntl(mfd, F_SETFD, 0);
        char b1[16], b2[16], b3[32];
        snprintf(b1, sizeof b1, "%d", sv[1]); snprintf(b2, sizeof b2, "%d", mfd); snprintf(b3, sizeof b3, "%g", px_scale);
        setenv("ISIM_CLIENT_SOCK", b1, 1); setenv("ISIM_CLIENT_SURFACE", b2, 1); setenv("ISIM_CLIENT_SCALE", b3, 1);
        unsetenv("ISIM_SCRIPT"); unsetenv("ISIM_HEADLESS"); unsetenv("ISIM_CONTROL");
        if (url && *url) setenv("ISIM_LAUNCH_URL", url, 1); else unsetenv("ISIM_LAUNCH_URL");
        if (spawn_background) setenv("ISIM_LAUNCH_BACKGROUND", "1", 1); else unsetenv("ISIM_LAUNCH_BACKGROUND");
        char ob[8]; snprintf(ob, sizeof ob, "%d", device_orient); setenv("ISIM_DEVICE_ORIENTATION", ob, 1);
        char *av[64]; int n = 0;
        av[n++] = (char *)shell_self; av[n++] = "--root"; av[n++] = (char *)shell_root; av[n++] = (char *)exe;
        if (open_args && slot < 0 && nclients > 0 && !strcmp(bundle, open_args[0]))
            for (char **a = open_args + 2; *a && n < 63; a++) av[n++] = *a;
        av[n] = NULL;
        execv(shell_self, av);
        perror("isim shell: exec"); _exit(127);
    }
    close(sv[1]); close(mfd);
    int idx = slot >= 0 ? slot : nclients;
    struct shell_client *c = &clients[idx];
    if (slot >= 0 && c->pixels) munmap(c->pixels, surface_bytes);
    *c = (struct shell_client){ .pid = pid, .sock = sv[0], .pixels = px, .alive = 1, .orient = 1 };
    if (spawn_background) { c->bg = 1; c->bg_t = now(); }       /* launched into the background: it can be suspended */
    snprintf(c->bundle, sizeof c->bundle, "%s", bundle);
    snprintf(c->exe, sizeof c->exe, "%s", exe);
    fprintf(stderr, "isim shell: launched %s (pid %d)\n", bundle, pid);
    return slot >= 0 ? slot : nclients++;
}
static int shell_spawn(const char *bundle, const char *exe, const char *url) { return shell_spawn_at(-1, bundle, exe, url); }
static void shell_launch(const char *bundle, const char *exe, const char *url) {
    int from_home = active == 0;
    int i = shell_find(bundle);
    if (i >= 0) {
        if (active >= 0 && active != i) shell_send(active, EV_BACKGROUND);
        active = i;
        shell_send(i, EV_FOREGROUND);
        if (url && *url) { struct isim_event e = { .type = EV_OPEN_URL }; snprintf(e.text, sizeof e.text, "%s", url); shell_forward(i, &e); }
    } else {
        i = shell_spawn(bundle, exe, url);
        if (i < 0) return;
        if (active >= 0) shell_send(active, EV_BACKGROUND);
        active = i;
    }
    double r0; struct rectf from = icon_target(i, &r0);
    if (from_home || icon_for(bundle)) start_anim(ANIM_OPEN, i, from, full_rect(), r0, dev.corner_radius, 0.5);
    else shell_show(i);
}
/* go home, shrinking the app card from `from` into its icon */
static void shell_home_from(struct rectf from, double radius) {
    if (active <= 0) return;
    fprintf(stderr, "isim shell: home\n");
    int app = active;
    shell_send(app, EV_BACKGROUND);
    active = 0;
    shell_send(0, EV_FOREGROUND);
    if (win_orient != 1) { shell_apply_orient(1); from = full_rect(); radius = dev.corner_radius; }   /* the home screen is upright */
    double r1; struct rectf to = icon_target(app, &r1);
    start_anim(ANIM_CLOSE, app, from, to, radius, r1, 0.42);
}
static void shell_home(void) { shell_home_from(full_rect(), dev.corner_radius); }
static void shell_quit(void) {
    for (int i = 0; i < nclients; i++) shell_send(i, EV_QUIT);
    double until = now() + 2;
    for (int i = 0; i < nclients; i++) {
        while (clients[i].alive && now() < until) {
            if (waitpid(clients[i].pid, NULL, WNOHANG) == clients[i].pid) clients[i].alive = 0;
            else { struct timespec ts = { 0, 10000000 }; nanosleep(&ts, NULL); }
        }
        if (clients[i].alive) kill(clients[i].pid, SIGKILL);
    }
}

#include "shell_system.inc"

/* one client message */
static void shell_handle(int i, const struct shell_msg *m) {
    switch (m->type) {
    case SM_FRAME:
        clients[i].has_frame = 1;
        if (i == active && anim.kind == ANIM_NONE && !drag_active) shell_show(i);
        break;
    case SM_ICON: set_icon(m->a, m->b); break;
    case SM_ORIENT:
        clients[i].orient = atoi(m->a);
        if (i == active && anim.kind == ANIM_NONE && !drag_active) shell_show(i);
        break;
    case SM_NOTIFY: sys_notify(i, m); break;
    case SM_DEFER_EDGES: clients[i].defer_edges = atoi(m->a); clients[i].defer_armed = 0; break;
    case SM_SYSTEM: sys_handle_msg(i, m); break;
    case SM_LAUNCH: shell_launch(m->a, m->b, m->c); break;
    case SM_HOME: shell_home(); break;
    case SM_SETTINGS:
        for (int k = 0; k < nclients; k++) if (k != i) shell_send(k, EV_SETTINGS);
        break;
    case SM_TERMINATE_OTHERS:                         /* e.g. after a language change, like iOS */
        for (int k = 1; k < nclients; k++) if (k != i && clients[k].alive) { clients[k].sysquit = 1; shell_send(k, EV_QUIT); }
        break;
    case SM_RESTART_SYSTEM:                           /* language change: like iOS, the UI restarts */
        for (int k = 0; k < nclients; k++) if (clients[k].alive) {
            if (k == 0 || k == i) clients[k].relaunch = 1; else clients[k].sysquit = 1;
            shell_send(k, EV_QUIT);
        }
        break;
    case SM_TERMINATE_APP: {                          /* the app is being deleted */
        int k = shell_find(m->a);
        if (k > 0) { clients[k].sysquit = 1; shell_send(k, EV_QUIT); if (k == active) { active = -1; shell_activate(0); } }
        break; }
    default: break;
    }
}

int isim_shell_main(const char *self, const char *root, const char *springboard_bundle, const char *springboard_exe, char **open) {
    open_args = open && open[0] && open[1] ? open : NULL;
    shell_self = self; shell_root = root; shell_springboard = springboard_bundle; shell_mode = 1;
    signal(SIGPIPE, SIG_IGN);
    if (!dev.width) device_from_env();
    t0 = now();
    headless = getenv("ISIM_HEADLESS") && atoi(getenv("ISIM_HEADLESS"));
    if (getenv("ISIM_SCRIPT")) { script = strdup(getenv("ISIM_SCRIPT")); script_pos = script; }
    if (!headless && !SDL_Init(SDL_INIT_VIDEO)) { fprintf(stderr, "isim shell: SDL_Init failed: %s (headless)\n", SDL_GetError()); headless = 1; }
    if (!headless) {
        char t[256]; snprintf(t, sizeof t, "%s (isim)", dev.name);
        win = SDL_CreateWindow(t, (int)lround(dev.width * zoom), (int)lround(dev.height * zoom), SDL_WINDOW_HIGH_PIXEL_DENSITY);
        if (!win) { fprintf(stderr, "isim shell: SDL_CreateWindow failed: %s\n", SDL_GetError()); headless = 1; }
        else { px_scale = SDL_GetWindowPixelDensity(win) * zoom; SDL_StartTextInput(win); }
    }
    if (headless) px_scale = getenv("ISIM_SHOT_SCALE") ? atof(getenv("ISIM_SHOT_SCALE")) : 2;
    if (headless && !getenv("ISIM_AUDIO")) setenv("ISIM_MUTE", "1", 1);      /* headless runs (tests) are silent */
    surf_w = (int)lround(dev.width * px_scale); surf_h = (int)lround(dev.height * px_scale);
    surface_bytes = (size_t)surf_w * surf_h * 4;
    pctx = NULL;

    { const char *d = getenv("ISIM_DATA"); char p[1024];        /* `isim push` checks that a device is running */
      if (d && *d) { snprintf(p, sizeof p, "%s/Library/isim", d); mkdir(p, 0755); snprintf(p, sizeof p, "%s/Library/isim/shell.pid", d);
                     FILE *f = fopen(p, "w"); if (f) { fprintf(f, "%d\n", (int)getpid()); fclose(f); } } }
    if (shell_spawn(springboard_bundle, springboard_exe, NULL) != 0) return 1;
    active = 0;
    if (open_args) {                       /* isim run: open the app over the home screen, like Xcode */
        int i = shell_spawn(open_args[0], open_args[1], NULL);
        if (i > 0) { shell_send(0, EV_BACKGROUND); active = i; open_slot = i; }
    }
    int gesture = 0; double gesture_y = 0;
    for (;;) {
        /* children */
        int status; pid_t dead;
        while ((dead = waitpid(-1, &status, WNOHANG)) > 0) {
            sys_reaped(dead, status);                    /* widget extension helpers (shell_system.inc) */
            for (int i = 0; i < nclients; i++) if (clients[i].pid == dead && clients[i].alive) {
                clients[i].alive = 0; close(clients[i].sock);
                fprintf(stderr, "isim shell: %s exited\n", clients[i].bundle);
                if (i == open_slot && !clients[i].relaunch && !clients[i].sysquit) {
                    int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + (WIFSIGNALED(status) ? WTERMSIG(status) : 0);
                    fprintf(stderr, "isim shell: the run ended (%s exited with %d)\n", clients[i].bundle, code);
                    shell_quit(); return code;
                }
                if (clients[i].relaunch) {           /* restarted by the system (language change) */
                    char b[512], x[512];
                    snprintf(b, sizeof b, "%s", clients[i].bundle); snprintf(x, sizeof x, "%s", clients[i].exe);
                    if (shell_spawn_at(i, b, x, NULL) == i) { if (i == active) shell_send(i, EV_FOREGROUND); else shell_send(i, EV_BACKGROUND); continue; }
                }
                if (i == 0) { fprintf(stderr, "isim shell: the home screen exited; shutting down\n"); shell_quit(); return 0; }
                if (i == active) { active = -1; shell_activate(0); }
            }
        }
        /* client messages */
        struct pollfd pf[32]; int map[32], np = 0;
        for (int i = 0; i < nclients; i++) if (clients[i].alive) { pf[np] = (struct pollfd){ clients[i].sock, POLLIN, 0 }; map[np++] = i; }
        if (poll(pf, np, 0) > 0)
            for (int k = 0; k < np; k++) if (pf[k].revents & POLLIN) {
                struct shell_msg m;
                while (recv(pf[k].fd, &m, sizeof m, MSG_DONTWAIT) == (ssize_t)sizeof m) shell_handle(map[k], &m);
            }
        /* input (script or window) */
        anim_frame();
        nb_tick();
        sys_tick();
        struct isim_event ev;
        if (!isim_next_event(&ev, anim.kind != ANIM_NONE ? 0.004 : 0.008)) continue;
        if (ev.type == EV_TOUCH_DOWN || ev.type == EV_TOUCH_MOVE || ev.type == EV_KEY || ev.type == EV_TEXT || ev.type == EV_ID_DOWN || ev.type == EV_TEXT_DOWN) sys_input_seen();
        if (ev.type == EV_QUIT) { shell_quit(); return 0; }
        if (ev.type == EV_HOME) { shell_home(); continue; }
        if (ev.type == EV_LAUNCH_ID) { shell_forward(0, &ev); continue; }        /* the home screen resolves bundle ids */
        if (ev.type == EV_SHELL_CMD) { sys_command(ev.text); continue; }
        if (ev.type == EV_REDRAW) { shell_send(active, EV_REDRAW); continue; }
        if ((ev.type == EV_DEVICE_ORIENTATION || ev.type == EV_KEY) && sys_input(&ev)) continue;   /* orientation lock, system keys */
        if (ev.type == EV_DEVICE_ORIENTATION) { for (int k = 0; k < nclients; k++) shell_forward(k, &ev); continue; }
        if (ev.type == EV_KEY && (ev.mods & SDL_KMOD_CTRL) && (ev.mods & SDL_KMOD_SHIFT) && (ev.key == 'h' || ev.key == 'H')) { shell_home(); continue; }
        /* home-indicator gesture: touches starting at the bottom edge belong to the system */
        /* home indicator: a swipe up starting at the bottom edge (iOS). The edge zone is generous for a mouse. */
        if (anim.kind != ANIM_NONE && (ev.type == EV_TOUCH_DOWN || ev.type == EV_TOUCH_MOVE || ev.type == EV_TOUCH_UP)) continue;
        if (sys_input(&ev)) continue;
        if (nb_input(&ev)) continue;
        if (ev.type == EV_TOUCH_DOWN && ev.y > dev.height - 34 && active > 0 && (clients[active].defer_edges & 4) && now() - clients[active].defer_armed > 3) {
            clients[active].defer_armed = now();           /* deferred edge: this swipe goes to the app; a second one within 3 s goes home */
            shell_forward(active, &ev);
            continue;
        }
        if (ev.type == EV_TOUCH_DOWN && ev.y > dev.height - 34 && active > 0) {
            clients[active].defer_armed = 0;
            gesture = 1; (void)gesture_y;
            drag_active = 0; drag_x0 = drag_x = ev.x; drag_y0 = drag_y = ev.y; drag_t = drag_moved_t = now(); drag_vy = 0;
            continue;
        }
        if (gesture) {
            if (ev.type == EV_TOUCH_MOVE) {
                double t = now(), dt = t - drag_t;
                if (dt > 0.001) drag_vy = 0.6 * drag_vy + 0.4 * (ev.y - drag_y) / dt;     /* points per second */
                if (fabs(ev.y - drag_y) > 3 || fabs(ev.x - drag_x) > 3) drag_moved_t = t;
                drag_t = t; drag_x = ev.x; drag_y = ev.y;
                if (!drag_active && drag_y0 - drag_y > 4) drag_active = 1;
                if (drag_active) { double rad, ir; struct rectf r = drag_rect(&rad); compose(active, r, rad, 1, 0, 1.06, icon_target(active, &ir)); }
            } else if (ev.type == EV_TOUCH_UP) {
                gesture = 0;
                if (drag_active) {
                    drag_active = 0;
                    double rad; struct rectf r = drag_rect(&rad);
                    if (drag_y0 - drag_y > 90 && now() - drag_moved_t > 0.3) sys_open(OV_SWITCHER);     /* swipe up and hold */
                    else if (drag_y0 - drag_y > 110 || drag_vy < -700) shell_home_from(r, rad);
                    else start_anim(ANIM_BACK, active, r, full_rect(), rad, dev.corner_radius, 0.28);
                }
            }
            continue;
        }
        shell_forward(active, &ev);
    }
}
