/* isim shell: the Siri UI (included by shell_system.inc). Adapted: isim's drawing of iOS's compact Siri.
 *
 * The home screen decides what Siri says (system/SpringBoard/SBSiri.m) and sends "siri-ui FILE": a sidecar of
 * key=value lines (mode = listening | working | value | choice | confirm | result | hidden; source = siri |
 * shortcuts | spotlight | ...; heard, text, detail, app, appname, snippet (PNG), option = TITLE\x1eSUBTITLE (one per
 * line), action, cancel, input, placeholder). The shell draws it over whatever is on screen and sends taps and typed
 * text back: "siri-answer option N | confirm | cancel | dismiss | text TEXT".
 *   iOS 17: the orb at the bottom; iOS 18+: the glowing edge around the screen. Siri's answers and questions are on a
 *   card at the top (a light material platter; Liquid Glass from iOS 26). Runs from the Shortcuts app or Spotlight show
 *   the card alone. Type to Siri: a text field at the bottom while Siri listens or asks for a value (`type TEXT;
 *   key return`, or `siri TEXT`).
 * Script ids: siri-card (text: what Siri says), siri-heard, siri-detail, siri-snippet, siri-option-N, siri-confirm,
 * siri-cancel, siri-field, siri-orb (iOS 17) / siri-glow (iOS 18+), siri-background (tap: dismiss). */

static struct {
    int on, input, nopt;
    char mode[16], source[24], heard[512], text[1024], detail[1024], app[512], appname[128], snippet[512], action[64], cancel[64], placeholder[64];
    char opt[8][2][192];
    char typed[512];
    double t0;
    cairo_surface_t *snip;
} siri;

static int siri_visible(void) { return siri.on; }
static void siri_unesc(char *s) { for (; *s; s++) if (*s == '\x1e') *s = '\n'; }
static void siri_load(const char *file) {
    FILE *f = fopen(file, "r");
    if (!f) return;
    int was = siri.on;
    char keep_typed[512]; snprintf(keep_typed, sizeof keep_typed, "%s", siri.typed);
    if (siri.snip) { cairo_surface_destroy(siri.snip); siri.snip = NULL; }
    memset(siri.heard, 0, sizeof siri.heard); siri.text[0] = siri.detail[0] = siri.app[0] = siri.appname[0] = siri.snippet[0] = 0;
    siri.action[0] = siri.cancel[0] = siri.placeholder[0] = 0; siri.input = 0; siri.nopt = 0;
    char line[2048];
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        if (!strcmp(line, "mode")) snprintf(siri.mode, sizeof siri.mode, "%s", v);
        else if (!strcmp(line, "source")) snprintf(siri.source, sizeof siri.source, "%s", v);
        else if (!strcmp(line, "heard")) snprintf(siri.heard, sizeof siri.heard, "%s", v);
        else if (!strcmp(line, "text")) { snprintf(siri.text, sizeof siri.text, "%s", v); siri_unesc(siri.text); }
        else if (!strcmp(line, "detail")) { snprintf(siri.detail, sizeof siri.detail, "%s", v); siri_unesc(siri.detail); }
        else if (!strcmp(line, "app")) snprintf(siri.app, sizeof siri.app, "%s", v);
        else if (!strcmp(line, "appname")) snprintf(siri.appname, sizeof siri.appname, "%s", v);
        else if (!strcmp(line, "snippet")) snprintf(siri.snippet, sizeof siri.snippet, "%s", v);
        else if (!strcmp(line, "action")) snprintf(siri.action, sizeof siri.action, "%s", v);
        else if (!strcmp(line, "cancel")) snprintf(siri.cancel, sizeof siri.cancel, "%s", v);
        else if (!strcmp(line, "placeholder")) snprintf(siri.placeholder, sizeof siri.placeholder, "%s", v);
        else if (!strcmp(line, "input")) siri.input = atoi(v);
        else if (!strcmp(line, "option") && siri.nopt < 8) {
            char *sub = strchr(v, '\x1e'); if (sub) *sub++ = 0;
            snprintf(siri.opt[siri.nopt][0], sizeof siri.opt[0][0], "%s", v);
            snprintf(siri.opt[siri.nopt][1], sizeof siri.opt[0][1], "%s", sub ? sub : "");
            siri.nopt++;
        }
    }
    fclose(f);
    siri.on = strcmp(siri.mode, "hidden") != 0;
    if (siri.snippet[0]) {
        siri.snip = cairo_image_surface_create_from_png(siri.snippet);
        if (cairo_surface_status(siri.snip) != CAIRO_STATUS_SUCCESS) { cairo_surface_destroy(siri.snip); siri.snip = NULL; }
    }
    if (!siri.input || strcmp(siri.mode, "working") == 0) siri.typed[0] = 0; else snprintf(siri.typed, sizeof siri.typed, "%s", strcmp(siri.mode, "listening") ? "" : keep_typed);
    if (siri.on && !was) siri.t0 = now();
    fprintf(stderr, "isim shell: Siri %s%s%s%s\n", siri.mode, siri.text[0] ? " “" : "", siri.text, siri.text[0] ? "”" : "");
    if (siri.on || was) shell_show(active >= 0 ? active : 0);
}
static void siri_hide_now(void) { if (!siri.on) return; siri.on = 0; snprintf(siri.mode, sizeof siri.mode, "hidden"); shell_show(active >= 0 ? active : 0); }

