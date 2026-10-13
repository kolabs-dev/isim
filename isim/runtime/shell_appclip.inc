/* isim shell: the App Clip card (included by shell_system.inc).
 *
 * An App Clip invocation (script `appclip URL`, `openurl` of an App Clip's URL; the home screen resolves it, see
 * system/SpringBoard/SBAppClips.m) shows the App Clip card over the current screen: the header image, the title and
 * subtitle, the call-to-action button (Open / View / Play), the notes for ephemeral notifications and location
 * confirmation (tap: turn off / on), and the App Clip's name. The home screen sends "appclip-card SIDECAR" (a text file:
 * key=value lines: title, subtitle, action, image, icon, name, notifications, location); the card answers
 * "appclip-open SIDECAR\x1fNOTIFICATIONS\x1fLOCATION" (the button) or "appclip-dismissed SIDECAR".
 *
 * The look follows the emulated iOS (adapted, isim's own drawing): iOS 17/18 an opaque card (white, or dark grey in dark
 * mode) floating 8 pt inside the display on Face ID iPhones with corners concentric to the display's (attached to the
 * bottom edge with 13 pt top corners on Home-button iPhones), a full-width rounded-rectangle button; iOS 26/27 a
 * Liquid Glass card and a capsule button. The screen behind is dimmed. */
enum { EL_AC_OPEN = 100, EL_AC_CLOSE, EL_AC_NOTIFY, EL_AC_LOCATION };
static struct {
    int on, notify_req, location_req, notify, location;
    char sidecar[512], title[192], subtitle[256], action[32], image[512], icon[512], name[128];
} ac;

