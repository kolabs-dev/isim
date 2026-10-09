/* Host input extras (included by host.c): a second finger, pointer hover, IME composition and VoiceOver commands.
 *
 * Multi-touch mirrors the Simulator: holding Option (Alt) while clicking puts a second finger at the point mirrored
 * around the screen centre (drag to pinch / rotate); Option+Shift keeps the two fingers' spacing and moves them
 * together (two-finger pan). While Option is held the window shows both fingers as grey circles. Touch events carry
 * the finger in `pad` (0 first finger, 1 second finger).
 * Without a button pressed, mouse motion is pointer hover (EV_HOVER; pad 1 = the pointer left the window).
 * SDL text editing (IME composition) becomes EV_TEXT_EDITING: text = marked text, key = cursor, mods = selection length.
 *
 * Script commands:
 *   pinch X Y SCALE SECS          two fingers around (X, Y), 100 pt apart, spread to 100*SCALE pt
 *   rotate2 X Y DEGREES SECS      two fingers 120 pt apart around (X, Y), turned by DEGREES (clockwise > 0)
 *   twofinger X Y DX DY SECS      two fingers 60 pt apart, moved together by (DX, DY)
 *   longdrag X1 Y1 X2 Y2 HOLD SECS  one finger down, held HOLD s (a long press), then moved over SECS and lifted
 *   hover X Y | hover off         pointer at (X, Y) without touching / pointer leaves
 *   dictate TEXT | dictate fail   speech for dictation (the app's keyboard mic): TEXT is what was "said"
 *   scribble X Y TEXT             handwriting TEXT with Apple Pencil at (X, Y) (Scribble, iPad)
 *   sms TEXT                      a text message arrives (Messages); one-time codes in it are offered by AutoFill
 *   compose TEXT                  IME marked text (an empty TEXT ends composing); `type` commits
 *   voiceover on|off|next|prev|activate|read|rotor [prev]|up|down   VoiceOver (the app's UIKit runs it)
 *   switchcontrol on|off|next|select|auto   Switch Control: item scanning (auto: a timer moves the highlight)
 *   voicecontrol PHRASE          Voice Control: "tap Done", "show numbers", "tap 3", "scroll down", "go back", …
 */
enum { EV_HOVER = 40, EV_TEXT_EDITING = 41, EV_VOICEOVER = 42 };

static int button_down;                      /* (tentative definition; also declared where host.c uses it) */
static int mt_host_fingers;                  /* window input: 2 while an Option-drag is in progress */
static double mt_host_dx, mt_host_dy;        /* Option+Shift: second finger offset from the first */
static double mouse_x = -1, mouse_y = -1;    /* last pointer position (points) */
static int mt_overlay;                       /* Option held: draw the two fingers */

