/* isim shell: the system alarm alert for AlarmKit (included by shell_system.inc). Adapted: isim's drawing of iOS 26's
 * alarm and timer alerts; the alarms are the apps' (AlarmKit, swift/overlays/AlarmKit).
 *
 * The app tells the shell when each of its alarms goes off: "alarm-set UUID FIRE title\x1fstop\x1fsecondary\x1f
 * secondary symbol\x1fapp name\x1ftint r,g,b\x1fsound\x1fkind" (FIRE: seconds since 1970; kind: alarm or timer), and
 * "alarm-clear UUID" when it no longer does (cancelled, paused, stopped). The shell keeps the time, so an alarm goes
 * off whether or not its app runs, and plays in Silent Mode like iOS's alarms. When it goes off the app gets
 * "alarm-action alert UUID"; what the user does comes as "alarm-action stop|secondary UUID". An action taken while the
 * app was not running waits in the shell until the app runs and sets that alarm again.
 *   While the device is in use: a banner at the top (in the Dynamic Island's black on iPhones that have one) with the
 *   title, the secondary button and a Stop (×) button; tapping the banner opens the full-screen alert. On the Lock
 *   Screen and in StandBy: the full-screen alert (the time, the title, the secondary button, Stop).
 * Script ids: alarm-banner, alarm-stop, alarm-secondary. */

#define ALARM_MAX 16
static struct alarm {
    char uuid[64], path[512], title[128], stop[48], secondary[48], symbol[64], appname[96], sound[512];
    double fire, tint[3];
    int timer, alerting, pending;                  /* pending: 's' stop / 'x' secondary, for an app that was not running */
    int ring_buf;
    double last_ring;
} alarms[ALARM_MAX];
static int nalarms;
static int alarm_ui;                               /* 0 none, 1 banner, 2 full screen */
static double alarm_ui_t0;

static struct alarm *alarm_find(const char *uuid) { for (int k = 0; k < nalarms; k++) if (!strcmp(alarms[k].uuid, uuid)) return &alarms[k]; return NULL; }
static struct alarm *alarm_main(void) {           /* the alarm the alert is about */
    for (int k = 0; k < nalarms; k++) if (alarms[k].alerting) return &alarms[k];
    return NULL;
}
static int alarms_visible(void) { return alarm_main() != NULL && alarm_ui != 0; }
static int alarms_fullscreen(void) { return alarms_visible() && alarm_ui == 2; }
static void alarm_redraw(void) { shell_show(active >= 0 ? active : 0); }
static void alarm_set_ui(int ui) {
    if (ui != alarm_ui) alarm_ui_t0 = now();
    alarm_ui = ui;
    alarm_redraw();
}
/* the running client of the alarm's app, or -1 */
static int alarm_client(const struct alarm *a) {
    for (int i = 1; i < nclients; i++) if (clients[i].alive && !strcmp(clients[i].bundle, a->path)) return i;
    return -1;
}
static int alarm_send(const struct alarm *a, const char *what) {
    int i = alarm_client(a);
    if (i < 0) return 0;
    sys_send_text(i, "alarm-action %s %s", what, a->uuid);
    return 1;
}
static void alarm_remove(struct alarm *a) {
    if (a->ring_buf) isim_audio_buffer_release(a->ring_buf);
    int k = (int)(a - alarms);
    memmove(&alarms[k], &alarms[k + 1], (nalarms - k - 1) * sizeof *alarms); nalarms--;
    if (!alarm_main()) alarm_ui = 0;
    alarm_redraw();
}

/* ---- the sound: the alarm's sound file, else a synthesized alarm (four quick beeps); every 1.5 s while it alerts ---- */
static int alarm_ring_buffer(struct alarm *a) {
    if (a->ring_buf) return a->ring_buf;
    if (a->sound[0]) {
        float *pcm = NULL; long frames = 0; int ch = 0; double rate = 0;
        if (isim_audio_decode_file(a->sound, &pcm, &frames, &ch, &rate)) { a->ring_buf = isim_audio_buffer_create(pcm, frames, ch, rate); isim_audio_free(pcm); }
        if (a->ring_buf) return a->ring_buf;
    }
    enum { RATE = 44100 };
    long frames = RATE;                            /* 1 s: four 0.1 s beeps 0.18 s apart */
    float *pcm = calloc((size_t)frames, sizeof(float));
    for (long i = 0; i < frames; i++) {
        double t = (double)i / RATE, bt = fmod(t, 0.18);
        if (t >= 0.72 || bt >= 0.1) continue;
        pcm[i] = (float)(0.25 * sin(2 * M_PI * 1760 * t) * fmin(1, bt * 200) * fmin(1, (0.1 - bt) * 200));
    }
    a->ring_buf = isim_audio_buffer_create(pcm, frames, 1, RATE);
    free(pcm);
    return a->ring_buf;
}
static void alarm_ring(struct alarm *a) {
    a->last_ring = now();
    if (!isim_audio_available()) return;           /* AlarmKit alarms sound in Silent Mode and Focus */
    int b = alarm_ring_buffer(a);
    if (b) isim_audio_play(b, fmax(cc_volume, 0.5), 0);
}
static void alarm_go_off(struct alarm *a) {
    a->alerting = 1;
    fprintf(stderr, "isim shell: %s %s of %s is alerting\n", a->timer ? "timer" : "alarm", a->title, a->appname);
    if (!alarm_send(a, "alert")) fprintf(stderr, "isim shell: %s is not running; the alarm's actions wait for it\n", a->appname);
    alarm_set_ui(locked || standby ? 2 : 1);
    alarm_ring(a);
}

