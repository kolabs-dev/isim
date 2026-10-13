/* isim shell: the system call UI for CallKit (included by shell_system.inc). Adapted: isim's drawing of iOS's call
 * screens; isim has no telephony, so the calls are the apps' VoIP calls (CallKit, swift/overlays/CallKit).
 *
 * The app reports calls ("call-incoming UUID caller\x1fhandle\x1fvideo\x1fringtone\x1fcaps\x1fapp name", "call-outgoing",
 * "call-update", "call-state UUID connecting|connected|held|unheld|muted|unmuted", "call-end UUID REASON") and gets
 * what the user does as "call-action answer|end|mute|hold|dtmf|speaker UUID [ARG]".
 *   Incoming: while the device is in use, a banner at the top (in the Dynamic Island's black on iPhones that have one)
 *   with Decline and Accept; tapping it opens the full-screen call; on the Lock Screen the full-screen call with
 *   "slide to answer". The ringtone repeats (the provider's ringtoneSound, else isim's own), silent in Silent Mode.
 *   In a call: the call screen (caller, duration; speaker, video, mute, hold / add call, the app, keypad; End). Home /
 *   swiping up hides it; then the call shows as the green indicator around the clock (in the Dynamic Island: a phone
 *   and the duration in green), which brings the call screen back. Calls the app placed itself show only the indicator.
 * Script ids: call-banner, call-accept, call-decline, call-mute, call-speaker, call-video, call-hold, call-add, call-app,
 * call-keypad, call-key-0..9 / call-key-star / call-key-hash, call-keypad-hide, call-end, call-pill. */

#define CALL_MAX 4
static struct call {
    char uuid[64], path[512], name[128], handle[128], appname[96], ringtone[512], caps[8];
    int client, video, incoming, state;            /* state: 0 ringing / dialing, 1 connecting, 2 connected */
    int muted, held, speaker, ring_buf;
    double t0, t_conn, last_ring;
} calls[CALL_MAX];
static int ncalls;
static int call_ui;                                /* 0 none, 1 banner, 2 full-screen incoming, 3 call screen */
static int call_keypad;
static char call_digits[40];
static double call_ui_t0;

