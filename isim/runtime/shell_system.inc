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
 *                  "bg-assert REASONS"           what keeps the app running in the background (empty: it can be suspended)
 *                  "bg-wake T"                   when its next local notification is due (seconds since 1970; 0: none)
 *                  "badge PATH N"                the app's icon badge (the home screen draws it)
 *                  "push-deliver PATH EXE\x1fSIDECAR"   the home screen routed a remote notification (see sys_push_deliver)
 *                  "ext-run EXE REQUEST"         run a notification extension (like widget-run; "ext-done" to the home screen)
 *                  "nc-expanded RECORD SIDECAR"  the home screen's answer to "nc-expand" (expanded notifications)
 *                  "appclip-card SIDECAR"        show the App Clip card (shell_appclip.inc; "appclip-open" / "appclip-dismissed")
 *                  "siri-ui SIDECAR"             what Siri shows (shell_siri.inc); "intent-run ARGS" (the Shortcuts app) to the home screen
 *   shell -> app   "openurl URL", "launchtask BUNDLE TASK", "reload" (to the home screen), "bgtask TASK" (to the app),
 *                  "push BUNDLE FILE" / "push-drop FILE" / "badge PATH N" / "nc-expand ..." (to the home screen),
 *                  "remote-notification FILE", "nc-action RECORD\x1fID\x1fACTION\x1fTEXT" (to the app)
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

static void sys_protected_data(int available);
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
enum { OV_NONE, OV_SWITCHER, OV_LOCK, OV_NC, OV_CC, OV_NX /* an expanded notification */, OV_CLIP /* the App Clip card */ };
static int ov, locked;
static double ov_t0;                                  /* when the overlay opened (slide-in) */
static double last_active_t[32];                      /* app switcher order (most recent first) */
static int seen_active = -1;

struct nc_item { char path[512], id[256], title[256], body[512], icon[512], record[512], thumb[512], exe[512], file[512]; time_t t;
                 /* from the record's sidecar (<record>.txt): the thread it is grouped by, its sound, interruption level
                    (0 passive, 1 active, 2 time sensitive, 3 critical) and the stack summary */
                 char thread[160], sound[512], summary[160], sumarg[128]; int level, sumcount; };
static struct nc_item ncl[64]; static int nnc;

struct sys_el { char id[128], text[192]; struct rectf r; int kind, arg; };
enum { EL_NONE, EL_CARD, EL_NC_ITEM, EL_NC_GROUP, EL_NC_LESS, EL_NX_EXT, EL_NX_MEDIA, EL_NC_CLEAR, EL_CC_TOGGLE, EL_CC_SLIDER, EL_BG, EL_NX_CONTENT, EL_NX_ACTION, EL_NX_SEND, EL_LA, EL_LW, EL_SIRI, EL_CC_X /* shell_controls.inc */, EL_NP, EL_CALL /* shell_calls.inc */ };
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

/* Now Playing: an app's MPNowPlayingInfoCenter info ("nowplaying" request), drawn in Control Center and on the lock
   screen; their transport buttons send the app remote commands ("remote previous|toggle|next" system events) */
static struct { int client; char title[256], artist[256], album[256], artwork[512]; double duration, elapsed, rate, at; } np = { .client = -1 };
static int np_on(void) { return np.client >= 0 && np.client < nclients && clients[np.client].alive && np.title[0]; }
static double np_elapsed(void) {
    double e = np.elapsed + (np.rate > 0 ? (now() - np.at) * np.rate : 0);
    return np.duration > 0 ? fmin(e, np.duration) : e;
}
static const char *const np_cmds[3] = { "previous", "toggle", "next" };
/* the device volume (host_audio.c): Control Center's slider, the `volume` command and apps' MPVolumeViews share it */
double isim_device_volume(void); void isim_device_volume_set(double v, int save);
static void sys_volume_changed(double v, int except) {
    cc_volume = v;
    isim_device_volume_set(v, 1);
    for (int i = 0; i < nclients; i++) if (i != except && clients[i].alive) sys_send_text(i, "volume %.4f", v);
}

static int siri_visible(void); static void siri_draw(cairo_t *c); static int siri_input(const struct isim_event *ev); static void siri_tick(void);
static void siri_load(const char *file);                                       /* shell_siri.inc */
static int calls_visible(void); static void calls_draw(cairo_t *c); static int calls_input(const struct isim_event *ev); static void calls_tick(void); static int calls_home(void); static int calls_fullscreen(void);
static int calls_handle_msg(int from, const struct shell_msg *m);             /* shell_calls.inc */
static int sys_visible(void) { return ov != OV_NONE || siri_visible() || calls_visible(); }
static int sys_hides_banners(void) { return locked || ov != OV_NONE; }      /* Focus: focus_silences (shell_controls.inc) */
static void shell_launch(const char *bundle, const char *exe, const char *url);
static void sys_push_deliver(const char *path, const char *exe, const char *sidecar);
static void sys_local_deliver(const char *path, const char *exe, const char *sidecar);
static void nx_close(void);

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
/* record: the notification's record in the app container (expanding it, responses after a relaunch); thumb: an image
   attachment; exe/file: how to launch the app when it is not running (file: a remote notification's payload) */
static struct nc_item *nc_add(const char *path, const char *id, const char *icon, const char *title, const char *body) {
    for (int i = 0; i < nnc; i++) if (!strcmp(ncl[i].path, path) && !strcmp(ncl[i].id, id)) { memmove(&ncl[i], &ncl[i + 1], (nnc - i - 1) * sizeof *ncl); nnc--; break; }
    if (nnc >= 64) { memmove(&ncl[0], &ncl[1], 63 * sizeof *ncl); nnc--; }
    struct nc_item *n = &ncl[nnc++];
    memset(n, 0, sizeof *n);
    snprintf(n->path, sizeof n->path, "%s", path); snprintf(n->id, sizeof n->id, "%s", id); snprintf(n->icon, sizeof n->icon, "%s", icon ? icon : "");
    snprintf(n->title, sizeof n->title, "%s", title); snprintf(n->body, sizeof n->body, "%s", body); n->t = time(NULL);
    int i = shell_find(path);
    if (i >= 0) snprintf(n->exe, sizeof n->exe, "%s", clients[i].exe);
    return n;
}
static int focus_silences(const char *path, const char *flags, const char *title);   /* shell_controls.inc */
static int ctl_silent;                                                                 /* Silent Mode (shell_controls.inc) */
/* the record's sidecar, written by UserNotifications (or the home screen) next to the record */
static void nc_load_sidecar(struct nc_item *n) {
    n->level = 1; n->sumcount = 1;
    if (!n->record[0]) return;
    char p[600]; snprintf(p, sizeof p, "%s", n->record);
    char *dot = strrchr(p, '.'); if (dot && !strchr(dot, '/')) strcpy(dot, ".txt"); else strncat(p, ".txt", sizeof p - strlen(p) - 1);
    FILE *f = fopen(p, "r");
    if (!f) return;
    char line[700];
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        if (!strcmp(line, "thread")) snprintf(n->thread, sizeof n->thread, "%s", v);
        else if (!strcmp(line, "sound")) snprintf(n->sound, sizeof n->sound, "%s", v);
        else if (!strcmp(line, "summary")) snprintf(n->summary, sizeof n->summary, "%s", v);
        else if (!strcmp(line, "sumarg")) snprintf(n->sumarg, sizeof n->sumarg, "%s", v);
        else if (!strcmp(line, "sumcount")) n->sumcount = atoi(v) > 0 ? atoi(v) : 1;
        else if (!strcmp(line, "level")) n->level = !strcmp(v, "passive") ? 0 : !strcmp(v, "timesensitive") ? 2 : !strcmp(v, "critical") ? 3 : 1;
    }
    fclose(f);
}

/* ---- notification sounds: the record's sound (a file, "default", "ringtone", "critical:..."), played by the shell
   at the device volume; Silent Mode mutes all but critical alerts (which play at full volume). The default sound is
   synthesized (a short rising three-note chime; isim has no copy of Apple's sounds). ---- */
static void sys_play_sound(const char *spec, const char *app) {
    if (!spec || !spec[0]) return;
    int critical = !strncmp(spec, "critical:", 9);
    const char *what = critical ? spec + 9 : spec;
    const char *name = strrchr(what, '/'); name = name ? name + 1 : what;
    const char *a = strrchr(app, '/'); a = a ? a + 1 : app;
    if (ctl_silent && !critical) { fprintf(stderr, "isim shell: notification sound %s from %s not played (Silent Mode)\n", name, a); return; }
    if (!isim_audio_available()) { fprintf(stderr, "isim shell: notification sound %s from %s (no audio device)\n", name, a); return; }
    double vol = critical ? 1.0 : cc_volume;
    if (what[0] == '/') {
        float *pcm = NULL; long frames = 0; int ch = 0; double rate = 0;
        if (isim_audio_decode_file(what, &pcm, &frames, &ch, &rate)) {
            int buf = isim_audio_buffer_create(pcm, frames, ch, rate);
            if (buf) { isim_audio_play(buf, vol, 0); isim_audio_buffer_release(buf); }
            isim_audio_free(pcm);
        }
    } else {
        enum { RATE = 44100 };
        static const double notes[3] = { 1046.5, 1318.5, 1568.0 };
        int ring = !strcmp(what, "ringtone");
        long frames = (long)(RATE * (ring ? 1.2 : 0.48));
        float *pcm = calloc((size_t)frames, sizeof(float));
        for (long i = 0; i < frames; i++) {
            double t = (double)i / RATE, step = ring ? 0.1 : 0.16; int k = (int)(t / step); double tt = t - k * step;
            pcm[i] = (float)(0.28 * sin(2 * M_PI * notes[ring ? k % 2 * 2 : (k > 2 ? 2 : k)] * tt) * exp(-tt * (ring ? 8 : 14)));
        }
        int buf = isim_audio_buffer_create(pcm, frames, 1, RATE);
        if (buf) { isim_audio_play(buf, vol, 0); isim_audio_buffer_release(buf); }
        free(pcm);
    }
    fprintf(stderr, "isim shell: notification sound %s from %s played%s\n", name, a, critical ? " (critical alert)" : "");
}

/* a notification that was just listed: its sound and banner, as Focus, Silent Mode, the lock screen and its
   interruption level allow (passive: listed quietly; critical: breaks through Focus and Silent Mode) */
static void sys_alert(int client, struct nc_item *n, const char *flags) {
    const char *app = n->path;
    if (n->level == 0) {
        fprintf(stderr, "isim shell: passive notification from %s listed quietly: %s\n", app, n->title);
        if (ov != OV_NONE) sys_draw();
        return;
    }
    if (n->level == 3) fprintf(stderr, "isim shell: critical alert from %s\n", app);
    else if (focus_silences(app, flags, n->title)) { if (ov != OV_NONE) sys_draw(); return; }
    sys_play_sound(n->sound, app);
    if (sys_hides_banners()) {
        fprintf(stderr, "isim shell: notification from %s listed%s: %s\n", app, locked ? " on the lock screen" : "", n->title);
        if (ov != OV_NONE) sys_draw();
        return;
    }
    nb_show(client, n->path, n->id, n->icon, n->title, n->body, n->thumb);
}

/* stacks: notifications of one app and thread (no thread: the app's) are grouped, newest on top; a tap expands the
   stack. The summary under it: the category's summary format ("%u more messages from %@"), else "N more notifications" */
