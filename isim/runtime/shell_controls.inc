/* isim shell: Focus and Control Center controls (included by shell_system.inc). Adapted: isim's own drawing of the
 * iOS 18 layout (iOS 26/27: glass), not Apple artwork.
 *
 * Focus: Do Not Disturb, Personal, Work, Sleep. The Focus module of Control Center toggles the last Focus (its icon)
 * or opens the list of Focus modes (its title; `cc-focus-modes`); Settings > Focus and the script `focus MODE|off`
 * do the same. While a Focus is on, notifications from apps it does not allow are delivered quietly (Notification
 * Center, no banner); time-sensitive ones break through when that Focus allows them; an app's Focus filter predicate
 * can quiet its own notifications. Files (<ISIM_DATA>/Library/isim/Focus/): Current (the Focus on: dnd|personal|
 * work|sleep, written here), Allowed.txt ("MODE<TAB>APP-PATH" lines) and Options.txt ("MODE<TAB>timesensitive<TAB>0|1"),
 * both written by Settings. Focus filters: the home screen runs them ("focus-changed OLD NEW"; SBFocus.m).
 *
 * Controls (iOS 18+): Control Center's edit mode ("+" at the top left): remove badges on the modules below the
 * sliders, a resize handle on app controls (1x1 <-> 2x1) and "Add a Control", which opens the gallery of system
 * controls and installed apps' ControlWidgets (listed by their widget extensions: "cc-controls PATH FILE" from the
 * home screen, a FILE line per control: control=KIND RS NAME RS TYPE RS SYMBOL RS TITLE RS VALUE RS TINT RS ON RS HINT
 * RS DESCRIPTION). Tapping an app control asks the home screen to run its action in the extension ("control-run
 * PATH US KIND US VALUE"); the new state comes back as "cc-controls". Placed controls: <ISIM_DATA>/Library/isim/
 * ControlCenter.txt ("system<TAB>NAME" | "app<TAB>PATH<TAB>KIND<TAB>small|medium" lines). The Lock Screen's two
 * buttons (LockScreenControls.txt, "... <TAB>left|right") and the Action button of iPhone 15 Pro and later
 * (ActionButton.txt) can run any of these controls.
 */

/* ======================= Focus ======================= */
enum { FOCUS_OFF, FOCUS_DND, FOCUS_PERSONAL, FOCUS_WORK, FOCUS_SLEEP, FOCUS_N };
static const char *const focus_ids[FOCUS_N] = { "off", "dnd", "personal", "work", "sleep" };
static const char *const focus_names[FOCUS_N] = { "Focus", "Do Not Disturb", "Personal", "Work", "Sleep" };
static const char *const focus_symbols[FOCUS_N] = { "moon.fill", "moon.fill", "person.fill", "person.lanyardcard.fill", "bed.double.fill" };
static const double focus_rgb[FOCUS_N][3] = { { 0.37, 0.36, 0.90 }, { 0.37, 0.36, 0.90 }, { 0.69, 0.32, 0.87 }, { 0.19, 0.69, 0.78 }, { 0.20, 0.78, 0.65 } };
static int focus_mode, focus_last = FOCUS_DND, focus_loaded;

static const char *ctl_data_path(char *out, size_t n, const char *rel) {
    const char *d = getenv("ISIM_DATA");
    if (!d || !*d) { out[0] = 0; return out; }
    snprintf(out, n, "%s/Library/isim/%s", d, rel);
    char dir[1100]; snprintf(dir, sizeof dir, "%s", out);
    for (char *p = dir + strlen(d) + 1; *p; p++) if (*p == '/') { *p = 0; mkdir(dir, 0755); *p = '/'; }
    return out;
}
static int focus_from_id(const char *s) {
    for (int k = 0; k < FOCUS_N; k++) if (!strcmp(s, focus_ids[k])) return k;
    if (!strcmp(s, "donotdisturb") || !strcmp(s, "do-not-disturb")) return FOCUS_DND;
    if (!strcmp(s, "none") || !strcmp(s, "")) return FOCUS_OFF;
    return -1;
}
static void focus_load(void) {
    if (focus_loaded) return;
    focus_loaded = 1;
    char p[1100]; ctl_data_path(p, sizeof p, "Focus/Current");
    FILE *f = p[0] ? fopen(p, "r") : NULL;
    char id[32] = "";
    if (f) { if (fscanf(f, "%31s", id) != 1) id[0] = 0; fclose(f); }
    int m = focus_from_id(id);
    focus_mode = m > 0 ? m : FOCUS_OFF;
    if (focus_mode) focus_last = focus_mode;
    cc_on[CC_FOCUS] = focus_mode != FOCUS_OFF;
}
static void focus_set(int m) {
    focus_load();
    if (m < 0 || m >= FOCUS_N) return;
    int old = focus_mode;
    focus_mode = m; cc_on[CC_FOCUS] = m != FOCUS_OFF;
    if (m) focus_last = m;
    char p[1100]; ctl_data_path(p, sizeof p, "Focus/Current");
    if (p[0]) { if (m) { FILE *f = fopen(p, "w"); if (f) { fprintf(f, "%s\n", focus_ids[m]); fclose(f); } } else unlink(p); }
    if (m) fprintf(stderr, "isim shell: Focus %s on\n", focus_names[m]);
    else if (old) fprintf(stderr, "isim shell: Focus off (was %s)\n", focus_names[old]);
    else fprintf(stderr, "isim shell: Focus off\n");
    if (old != m) sys_send_text(0, "focus-changed %s %s", focus_ids[old], focus_ids[m]);     /* Focus filters (SBFocus.m) */
    if (ov != OV_NONE) sys_draw();
}
/* a line "MODE<TAB>..." of a Focus settings file */
static int focus_file_has(const char *file, const char *mode, const char *value, int match_basename) {
    char p[1100]; ctl_data_path(p, sizeof p, file);
    FILE *f = p[0] ? fopen(p, "r") : NULL;
    if (!f) return -1;
    char line[1400]; int found = 0;
    const char *vb = strrchr(value, '/'); vb = vb ? vb + 1 : value;
    while (!found && fgets(line, sizeof line, f)) {
        line[strcspn(line, "\r\n")] = 0;
        char *tab = strchr(line, '\t'); if (!tab) continue;
        *tab = 0;
        if (strcmp(line, mode)) continue;
        const char *v = tab + 1;
        if (match_basename) { const char *b = strrchr(v, '/'); b = b ? b + 1 : v; found = !strcmp(b, vb); }
        else found = !strcmp(v, value);
    }
    fclose(f);
    return found;
}
/* does the Focus on keep this notification quiet? flags: t = time sensitive, q = the app's Focus filter rejects it */
static int focus_silences(const char *path, const char *flags, const char *title) {
    focus_load();
    if (!focus_mode) return 0;
    const char *app = strrchr(path, '/'); app = app ? app + 1 : path;
    if (flags && strchr(flags, 'q')) { fprintf(stderr, "isim shell: notification from %s silenced by its Focus filter (Focus %s): %s\n", app, focus_names[focus_mode], title); return 1; }
    if (focus_file_has("Focus/Allowed.txt", focus_ids[focus_mode], path, 1) == 1) {
        fprintf(stderr, "isim shell: notification from %s allowed during Focus %s\n", app, focus_names[focus_mode]); return 0;
    }
    if (flags && strchr(flags, 't')) {
        if (focus_file_has("Focus/Options.txt", focus_ids[focus_mode], "timesensitive\t0", 0) != 1) {
            fprintf(stderr, "isim shell: time-sensitive notification from %s breaks through Focus %s\n", app, focus_names[focus_mode]); return 0;
        }
    }
    fprintf(stderr, "isim shell: notification from %s silenced (Focus %s): %s\n", app, focus_names[focus_mode], title);
    return 1;
}