/* ---- app → shell ---- */
static void alarm_fields(struct alarm *a, const char *f) {
    char v[64];
    field(f, 0, a->title, sizeof a->title); field(f, 1, a->stop, sizeof a->stop);
    field(f, 2, a->secondary, sizeof a->secondary); field(f, 3, a->symbol, sizeof a->symbol);
    field(f, 4, a->appname, sizeof a->appname);
    field(f, 5, v, sizeof v);
    if (sscanf(v, "%lf,%lf,%lf", &a->tint[0], &a->tint[1], &a->tint[2]) != 3) { a->tint[0] = 1; a->tint[1] = 0.62; a->tint[2] = 0.04; }
    field(f, 6, a->sound, sizeof a->sound);
    field(f, 7, v, sizeof v); a->timer = !strcmp(v, "timer");
    if (!a->stop[0]) snprintf(a->stop, sizeof a->stop, "Stop");
    if (!a->appname[0]) { struct sys_appinfo *ai = sys_info(a->path); snprintf(a->appname, sizeof a->appname, "%s", ai && ai->name[0] ? ai->name : "Alarm"); }
}
static int alarms_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (strncmp(verb, "alarm-", 6)) return 0;
    struct alarm *a = alarm_find(m->b);
    if (!strcmp(verb, "alarm-set")) {
        if (a && a->pending) {                     /* the user answered it while the app was not running */
            fprintf(stderr, "isim shell: alarm %s: delivering the %s the user chose\n", a->uuid, a->pending == 's' ? "stop" : "secondary action");
            sys_send_text(from, "alarm-action %s %s", a->pending == 's' ? "stop" : "secondary", a->uuid);
            a->pending = 0; a->alerting = 0;
            return 1;
        }
        if (!a) {
            if (nalarms >= ALARM_MAX) { fprintf(stderr, "isim shell: alarm %s refused (too many alarms)\n", m->b); return 1; }
            a = &alarms[nalarms++];
            memset(a, 0, sizeof *a);
            snprintf(a->uuid, sizeof a->uuid, "%s", m->b); snprintf(a->path, sizeof a->path, "%s", clients[from].bundle);
        }
        const char *sp = strchr(m->c, ' ');        /* "FIRE fields" */
        a->fire = atof(m->c);
        alarm_fields(a, sp ? sp + 1 : "");
        if (!a->alerting) {
            time_t ft = (time_t)a->fire; struct tm tm; localtime_r(&ft, &tm);
            fprintf(stderr, "isim shell: %s %s of %s goes off at %02d:%02d:%02d\n", a->timer ? "timer" : "alarm", a->title, a->appname, tm.tm_hour, tm.tm_min, tm.tm_sec);
        }
        alarm_redraw();
    } else if (!strcmp(verb, "alarm-clear")) {
        if (a) { fprintf(stderr, "isim shell: alarm %s cleared\n", a->title); alarm_remove(a); }
    }
    return 1;
}