static char ncx_open[16][700]; static int nncx;              /* expanded stacks (app\x1fthread) */
static void nc_group_key(const struct nc_item *n, char *out, size_t sz) { snprintf(out, sz, "%s\x1f%s", n->path, n->thread); }
static int nc_group_open(const char *key) { for (int k = 0; k < nncx; k++) if (!strcmp(ncx_open[k], key)) return 1; return 0; }
static void nc_summary(const char *fmt, int count, const char *arg, char *out, size_t sz) {
    char f[200];
    if (fmt && fmt[0]) snprintf(f, sizeof f, "%s", fmt);
    else snprintf(f, sizeof f, count == 1 ? "%%u more notification" : "%%u more notifications");
    size_t o = 0; out[0] = 0;
    for (const char *p = f; *p && o + 1 < sz; p++) {
        if (*p == '%' && p[1]) {
            const char *q = p + 1;
            while ((*q >= '0' && *q <= '9') || *q == '$') q++;
            while (*q == 'l' || *q == 'z') q++;
            if (*q == 'u' || *q == 'd' || *q == 'i') { o += (size_t)snprintf(out + o, sz - o, "%d", count); p = q; continue; }
            if (*q == '@') { o += (size_t)snprintf(out + o, sz - o, "%s", arg ? arg : ""); p = q; continue; }
            if (*q == '%') { out[o++] = '%'; out[o] = 0; p = q; continue; }
        }
        out[o++] = *p; out[o] = 0;
    }
}
static double nc_draw_card(cairo_t *c, struct nc_item *n, int i, double x, double y, double w, const char *summary) {
    struct rectf r = { x, y, w, summary ? 94 : 76 };
    sys_round(c, r.x, r.y, r.w, r.h, 22);
    cairo_set_source_rgba(c, 0.95, 0.95, 0.97, 0.88); cairo_fill(c);
    sys_icon(c, n->icon, r.x + 12, r.y + 19, 38);
    sys_text(c, n->title, r.x + 60, r.y + 12, r.w - 130, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 0, 0, 0, 1);
    long ago = (long)(time(NULL) - n->t) / 60; char when[32];
    if (ago < 1) snprintf(when, sizeof when, "now"); else snprintf(when, sizeof when, "%ldm ago", ago);
    sys_text(c, when, r.x + r.w - 70, r.y + 13, 56, 13, PANGO_WEIGHT_NORMAL, 2, 1, 0.45, 0.45, 0.45, 1);
    sys_text(c, n->body, r.x + 60, r.y + 33, r.w - 74 - (n->thumb[0] ? 46 : 0), 15, PANGO_WEIGHT_NORMAL, 0, summary ? 1 : 2, 0, 0, 0, 1);
    if (n->thumb[0]) nb_thumb(c, n->thumb, r.x + r.w - 14 - 38, r.y + 76 - 14 - 38, 38);
    if (summary) sys_text(c, summary, r.x + 60, r.y + 68, r.w - 74, 13, PANGO_WEIGHT_NORMAL, 0, 1, 0.42, 0.42, 0.45, 1);
    char id[300]; snprintf(id, sizeof id, summary ? "nc-group-%s" : "nc-item-%s", n->id);
    el_add(id, n->title, r, summary ? EL_NC_GROUP : EL_NC_ITEM, i);
    return r.h;
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
    int done[64] = { 0 };
    for (int i = nnc - 1; i >= 0 && y < dev.height - 120; i--) {
        if (done[i]) continue;
        char key[700]; nc_group_key(&ncl[i], key, sizeof key);
        int members[64], nm = 0;
        for (int j = i; j >= 0; j--) { char k2[700]; nc_group_key(&ncl[j], k2, sizeof k2); if (!strcmp(k2, key)) { members[nm++] = j; done[j] = 1; } }
        if (nm == 1) { y += nc_draw_card(c, &ncl[i], i, x, y, w, NULL) + 8; continue; }
        if (nc_group_open(key)) {                       /* an expanded stack: its header ("Show Less") and every notification */
            struct sys_appinfo *ai = sys_info(ncl[i].path);
            sys_text(c, ai && ai->name[0] ? ai->name : "App", x + 6, y + 4, w - 120, 17, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
            struct rectf less = { x + w - 104, y, 100, 26 };
            sys_round(c, less.x, less.y, less.w, less.h, 13); cairo_set_source_rgba(c, 1, 1, 1, 0.25); cairo_fill(c);
            sys_text(c, "Show Less", less.x, less.y + 5, less.w, 13, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
            char id[300]; snprintf(id, sizeof id, "nc-less-%s", ncl[i].id);
            el_add(id, "Show Less", less, EL_NC_LESS, i);
            y += 34;
            for (int k = 0; k < nm && y < dev.height - 120; k++) y += nc_draw_card(c, &ncl[members[k]], members[k], x, y, w, NULL) + 8;
            continue;
        }
        /* a stack: plates under the newest notification and the summary of the others */
        int hidden = 0; char args[128] = "";
        for (int k = 1; k < nm; k++) {
            struct nc_item *m = &ncl[members[k]];
            hidden += m->sumcount > 0 ? m->sumcount : 1;
            if (m->sumarg[0] && !strstr(args, m->sumarg)) { if (args[0]) strncat(args, ", ", sizeof args - strlen(args) - 1); strncat(args, m->sumarg, sizeof args - strlen(args) - 1); }
        }
        char summary[200]; nc_summary(ncl[i].summary, hidden, args, summary, sizeof summary);
        for (int k = nm >= 3 ? 2 : 1; k >= 1; k--) {
            double inset = 10 * k;
            sys_round(c, x + inset, y + 94 - 70 + 7 * k, w - 2 * inset, 70, 20);
            cairo_set_source_rgba(c, 0.92, 0.92, 0.95, 0.75 - 0.2 * k); cairo_fill(c);
        }
        y += nc_draw_card(c, &ncl[i], i, x, y, w, summary) + 8 + (nm >= 3 ? 14 : 7);
    }
}

static void cc_button(cairo_t *c, int k, struct rectf r, int circle);
#include "shell_controls.inc"

/* ---- Control Center ---- */
static void cc_button(cairo_t *c, int k, struct rectf r, int circle) {
    int on = cc_on[k];
    double bg_on[3] = { 0, 0.48, 1 };
    if (k == CC_AIRPLANE) { bg_on[0] = 1; bg_on[1] = 0.58; bg_on[2] = 0; }
    if (k == CC_CELLULAR) { bg_on[0] = 0.2; bg_on[1] = 0.78; bg_on[2] = 0.35; }
    if (k == CC_FOCUS) { focus_load(); for (int q = 0; q < 3; q++) bg_on[q] = focus_rgb[focus_mode][q]; }
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
    if (k == CC_FOCUS) focus_draw_module(c, r, fg);
    else sys_symbol(c, cc_symbols[k], r.x + r.w / 2, r.y + r.h / 2, circle ? 22 : 24, fg, fg, fg);
    el_add(cc_ids[k], k == CC_FOCUS && on ? focus_names[focus_mode] : on ? "on" : "off", r, EL_CC_TOGGLE, k);
    if (k == CC_FOCUS) focus_register_module(r);
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
    if (cc_page == CC_PAGE_FOCUS) { focus_draw_list(c); return; }        /* the expanded Focus module */
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
        el_add("cc-edit", "Edit", edit, EL_CC_X, XARG(X_EDIT, 0)); el_add("cc-power", "Power", power, EL_NONE, 0);
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
    struct rectf npr = { m + big + gap, top, big, big };
    sys_platter(c, npr.x, npr.y, npr.w, npr.h, prad, 0.14);
    if (np_on()) {                                              /* artwork, title, artist (the app's now-playing info) */
        double tx = npr.x + 16;
        cairo_surface_t *art = np.artwork[0] ? cairo_image_surface_create_from_png(np.artwork) : NULL;
        if (art && cairo_surface_status(art) == CAIRO_STATUS_SUCCESS) {
            double aw = cairo_image_surface_get_width(art), ah = cairo_image_surface_get_height(art), s = 36;
            cairo_save(c); cairo_new_path(c); sys_round(c, npr.x + 14, npr.y + 14, s, s, 7); cairo_clip(c);
            cairo_translate(c, npr.x + 14, npr.y + 14); cairo_scale(c, s / aw, s / ah); cairo_set_source_surface(c, art, 0, 0); cairo_paint(c);
            cairo_restore(c);
            tx += s + 8;
        }
        if (art) cairo_surface_destroy(art);
        sys_text(c, np.title, tx, npr.y + 14, npr.x + npr.w - 12 - tx, 14, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
        if (np.artist[0]) sys_text(c, np.artist, tx, npr.y + 32, npr.x + npr.w - 12 - tx, 13, PANGO_WEIGHT_NORMAL, 0, 1, 1, 1, 1, 0.6);
        char t[600]; snprintf(t, sizeof t, "%s%s%s", np.title, np.artist[0] ? " — " : "", np.artist);
        el_add("cc-nowplaying", t, npr, EL_NONE, 0);
    } else {
        sys_text(c, "Not Playing", npr.x + 16, npr.y + 16, npr.w - 32, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 0.85);
        el_add("cc-nowplaying", "Not Playing", npr, EL_NONE, 0);
    }
    double fade = np_on() ? 1 : 0.35;
    const char *glyphs[3] = { "backward.fill", np_on() && np.rate > 0 ? "pause.fill" : "play.fill", "forward.fill" };
    const char *ids[3] = { "cc-np-previous", "cc-np-play", "cc-np-next" };
    for (int k = 0; k < 3; k++) {
        double cx = npr.x + npr.w * (0.22 + 0.28 * k), cy = npr.y + npr.h - 34;
        sys_symbol(c, glyphs[k], cx, cy, k == 1 ? 24 : 20, fade, fade, fade);
        el_add(ids[k], k == 1 ? (np_on() && np.rate > 0 ? "pause" : "play") : np_cmds[k], (struct rectf){ cx - 22, cy - 22, 44, 44 }, EL_NP, k);
    }
    /* row 2: orientation lock, mirroring | brightness, volume (tall) ; focus under the first two */
    double y2 = top + big + gap;
    cc_button(c, CC_ORIENT, (struct rectf){ m, y2, u, u }, 0);
    cc_button(c, CC_MIRROR, (struct rectf){ m + u + gap, y2, u, u }, 0);
    cc_button(c, CC_FOCUS, (struct rectf){ m, y2 + u + gap, big, u }, 0);
    cc_slider(c, "cc-brightness", "sun.max.fill", cc_brightness, (struct rectf){ m + big + gap, y2, u, big }, 0);
    cc_slider(c, "cc-volume", "speaker.wave.2.fill", cc_volume, (struct rectf){ m + big + gap + u + gap, y2, u, big }, 1);
    /* row 4 on: flashlight, timer, dark mode, camera and the controls added in edit mode (iOS 18+) */
    ctl_draw_flow(c, m, y2 + big + gap, u, gap);
    if (cc_page == CC_PAGE_GALLERY) ctl_draw_gallery(c);
}

/* ---- lock screen ---- */
static double la_draw_lock(cairo_t *c, double top);
/* the lock screen's media player: artwork, title, artist, progress with elapsed / remaining time, transport buttons */
static double np_draw_lock(cairo_t *c, double top) {
    if (!np_on()) return 0;
    double x = 14, w = dev.width - 28, h = 176;
    if (sys_os() >= 26) sys_glass(c, x, top, w, h, 24, NULL, 1 | 2);
    else { cairo_new_path(c); sys_round(c, x, top, w, h, 22); cairo_set_source_rgba(c, 0.15, 0.15, 0.17, 0.55); cairo_fill(c); }
    double tx = x + 16;
    cairo_surface_t *art = np.artwork[0] ? cairo_image_surface_create_from_png(np.artwork) : NULL;
    if (art && cairo_surface_status(art) == CAIRO_STATUS_SUCCESS) {
        double aw = cairo_image_surface_get_width(art), ah = cairo_image_surface_get_height(art), s = 52;
        cairo_save(c); cairo_new_path(c); sys_round(c, x + 16, top + 16, s, s, 8); cairo_clip(c);
        cairo_translate(c, x + 16, top + 16); cairo_scale(c, s / aw, s / ah); cairo_set_source_surface(c, art, 0, 0); cairo_paint(c);
        cairo_restore(c);
        tx += s + 12;
    }
    if (art) cairo_surface_destroy(art);
    sys_text(c, np.title, tx, top + 20, x + w - 16 - tx, 16, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
    if (np.artist[0]) sys_text(c, np.artist, tx, top + 42, x + w - 16 - tx, 15, PANGO_WEIGHT_NORMAL, 0, 1, 1, 1, 1, 0.6);
    double e = np_elapsed(), py = top + 92;
    cairo_new_path(c); sys_round(c, x + 16, py, w - 32, 5, 2.5); cairo_set_source_rgba(c, 1, 1, 1, 0.25); cairo_fill(c);
    if (np.duration > 0) { cairo_new_path(c); sys_round(c, x + 16, py, (w - 32) * fmin(1, e / np.duration), 5, 2.5); cairo_set_source_rgba(c, 1, 1, 1, 0.9); cairo_fill(c); }
    char a[32], b[32];
    snprintf(a, sizeof a, "%d:%02d", (int)e / 60, (int)e % 60);
    double rem = np.duration > 0 ? np.duration - e : 0;
    snprintf(b, sizeof b, "-%d:%02d", (int)rem / 60, (int)rem % 60);
    sys_text(c, a, x + 16, py + 10, 80, 12, PANGO_WEIGHT_NORMAL, 0, 1, 1, 1, 1, 0.6);
    sys_text(c, np.duration > 0 ? b : "", x + w - 96, py + 10, 80, 12, PANGO_WEIGHT_NORMAL, 2, 1, 1, 1, 1, 0.6);
    const char *glyphs[3] = { "backward.fill", np.rate > 0 ? "pause.fill" : "play.fill", "forward.fill" };
    const char *ids[3] = { "lock-np-previous", "lock-np-play", "lock-np-next" };
    for (int k = 0; k < 3; k++) {
        double cx = x + w * (0.25 + 0.25 * k), cy = top + h - 30;
        sys_symbol(c, glyphs[k], cx, cy, k == 1 ? 30 : 24, 1, 1, 1);
        el_add(ids[k], k == 1 ? (np.rate > 0 ? "pause" : "play") : np_cmds[k], (struct rectf){ cx - 24, cy - 24, 48, 48 }, EL_NP, k);
    }
    char t[600]; snprintf(t, sizeof t, "%s%s%s %d:%02d", np.title, np.artist[0] ? " — " : "", np.artist, (int)e / 60, (int)e % 60);
    el_add("lock-nowplaying", t, (struct rectf){ x, top, w, h }, EL_NONE, 0);
    return h + 12;
}
static void lw_draw_date(cairo_t *c, double top, const char *dstr); static double lw_draw_row(cairo_t *c);
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
    lw_draw_date(c, top, dstr);                                    /* the date, with the inline widget */
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
    double row = lw_draw_row(c);                                   /* the widgets under the clock */
    double pill = row ? row + 10 : top + 156;                      /* the Focus pill: under the widgets, if any */
    int focused = focus_draw_lock(c, pill);
    double lt = fmax(dev.height * 0.30, focused ? pill + 30 + 14 : row ? row + 14 : 0);
    lt += la_draw_lock(c, lt);
    lt += np_draw_lock(c, lt);
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
    lockctl_draw(c, bl, br);                                       /* flashlight / camera, or controls (shell_controls.inc) */
}


static void sys_lock(void); static void sys_unlock(void);
/* ---- Live Activities: drawn on the lock screen and around the Dynamic Island (images rendered by the app's widget
   extension; the home screen sends "la-set APP SIDECAR": id=, dir= (lock.png, leading.png, trailing.png, minimal.png,
   expanded.png), relevance=, seq=, ended=, dismiss=, alert=, stale=, url=; "la-end APP ID\x1fDISMISS" when it ends).
   One activity: compact (leading / trailing around the island). Two or more: the two most relevant minimal, one
   attached to the island's leading side and one detached on the trailing side (estimated: a 37 pt circle 8 pt from
   the island). Ended activities leave the island at once and stay on the lock screen until their dismissal time.
   Alerts (AlertConfiguration, a push's "alert"): the island expands for 4 s (no island: a banner with the lock-screen
   view); on the lock screen the activity lights up (moves to the top, outlined) for 4 s. ---- */
#define LA_MAX 8
#define LA_ALERT_SECONDS 4.0
struct la_item { int on, ended, stale; char id[80], app[512], url[512]; double relevance, dismiss_at, seq, started;
                 cairo_surface_t *lock, *leading, *trailing, *minimal, *exp; };
static struct la_item las[LA_MAX];
static struct { char exp_id[80], alert_id[80]; double alert_until; int alert_expand, alert_banner; } la;
static double wall_now(void);
static cairo_surface_t *la_png(const char *dir, const char *name) {
    char p[1100]; snprintf(p, sizeof p, "%s/%s.png", dir, name);
    cairo_surface_t *s = cairo_image_surface_create_from_png(p);
    if (cairo_surface_status(s) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(s); return NULL; }
    return s;
}
static void la_free_images(struct la_item *it) {
    cairo_surface_t **ss[5] = { &it->lock, &it->leading, &it->trailing, &it->minimal, &it->exp };
    for (int i = 0; i < 5; i++) if (*ss[i]) { cairo_surface_destroy(*ss[i]); *ss[i] = NULL; }
}
static void la_remove(int i) {
    la_free_images(&las[i]);
    if (!strcmp(la.exp_id, las[i].id)) la.exp_id[0] = 0;
    memset(&las[i], 0, sizeof las[i]);
}
static int la_find(const char *id) { for (int i = 0; i < LA_MAX; i++) if (las[i].on && !strcmp(las[i].id, id)) return i; return -1; }
/* the activities around the island: not ended, their app not in front; the most relevant (then the newest) first */
static int la_island_list(int *out) {
    int n = 0;
    for (int i = 0; i < LA_MAX; i++) if (las[i].on && !las[i].ended && active != shell_find(las[i].app)) out[n++] = i;
    for (int a = 1; a < n; a++) for (int b = a; b > 0; b--) {
        struct la_item *x = &las[out[b - 1]], *y = &las[out[b]];
        if (y->relevance > x->relevance || (y->relevance == x->relevance && y->started > x->started)) { int t = out[b]; out[b] = out[b - 1]; out[b - 1] = t; }
    }
    return n;
}
static int la_expanded(void) { return la.exp_id[0] ? la_find(la.exp_id) : -1; }
static void la_alert(int i);
static void la_set(const char *app, const char *sidecar) {
    char line[1200], id[80] = "", dir[600] = "", url[512] = "";
    double relevance = 0, seq = 0, dismiss = 0; int ended = 0, alert = 0, stale = 0;
    FILE *f = fopen(sidecar, "r");
    if (!f) return;
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        if (!strcmp(line, "id")) snprintf(id, sizeof id, "%s", v); else if (!strcmp(line, "dir")) snprintf(dir, sizeof dir, "%s", v);
        else if (!strcmp(line, "url")) snprintf(url, sizeof url, "%s", v); else if (!strcmp(line, "relevance")) relevance = atof(v);
        else if (!strcmp(line, "seq")) seq = atof(v); else if (!strcmp(line, "dismiss")) dismiss = atof(v);
        else if (!strcmp(line, "ended")) ended = atoi(v); else if (!strcmp(line, "alert")) alert = atoi(v); else if (!strcmp(line, "stale")) stale = atoi(v);
    }
    fclose(f);
    int i = la_find(id);
    if (ended && dismiss <= wall_now()) { if (i >= 0) la_remove(i); return; }           /* already dismissed */
    if (i >= 0 && seq < las[i].seq) { fprintf(stderr, "isim shell: Live Activity %s: an older render ignored\n", id); return; }
    if (i < 0) {
        if (ended) return;                                               /* ended before it was shown */
        for (int k = 0; k < LA_MAX && i < 0; k++) if (!las[k].on) i = k;
        if (i < 0) { fprintf(stderr, "isim shell: too many Live Activities\n"); return; }
        las[i].started = wall_now();
    }
    struct la_item *it = &las[i];
    la_free_images(it);
    it->lock = la_png(dir, "lock"); it->leading = la_png(dir, "leading"); it->trailing = la_png(dir, "trailing");
    it->minimal = la_png(dir, "minimal"); it->exp = la_png(dir, "expanded");
    int was = it->on;
    it->on = it->lock != NULL;
    snprintf(it->id, sizeof it->id, "%s", id); snprintf(it->app, sizeof it->app, "%s", app); snprintf(it->url, sizeof it->url, "%s", url);
    it->relevance = relevance; it->seq = seq; it->stale = stale;
    if (ended && !it->ended) { it->ended = 1; it->dismiss_at = dismiss; }
    if (!was) fprintf(stderr, "isim shell: Live Activity from %s %s (%s)\n", app, it->on ? "shown" : "(no images)", id);
    else fprintf(stderr, "isim shell: Live Activity %s updated%s\n", id, stale ? " (stale)" : "");
    if (it->on && alert) la_alert(i);
}
static void la_end(const char *app, const char *args) {
    char id[80]; double dismiss = 0;
    const char *sep = strchr(args, '\x1f');
    snprintf(id, sizeof id, "%.*s", sep ? (int)(sep - args) : (int)strlen(args), args);
    if (sep) dismiss = atof(sep + 1);
    int i = la_find(id);
    if (i < 0) return;
    las[i].ended = 1; las[i].dismiss_at = dismiss;
    if (!strcmp(la.exp_id, id)) la.exp_id[0] = 0;
    fprintf(stderr, "isim shell: Live Activity ended (%s; %s)\n", id, dismiss <= wall_now() ? "dismissed" : "stays on the lock screen");
    if (dismiss <= wall_now()) la_remove(i);
    (void)app;
}
static int la_banner_visible(void) { return la.alert_banner && la.alert_until > now() && !locked && ov == OV_NONE && anim.kind == ANIM_NONE; }
static int la_island_visible(void) {
    if (la_banner_visible()) return 1;
    if (dev.has_island != 1 || locked || ov != OV_NONE || anim.kind != ANIM_NONE) return 0;
    int idx[LA_MAX];
    return la_island_list(idx) > 0 || la_expanded() >= 0;
}
/* how far the island grows sideways: at most 64 pt (compact) / 44 pt (minimal), and never over the status bar's time
   (centred at x 77 on Dynamic Island iPhones, ~17 pt each side) or its icons, which keep showing as on iOS */
static double la_side(double most) { return fmax(24, fmin(most, dev.width / 2 - 62.5 - 100)); }
static struct rectf la_compact_rect(void) { double e = la_side(64); return (struct rectf){ dev.width / 2 - 62.5 - e, 11, 125 + 2 * e, 37 }; }
static struct rectf la_attached_rect(void) { double e = la_side(44); return (struct rectf){ dev.width / 2 - 62.5 - e, 11, 125 + e, 37 }; }
/* the island reaches where the cellular bars are (host.c: from width - 105, ~16 pt wide), as the compact presentation and
   the detached circle do: the status bar leaves them out, like iOS dropping a lower-priority item when space runs out */
static struct rectf la_detached_rect(void);
static int la_detached_shown(void) {
    if (!la_island_visible() || la_banner_visible() || la_expanded() >= 0) return 0;
    int idx[LA_MAX], n = la_island_list(idx);
    double right = n >= 2 ? la_detached_rect().x + 37 : n == 1 ? la_compact_rect().x + la_compact_rect().w : 0;
    return right > dev.width - 105 - 2;
}
/* the apps draw their own status bars: tell them when the island starts / stops covering the cellular bars */
static void la_sync_status_bars(void) {
    static int told = -1;
    int now_shown = la_detached_shown();
    if (now_shown == told) return;
    told = now_shown;
    for (int i = 0; i < nclients; i++) if (clients[i].alive) sys_send_text(i, "statusbar-cellular %d", now_shown);
}
static struct rectf la_detached_rect(void) { return (struct rectf){ dev.width / 2 + 62.5 + 8, 11, 37, 37 }; }
static struct rectf la_expanded_rect(void) { return (struct rectf){ 8, 8, dev.width - 16, 176 }; }
static struct rectf la_banner_rect(void) { double w = fmin(dev.width - 16, 400); return (struct rectf){ (dev.width - w) / 2, fmax(dev.safe_top, 20) + 4, w, w * 160 / 370 }; }
static void la_img(cairo_t *c, cairo_surface_t *s, double x, double y, double w, double h) {
    if (!s) return;
    double iw = cairo_image_surface_get_width(s), ih = cairo_image_surface_get_height(s);
    cairo_save(c); cairo_translate(c, x, y); cairo_scale(c, w / iw, h / ih);
    cairo_set_source_surface(c, s, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
    cairo_restore(c);
}
static void la_draw_island(cairo_t *c) {
    if (la_banner_visible()) {                             /* no Dynamic Island: an alert shows the lock-screen view as a banner */
        int i = la_find(la.alert_id);
        if (i >= 0) {
            struct rectf r = la_banner_rect();
            cairo_save(c); sys_round(c, r.x, r.y, r.w, r.h, 22); cairo_clip_preserve(c);
            cairo_set_source_rgba(c, 0.95, 0.95, 0.97, 0.95); cairo_fill(c);
            la_img(c, las[i].lock, r.x, r.y, r.w, r.h); cairo_restore(c);
            el_add("live-activity-banner", las[i].id, r, EL_LA, i);
        }
        return;
    }
    if (dev.has_island != 1) return;
    int e = la_expanded();
    if (e >= 0) {
        struct rectf r = la_expanded_rect();
        sys_round(c, r.x, r.y, r.w, r.h, 44); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        double w = fmin(370, r.w - 8);
        la_img(c, las[e].exp, r.x + (r.w - w) / 2, r.y + 10, w, w * 160 / 370);
        el_add("dynamic-island", "expanded", r, EL_NONE, e);
        return;
    }
    int idx[LA_MAX], n = la_island_list(idx);
    if (n == 1) {
        struct rectf r = la_compact_rect();
        sys_round(c, r.x, r.y, r.w, r.h, 18.5); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        double e = la_side(64);                                    /* the 64 pt renders, centred in each side, clipped */
        cairo_save(c); sys_round(c, r.x, r.y, r.w, r.h, 18.5); cairo_clip(c);
        la_img(c, las[idx[0]].leading, r.x + e / 2 - 32 + 2, r.y, 64, 37);
        la_img(c, las[idx[0]].trailing, r.x + r.w - e / 2 - 32 - 2, r.y, 64, 37);
        cairo_restore(c);
        el_add("dynamic-island", "compact", r, EL_NONE, idx[0]);
    } else if (n >= 2) {                                   /* minimal: one attached (leading), one detached (trailing) */
        struct rectf a = la_attached_rect(), d = la_detached_rect();
        sys_round(c, a.x, a.y, a.w, a.h, 18.5); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        la_img(c, las[idx[0]].minimal, a.x + 2, a.y, 37, 37);
        cairo_new_path(c); cairo_arc(c, d.x + d.w / 2, d.y + d.h / 2, d.h / 2, 0, 2 * M_PI); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        la_img(c, las[idx[1]].minimal, d.x, d.y, 37, 37);
        el_add("dynamic-island", "minimal", a, EL_NONE, idx[0]);
        el_add("dynamic-island-detached", "minimal", d, EL_NONE, idx[1]);
    }
}
/* the island as `dump` lists it */
static void la_dump_island(void) {
    if (la_banner_visible()) { struct rectf r = la_banner_rect(); fprintf(stderr, "IsimLiveActivityBanner (%g %g; %g x %g) id=live-activity-banner text=%s\n", r.x, r.y, r.w, r.h, la.alert_id); return; }
    int e = la_expanded(), idx[LA_MAX], n = la_island_list(idx);
    if (e >= 0) { struct rectf r = la_expanded_rect(); fprintf(stderr, "IsimDynamicIsland (%g %g; %g x %g) id=dynamic-island text=expanded\n", r.x, r.y, r.w, r.h); return; }
    if (n == 1) { struct rectf r = la_compact_rect(); fprintf(stderr, "IsimDynamicIsland (%g %g; %g x %g) id=dynamic-island text=compact\n", r.x, r.y, r.w, r.h); }
    if (n >= 2) {
        struct rectf a = la_attached_rect(), d = la_detached_rect();
        fprintf(stderr, "IsimDynamicIsland (%g %g; %g x %g) id=dynamic-island text=minimal activity=%s\n", a.x, a.y, a.w, a.h, las[idx[0]].id);
        fprintf(stderr, "IsimDynamicIsland (%g %g; %g x %g) id=dynamic-island-detached text=minimal activity=%s\n", d.x, d.y, d.w, d.h, las[idx[1]].id);
    }
}
/* expand / collapse: which = 0 the attached (or only) activity, 1 the detached one */
static void la_toggle(int which) {
    int idx[LA_MAX], n = la_island_list(idx);
    la.alert_expand = 0;
    if (la_expanded() >= 0) la.exp_id[0] = 0;
    else if (n > which) snprintf(la.exp_id, sizeof la.exp_id, "%s", las[idx[which]].id);
    fprintf(stderr, "isim shell: Dynamic Island %s\n", la_expanded() >= 0 ? "expanded" : n >= 2 ? "minimal" : "compact");
}
static void la_alert(int i) {
    struct la_item *it = &las[i];
    snprintf(la.alert_id, sizeof la.alert_id, "%s", it->id);
    la.alert_until = now() + LA_ALERT_SECONDS; la.alert_expand = la.alert_banner = 0;
    it->started = wall_now();                               /* the alerting activity comes first on the lock screen */
    if (locked) { fprintf(stderr, "isim shell: Live Activity alert %s: the lock screen lights up\n", it->id); if (ov == OV_LOCK) sys_draw(); return; }
    if (active == shell_find(it->app)) { fprintf(stderr, "isim shell: Live Activity alert %s: the app is in the foreground\n", it->id); return; }
    if (dev.has_island == 1) {
        snprintf(la.exp_id, sizeof la.exp_id, "%s", it->id); la.alert_expand = 1;
        fprintf(stderr, "isim shell: Live Activity alert %s: Dynamic Island expanded (alert)\n", it->id);
    } else {
        la.alert_banner = 1;
        fprintf(stderr, "isim shell: Live Activity alert %s: banner\n", it->id);
    }
}
/* alerts ending, ended activities reaching their dismissal time */
static void la_tick(void) {
    int redraw = 0;
    la_sync_status_bars();
    if (la.alert_until && now() >= la.alert_until) {
        if (la.alert_expand && !strcmp(la.exp_id, la.alert_id)) { la.exp_id[0] = 0; fprintf(stderr, "isim shell: Dynamic Island compact (alert ended)\n"); }
        la.alert_until = 0; la.alert_expand = la.alert_banner = 0; la.alert_id[0] = 0; redraw = 1;
    }
    double w = wall_now();
    for (int i = 0; i < LA_MAX; i++) if (las[i].on && las[i].ended && las[i].dismiss_at <= w) {
        fprintf(stderr, "isim shell: Live Activity %s dismissed\n", las[i].id);
        la_remove(i); redraw = 1;
    }
    if (!redraw) return;
    if (ov != OV_NONE) sys_draw(); else shell_show(active >= 0 ? active : 0);
}
static double la_draw_lock(cairo_t *c, double top) {           /* returns the height used */
    int order[LA_MAX], n = 0;
    for (int i = 0; i < LA_MAX; i++) if (las[i].on && las[i].lock) order[n++] = i;
    for (int a = 1; a < n; a++) for (int b = a; b > 0; b--) {   /* alerting first, then the most relevant, then the newest */
        struct la_item *x = &las[order[b - 1]], *y = &las[order[b]];
        int ya = la.alert_until > now() && !strcmp(y->id, la.alert_id), xa = la.alert_until > now() && !strcmp(x->id, la.alert_id);
        if (ya > xa || (ya == xa && (y->relevance > x->relevance || (y->relevance == x->relevance && y->started > x->started)))) { int t = order[b]; order[b] = order[b - 1]; order[b - 1] = t; }
    }
    double w = fmin(dev.width - 16, 400), x = (dev.width - w) / 2, h = w * 160 / 370, y = top;
    for (int k = 0; k < n && k < 3; k++) {
        struct la_item *it = &las[order[k]];
        cairo_save(c);
        sys_round(c, x, y, w, h, 22); cairo_clip_preserve(c);
        cairo_set_source_rgba(c, 0.95, 0.95, 0.97, 0.88); cairo_fill(c);
        la_img(c, it->lock, x, y, w, h);
        cairo_restore(c);
        if (la.alert_until > now() && !strcmp(it->id, la.alert_id)) {     /* lit up by an alert */
            cairo_new_path(c); sys_round(c, x - 2, y - 2, w + 4, h + 4, 24); cairo_set_source_rgba(c, 1, 1, 1, 0.95); cairo_set_line_width(c, 3); cairo_stroke(c);
        }
        char eid[32]; if (k) snprintf(eid, sizeof eid, "live-activity-%d", k + 1); else snprintf(eid, sizeof eid, "live-activity");
        el_add(eid, it->id, (struct rectf){ x, y, w, h }, EL_LA, order[k]);
        y += h + 10;
    }
    return y - top;
}
/* a tap on a Live Activity (lock screen, banner): the app opens, with its widgetURL */
static void la_open(int i) {
    if (i < 0 || i >= LA_MAX || !las[i].on) return;
    fprintf(stderr, "isim shell: Live Activity %s opens its app%s%s\n", las[i].id, las[i].url[0] ? " with " : "", las[i].url);
    if (locked) sys_unlock();
    la.alert_banner = 0;
    sys_send_text(0, "la-open %s\x1f%s", las[i].app, las[i].url);
}

/* ---- Lock Screen widgets (WidgetKit accessory families, rendered vibrant by the app's widget extension; the home
   screen sends "lw-set SIDECAR": inline=FILE\x1fAPP\x1fKIND and widget=FAMILY\x1fFILE\x1fAPP\x1fKIND lines). The
   inline widget sits next to the (shortened) date above the clock; up to four units of circular (one unit, 72 pt) and
   rectangular (two units, 160 x 72) widgets in a row under the clock, 16 pt apart (estimated from iPhone 15/16 Pro
   screenshots). A long press on the Lock Screen (or `lockscreen customize`) opens the home screen's editor. ---- */
struct lw_item { int family; cairo_surface_t *img; char app[256], kind[128]; double cx0, cx1; };   /* family: 0 inline, 1 circular, 2 rectangular */
static struct lw_item lws[5]; static int nlw;
static int lock_editing, lock_edit_active;
static void lw_clear(void) { for (int i = 0; i < nlw; i++) if (lws[i].img) cairo_surface_destroy(lws[i].img); memset(lws, 0, sizeof lws); nlw = 0; }
static void lw_set(const char *sidecar) {
    FILE *f = fopen(sidecar, "r");
    if (!f) return;
    lw_clear();
    char line[1400];
    while (fgets(line, sizeof line, f) && nlw < 5) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        char fam[32] = "", file[900] = "";
        struct lw_item *it = &lws[nlw];
        if (!strcmp(line, "inline")) { it->family = 0; field(v, 0, file, sizeof file); field(v, 1, it->app, sizeof it->app); field(v, 2, it->kind, sizeof it->kind); }
        else if (!strcmp(line, "widget")) {
            field(v, 0, fam, sizeof fam); field(v, 1, file, sizeof file); field(v, 2, it->app, sizeof it->app); field(v, 3, it->kind, sizeof it->kind);
            it->family = !strcmp(fam, "accessoryRectangular") ? 2 : 1;
        } else continue;
        if (file[0]) {
            it->img = cairo_image_surface_create_from_png(file);
            if (cairo_surface_status(it->img) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(it->img); it->img = NULL; }
        }
        if (it->img && it->family == 0) {                  /* the inline content's horizontal extent (it is centred in its frame) */
            cairo_surface_flush(it->img);
            int w = cairo_image_surface_get_width(it->img), h = cairo_image_surface_get_height(it->img), st = cairo_image_surface_get_stride(it->img);
            unsigned char *px = cairo_image_surface_get_data(it->img); int x0 = w, x1 = -1;
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) if (px[y * st + x * 4 + 3] > 8) { if (x < x0) x0 = x; if (x > x1) x1 = x; }
            it->cx0 = x1 >= x0 ? (double)x0 / w : 0; it->cx1 = x1 >= x0 ? (double)(x1 + 1) / w : 1;
        }
        nlw++;
    }
    fclose(f);
    fprintf(stderr, "isim shell: Lock Screen widgets: %d\n", nlw);
    if (ov == OV_LOCK) sys_draw();
}
/* under the clock: iOS 26's tall numerals (lock_draw: dev.width * 0.40 from top + 40, the layout's line ~1.18 of it) */
static double lw_row_top(void) { double top = fmax(dev.safe_top, 20); return sys_os() >= 26 ? round(top + 40 + dev.width * 0.40 * 1.18 + 8) : top + 162; }
/* the date line (with the inline widget) */
static void lw_draw_date(cairo_t *c, double top, const char *dstr) {
    struct lw_item *in = NULL;
    for (int i = 0; i < nlw; i++) if (lws[i].family == 0) in = &lws[i];
    if (!in) { sys_text(c, dstr, 0, top + 30, dev.width, 19, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.9); return; }
    char shortd[32]; time_t t = time(NULL); struct tm tm; localtime_r(&t, &tm); strftime(shortd, sizeof shortd, "%a %e", &tm);
    char *dbl = strstr(shortd, "  "); if (dbl) memmove(dbl, dbl + 1, strlen(dbl));
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_new();
    pango_font_description_set_family(fd, SYSTEM_SANS); pango_font_description_set_absolute_size(fd, 19 * PANGO_SCALE); pango_font_description_set_weight(fd, PANGO_WEIGHT_SEMIBOLD);
    pango_layout_set_font_description(l, fd); pango_font_description_free(fd); pango_layout_set_text(l, shortd, -1);
    int dw, dh; pango_layout_get_pixel_size(l, &dw, &dh); g_object_unref(l);
    double iw = 234, ih = 26, cw = in->img ? (in->cx1 - in->cx0) * iw : 0, gap = 8, total = dw + (cw > 0 ? gap + cw : 0), x = (dev.width - total) / 2;
    sys_text(c, shortd, x, top + 30, 0, 19, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 0.9);
    double iy = top + 30 + (dh - ih) / 2;
    if (in->img) {
        cairo_save(c); cairo_rectangle(c, x + dw + gap, iy, cw, ih); cairo_clip(c);
        la_img(c, in->img, x + dw + gap - in->cx0 * iw, iy, iw, ih); cairo_restore(c);
    }
    el_add("lock-widget-inline", in->kind, (struct rectf){ x + dw + gap, iy, cw, ih }, EL_LW, (int)(in - lws));
}
/* the row under the clock; returns its bottom (0: no widgets) */
/* WidgetKit's Lock Screen sizes: circular 72 x 72 and rectangular 160 x 72 pt on the 6.1" phones, 76 and 172 x 76 on the
   6.7" (Plus / Pro Max) class, 16 pt apart; a widget whose render is still on its way shows a placeholder, as on iOS */
static double lw_h(void) { return dev.width >= 428 ? 76 : 72; }
static double lw_w(int family) { return family == 2 ? (dev.width >= 428 ? 172 : 160) : lw_h(); }
static double lw_draw_row(cairo_t *c) {
    double total = 0, h = lw_h(); int n = 0;
    for (int i = 0; i < nlw; i++) if (lws[i].family) { total += lw_w(lws[i].family); n++; }
    if (!n) return 0;
    total += 16 * (n - 1);
    double x = (dev.width - total) / 2, y = lw_row_top(); int k = 0;
    for (int i = 0; i < nlw; i++) {
        if (!lws[i].family) continue;
        double w = lw_w(lws[i].family);
        if (lws[i].img) la_img(c, lws[i].img, x, y, w, h);
        else { cairo_new_path(c); sys_round(c, x, y, w, h, lws[i].family == 2 ? 18 : h / 2); cairo_set_source_rgba(c, 1, 1, 1, 0.18); cairo_fill(c); }
        char id[32]; snprintf(id, sizeof id, "lock-widget-%d", ++k);
        el_add(id, lws[i].kind, (struct rectf){ x, y, w, h }, EL_LW, i);
        x += w + 16;
    }
    return y + h;
}
static void lw_open(int i) {
    if (i < 0 || i >= nlw) return;
    fprintf(stderr, "isim shell: Lock Screen widget %s opens its app\n", lws[i].kind);
    sys_unlock();
    sys_send_text(0, "lw-open %d", i);
}
/* the Lock Screen editor (a long press on the Lock Screen > Customize): the home screen draws it while the device
   stays locked; "lock-edit-done" brings the Lock Screen back */
static void lock_customize(void) {
    if (!locked || lock_editing || ov != OV_LOCK) return;
    lock_editing = 1; lock_edit_active = active;
    ov = OV_NONE; active = 0;
    fprintf(stderr, "isim shell: Lock Screen customization\n");
    shell_send(0, EV_FOREGROUND);
    sys_send_text(0, "lock-customize");
    shell_show(0);
}
static void lock_customize_done(void) {
    if (!lock_editing) return;
    lock_editing = 0;
    shell_send(0, EV_BACKGROUND);
    active = lock_edit_active; ov = OV_LOCK; ov_t0 = now() - 1;
    fprintf(stderr, "isim shell: Lock Screen customization done\n");
    sys_draw();
}

/* ---- StandBy (iOS 17+: an iPhone on its side while charging): `standby on` locks the device, turns it to landscape
   and shows two widgets side by side, full colour, without their container backgrounds, on black (the home screen
   renders the first two small home-screen widgets, "sb-set SIDECAR": left= / right=FILE\x1fAPP\x1fKIND); an empty
   side shows the system's clock (adapted: isim's digital clock). ---- */
static int standby;
static struct { cairo_surface_t *img; char app[256], kind[128]; } sbw[2];
static void sb_clear(void) { for (int i = 0; i < 2; i++) { if (sbw[i].img) cairo_surface_destroy(sbw[i].img); memset(&sbw[i], 0, sizeof sbw[i]); } }
static void sb_set(const char *sidecar) {
    FILE *f = fopen(sidecar, "r");
    if (!f) return;
    sb_clear();
    char line[1400]; int n = 0;
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        int i = !strcmp(line, "left") ? 0 : !strcmp(line, "right") ? 1 : -1;
        if (i < 0) continue;
        char file[900]; field(v, 0, file, sizeof file); field(v, 1, sbw[i].app, sizeof sbw[i].app); field(v, 2, sbw[i].kind, sizeof sbw[i].kind);
        sbw[i].img = cairo_image_surface_create_from_png(file);
        if (cairo_surface_status(sbw[i].img) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(sbw[i].img); sbw[i].img = NULL; } else n++;
    }
    fclose(f);
    fprintf(stderr, "isim shell: StandBy widgets: %d\n", n);
    if (standby && ov == OV_LOCK) sys_draw();
}
static void standby_draw(cairo_t *c) {
    cairo_set_source_rgb(c, 0, 0, 0); cairo_paint(c);
    double l = fmax(dev.safe_left, 20), r = fmax(dev.safe_right, 20), gap = 24, avail = dev.width - l - r;
    double side = fmin(dev.height - 40, (avail - gap) / 2), x0 = l + (avail - 2 * side - gap) / 2, y = (dev.height - side) / 2;
    for (int i = 0; i < 2; i++) {
        struct rectf s = { x0 + i * (side + gap), y, side, side };
        if (sbw[i].img) la_img(c, sbw[i].img, s.x, s.y, s.w, s.h);
        else {                                              /* the system's clock */
            char t[16], d[64]; sys_time_strings(t, sizeof t, d, sizeof d);
            const char *fixed = getenv("ISIM_LOCK_TIME"); if (fixed && *fixed) snprintf(t, sizeof t, "%s", fixed);
            sys_text(c, t, s.x, s.y + side * 0.22, s.w, side * 0.42, PANGO_WEIGHT_HEAVY, 1, 1, 1, 1, 1, 0.95);
            sys_text(c, d, s.x, s.y + side * 0.78, s.w, 20, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 0.7);
        }
        el_add(i ? "standby-widget-right" : "standby-widget-left", sbw[i].img ? sbw[i].kind : "Clock", s, EL_NONE, i);
    }
}
static void standby_set(int on) {
    if (on == standby) return;
    if (on) {
        if (!locked) sys_lock();
        standby = 1;
        shell_apply_orient(3);
        fprintf(stderr, "isim shell: StandBy on (charging, landscape)\n");
        sys_send_text(0, "standby on");
    } else {
        standby = 0; sb_clear();
        shell_apply_orient(1);
        fprintf(stderr, "isim shell: StandBy off\n");
        sys_send_text(0, "standby off");
    }
    if (ov == OV_LOCK) sys_draw();
}