/* ======================= controls ======================= */
struct ctl_def { char kind[128], name[128], type[8], symbol[64], title[128], value[64], tint[8], hint[128], desc[192]; int on; };
struct ctl_app { char path[512]; int n; struct ctl_def d[12]; };
static struct ctl_app ctl_apps[16]; static int nctl_apps;
struct ctl_placed { int sys; char name[16], path[512], kind[128]; int medium; };
static struct ctl_placed placed[24]; static int nplaced, placed_loaded;
/* the lock screen's buttons [0 left, 1 right] and the Action button */
static struct ctl_placed lockctl[2], actionctl; static int lockctl_loaded;
static int ctl_lowpower, ctl_silent;
enum { CC_PAGE_MAIN, CC_PAGE_FOCUS, CC_PAGE_EDIT, CC_PAGE_GALLERY };
static int cc_page;
/* system controls of the gallery and the flow (the modules under the sliders) */
static const char *const sysctl_names[] = { "flashlight", "timer", "dark", "camera", "lowpower" };
static const char *const sysctl_titles[] = { "Flashlight", "Timer", "Dark Mode", "Camera", "Low Power Mode" };
static const char *const sysctl_symbols[] = { "flashlight.on.fill", "timer", "circle.lefthalf.filled", "camera.fill", "battery.25" };
#define NSYSCTL 5
static int sysctl_cc(const char *name) {                          /* the Control Center button of a system control */
    static const int ks[] = { CC_FLASHLIGHT, CC_TIMER, CC_DARK, CC_CAMERA, -1 };
    for (int k = 0; k < NSYSCTL; k++) if (!strcmp(name, sysctl_names[k])) return ks[k];
    return -1;
}
static int sysctl_index(const char *name) { for (int k = 0; k < NSYSCTL; k++) if (!strcmp(name, sysctl_names[k])) return k; return -1; }

