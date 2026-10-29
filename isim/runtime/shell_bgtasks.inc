/* isim shell: the system's Live Activity for BackgroundTasks' continued processing tasks (iOS 26; included by
 * shell_system.inc). Adapted: isim's drawing of it. The app tells the shell about each running task:
 * "bgtask-progress ID title\x1fsubtitle\x1ffraction\x1fapp name" (fraction -1: indeterminate) and "bgtask-end ID".
 * The shell draws the activity's views itself (no widget extension) and shows them as a Live Activity
 * ("bgtask:ID"): on the Lock Screen, and in the Dynamic Island (compact: the app's icon and a progress ring;
 * expanded on a tap) while the app is not in front. The Lock Screen and expanded views have a cancel button
 * ("bgtask-cancel"); cancelling sends "bgtask-action cancel ID" to the app, whose task expires. `dump` lists the running
 * tasks as IsimBackgroundTask (id=bgtask-ID text=TITLE — SUBTITLE (N%)). */

/* where the cancel button sits in the 370 x 160 views */
#define BT_CANCEL_X 326.0
#define BT_CANCEL_Y 16.0
#define BT_CANCEL_D 28.0

struct bt_info { char title[256], subtitle[256], appname[128]; double fraction; };
static struct bt_info bt_infos[LA_MAX];                   /* by Live Activity slot */

static int bt_is(int i) { return i >= 0 && i < LA_MAX && las[i].on && !strncmp(las[i].id, "bgtask:", 7); }
static const char *bt_task_id(int i) { return las[i].id + 7; }

/* a 2x image surface of w x h points */
static cairo_t *bt_begin(cairo_surface_t **s, double w, double h) {
    *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int)(w * 2), (int)(h * 2));
    cairo_t *c = cairo_create(*s); cairo_scale(c, 2, 2);
    return c;
}
static void bt_ring(cairo_t *c, double cx, double cy, double r, double fraction, double lw) {
    cairo_set_line_width(c, lw);
    cairo_new_path(c); cairo_arc(c, cx, cy, r, 0, 2 * M_PI); cairo_set_source_rgba(c, 1, 1, 1, 0.25); cairo_stroke(c);
    double f = fraction < 0 ? 0.25 : fraction;               /* indeterminate: a quarter */
    cairo_new_path(c); cairo_arc(c, cx, cy, r, -M_PI / 2, -M_PI / 2 + 2 * M_PI * f);
    cairo_set_source_rgb(c, 0.04, 0.52, 1); cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_stroke(c);
}
/* the Lock Screen (light platter) and expanded (black) view: icon and app name, cancel, title, subtitle, progress */
static cairo_surface_t *bt_render_card(const struct bt_info *t, const char *app, int dark) {
    cairo_surface_t *s; cairo_t *c = bt_begin(&s, 370, 160);
    double fg = dark ? 1 : 0, sec = dark ? 0.6 : 0.45;
    struct sys_appinfo *ai = sys_info(app);
    sys_icon(c, ai ? ai->icon : NULL, 16, 16, 24);
    sys_text(c, t->appname, 48, 19, 250, 14, PANGO_WEIGHT_MEDIUM, 0, 1, fg, fg, fg, sec);
    cairo_new_path(c); cairo_arc(c, BT_CANCEL_X + BT_CANCEL_D / 2, BT_CANCEL_Y + BT_CANCEL_D / 2, BT_CANCEL_D / 2, 0, 2 * M_PI);
    cairo_set_source_rgba(c, fg, fg, fg, dark ? 0.2 : 0.1); cairo_fill(c);
    sys_symbol(c, "xmark", BT_CANCEL_X + BT_CANCEL_D / 2, BT_CANCEL_Y + BT_CANCEL_D / 2, 13, fg * 0.85, fg * 0.85, fg * 0.85);
    sys_text(c, t->title, 16, 56, 338, 18, PANGO_WEIGHT_SEMIBOLD, 0, 1, fg, fg, fg, 1);
    sys_text(c, t->subtitle, 16, 82, 280, 15, PANGO_WEIGHT_NORMAL, 0, 1, fg, fg, fg, sec);
    if (t->fraction >= 0) {
        char pct[16]; snprintf(pct, sizeof pct, "%d%%", (int)lround(t->fraction * 100));
        sys_text(c, pct, 296, 82, 58, 15, PANGO_WEIGHT_MEDIUM, 2, 1, fg, fg, fg, sec);
    }
    double bx = 16, by = 124, bw = 338, bh = 6, f = t->fraction < 0 ? 0.25 : t->fraction;
    cairo_new_path(c); sys_round(c, bx, by, bw, bh, bh / 2); cairo_set_source_rgba(c, fg, fg, fg, dark ? 0.22 : 0.12); cairo_fill(c);
    if (f > 0) { cairo_new_path(c); sys_round(c, bx, by, fmax(bh, bw * f), bh, bh / 2); cairo_set_source_rgb(c, 0.04, 0.52, 1); cairo_fill(c); }
    cairo_destroy(c);
    return s;
}
static void bt_render(int i) {
    struct la_item *it = &las[i]; struct bt_info *t = &bt_infos[i];
    la_free_images(it);
    it->lock = bt_render_card(t, it->app, 0);
    it->exp = bt_render_card(t, it->app, 1);
    struct sys_appinfo *ai = sys_info(it->app);
    cairo_t *c = bt_begin(&it->leading, 64, 37); sys_icon(c, ai ? ai->icon : NULL, 20, 7.5, 22); cairo_destroy(c);
    c = bt_begin(&it->trailing, 64, 37); bt_ring(c, 32, 18.5, 9, t->fraction, 3); cairo_destroy(c);
    c = bt_begin(&it->minimal, 37, 37); bt_ring(c, 18.5, 18.5, 9, t->fraction, 3); cairo_destroy(c);
}
static void bt_redraw(void) { if (ov != OV_NONE) sys_draw(); else shell_show(active >= 0 ? active : 0); }

