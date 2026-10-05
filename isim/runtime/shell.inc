/* isim shell ("SpringBoard host"): owns the window, runs every app as a child process.
 * Included by host.c (shares the device, window, script and screenshot code).
 *
 * - Each client renders into its own shared-memory surface (memfd) and tells the shell when a
 *   frame is ready; the shell shows the foreground client's surface.
 * - Input goes to the foreground client. Touches that start in the bottom 34 pt and swipe up
 *   (or Ctrl+Shift+H, or the script command "home") go to the home screen.
 * - Leaving an app sends it EV_BACKGROUND (it keeps running); opening it again resumes it.
 * - Clients ask to launch apps (SM_LAUNCH), report settings changes (broadcast as EV_SETTINGS),
 *   go home, or terminate the other apps (language changes). */

struct shell_client { pid_t pid; int sock; unsigned char *pixels; char bundle[512]; int alive, has_frame; };
static struct shell_client clients[32];
static int nclients, active = -1;
static const char *shell_self, *shell_root;
static size_t surface_bytes;

static void shell_send(int i, int type) {
    if (i < 0 || i >= nclients || !clients[i].alive) return;
    struct shell_msg m = { .type = SM_EVENT }; m.ev.type = type;
    send(clients[i].sock, &m, sizeof m, MSG_NOSIGNAL);
}
static void shell_forward(int i, const struct isim_event *ev) {
    if (i < 0 || i >= nclients || !clients[i].alive) return;
    struct shell_msg m = { .type = SM_EVENT }; m.ev = *ev;
    send(clients[i].sock, &m, sizeof m, MSG_NOSIGNAL);
}
static void shell_show(int i) {
    if (i < 0 || !clients[i].alive) return;
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
    SDL_UpdateWindowSurface(win);
}

/* ---- app open / close animations (like iOS: apps zoom out of and back into their icons) ---- */
struct rectf { double x, y, w, h; };
struct icon_rect { char path[512]; struct rectf r; double radius; };
static struct icon_rect icons[256]; static int nicons;
enum { ANIM_NONE, ANIM_OPEN, ANIM_CLOSE, ANIM_BACK };
static struct { int kind, client; double t0, dur; struct rectf from, to; double rfrom, rto; } anim;
static cairo_surface_t *comp;          /* composited frame (device pixels) */
static int drag_active; static double drag_x0, drag_y0, drag_x, drag_y, drag_t, drag_vy;

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
    return cairo_image_surface_create_for_data(clients[i].pixels, CAIRO_FORMAT_ARGB32, surf_w, surf_h, surf_w * 4);
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
            cairo_translate(c, r.x, r.y); cairo_scale(c, r.w / dev.width, r.h / dev.height);
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
static int shell_spawn(const char *bundle, const char *exe, const char *url) {
    if (nclients >= (int)(sizeof clients / sizeof *clients)) { fprintf(stderr, "isim shell: too many apps\n"); return -1; }
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
        execl(shell_self, shell_self, "--root", shell_root, exe, (char *)NULL);
        perror("isim shell: exec"); _exit(127);
    }
    close(sv[1]); close(mfd);
    struct shell_client *c = &clients[nclients];
    *c = (struct shell_client){ pid, sv[0], px, "", 1, 0 };
    snprintf(c->bundle, sizeof c->bundle, "%s", bundle);
    fprintf(stderr, "isim shell: launched %s (pid %d)\n", bundle, pid);
    return nclients++;
}
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

/* one client message */
static void shell_handle(int i, const struct shell_msg *m) {
    switch (m->type) {
    case SM_FRAME:
        clients[i].has_frame = 1;
        if (i == active && anim.kind == ANIM_NONE && !drag_active) shell_show(i);
        break;
    case SM_ICON: set_icon(m->a, m->b); break;
    case SM_LAUNCH: shell_launch(m->a, m->b, m->c); break;
    case SM_HOME: shell_home(); break;
    case SM_SETTINGS:
        for (int k = 0; k < nclients; k++) if (k != i) shell_send(k, EV_SETTINGS);
        break;
    case SM_TERMINATE_OTHERS:                         /* e.g. after a language change, like iOS */
        for (int k = 1; k < nclients; k++) if (k != i && clients[k].alive) shell_send(k, EV_QUIT);
        break;
    case SM_TERMINATE_APP: {                          /* the app is being deleted */
        int k = shell_find(m->a);
        if (k > 0) { shell_send(k, EV_QUIT); if (k == active) { active = -1; shell_activate(0); } }
        break; }
    default: break;
    }
}