static struct ctl_def *ctl_find(const char *path, const char *kind, struct ctl_app **app) {
    const char *pb = strrchr(path, '/'); pb = pb ? pb + 1 : path;
    for (int i = 0; i < nctl_apps; i++) {
        const char *b = strrchr(ctl_apps[i].path, '/'); b = b ? b + 1 : ctl_apps[i].path;
        if (*path && strcmp(b, pb)) continue;
        for (int k = 0; k < ctl_apps[i].n; k++) if (!strcmp(ctl_apps[i].d[k].kind, kind)) { if (app) *app = &ctl_apps[i]; return &ctl_apps[i].d[k]; }
    }
    return NULL;
}
static void ctl_parse_line(char *line, struct ctl_placed *p) {          /* "system NAME [_ SIDE]" | "app PATH KIND SIZE" */
    memset(p, 0, sizeof *p);
    char *f[5] = { 0 }; int n = 0; f[n++] = line;
    for (char *q = line; *q && n < 5; q++) if (*q == '\t') { *q = 0; f[n++] = q + 1; }
    if (!strcmp(f[0], "system") && n >= 2) { p->sys = 1; snprintf(p->name, sizeof p->name, "%s", f[1]); }
    else if (!strcmp(f[0], "app") && n >= 3) { snprintf(p->path, sizeof p->path, "%s", f[1]); snprintf(p->kind, sizeof p->kind, "%s", f[2]); p->medium = n >= 4 && !strcmp(f[3], "medium"); }
    else p->name[0] = 0, p->sys = -1;
}
static void ctl_line(FILE *f, const struct ctl_placed *p, const char *extra) {
    if (p->sys == 1) fprintf(f, "system\t%s\t\t%s\n", p->name, extra ? extra : "");
    else if (p->sys == 0 && p->kind[0]) fprintf(f, "app\t%s\t%s\t%s\n", p->path, p->kind, extra ? extra : p->medium ? "medium" : "small");
}
static void placed_load(void) {
    if (placed_loaded) return;
    placed_loaded = 1; nplaced = 0;
    char p[1100]; ctl_data_path(p, sizeof p, "ControlCenter.txt");
    FILE *f = p[0] ? fopen(p, "r") : NULL;
    if (!f) {                                                     /* the default: the four buttons under the sliders */
        for (int k = 0; k < 4; k++) { memset(&placed[nplaced], 0, sizeof *placed); placed[nplaced].sys = 1; snprintf(placed[nplaced++].name, sizeof placed->name, "%s", sysctl_names[k]); }
        return;
    }
    char line[1400];
    while (nplaced < 24 && fgets(line, sizeof line, f)) {
        line[strcspn(line, "\r\n")] = 0;
        if (!line[0]) continue;
        ctl_parse_line(line, &placed[nplaced]);
        if (placed[nplaced].sys >= 0) nplaced++;
    }
    fclose(f);
}
static void placed_save(void) {
    char p[1100]; ctl_data_path(p, sizeof p, "ControlCenter.txt");
    FILE *f = p[0] ? fopen(p, "w") : NULL;
    if (!f) return;
    for (int i = 0; i < nplaced; i++) ctl_line(f, &placed[i], NULL);
    fclose(f);
}
static void lockctl_load(void) {
    if (lockctl_loaded) return;
    lockctl_loaded = 1;
    memset(lockctl, 0, sizeof lockctl); memset(&actionctl, 0, sizeof actionctl);
    lockctl[0].sys = lockctl[1].sys = 1; snprintf(lockctl[0].name, sizeof lockctl->name, "flashlight"); snprintf(lockctl[1].name, sizeof lockctl->name, "camera");
    actionctl.sys = 1; snprintf(actionctl.name, sizeof actionctl.name, "silent");
    char p[1100], line[1400]; FILE *f;
    if ((f = fopen(ctl_data_path(p, sizeof p, "LockScreenControls.txt"), "r"))) {
        while (fgets(line, sizeof line, f)) {
            line[strcspn(line, "\r\n")] = 0;
            char *side = strrchr(line, '\t'); if (!side) continue;
            int s = !strcmp(side + 1, "right"); *side = 0;
            struct ctl_placed c; ctl_parse_line(line, &c);
            if (c.sys >= 0) lockctl[s] = c;
            else { memset(&lockctl[s], 0, sizeof lockctl[s]); lockctl[s].sys = 1; }       /* none */
        }
        fclose(f);
    }
    if ((f = fopen(ctl_data_path(p, sizeof p, "ActionButton.txt"), "r"))) {
        if (fgets(line, sizeof line, f)) { line[strcspn(line, "\r\n")] = 0; struct ctl_placed c; ctl_parse_line(line, &c); if (c.sys >= 0) actionctl = c; }
        fclose(f);
    }
}
static void lockctl_save(void) {
    char p[1100]; FILE *f;
    if ((f = fopen(ctl_data_path(p, sizeof p, "LockScreenControls.txt"), "w"))) {
        for (int s = 0; s < 2; s++) {
            if (lockctl[s].sys == 1 && !lockctl[s].name[0]) fprintf(f, "none\t%s\n", s ? "right" : "left");
            else ctl_line(f, &lockctl[s], s ? "right" : "left");
        }
        fclose(f);
    }
    if ((f = fopen(ctl_data_path(p, sizeof p, "ActionButton.txt"), "w"))) { ctl_line(f, &actionctl, ""); fclose(f); }
}
/* an app's controls as its widget extension described them */
static void ctl_load_app(const char *path, const char *file) {
    struct ctl_app *a = NULL;
    for (int i = 0; i < nctl_apps; i++) if (!strcmp(ctl_apps[i].path, path)) a = &ctl_apps[i];
    if (!a) { if (nctl_apps >= 16) return; a = &ctl_apps[nctl_apps++]; memset(a, 0, sizeof *a); snprintf(a->path, sizeof a->path, "%s", path); }
    FILE *f = fopen(file, "r");
    if (!f) return;
    a->n = 0;
    char line[2048];
    while (a->n < 12 && fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        if (strncmp(line, "control=", 8)) continue;
        struct ctl_def *d = &a->d[a->n++]; memset(d, 0, sizeof *d);
        char *fl[10] = { 0 }; int n = 0; fl[n++] = line + 8;
        for (char *q = line + 8; *q && n < 10; q++) if (*q == '\x1e') { *q = 0; fl[n++] = q + 1; }
        #define CP(dst, i) snprintf(d->dst, sizeof d->dst, "%s", fl[i] ? fl[i] : "")
        CP(kind, 0); CP(name, 1); CP(type, 2); CP(symbol, 3); CP(title, 4); CP(value, 5); CP(tint, 6); CP(hint, 8); CP(desc, 9);
        #undef CP
        d->on = fl[7] && fl[7][0] == '1';
    }
    fclose(f);
    fprintf(stderr, "isim shell: %d control(s) from %s\n", a->n, path);
    if (ov != OV_NONE) sys_draw();
}