static int calls_pill_visible(void);
static int calls_fullscreen(void) { return ncalls > 0 && call_ui >= 2; }
static int calls_visible(void) { return ncalls > 0 && (call_ui || calls_pill_visible()); }
static struct call *call_find(const char *uuid) { for (int k = 0; k < ncalls; k++) if (!strcmp(calls[k].uuid, uuid)) return &calls[k]; return NULL; }
static struct call *call_main(void) {             /* the call the UI is about: a ringing one first */
    for (int k = 0; k < ncalls; k++) if (calls[k].incoming && calls[k].state == 0) return &calls[k];
    return ncalls ? &calls[0] : NULL;
}
static int calls_pill_visible(void) {
    if (!ncalls || call_ui || locked || ov != OV_NONE || anim.kind != ANIM_NONE) return 0;
    struct call *c = call_main();
    return c && !(c->incoming && c->state == 0);
}
static void call_redraw(void) { shell_show(active >= 0 ? active : 0); }
static void call_set_ui(int ui) {
    if (ui != call_ui) call_ui_t0 = now();
    call_ui = ui;
    if (ui != 3) call_keypad = 0;
    call_redraw();
}
static void call_send(struct call *c, const char *fmt, ...) {
    char t[300]; va_list ap; va_start(ap, fmt); vsnprintf(t, sizeof t, fmt, ap); va_end(ap);
    if (c->client >= 0 && c->client < nclients && clients[c->client].alive) sys_send_text(c->client, "call-action %s", t);
}
static void call_remove(struct call *c, const char *why) {
    fprintf(stderr, "isim shell: call %s with %s ended (%s)\n", c->uuid, c->name, why);
    if (c->ring_buf) isim_audio_buffer_release(c->ring_buf);
    int k = (int)(c - calls);
    memmove(&calls[k], &calls[k + 1], (ncalls - k - 1) * sizeof *calls); ncalls--;
    if (!ncalls) { call_ui = 0; call_keypad = 0; call_digits[0] = 0; }
    else if (call_ui == 1 || call_ui == 2) { struct call *m = call_main(); if (!(m->incoming && m->state == 0)) call_ui = 0; }
    call_redraw();
}
static void call_duration(struct call *c, char *out, size_t n) {
    if (c->held) { snprintf(out, n, "on hold"); return; }
    if (c->state < 2) { snprintf(out, n, c->incoming ? "connecting…" : "calling…"); return; }
    int s = (int)(now() - c->t_conn);
    if (s >= 3600) snprintf(out, n, "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60); else snprintf(out, n, "%02d:%02d", s / 60, s % 60);
}

/* ---- the ringtone: the provider's sound file, else a synthesized two-tone ring; every 3 s while it rings ---- */
static int call_ring_buffer(struct call *c) {
    if (c->ring_buf) return c->ring_buf;
    if (c->ringtone[0]) {
        float *pcm = NULL; long frames = 0; int ch = 0; double rate = 0;
        if (isim_audio_decode_file(c->ringtone, &pcm, &frames, &ch, &rate)) { c->ring_buf = isim_audio_buffer_create(pcm, frames, ch, rate); isim_audio_free(pcm); }
        if (c->ring_buf) return c->ring_buf;
    }
    enum { RATE = 44100 };
    long frames = RATE * 2;                        /* 2 s: the classic double ring (two bursts of alternating tones) */
    float *pcm = calloc((size_t)frames, sizeof(float));
    for (long i = 0; i < frames; i++) {
        double t = (double)i / RATE;
        if (!(t < 0.4 || (t >= 0.5 && t < 0.9))) continue;
        double bt = t < 0.4 ? t : t - 0.5, f = ((int)(t / 0.05) % 2) ? 1318.5 : 1046.5;
        pcm[i] = (float)(0.22 * sin(2 * M_PI * f * t) * fmin(1, bt * 40) * fmin(1, (0.4 - bt) * 40));
    }
    c->ring_buf = isim_audio_buffer_create(pcm, frames, 1, RATE);
    free(pcm);
    return c->ring_buf;
}
static void call_ring(struct call *c) {
    c->last_ring = now();
    if (ctl_silent) return;
    if (!isim_audio_available()) return;
    int b = call_ring_buffer(c);
    if (b) isim_audio_play(b, cc_volume, 0);
}

/* ---- app → shell ---- */
static void call_fields(struct call *c, const char *f) {
    char v[8];
    field(f, 0, c->name, sizeof c->name); field(f, 1, c->handle, sizeof c->handle);
    field(f, 2, v, sizeof v); c->video = atoi(v);
    field(f, 4, c->caps, sizeof c->caps); field(f, 5, c->appname, sizeof c->appname);
    if (!c->appname[0]) { struct sys_appinfo *ai = sys_info(c->path); snprintf(c->appname, sizeof c->appname, "%s", ai && ai->name[0] ? ai->name : "VoIP"); }
}
static int calls_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (strncmp(verb, "call-", 5)) return 0;
    struct call *c = call_find(m->b);
    if (!strcmp(verb, "call-incoming") || !strcmp(verb, "call-outgoing")) {
        if (c || ncalls >= CALL_MAX) { fprintf(stderr, "isim shell: call %s refused (%s)\n", m->b, c ? "it exists" : "too many calls"); return 1; }
        c = &calls[ncalls++];
        memset(c, 0, sizeof *c);
        snprintf(c->uuid, sizeof c->uuid, "%s", m->b); snprintf(c->path, sizeof c->path, "%s", clients[from].bundle);
        c->client = from; c->t0 = now();
        call_fields(c, m->c);
        c->incoming = verb[5] == 'i';
        if (c->incoming) {
            field(m->c, 3, c->ringtone, sizeof c->ringtone);
            fprintf(stderr, "isim shell: incoming %s call from %s (%s)%s\n", c->video ? "video" : "audio", c->name, c->appname,
                    ctl_silent ? ": ringing silently (Silent Mode)" : "");
            call_set_ui(locked || standby ? 2 : 1);
            call_ring(c);
        } else {
            fprintf(stderr, "isim shell: outgoing call to %s (%s)\n", c->name, c->appname);
            call_redraw();
        }
    } else if (!c) {
        return 1;                                   /* a call the user already ended here */
    } else if (!strcmp(verb, "call-update")) {
        call_fields(c, m->c);
        call_redraw();
    } else if (!strcmp(verb, "call-state")) {
        if (!strcmp(m->c, "connecting")) c->state = 1;
        else if (!strcmp(m->c, "connected")) { if (c->state < 2) c->t_conn = now(); c->state = 2; fprintf(stderr, "isim shell: call with %s connected\n", c->name); }
        else if (!strcmp(m->c, "held") || !strcmp(m->c, "unheld")) c->held = m->c[0] == 'h';
        else if (!strcmp(m->c, "muted") || !strcmp(m->c, "unmuted")) c->muted = m->c[0] == 'm';
        call_redraw();
    } else if (!strcmp(verb, "call-end")) {
        call_remove(c, m->c[0] ? m->c : "ended");
    }
    return 1;
}