/* iOS 17: Siri's orb */
static void siri_orb(cairo_t *c, double cx, double cy, double r, double t) {
    static const double cols[4][3] = { { 1, 0.24, 0.56 }, { 0.36, 0.42, 1 }, { 0.2, 0.86, 0.95 }, { 0.62, 0.32, 1 } };
    cairo_save(c);
    cairo_pattern_t *bg = cairo_pattern_create_radial(cx, cy, 0, cx, cy, r);
    cairo_pattern_add_color_stop_rgba(bg, 0, 0.1, 0.1, 0.25, 1); cairo_pattern_add_color_stop_rgba(bg, 1, 0.02, 0.02, 0.08, 1);
    cairo_arc(c, cx, cy, r, 0, 2 * M_PI); cairo_set_source(c, bg); cairo_fill_preserve(c); cairo_pattern_destroy(bg);
    cairo_clip(c);
    for (int k = 0; k < 4; k++) {
        double a = t * 1.3 + k * M_PI / 2, ox = cx + cos(a) * r * 0.32, oy = cy + sin(a * 1.2) * r * 0.28;
        cairo_pattern_t *p = cairo_pattern_create_radial(ox, oy, 0, ox, oy, r * 0.85);
        cairo_pattern_add_color_stop_rgba(p, 0, cols[k][0], cols[k][1], cols[k][2], 0.9);
        cairo_pattern_add_color_stop_rgba(p, 1, cols[k][0], cols[k][1], cols[k][2], 0);
        cairo_set_source(c, p); cairo_paint(c); cairo_pattern_destroy(p);
    }
    cairo_pattern_t *hi = cairo_pattern_create_radial(cx - r * 0.3, cy - r * 0.35, 0, cx, cy, r);
    cairo_pattern_add_color_stop_rgba(hi, 0, 1, 1, 1, 0.55); cairo_pattern_add_color_stop_rgba(hi, 0.45, 1, 1, 1, 0); cairo_pattern_add_color_stop_rgba(hi, 1, 1, 1, 1, 0.12);
    cairo_set_source(c, hi); cairo_paint(c); cairo_pattern_destroy(hi);
    cairo_restore(c);
}
/* iOS 18+: the glow around the screen's edge */
static void siri_glow(cairo_t *c, double t) {
    double W = dev.width, H = dev.height, r = dev.corner_radius > 0 ? dev.corner_radius : 40;
    cairo_pattern_t *g = cairo_pattern_create_linear(0, 0, W, H);
    double s = fmod(t * 0.25, 1.0);
    static const double cols[6][3] = { { 1, 0.55, 0.2 }, { 1, 0.25, 0.55 }, { 0.7, 0.3, 1 }, { 0.3, 0.45, 1 }, { 0.2, 0.85, 1 }, { 1, 0.55, 0.2 } };
    for (int k = 0; k < 6; k++) cairo_pattern_add_color_stop_rgb(g, fmod(k / 5.0 + s, 1.0001), cols[k][0], cols[k][1], cols[k][2]);
    cairo_save(c);
    static const double widths[4] = { 26, 16, 9, 4 }, alphas[4] = { 0.18, 0.3, 0.55, 0.95 };
    for (int k = 0; k < 4; k++) {
        double w = widths[k];
        cairo_new_path(c);
        sys_round(c, w / 2 - 2, w / 2 - 2, W - w + 4, H - w + 4, fmax(4, r - w / 2));
        cairo_set_line_width(c, w);
        cairo_push_group(c); cairo_set_source(c, g); cairo_stroke(c); cairo_pop_group_to_source(c);
        cairo_paint_with_alpha(c, alphas[k]);
    }
    cairo_restore(c);
    cairo_pattern_destroy(g);
}
static void siri_card_bg(cairo_t *c, double x, double y, double w, double h, double r) {
    if (sys_os() >= 26) { sys_glass(c, x, y, w, h, r, NULL, 1 | 2 | 4); cairo_new_path(c); sys_round(c, x, y, w, h, r); cairo_set_source_rgba(c, 0.97, 0.97, 0.98, 0.9); cairo_fill(c); return; }
    cairo_save(c);                                                   /* a soft shadow, then the light material */
    cairo_new_path(c); sys_round(c, x, y + 3, w, h, r); cairo_set_source_rgba(c, 0, 0, 0, 0.12); cairo_fill(c);
    cairo_new_path(c); sys_round(c, x, y, w, h, r); cairo_set_source_rgba(c, 0.975, 0.975, 0.98, 0.97); cairo_fill(c);
    cairo_restore(c);
}
/* an element whose text is one line in `dump` (line breaks become spaces) */
static void siri_el(const char *id, const char *text, struct rectf r, int kind, int arg) {
    char t[192]; snprintf(t, sizeof t, "%s", text);
    for (char *p = t; *p; p++) if (*p == '\n') *p = ' ';
    el_add(id, t, r, kind, arg);
}
static double siri_measure(cairo_t *c, const char *s, double w, double size, int weight) { return s[0] ? sys_text(c, s, -10000, -10000, w, size, weight, 0, 0, 0, 0, 0, 0) : 0; }