static void cc_toggle(int k);
static void ctl_tint(const char *hex, double *rgb) {
    unsigned r, g, b;
    if (hex && sscanf(hex, "#%02x%02x%02x", &r, &g, &b) == 3) { rgb[0] = r / 255.0; rgb[1] = g / 255.0; rgb[2] = b / 255.0; }
    else { rgb[0] = 0; rgb[1] = 0.48; rgb[2] = 1; }
}
static const char *app_name_of(const char *path) {
    struct sys_appinfo *ai = sys_info(path);
    if (ai && ai->name[0]) return ai->name;
    const char *b = strrchr(path, '/'); return b ? b + 1 : path;
}
/* run a control: an app's in its widget extension, a system one here. from: where it was run (for the log) */
static void ctl_run(const struct ctl_placed *p, const char *from) {
    if (p->sys == 1) {
        if (!p->name[0]) return;
        int k = sysctl_cc(p->name);
        if (k >= 0) { fprintf(stderr, "isim shell: %s runs %s\n", from, p->name); cc_toggle(k); return; }
        if (!strcmp(p->name, "lowpower")) {
            ctl_lowpower = !ctl_lowpower;
            char f[1100]; ctl_data_path(f, sizeof f, "LowPowerMode");
            if (ctl_lowpower) { FILE *fp = fopen(f, "w"); if (fp) fclose(fp); } else unlink(f);
            fprintf(stderr, "isim shell: Low Power Mode %s\n", ctl_lowpower ? "on" : "off");
            for (int i = 0; i < nclients; i++) if (clients[i].alive) sys_send_text(i, "power-state %s", ctl_lowpower ? "low" : "normal");
        } else if (!strcmp(p->name, "silent")) {
            ctl_silent = !ctl_silent;
            fprintf(stderr, "isim shell: Silent Mode %s\n", ctl_silent ? "on" : "off");
        } else if (!strcmp(p->name, "focus")) {
            focus_load(); focus_set(focus_mode ? FOCUS_OFF : focus_last);
        }
        if (ov != OV_NONE) sys_draw();
        return;
    }
    struct ctl_def *d = ctl_find(p->path, p->kind, NULL);
    if (!d) { fprintf(stderr, "isim shell: control %s is not available (its app's widget extension did not list it)\n", p->kind); return; }
    int toggle = !strcmp(d->type, "toggle"), nv = toggle ? !d->on : -1;
    fprintf(stderr, "isim shell: %s runs control %s (%s)%s%s%s\n", from, d->kind, app_name_of(p->path), toggle ? (nv ? ": turn on" : ": turn off") : "",
            d->hint[0] ? " — " : "", d->hint);
    if (toggle) {                                                   /* like iOS: the new state at once, then the extension's */
        d->on = nv;
        if (!strcmp(d->value, "On") || !strcmp(d->value, "Off")) snprintf(d->value, sizeof d->value, "%s", nv ? "On" : "Off");
    }
    sys_send_text(0, "control-run %s\x1f%s\x1f%d", p->path, d->kind, nv);
    if (ov != OV_NONE) sys_draw();
}

/* ---- drawing ---- */
enum { X_FOCUS_LIST = 1, X_FOCUS_ROW, X_BACK, X_EDIT, X_EDIT_DONE, X_ADD, X_GALLERY_ITEM, X_GALLERY_CLOSE, X_REMOVE, X_RESIZE, X_MODULE, X_LOCK };
#define XARG(a, i) ((a) * 1000 + (i))
/* a gallery entry: index into this table, rebuilt while drawing the gallery */
static struct { int sys; char name[16], path[512], kind[128]; } gal[64]; static int ngal;

