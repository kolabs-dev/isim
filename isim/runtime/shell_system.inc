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
 *   shell -> app   "openurl URL", "launchtask BUNDLE TASK", "reload" (to the home screen), "bgtask TASK" (to the app)
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

static void sys_handle_msg(int from, const struct shell_msg *m) {
    const char *verb = m->a;
    if (!strcmp(verb, "appinfo")) {
        struct sys_appinfo *ai = sys_info(m->b);
        if (!ai) { if (nappinfo >= 128) return; ai = &appinfo[nappinfo++]; snprintf(ai->path, sizeof ai->path, "%s", m->b); }
        const char *sep = strchr(m->c, '\x1f');
        snprintf(ai->name, sizeof ai->name, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        snprintf(ai->icon, sizeof ai->icon, "%s", sep ? sep + 1 : "");
    } else if (!strcmp(verb, "openurl")) {
        sys_send_text(0, "openurl %s", m->c);
    } else if (!strcmp(verb, "reload-home")) {
        sys_send_text(0, "reload");
    } else if (!strcmp(verb, "launch-bg")) {
        const char *sep = strchr(m->c, '\x1f');
        char exe[512]; snprintf(exe, sizeof exe, "%.*s", sep ? (int)(sep - m->c) : (int)strlen(m->c), m->c);
        sys_launch_background(m->b, exe, sep ? sep + 1 : NULL);
    } else fprintf(stderr, "isim shell: unknown system request '%s' from %s\n", verb, clients[from].bundle);
}

/* script commands for the system (EV_SHELL_CMD); returns 1 when handled */
static int sys_command(const char *text) {
    char verb[32] = {0}; int n = 0;
    sscanf(text, "%31s%n", verb, &n);
    const char *args = text + n; while (*args == ' ') args++;
    if (!strcmp(verb, "bgtask")) { sys_send_text(0, "launchtask %s", args); return 1; }  /* the home screen resolves the bundle id */
    if (!strcmp(verb, "openurl")) { sys_send_text(0, "openurl %s", args); return 1; }
    fprintf(stderr, "isim shell: '%s' is not available\n", verb);
    return 1;
}
