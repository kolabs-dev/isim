/* libisim_host Office documents: Word, Excel, PowerPoint and OpenDocument files converted to PDF by the host's
 * LibreOffice (soffice --headless --convert-to pdf), for Quick Look's previews (QuickLook.m). Passthrough: LibreOffice
 * renders the document; without it the conversion fails and the preview shows the file's generic page. Each
 * conversion uses a private LibreOffice profile (next to its output) so it neither waits for nor disturbs an
 * instance the person is running. */
#include "guest_abi.h"
#include "platform.h"
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>

/* converts src into outdir/<its name>.pdf; returns 1 and the PDF's path in out, or 0 (no LibreOffice, or it failed) */
ISIM_GUEST_ABI int isim_office_to_pdf(const char *src, const char *outdir, char *out, int cap) {
    if (!src || !outdir || !out || cap <= 0) return 0;
    out[0] = 0;
    char profile[1100], env[1200];
    snprintf(profile, sizeof profile, "%s/.profile", outdir);
    snprintf(env, sizeof env, "-env:UserInstallation=file://%s", profile);
    const char *base = strrchr(src, '/'); base = base ? base + 1 : src;
    const char *dot = strrchr(base, '.');
    int stem = dot && dot != base ? (int)(dot - base) : (int)strlen(base);
    const char *programs[] = { "soffice", "libreoffice", NULL };
    for (int i = 0; programs[i]; i++) {
        char *argv[] = { (char *)programs[i], env, "--headless", "--norestore", "--nolockcheck", "--convert-to", "pdf",
                         "--outdir", (char *)outdir, (char *)src, NULL };
        struct isim_spawn sp = { .path = programs[i], .argv = argv, .null_stdin = 1, .null_stdout = 1, .null_stderr = 1,
                                 .close_others = 1, .die_with_parent = 1 };
        pid_t pid = isim_spawn(&sp);
        if (pid < 0) continue;                                    /* not installed under this name */
        int st = 0;
        while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
        snprintf(out, (size_t)cap, "%s/%.*s.pdf", outdir, stem, base);
        struct stat sb;
        if (WIFEXITED(st) && WEXITSTATUS(st) == 0 && stat(out, &sb) == 0 && sb.st_size > 0) return 1;
        fprintf(stderr, "isim office: LibreOffice could not convert %s\n", src);
        out[0] = 0;
        return 0;
    }
    fprintf(stderr, "isim office: %s needs LibreOffice on the host (soffice) to be previewed\n", base);
    return 0;
}