static void ctl_glyph_button(cairo_t *c, struct rectf r, int on, const double *tint, const char *symbol, int circle) {
    int os = sys_os();
    double rad = circle ? r.w / 2 : os >= 26 ? r.h / 2 : r.h * 0.42;
    if (!on && os >= 26) sys_glass(c, r.x, r.y, r.w, r.h, rad, NULL, 1 | 2 | 4);
    else {
        cairo_new_path(c);
        if (circle) cairo_arc(c, r.x + r.w / 2, r.y + r.h / 2, r.w / 2, 0, 2 * M_PI); else sys_round(c, r.x, r.y, r.w, r.h, rad);
        if (on) cairo_set_source_rgb(c, 1, 1, 1); else cairo_set_source_rgba(c, 1, 1, 1, 0.18);
        cairo_fill(c);
    }
    double fr = on ? tint[0] : 1, fg = on ? tint[1] : 1, fb = on ? tint[2] : 1;
    double cx = circle ? r.x + r.w / 2 : r.x + r.h / 2 + 4;
    sys_symbol(c, symbol, cx, r.y + r.h / 2, circle ? 24 : 22, fr, fg, fb);
}
/* one module of the flow (system or app control) */
static void ctl_draw_module(cairo_t *c, int i, struct rectf r) {
    struct ctl_placed *p = &placed[i];
    char id[200];
    if (p->sys == 1) {
        int k = sysctl_cc(p->name);
        if (k >= 0) { cc_button(c, k, r, 0); return; }
        int s = sysctl_index(p->name);
        double yellow[3] = { 1.0, 0.8, 0.0 };
        ctl_glyph_button(c, r, ctl_lowpower, yellow, s >= 0 ? sysctl_symbols[s] : "circle", sys_os() >= 18);
        snprintf(id, sizeof id, "cc-%s", p->name);
        el_add(id, ctl_lowpower ? "on" : "off", r, EL_CC_X, XARG(X_MODULE, i));
        return;
    }
    struct ctl_def *d = ctl_find(p->path, p->kind, NULL);
    double tint[3]; ctl_tint(d ? d->tint : NULL, tint);
    int on = d && !strcmp(d->type, "toggle") && d->on;
    const char *sym = d && d->symbol[0] ? d->symbol : "questionmark";
    if (p->medium) {
        ctl_glyph_button(c, r, on, tint, sym, 0);
        double fg = on ? 0.1 : 1;
        sys_text(c, d ? d->title : p->kind, r.x + r.h - 2, r.y + r.h / 2 - 19, r.w - r.h - 6, 14, PANGO_WEIGHT_SEMIBOLD, 0, 1, fg, fg, fg, 1);
        sys_text(c, d ? d->value : "", r.x + r.h - 2, r.y + r.h / 2 + 1, r.w - r.h - 6, 13, PANGO_WEIGHT_NORMAL, 0, 1, fg, fg, fg, 0.75);
    } else ctl_glyph_button(c, r, on, tint, sym, sys_os() >= 18);
    char text[260]; snprintf(text, sizeof text, "%s%s%s", d ? d->title : p->kind, d && d->value[0] ? ": " : "", d ? d->value : "");
    snprintf(id, sizeof id, "cc-control-%s", p->kind);
    el_add(id, d ? text : "unavailable", r, EL_CC_X, XARG(X_MODULE, i));
}
/* the modules under the sliders: 1x1 or 2x1 cells, four columns. Returns the bottom edge. */
static double ctl_draw_flow(cairo_t *c, double m, double y, double u, double gap) {
    placed_load();
    int col = 0, os = sys_os();
    double bottom = y;
    struct rectf rs[24];
    for (int i = 0; i < nplaced; i++) {
        struct ctl_placed *p = &placed[i];
        if (p->sys == 0 && os < 18) { rs[i] = (struct rectf){ -1000, -1000, 0, 0 }; continue; }     /* ControlWidget: iOS 18+ */
        int w = p->sys == 0 && p->medium ? 2 : 1;
        if (col + w > 4) { col = 0; y += u + gap; }
        rs[i] = (struct rectf){ m + col * (u + gap), y, w == 2 ? 2 * u + gap : u, u };
        ctl_draw_module(c, i, rs[i]);
        bottom = y + u;
        col += w; if (col >= 4) { col = 0; y += u + gap; }
    }
    if (cc_page == CC_PAGE_EDIT) {                                  /* edit mode: remove badges, resize handles, "Add a Control" */
        el_add("cc-edit-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_CC_X, XARG(X_EDIT_DONE, 0));
        for (int i = 0; i < nplaced; i++) {
            struct rectf r = rs[i]; if (r.w <= 0) continue;
            struct rectf b = { r.x - 6, r.y - 6, 24, 24 };
            cairo_new_path(c); cairo_arc(c, b.x + 12, b.y + 12, 12, 0, 2 * M_PI); cairo_set_source_rgb(c, 0.55, 0.55, 0.58); cairo_fill(c);
            cairo_set_source_rgb(c, 0, 0, 0); cairo_rectangle(c, b.x + 6, b.y + 11, 12, 2.4); cairo_fill(c);
            char id[200]; snprintf(id, sizeof id, "cc-remove-%s", placed[i].sys == 1 ? placed[i].name : placed[i].kind);
            el_add(id, "Remove", b, EL_CC_X, XARG(X_REMOVE, i));
            if (placed[i].sys == 0) {                                /* the resize handle (bottom right) */
                struct rectf h = { r.x + r.w - 20, r.y + r.h - 20, 22, 22 };
                cairo_save(c); cairo_set_source_rgb(c, 1, 1, 1); cairo_set_line_width(c, 3); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND);
                cairo_new_path(c); cairo_arc(c, h.x + 2, h.y + 2, 16, 0, M_PI / 2); cairo_stroke(c); cairo_restore(c);
                snprintf(id, sizeof id, "cc-resize-%s", placed[i].kind);
                el_add(id, placed[i].medium ? "medium" : "small", h, EL_CC_X, XARG(X_RESIZE, i));
            }
        }
        double bw = 190, bh = 44;
        struct rectf add = { (dev.width - bw) / 2, fmin(bottom + gap + 20, dev.height - dev.safe_bottom - bh - 16), bw, bh };
        if (os >= 26) sys_glass(c, add.x, add.y, bw, bh, bh / 2, NULL, 1 | 2 | 4);
        else { cairo_new_path(c); sys_round(c, add.x, add.y, bw, bh, bh / 2); cairo_set_source_rgba(c, 1, 1, 1, 0.22); cairo_fill(c); }
        sys_text(c, "Add a Control", add.x, add.y + 12, bw, 16, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
        el_add("cc-add-control", "Add a Control", add, EL_CC_X, XARG(X_ADD, 0));
    }
    return bottom;
}
/* the Focus module (2x1): icon (toggles), title (opens the list) */
static void focus_draw_module(cairo_t *c, struct rectf r, double fg) {
    focus_load();
    int m = focus_mode;
    sys_symbol(c, focus_symbols[m ? m : FOCUS_DND], r.x + 26, r.y + r.h / 2, 20, fg, fg, fg);
    sys_text(c, m ? focus_names[m] : "Focus", r.x + 46, r.y + r.h / 2 - (m ? 18 : 10), r.w - 52, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, fg, fg, fg, 1);
    if (m) sys_text(c, "On", r.x + 46, r.y + r.h / 2 + 1, r.w - 52, 13, PANGO_WEIGHT_NORMAL, 0, 1, fg, fg, fg, 0.8);
}
static void focus_register_module(struct rectf r) {
    el_add("cc-focus-modes", focus_mode ? focus_names[focus_mode] : "Focus", (struct rectf){ r.x + 46, r.y, r.w - 46, r.h }, EL_CC_X, XARG(X_FOCUS_LIST, 0));
}
/* the expanded Focus module: the modes */
static void focus_draw_list(cairo_t *c) {
    focus_load();
    double m = dev.width >= 700 ? (dev.width - 420) / 2 : 30, w = dev.width - 2 * m, h = 62, gap = 10;
    double y = fmax(dev.safe_top, 20) + 120;
    int os = sys_os();
    el_add("cc-page-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_CC_X, XARG(X_BACK, 0));
    for (int k = FOCUS_DND; k < FOCUS_N; k++) {
        struct rectf r = { m, y, w, h };
        int on = focus_mode == k;
        double rad = os >= 26 ? h / 2 : os >= 18 ? 24 : 16;
        if (on) { cairo_new_path(c); sys_round(c, r.x, r.y, r.w, r.h, rad); cairo_set_source_rgb(c, 1, 1, 1); cairo_fill(c); }
        else sys_platter(c, r.x, r.y, r.w, r.h, rad, 0.18);
        double cr_ = 19, cx = r.x + 14 + cr_, cy = r.y + h / 2;
        cairo_new_path(c); cairo_arc(c, cx, cy, cr_, 0, 2 * M_PI);
        if (on) cairo_set_source_rgb(c, focus_rgb[k][0], focus_rgb[k][1], focus_rgb[k][2]); else cairo_set_source_rgba(c, 1, 1, 1, 0.22);
        cairo_fill(c);
        sys_symbol(c, focus_symbols[k], cx, cy, 20, 1, 1, 1);
        double fg = on ? 0.05 : 1;
        sys_text(c, focus_names[k], cx + cr_ + 14, r.y + (on ? 12 : 20), w - 90, 17, PANGO_WEIGHT_SEMIBOLD, 0, 1, fg, fg, fg, 1);
        if (on) sys_text(c, "On", cx + cr_ + 14, r.y + 34, w - 90, 13, PANGO_WEIGHT_NORMAL, 0, 1, 0.35, 0.35, 0.37, 1);
        sys_text(c, "•••", r.x + w - 50, r.y + 20, 36, 15, PANGO_WEIGHT_BOLD, 1, 1, fg, fg, fg, 0.7);
        char id[64]; snprintf(id, sizeof id, "cc-focus-%s", focus_ids[k]);
        el_add(id, on ? "on" : "off", r, EL_CC_X, XARG(X_FOCUS_ROW, k));
        y += h + gap;
    }
}
/* the "Add a Control" gallery */
static void ctl_gallery_tile(cairo_t *c, double x, double y, double d, const char *symbol, const char *title, const double *tint, const char *id, int gi) {
    ctl_glyph_button(c, (struct rectf){ x, y, d, d }, 0, tint, symbol, 1);
    sys_text(c, title, x - 10, y + d + 6, d + 20, 12, PANGO_WEIGHT_NORMAL, 1, 2, 1, 1, 1, 0.9);
    el_add(id, title, (struct rectf){ x - 6, y - 4, d + 12, d + 40 }, EL_CC_X, XARG(X_GALLERY_ITEM, gi));
}
static void ctl_draw_gallery(cairo_t *c) {
    double top = fmax(dev.safe_top, 20) + 30, w = fmin(dev.width, 520), x = (dev.width - w) / 2;
    int os = sys_os();
    el_add("cc-page-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_CC_X, XARG(X_GALLERY_CLOSE, 0));
    struct rectf sheet = { x, top, w, dev.height - top + 40 };
    if (os >= 26) {                                                /* glass, frosted dark enough to read over Control Center */
        sys_glass(c, sheet.x + 8, sheet.y, sheet.w - 16, sheet.h, 38, NULL, 1 | 2 | 4);
        cairo_new_path(c); sys_round(c, sheet.x + 8, sheet.y, sheet.w - 16, sheet.h, 38); cairo_set_source_rgba(c, 0.07, 0.07, 0.08, 0.78); cairo_fill(c);
    }
    else { cairo_new_path(c); sys_round(c, sheet.x, sheet.y, sheet.w, sheet.h, 38); cairo_set_source_rgba(c, 0.11, 0.11, 0.12, 0.97); cairo_fill(c); }
    el_add("cc-gallery", "Controls", sheet, EL_NONE, 0);
    cairo_set_source_rgba(c, 1, 1, 1, 0.3); sys_round(c, dev.width / 2 - 18, top + 6, 36, 5, 2.5); cairo_fill(c);
    /* the search field (a placeholder: the gallery is short enough to scan) and the close button */
    struct rectf field = { x + 20, top + 24, w - 40 - 46, 38 }, close = { x + w - 20 - 38, top + 24, 38, 38 };
    cairo_new_path(c); sys_round(c, field.x, field.y, field.w, field.h, 19); cairo_set_source_rgba(c, 1, 1, 1, 0.12); cairo_fill(c);
    sys_symbol(c, "magnifyingglass", field.x + 20, field.y + 19, 16, 0.6, 0.6, 0.62);
    sys_text(c, "Search Controls", field.x + 36, field.y + 10, field.w - 44, 16, PANGO_WEIGHT_NORMAL, 0, 1, 0.6, 0.6, 0.62, 1);
    cairo_new_path(c); cairo_arc(c, close.x + 19, close.y + 19, 19, 0, 2 * M_PI); cairo_set_source_rgba(c, 1, 1, 1, 0.14); cairo_fill(c);
    cairo_save(c); cairo_set_source_rgb(c, 0.8, 0.8, 0.82); cairo_set_line_width(c, 2.2); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND);
    cairo_move_to(c, close.x + 13, close.y + 13); cairo_line_to(c, close.x + 25, close.y + 25); cairo_move_to(c, close.x + 25, close.y + 13); cairo_line_to(c, close.x + 13, close.y + 25); cairo_stroke(c);
    cairo_restore(c);
    el_add("cc-gallery-close", "Close", close, EL_CC_X, XARG(X_GALLERY_CLOSE, 0));
    double y = top + 84, d = fmin(64, (w - 40 - 3 * 24) / 4), colw = (w - 40) / 4;
    ngal = 0;
    placed_load();
    double blue[3] = { 0, 0.48, 1 };
    /* installed apps' controls, by app */
    for (int a = 0; a < nctl_apps && y < dev.height - 80; a++) {
        if (!ctl_apps[a].n) continue;
        sys_text(c, app_name_of(ctl_apps[a].path), x + 24, y, w - 48, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 0.65);
        y += 28;
        for (int k = 0; k < ctl_apps[a].n && ngal < 64; k++) {
            struct ctl_def *df = &ctl_apps[a].d[k];
            if (k && k % 4 == 0) y += d + 52;
            double tx = x + 20 + (k % 4) * colw + (colw - d) / 2;
            gal[ngal].sys = 0; snprintf(gal[ngal].path, sizeof gal->path, "%s", ctl_apps[a].path); snprintf(gal[ngal].kind, sizeof gal->kind, "%s", df->kind);
            char id[200]; snprintf(id, sizeof id, "cc-gallery-%s", df->kind);
            double tint[3]; ctl_tint(df->tint, tint);
            ctl_gallery_tile(c, tx, y, d, df->symbol[0] ? df->symbol : "questionmark", df->name[0] ? df->name : df->title, tint, id, ngal++);
        }
        y += d + 60;
    }
    /* system controls not in Control Center */
    sys_text(c, "Controls", x + 24, y, w - 48, 15, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 0.65);
    y += 28;
    int col = 0;
    for (int s = 0; s < NSYSCTL && ngal < 64; s++) {
        int there = 0;
        for (int i = 0; i < nplaced; i++) if (placed[i].sys == 1 && !strcmp(placed[i].name, sysctl_names[s])) there = 1;
        if (there) continue;
        if (col == 4) { col = 0; y += d + 52; }
        double tx = x + 20 + col * colw + (colw - d) / 2;
        gal[ngal].sys = 1; snprintf(gal[ngal].name, sizeof gal->name, "%s", sysctl_names[s]);
        char id[64]; snprintf(id, sizeof id, "cc-gallery-system-%s", sysctl_names[s]);
        ctl_gallery_tile(c, tx, y, d, sysctl_symbols[s], sysctl_titles[s], blue, id, ngal++);
        col++;
    }
}
/* Lock Screen buttons */
static void lockctl_draw(cairo_t *c, struct rectf bl, struct rectf br) {
    lockctl_load();
    struct rectf rs[2] = { bl, br };
    for (int s = 0; s < 2; s++) {
        struct ctl_placed *p = &lockctl[s];
        struct rectf r = rs[s];
        const char *sym = NULL, *text = "";
        int on = 0;
        if (p->sys == 1) {
            int k = sysctl_cc(p->name), si = sysctl_index(p->name);
            if (!p->name[0]) continue;
            sym = !strcmp(p->name, "flashlight") ? (cc_on[CC_FLASHLIGHT] ? "flashlight.on.fill" : "flashlight.off.fill") : si >= 0 ? sysctl_symbols[si] : "circle";
            on = k >= 0 ? cc_on[k] : !strcmp(p->name, "lowpower") ? ctl_lowpower : 0;
            text = si >= 0 ? sysctl_titles[si] : p->name;
        } else {
            struct ctl_def *d = ctl_find(p->path, p->kind, NULL);
            sym = d && d->symbol[0] ? d->symbol : "questionmark";
            on = d && !strcmp(d->type, "toggle") && d->on;
            text = d ? d->title : p->kind;
        }
        if (on) { cairo_new_path(c); cairo_arc(c, r.x + 25, r.y + 25, 25, 0, 2 * M_PI); cairo_set_source_rgb(c, 1, 1, 1); cairo_fill(c); }
        sys_symbol(c, sym, r.x + 25, r.y + 25, 20, on ? 0.1 : 1, on ? 0.1 : 1, on ? 0.1 : 1);
        char t[200]; snprintf(t, sizeof t, "%s%s", text, on ? ": on" : "");
        el_add(s ? "lock-control-right" : "lock-control-left", t, r, EL_CC_X, XARG(X_LOCK, s));
    }
}
/* the Focus on the Lock Screen: a capsule under the clock */
static int focus_draw_lock(cairo_t *c, double y) {               /* 1 when a Focus pill was drawn */
    focus_load();
    if (!focus_mode) return 0;
    double w = 170, h = 30, x = (dev.width - w) / 2;
    cairo_new_path(c); sys_round(c, x, y, w, h, h / 2); cairo_set_source_rgba(c, 0, 0, 0, 0.28); cairo_fill(c);
    sys_symbol(c, focus_symbols[focus_mode], x + 20, y + h / 2, 15, 1, 1, 1);
    sys_text(c, focus_names[focus_mode], x + 34, y + 6, w - 42, 14, PANGO_WEIGHT_SEMIBOLD, 0, 1, 1, 1, 1, 1);
    el_add("lock-focus", focus_names[focus_mode], (struct rectf){ x, y, w, h }, EL_NONE, 0);
    return 1;
}

/* ---- input ---- */
static void ctl_tap(struct sys_el *e) {
    int a = e->arg / 1000, i = e->arg % 1000;
    switch (a) {
    case X_FOCUS_LIST: cc_page = CC_PAGE_FOCUS; fprintf(stderr, "isim shell: Focus modes\n"); break;
    case X_FOCUS_ROW: focus_set(focus_mode == i ? FOCUS_OFF : i); break;
    case X_BACK: cc_page = CC_PAGE_MAIN; break;
    case X_EDIT:
        if (sys_os() < 18) break;
        cc_page = cc_page == CC_PAGE_EDIT ? CC_PAGE_MAIN : CC_PAGE_EDIT;
        fprintf(stderr, "isim shell: Control Center %s\n", cc_page == CC_PAGE_EDIT ? "edit mode" : "edit mode ended");
        break;
    case X_EDIT_DONE: cc_page = CC_PAGE_MAIN; fprintf(stderr, "isim shell: Control Center edit mode ended\n"); break;
    case X_ADD: {
        cc_page = CC_PAGE_GALLERY;
        int n = 0; for (int k = 0; k < nctl_apps; k++) n += ctl_apps[k].n;
        fprintf(stderr, "isim shell: Control Center gallery (%d app control%s)\n", n, n == 1 ? "" : "s");
        sys_send_text(0, "control-reload \x1f*");                    /* fresh values from the extensions */
        break; }
    case X_GALLERY_CLOSE: cc_page = CC_PAGE_EDIT; break;
    case X_GALLERY_ITEM: {
        if (i >= ngal) break;
        placed_load();
        if (nplaced >= 24) break;
        struct ctl_placed *p = &placed[nplaced]; memset(p, 0, sizeof *p);
        p->sys = gal[i].sys;
        if (p->sys) snprintf(p->name, sizeof p->name, "%s", gal[i].name);
        else { snprintf(p->path, sizeof p->path, "%s", gal[i].path); snprintf(p->kind, sizeof p->kind, "%s", gal[i].kind); }
        nplaced++; placed_save();
        struct ctl_def *d = p->sys ? NULL : ctl_find(p->path, p->kind, NULL);
        fprintf(stderr, "isim shell: Control Center: added control %s%s%s%s\n", p->sys ? p->name : p->kind, p->sys ? "" : " (", p->sys ? "" : app_name_of(p->path), p->sys ? "" : ")");
        if (d) fprintf(stderr, "isim shell: control %s: %s %s\n", d->kind, d->title, d->value);
        cc_page = CC_PAGE_EDIT;
        break; }
    case X_REMOVE:
        if (i < nplaced) {
            fprintf(stderr, "isim shell: Control Center: removed control %s\n", placed[i].sys ? placed[i].name : placed[i].kind);
            memmove(&placed[i], &placed[i + 1], (nplaced - i - 1) * sizeof *placed); nplaced--; placed_save();
        }
        break;
    case X_RESIZE:
        if (i < nplaced) { placed[i].medium = !placed[i].medium; placed_save(); fprintf(stderr, "isim shell: control %s is %s\n", placed[i].kind, placed[i].medium ? "medium (2x1)" : "small (1x1)"); }
        break;
    case X_MODULE: if (cc_page != CC_PAGE_EDIT && i < nplaced) ctl_run(&placed[i], "Control Center"); break;
    case X_LOCK: lockctl_load(); ctl_run(&lockctl[i], i ? "Lock Screen (right)" : "Lock Screen (left)"); break;
    }
    sys_draw();
}
/* a placed control from a script argument: system NAME, an app control KIND, or none */
static int ctl_from_arg(const char *arg, struct ctl_placed *out) {
    memset(out, 0, sizeof *out);
    if (!strcmp(arg, "none")) { out->sys = 1; return 1; }
    if (sysctl_index(arg) >= 0 || !strcmp(arg, "silent") || !strcmp(arg, "focus")) { out->sys = 1; snprintf(out->name, sizeof out->name, "%s", arg); return 1; }
    struct ctl_app *a = NULL;
    struct ctl_def *d = ctl_find("", arg, &a);
    if (!d) { fprintf(stderr, "isim shell: no control '%s' (system: flashlight timer dark camera lowpower silent focus; or an app control's kind)\n", arg); return 0; }
    snprintf(out->path, sizeof out->path, "%s", a->path); snprintf(out->kind, sizeof out->kind, "%s", d->kind);
    return 1;
}
static int has_action_button(void) {
    return !strncmp(dev.name, "iPhone 15 Pro", 13) || !strncmp(dev.name, "iPhone 16", 9) || !strncmp(dev.name, "iPhone 17", 9) || !strncmp(dev.name, "iPhone Air", 10);
}
/* script commands: focus, silent, actionbutton, lockcontrol */
static int ctl_command(const char *verb, const char *args) {
    if (!strcmp(verb, "focus")) {
        focus_load();
        if (!*args) { fprintf(stderr, "isim shell: Focus %s\n", focus_mode ? focus_names[focus_mode] : "off"); return 1; }
        int m = focus_from_id(args);
        if (m < 0) { fprintf(stderr, "isim shell: focus: unknown Focus '%s' (dnd, personal, work, sleep, off)\n", args); return 1; }
        focus_set(m);
        return 1;
    }
    if (!strcmp(verb, "silent")) {                         /* the Ring/Silent switch (or the Action button's Silent Mode) */
        int on = !strcmp(args, "on") ? 1 : !strcmp(args, "off") ? 0 : -1;
        if (on >= 0 && on != ctl_silent) { ctl_silent = on; if (ov != OV_NONE) sys_draw(); }
        fprintf(stderr, "isim shell: Silent Mode %s\n", ctl_silent ? "on" : "off");
        return 1;
    }
    if (!strcmp(verb, "actionbutton")) {
        if (!has_action_button()) { fprintf(stderr, "isim shell: %s has no Action button\n", dev.name); return 1; }
        lockctl_load();
        if (!strncmp(args, "assign ", 7)) {
            struct ctl_placed p;
            if (!ctl_from_arg(args + 7, &p)) return 1;
            actionctl = p; lockctl_save();
            fprintf(stderr, "isim shell: Action button: %s\n", p.sys ? (p.name[0] ? p.name : "none") : p.kind);
            return 1;
        }
        if (actionctl.sys == 1 && !actionctl.name[0]) { fprintf(stderr, "isim shell: Action button: no action\n"); return 1; }
        ctl_run(&actionctl, "Action button");
        return 1;
    }
    if (!strcmp(verb, "lockcontrol")) {
        char side[16] = ""; int n = 0;
        sscanf(args, "%15s%n", side, &n);
        const char *what = args + n; while (*what == ' ') what++;
        int s = !strcmp(side, "right") ? 1 : !strcmp(side, "left") ? 0 : -1;
        if (s < 0 || !*what) { fprintf(stderr, "isim shell: lockcontrol left|right CONTROL\n"); return 1; }
        lockctl_load();
        struct ctl_placed p;
        if (!ctl_from_arg(what, &p)) return 1;
        lockctl[s] = p; lockctl_save();
        fprintf(stderr, "isim shell: Lock Screen %s button: %s\n", side, p.sys ? (p.name[0] ? p.name : "none") : p.kind);
        if (ov != OV_NONE) sys_draw();
        return 1;
    }
    return 0;
}
/* system messages about Focus and controls; returns 1 when handled */
static int ctl_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (!strcmp(verb, "cc-controls")) { ctl_load_app(m->b, m->c); return 1; }        /* the home screen: an app's controls */
    if (!strcmp(verb, "control-reload")) {                                         /* ControlCenter.reloadControls (an app or its extension) */
        sys_send_text(0, "control-reload %s\x1f%s", from > 0 ? clients[from].bundle : "", m->c);
        return 1;
    }
    if (!strcmp(verb, "focus-set")) { int f = focus_from_id(m->b); if (f >= 0) focus_set(f); return 1; }   /* Settings */
    if (!strcmp(verb, "focus-config")) { focus_load(); sys_send_text(0, "focus-apply %s", focus_ids[focus_mode]); return 1; }
    if (!strcmp(verb, "focus-filter")) {                                           /* the home screen runs a Focus filter in an app */
        char exe[512], side[512]; field(m->c, 0, exe, sizeof exe); field(m->c, 1, side, sizeof side);
        int i = shell_find(m->b);
        if (i >= 0) sys_send_text(i, "focus-filter %s", side);
        else { char url[600]; snprintf(url, sizeof url, "isim-focus-filter:%s", side); sys_launch_background(m->b, exe, url); }
        return 1;
    }
    return 0;
}