/* scripted two-finger gestures: centre (cx, cy) moving by (dx, dy), half-spacing r0 -> r1, angle a0 -> a1 */
static struct { int on; double t0, dur, last, cx, cy, dx, dy, r0, r1, a0, a1; } mt;
static void mt_points(double p, double pt[4]) {
    double cx = mt.cx + mt.dx * p, cy = mt.cy + mt.dy * p, r = mt.r0 + (mt.r1 - mt.r0) * p, a = mt.a0 + (mt.a1 - mt.a0) * p;
    pt[0] = cx - r * cos(a); pt[1] = cy - r * sin(a); pt[2] = cx + r * cos(a); pt[3] = cy + r * sin(a);
}
static void mt_push(int type, const double pt[4]) {
    pending[npending++] = (struct isim_event){ .type = type, .x = pt[0], .y = pt[1], .pad = 0 };
    pending[npending++] = (struct isim_event){ .type = type, .x = pt[2], .y = pt[3], .pad = 1 };
}
static void mt_start(double cx, double cy, double dx, double dy, double r0, double r1, double a0, double a1, double dur) {
    mt.on = 1; mt.cx = cx; mt.cy = cy; mt.dx = dx; mt.dy = dy; mt.r0 = r0; mt.r1 = r1; mt.a0 = a0; mt.a1 = a1;
    mt.dur = dur > 0.02 ? dur : 0.02; mt.t0 = mt.last = now();
    double pt[4]; mt_points(0, pt); mt_push(EV_TOUCH_DOWN, pt);
    script_resume = now() + mt.dur + 0.05;
}
/* one frame of a scripted two-finger gesture (called from script_step while npending == 0) */
static void mt_tick(void) {
    double t = now();
    if (t - mt.last < 0.016) return;
    mt.last = t;
    double p = fmin(1, (t - mt.t0) / mt.dur), pt[4];
    mt_points(p, pt);
    mt_push(EV_TOUCH_MOVE, pt);
    if (p >= 1) { mt_push(EV_TOUCH_UP, pt); mt.on = 0; }
}
/* longdrag: press, hold, then a timed move */
static struct { int on; double x1, y1, x2, y2, hold_until, t0, dur, last; } ld;
static void ld_tick(void) {
    double t = now();
    if (t < ld.hold_until || t - ld.last < 0.016) return;
    if (!ld.t0) ld.t0 = t;
    ld.last = t;
    double p = fmin(1, (t - ld.t0) / ld.dur);
    pending[npending++] = (struct isim_event){ .type = EV_TOUCH_MOVE, .x = ld.x1 + (ld.x2 - ld.x1) * p, .y = ld.y1 + (ld.y2 - ld.y1) * p };
    if (p >= 1) { pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = ld.x2, .y = ld.y2 }; ld.on = 0; }
}
/* script commands of this file; returns 1 if `cmd` was one */
static int input_script_cmd(const char *cmd, const char *args) {
    double a, b, c, d, e; char arg[512] = {0};
    if (!strcmp(cmd, "pinch") && sscanf(args, "%lf %lf %lf %lf", &a, &b, &c, &d) == 4) { mt_start(a, b, 0, 0, 50, 50 * c, 0, 0, d); return 1; }
    if (!strcmp(cmd, "rotate2") && sscanf(args, "%lf %lf %lf %lf", &a, &b, &c, &d) == 4) { mt_start(a, b, 0, 0, 60, 60, 0, c * M_PI / 180, d); return 1; }
    if (!strcmp(cmd, "twofinger") && sscanf(args, "%lf %lf %lf %lf %lf", &a, &b, &c, &d, &e) == 5) { mt_start(a, b, c, d, 30, 30, 0, 0, e); return 1; }
    double f;
    if (!strcmp(cmd, "longdrag") && sscanf(args, "%lf %lf %lf %lf %lf %lf", &a, &b, &c, &d, &e, &f) == 6) {
        ld.on = 1; ld.x1 = a; ld.y1 = b; ld.x2 = c; ld.y2 = d; ld.hold_until = now() + e; ld.t0 = 0; ld.dur = f > 0.02 ? f : 0.02; ld.last = 0;
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = a, .y = b };
        script_resume = now() + e + ld.dur + 0.1;
        return 1;
    }
    if (!strcmp(cmd, "hover")) {
        if (sscanf(args, "%lf %lf", &a, &b) == 2) pending[npending++] = (struct isim_event){ .type = EV_HOVER, .x = a, .y = b };
        else pending[npending++] = (struct isim_event){ .type = EV_HOVER, .pad = 1 };
        script_resume = now() + 0.02;
        return 1;
    }
    /* text services run in the app's UIKit (UITextServices.m) */
    if (!strcmp(cmd, "dictate") || !strcmp(cmd, "scribble") || !strcmp(cmd, "sms")) {
        enum { EV_TEXT_SERVICE = 43 };
        sscanf(args, " %511[^\n]", arg);
        for (size_t n = strlen(arg); n && arg[n - 1] == ' '; n--) arg[n - 1] = 0;
        pending[npending++] = (struct isim_event){ .type = EV_TEXT_SERVICE };
        if (!strcmp(cmd, "dictate") && !strcmp(arg, "fail")) snprintf(pending[npending - 1].text, sizeof pending->text, "dictate-fail");
        else snprintf(pending[npending - 1].text, sizeof pending->text, "%s:%s", cmd, arg);
        script_resume = now() + 0.1;
        return 1;
    }
    if (!strcmp(cmd, "compose")) {
        sscanf(args, " %511[^;]", arg);
        pending[npending++] = (struct isim_event){ .type = EV_TEXT_EDITING };
        snprintf(pending[npending - 1].text, sizeof pending->text, "%s", arg);
        int chars = 0; for (const char *q = arg; *q; q++) chars += (*q & 0xC0) != 0x80;
        pending[npending - 1].key = chars;                       /* cursor after the marked text (characters) */
        script_resume = now() + 0.05;
        return 1;
    }
    /* assistive technologies run in the app's UIKit: VoiceOver, Switch Control ("switch:"), Voice Control ("voice:") */
    if ((!strcmp(cmd, "voiceover") || !strcmp(cmd, "switchcontrol") || !strcmp(cmd, "voicecontrol")) && sscanf(args, " %511[^;\n]", arg) == 1) {
        for (size_t n = strlen(arg); n && arg[n - 1] == ' '; n--) arg[n - 1] = 0;
        const char *prefix = !strcmp(cmd, "voiceover") ? "" : !strcmp(cmd, "switchcontrol") ? "switch:" : "voice:";
        pending[npending++] = (struct isim_event){ .type = EV_VOICEOVER };
        snprintf(pending[npending - 1].text, sizeof pending->text, "%s%s", prefix, arg);
        script_resume = now() + 0.1;
        return 1;
    }
    return 0;
}