/* ---- widget extension helpers (WidgetKit): short-lived processes the home screen asks for ---- */
static struct { pid_t pid; char req[512]; int ext; } helpers[16];
/* a notification extension's control FIFO (<request>.ctl, its ISIM_CONTROL): the shell drives an interactive Content
   extension session through it (taps, and system events: "sysevent nx-...") */
static void helper_ctl_path(const char *req, char *out, size_t n) { snprintf(out, n, "%s.ctl", req); }
static void sys_run_helper_kind(const char *exe, const char *req, int ext);
static void sys_run_helper(const char *exe, const char *req) { sys_run_helper_kind(exe, req, 0); }
/* ext: a notification extension (ISIM_EXTENSION_REQUEST; "ext-done" when it exits), else a widget extension */
static void sys_run_helper_kind(const char *exe, const char *req, int ext) {
    int slot = -1;
    for (int i = 0; i < 16; i++) if (!helpers[i].pid) { slot = i; break; }
    if (slot < 0) { fprintf(stderr, "isim shell: too many widget extension processes\n"); return; }
    char ctl[600] = "";
    if (ext) { helper_ctl_path(req, ctl, sizeof ctl); unlink(ctl); if (mkfifo(ctl, 0600) != 0) ctl[0] = 0; }
    pid_t shell_pid = getpid(), pid = fork();
    if (pid < 0) return;
    if (pid == 0) {
        prctl(PR_SET_PDEATHSIG, SIGKILL);                   /* dies with the shell */
        if (getppid() != shell_pid) _exit(1);
        for (int fd = 3; fd < 256; fd++) close(fd);
        unsetenv("ISIM_CLIENT_SOCK"); unsetenv("ISIM_CLIENT_SURFACE"); unsetenv("ISIM_SCRIPT"); unsetenv("ISIM_CONTROL");
        unsetenv("ISIM_LAUNCH_URL"); unsetenv("ISIM_LAUNCH_BACKGROUND");
        setenv("ISIM_HEADLESS", "1", 1); setenv(ext ? "ISIM_EXTENSION_REQUEST" : "ISIM_WIDGET_REQUEST", req, 1); setenv("ISIM_MUTE", "1", 1);
        if (ctl[0]) setenv("ISIM_CONTROL", ctl, 1);
        execl(shell_self, shell_self, "--root", shell_root, exe, (char *)NULL);
        _exit(127);
    }
    helpers[slot].pid = pid; helpers[slot].ext = ext; snprintf(helpers[slot].req, sizeof helpers[slot].req, "%s", req);
}
static void sys_reaped(pid_t pid, int status) {
    for (int i = 0; i < 16; i++) if (helpers[i].pid == pid) {
        helpers[i].pid = 0;
        if (helpers[i].ext) { char ctl[600]; helper_ctl_path(helpers[i].req, ctl, sizeof ctl); unlink(ctl); }
        sys_send_text(0, "%s %d %s", helpers[i].ext ? "ext-done" : "widget-done", WIFEXITED(status) ? WEXITSTATUS(status) : 128, helpers[i].req);
    }
}