/* ---- drawing ---- */
static void alarm_circle(cairo_t *c, double cx, double cy, double d, const double *rgb, double alpha) {
    cairo_new_path(c); cairo_arc(c, cx, cy, d / 2, 0, 2 * M_PI);
    cairo_set_source_rgba(c, rgb[0], rgb[1], rgb[2], alpha); cairo_fill(c);
}
static void alarm_draw_banner(cairo_t *c, struct alarm *a) {
    double w = fmin(dev.width - 16, 420), x = (dev.width - w) / 2, y = dev.has_island == 1 ? 11 : fmax(dev.safe_top - 40, 8), h = 84;
    double t = fmin(1, (now() - alarm_ui_t0) / 0.3), e = 1 - pow(1 - t, 3);
    cairo_save(c);
    cairo_translate(c, 0, -(y + h) * (1 - e));
    cairo_new_path(c); sys_round(c, x, y, w, h, 42);
    cairo_set_source_rgba(c, 0.07, 0.07, 0.08, dev.has_island == 1 ? 1 : 0.94); cairo_fill(c);
    double d = 52, cy = y + h / 2, sx = x + w - 16 - d / 2, ax = sx - d - 12;
    int second = a->secondary[0] != 0;
    double tx = x + 22, tw = (second ? ax - d / 2 : sx - d / 2) - tx - 8;
    sys_symbol(c, a->timer ? "timer" : "alarm.fill", tx + 10, y + 26, 15, a->tint[0], a->tint[1], a->tint[2]);
    sys_text(c, a->appname, tx + 24, y + 18, tw - 24, 13, PANGO_WEIGHT_NORMAL, 0, 1, 1, 1, 1, 0.6);
    sys_text(c, a->title, tx, y + 38, tw, 22, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
    if (second) {
        alarm_circle(c, ax, cy, d, a->tint, 1);
        sys_symbol(c, a->symbol[0] ? a->symbol : "repeat", ax, cy, 22, 1, 1, 1);
    }
    static const double gray[3] = { 0.36, 0.36, 0.38 };
    alarm_circle(c, sx, cy, d, gray, 1);
    sys_symbol(c, "xmark", sx, cy, 20, 1, 1, 1);
    cairo_restore(c);
    el_add("alarm-banner", a->title, (struct rectf){ x, y, w, h }, EL_ALARM, 0);
    if (second) el_add("alarm-secondary", a->secondary, (struct rectf){ ax - d / 2, cy - d / 2, d, d }, EL_ALARM, 0);
    el_add("alarm-stop", a->stop, (struct rectf){ sx - d / 2, cy - d / 2, d, d }, EL_ALARM, 0);
}
static void alarm_draw_full(cairo_t *c, struct alarm *a) {
    nels = 0;                                      /* it covers what is under it (the Lock Screen's buttons) */
    /* the wallpaper, blurred and darkened */
    cairo_surface_t *home = client_surface(0); int hw, hh; client_dims(0, &hw, &hh);
    int w = (int)dev.width, h = (int)dev.height;
    cairo_surface_t *wp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h);
    cairo_t *k = cairo_create(wp); wallpaper_draw(k, home, hw, hh); cairo_destroy(k);
    sys_paint_blurred(c, wp, w, h, 0.55);
    cairo_surface_destroy(wp); cairo_surface_destroy(home);
    double top = fmax(dev.safe_top, 20);
    char tm_s[16], date_s[64]; sys_time_strings(tm_s, sizeof tm_s, date_s, sizeof date_s);
    sys_symbol(c, a->timer ? "timer" : "alarm.fill", dev.width / 2, top + 40, 22, a->tint[0], a->tint[1], a->tint[2]);
    sys_text(c, a->title, 20, top + 62, dev.width - 40, 22, PANGO_WEIGHT_SEMIBOLD, 1, 2, 1, 1, 1, 1);
    el_add("alarm-title", a->title, (struct rectf){ 20, top + 62, dev.width - 40, 30 }, EL_NONE, 0);
    sys_text(c, a->timer ? "Timer" : tm_s, 0, top + 100, dev.width, a->timer ? 40 : 88, PANGO_WEIGHT_BOLD, 1, 1, 1, 1, 1, 0.95);
    sys_text(c, a->appname, 20, top + (a->timer ? 156 : 210), dev.width - 40, 15, PANGO_WEIGHT_MEDIUM, 1, 1, 1, 1, 1, 0.7);
    double bw = dev.width - 64, bh = 64, bx = 32, sy = dev.height - fmax(dev.safe_bottom, 20) - 40 - bh;
    if (a->secondary[0]) {                         /* the secondary button: in the alarm's tint */
        double ay = sy - bh - 16;
        cairo_new_path(c); sys_round(c, bx, ay, bw, bh, bh / 2);
        cairo_set_source_rgb(c, a->tint[0], a->tint[1], a->tint[2]); cairo_fill(c);
        sys_text(c, a->secondary, bx, ay + bh / 2 - 13, bw, 21, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
        el_add("alarm-secondary", a->secondary, (struct rectf){ bx, ay, bw, bh }, EL_ALARM, 0);
    }
    if (sys_os() >= 26) sys_glass(c, bx, sy, bw, bh, bh / 2, NULL, 1 | 2 | 4);
    cairo_new_path(c); sys_round(c, bx, sy, bw, bh, bh / 2);
    cairo_set_source_rgba(c, 1, 1, 1, 0.22); cairo_fill(c);
    sys_text(c, a->stop, bx, sy + bh / 2 - 13, bw, 21, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
    el_add("alarm-stop", a->stop, (struct rectf){ bx, sy, bw, bh }, EL_ALARM, 0);
}
static void alarms_draw(cairo_t *c) {
    struct alarm *a = alarm_main();
    if (!a) return;
    if (alarm_ui == 1) alarm_draw_banner(c, a);
    else if (alarm_ui == 2) alarm_draw_full(c, a);
}

/* ---- what the user does ---- */
static void alarm_answer(struct alarm *a, int secondary) {
    fprintf(stderr, "isim shell: %s %s (%s)\n", secondary ? "secondary action on" : "stopped", a->title, secondary ? a->secondary : a->stop);
    if (alarm_send(a, secondary ? "secondary" : "stop")) { alarm_remove(a); return; }
    a->pending = secondary ? 'x' : 's';            /* for the app's next run */
    a->alerting = 0;
    if (!alarm_main()) alarm_ui = 0;
    alarm_redraw();
}
static void alarm_tap(struct sys_el *e) {
    struct alarm *a = alarm_main();
    if (!a || !e) return;
    if (!strcmp(e->id, "alarm-stop")) alarm_answer(a, 0);
    else if (!strcmp(e->id, "alarm-secondary")) alarm_answer(a, 1);
    else if (!strcmp(e->id, "alarm-banner")) alarm_set_ui(2);
}
static struct sys_el *alarm_hit(double x, double y) {
    struct sys_el *hit = NULL;                     /* the topmost: the buttons on the banner before the banner */
    for (int k = 0; k < nels; k++) {
        struct rectf r = els[k].r;
        if (els[k].kind == EL_ALARM && x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h) hit = &els[k];
    }
    return hit;
}
/* Home while the full-screen alert is up (unlocked): it becomes the banner. 1 when Home was the alarm's. */
static int alarms_home(void) {
    if (locked || !alarm_main() || alarm_ui != 2) return 0;
    alarm_set_ui(1);
    return 1;
}
static int alarms_input(const struct isim_event *ev) {
    if (!alarm_main() || !alarm_ui) return 0;
    if (ev->type == EV_DUMP) {
        if (ov != OV_NONE && alarm_ui != 2) return 0;
        fprintf(stderr, "%s (0 0; %g x %g)\n", alarm_ui == 2 ? "IsimAlarmAlert" : "IsimAlarmBanner", dev.width, dev.height);
        if (ov != OV_NONE) return 0;                /* sys_dump lists the alert's parts with the overlay's */
        for (int k = 0; k < nels; k++) if (!strncmp(els[k].id, "alarm-", 6))
            fprintf(stderr, "  IsimAlarmButton (%g %g; %g x %g) id=%s%s%s\n", els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text[0] ? " text=" : "", els[k].text);
        return 0;
    }
    if (ev->type == EV_KEY && (ev->mods & SDL_KMOD_CTRL) && (ev->mods & SDL_KMOD_SHIFT) && (ev->key == 'h' || ev->key == 'H')) return alarms_home();
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        if (strncmp(ev->text, "alarm-", 6)) return alarm_ui == 2;
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no alarm element '%s'\n", ev->text); return 1; }
        if (ev->type == EV_ID_UP && ev->mods != 1) alarm_tap(e);
        return 1;
    }
    static int down_on_alarm;
    if (ev->type == EV_TOUCH_DOWN) { down_on_alarm = alarm_hit(ev->x, ev->y) != NULL || alarm_ui == 2; return down_on_alarm; }
    if (ev->type == EV_TOUCH_MOVE) return down_on_alarm;
    if (ev->type == EV_TOUCH_UP) {
        if (!down_on_alarm) return 0;
        down_on_alarm = 0;
        alarm_tap(alarm_hit(ev->x, ev->y));
        return 1;
    }
    return 0;
}
static void alarms_tick(void) {
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    double t = now(), wall = ts.tv_sec + ts.tv_nsec / 1e9;
    for (int k = 0; k < nalarms; k++) {
        struct alarm *a = &alarms[k];
        if (!a->alerting && !a->pending && a->fire > 0 && wall >= a->fire) alarm_go_off(a);
        else if (a->alerting && t - a->last_ring > 1.5) alarm_ring(a);
    }
    static double last;
    if (!alarms_visible()) return;
    int animating = alarm_ui == 1 && t - alarm_ui_t0 < 0.35;
    if ((animating && t - last > 0.03) || t - last > 1.0) { last = t; alarm_redraw(); }
}