/* ---- window input ---- */
static void present_overlay(SDL_Surface *ws);
static void reblit(void) {                    /* redraw the window from the shown frame (for the finger overlay) */
    if (headless || !win || !surf) return;
    SDL_Surface *ws = SDL_GetWindowSurface(win);
    if (!ws) return;
    cairo_surface_flush(surf);
    int w = cairo_image_surface_get_width(surf), h = cairo_image_surface_get_height(surf);
    SDL_Surface *src = SDL_CreateSurfaceFrom(w, h, SDL_PIXELFORMAT_ARGB8888, cairo_image_surface_get_data(surf), cairo_image_surface_get_stride(surf));
    if (ws->w == w && ws->h == h) SDL_BlitSurface(src, NULL, ws, NULL);
    else SDL_BlitSurfaceScaled(src, NULL, ws, NULL, SDL_SCALEMODE_LINEAR);
    SDL_DestroySurface(src);
    present_overlay(ws);
    SDL_UpdateWindowSurface(win);
}
static void second_finger(double x, double y, double *x2, double *y2) {
    if (mt_host_fingers == 2) { *x2 = x + mt_host_dx; *y2 = y + mt_host_dy; return; }
    *x2 = dev.width - x; *y2 = dev.height - y;                /* mirrored around the screen centre */
}
/* draws the two fingers onto the window (not into screenshots) while Option is held */
static void present_overlay(SDL_Surface *ws) {
    if (!mt_overlay || mouse_x < 0 || !ws || (ws->format != SDL_PIXELFORMAT_XRGB8888 && ws->format != SDL_PIXELFORMAT_ARGB8888)) return;
    if (!SDL_LockSurface(ws)) return;
    cairo_surface_t *s = cairo_image_surface_create_for_data(ws->pixels, CAIRO_FORMAT_RGB24, ws->w, ws->h, ws->pitch);
    cairo_t *c = cairo_create(s);
    double k = (double)ws->w / dev.width, x2, y2;
    second_finger(mouse_x, mouse_y, &x2, &y2);
    double pts[2][2] = { { mouse_x, mouse_y }, { x2, y2 } };
    for (int i = 0; i < 2; i++) {
        cairo_arc(c, pts[i][0] * k, pts[i][1] * k, 18 * k, 0, 2 * M_PI);
        cairo_set_source_rgba(c, 0.5, 0.5, 0.5, button_down ? 0.55 : 0.35); cairo_fill_preserve(c);
        cairo_set_source_rgba(c, 0.25, 0.25, 0.25, 0.6); cairo_set_line_width(c, 1.5 * k); cairo_stroke(c);
    }
    cairo_destroy(c); cairo_surface_destroy(s);
    SDL_UnlockSurface(ws);
}
/* SDL events this file turns into isim events; returns 1 with *ev filled (more may be queued in `pending`) */
static int input_sdl_event(const SDL_Event *e, struct isim_event *ev) {
    switch (e->type) {
    case SDL_EVENT_MOUSE_BUTTON_DOWN: {
        if (e->button.button != SDL_BUTTON_LEFT) return 0;
        SDL_Keymod m = SDL_GetModState();
        if (!(m & SDL_KMOD_ALT)) return 0;
        double x = e->button.x / zoom, y = e->button.y / zoom, x2, y2;
        mt_host_fingers = 1;
        second_finger(x, y, &x2, &y2);
        mt_host_dx = x2 - x; mt_host_dy = y2 - y;
        mt_host_fingers = (m & SDL_KMOD_SHIFT) ? 2 : 3;       /* 2: move together, 3: mirrored */
        button_down = 1; mouse_x = x; mouse_y = y;
        *ev = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = x, .y = y, .timestamp = isim_time() };
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_DOWN, .x = x2, .y = y2, .pad = 1 };
        reblit();
        return 1; }
    case SDL_EVENT_MOUSE_MOTION: {
        double x = e->motion.x / zoom, y = e->motion.y / zoom;
        mouse_x = x; mouse_y = y;
        if (mt_host_fingers && button_down) {
            double x2, y2; second_finger(x, y, &x2, &y2);
            *ev = (struct isim_event){ .type = EV_TOUCH_MOVE, .x = x, .y = y, .timestamp = isim_time() };
            pending[npending++] = (struct isim_event){ .type = EV_TOUCH_MOVE, .x = x2, .y = y2, .pad = 1 };
            reblit();
            return 1;
        }
        if (button_down) return 0;
        if (mt_overlay) reblit();
        *ev = (struct isim_event){ .type = EV_HOVER, .x = x, .y = y, .timestamp = isim_time() };
        return 1; }
    case SDL_EVENT_MOUSE_BUTTON_UP: {
        if (e->button.button != SDL_BUTTON_LEFT || !mt_host_fingers || !button_down) return 0;
        double x = e->button.x / zoom, y = e->button.y / zoom, x2, y2;
        second_finger(x, y, &x2, &y2);
        mt_host_fingers = 0; button_down = 0;
        *ev = (struct isim_event){ .type = EV_TOUCH_UP, .x = x, .y = y, .timestamp = isim_time() };
        pending[npending++] = (struct isim_event){ .type = EV_TOUCH_UP, .x = x2, .y = y2, .pad = 1 };
        reblit();
        return 1; }
    case SDL_EVENT_WINDOW_MOUSE_LEAVE:
        mouse_x = mouse_y = -1;
        *ev = (struct isim_event){ .type = EV_HOVER, .pad = 1, .timestamp = isim_time() };
        return 1;
    case SDL_EVENT_KEY_DOWN: case SDL_EVENT_KEY_UP: {
        int alt = (SDL_GetModState() & SDL_KMOD_ALT) != 0;
        if (alt != mt_overlay) { mt_overlay = alt; reblit(); }
        return 0; }
    case SDL_EVENT_TEXT_EDITING:
        *ev = (struct isim_event){ .type = EV_TEXT_EDITING, .key = e->edit.start, .mods = e->edit.length, .timestamp = isim_time() };
        snprintf(ev->text, sizeof ev->text, "%s", e->edit.text ? e->edit.text : "");
        return 1;
    default: return 0;
    }
}