/* ======================= background execution =======================
 * Like iOS, an app that goes to the background is suspended (SIGSTOP: its timers and run loop stop) a few seconds
 * later (ISIM_SUSPEND_SECONDS, default 5) unless it reported something that keeps it running ("bg-assert REASONS":
 * task, audio, location, location-indicator). Any event the shell sends a suspended app resumes it (SIGCONT) for a new
 * grace period — a background task launch, a push, a notification action, going back to the app — and so does the
 * time of its next local notification ("bg-wake T"), which it then delivers itself. ISIM_SUSPEND=0 turns this off.
 * Adapted: iOS suspends right after the app's background work ends; the home screen (client 0) is never suspended. */
static double wall_now(void) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
static int suspend_enabled(void) { const char *e = getenv("ISIM_SUSPEND"); return !(e && !strcmp(e, "0")); }
static double suspend_after(void) { const char *e = getenv("ISIM_SUSPEND_SECONDS"); return e && atof(e) > 0 ? atof(e) : 5; }
static const char *short_name(int i) { const char *b = strrchr(clients[i].bundle, '/'); return b ? b + 1 : clients[i].bundle; }
static void bg_resume(int i, const char *why) {
    if (!clients[i].suspended) return;
    kill(clients[i].pid, SIGCONT);
    clients[i].suspended = 0; clients[i].bg_t = now();
    fprintf(stderr, "isim shell: resumed %s (%s)\n", short_name(i), why);
}
static void bg_track(int i, int type) {
    if (i <= 0) return;
    struct shell_client *c = &clients[i];
    if (type == EV_BACKGROUND) { if (!c->bg) { c->bg = 1; c->bg_seen = 0; c->bg_t = now(); c->reasons[0] = 0; } }
    else if (type == EV_FOREGROUND) { bg_resume(i, "foreground"); c->bg = 0; c->wake_at = 0; }
    if (c->suspended && type != EV_SETTINGS && type != EV_DEVICE_ORIENTATION && type != EV_REDRAW) {
        const char *why = type == EV_SYSTEM ? "system event" : type == EV_QUIT ? "quit" : type == EV_OPEN_URL ? "URL" : type == EV_NOTIFICATION_RESPONSE ? "notification" : "event";
        bg_resume(i, why);
    }
}
static void bg_tick(void) {
    if (!suspend_enabled()) return;
    double t = now();
    for (int i = 1; i < nclients; i++) {
        struct shell_client *c = &clients[i];
        if (!c->alive || !c->bg) continue;
        if (c->suspended) {
            if (c->wake_at > 0 && wall_now() >= c->wake_at) { c->wake_at = 0; bg_resume(i, "a local notification is due"); }
            continue;
        }
        if (c->reasons[0]) continue;
        double grace = suspend_after() * (c->bg_seen ? 1 : 2);      /* an app that did not report yet gets longer */
        if (t - c->bg_t < grace) continue;
        if (anim.kind != ANIM_NONE && anim.client == i) continue;
        if (kill(c->pid, SIGSTOP) == 0) { c->suspended = 1; fprintf(stderr, "isim shell: suspended %s\n", short_name(i)); }
    }
}
/* ======================= Picture in Picture =======================
 * An app's AVPictureInPictureController hands its video to the system: "pip-start URL\x1fTITLE", c = "TIME RATE W H FPS";
 * "pip-update", c = "TIME RATE"; "pip-stop". The shell decodes the video itself (host_media.c: frames only; the app's
 * player keeps the sound) and floats it over the screen — over the app, the home screen and other apps — until the app
 * stops it. Like iOS: tap shows the controls (close, return to the app, skip ±15 s, play/pause); drag moves it to a
 * corner. Controls send the app "pip close|restore|play|pause|skip SECONDS" system events. Elements: pip-window,
 * pip-close, pip-restore, pip-play, pip-skip-back, pip-skip-forward. */
