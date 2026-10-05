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

struct shell_client { pid_t pid; int sock; unsigned char *pixels; char bundle[512]; int alive; };
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
    *c = (struct shell_client){ pid, sv[0], px, "", 1 };
    snprintf(c->bundle, sizeof c->bundle, "%s", bundle);
    fprintf(stderr, "isim shell: launched %s (pid %d)\n", bundle, pid);
    return nclients++;
}
static void shell_launch(const char *bundle, const char *exe, const char *url) {
    int i = shell_find(bundle);
    if (i >= 0) {
        shell_activate(i);
        if (url && *url) { struct isim_event e = { .type = EV_OPEN_URL }; snprintf(e.text, sizeof e.text, "%s", url); shell_forward(i, &e); }
        return;
    }
    i = shell_spawn(bundle, exe, url);
    if (i < 0) return;
    if (active >= 0) shell_send(active, EV_BACKGROUND);
    active = i;
    shell_show(i);
}
static void shell_home(void) {
    if (active != 0) { fprintf(stderr, "isim shell: home\n"); shell_activate(0); }
}
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
    case SM_FRAME: if (i == active) shell_show(i); break;
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
        if (k > 0) { shell_send(k, EV_QUIT); if (k == active) shell_activate(0); }
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
        struct isim_event ev;
        if (!isim_next_event(&ev, 0.008)) continue;
        if (ev.type == EV_QUIT) { shell_quit(); return 0; }
        if (ev.type == EV_HOME) { shell_home(); continue; }
        if (ev.type == EV_LAUNCH_ID) { shell_forward(0, &ev); continue; }        /* the home screen resolves bundle ids */
        if (ev.type == EV_REDRAW) { shell_send(active, EV_REDRAW); continue; }
        if (ev.type == EV_KEY && (ev.mods & SDL_KMOD_CTRL) && (ev.mods & SDL_KMOD_SHIFT) && (ev.key == 'h' || ev.key == 'H')) { shell_home(); continue; }
        /* home-indicator gesture: touches starting at the bottom edge belong to the system */
        /* home indicator: a swipe up starting at the bottom edge (iOS). The edge zone is generous for a mouse. */
        if (ev.type == EV_TOUCH_DOWN && ev.y > dev.height - 34 && active != 0) { gesture = 1; gesture_y = ev.y; continue; }
        if (gesture) {
            if (ev.type == EV_TOUCH_MOVE && gesture_y - ev.y > 50) { gesture = 0; shell_home(); }
            else if (ev.type == EV_TOUCH_UP) gesture = 0;
            continue;
        }
        shell_forward(active, &ev);
    }
}