static int bgtasks_handle_msg(int from, const struct shell_msg *m) {
    if (strcmp(m->a, "bgtask-progress") && strcmp(m->a, "bgtask-end")) return 0;
    char id[80]; snprintf(id, sizeof id, "bgtask:%s", m->b);
    int i = la_find(id);
    if (!strcmp(m->a, "bgtask-end")) {
        if (i >= 0) { fprintf(stderr, "isim shell: continued processing task %s ended\n", m->b); la_remove(i); bt_redraw(); }
        return 1;
    }
    if (i < 0) {
        for (int k = 0; k < LA_MAX && i < 0; k++) if (!las[k].on) i = k;
        if (i < 0) { fprintf(stderr, "isim shell: too many Live Activities (continued processing task %s)\n", m->b); return 1; }
        memset(&las[i], 0, sizeof las[i]); memset(&bt_infos[i], 0, sizeof bt_infos[i]);
        snprintf(las[i].id, sizeof las[i].id, "%s", id); snprintf(las[i].app, sizeof las[i].app, "%s", clients[from].bundle);
        las[i].on = 1; las[i].started = wall_now(); las[i].relevance = 50;
    }
    struct bt_info *t = &bt_infos[i]; char v[64];
    int was_new = !t->title[0];
    field(m->c, 0, t->title, sizeof t->title); field(m->c, 1, t->subtitle, sizeof t->subtitle);
    field(m->c, 2, v, sizeof v); t->fraction = atof(v);
    field(m->c, 3, t->appname, sizeof t->appname);
    if (!t->appname[0]) { struct sys_appinfo *ai = sys_info(las[i].app); snprintf(t->appname, sizeof t->appname, "%s", ai && ai->name[0] ? ai->name : "App"); }
    bt_render(i);
    if (was_new) fprintf(stderr, "isim shell: continued processing task %s of %s shown (“%s”)\n", m->b, t->appname, t->title);
    bt_redraw();
    return 1;
}
/* the cancel button over a drawn view (x, y, w, h: where the 370 x 160 view is) */
static void bt_add_cancel(int i, double x, double y, double w, double h) {
    if (!bt_is(i)) return;
    double sx = w / 370, sy = h / 160;
    el_add("bgtask-cancel", bt_infos[i].title, (struct rectf){ x + BT_CANCEL_X * sx - 6, y + BT_CANCEL_Y * sy - 6, BT_CANCEL_D * sx + 12, BT_CANCEL_D * sy + 12 }, EL_BGTASK, i);
}
static void bt_cancel(int i) {
    if (!bt_is(i)) return;
    int app = shell_find(las[i].app);
    fprintf(stderr, "isim shell: continued processing task %s cancelled by the user\n", bt_task_id(i));
    if (app >= 0) sys_send_text(app, "bgtask-action cancel %s", bt_task_id(i));
    else la_remove(i);                                    /* its app is gone */
    if (!strcmp(la.exp_id, las[i].id)) la.exp_id[0] = 0;
    bt_redraw();
}
static int bgtasks_input(const struct isim_event *ev) {
    if (ev->type == EV_DUMP) {
        for (int i = 0; i < LA_MAX; i++) if (bt_is(i)) {
            const struct bt_info *t = &bt_infos[i];
            char pct[16] = ""; if (t->fraction >= 0) snprintf(pct, sizeof pct, " (%d%%)", (int)lround(t->fraction * 100));
            fprintf(stderr, "IsimBackgroundTask (0 0; 0 x 0) id=bgtask-%s text=%s — %s%s\n", bt_task_id(i), t->title, t->subtitle, pct);
        }
        if (ov == OV_NONE) for (int k = 0; k < nels; k++) if (els[k].kind == EL_BGTASK)
            fprintf(stderr, "IsimBackgroundTaskButton (%g %g; %g x %g) id=%s text=%s\n", els[k].r.x, els[k].r.y, els[k].r.w, els[k].r.h, els[k].id, els[k].text);
        return 0;
    }
    if (ev->type == EV_ID_DOWN || ev->type == EV_ID_UP) {
        if (strcmp(ev->text, "bgtask-cancel")) return 0;
        struct sys_el *e = el_named(ev->text);
        if (!e) { fprintf(stderr, "isim shell: no continued processing task's cancel button is showing\n"); return 1; }
        if (ev->type == EV_ID_UP) bt_cancel(e->arg);
        return 1;
    }
    static int down;
    if (ev->type == EV_TOUCH_DOWN || ev->type == EV_TOUCH_UP) {
        struct sys_el *hit = NULL;
        for (int k = 0; k < nels; k++) {
            struct rectf r = els[k].r;
            if (els[k].kind == EL_BGTASK && ev->x >= r.x && ev->x <= r.x + r.w && ev->y >= r.y && ev->y <= r.y + r.h) hit = &els[k];
        }
        if (ev->type == EV_TOUCH_DOWN) { down = hit != NULL; return down; }
        if (!down) return 0;
        down = 0;
        if (hit) bt_cancel(hit->arg);
        return 1;
    }
    return ev->type == EV_TOUCH_MOVE && down;
}
/* a task whose app is gone ends with it */
static void bgtasks_tick(void) {
    for (int i = 0; i < LA_MAX; i++) if (bt_is(i) && shell_find(las[i].app) < 0) {
        fprintf(stderr, "isim shell: continued processing task %s ended (its app is gone)\n", bt_task_id(i));
        la_remove(i); bt_redraw();
    }
}