struct isim_media_info { double duration, width, height, fps; int has_video, has_audio; };
int isim_media_probe(const char *url, struct isim_media_info *info);
int isim_media_open_rate(const char *url, double start, double width, double height, double fps, int want_video, int want_audio, double volume, double rate);
int isim_media_video_frame(int h, double t, int *eof, double *pts);
void isim_media_close(int h);
int isim_image_read_bgra(int hd, int x, int y, int w, int h, unsigned char *out);
static struct {
    int on, client, media, corner, controls, down, moved;
    char url[1024], title[256];
    double t0, at, rate, vw, vh, fps, mw, mh, controls_t, ox, oy, dx, dy;
    unsigned char *px;
} pip = { .corner = 3 };
static int pip_visible(void) { return pip.on && pip.client > 0 && pip.client < nclients && clients[pip.client].alive && !locked && ov == OV_NONE && anim.kind == ANIM_NONE; }
static double pip_time(void) { return pip.t0 + (pip.rate > 0 ? (now() - pip.at) * pip.rate : 0); }
static struct rectf pip_rect(void) {
    double w = fmin(dev.width * 0.62, 260), h = pip.vw > 0 ? w * pip.vh / pip.vw : w * 9 / 16;
    if (h > dev.height * 0.4) { h = dev.height * 0.4; w = pip.vh > 0 ? h * pip.vw / pip.vh : w; }
    double m = 10, top = fmax(dev.safe_top, 20) + 6, bottom = dev.height - fmax(dev.safe_bottom, 10) - 10 - h;
    struct rectf r = { pip.corner & 1 ? dev.width - m - w : m, pip.corner & 2 ? bottom : top, w, h };
    if (pip.down && pip.moved) { r.x += pip.dx; r.y += pip.dy; }
    return r;
}
static void pip_open_media(void) {
    if (pip.media > 0) { isim_media_close(pip.media); pip.media = 0; }
    double sc = fmax(pip.vw, pip.vh) > 960 ? 960 / fmax(pip.vw, pip.vh) : 1;
    pip.mw = (int)lround(pip.vw * sc / 2) * 2; pip.mh = (int)lround(pip.vh * sc / 2) * 2;
    if (pip.mw < 2 || pip.mh < 2) return;
    pip.media = isim_media_open_rate(pip.url, pip_time(), pip.vw, pip.vh, pip.fps, 1, 0, 0, pip.rate > 0 ? pip.rate : 1);
    free(pip.px); pip.px = malloc((size_t)pip.mw * pip.mh * 4); memset(pip.px, 0, (size_t)pip.mw * pip.mh * 4);
}
static void pip_stop(void) {
    if (pip.media > 0) isim_media_close(pip.media);
    pip.media = 0; pip.on = 0; free(pip.px); pip.px = NULL;
}
static void pip_glyph(cairo_t *c, const char *g, double cx, double cy, double s) {
    cairo_save(c); cairo_set_source_rgb(c, 1, 1, 1); cairo_set_line_width(c, s * 0.12); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND);
    cairo_set_line_join(c, CAIRO_LINE_JOIN_ROUND); cairo_new_path(c);
    if (!strcmp(g, "close")) { double d = s * 0.32; cairo_move_to(c, cx - d, cy - d); cairo_line_to(c, cx + d, cy + d); cairo_move_to(c, cx + d, cy - d); cairo_line_to(c, cx - d, cy + d); cairo_stroke(c); }
    else if (!strcmp(g, "play")) { cairo_move_to(c, cx - s * 0.3, cy - s * 0.42); cairo_line_to(c, cx + s * 0.45, cy); cairo_line_to(c, cx - s * 0.3, cy + s * 0.42); cairo_close_path(c); cairo_fill(c); }
    else if (!strcmp(g, "pause")) { sys_round(c, cx - s * 0.36, cy - s * 0.42, s * 0.24, s * 0.84, s * 0.05); sys_round(c, cx + s * 0.12, cy - s * 0.42, s * 0.24, s * 0.84, s * 0.05); cairo_fill(c); }
    else if (!strcmp(g, "restore")) {                                 /* a screen with a small window: back to the app */
        sys_round(c, cx - s * 0.45, cy - s * 0.34, s * 0.9, s * 0.68, s * 0.1); cairo_stroke(c);
        sys_round(c, cx + s * 0.02, cy + s * 0.0, s * 0.3, s * 0.22, s * 0.04); cairo_fill(c);
    } else {                                                          /* skip: an arc with an arrow head and "15" */
        int fwd = !strcmp(g, "fwd");
        cairo_arc(c, cx, cy, s * 0.42, fwd ? -M_PI * 0.45 : -M_PI * 0.55 - 0.0, fwd ? M_PI * 1.25 : -M_PI * 2.25);
        if (!fwd) { cairo_new_path(c); cairo_arc_negative(c, cx, cy, s * 0.42, -M_PI * 0.55, M_PI * -2.25 + M_PI * 2); }
        cairo_stroke(c);
        double tx = cx + (fwd ? s * 0.05 : -s * 0.05), ty = cy - s * 0.42;
        cairo_move_to(c, tx + (fwd ? -s * 0.12 : s * 0.12), ty - s * 0.12); cairo_line_to(c, tx + (fwd ? s * 0.06 : -s * 0.06), ty); cairo_line_to(c, tx + (fwd ? -s * 0.12 : s * 0.12), ty + s * 0.12);
        cairo_stroke(c);
        sys_text(c, "15", cx - s * 0.5, cy - s * 0.2, s, s * 0.32, PANGO_WEIGHT_BOLD, 1, 1, 1, 1, 1, 1);
    }
    cairo_restore(c);
}
static struct rectf pip_button(const char *which) {
    struct rectf r = pip_rect(); double b = 36;
    if (!strcmp(which, "pip-close")) return (struct rectf){ r.x + 4, r.y + 4, b, b };
    if (!strcmp(which, "pip-restore")) return (struct rectf){ r.x + r.w - 4 - b, r.y + 4, b, b };
    if (!strcmp(which, "pip-play")) return (struct rectf){ r.x + r.w / 2 - 22, r.y + r.h / 2 - 22, 44, 44 };
    if (!strcmp(which, "pip-skip-back")) return (struct rectf){ r.x + r.w / 2 - 22 - 56, r.y + r.h / 2 - 20, 40, 40 };
    return (struct rectf){ r.x + r.w / 2 + 22 + 16, r.y + r.h / 2 - 20, 40, 40 };
}
static void pip_draw(cairo_t *c) {
    if (!pip_visible()) return;
    struct rectf r = pip_rect();
    if (pip.controls && now() - pip.controls_t > 3) pip.controls = 0;
    cairo_save(c);
    cairo_new_path(c); sys_round(c, r.x - 1, r.y + 2, r.w + 2, r.h + 2, 13); cairo_set_source_rgba(c, 0, 0, 0, 0.25); cairo_fill(c);
    cairo_new_path(c); sys_round(c, r.x, r.y, r.w, r.h, 12); cairo_clip(c);
    cairo_set_source_rgb(c, 0, 0, 0); cairo_paint(c);
    if (pip.media > 0 && pip.px) {
        int eof = 0; double pts = 0;
        int img = isim_media_video_frame(pip.media, pip_time(), &eof, &pts);
        if (img > 0) isim_image_read_bgra(img, 0, 0, (int)pip.mw, (int)pip.mh, pip.px);
        cairo_surface_t *f = cairo_image_surface_create_for_data(pip.px, CAIRO_FORMAT_ARGB32, (int)pip.mw, (int)pip.mh, (int)pip.mw * 4);
        cairo_save(c); cairo_translate(c, r.x, r.y); cairo_scale(c, r.w / pip.mw, r.h / pip.mh);
        cairo_set_source_surface(c, f, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
        cairo_restore(c); cairo_surface_destroy(f);
    }
    char t[300]; snprintf(t, sizeof t, "%s %s", pip.title[0] ? pip.title : app_label(pip.client), pip.rate > 0 ? "playing" : "paused");
    el_add("pip-window", t, r, EL_NONE, 0);
    if (pip.controls) {
        cairo_set_source_rgba(c, 0, 0, 0, 0.35); cairo_paint(c);
        struct { const char *id, *glyph; double size; } b[5] = { { "pip-close", "close", 18 }, { "pip-restore", "restore", 22 },
            { "pip-skip-back", "back", 26 }, { "pip-play", pip.rate > 0 ? "pause" : "play", 30 }, { "pip-skip-forward", "fwd", 26 } };
        for (int k = 0; k < 5; k++) {
            struct rectf br = pip_button(b[k].id);
            pip_glyph(c, b[k].glyph, br.x + br.w / 2, br.y + br.h / 2, b[k].size);
            el_add(b[k].id, k == 3 ? (pip.rate > 0 ? "pause" : "play") : "", br, EL_NONE, 0);
        }
    }
    cairo_restore(c);
}
static void pip_action(const char *id) {
    const char *a = !strcmp(id, "pip-close") ? "close" : !strcmp(id, "pip-restore") ? "restore" : !strcmp(id, "pip-play") ? (pip.rate > 0 ? "pause" : "play")
        : !strcmp(id, "pip-skip-back") ? "skip -15" : !strcmp(id, "pip-skip-forward") ? "skip 15" : NULL;
    if (!a) return;
    fprintf(stderr, "isim shell: Picture in Picture %s (%s)\n", a, app_label(pip.client));
    int app = pip.client;
    if (!strcmp(a, "restore") && app != active) shell_launch(clients[app].bundle, clients[app].exe, NULL);   /* back to the app */
    sys_send_text(app, "pip %s", a);
    pip.controls_t = now();
}
/* touches on the floating window: tap shows the controls (or presses one), a drag moves it to another corner */
static int pip_input(const struct isim_event *ev) {
    if (!pip_visible()) return 0;
    if (ev->type == EV_DUMP) {                                       /* `dump`: the floating window and its controls */
        struct rectf r = pip_rect();
        fprintf(stderr, "IsimPictureInPicture (%g %g; %g x %g) id=pip-window text=%s %s\n", r.x, r.y, r.w, r.h,
                pip.title[0] ? pip.title : app_label(pip.client), pip.rate > 0 ? "playing" : "paused");
        if (pip.controls) {
            const char *ids[5] = { "pip-close", "pip-restore", "pip-skip-back", "pip-play", "pip-skip-forward" };
            for (int k = 0; k < 5; k++) { struct rectf b = pip_button(ids[k]); fprintf(stderr, "  IsimControlButton (%g %g; %g x %g) id=%s%s\n", b.x, b.y, b.w, b.h, ids[k], k == 3 ? (pip.rate > 0 ? " text=pause" : " text=play") : ""); }
        }
        return 0;
    }
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        if (strncmp(ev->text, "pip-", 4)) return 0;
        if (ev->type == EV_ID_UP) { if (!strcmp(ev->text, "pip-window")) { pip.controls = !pip.controls; pip.controls_t = now(); } else if (pip.controls) pip_action(ev->text); shell_show(active); }
        return 1;
    }
    struct rectf r = pip_rect();
    int inside = ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h;
    if (ev->type == EV_TOUCH_DOWN) { if (!inside) return 0; pip.down = 1; pip.moved = 0; pip.ox = ev->x; pip.oy = ev->y; pip.dx = pip.dy = 0; return 1; }
    if (!pip.down) return 0;
    if (ev->type == EV_TOUCH_MOVE) {
        pip.dx = ev->x - pip.ox; pip.dy = ev->y - pip.oy;
        if (fabs(pip.dx) + fabs(pip.dy) > 8) pip.moved = 1;
        shell_show(active); return 1;
    }
    if (ev->type == EV_TOUCH_UP) {
        if (pip.moved) {
            struct rectf m = pip_rect();
            pip.corner = (m.x + m.w / 2 > dev.width / 2 ? 1 : 0) | (m.y + m.h / 2 > dev.height / 2 ? 2 : 0);
            fprintf(stderr, "isim shell: Picture in Picture moved to the %s %s corner\n", pip.corner & 2 ? "bottom" : "top", pip.corner & 1 ? "right" : "left");
        } else if (!pip.controls) { pip.controls = 1; pip.controls_t = now(); }
        else {
            const char *ids[5] = { "pip-close", "pip-restore", "pip-play", "pip-skip-back", "pip-skip-forward" }; int hit = 0;
            for (int k = 0; k < 5; k++) { struct rectf b = pip_button(ids[k]); if (ev->x >= b.x && ev->x <= b.x + b.w && ev->y >= b.y && ev->y <= b.y + b.h) { pip_action(ids[k]); hit = 1; break; } }
            if (!hit) pip.controls = 0;
        }
        pip.down = 0; pip.moved = 0;
        shell_show(active); return 1;
    }
    return 0;
}