/* ---- drawing ---- */
static const double call_red[3] = { 0.92, 0.27, 0.23 }, call_green[3] = { 0.2, 0.78, 0.35 };
static void call_circle(cairo_t *c, double cx, double cy, double d, const double *rgb, double a) {
    cairo_new_path(c); cairo_arc(c, cx, cy, d / 2, 0, 2 * M_PI);
    cairo_set_source_rgba(c, rgb[0], rgb[1], rgb[2], a); cairo_fill(c);
}
/* a round call button: on (white) or off (translucent; Liquid Glass from iOS 26), its glyph and label */
static void call_button(cairo_t *c, const char *id, const char *label, const char *symbol, double cx, double cy, int on, int enabled) {
    double d = 78;
    if (sys_os() >= 26 && !on) sys_glass(c, cx - d / 2, cy - d / 2, d, d, d / 2, NULL, 1 | 2 | 4);
    static const double white[3] = { 1, 1, 1 };
    call_circle(c, cx, cy, d, white, on ? 1 : enabled ? 0.22 : 0.1);
    double g = on ? 0.1 : 1, ga = enabled ? 1 : 0.4;
    sys_symbol(c, symbol, cx, cy, 30, g * ga + (1 - ga) * 0.5, g * ga + (1 - ga) * 0.5, g * ga + (1 - ga) * 0.5);
    sys_text(c, label, cx - 50, cy + d / 2 + 6, 100, 13, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, enabled ? 0.95 : 0.4);
    if (enabled) el_add(id, label, (struct rectf){ cx - d / 2, cy - d / 2, d, d }, EL_CALL, on);
}
static void call_background(cairo_t *c) {
    /* the wallpaper, blurred and darkened (isim has no contact posters) */
    cairo_surface_t *home = client_surface(0); int hw, hh; client_dims(0, &hw, &hh);
    int w = (int)dev.width, h = (int)dev.height;
    cairo_surface_t *wp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    cairo_t *k = cairo_create(wp); wallpaper_draw(k, home, hw, hh); cairo_destroy(k);
    sys_paint_blurred(c, wp, w, h, 0.45);
    cairo_surface_destroy(wp); cairo_surface_destroy(home);
}
static void call_title(cairo_t *c, struct call *k, const char *top, const char *status) {
    double y = fmax(dev.safe_top, 20) + 44;
    if (top) sys_text(c, top, 20, y, dev.width - 40, 15, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, 0.7);
    sys_text(c, k->name, 20, y + 22, dev.width - 40, 34, PANGO_WEIGHT_NORMAL, 1, 2, 1, 1, 1, 1);
    el_add("call-caller", k->name, (struct rectf){ 20, y + 22, dev.width - 40, 42 }, EL_NONE, 0);
    if (status) {
        sys_text(c, status, 20, y + 68, dev.width - 40, 17, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 0.75);
        el_add("call-status", status, (struct rectf){ 20, y + 68, dev.width - 40, 22 }, EL_NONE, 0);
    }
}
static void call_draw_incoming(cairo_t *c, struct call *k) {
    call_background(c);
    char top[160]; snprintf(top, sizeof top, "%s %s", k->appname, k->video ? "Video" : "Audio");
    call_title(c, k, top, NULL);
    double by = dev.height - fmax(dev.safe_bottom, 20) - 110;
    if (locked) {                                  /* the Lock Screen: slide to answer */
        double x = 34, w = dev.width - 68, h = 74, y = by - 10;
        if (sys_os() >= 26) sys_glass(c, x, y, w, h, h / 2, NULL, 1 | 2 | 4);
        cairo_new_path(c); sys_round(c, x, y, w, h, h / 2); cairo_set_source_rgba(c, 1, 1, 1, 0.18); cairo_fill(c);
        sys_text(c, "slide to answer", x + h, y + h / 2 - 12, w - h - 10, 20, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 0.85);
        static const double white[3] = { 1, 1, 1 };
        call_circle(c, x + h / 2, y + h / 2, h - 10, white, 1);
        sys_symbol(c, "phone.fill", x + h / 2, y + h / 2, 28, call_green[0], call_green[1], call_green[2]);
        el_add("call-accept", "slide to answer", (struct rectf){ x, y, w, h }, EL_CALL, 0);
        return;
    }
    double lx = dev.width * 0.25, rx = dev.width * 0.75;
    call_circle(c, lx, by, 78, call_red, 1); sys_symbol(c, "phone.down.fill", lx, by, 32, 1, 1, 1);
    call_circle(c, rx, by, 78, call_green, 1); sys_symbol(c, "phone.fill", rx, by, 30, 1, 1, 1);
    sys_text(c, "Decline", lx - 50, by + 45, 100, 15, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, 0.95);
    sys_text(c, "Accept", rx - 50, by + 45, 100, 15, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, 0.95);
    el_add("call-decline", "Decline", (struct rectf){ lx - 39, by - 39, 78, 78 }, EL_CALL, 0);
    el_add("call-accept", "Accept", (struct rectf){ rx - 39, by - 39, 78, 78 }, EL_CALL, 0);
}
static void call_draw_banner(cairo_t *c, struct call *k) {
    double w = fmin(dev.width - 16, 420), x = (dev.width - w) / 2, y = dev.has_island == 1 ? 11 : fmax(dev.safe_top - 40, 8), h = 76;
    double t = fmin(1, (now() - call_ui_t0) / 0.3), e = 1 - pow(1 - t, 3);
    cairo_save(c);
    cairo_translate(c, 0, -(y + h) * (1 - e));
    cairo_new_path(c); sys_round(c, x, y, w, h, 38);
    cairo_set_source_rgba(c, 0.07, 0.07, 0.08, dev.has_island == 1 ? 1 : 0.94); cairo_fill(c);
    struct sys_appinfo *ai = sys_info(k->path);
    if (ai && ai->icon[0]) sys_icon(c, ai->icon, x + 16, y + 18, 40);
    char sub[160]; snprintf(sub, sizeof sub, "%s %s", k->appname, k->video ? "Video" : "Audio");
    double tx = x + 66, tw = w - 66 - 120;
    sys_text(c, sub, tx, y + 17, tw, 13, PANGO_WEIGHT_NORMAL, 0, 1, 1, 1, 1, 0.6);
    sys_text(c, k->name, tx, y + 35, tw, 17, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
    double d = 48, cy = y + h / 2, ax = x + w - 14 - d / 2, dx = ax - d - 10;
    call_circle(c, dx, cy, d, call_red, 1); sys_symbol(c, "phone.down.fill", dx, cy, 22, 1, 1, 1);
    call_circle(c, ax, cy, d, call_green, 1); sys_symbol(c, "phone.fill", ax, cy, 20, 1, 1, 1);
    cairo_restore(c);
    el_add("call-banner", k->name, (struct rectf){ x, y, w, h }, EL_CALL, 0);
    el_add("call-decline", "Decline", (struct rectf){ dx - d / 2, cy - d / 2, d, d }, EL_CALL, 0);
    el_add("call-accept", "Accept", (struct rectf){ ax - d / 2, cy - d / 2, d, d }, EL_CALL, 0);
}
static const char *const call_keys[12] = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#" };
static const char *const call_key_letters[12] = { "", "ABC", "DEF", "GHI", "JKL", "MNO", "PQRS", "TUV", "WXYZ", "", "+", "" };
static void call_draw_screen(cairo_t *c, struct call *k) {
    call_background(c);
    char st[64]; call_duration(k, st, sizeof st);
    if (call_keypad && call_digits[0]) call_title(c, k, NULL, call_digits); else call_title(c, k, NULL, st);
    double colx[3] = { dev.width / 2 - 100, dev.width / 2, dev.width / 2 + 100 };
    double endy = dev.height - fmax(dev.safe_bottom, 20) - 70;
    if (call_keypad) {
        double top = endy - 4 * 92 - 40;
        static const double white[3] = { 1, 1, 1 };
        for (int i = 0; i < 12; i++) {
            double cx = colx[i % 3], cy = top + (i / 3) * 92;
            if (sys_os() >= 26) sys_glass(c, cx - 39, cy - 39, 78, 78, 39, NULL, 1 | 2 | 4);
            call_circle(c, cx, cy, 78, white, 0.22);
            int letters = call_key_letters[i][0] != 0;
            sys_text(c, call_keys[i], cx - 39, cy - (letters ? 24 : 18), 78, 32, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 1);
            if (letters) sys_text(c, call_key_letters[i], cx - 39, cy + 12, 78, 10, PANGO_WEIGHT_BOLD, 1, 1, 1, 1, 1, 0.9);
            char id[24]; snprintf(id, sizeof id, "call-key-%s", i == 9 ? "star" : i == 11 ? "hash" : call_keys[i]);
            el_add(id, call_keys[i], (struct rectf){ cx - 39, cy - 39, 78, 78 }, EL_CALL, i);
        }
        sys_text(c, "Hide", colx[2] - 40, endy - 11, 80, 17, PANGO_WEIGHT_NORMAL, 1, 1, 1, 1, 1, 1);
        el_add("call-keypad-hide", "Hide", (struct rectf){ colx[2] - 39, endy - 39, 78, 78 }, EL_CALL, 0);
    } else {
        double r1 = endy - 250, r2 = endy - 135;
        int hold = strchr(k->caps, 'h') != NULL;
        call_button(c, "call-speaker", "speaker", "speaker.wave.3.fill", colx[0], r1, k->speaker, 1);
        call_button(c, "call-video", "video", "video.fill", colx[1], r1, k->video, strchr(k->caps, 'v') != NULL);
        call_button(c, "call-mute", "mute", "mic.slash.fill", colx[2], r1, k->muted, 1);
        if (hold) call_button(c, "call-hold", "hold", "pause.fill", colx[0], r2, k->held, 1);
        else call_button(c, "call-add", "add call", "plus", colx[0], r2, 0, strchr(k->caps, 'g') != NULL);
        double d = 78;                                     /* the app's button: its icon */
        if (sys_os() >= 26) sys_glass(c, colx[1] - d / 2, r2 - d / 2, d, d, d / 2, NULL, 1 | 2 | 4);
        static const double white[3] = { 1, 1, 1 };
        call_circle(c, colx[1], r2, d, white, 0.22);
        struct sys_appinfo *ai = sys_info(k->path);
        if (ai && ai->icon[0]) sys_icon(c, ai->icon, colx[1] - 17, r2 - 17, 34);
        sys_text(c, k->appname, colx[1] - 50, r2 + d / 2 + 6, 100, 13, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, 0.95);
        el_add("call-app", k->appname, (struct rectf){ colx[1] - d / 2, r2 - d / 2, d, d }, EL_CALL, 0);
        call_button(c, "call-keypad", "keypad", "circle.grid.3x3.fill", colx[2], r2, 0, 1);
    }
    call_circle(c, colx[1], endy, 78, call_red, 1); sys_symbol(c, "phone.down.fill", colx[1], endy, 32, 1, 1, 1);
    el_add("call-end", "End", (struct rectf){ colx[1] - 39, endy - 39, 78, 78 }, EL_CALL, 0);
}
/* the call while its screen is hidden: green around the clock, or in the Dynamic Island */
static void call_draw_pill(cairo_t *c, struct call *k) {
    char st[64]; call_duration(k, st, sizeof st);
    if (k->state < 2) st[0] = 0;
    if (dev.has_island == 1) {
        struct rectf r = la_compact_rect();
        sys_round(c, r.x, r.y, r.w, r.h, 18.5); cairo_set_source_rgb(c, 0, 0, 0); cairo_fill(c);
        sys_symbol(c, "phone.fill", r.x + 22, r.y + r.h / 2, 16, call_green[0], call_green[1], call_green[2]);
        if (st[0]) sys_text(c, st, r.x + r.w - 70, r.y + 9, 58, 15, PANGO_WEIGHT_SEMIBOLD, 2, 1, call_green[0], call_green[1], call_green[2], 1);
        el_add("call-pill", st[0] ? st : k->name, r, EL_CALL, 0);
        return;
    }
    struct rectf r = pill_rect(NULL);
    sys_round(c, r.x, r.y, r.w, r.h, r.h / 2); cairo_set_source_rgb(c, call_green[0], call_green[1], call_green[2]); cairo_fill(c);
    time_t tt = time(NULL); struct tm tm; localtime_r(&tt, &tm);
    char clock[16]; snprintf(clock, sizeof clock, "%d:%02d", tm.tm_hour % 12 ? tm.tm_hour % 12 : 12, tm.tm_min);
    sys_text(c, clock, r.x, r.y + 3, r.w, 16, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
    el_add("call-pill", st[0] ? st : k->name, r, EL_CALL, 0);
}
static void calls_draw(cairo_t *c) {
    struct call *k = call_main();
    if (!k) return;
    if (call_ui == 1) call_draw_banner(c, k);
    else if (call_ui == 2) call_draw_incoming(c, k);
    else if (call_ui == 3) call_draw_screen(c, k);
    else if (calls_pill_visible()) call_draw_pill(c, k);
}

/* ---- what the user does ---- */
static void call_answer(struct call *k) {
    fprintf(stderr, "isim shell: answered the call from %s\n", k->name);
    k->state = k->state < 1 ? 1 : k->state;
    call_send(k, "answer %s", k->uuid);
    call_set_ui(3);
}
static void call_hang_up(struct call *k, const char *how) {
    fprintf(stderr, "isim shell: %s the call %s\n", how, k->name);
    call_send(k, "end %s", k->uuid);
    call_remove(k, how);
}
static void call_open_app(struct call *k) {
    if (locked) sys_unlock();
    int i = k->client;
    call_set_ui(0);
    if (i > 0 && i < nclients && clients[i].alive) { fprintf(stderr, "isim shell: opened %s from the call\n", app_label(i)); shell_activate(i); }
}
static void call_tap(struct sys_el *e) {
    struct call *k = call_main();
    if (!k || !e) return;
    const char *id = e->id;
    if (!strcmp(id, "call-accept")) call_answer(k);
    else if (!strcmp(id, "call-decline")) call_hang_up(k, "declined");
    else if (!strcmp(id, "call-banner")) call_set_ui(2);
    else if (!strcmp(id, "call-end")) call_hang_up(k, "ended");
    else if (!strcmp(id, "call-pill")) call_set_ui(3);
    else if (!strcmp(id, "call-app")) call_open_app(k);
    else if (!strcmp(id, "call-mute")) { k->muted = !k->muted; call_send(k, "mute %s %d", k->uuid, k->muted); fprintf(stderr, "isim shell: call %s\n", k->muted ? "muted" : "unmuted"); }
    else if (!strcmp(id, "call-hold")) { k->held = !k->held; call_send(k, "hold %s %d", k->uuid, k->held); fprintf(stderr, "isim shell: call %s\n", k->held ? "on hold" : "resumed"); }
    else if (!strcmp(id, "call-speaker")) { k->speaker = !k->speaker; call_send(k, "speaker %s %d", k->uuid, k->speaker); fprintf(stderr, "isim shell: speaker %s\n", k->speaker ? "on" : "off"); }
    else if (!strcmp(id, "call-keypad")) { call_keypad = 1; call_digits[0] = 0; }
    else if (!strcmp(id, "call-keypad-hide")) call_keypad = 0;
    else if (!strncmp(id, "call-key-", 9)) {
        const char *d = call_keys[e->arg];
        if (strlen(call_digits) + 1 < sizeof call_digits) strcat(call_digits, d);
        if (strchr(k->caps, 'd')) call_send(k, "dtmf %s %s", k->uuid, d);
        fprintf(stderr, "isim shell: keypad %s\n", d);
    }
    else if (!strcmp(id, "call-video") || !strcmp(id, "call-add")) fprintf(stderr, "isim shell: %s is not available on isim\n", e->text);
    call_redraw();
}
static struct sys_el *call_hit(double x, double y) {
    for (int k = nels - 1; k >= 0; k--) {
        struct rectf r = els[k].r;
        if (els[k].kind == EL_CALL && x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) {
            if (!strcmp(els[k].id, "call-banner")) {         /* the buttons on the banner first */
                for (int j = nels - 1; j > k; j--) { struct rectf q = els[j].r; if (els[j].kind == EL_CALL && x >= q.x && x <= q.x + q.w && y >= q.y && y <= q.y + q.h) return &els[j]; }
            }
            return &els[k];
        }
    }
    return NULL;
}
/* Home while a call screen is up: the call screen goes (the call goes on behind the indicator); a full-screen incoming
   call becomes the banner. 1 when Home was the call's. */
static int calls_home(void) {
    if (locked || !ncalls) return 0;
    if (call_ui == 3) { call_set_ui(0); return 1; }
    if (call_ui == 2) { call_set_ui(1); return 1; }
    return 0;
}
static int calls_input(const struct isim_event *ev) {
    if (!ncalls) return 0;
    if (ev->type == EV_DUMP) {
        if (ov != OV_NONE || !calls_visible()) return 0;     /* sys_dump lists the call's parts with the overlay's */
        static const char *const names[] = { "IsimCallIndicator", "IsimIncomingCallBanner", "IsimIncomingCall", "IsimCallScreen" };
        fprintf(stderr, "%s (0 0; %g x %g)\n", names[call_ui], dev.width, dev.height);
        for (int k = 0; k < nels; k++) if (!strncmp(els[k].id, "call-", 5))
            fprintf(stderr, "  IsimCallButton (%g %g; %g x %g) id=%s%s%s\n", els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text[0] ? " text=" : "", els[k].text);
        return 0;
    }
    if (ev->type == EV_KEY && ev->key == 27 && call_ui == 3) { call_set_ui(0); return 1; }
    if (ev->type == EV_KEY && (ev->mods & SDL_KMOD_CTRL) && (ev->mods & SDL_KMOD_SHIFT) && (ev->key == 'h' || ev->key == 'H')) return calls_home();
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        if (strncmp(ev->text, "call-", 5)) return call_ui >= 2;
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no call element '%s'\n", ev->text); return 1; }
        if (ev->type == EV_ID_UP && ev->mods != 1) call_tap(e);
        return 1;
    }
    static int down_on_call;
    static double dy0;
    if (ev->type == EV_TOUCH_DOWN) {
        struct sys_el *e = call_hit(ev->x, ev->y);
        down_on_call = e != NULL || call_ui >= 2; dy0 = ev->y;
        return down_on_call;
    }
    if (ev->type == EV_TOUCH_MOVE) return down_on_call;
    if (ev->type == EV_TOUCH_UP) {
        if (!down_on_call) return 0;
        down_on_call = 0;
        if (call_ui == 3 && dy0 > dev.height - 40 && ev->y < dy0 - 60 && !locked) { call_set_ui(0); return 1; }   /* swipe up */
        call_tap(call_hit(ev->x, ev->y));
        return 1;
    }
    return 0;
}
static void calls_tick(void) {
    for (int k = 0; k < ncalls; k++) {
        struct call *c = &calls[k];
        if (c->client < 0 || c->client >= nclients || !clients[c->client].alive) { call_remove(c, "the app quit"); k--; continue; }
        if (c->incoming && c->state == 0 && now() - c->last_ring > 3) call_ring(c);
    }
    static double last;
    if (!ncalls) return;
    double t = now();
    int animating = call_ui == 1 && t - call_ui_t0 < 0.35;
    if ((animating && t - last > 0.03) || t - last > 1.0) { last = t; if (calls_visible()) call_redraw(); }
}