static void siri_draw(cairo_t *c) {
    if (!siri.on) return;
    double t = now() - siri.t0, fade = fmin(1, t / 0.25);
    int os = sys_os(), from_siri = !strcmp(siri.source, "siri");
    cairo_push_group(c);
    el_add("siri-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_SIRI, -1);
    /* the glow (iOS 18+) or the orb (iOS 17) */
    if (from_siri && os >= 18) { siri_glow(c, t); el_add("siri-glow", siri.mode, (struct rectf){ 0, 0, dev.width, dev.height }, EL_NONE, 0); }
    double orb_r = 34, orb_cy = dev.height - fmax(dev.safe_bottom, 10) - 50;
    if (from_siri && os < 18) {
        siri_orb(c, dev.width / 2, orb_cy, orb_r, t);
        el_add("siri-orb", siri.mode, (struct rectf){ dev.width / 2 - orb_r, orb_cy - orb_r, orb_r * 2, orb_r * 2 }, EL_NONE, 0);
    }
    /* the card */
    double w = fmin(dev.width - 16, 420), x = (dev.width - w) / 2, y = fmax(dev.safe_top, 20) + 8, pad = 18, iw = w - 2 * pad, r = os >= 26 ? 32 : 26;
    int listening = !strcmp(siri.mode, "listening"), working = !strcmp(siri.mode, "working");
    int show_card = !listening || siri.text[0];
    if (listening && os < 18 && siri.text[0]) {                      /* iOS 17: the question over the orb */
        sys_text(c, siri.text, 24, orb_cy - orb_r - 64, dev.width - 48, 22, PANGO_WEIGHT_SEMIBOLD, 1, 2, 0, 0, 0, 0.35);
        sys_text(c, siri.text, 24, orb_cy - orb_r - 65, dev.width - 48, 22, PANGO_WEIGHT_SEMIBOLD, 1, 2, 1, 1, 1, 1);
        siri_el("siri-card", siri.text, (struct rectf){ 24, orb_cy - orb_r - 65, dev.width - 48, 30 }, EL_NONE, 0);
        show_card = 0;
    }
    if (show_card) {
        double head = siri.appname[0] ? 30 : 0;
        double heard_h = siri.heard[0] && strcmp(siri.mode, "result") ? siri_measure(c, siri.heard, iw, 14, PANGO_WEIGHT_NORMAL) + 6 : 0;
        const char *txt = siri.text[0] ? siri.text : working ? "…" : "";
        double text_h = siri_measure(c, txt, iw, 19, PANGO_WEIGHT_MEDIUM);
        double detail_h = siri.detail[0] ? siri_measure(c, siri.detail, iw - 24, 15, PANGO_WEIGHT_NORMAL) + 22 : 0;
        double snip_h = 0;
        if (siri.snip) snip_h = cairo_image_surface_get_height(siri.snip) * iw / fmax(1, cairo_image_surface_get_width(siri.snip));
        double opts_h = siri.nopt * 50, buttons_h = !strcmp(siri.mode, "confirm") ? 62 : 0;
        double h = pad + head + heard_h + text_h + (detail_h ? detail_h + 10 : 0) + (snip_h ? snip_h + 10 : 0) + (opts_h ? opts_h + 8 : 0) + buttons_h + pad;
        siri_card_bg(c, x, y, w, h, r);
        double cy = y + pad;
        if (head) {
            struct sys_appinfo *ai = sys_info(siri.app);
            sys_icon(c, ai ? ai->icon : NULL, x + pad, cy - 2, 22);
            sys_text(c, siri.appname, x + pad + 30, cy + 1, iw - 30, 13, PANGO_WEIGHT_SEMIBOLD, 0, 1, 0.42, 0.42, 0.45, 1);
            cy += head;
        }
        if (heard_h) {
            sys_text(c, siri.heard, x + pad, cy, iw, 14, PANGO_WEIGHT_NORMAL, 0, 0, 0.45, 0.45, 0.48, 1);
            el_add("siri-heard", siri.heard, (struct rectf){ x + pad, cy, iw, heard_h - 6 }, EL_NONE, 0);
            cy += heard_h;
        }
        sys_text(c, txt, x + pad, cy, iw, 19, PANGO_WEIGHT_MEDIUM, 0, 0, 0.05, 0.05, 0.07, 1);
        siri_el("siri-card", siri.text, (struct rectf){ x, y, w, h }, EL_NONE, 0);
        cy += text_h;
        if (detail_h) {
            cy += 10;
            cairo_new_path(c); sys_round(c, x + pad, cy, iw, detail_h, 14); cairo_set_source_rgba(c, 0, 0, 0, 0.05); cairo_fill(c);
            sys_text(c, siri.detail, x + pad + 12, cy + 11, iw - 24, 15, PANGO_WEIGHT_NORMAL, 0, 0, 0.1, 0.1, 0.12, 1);
            siri_el("siri-detail", siri.detail, (struct rectf){ x + pad, cy, iw, detail_h }, EL_NONE, 0);
            cy += detail_h;
        }
        if (snip_h) {
            cy += 10;
            cairo_save(c); cairo_new_path(c); sys_round(c, x + pad, cy, iw, snip_h, 12); cairo_clip(c);
            double k = iw / cairo_image_surface_get_width(siri.snip);
            cairo_translate(c, x + pad, cy); cairo_scale(c, k, k);
            cairo_set_source_surface(c, siri.snip, 0, 0); cairo_pattern_set_filter(cairo_get_source(c), CAIRO_FILTER_GOOD); cairo_paint(c);
            cairo_restore(c);
            el_add("siri-snippet", siri.snippet, (struct rectf){ x + pad, cy, iw, snip_h }, EL_NONE, 0);
            cy += snip_h;
        }
        if (opts_h) {
            cy += 8;
            for (int k = 0; k < siri.nopt; k++) {
                struct rectf orr = { x + pad - 6, cy + k * 50, iw + 12, 46 };
                cairo_new_path(c); sys_round(c, orr.x, orr.y, orr.w, orr.h, 14); cairo_set_source_rgba(c, 0, 0, 0, 0.05); cairo_fill(c);
                double sub = siri.opt[k][1][0] ? 1 : 0;
                sys_text(c, siri.opt[k][0], orr.x + 14, orr.y + (sub ? 5 : 13), orr.w - 28, 17, PANGO_WEIGHT_NORMAL, 0, 1, 0, 0.42, 1, 1);
                if (sub) sys_text(c, siri.opt[k][1], orr.x + 14, orr.y + 26, orr.w - 28, 13, PANGO_WEIGHT_NORMAL, 0, 1, 0.45, 0.45, 0.48, 1);
                char id[32]; snprintf(id, sizeof id, "siri-option-%d", k);
                el_add(id, siri.opt[k][0], orr, EL_SIRI, k);
            }
            cy += opts_h;
        }
        if (buttons_h) {
            double bw = (iw - 10) / 2, by = cy + 12;
            struct rectf cancel = { x + pad, by, bw, 46 }, ok = { x + pad + bw + 10, by, bw, 46 };
            if (os >= 26) { sys_glass(c, cancel.x, cancel.y, cancel.w, cancel.h, 23, NULL, 1 | 2); static const double blue[4] = { 0, 0.48, 1, 1 }; sys_glass(c, ok.x, ok.y, ok.w, ok.h, 23, blue, 1 | 2); }
            else {
                cairo_new_path(c); sys_round(c, cancel.x, cancel.y, cancel.w, cancel.h, 14); cairo_set_source_rgba(c, 0, 0, 0, 0.07); cairo_fill(c);
                cairo_new_path(c); sys_round(c, ok.x, ok.y, ok.w, ok.h, 14); cairo_set_source_rgb(c, 0, 0.48, 1); cairo_fill(c);
            }
            sys_text(c, siri.cancel[0] ? siri.cancel : "Cancel", cancel.x, cancel.y + 13, cancel.w, 17, PANGO_WEIGHT_SEMIBOLD, 1, 1, 0, 0.42, 1, 1);
            sys_text(c, siri.action[0] ? siri.action : "Confirm", ok.x, ok.y + 13, ok.w, 17, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
            el_add("siri-cancel", siri.cancel[0] ? siri.cancel : "Cancel", cancel, EL_SIRI, -3);
            el_add("siri-confirm", siri.action[0] ? siri.action : "Confirm", ok, EL_SIRI, -2);
        }
    }
    /* Type to Siri */
    if (siri.input && (listening || !strcmp(siri.mode, "value") || !strcmp(siri.mode, "choice"))) {
        double fy = (from_siri && os < 18) ? orb_cy - orb_r - 62 : dev.height - fmax(dev.safe_bottom, 12) - 62;
        if (from_siri && os < 18 && listening && siri.text[0]) fy = orb_cy - orb_r - 120;
        struct rectf f = { 16, fy, dev.width - 32, 46 };
        if (os >= 26) sys_glass(c, f.x, f.y, f.w, f.h, 23, NULL, 1 | 2 | 4);
        else { cairo_new_path(c); sys_round(c, f.x, f.y, f.w, f.h, 23); cairo_set_source_rgba(c, 0.97, 0.97, 0.98, 0.96); cairo_fill(c); }
        const char *shown = siri.typed[0] ? siri.typed : siri.placeholder[0] ? siri.placeholder : "Ask Siri…";
        sys_text(c, shown, f.x + 18, f.y + 13, f.w - 36, 17, PANGO_WEIGHT_NORMAL, 0, 1, siri.typed[0] ? 0 : 0.55, siri.typed[0] ? 0 : 0.55, siri.typed[0] ? 0 : 0.58, 1);
        el_add("siri-field", siri.typed[0] ? siri.typed : shown, f, EL_SIRI, -4);
    }
    cairo_pop_group_to_source(c);
    cairo_paint_with_alpha(c, fade);
}
static void siri_tick(void) {
    static double last;
    double t = now() - siri.t0;
    if (!siri.on) return;
    if ((t < 0.3 && now() - last > 0.03) || (t < 1.5 && now() - last > 0.1)) { last = now(); shell_show(active >= 0 ? active : 0); }
}
static void siri_answer(const char *what) { sys_send_text(0, "siri-answer %s", what); }
static void siri_tap(struct sys_el *e) {
    if (!e || e->kind != EL_SIRI) { siri_answer("dismiss"); siri_hide_now(); return; }
    if (e->arg >= 0) { char a[32]; snprintf(a, sizeof a, "option %d", e->arg); siri_answer(a); }
    else if (e->arg == -2) siri_answer("confirm");
    else if (e->arg == -3) siri_answer("cancel");
    else if (e->arg == -4) { fprintf(stderr, "isim shell: Type to Siri (type TEXT, then key return)\n"); }
    else { siri_answer("dismiss"); siri_hide_now(); }
}
/* input while Siri is shown (and the key that brings it up); 1 when it was Siri's */
static int siri_input(const struct isim_event *ev) {
    if (ev->type == EV_KEY && (ev->mods & SDL_KMOD_CTRL) && (ev->mods & SDL_KMOD_SHIFT) && (ev->key == 's' || ev->key == 'S')) {   /* hold the side button */
        if (siri.on) { siri_answer("dismiss"); siri_hide_now(); } else sys_send_text(0, "siri %d", locked);
        return 1;
    }
    if (!siri.on) return 0;
    if (ev->type == EV_DUMP) {
        if (ov != OV_NONE) return 0;                                  /* sys_dump lists Siri's parts with the overlay's */
        fprintf(stderr, "IsimSiri (0 0; %g x %g) mode=%s source=%s\n", dev.width, dev.height, siri.mode, siri.source);
        for (int k = 0; k < nels; k++) if (!strncmp(els[k].id, "siri-", 5))
            fprintf(stderr, "  IsimSiriView (%g %g; %g x %g) id=%s%s%s\n", els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text[0] ? " text=" : "", els[k].text);
        return 0;
    }
    int typing = siri.input && (!strcmp(siri.mode, "listening") || !strcmp(siri.mode, "value") || !strcmp(siri.mode, "choice"));
    if (ev->type == EV_TEXT && typing) { strncat(siri.typed, ev->text, sizeof siri.typed - strlen(siri.typed) - 1); shell_show(active >= 0 ? active : 0); return 1; }
    if (ev->type == EV_KEY && ev->key == 8 && typing) { size_t l = strlen(siri.typed); while (l > 0 && (siri.typed[l - 1] & 0xC0) == 0x80) l--; if (l) siri.typed[l - 1] = 0; shell_show(active >= 0 ? active : 0); return 1; }
    if (ev->type == EV_KEY && ev->key == 13 && typing && siri.typed[0]) {
        char a[600]; snprintf(a, sizeof a, "text %s", siri.typed); siri.typed[0] = 0;
        siri_answer(a); return 1;
    }
    if (ev->type == EV_KEY && ev->key == 27) { siri_answer("dismiss"); siri_hide_now(); return 1; }
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        if (strncmp(ev->text, "siri-", 5)) return 0;                    /* the app's own views */
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no Siri element '%s'\n", ev->text); return 1; }
        if (ev->type == EV_ID_UP && ev->mods != 1) siri_tap(e);
        return 1;
    }
    if (ev->type == EV_TOUCH_DOWN || ev->type == EV_TOUCH_MOVE) return 1;
    if (ev->type == EV_TOUCH_UP) {
        struct sys_el *hit = NULL;
        for (int k = nels - 1; k >= 0; k--) {
            struct rectf r = els[k].r;
            if (els[k].kind == EL_SIRI && els[k].arg != -1 && ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h) { hit = &els[k]; break; }
        }
        if (!hit) {                                                       /* on the card itself: nothing; elsewhere: Siri goes away */
            struct sys_el *card = el_named("siri-card");
            if (card && ev->x >= card->r.x && ev->x <= card->r.x + card->r.w && ev->y >= card->r.y && ev->y <= card->r.y + card->r.h) return 1;
        }
        siri_tap(hit);
        return 1;
    }
    return 0;
}