/* the blue location indicator (iOS: the status bar's time on a blue capsule while an app uses location in the background) */
static int pill_client(void) {
    if (locked || ov != OV_NONE) return -1;
    for (int i = 1; i < nclients; i++)
        if (clients[i].alive && clients[i].bg && i != active && strstr(clients[i].reasons, "location-indicator")) return i;
    return -1;
}
static int pill_visible(void) { return pill_client() > 0 && anim.kind == ANIM_NONE; }
static struct rectf pill_rect(double *tw) {
    double w = 46;                                                  /* the status bar clock's width ("12:34" at 17 pt) */
    if (tw) *tw = w;
    double cx = dev.has_island ? 51 + 26 : 8 + w / 2, cy = dev.has_island ? 29 : (dev.safe_top >= 44 ? 27 : dev.safe_top / 2);
    return (struct rectf){ cx - w / 2 - 12, cy - 13, w + 24, 26 };
}
static void pill_draw(cairo_t *c) {
    int i = pill_client();
    if (i <= 0) return;
    struct rectf r = pill_rect(NULL);
    sys_round(c, r.x, r.y, r.w, r.h, r.h / 2); cairo_set_source_rgb(c, 0.0, 0.48, 1.0); cairo_fill(c);
    time_t tt = time(NULL); struct tm tm; localtime_r(&tt, &tm);
    char clock[16]; snprintf(clock, sizeof clock, "%d:%02d", tm.tm_hour % 12 ? tm.tm_hour % 12 : 12, tm.tm_min);
    sys_text(c, clock, r.x, r.y + 3, r.w, 16, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
    el_add("location-indicator", app_label(i), r, EL_NONE, i);
}

/* ======================= expanded notifications =======================
 * A long press on a notification (Notification Center, lock screen, banner) expands it: the shell asks the home screen
 * ("nc-expand PATH\x1fRECORD\x1fID"), which reads the app's categories and runs its Notification Content extension, then
 * answers "nc-expanded RECORD SIDECAR" (a text file: image=, height=, hidden=, dismiss=, action=ID\x1eTITLE\x1eOPTIONS\x1e
 * TEXT\x1eBUTTON\x1ePLACEHOLDER lines). The shell draws the card (the extension's image, else the title and body) and the
 * actions; a text input action opens a reply field (`type` and `key return`). Responses go to the app: "nc-action
 * RECORD\x1fID\x1fACTION\x1fTEXT" (EV_SYSTEM), or a launch with isim-nc-action:... when it is not running. */
struct nx_action { char id[128], title[128], button[64], placeholder[128]; int opts, text; };
static struct {
    int on, loading, hidden, dismiss, nact, reply;          /* reply: index of the text input action being answered + 1 */
    struct nc_item it; cairo_surface_t *img; double img_h; struct nx_action act[8]; char text[512];
    /* an interactive Content extension session: its directory (state, frames) and control FIFO; interactive: taps on
       the view go to it (UNNotificationExtensionUserInteractionEnabled); responds: it answers actions first */
    char session[512], ctl[600], frame[600]; int interactive, responds, seq, answer_seq, media, playing, waiting; double ext_w, media_r[4];
    struct timespec state_mtime; char wait_action[128], wait_text[512]; int wait_fg;
} nx;
static void nx_send(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void nx_send(const char *fmt, ...) {
    if (!nx.ctl[0]) return;
    int fd = open(nx.ctl, O_WRONLY | O_NONBLOCK);
    if (fd < 0) return;
    char line[1200]; va_list ap; va_start(ap, fmt); int n = vsnprintf(line, sizeof line - 1, fmt, ap); va_end(ap);
    if (n > (int)sizeof line - 2) n = (int)sizeof line - 2;
    line[n++] = '\n';
    if (write(fd, line, (size_t)n) < 0) {}
    close(fd);
}
static void nx_end_session(void) {
    if (nx.session[0]) { nx_send("sysevent nx-close"); fprintf(stderr, "isim shell: content extension session ended\n"); }
    nx.session[0] = nx.ctl[0] = nx.frame[0] = 0; nx.interactive = nx.responds = nx.media = nx.waiting = 0;
}
static void nx_free_image(void) { if (nx.img) { cairo_surface_destroy(nx.img); nx.img = NULL; } }
static int nc_find(const char *path, const char *id) {
    for (int k = 0; k < nnc; k++) if (!strcmp(ncl[k].path, path) && !strcmp(ncl[k].id, id)) return k;
    return -1;
}
static void nx_open_item(int idx) {
    if (idx < 0 || idx >= nnc) return;
    nx_free_image();
    memset(&nx.act, 0, sizeof nx.act);
    nx_end_session();
    nx.on = 1; nx.loading = 1; nx.hidden = nx.dismiss = nx.nact = nx.reply = 0; nx.text[0] = 0; nx.img_h = 0;
    nx.seq = nx.answer_seq = nx.playing = 0; memset(&nx.state_mtime, 0, sizeof nx.state_mtime);
    nx.it = ncl[idx];
    if (anim.kind != ANIM_NONE) anim.kind = ANIM_NONE;
    if (win_orient != 1) shell_apply_orient(1);
    ov = OV_NX; ov_t0 = now();
    fprintf(stderr, "isim shell: expanded notification %s\n", nx.it.id);
    sys_send_text(0, "nc-expand %s\x1f%s\x1f%s", nx.it.path, nx.it.record, nx.it.id);
    sys_draw();
}
/* the home screen's answer */
static void nx_loaded(const char *record, const char *sidecar) {
    if (!nx.on || strcmp(record, nx.it.record)) return;
    FILE *f = fopen(sidecar, "r");
    nx.loading = 0;
    if (!f) { sys_draw(); return; }
    char line[2048];
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        if (!strncmp(line, "image=", 6) && line[6]) {
            nx_free_image();
            nx.img = cairo_image_surface_create_from_png(line + 6);
            if (cairo_surface_status(nx.img) != CAIRO_STATUS_SUCCESS) nx_free_image();
        } else if (!strncmp(line, "height=", 7)) nx.img_h = atof(line + 7);
        else if (!strncmp(line, "session=", 8)) snprintf(nx.session, sizeof nx.session, "%s", line + 8);
        else if (!strncmp(line, "control=", 8)) snprintf(nx.ctl, sizeof nx.ctl, "%s", line + 8);
        else if (!strncmp(line, "interactive=", 12)) nx.interactive = atoi(line + 12);
        else if (!strncmp(line, "responds=", 9)) nx.responds = atoi(line + 9);
        else if (!strncmp(line, "width=", 6)) nx.ext_w = atof(line + 6);
        else if (!strncmp(line, "hidden=", 7)) nx.hidden = atoi(line + 7);
        else if (!strncmp(line, "dismiss=", 8)) nx.dismiss = atoi(line + 8);
        else if (!strncmp(line, "action=", 7) && nx.nact < 8) {
            struct nx_action *a = &nx.act[nx.nact++];
            char *p = line + 7, *parts[6] = { 0 }; int n = 0;
            parts[n++] = p;
            for (char *q = p; *q && n < 6; q++) if (*q == '\x1e') { *q = 0; parts[n++] = q + 1; }
            snprintf(a->id, sizeof a->id, "%s", parts[0] ? parts[0] : "");
            snprintf(a->title, sizeof a->title, "%s", parts[1] ? parts[1] : "");
            a->opts = parts[2] ? atoi(parts[2]) : 0; a->text = parts[3] ? atoi(parts[3]) : 0;
            snprintf(a->button, sizeof a->button, "%s", parts[4] && *parts[4] ? parts[4] : "Send");
            snprintf(a->placeholder, sizeof a->placeholder, "%s", parts[5] ? parts[5] : "");
        }
    }
    fclose(f);
    fprintf(stderr, "isim shell: expanded notification %s: %d action(s)%s%s\n", nx.it.id, nx.nact, nx.img ? ", content extension view" : "",
            nx.session[0] ? (nx.interactive ? " (interactive session)" : " (session)") : "");
    sys_draw();
}
static void nx_close(void) {
    nx_end_session();
    nx.on = 0; nx_free_image();
    if (ov == OV_NX) ov = locked ? OV_LOCK : OV_NONE;
    shell_show(active >= 0 ? active : 0);
}
/* deliver a response for the expanded notification to its app (launching it if needed) */
static void nx_respond(const char *action, const char *text, int foreground) {
    struct nc_item it = nx.it;
    int k = nc_find(it.path, it.id);
    if (k >= 0 && strcmp(action, "com.apple.UNNotificationDismissActionIdentifier")) { memmove(&ncl[k], &ncl[k + 1], (nnc - k - 1) * sizeof *ncl); nnc--; }
    fprintf(stderr, "isim shell: notification action %s on %s%s%s\n", action, it.id, text ? " with text: " : "", text ? text : "");
    nx_end_session();
    nx.on = 0; nx_free_image();
    ov = OV_NONE;
    if (foreground && locked) { locked = 0; fprintf(stderr, "isim shell: unlocked\n"); sys_protected_data(1); }
    if (locked) ov = OV_LOCK;
    char msg[1024]; snprintf(msg, sizeof msg, "%s\x1f%s\x1f%s\x1f%s", it.record, it.id, action, text ? text : "");
    int i = shell_find(it.path);
    if (i >= 0) {
        if (foreground && active != i) { if (active >= 0) shell_send(active, EV_BACKGROUND); active = i; shell_send(i, EV_FOREGROUND); }
        sys_send_text(i, "nc-action %s", msg);
    } else if (it.exe[0]) {
        char url[1100]; snprintf(url, sizeof url, "isim-nc-action:%s", msg);
        if (foreground) shell_launch(it.path, it.exe, url);
        else { spawn_background = 1; i = shell_spawn(it.path, it.exe, url); spawn_background = 0;
               if (i >= 0) fprintf(stderr, "isim shell: %s launched in the background\n", it.path); }
    } else fprintf(stderr, "isim shell: %s is not running\n", it.path);
    if (foreground && i >= 0) { double r0; struct rectf from = icon_target(i, &r0); start_anim(ANIM_OPEN, i, from, full_rect(), r0, dev.corner_radius, 0.45); }
    else shell_show(active >= 0 ? active : 0);
}
static void nx_draw(cairo_t *c) {
    double w = fmin(dev.width - 16, 400), x = (dev.width - w) / 2, y = fmax(dev.safe_top, 20) + 16;
    el_add("nx-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_BG, 0);
    /* the card: header, then the content extension's view or the title and body */
    double ch = 46, iw = w, ih = 0;
    if (nx.img) { double pw = cairo_image_surface_get_width(nx.img); ih = nx.img_h > 0 ? nx.img_h * w / fmax(1, w) : cairo_image_surface_get_height(nx.img) * w / pw; ch += ih; }
    PangoLayout *tl = NULL;
    double body_h = 0;
    if (!nx.img || !nx.hidden) {
        char text[1024]; snprintf(text, sizeof text, "%s", nx.it.body);
        tl = pango_cairo_create_layout(c);
        PangoFontDescription *fd = pango_font_description_from_string(SYSTEM_SANS " 15");
        pango_font_description_set_absolute_size(fd, 15 * PANGO_SCALE);
        pango_layout_set_font_description(tl, fd); pango_font_description_free(fd);
        pango_layout_set_width(tl, (int)((w - 32) * PANGO_SCALE)); pango_layout_set_wrap(tl, PANGO_WRAP_WORD_CHAR);
        pango_layout_set_text(tl, text, -1);
        int pw, ph; pango_layout_get_pixel_size(tl, &pw, &ph); body_h = ph;
        ch += 24 + body_h + 14;
    }
    if (nx.loading && !nx.img) ch += 0;
    struct rectf card = { x, y, w, ch };
    sys_round(c, card.x, card.y, card.w, card.h, 22); cairo_set_source_rgba(c, 0.97, 0.97, 0.98, 0.98); cairo_fill(c);
    sys_icon(c, nx.it.icon, x + 14, y + 12, 24);
    struct sys_appinfo *ai = sys_info(nx.it.path);
    sys_text(c, ai && ai->name[0] ? ai->name : "App", x + 46, y + 15, w - 120, 13, PANGO_WEIGHT_SEMIBOLD, 0, 1, 0.35, 0.35, 0.37, 1);
    sys_text(c, "now", x + w - 70, y + 15, 56, 13, PANGO_WEIGHT_NORMAL, 2, 1, 0.45, 0.45, 0.45, 1);
    double cy = y + 46;
    if (nx.img) {
        cairo_save(c); cairo_rectangle(c, x, cy, iw, ih); cairo_clip(c);
        double k = iw / cairo_image_surface_get_width(nx.img);
        cairo_translate(c, x, cy); cairo_scale(c, k, k);
        cairo_set_source_surface(c, nx.img, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
        cairo_restore(c);
        cy += ih;
    }
    if (tl) {
        sys_text(c, nx.it.title, x + 16, cy + 4, w - 32, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 0, 0, 0, 1);
        cairo_set_source_rgb(c, 0, 0, 0); cairo_move_to(c, x + 16, cy + 24); pango_cairo_show_layout(c, tl);
        g_object_unref(tl);
    }
    el_add("nx-content", nx.it.title, card, EL_NX_CONTENT, 0);
    if (nx.img && nx.session[0]) {
        struct rectf ir = { x, y + 46, iw, ih };
        double k = iw / (nx.ext_w > 0 ? nx.ext_w : iw);
        if (nx.interactive) el_add("nx-extension", "", ir, EL_NX_EXT, 0);    /* taps go to the extension's view */
        if (nx.media) {                                           /* the play / pause button the system draws over it */
            struct rectf mr = { ir.x + nx.media_r[0] * k, ir.y + nx.media_r[1] * k, nx.media_r[2] * k, nx.media_r[3] * k };
            double cx = mr.x + mr.w / 2, cyy = mr.y + mr.h / 2, rad = fmin(mr.w, mr.h) / 2;
            cairo_set_source_rgba(c, 1, 1, 1, nx.media == 2 ? 0.55 : 0.92); cairo_arc(c, cx, cyy, rad, 0, 2 * M_PI); cairo_fill(c);
            cairo_set_source_rgb(c, 0.1, 0.1, 0.12);
            if (nx.playing) { cairo_rectangle(c, cx - rad * 0.32, cyy - rad * 0.38, rad * 0.22, rad * 0.76); cairo_rectangle(c, cx + rad * 0.1, cyy - rad * 0.38, rad * 0.22, rad * 0.76); }
            else { cairo_move_to(c, cx - rad * 0.25, cyy - rad * 0.4); cairo_line_to(c, cx + rad * 0.42, cyy); cairo_line_to(c, cx - rad * 0.25, cyy + rad * 0.4); cairo_close_path(c); }
            cairo_fill(c);
            el_add("nx-media", nx.playing ? "Pause" : "Play", mr, EL_NX_MEDIA, 0);
        }
    }
    /* the actions */
    double ay = card.y + card.h + 10;
    if (nx.nact) {
        double rh = 48;
        struct rectf plat = { x, ay, w, rh * nx.nact };
        sys_round(c, plat.x, plat.y, plat.w, plat.h, 16); cairo_set_source_rgba(c, 0.97, 0.97, 0.98, 0.98); cairo_fill(c);
        for (int k = 0; k < nx.nact; k++) {
            struct rectf r = { x, ay + k * rh, w, rh };
            if (k) { cairo_set_source_rgba(c, 0, 0, 0, 0.12); cairo_rectangle(c, x + 16, r.y, w - 16, 0.5); cairo_fill(c); }
            int destructive = nx.act[k].opts & 2;
            sys_text(c, nx.act[k].title, x + 16, r.y + 14, w - 32, 17, PANGO_WEIGHT_NORMAL, 0, 1, destructive ? 1 : 0, destructive ? 0.23 : 0, destructive ? 0.19 : 0, 1);
            char id[200]; snprintf(id, sizeof id, "nx-action-%s", nx.act[k].id);
            el_add(id, nx.act[k].title, r, EL_NX_ACTION, k);
        }
        ay += plat.h + 10;
    } else if (nx.loading) sys_text(c, "…", x, ay, w, 15, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 0.8);
    /* the reply field of a text input action */
    if (nx.reply) {
        struct nx_action *a = &nx.act[nx.reply - 1];
        struct rectf f = { x, ay, w - 86, 44 }, send = { x + w - 78, ay, 78, 44 };
        sys_round(c, f.x, f.y, f.w, f.h, 22); cairo_set_source_rgb(c, 1, 1, 1); cairo_fill(c);
        if (nx.text[0]) sys_text(c, nx.text, f.x + 16, f.y + 12, f.w - 24, 16, PANGO_WEIGHT_NORMAL, 0, 1, 0, 0, 0, 1);
        else sys_text(c, a->placeholder, f.x + 16, f.y + 12, f.w - 24, 16, PANGO_WEIGHT_NORMAL, 0, 1, 0.55, 0.55, 0.58, 1);
        sys_round(c, send.x, send.y, send.w, send.h, 22); cairo_set_source_rgb(c, 0, 0.48, 1); cairo_fill(c);
        sys_text(c, a->button, send.x, send.y + 12, send.w, 16, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
        el_add("nx-reply-field", nx.text[0] ? nx.text : a->placeholder, f, EL_NONE, 0);
        el_add("nx-reply-send", a->button, send, EL_NX_SEND, 0);
    }
}
/* an action chosen under the expanded notification: an extension that handles responses answers first (keep the
   notification open, dismiss it, or forward the action to the app), else the action goes to the app */
static void nx_choose(const char *action, const char *text, int foreground) {
    if (nx.session[0] && nx.responds) {
        snprintf(nx.wait_action, sizeof nx.wait_action, "%s", action); snprintf(nx.wait_text, sizeof nx.wait_text, "%s", text ? text : "");
        nx.wait_fg = foreground; nx.waiting = 1; nx.reply = 0;
        fprintf(stderr, "isim shell: action %s goes to the content extension first\n", action);
        nx_send("sysevent nx-action %s\x1f%s", action, text ? text : "");
        sys_draw();
        return;
    }
    nx_respond(action, text, foreground);
}
static void nx_answer(const char *a) {
    fprintf(stderr, "isim shell: content extension answered %s\n", a);
    nx.waiting = 0;
    if (!strcmp(a, "keep")) { sys_draw(); return; }
    if (!strcmp(a, "dismiss")) { nx_close(); return; }
    if (strncmp(a, "forward ", 8)) return;
    char action[128], text[512]; int fg, has_text = 0;
    snprintf(action, sizeof action, "%s", a + 8);
    if (!strcmp(action, nx.wait_action)) { fg = nx.wait_fg; snprintf(text, sizeof text, "%s", nx.wait_text); has_text = text[0] != 0; }
    else fg = !strcmp(action, "com.apple.UNNotificationDefaultActionIdentifier");
    nx.wait_action[0] = 0;
    nx_respond(action, has_text ? text : NULL, fg);
}
/* the session's state file: a new frame, the play / pause button, the actions (notificationActions), an answer */
static void nx_poll(void) {
    if (!nx.on || !nx.session[0]) return;
    char p[600]; snprintf(p, sizeof p, "%s/state", nx.session);
    struct stat st;
    if (stat(p, &st) != 0 || (st.st_mtim.tv_sec == nx.state_mtime.tv_sec && st.st_mtim.tv_nsec == nx.state_mtime.tv_nsec)) return;
    nx.state_mtime = st.st_mtim;
    FILE *f = fopen(p, "r");
    if (!f) return;
    int seq = nx.seq, aseq = 0, nact = 0, actions = 0, media = 0, playing = 0; double h = nx.img_h, mr[4] = { 0 };
    char frame[600] = "", answer[300] = "", line[2048];
    struct nx_action act[8]; memset(act, 0, sizeof act);
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        if (!strncmp(line, "seq=", 4)) seq = atoi(line + 4);
        else if (!strncmp(line, "frame=", 6)) snprintf(frame, sizeof frame, "%s", line + 6);
        else if (!strncmp(line, "height=", 7)) h = atof(line + 7);
        else if (!strncmp(line, "media=", 6)) sscanf(line + 6, "%d %lf %lf %lf %lf %d", &media, &mr[0], &mr[1], &mr[2], &mr[3], &playing);
        else if (!strncmp(line, "actions=", 8)) actions = 1;
        else if (!strncmp(line, "answer=", 7)) sscanf(line + 7, "%d %299[^\n]", &aseq, answer);
        else if (!strncmp(line, "action=", 7) && nact < 8) {
            struct nx_action *ac = &act[nact++];
            char *q = line + 7, *parts[6] = { 0 }; int n = 0;
            parts[n++] = q;
            for (char *r = q; *r && n < 6; r++) if (*r == '\x1e') { *r = 0; parts[n++] = r + 1; }
            snprintf(ac->id, sizeof ac->id, "%s", parts[0] ? parts[0] : ""); snprintf(ac->title, sizeof ac->title, "%s", parts[1] ? parts[1] : "");
            ac->opts = parts[2] ? atoi(parts[2]) : 0; ac->text = parts[3] ? atoi(parts[3]) : 0;
            snprintf(ac->button, sizeof ac->button, "%s", parts[4] && *parts[4] ? parts[4] : "Send"); snprintf(ac->placeholder, sizeof ac->placeholder, "%s", parts[5] ? parts[5] : "");
        }
    }
    fclose(f);
    nx.media = media; nx.playing = playing; memcpy(nx.media_r, mr, sizeof mr);
    if (actions) { memcpy(nx.act, act, sizeof act); nx.nact = nact; }
    if (seq != nx.seq && frame[0] && strcmp(frame, nx.frame)) {
        cairo_surface_t *img = cairo_image_surface_create_from_png(frame);
        if (cairo_surface_status(img) == CAIRO_STATUS_SUCCESS) {
            nx_free_image(); nx.img = img; nx.img_h = h; nx.seq = seq; snprintf(nx.frame, sizeof nx.frame, "%s", frame);
            fprintf(stderr, "isim shell: content extension frame %d\n", seq);
        } else cairo_surface_destroy(img);
    }
    if (ov == OV_NX) sys_draw();
    if (aseq > nx.answer_seq) { nx.answer_seq = aseq; nx_answer(answer); }
}
/* text typed into the reply field */
static int nx_text_input(const struct isim_event *ev) {
    if (ov != OV_NX || !nx.reply) return 0;
    if (ev->type == EV_TEXT) { strncat(nx.text, ev->text, sizeof nx.text - strlen(nx.text) - 1); sys_draw(); return 1; }
    if (ev->type == EV_KEY && ev->key == 8) { size_t l = strlen(nx.text); while (l > 0 && (nx.text[l - 1] & 0xC0) == 0x80) l--; if (l) nx.text[l - 1] = 0; sys_draw(); return 1; }
    if (ev->type == EV_KEY && ev->key == 13) {
        struct nx_action *a = &nx.act[nx.reply - 1]; char t[512]; snprintf(t, sizeof t, "%s", nx.text);
        nx_choose(a->id, t, (a->opts & 4) != 0); return 1;
    }
    return 0;
}

/* an image attachment's thumbnail (any format the host image code reads) */
static void nb_thumb(cairo_t *c, const char *path, double x, double y, double s) {
    double w = 0, h = 0; int hd = isim_image_load(path, &w, &h);
    if (!hd || w <= 0 || h <= 0) { if (hd) isim_image_free(hd); return; }
    cairo_save(c);
    sys_round(c, x, y, s, s, 6); cairo_clip(c);
    double k = fmax(s / w, s / h);                                  /* aspect fill */
    cairo_t *saved = cr; cr = c;
    isim_image_draw(hd, x + (s - w * k) / 2, y + (s - h * k) / 2, w * k, h * k, NULL, 1);
    cr = saved;
    cairo_restore(c);
    isim_image_free(hd);
}

#include "shell_appclip.inc"

/* What the overlays leave of the device: the status bar (system UI drawn over them; alpha: Control Center's fade-in),
   the Dynamic Island or notch, the home indicator (lock screen, Notification Center) and the display's rounded
   corners. Over apps host.c draws these in isim_frame_end. */
static void sys_chrome(cairo_t *c, double alpha) {
    static const double white[4] = { 1, 1, 1, 1 };
    int lockish = ov == OV_LOCK || ov == OV_NC || (ov == OV_NX && locked);
    if (!pctx) text_context(c);
    cairo_t *saved = cr; cr = c;
    cairo_save(c); cairo_identity_matrix(c); cairo_reset_clip(c); cairo_scale(c, px_scale, px_scale);
    cairo_push_group(c);
    draw_status_bar(ov == OV_CC ? SB_CC : lockish ? SB_LOCK : SB_APP, white);
    cairo_pop_group_to_source(c); cairo_paint_with_alpha(c, alpha);
    draw_hardware(lockish, white);
    apply_corner_mask();
    cairo_restore(c);
    cr = saved;
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
        pill_draw(c);
        pip_draw(c);
    } else if (ov == OV_NX) {                                         /* an expanded notification over the blurred screen */
        cairo_surface_t *under = locked ? home : bs; int uw = locked ? hw : bw, uh = locked ? hh : bh;
        sys_paint_blurred(c, under, uw, uh, 0.3);
        cairo_scale(c, px_scale, px_scale);
        nx_draw(c);
    } else if (ov == OV_CLIP) {                                       /* the App Clip card over the dimmed screen */
        cairo_save(c); cairo_identity_matrix(c);
        cairo_scale(c, (double)surf_w / bw, (double)surf_h / bh);
        cairo_set_source_surface(c, bs, 0, 0); cairo_paint(c);
        cairo_restore(c);
        cairo_set_source_rgba(c, 0, 0, 0, 0.32 * fmin(1, (now() - ov_t0) / 0.25)); cairo_paint(c);
        cairo_scale(c, px_scale, px_scale);
        ac_draw(c);
    } else if (ov == OV_LOCK) {
        cairo_scale(c, px_scale, px_scale);
        if (standby) standby_draw(c); else lock_draw(c, home, hw, hh);
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
    if (ov != OV_NONE && !(standby && ov == OV_LOCK)) sys_chrome(c, ov == OV_CC ? e : 1);   /* StandBy: no status bar */
    if (calls_visible()) { cairo_save(c); cairo_identity_matrix(c); cairo_scale(c, px_scale, px_scale); calls_draw(c); cairo_restore(c); }
    if (calls_fullscreen() && ov == OV_NONE) sys_chrome(c, 1);                    /* the status bar over the call screens */
    if (siri_visible()) { cairo_save(c); cairo_identity_matrix(c); cairo_scale(c, px_scale, px_scale); siri_draw(c); cairo_restore(c); }
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
    } else if (which == OV_NC) { nncx = 0; fprintf(stderr, "isim shell: Notification Center (%d notification%s)\n", nnc, nnc == 1 ? "" : "s"); }
    else if (which == OV_CC) { cc_page = CC_PAGE_MAIN; fprintf(stderr, "isim shell: Control Center (iOS %d look)\n", sys_os()); }
    sys_draw();
}
static void sys_close(void) {
    if (ov == OV_NX) { nx_close(); return; }
    if (ov == OV_CLIP) { ac_close(0); return; }
    int was = ov; ov = OV_NONE;
    if (was == OV_SWITCHER) {                      /* back to the home screen */
        int app = active; active = 0;
        if (app > 0 && clients[app].alive) shell_send(app, EV_BACKGROUND);
        shell_send(0, EV_FOREGROUND);
    }
    shell_show(active >= 0 ? active : 0);
}
/* protected data (UIApplication.isProtectedDataAvailable): unavailable while the device is locked */
static void sys_protected_data(int available) {
    for (int i = 1; i < nclients; i++) if (clients[i].alive) sys_send_text(i, "protected-data %d", available);
}
static void sys_lock(void) {
    if (locked) return;
    locked = 1; ov = OV_LOCK; ov_t0 = now(); nb.on = 0;
    if (active >= 0) shell_send(active, EV_BACKGROUND);       /* like iOS: the foreground app resigns and goes to the background */
    sys_protected_data(0);
    fprintf(stderr, "isim shell: locked (iOS %d look)\n", sys_os());
    if (win_orient != 1) shell_apply_orient(1);
    sys_draw();
}
static void sys_unlock(void) {
    if (!locked) return;
    if (lock_editing) { lock_editing = 0; active = lock_edit_active; sys_send_text(0, "lock-customize-cancel"); }
    if (standby) { standby = 0; sb_clear(); shell_apply_orient(1); fprintf(stderr, "isim shell: StandBy off\n"); sys_send_text(0, "standby off"); }
    locked = 0; ov = OV_NONE;
    fprintf(stderr, "isim shell: unlocked\n");
    sys_protected_data(1);
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
    clients[i].sysquit = 1; clients[i].forcequit = 1;
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
    fprintf(stderr, "isim shell: opened notification %s from %s\n", n.id, locked ? "the lock screen" : ov == OV_NX ? "an expanded notification" : "Notification Center");
    if (locked) { locked = 0; fprintf(stderr, "isim shell: unlocked\n"); sys_protected_data(1); }
    if (nx.on) nx_end_session();
    ov = OV_NONE; nx.on = 0;
    if (i < 0 && n.exe[0]) {                                   /* not running: launch it with the response (or the remote notification) */
        char url[1300];
        if (n.file[0]) snprintf(url, sizeof url, "isim-push-open:%s", n.file);
        else snprintf(url, sizeof url, "isim-nc-action:%s\x1f%s\x1f" "com.apple.UNNotificationDefaultActionIdentifier\x1f", n.record, n.id);
        shell_launch(n.path, n.exe, url);
        return;
    }
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
    if (k == CC_FOCUS) { focus_load(); focus_set(focus_mode ? FOCUS_OFF : focus_last); return; }
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
static double el_tap_x;                                      /* the x of the tap el_tap handles */
static void el_tap(struct sys_el *e, double y) {
    if (!e) return;
    switch (e->kind) {
    case EL_CARD: {
        double rad; int k = 0; for (; k < sw_n && sw_order[k] != e->arg; k++) {}
        struct rectf r = sw_card_rect(k, &rad);
        sw_activate(e->arg, r, rad); break; }
    case EL_NC_ITEM: nc_open(e->arg); break;
    case EL_NC_GROUP: case EL_NC_LESS: {                           /* expand / collapse a stack */
        char key[700]; nc_group_key(&ncl[e->arg], key, sizeof key);
        if (e->kind == EL_NC_GROUP && nncx < 16 && !nc_group_open(key)) { snprintf(ncx_open[nncx++], sizeof ncx_open[0], "%s", key); fprintf(stderr, "isim shell: expanded the stack of %s\n", ncl[e->arg].path); }
        else if (e->kind == EL_NC_LESS) {
            for (int k = 0; k < nncx; k++) if (!strcmp(ncx_open[k], key)) { memmove(ncx_open[k], ncx_open[k + 1], sizeof ncx_open[0] * (size_t)(nncx - k - 1)); nncx--; break; }
            fprintf(stderr, "isim shell: collapsed the stack of %s\n", ncl[e->arg].path);
        }
        sys_draw(); break; }
    case EL_NX_CONTENT: { int k = nc_find(nx.it.path, nx.it.id); if (k >= 0) nc_open(k); else nx_close(); break; }
    case EL_NX_ACTION: {
        struct nx_action *a = &nx.act[e->arg];
        if (a->text) { nx.reply = e->arg + 1; nx.text[0] = 0; fprintf(stderr, "isim shell: reply field for %s\n", a->id); sys_draw(); }
        else nx_choose(a->id, NULL, (a->opts & 4) != 0);
        break; }
    case EL_NX_SEND: if (nx.reply) { struct nx_action *a = &nx.act[nx.reply - 1]; char t[512]; snprintf(t, sizeof t, "%s", nx.text); nx_choose(a->id, t, (a->opts & 4) != 0); } break;
    case EL_NX_EXT: {                                            /* a tap on the extension's view: to the extension, in its points */
        double k = nx.ext_w > 0 ? nx.ext_w / e->r.w : 1;
        double px = (el_tap_x - e->r.x) * k, py = (y - e->r.y) * k;
        fprintf(stderr, "isim shell: tap %.0f,%.0f in the content extension\n", px, py);
        nx_send("tap %.1f %.1f", px, py);
        break; }
    case EL_NX_MEDIA:
        nx.playing = !nx.playing;
        fprintf(stderr, "isim shell: content extension media %s\n", nx.playing ? "play" : "pause");
        nx_send("sysevent nx-media %s", nx.playing ? "play" : "pause");
        sys_draw(); break;
    case EL_NC_CLEAR: fprintf(stderr, "isim shell: cleared %d notification(s)\n", nnc); nnc = 0; sys_draw(); break;
    case EL_CC_TOGGLE: cc_toggle(e->arg); break;
    case EL_NP:
        if (np_on()) { fprintf(stderr, "isim shell: Now Playing %s -> %s\n", np_cmds[e->arg], app_label(np.client)); sys_send_text(np.client, "remote %s", np_cmds[e->arg]); }
        break;
    case EL_CC_X: ctl_tap(e); break;
    case EL_LA: la_open(e->arg); break;                          /* a Live Activity: its app (with its widgetURL) */
    case EL_LW: lw_open(e->arg); break;                          /* a Lock Screen widget: its app */
    case EL_CC_SLIDER: {
        double v = fmin(1, fmax(0, 1 - (y - e->r.y) / e->r.h));
        if (e->arg == 0) cc_brightness = fmax(0.05, v); else sys_volume_changed(v, -1);
        fprintf(stderr, "isim shell: Control Center %s %d%%\n", e->arg ? "volume" : "brightness", (int)lround(v * 100));
        sys_draw(); break; }
    case EL_BG:
        if (ov == OV_CLIP) { ac_close(0); break; }
        if (ov == OV_NX) { if (nx.dismiss) nx_respond("com.apple.UNNotificationDismissActionIdentifier", NULL, 0); else nx_close(); break; }
        if (ov == OV_LOCK) break;
        sys_close(); break;
    default: ac_tap(e); break;
    }
}
static void sys_dump(void) {
    static const char *const names[] = { "", "IsimAppSwitcher", "IsimLockScreen", "IsimNotificationCenter", "IsimControlCenter", "IsimExpandedNotification", "IsimAppClipCard" };
    fprintf(stderr, "%s (0 0; %g x %g)\n", names[ov], dev.width, dev.height);
    for (int k = 0; k < nels; k++)
        fprintf(stderr, "  %s (%g %g; %g x %g) id=%s%s%s\n", els[k].kind == EL_CARD ? "IsimAppCard" : els[k].kind == EL_NC_ITEM ? "IsimNotification" : els[k].kind == EL_NC_GROUP ? "IsimNotificationStack" :
                els[k].kind == EL_NX_ACTION ? "IsimNotificationAction" : els[k].kind == EL_NX_CONTENT ? "IsimNotificationContent" :
                els[k].kind == EL_NX_EXT ? "IsimNotificationExtensionView" : els[k].kind == EL_NX_MEDIA ? "IsimNotificationMediaButton" :
                els[k].kind == EL_CC_TOGGLE || (els[k].kind == EL_CC_X && els[k].arg / 1000 == X_MODULE) || els[k].kind == EL_NP ? "IsimControlButton" : els[k].kind == EL_CC_SLIDER ? "IsimControlSlider" : els[k].kind == EL_CALL ? "IsimCallButton" : els[k].kind == EL_LA ? "IsimLiveActivity" : els[k].kind == EL_LW ? "IsimLockScreenWidget" : els[k].kind >= EL_AC_OPEN ? "IsimAppClipButton" : "IsimSystemView",
                els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text[0] ? " text=" : "", els[k].text);
}

/* input while an overlay is up, and the gestures / keys that open them. Returns 1 when the event was the system's. */
static struct { int on, sys; double x0, y0, t0; } top_drag;     /* a touch that started at the top edge */
static double last_home_key;
static int sys_input(const struct isim_event *ev) {
    if (siri_input(ev)) return 1;
    if (calls_input(ev)) return 1;
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
    if (nx_text_input(ev)) return 1;
    if (ov == OV_NONE && pip_input(ev)) return 1;
    if (ov == OV_NONE && pill_visible()) {                       /* the location indicator: tap opens the app using location */
        struct rectf r = pill_rect(NULL); int app = pill_client();
        if ((ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) && !strcmp(ev->text, "location-indicator")) {
            if (ev->type == EV_ID_UP && app > 0) { fprintf(stderr, "isim shell: location indicator opens %s\n", short_name(app)); shell_launch(clients[app].bundle, clients[app].exe, NULL); }
            return 1;
        }
        if (ev->type == EV_DUMP) fprintf(stderr, "IsimLocationIndicator (%g %g; %g x %g) id=location-indicator text=%s\n", r.x, r.y, r.w, r.h, app > 0 ? app_label(app) : "");
        int inside = ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h;
        if (ev->type == EV_TOUCH_DOWN && inside) return 1;
        if (ev->type == EV_TOUCH_UP && inside && app > 0) { shell_launch(clients[app].bundle, clients[app].exe, NULL); return 1; }
    }
    if (ov == OV_NONE && la_island_visible()) {                 /* the Dynamic Island: tap expands / collapses; a banner opens the app */
        int e = la_expanded(), idx[LA_MAX], n = la_island_list(idx);
        struct rectf r = la_banner_visible() ? la_banner_rect() : e >= 0 ? la_expanded_rect() : n >= 2 ? la_attached_rect() : la_compact_rect();
        struct rectf d = la_detached_rect();
        if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
            if (!strcmp(ev->text, "live-activity-banner")) { if (ev->type == EV_ID_UP) la_open(la_find(la.alert_id)); return 1; }
            if (!strcmp(ev->text, "dynamic-island") || (!strcmp(ev->text, "dynamic-island-detached") && n >= 2 && e < 0)) {
                if (ev->type == EV_ID_UP) { la_toggle(!strcmp(ev->text, "dynamic-island-detached")); shell_show(active); }
                return 1;
            }
        }
        if (ev->type == EV_DUMP) { la_dump_island(); return 0; }
        int inside = ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h;
        int in_d = n >= 2 && e < 0 && !la_banner_visible() && ev->x >= d.x && ev->x <= d.x + d.w && ev->y >= d.y && ev->y <= d.y + d.h;
        if (la_banner_visible()) {
            if (ev->type == EV_TOUCH_DOWN && inside) return 1;
            if (ev->type == EV_TOUCH_UP && inside) { la_open(la_find(la.alert_id)); return 1; }
        } else {
            if (ev->type == EV_TOUCH_DOWN && (inside || in_d || e >= 0)) { top_drag.on = 0; return 1; }
            if (ev->type == EV_TOUCH_UP && (inside || in_d || e >= 0)) {
                if (e >= 0 && !inside) { la.exp_id[0] = 0; fprintf(stderr, "isim shell: Dynamic Island %s\n", n >= 2 ? "minimal" : "compact"); }
                else la_toggle(in_d);
                shell_show(active); return 1;
            }
            if (ev->type == EV_TOUCH_MOVE && e >= 0) return 1;
        }
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
        static double id_down_t; static char id_down[128];
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no system element '%s'\n", ev->text); return 1; }
        if (ev->type == EV_ID_DOWN && ev->mods != 1) { id_down_t = now(); snprintf(id_down, sizeof id_down, "%s", ev->text); }
        if (ev->type == EV_ID_UP && (e->kind == EL_NC_ITEM || e->kind == EL_NC_GROUP) && !strcmp(id_down, ev->text) && now() - id_down_t >= 0.5) {   /* holdid: expand */
            id_down[0] = 0; nx_open_item(e->arg); return 1;
        }
        if (ev->type == EV_ID_UP && ov == OV_LOCK && !standby && !strcmp(ev->text, "lock-clock") && !strcmp(id_down, ev->text) && now() - id_down_t >= 0.5) {
            id_down[0] = 0; lock_customize(); return 1;                    /* holdid lock-clock: customize */
        }
        if (ev->type == EV_ID_DOWN && ev->mods == 1) {                 /* swipeid ID dx dy s */
            if (e->kind == EL_CARD && ev->y < -50) sw_kill(e->arg);
            else if (e->kind == EL_CARD && fabs(ev->x) > 20) { sw_scroll = fmax(0, sw_scroll + ev->x); sys_draw(); }
            else if (e->kind == EL_BG && ev->y < -50) { if (ov == OV_LOCK) sys_unlock(); else sys_close(); }
            return 1;
        }
        if (ev->type == EV_ID_UP) { el_tap_x = e->r.x + e->r.w / 2; el_tap(e, e->r.y + e->r.h / 2); }
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
            if (e && e->kind == EL_CC_SLIDER) { el_tap_x = ev->x; el_tap(e, ev->y); }
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
        struct sys_el *te = moved ? NULL : el_at(ev->x, ev->y);
        if (te && (te->kind == EL_NC_ITEM || te->kind == EL_NC_GROUP) && now() - sw_drag.t0 >= 0.5) { nx_open_item(te->arg); return 1; }   /* long press: expand */
        if (ov == OV_LOCK && !standby && !moved && now() - sw_drag.t0 >= 0.6 && (!te || te->kind == EL_NONE)) { lock_customize(); return 1; }   /* long press: customize */
        if (!moved) { el_tap_x = ev->x; el_tap(te, ev->y); }
        else if (ov == OV_SWITCHER) sys_draw();
        return 1;
    }
    return ov != OV_NONE;
}
/* per loop iteration: slide-in animation, lock clock, switcher bookkeeping */
/* auto-lock (ISIM_AUTOLOCK=SECONDS, default off): no input for that long locks the device, unless the foreground app
   disabled its idle timer (UIApplication.isIdleTimerDisabled) */
static double last_input_t;
static void sys_input_seen(void) { last_input_t = now(); }
static void sys_autolock_tick(void) {
    static double secs = -1;
    if (secs < 0) { const char *e = getenv("ISIM_AUTOLOCK"); secs = e && *e ? atof(e) : 0; }
    if (secs <= 0 || locked) { last_input_t = now(); return; }
    if (!last_input_t) last_input_t = now();
    if (active > 0 && clients[active].alive && clients[active].idle_disabled) { last_input_t = now(); return; }
    if (now() - last_input_t < secs) return;
    fprintf(stderr, "isim shell: auto-lock after %g s without input\n", secs);
    sys_lock();
}
static void sys_tick(void) {
    if (active != seen_active) { seen_active = active; if (active > 0) last_active_t[active] = now(); }
    sys_autolock_tick();
    bg_tick();
    if (pip_visible()) {                                   /* the floating video: ~30 frames a second */
        static double last_pip;
        if (now() - last_pip > 1.0 / 30) { last_pip = now(); shell_show(active >= 0 ? active : 0); }
    }
    la_tick();
    siri_tick();
    calls_tick();
    nx_poll();
    if (ov == OV_NONE) return;
    static double last_draw;
    double t = now();
    if (t - ov_t0 < 0.32 || t - last_draw > 1.0) { last_draw = t; if (anim.kind == ANIM_NONE && ov != OV_NX) sys_draw(); }
}

static void sys_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (ctl_handle_msg(from, m)) return;                         /* Focus and controls (shell_controls.inc) */
    if (calls_handle_msg(from, m)) return;                       /* CallKit calls (shell_calls.inc) */
    if (!strcmp(verb, "appinfo")) {
        struct sys_appinfo *ai = sys_info(m->b);
        if (!ai) { if (nappinfo >= 128) return; ai = &appinfo[nappinfo++]; snprintf(ai->path, sizeof ai->path, "%s", m->b); }
        const char *sep = strchr(m->c, '\x1f');
        snprintf(ai->name, sizeof ai->name, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        snprintf(ai->icon, sizeof ai->icon, "%s", sep ? sep + 1 : "");
    } else if (!strcmp(verb, "notified")) {                 /* delivered while the app was in the foreground: b = id\x1ficon\x1frecord\x1fthumb */
        char id[256], icon[512], title[256], body[512];
        field(m->b, 0, id, sizeof id); field(m->b, 1, icon, sizeof icon); field(m->c, 0, title, sizeof title); field(m->c, 1, body, sizeof body);
        struct nc_item *n = nc_add(clients[from].bundle, id, icon, title, body);
        field(m->b, 2, n->record, sizeof n->record); field(m->b, 3, n->thumb, sizeof n->thumb);
        nc_load_sidecar(n);
        if (ov != OV_NONE) sys_draw();
    } else if (!strcmp(verb, "notif-sound")) {             /* a notification the foreground app presented with .sound */
        sys_play_sound(m->b, clients[from].bundle);
    } else if (!strcmp(verb, "local-due")) {               /* the home screen's scheduler: a local notification of an app */
        char exe[512], side[512]; field(m->c, 0, exe, sizeof exe); field(m->c, 1, side, sizeof side);
        sys_local_deliver(m->b, exe, side);
    } else if (!strcmp(verb, "bg-assert")) {               /* what keeps the app running in the background */
        struct shell_client *c = &clients[from];
        if (strcmp(c->reasons, m->b)) fprintf(stderr, "isim shell: %s in the background: %s\n", short_name(from), m->b[0] ? m->b : "can be suspended");
        snprintf(c->reasons, sizeof c->reasons, "%s", m->b); c->bg_seen = 1;
        if (pill_visible() || from == active) shell_show(active >= 0 ? active : 0);
    } else if (!strcmp(verb, "nowplaying")) {             /* b = title\x1fartist\x1falbum\x1fartwork PNG, c = "duration elapsed rate" */
        if (!m->b[0]) {
            if (np.client == from) { np.client = -1; np.title[0] = 0; fprintf(stderr, "isim shell: Now Playing cleared\n"); }
        } else {
            np.client = from;
            field(m->b, 0, np.title, sizeof np.title); field(m->b, 1, np.artist, sizeof np.artist);
            field(m->b, 2, np.album, sizeof np.album); field(m->b, 3, np.artwork, sizeof np.artwork);
            np.duration = np.elapsed = np.rate = 0;
            sscanf(m->c, "%lf %lf %lf", &np.duration, &np.elapsed, &np.rate);
            np.at = now();
            fprintf(stderr, "isim shell: Now Playing %s — %s (%s) %.1f/%.1f s rate %g\n", np.title, np.artist, app_label(from), np.elapsed, np.duration, np.rate);
        }
        if (ov != OV_NONE) sys_draw();
    } else if (!strcmp(verb, "pip-start")) {               /* b = URL\x1fTITLE, c = "TIME RATE W H FPS" */
        pip_stop();
        field(m->b, 0, pip.url, sizeof pip.url); field(m->b, 1, pip.title, sizeof pip.title);
        pip.vw = pip.vh = 0; pip.fps = 30; pip.t0 = 0; pip.rate = 0;
        sscanf(m->c, "%lf %lf %lf %lf %lf", &pip.t0, &pip.rate, &pip.vw, &pip.vh, &pip.fps);
        pip.at = now(); pip.client = from; pip.on = 1; pip.controls = 0;
        pip_open_media();
        fprintf(stderr, "isim shell: Picture in Picture from %s (%.0fx%.0f) at %.1f s\n", app_label(from), pip.vw, pip.vh, pip.t0);
        shell_show(active >= 0 ? active : 0);
    } else if (!strcmp(verb, "pip-update")) {              /* c = "TIME RATE": seek / play / pause */
        if (pip.on && pip.client == from) {
            double t = pip.t0, r = pip.rate;
            sscanf(m->c, "%lf %lf", &t, &r);
            int reopen = fabs(t - pip_time()) > 0.4 || (r > 0 && fabs(r - pip.rate) > 1e-3 && pip.rate > 0);
            pip.t0 = t; pip.at = now(); pip.rate = r;
            if (reopen) pip_open_media();
        }
    } else if (!strcmp(verb, "pip-stop")) {
        if (pip.client == from && pip.on) { pip_stop(); fprintf(stderr, "isim shell: Picture in Picture ended\n"); shell_show(active >= 0 ? active : 0); }
    } else if (!strcmp(verb, "volume")) {                  /* an app's MPVolumeView changed the device volume */
        sys_volume_changed(atof(m->b), from);
        fprintf(stderr, "isim shell: volume %d%% (%s)\n", (int)lround(cc_volume * 100), app_label(from));
        if (ov != OV_NONE) sys_draw();
    } else if (!strcmp(verb, "bg-wake")) {                 /* the app's next local notification (seconds since 1970) */
        clients[from].wake_at = atof(m->b);
    } else if (!strcmp(verb, "idle-timer")) {              /* UIApplication.isIdleTimerDisabled */
        clients[from].idle_disabled = atoi(m->b);
        fprintf(stderr, "isim shell: %s idle timer %s\n", short_name(from), clients[from].idle_disabled ? "disabled" : "enabled");
    } else if (!strcmp(verb, "badge")) {                   /* an app's icon badge: the home screen draws it */
        sys_send_text(0, "badge %s %s", m->b, m->c);
    } else if (!strcmp(verb, "push-deliver")) {
        char exe[512], side[512]; field(m->c, 0, exe, sizeof exe); field(m->c, 1, side, sizeof side);
        sys_push_deliver(m->b, exe, side);
    } else if (!strcmp(verb, "ext-run")) {                 /* the home screen runs a notification extension */
        sys_run_helper_kind(m->b, m->c, 1);
    } else if (!strcmp(verb, "appclip-card")) {             /* the home screen resolved an App Clip invocation */
        ac_show(m->b);
    } else if (!strcmp(verb, "nc-expanded")) {
        nx_loaded(m->b, m->c);
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
    } else if (!strcmp(verb, "la-set")) {                    /* a Live Activity rendered (SBLiveActivities.m) */
        la_set(m->b, m->c);
        if (ov != OV_NONE) sys_draw(); else shell_show(active >= 0 ? active : 0);
    } else if (!strcmp(verb, "la-end")) {
        la_end(m->b, m->c);
        if (ov != OV_NONE) sys_draw(); else shell_show(active >= 0 ? active : 0);
    } else if (!strcmp(verb, "lw-set")) {                    /* Lock Screen widgets (SBLockScreen.m) */
        lw_set(m->c);
    } else if (!strcmp(verb, "sb-set")) {                    /* StandBy's widgets */
        sb_set(m->c);
    } else if (!strcmp(verb, "lock-edit-done")) {
        lock_customize_done();
    } else if (!strcmp(verb, "openurl")) {
        sys_send_text(0, "openurl %s", m->c);
    } else if (!strcmp(verb, "reload-home")) {
        sys_send_text(0, "reload");
    } else if (!strcmp(verb, "terminate")) {               /* script `terminate BUNDLE-ID` (resolved by the home screen) */
        int k = shell_find(m->b);
        if (k > 0) {                                          /* like iOS reclaiming memory: killed without notice */
            fprintf(stderr, "isim shell: terminated %s (system)\n", clients[k].bundle);
            clients[k].sysquit = 1;
            kill(clients[k].pid, SIGKILL);
            if (k == active) { active = -1; shell_activate(0); }
        } else fprintf(stderr, "isim shell: terminate: %s is not running\n", m->b);
    } else if (!strcmp(verb, "siri-ui")) {                  /* the home screen's Siri (shell_siri.inc) */
        siri_load(m->b);
    } else if (!strcmp(verb, "intent-run") || !strcmp(verb, "intents-refresh")) {   /* the Shortcuts app runs an intent: the home screen does it */
        sys_send_text(0, "%s %s", verb, m->b);
    } else if (!strcmp(verb, "launch-bg")) {
        const char *sep = strchr(m->c, '\x1f');
        char exe[512]; snprintf(exe, sizeof exe, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        sys_launch_background(m->b, exe, sep ? sep + 1 : NULL);
    } else fprintf(stderr, "isim shell: unknown system request '%s' from %s\n", verb, clients[from].bundle);
}

/* a remote notification the home screen routed: the sidecar file has lines file=, flags=, id=, title=, body=, icon=,
   record=, thumb=. A running app gets the payload ("push FILE"); otherwise flags c (content-available and the
   remote-notification background mode) launches it in the background with it, and flags a (an alert it may show)
   makes the system show it: Notification Center and a banner, tapping opens the app with the notification. */
static void sys_push_deliver(const char *path, const char *exe, const char *sidecar) {
    char file[512] = "", flags[32] = "", id[256] = "", title[256] = "", body[512] = "", icon[512] = "", record[512] = "", thumb[512] = "", line[1200];
    FILE *f = fopen(sidecar, "r");
    if (!f) { fprintf(stderr, "isim shell: push: cannot read %s\n", sidecar); return; }
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        for (char *q = v; *q; q++) if (*q == '\x1e') *q = '\n';         /* multi-line text */
        if (!strcmp(line, "file")) snprintf(file, sizeof file, "%s", v); else if (!strcmp(line, "flags")) snprintf(flags, sizeof flags, "%s", v);
        else if (!strcmp(line, "id")) snprintf(id, sizeof id, "%s", v); else if (!strcmp(line, "title")) snprintf(title, sizeof title, "%s", v);
        else if (!strcmp(line, "body")) snprintf(body, sizeof body, "%s", v); else if (!strcmp(line, "icon")) snprintf(icon, sizeof icon, "%s", v);
        else if (!strcmp(line, "record")) snprintf(record, sizeof record, "%s", v); else if (!strcmp(line, "thumb")) snprintf(thumb, sizeof thumb, "%s", v);
    }
    fclose(f);
    int i = shell_find(path);
    if (i >= 0) { fprintf(stderr, "isim shell: push %s to the running %s\n", id, short_name(i)); sys_send_text(i, "remote-notification %s", file); return; }
    if (strchr(flags, 'c')) {
        char url[600]; snprintf(url, sizeof url, "isim-push:%s", file);
        sys_launch_background(path, exe, url);
        return;
    }
    if (!strchr(flags, 'a')) { fprintf(stderr, "isim shell: push %s for %s not shown (the app is not running and the notification has no alert it may show)\n", id, path); return; }
    struct nc_item *n = nc_add(path, id, icon, title, body);
    snprintf(n->record, sizeof n->record, "%s", record); snprintf(n->thumb, sizeof n->thumb, "%s", thumb);
    snprintf(n->exe, sizeof n->exe, "%s", exe); snprintf(n->file, sizeof n->file, "%s", file);
    nc_load_sidecar(n);
    sys_alert(-1, n, flags);
}

/* a local notification the home screen's scheduler found due (the sidecar: flags=, id=, title=, body=, icon=, record=,
   thumb=, fire=, bundle=). A running app delivers its own (a suspended one is woken for it: bg-wake); for an app that
   is not running the system shows it, like a remote one (tapping it launches the app with the response), and tells the
   home screen ("local-shown"), which updates the app's pending requests. */
static void sys_local_deliver(const char *path, const char *exe, const char *sidecar) {
    char flags[32] = "", id[256] = "", title[256] = "", body[512] = "", icon[512] = "", record[512] = "", thumb[512] = "", fire[64] = "", bundle[256] = "", line[1200];
    FILE *f = fopen(sidecar, "r");
    if (!f) { fprintf(stderr, "isim shell: local notification: cannot read %s\n", sidecar); return; }
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        for (char *q = v; *q; q++) if (*q == '\x1e') *q = '\n';
        if (!strcmp(line, "flags")) snprintf(flags, sizeof flags, "%s", v); else if (!strcmp(line, "id")) snprintf(id, sizeof id, "%s", v);
        else if (!strcmp(line, "title")) snprintf(title, sizeof title, "%s", v); else if (!strcmp(line, "body")) snprintf(body, sizeof body, "%s", v);
        else if (!strcmp(line, "icon")) snprintf(icon, sizeof icon, "%s", v); else if (!strcmp(line, "record")) snprintf(record, sizeof record, "%s", v);
        else if (!strcmp(line, "thumb")) snprintf(thumb, sizeof thumb, "%s", v); else if (!strcmp(line, "fire")) snprintf(fire, sizeof fire, "%s", v);
        else if (!strcmp(line, "bundle")) snprintf(bundle, sizeof bundle, "%s", v);
    }
    fclose(f);
    unlink(sidecar);
    int i = shell_find(path);
    if (i >= 0) { fprintf(stderr, "isim shell: local notification %s is due in the running %s (the app delivers it)\n", id, short_name(i)); return; }
    fprintf(stderr, "isim shell: local notification %s for %s, which is not running: the system delivers it\n", id, path);
    sys_send_text(0, "local-shown %s\x1f%s\x1f%s", bundle, id, fire);
    if (!strchr(flags, 'a')) { fprintf(stderr, "isim shell: local notification %s for %s not shown (the app may not show alerts)\n", id, path); return; }
    struct nc_item *n = nc_add(path, id, icon, title, body);
    snprintf(n->record, sizeof n->record, "%s", record); snprintf(n->thumb, sizeof n->thumb, "%s", thumb);
    snprintf(n->exe, sizeof n->exe, "%s", exe);
    nc_load_sidecar(n);
    sys_alert(-1, n, flags);
}

/* script commands for the system (EV_SHELL_CMD); returns 1 when handled */
static int sys_command(const char *text) {
    char verb[32] = {0}; int n = 0;
    sscanf(text, "%31s%n", verb, &n);
    const char *args = text + n; while (*args == ' ') args++;
    if (!strcmp(verb, "bgtask")) { sys_send_text(0, "launchtask %s", args); return 1; }  /* the home screen resolves the bundle id */
    if (!strcmp(verb, "terminate")) { sys_send_text(0, "terminate %s", args); return 1; }
    if (!strcmp(verb, "openurl")) { sys_send_text(0, "openurl %s", args); return 1; }
    if (!strcmp(verb, "handoff")) { sys_send_text(0, "handoff %s", args); return 1; }   /* an activity from another device */
    if (!strcmp(verb, "appclip")) { sys_send_text(0, "appclip %s", args); return 1; }   /* App Clips: the home screen resolves them */
    if (!strcmp(verb, "push") || !strcmp(verb, "push-drop")) {   /* remote notifications: the home screen routes them */
        char a[1000]; snprintf(a, sizeof a, "%s", args);
        if (!strcmp(verb, "push")) {                             /* make the file path absolute: the home screen's cwd differs */
            char *sp = strchr(a, ' ');
            if (sp && sp[1] && sp[1] != '/') { char cwd[512]; if (getcwd(cwd, sizeof cwd)) { char b[1000]; snprintf(b, sizeof b, "%.*s %s/%s", (int)(sp - a), a, cwd, sp + 1); snprintf(a, sizeof a, "%s", b); } }
        }
        sys_send_text(0, "%s %s", verb, a); return 1;
    }
    if (!strcmp(verb, "lock")) { sys_lock(); return 1; }
    if (!strcmp(verb, "unlock")) { sys_unlock(); return 1; }
    if (!strcmp(verb, "switcher")) { if (!locked) sys_open(OV_SWITCHER); return 1; }
    if (!strcmp(verb, "notifications")) { if (!locked) sys_open(OV_NC); return 1; }
    if (!strcmp(verb, "controlcenter")) { if (!locked) sys_open(OV_CC); return 1; }
    if (!strcmp(verb, "remote")) {                           /* to the app that is playing (else the foreground app) */
        int to = np_on() ? np.client : active;
        if (to >= 0) sys_send_text(to, "remote %s", args);
        return 1;
    }
    if (!strcmp(verb, "volume")) {                           /* the volume buttons: volume up|down|0...1 */
        double v = cc_volume;
        if (!strcmp(args, "up")) v += 1.0 / 16; else if (!strcmp(args, "down")) v -= 1.0 / 16; else v = atof(args);
        v = fmin(1, fmax(0, round(v * 16) / 16));
        sys_volume_changed(v, -1);
        fprintf(stderr, "isim shell: volume %d%%\n", (int)lround(v * 100));
        if (ov != OV_NONE) sys_draw();
        return 1;
    }
    if (!strcmp(verb, "island")) {                             /* island [detached]: expand / collapse */
        int idx[LA_MAX];
        if (la_island_list(idx) > 0 || la_expanded() >= 0) { la_toggle(!strcmp(args, "detached")); shell_show(active); }
        else fprintf(stderr, "isim shell: no Live Activity\n");
        return 1;
    }
    if (!strcmp(verb, "standby")) {                            /* standby on|off: StandBy (charging, on its side) */
        if (!strcmp(args, "on") || !strcmp(args, "off")) standby_set(!strcmp(args, "on"));
        else fprintf(stderr, "isim shell: standby on|off\n");
        return 1;
    }
    if (!strcmp(verb, "lockscreen")) {                         /* lockscreen customize|done: the Lock Screen editor */
        if (!strcmp(args, "customize")) { if (!locked) sys_lock(); lock_customize(); }
        else if (!strcmp(args, "done")) sys_send_text(0, "lock-customize-done");
        else fprintf(stderr, "isim shell: lockscreen customize|done\n");
        return 1;
    }
    if (!strcmp(verb, "homepage")) { if (!locked && active == 0) sys_send_text(0, "homepage %s", args); return 1; }
    if (!strcmp(verb, "iconstyle")) { sys_send_text(0, "iconstyle %s", args); return 1; }   /* Home Screen > Edit > Customize */
    if (!strcmp(verb, "spotlight")) { if (!locked && active == 0) sys_send_text(0, "spotlight"); return 1; }
    if (ctl_command(verb, args)) return 1;                       /* focus, actionbutton, lockcontrol */
    if (!strcmp(verb, "siri")) { sys_send_text(0, "siri %d %s", locked, args); return 1; }   /* the simulated Siri (SBSiri.m) */
    fprintf(stderr, "isim shell: '%s' is not available\n", verb);
    return 1;
}

/* a notification delivered to a background app: Notification Center / lock screen list, and a banner unless hidden.
   a = id\x1ficon\x1frecord\x1fthumb */
static void sys_notify(int i, const struct shell_msg *m) {
    char id[256], icon[512];
    field(m->a, 0, id, sizeof id); field(m->a, 1, icon, sizeof icon);
    struct nc_item *n = nc_add(clients[i].bundle, id, icon, m->b, m->c);
    field(m->a, 2, n->record, sizeof n->record); field(m->a, 3, n->thumb, sizeof n->thumb);
    nc_load_sidecar(n);
    char flags[16]; field(m->a, 4, flags, sizeof flags);
    sys_alert(i, n, flags);
}

#include "shell_siri.inc"
#include "shell_calls.inc"