static int ac_dark(void) {
    const char *e = getenv("ISIM_APPEARANCE");
    if (e && !strcmp(e, "dark")) return 1;
    const char *d = getenv("ISIM_DATA"); if (!d || !*d) return 0;
    char p[1024]; snprintf(p, sizeof p, "%s/Library/Preferences/.GlobalPreferences.plist", d);
    FILE *f = fopen(p, "r"); if (!f) return 0;
    char buf[8192]; size_t n = fread(buf, 1, sizeof buf - 1, f); fclose(f); buf[n] = 0;
    const char *k = strstr(buf, "<key>AppleInterfaceStyle</key>");
    return k && !strncmp(k + 30 + strspn(k + 30, " \t\r\n"), "<string>Dark</string>", 21);
}
/* the home screen's request: show the card */
static void ac_show(const char *sidecar) {
    FILE *f = fopen(sidecar, "r");
    if (!f) { fprintf(stderr, "isim shell: App Clip card: cannot read %s\n", sidecar); return; }
    memset(&ac, 0, sizeof ac);
    snprintf(ac.sidecar, sizeof ac.sidecar, "%s", sidecar);
    snprintf(ac.action, sizeof ac.action, "Open");
    char line[1200];
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\n")] = 0;
        char *v = strchr(line, '='); if (!v) continue; *v++ = 0;
        if (!strcmp(line, "title")) snprintf(ac.title, sizeof ac.title, "%s", v);
        else if (!strcmp(line, "subtitle")) snprintf(ac.subtitle, sizeof ac.subtitle, "%s", v);
        else if (!strcmp(line, "action") && *v) snprintf(ac.action, sizeof ac.action, "%s", v);
        else if (!strcmp(line, "image")) snprintf(ac.image, sizeof ac.image, "%s", v);
        else if (!strcmp(line, "icon")) snprintf(ac.icon, sizeof ac.icon, "%s", v);
        else if (!strcmp(line, "name")) snprintf(ac.name, sizeof ac.name, "%s", v);
        else if (!strcmp(line, "notifications")) ac.notify_req = atoi(v);
        else if (!strcmp(line, "location")) ac.location_req = atoi(v);
    }
    fclose(f);
    ac.notify = ac.notify_req; ac.location = ac.location_req;        /* both notes are on by default */
    ac.on = 1;
    if (anim.kind != ANIM_NONE) anim.kind = ANIM_NONE;
    if (win_orient != 1) shell_apply_orient(1);
    nb.on = 0;
    ov = OV_CLIP; ov_t0 = now();
    fprintf(stderr, "isim shell: App Clip card “%s” (%s; iOS %d look)\n", ac.title, ac.action, sys_os());
    sys_draw();
}
static void ac_close(int open) {
    if (!ac.on) return;
    ac.on = 0;
    if (ov == OV_CLIP) ov = OV_NONE;
    if (open) {
        fprintf(stderr, "isim shell: App Clip card: %s (notifications %s, location confirmation %s)\n", ac.action,
                ac.notify_req ? (ac.notify ? "allowed" : "off") : "not requested", ac.location_req ? (ac.location ? "allowed" : "off") : "not requested");
        sys_send_text(0, "appclip-open %s\x1f%d\x1f%d", ac.sidecar, ac.notify, ac.location);
    } else {
        fprintf(stderr, "isim shell: App Clip card dismissed\n");
        sys_send_text(0, "appclip-dismissed %s", ac.sidecar);
    }
    shell_show(active >= 0 ? active : 0);
}
/* the header image: aspect-filled into r (any format the host image code reads); none: the App Clip's icon on a tint */
static void ac_header(cairo_t *c, struct rectf r, int dark) {
    double w = 0, h = 0; int hd = ac.image[0] ? isim_image_load(ac.image, &w, &h) : 0;
    if (hd && w > 0 && h > 0) {
        double k = fmax(r.w / w, r.h / h);
        cairo_t *saved = cr; cr = c;
        isim_image_draw(hd, r.x + (r.w - w * k) / 2, r.y + (r.h - h * k) / 2, w * k, h * k, NULL, 1);
        cr = saved;
    } else {
        cairo_pattern_t *g = cairo_pattern_create_linear(0, r.y, 0, r.y + r.h);
        cairo_pattern_add_color_stop_rgb(g, 0, dark ? 0.20 : 0.84, dark ? 0.22 : 0.88, dark ? 0.27 : 0.95);
        cairo_pattern_add_color_stop_rgb(g, 1, dark ? 0.12 : 0.70, dark ? 0.13 : 0.76, dark ? 0.17 : 0.88);
        cairo_rectangle(c, r.x, r.y, r.w, r.h); cairo_set_source(c, g); cairo_fill(c); cairo_pattern_destroy(g);
        double s = fmin(r.h * 0.42, 96);
        sys_icon(c, ac.icon, r.x + (r.w - s) / 2, r.y + (r.h - s) / 2, s);
    }
    if (hd) isim_image_free(hd);
}
static void ac_draw(cairo_t *c) {
    int glass = sys_os() >= 26, dark = ac_dark(), homebutton = dev.corner_radius <= 0;
    double e = 1 - pow(1 - fmin(1, (now() - ov_t0) / 0.3), 3);
    double inset = homebutton ? 0 : 8, cw = fmin(dev.width - 2 * inset, 440), cx = (dev.width - cw) / 2;
    double radius = homebutton ? 13 : fmax(dev.corner_radius - inset, 22);
    double fg = dark ? 1 : 0, sec = dark ? 0.62 : 0.42;
    /* the parts, top to bottom */
    double header_h = round(cw * 2 / 3), pad = 20;
    double title_h = 26, sub_h = ac.subtitle[0] ? 40 : 0, button_h = 50, note_h = 30;
    int notes = (ac.notify_req ? 1 : 0) + (ac.location_req ? 1 : 0);
    double ch = header_h + 16 + title_h + sub_h + 14 + button_h + (notes ? 10 + notes * note_h : 0) + 14 + 22 + (homebutton ? 12 : dev.safe_bottom > 0 ? 18 : 12);
    double cy = dev.height - inset - ch + (ch + inset) * (1 - e);
    struct rectf card = { cx, cy, cw, ch + (homebutton ? 0 : 0) };
    el_add("appclip-background", "", (struct rectf){ 0, 0, dev.width, dev.height }, EL_BG, 0);
    /* the card */
    cairo_save(c);
    if (homebutton) {                                      /* rounded top corners only */
        cairo_new_sub_path(c);
        cairo_arc(c, card.x + card.w - radius, card.y + radius, radius, -M_PI / 2, 0);
        cairo_line_to(c, card.x + card.w, card.y + card.h); cairo_line_to(c, card.x, card.y + card.h);
        cairo_arc(c, card.x + radius, card.y + radius, radius, M_PI, 1.5 * M_PI); cairo_close_path(c);
    } else sys_round(c, card.x, card.y, card.w, card.h, radius);
    cairo_path_t *shape = cairo_copy_path(c);
    if (glass) {
        cairo_new_path(c);
        const double tint_dark[4] = { 0.10, 0.10, 0.11, 0.78 }, tint_light[4] = { 1, 1, 1, 0.78 };
        sys_glass(c, card.x, card.y, card.w, card.h, radius, dark ? tint_dark : tint_light, (dark ? 1 : 0) | 4);
    } else {
        if (dark) cairo_set_source_rgb(c, 0.11, 0.11, 0.12); else cairo_set_source_rgb(c, 1, 1, 1);
        cairo_fill(c);
    }
    /* the header image, clipped to the card's top corners */
    cairo_new_path(c); cairo_append_path(c, shape); cairo_clip(c);
    ac_header(c, (struct rectf){ card.x, card.y, card.w, header_h }, dark);
    cairo_restore(c);
    cairo_path_destroy(shape);
    /* the close button over the image */
    struct rectf x = { card.x + card.w - 14 - 30, card.y + 14, 30, 30 };
    cairo_new_path(c); cairo_arc(c, x.x + 15, x.y + 15, 15, 0, 2 * M_PI);
    if (glass) { cairo_new_path(c); sys_glass(c, x.x, x.y, 30, 30, 15, NULL, 1 | 4); }
    else { cairo_set_source_rgba(c, 0.10, 0.10, 0.12, 0.45); cairo_fill(c); }
    sys_symbol(c, "xmark", x.x + 15, x.y + 15, 12, glass ? 0.25 : 1, glass ? 0.25 : 1, glass ? 0.27 : 1);
    el_add("appclip-close", "Close", x, EL_AC_CLOSE, 0);
    /* title, subtitle */
    double y = card.y + header_h + 16, tx = card.x + pad, tw = card.w - 2 * pad;
    sys_text(c, ac.title, tx, y, tw, 20, PANGO_WEIGHT_BOLD, 0, 1, fg, fg, fg, 1);
    el_add("appclip-title", ac.title, (struct rectf){ tx, y, tw, title_h }, EL_NONE, 0);
    y += title_h;
    if (ac.subtitle[0]) {
        sys_text(c, ac.subtitle, tx, y + 2, tw, 15, PANGO_WEIGHT_NORMAL, 0, 2, sec, sec, sec + 0.02, 1);
        el_add("appclip-subtitle", ac.subtitle, (struct rectf){ tx, y, tw, sub_h }, EL_NONE, 0);
        y += sub_h;
    }
    y += 14;
    /* the call-to-action button */
    struct rectf b = { tx, y, tw, button_h };
    if (glass) {
        const double blue[4] = { 0.0, 0.48, 1.0, 0.92 };
        sys_glass(c, b.x, b.y, b.w, b.h, b.h / 2, blue, (dark ? 1 : 0) | 4);
    } else {
        cairo_new_path(c); sys_round(c, b.x, b.y, b.w, b.h, 12);
        if (dark) cairo_set_source_rgb(c, 0.04, 0.52, 1.0); else cairo_set_source_rgb(c, 0.0, 0.48, 1.0);
        cairo_fill(c);
    }
    sys_text(c, ac.action, b.x, b.y + 14, b.w, 17, PANGO_WEIGHT_SEMIBOLD, 1, 1, 1, 1, 1, 1);
    el_add("appclip-open", ac.action, b, EL_AC_OPEN, 0);
    y += button_h;
    /* the notes: tap to turn off (and on again) */
    if (notes) y += 10;
    for (int k = 0; k < 2; k++) {
        int req = k == 0 ? ac.notify_req : ac.location_req, on = k == 0 ? ac.notify : ac.location;
        if (!req) continue;
        struct rectf r = { tx, y, tw, note_h };
        const char *text = k == 0 ? (on ? "Notifications allowed for 8 hours" : "Notifications not allowed")
                                  : (on ? "Can verify your location" : "Location verification off");
        const char *sym = k == 0 ? (on ? "bell.fill" : "bell.slash.fill") : (on ? "location.fill" : "location.slash.fill");
        sys_symbol(c, sym, r.x + 9, r.y + note_h / 2, 13, sec, sec, sec + 0.02);
        sys_text(c, text, r.x + 24, r.y + 7, r.w - 24, 13, PANGO_WEIGHT_NORMAL, 0, 1, sec, sec, sec + 0.02, 1);
        el_add(k == 0 ? "appclip-notifications" : "appclip-location", text, r, k == 0 ? EL_AC_NOTIFY : EL_AC_LOCATION, 0);
        y += note_h;
    }
    /* the footer: the App Clip's icon and name */
    y += 14;
    cairo_set_source_rgba(c, fg, fg, fg, dark ? 0.16 : 0.10); cairo_rectangle(c, tx, y - 7, tw, 0.5); cairo_fill(c);
    sys_icon(c, ac.icon, tx, y, 20);
    char foot[192]; snprintf(foot, sizeof foot, "%s · App Clip", ac.name[0] ? ac.name : ac.title);
    sys_text(c, foot, tx + 28, y + 2, tw - 28, 13, PANGO_WEIGHT_MEDIUM, 0, 1, sec, sec, sec + 0.02, 1);
    el_add("appclip-app", foot, (struct rectf){ tx, y, tw, 22 }, EL_NONE, 0);
    el_add("appclip-card", ac.title, card, EL_NONE, 0);
}
static void ac_tap(struct sys_el *e) {
    switch (e->kind) {
    case EL_AC_OPEN: ac_close(1); break;
    case EL_AC_CLOSE: ac_close(0); break;
    case EL_AC_NOTIFY: ac.notify = !ac.notify; fprintf(stderr, "isim shell: App Clip card: notifications %s\n", ac.notify ? "allowed" : "off"); sys_draw(); break;
    case EL_AC_LOCATION: ac.location = !ac.location; fprintf(stderr, "isim shell: App Clip card: location confirmation %s\n", ac.location ? "allowed" : "off"); sys_draw(); break;
    default: break;
    }
}