int isim_shell_main(const char *self, const char *root, const char *springboard_bundle, const char *springboard_exe) {
    shell_self = self; shell_root = root;
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

    if (shell_spawn(springboard_bundle, springboard_exe, NULL) != 0) return 1;
    active = 0;
    int gesture = 0; double gesture_y = 0;
    for (;;) {
        /* children */
        int status; pid_t dead;
        while ((dead = waitpid(-1, &status, WNOHANG)) > 0)
            for (int i = 0; i < nclients; i++) if (clients[i].pid == dead && clients[i].alive) {
                clients[i].alive = 0; close(clients[i].sock);
                fprintf(stderr, "isim shell: %s exited\n", clients[i].bundle);
                if (i == 0) { fprintf(stderr, "isim shell: the home screen exited; shutting down\n"); shell_quit(); return 0; }
                if (i == active) { active = -1; shell_activate(0); }
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
        struct isim_event ev;
        if (!isim_next_event(&ev, anim.kind != ANIM_NONE ? 0.004 : 0.008)) continue;
        if (ev.type == EV_QUIT) { shell_quit(); return 0; }
        if (ev.type == EV_HOME) { shell_home(); continue; }
        if (ev.type == EV_LAUNCH_ID) { shell_forward(0, &ev); continue; }        /* the home screen resolves bundle ids */
        if (ev.type == EV_REDRAW) { shell_send(active, EV_REDRAW); continue; }
        if (ev.type == EV_KEY && (ev.mods & SDL_KMOD_CTRL) && (ev.mods & SDL_KMOD_SHIFT) && (ev.key == 'h' || ev.key == 'H')) { shell_home(); continue; }
        /* home-indicator gesture: touches starting at the bottom edge belong to the system */
        /* home indicator: a swipe up starting at the bottom edge (iOS). The edge zone is generous for a mouse. */
        if (anim.kind != ANIM_NONE && (ev.type == EV_TOUCH_DOWN || ev.type == EV_TOUCH_MOVE || ev.type == EV_TOUCH_UP)) continue;
        if (ev.type == EV_TOUCH_DOWN && ev.y > dev.height - 34 && active > 0) {
            gesture = 1; (void)gesture_y;
            drag_active = 0; drag_x0 = drag_x = ev.x; drag_y0 = drag_y = ev.y; drag_t = now(); drag_vy = 0;
            continue;
        }
        if (gesture) {
            if (ev.type == EV_TOUCH_MOVE) {
                double t = now(), dt = t - drag_t;
                if (dt > 0.001) drag_vy = 0.6 * drag_vy + 0.4 * (ev.y - drag_y) / dt;     /* points per second */
                drag_t = t; drag_x = ev.x; drag_y = ev.y;
                if (!drag_active && drag_y0 - drag_y > 4) drag_active = 1;
                if (drag_active) { double rad, ir; struct rectf r = drag_rect(&rad); compose(active, r, rad, 1, 0, 1.06, icon_target(active, &ir)); }
            } else if (ev.type == EV_TOUCH_UP) {
                gesture = 0;
                if (drag_active) {
                    drag_active = 0;
                    double rad; struct rectf r = drag_rect(&rad);
                    if (drag_y0 - drag_y > 110 || drag_vy < -700) shell_home_from(r, rad);
                    else start_anim(ANIM_BACK, active, r, full_rect(), rad, dev.corner_radius, 0.28);
                }
            }
            continue;
        }
        shell_forward(active, &ev);
    }
}
