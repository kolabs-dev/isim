/* Real X input for the isim window, for tests of the window's controls (test_window_clicks.py): the same events a
 * mouse and keyboard send (XTest), not script commands.
 *
 *   xinput where                 the window's position and size: "X Y W H"
 *   xinput click X Y [shift]     a left click at window points (Shift held)
 *   xinput type TEXT             type TEXT (ASCII)
 *   xinput key NAME              press a key (X keysym name: Return, Escape, Tab, BackSpace, ...)
 *   xinput list                  every window titled isim..., shown or not (debugging)
 *
 * The window is the top-level window whose title starts with "isim". Build: cc xinput.c -lX11 -lXtst */
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/extensions/XTest.h>
#include <X11/keysym.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static Window find(Display *d, Window w) {
    char *name = NULL;
    XWindowAttributes wa;
    if (XFetchName(d, w, &name) && name) {
        int ok = !strncmp(name, "isim", 4) && XGetWindowAttributes(d, w, &wa) && wa.map_state == IsViewable;   /* shown */
        XFree(name);
        if (ok) return w;
    }
    Window r, p, *kids; unsigned n;
    if (!XQueryTree(d, w, &r, &p, &kids, &n)) return 0;
    Window f = 0;
    for (unsigned i = 0; i < n && !f; i++) f = find(d, kids[i]);
    if (kids) XFree(kids);
    return f;
}

static void key(Display *d, KeySym ks, int shift) {
    KeyCode kc = XKeysymToKeycode(d, ks), sk = XKeysymToKeycode(d, XK_Shift_L);
    if (!kc) { fprintf(stderr, "xinput: no key for keysym %lu\n", (unsigned long)ks); return; }
    if (shift) XTestFakeKeyEvent(d, sk, True, 0);
    XTestFakeKeyEvent(d, kc, True, 0); XTestFakeKeyEvent(d, kc, False, 0);
    if (shift) XTestFakeKeyEvent(d, sk, False, 0);
    XFlush(d); usleep(15000);
}

static void list(Display *d, Window w, int depth) {      /* every window titled isim..., for debugging */
    char *name = NULL; XWindowAttributes wa;
    if (XFetchName(d, w, &name) && name) {
        if (!strncmp(name, "isim", 4) && XGetWindowAttributes(d, w, &wa))
            printf("%#lx %s %dx%d+%d+%d \"%s\"\n", (unsigned long)w, wa.map_state == IsViewable ? "shown" : "hidden",
                   wa.width, wa.height, wa.x, wa.y, name);
        XFree(name);
    }
    Window r, p, *kids; unsigned n;
    if (!XQueryTree(d, w, &r, &p, &kids, &n)) return;
    for (unsigned i = 0; i < n; i++) list(d, kids[i], depth + 1);
    if (kids) XFree(kids);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: xinput where | click X Y [shift] | type TEXT | key NAME\n"); return 1; }
    Display *d = XOpenDisplay(NULL);
    if (!d) { fprintf(stderr, "xinput: no display\n"); return 2; }
    if (!strcmp(argv[1], "list")) { list(d, DefaultRootWindow(d), 0); return 0; }
    Window w = find(d, DefaultRootWindow(d));
    if (!w) { fprintf(stderr, "xinput: no isim window\n"); return 3; }
    int x, y; Window child; XWindowAttributes a;
    XGetWindowAttributes(d, w, &a);
    XTranslateCoordinates(d, w, DefaultRootWindow(d), 0, 0, &x, &y, &child);
    if (!strcmp(argv[1], "where")) { printf("%d %d %d %d\n", x, y, a.width, a.height); return 0; }
    if (!strcmp(argv[1], "click") && argc >= 4) {
        int shift = argc > 4 && !strcmp(argv[4], "shift");
        KeyCode sk = XKeysymToKeycode(d, XK_Shift_L);
        XTestFakeMotionEvent(d, -1, x + atoi(argv[2]), y + atoi(argv[3]), 0); XFlush(d); usleep(50000);
        if (shift) { XTestFakeKeyEvent(d, sk, True, 0); XFlush(d); usleep(20000); }
        XTestFakeButtonEvent(d, 1, True, 0); XFlush(d); usleep(50000);
        XTestFakeButtonEvent(d, 1, False, 0); XFlush(d); usleep(20000);
        if (shift) { XTestFakeKeyEvent(d, sk, False, 0); XFlush(d); }
    } else if (!strcmp(argv[1], "type") && argc >= 3) {
        for (const char *s = argv[2]; *s; s++) {
            static const char shifted[] = "~!@#$%^&*()_+{}|:\"<>?";
            static const char base[] = "`1234567890-=[]\\;',./";
            char c = *s, ch[2] = { 0, 0 };
            int shift = (c >= 'A' && c <= 'Z') || strchr(shifted, c) != NULL;
            if (strchr(shifted, c)) c = base[strchr(shifted, c) - shifted];
            if (c >= 'A' && c <= 'Z') c = (char)(c - 'A' + 'a');
            ch[0] = c;
            KeySym ks = c == ' ' ? XK_space : c == '-' ? XK_minus : c == '=' ? XK_equal : c == '.' ? XK_period
                      : c == '/' ? XK_slash : c == ';' ? XK_semicolon : c == ',' ? XK_comma : c == '\'' ? XK_apostrophe
                      : c == '[' ? XK_bracketleft : c == ']' ? XK_bracketright : c == '\\' ? XK_backslash
                      : c == '`' ? XK_grave : XStringToKeysym(ch);
            key(d, ks, shift);
        }
    } else if (!strcmp(argv[1], "key") && argc >= 3) {
        key(d, XStringToKeysym(argv[2]), 0);
    } else {
        fprintf(stderr, "xinput: bad arguments\n");
        return 1;
    }
    XCloseDisplay(d);
    return 0;
}
