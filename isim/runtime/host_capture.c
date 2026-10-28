/* libisim_host capture, vision, export and speech helpers for isim's AVFoundation (capture, composition/export,
 * asset reader/writer), Vision and Speech. Like host_media.c, the heavy lifting happens in host tools run as child
 * processes, or in optional host libraries loaded with dlopen only when an app needs them:
 *   - simulated camera:      ffmpeg decoding ISIM_CAMERA=<image|video file> (looped, paced in real time), or the
 *                            host webcam (ISIM_CAMERA=webcam[:/dev/videoN]) through ffmpeg's v4l2 input
 *   - export / asset reader: ffmpeg (argument lists are built by the guest; run without a shell)
 *   - barcodes and QR codes: libzbar.so.0 (dlopen; optional)
 *   - text recognition:      the tesseract command (optional)
 *   - RAW photos:            LibRaw's dcraw_emu and raw-identify (libraw-bin; optional), libraw.so.23 for the
 *                            supported camera list (dlopen; optional)
 *   - speech recognition:    whisper.cpp (whisper-cli + ISIM_WHISPER_MODEL) or vosk-transcriber (+ ISIM_VOSK_MODEL)
 *   - language models:       llama.cpp's llama-server for a GGUF model (ISIM_LLM_MODEL; Foundation Models, issue #277)
 * Nothing here opens a camera or microphone unless the user configured it. Face detection has no host backend. */
#define _GNU_SOURCE
#include "guest_abi.h"
#include "platform.h"
#include <dlfcn.h>
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
extern char **environ;

struct isim_media_info { double duration, width, height, fps; int has_video, has_audio; };
ISIM_GUEST_ABI int isim_media_probe(const char *url, struct isim_media_info *info);
ISIM_GUEST_ABI int isim_image_create_bgra(int w, int h);
ISIM_GUEST_ABI void isim_image_update_bgra(int hd, const unsigned char *px, int w, int h);
ISIM_GUEST_ABI void isim_image_free(int hd);

/* argv with stdout on a pipe (*out), stderr on a pipe if errfd != NULL (else /dev/null), stdin /dev/null */
static pid_t spawn2(char *const argv[], int *out, int *errfd) {
    int o[2], e[2] = { -1, -1 };
    if (pipe2(o, O_CLOEXEC)) return -1;
    if (errfd && pipe2(e, O_CLOEXEC)) { close(o[0]); close(o[1]); return -1; }
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, o[1], 1);
    posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0);
    if (errfd) posix_spawn_file_actions_adddup2(&fa, e[1], 2);
    else posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    int ok = posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ) == 0;
    posix_spawn_file_actions_destroy(&fa);
    close(o[1]); if (errfd) close(e[1]);
    if (!ok) { close(o[0]); if (errfd) close(e[0]); return -1; }
    *out = o[0]; if (errfd) *errfd = e[0];
    return pid;
}
static int read_full(int fd, void *dst, size_t n) {
    size_t got = 0;
    while (got < n) {
        ssize_t r = read(fd, (char *)dst + got, n - got);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) return 0;
        got += (size_t)r;
    }
    return 1;
}
static char *run_capture(char *const argv[], size_t *len) {
    int fd; pid_t pid = spawn2(argv, &fd, NULL);
    if (pid < 0) return NULL;
    size_t cap = 1 << 14, n = 0; char *buf = malloc(cap + 1);
    for (;;) {
        if (n == cap) { cap *= 2; buf = realloc(buf, cap + 1); }
        ssize_t r = read(fd, buf + n, cap - n);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        n += (size_t)r;
    }
    close(fd);
    int st = 0; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    if (!WIFEXITED(st) || WEXITSTATUS(st) != 0) { free(buf); return NULL; }
    buf[n] = 0; if (len) *len = n;
    return buf;
}
static int on_path(const char *tool) {
    const char *p = getenv("PATH"); if (!p) return 0;
    char dir[4096];
    while (*p) {
        size_t n = strcspn(p, ":");
        if (n && n < sizeof dir - 64) {
            memcpy(dir, p, n); snprintf(dir + n, sizeof dir - n, "/%s", tool);
            if (access(dir, X_OK) == 0) return 1;
        }
        p += n; if (*p) p++;
    }
    return 0;
}
static int temp_path(char *buf, size_t n, const char *suffix) {
    const char *t = getenv("TMPDIR"); if (!t || !*t) t = "/tmp";
    snprintf(buf, n, "%s/isim-XXXXXX%s", t, suffix);
    int fd = mkstemps(buf, (int)strlen(suffix));
    if (fd < 0) return 0;
    close(fd); return 1;
}

/* ================= simulated camera ================= */
/* The source of a camera: ISIM_CAMERA, or for the front camera ISIM_CAMERA_FRONT when set (else the same source). */
static const char *camera_env(int front) {
    const char *f = front ? getenv("ISIM_CAMERA_FRONT") : NULL;
    return f && *f ? f : getenv("ISIM_CAMERA");
}
/* kind: 0 no camera, 1 still image, 2 video file, 3 webcam (v4l2). desc receives the source (file or device).
 * position: 0 back (ISIM_CAMERA), 1 front (ISIM_CAMERA_FRONT, else ISIM_CAMERA). */
ISIM_GUEST_ABI int isim_camera_source_at(int position, char *desc, int len) {
    const char *s = camera_env(position == 1);
    if (desc && len > 0) desc[0] = 0;
    if (!s || !*s) return 0;
    if (!strncmp(s, "webcam", 6)) {
        const char *dev = s[6] == ':' && s[7] ? s + 7 : "/dev/video0";
        if (desc) snprintf(desc, len, "%s", dev);
        return 3;
    }
    if (desc) snprintf(desc, len, "%s", s);
    if (access(s, R_OK)) return 0;
    const char *ext = strrchr(s, '.');
    static const char *still[] = { ".png", ".jpg", ".jpeg", ".bmp", ".gif", ".webp", ".tif", ".tiff", ".ppm", ".pgm", NULL };
    if (ext) for (int i = 0; still[i]; i++) if (!strcasecmp(ext, still[i])) return 1;
    return 2;
}
ISIM_GUEST_ABI int isim_camera_source(char *desc, int len) { return isim_camera_source_at(0, desc, len); }

#define MAX_CAMS 6
struct cam {
    int used, w, h; pid_t pid; int fd; pthread_t th; int thread;
    pthread_mutex_t m; pthread_cond_t cv;
    unsigned char *front, *back, *raw; long seq; int stop, eof;
    int img; long img_seq;
    double zoom, gain;                  /* digital zoom (centre crop) and brightness gain, set by isim_camera_set_effects */
};
static struct cam cams[MAX_CAMS];
static pthread_mutex_t cams_mtx = PTHREAD_MUTEX_INITIALIZER;

/* zoom > 1 shows the centre 1/zoom of the picture (bilinear), gain scales the colour */
static void cam_effects(const struct cam *c, const unsigned char *src, unsigned char *dst, double zoom, double gain) {
    int w = c->w, h = c->h;
    int g = (int)(gain * 256 + 0.5);
    if (zoom <= 1.0001) {
        for (size_t i = 0; i < (size_t)w * h; i++) {
            for (int k = 0; k < 3; k++) { int v = src[i * 4 + k] * g >> 8; dst[i * 4 + k] = (unsigned char)(v > 255 ? 255 : v); }
            dst[i * 4 + 3] = src[i * 4 + 3];
        }
        return;
    }
    double sw = w / zoom, sh = h / zoom, x0 = (w - sw) / 2, y0 = (h - sh) / 2;
    for (int y = 0; y < h; y++) {
        double fy = y0 + (y + 0.5) * sh / h - 0.5; if (fy < 0) fy = 0;
        int iy = (int)fy; double ty = fy - iy; int iy1 = iy + 1 < h ? iy + 1 : iy;
        for (int x = 0; x < w; x++) {
            double fx = x0 + (x + 0.5) * sw / w - 0.5; if (fx < 0) fx = 0;
            int ix = (int)fx; double tx = fx - ix; int ix1 = ix + 1 < w ? ix + 1 : ix;
            const unsigned char *a = src + ((size_t)iy * w + ix) * 4, *b = src + ((size_t)iy * w + ix1) * 4;
            const unsigned char *cc = src + ((size_t)iy1 * w + ix) * 4, *d = src + ((size_t)iy1 * w + ix1) * 4;
            unsigned char *o = dst + ((size_t)y * w + x) * 4;
            for (int k = 0; k < 4; k++) {
                double v = (a[k] * (1 - tx) + b[k] * tx) * (1 - ty) + (cc[k] * (1 - tx) + d[k] * tx) * ty;
                if (k < 3) v = v * g / 256;
                o[k] = (unsigned char)(v > 255 ? 255 : v + 0.5);
            }
        }
    }
}
static void *cam_thread(void *arg) {
    struct cam *c = arg;
    size_t n = (size_t)c->w * c->h * 4;
    for (;;) {
        if (!read_full(c->fd, c->raw, n)) break;
        pthread_mutex_lock(&c->m);
        double zoom = c->zoom, gain = c->gain;
        pthread_mutex_unlock(&c->m);
        if (zoom > 1.0001 || gain < 0.999 || gain > 1.001) cam_effects(c, c->raw, c->back, zoom, gain);
        else memcpy(c->back, c->raw, n);
        pthread_mutex_lock(&c->m);
        unsigned char *t = c->front; c->front = c->back; c->back = t;
        c->seq++;
        int stop = c->stop;
        pthread_cond_broadcast(&c->cv);
        pthread_mutex_unlock(&c->m);
        if (stop) break;
    }
    pthread_mutex_lock(&c->m); c->eof = 1; pthread_cond_broadcast(&c->cv); pthread_mutex_unlock(&c->m);
    return NULL;
}

/* Starts the simulated camera at up to max_side pixels (longest side; 0 = 1280) and fps frames per second.
 * Returns a handle (> 0) with the frame size in w x h, or 0 (no ISIM_CAMERA, unreadable source, no ffmpeg). */
ISIM_GUEST_ABI int isim_camera_open_at(int position, int max_side, double fps, int *w, int *h) {
    char src[1024];
    int kind = isim_camera_source_at(position, src, sizeof src);
    if (!kind) {
        const char *s = camera_env(position == 1);
        if (s && *s) fprintf(stderr, "isim camera: cannot read %s\n", s);
        return 0;
    }
    if (max_side <= 0) max_side = 1280;
    if (fps <= 0) fps = 30;
    int ow = 1280, oh = 720;
    if (kind != 3) {
        struct isim_media_info info;
        if (!isim_media_probe(src, &info) || info.width <= 0 || info.height <= 0) {
            fprintf(stderr, "isim camera: cannot read %s (needs ffprobe/ffmpeg on the host)\n", src);
            return 0;
        }
        double sc = fmax(info.width, info.height) > max_side ? max_side / fmax(info.width, info.height) : 1;
        ow = (int)lround(info.width * sc / 2) * 2; oh = (int)lround(info.height * sc / 2) * 2;
        if (ow < 2) ow = 2;
        if (oh < 2) oh = 2;
    }
    char vf[160], rate[32];
    snprintf(rate, sizeof rate, "%.3f", fps);
    if (kind == 3) snprintf(vf, sizeof vf, "scale=%d:%d:force_original_aspect_ratio=decrease,pad=%d:%d:(ow-iw)/2:(oh-ih)/2,fps=%.3f", ow, oh, ow, oh, fps);
    else snprintf(vf, sizeof vf, "scale=%d:%d,fps=%.3f", ow, oh, fps);
    char *img_argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-re", "-loop", "1", "-framerate", rate, "-i", src, "-an", "-vf", vf,
                         "-pix_fmt", "bgra", "-f", "rawvideo", "-", NULL };
    char *vid_argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-re", "-stream_loop", "-1", "-i", src, "-an", "-sn", "-vf", vf,
                         "-pix_fmt", "bgra", "-f", "rawvideo", "-", NULL };
    char *cam_argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-f", "v4l2", "-i", src, "-an", "-vf", vf,
                         "-pix_fmt", "bgra", "-f", "rawvideo", "-", NULL };
    pthread_mutex_lock(&cams_mtx);
    int slot = -1;
    for (int i = 0; i < MAX_CAMS; i++) if (!cams[i].used) { slot = i; break; }
    if (slot < 0) { pthread_mutex_unlock(&cams_mtx); fprintf(stderr, "isim camera: too many capture sessions\n"); return 0; }
    struct cam *c = &cams[slot];
    memset(c, 0, sizeof *c);
    c->used = 1;
    pthread_mutex_unlock(&cams_mtx);
    c->w = ow; c->h = oh;
    c->pid = spawn2(kind == 1 ? img_argv : kind == 2 ? vid_argv : cam_argv, &c->fd, NULL);
    if (c->pid < 0) { c->used = 0; fprintf(stderr, "isim camera: cannot start ffmpeg (the simulated camera needs ffmpeg on the host)\n"); return 0; }
    pthread_mutex_init(&c->m, NULL); pthread_cond_init(&c->cv, NULL);
    c->front = calloc((size_t)ow * oh, 4); c->back = calloc((size_t)ow * oh, 4); c->raw = calloc((size_t)ow * oh, 4);
    c->zoom = 1; c->gain = 1;
    c->thread = pthread_create(&c->th, NULL, cam_thread, c) == 0;
    *w = ow; *h = oh;
    return slot + 1;
}
ISIM_GUEST_ABI int isim_camera_open(int max_side, double fps, int *w, int *h) { return isim_camera_open_at(0, max_side, fps, w, h); }
static struct cam *cam_get(int h) { return h > 0 && h <= MAX_CAMS && cams[h - 1].used ? &cams[h - 1] : NULL; }

/* Copies the newest frame (BGRA, w*h*4 bytes) into out when it is newer than `seq`, waiting up to timeout seconds.
 * Returns the frame's sequence number (> seq), or 0 when nothing newer arrived (or the source ended). */
ISIM_GUEST_ABI long isim_camera_frame(int h, unsigned char *out, long seq, double timeout) {
    struct cam *c = cam_get(h);
    if (!c) return 0;
    struct timespec dl; clock_gettime(CLOCK_REALTIME, &dl);
    double t = dl.tv_sec + dl.tv_nsec / 1e9 + (timeout > 0 ? timeout : 0);
    dl.tv_sec = (time_t)t; dl.tv_nsec = (long)((t - (double)dl.tv_sec) * 1e9);
    pthread_mutex_lock(&c->m);
    while (c->seq <= seq && !c->eof && !c->stop && timeout > 0)
        if (pthread_cond_timedwait(&c->cv, &c->m, &dl) == ETIMEDOUT) break;
    long s = 0;
    if (c->seq > seq) { if (out) memcpy(out, c->front, (size_t)c->w * c->h * 4); s = c->seq; }
    pthread_mutex_unlock(&c->m);
    return s;
}
/* Digital zoom (1 = none; the centre 1/zoom of the picture) and brightness gain (1 = none; torch, flash, exposure
   bias) for the frames that follow. */
ISIM_GUEST_ABI void isim_camera_set_effects(int h, double zoom, double gain) {
    struct cam *c = cam_get(h);
    if (!c) return;
    pthread_mutex_lock(&c->m); c->zoom = zoom < 1 ? 1 : zoom; c->gain = gain < 0 ? 0 : gain; pthread_mutex_unlock(&c->m);
}
/* UI thread: an image handle showing the newest frame (0 before the first frame arrives) */
ISIM_GUEST_ABI int isim_camera_preview(int h) {
    struct cam *c = cam_get(h);
    if (!c) return 0;
    if (!c->img) c->img = isim_image_create_bgra(c->w, c->h);
    pthread_mutex_lock(&c->m);
    if (c->seq > c->img_seq) { isim_image_update_bgra(c->img, c->front, c->w, c->h); c->img_seq = c->seq; }
    long s = c->img_seq;
    pthread_mutex_unlock(&c->m);
    return s > 0 ? c->img : 0;
}
ISIM_GUEST_ABI void isim_camera_close(int h) {
    struct cam *c = cam_get(h);
    if (!c) return;
    pthread_mutex_lock(&c->m); c->stop = 1; pthread_cond_broadcast(&c->cv); pthread_mutex_unlock(&c->m);
    if (c->pid > 0) kill(c->pid, SIGKILL);
    if (c->thread) pthread_join(c->th, NULL);
    close(c->fd);
    int st; if (c->pid > 0) waitpid(c->pid, &st, 0);
    if (c->img) isim_image_free(c->img);
    free(c->front); free(c->back); free(c->raw);
    pthread_mutex_destroy(&c->m); pthread_cond_destroy(&c->cv);
    pthread_mutex_lock(&cams_mtx); memset(c, 0, sizeof *c); pthread_mutex_unlock(&cams_mtx);
}

/* ================= ffmpeg jobs (AVAssetExportSession, AVAssetWriter) ================= */
/* Runs `ffmpeg -nostdin -v error -progress pipe:1 -nostats <args...>` to completion. *progress receives the output
 * time in seconds as it advances; setting *cancel to non-zero stops the job. err receives ffmpeg's error output.
 * Returns 0 on success, the exit status, -1 when ffmpeg cannot be started, -2 when cancelled. */
ISIM_GUEST_ABI int isim_ffmpeg_run(const char *const *args, int nargs, double *progress, volatile int *cancel, char *err, long errlen) {
    char **argv = calloc((size_t)nargs + 8, sizeof *argv);
    int k = 0;
    argv[k++] = "ffmpeg"; argv[k++] = "-nostdin"; argv[k++] = "-v"; argv[k++] = "error";
    argv[k++] = "-progress"; argv[k++] = "pipe:1"; argv[k++] = "-nostats";
    for (int i = 0; i < nargs; i++) argv[k++] = (char *)args[i];
    argv[k] = NULL;
    if (err && errlen > 0) err[0] = 0;
    int ofd, efd;
    pid_t pid = spawn2(argv, &ofd, &efd);
    free(argv);
    if (pid < 0) { if (err) snprintf(err, errlen, "ffmpeg is not installed on the host"); return -1; }
    char line[512]; int ll = 0; long el = 0; int open_o = 1, open_e = 1, cancelled = 0;
    while (open_o || open_e) {
        struct pollfd p[2] = { { open_o ? ofd : -1, POLLIN, 0 }, { open_e ? efd : -1, POLLIN, 0 } };
        int r = poll(p, 2, 100);
        if (cancel && *cancel && !cancelled) { kill(pid, SIGKILL); cancelled = 1; }
        if (r <= 0) continue;
        if (p[0].revents) {
            char buf[1024]; ssize_t n = read(ofd, buf, sizeof buf);
            if (n <= 0) { open_o = 0; continue; }
            for (ssize_t i = 0; i < n; i++) {
                if (buf[i] == '\n' || ll == (int)sizeof line - 1) {
                    line[ll] = 0; ll = 0;
                    long long us;
                    if (progress && sscanf(line, "out_time_us=%lld", &us) == 1 && us >= 0) *progress = us / 1e6;
                } else line[ll++] = buf[i];
            }
        }
        if (p[1].revents) {
            char buf[1024]; ssize_t n = read(efd, buf, sizeof buf);
            if (n <= 0) { open_e = 0; continue; }
            if (err && el < errlen - 1) {
                long c = n < errlen - 1 - el ? n : errlen - 1 - el;
                memcpy(err + el, buf, (size_t)c); el += c; err[el] = 0;
            }
        }
    }
    close(ofd); close(efd);
    int st = 0; while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    if (cancelled) return -2;
    if (!WIFEXITED(st)) return 255;
    return WEXITSTATUS(st);
}

/* ================= decoded readers (AVAssetReader) ================= */
/* kind 0: video as BGRA frames of w x h at fps; kind 1: audio as interleaved float32 at rate/channels.
 * duration <= 0 reads to the end. Returns a handle (> 0) or 0. */
#define MAX_READERS 16
static struct { pid_t pid; int fd; } readers[MAX_READERS];
static pthread_mutex_t readers_mtx = PTHREAD_MUTEX_INITIALIZER;
ISIM_GUEST_ABI int isim_media_reader_open(const char *url, int kind, double start, double duration, int w, int h, double rate, int channels) {
    char ss[32], tt[32], vf[96], ar[32], ac[16];
    snprintf(ss, sizeof ss, "%.6f", start > 0 ? start : 0);
    snprintf(tt, sizeof tt, "%.6f", duration > 0 ? duration : 1e9);
    /* video rate < 0: the source's own frames (no frame-rate conversion; the caller knows their times) */
    if (kind == 0 && rate < 0) snprintf(vf, sizeof vf, "scale=%d:%d", w > 0 ? w : 2, h > 0 ? h : 2);
    else snprintf(vf, sizeof vf, "scale=%d:%d,fps=%.6f", w > 0 ? w : 2, h > 0 ? h : 2, rate > 0 ? rate : 30);
    snprintf(ar, sizeof ar, "%d", rate > 0 ? (int)rate : 44100);
    snprintf(ac, sizeof ac, "%d", channels > 0 ? channels : 2);
    char *vargv[] = { "ffmpeg", "-nostdin", "-v", "error", "-ss", ss, "-t", tt, "-i", (char *)url, "-an", "-sn", "-vf", vf,
                      "-pix_fmt", "bgra", "-fps_mode", rate < 0 ? "passthrough" : "auto", "-f", "rawvideo", "-", NULL };
    char *aargv[] = { "ffmpeg", "-nostdin", "-v", "error", "-ss", ss, "-t", tt, "-i", (char *)url, "-vn", "-sn",
                      "-f", "f32le", "-ac", ac, "-ar", ar, "-", NULL };
    int fd; pid_t pid = spawn2(kind == 0 ? vargv : aargv, &fd, NULL);
    if (pid < 0) { fprintf(stderr, "isim media: cannot start ffmpeg to read %s\n", url); return 0; }
    pthread_mutex_lock(&readers_mtx);
    int hd = 0;
    for (int i = 0; i < MAX_READERS; i++) if (!readers[i].pid) { readers[i].pid = pid; readers[i].fd = fd; hd = i + 1; break; }
    pthread_mutex_unlock(&readers_mtx);
    if (!hd) { kill(pid, SIGKILL); close(fd); int st; waitpid(pid, &st, 0); }
    return hd;
}
/* blocking: reads up to n bytes (fewer only at the end of the stream); returns the count */
ISIM_GUEST_ABI long isim_media_reader_read(int hd, void *buf, long n) {
    if (hd <= 0 || hd > MAX_READERS || !readers[hd - 1].pid) return 0;
    int fd = readers[hd - 1].fd;
    long got = 0;
    while (got < n) {
        ssize_t r = read(fd, (char *)buf + got, (size_t)(n - got));
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        got += r;
    }
    return got;
}
ISIM_GUEST_ABI void isim_media_reader_close(int hd) {
    if (hd <= 0 || hd > MAX_READERS || !readers[hd - 1].pid) return;
    pthread_mutex_lock(&readers_mtx);
    pid_t pid = readers[hd - 1].pid; int fd = readers[hd - 1].fd;
    readers[hd - 1].pid = 0;
    pthread_mutex_unlock(&readers_mtx);
    kill(pid, SIGKILL); close(fd);
    int st; waitpid(pid, &st, 0);
}

/* ================= Vision backends ================= */
static struct {
    int tried, ok;
    void *(*scanner_create)(void); void (*scanner_destroy)(void *);
    int (*scanner_set_config)(void *, int, int, int);
    void *(*image_create)(void); void (*image_destroy)(void *);
    void (*image_set_format)(void *, unsigned long); void (*image_set_size)(void *, unsigned, unsigned);
    void (*image_set_data)(void *, const void *, unsigned long, void *);
    int (*scan_image)(void *, void *);
    const void *(*first_symbol)(const void *); const void *(*symbol_next)(const void *);
    int (*symbol_get_type)(const void *); const char *(*get_symbol_name)(int);
    const char *(*symbol_get_data)(const void *); unsigned (*symbol_get_data_length)(const void *);
    int (*symbol_get_quality)(const void *); unsigned (*symbol_get_loc_size)(const void *);
    int (*symbol_get_loc_x)(const void *, unsigned); int (*symbol_get_loc_y)(const void *, unsigned);
} zb;
static pthread_mutex_t zb_mtx = PTHREAD_MUTEX_INITIALIZER;
static int zbar_load(void) {
    pthread_mutex_lock(&zb_mtx);
    if (!zb.tried) {
        zb.tried = 1;
        void *lib = dlopen("libzbar.so.0", RTLD_NOW | RTLD_LOCAL);
        if (lib) {
#define Z(field, name) *(void **)&zb.field = dlsym(lib, name)
            Z(scanner_create, "zbar_image_scanner_create"); Z(scanner_destroy, "zbar_image_scanner_destroy");
            Z(scanner_set_config, "zbar_image_scanner_set_config");
            Z(image_create, "zbar_image_create"); Z(image_destroy, "zbar_image_destroy");
            Z(image_set_format, "zbar_image_set_format"); Z(image_set_size, "zbar_image_set_size"); Z(image_set_data, "zbar_image_set_data");
            Z(scan_image, "zbar_scan_image"); Z(first_symbol, "zbar_image_first_symbol"); Z(symbol_next, "zbar_symbol_next");
            Z(symbol_get_type, "zbar_symbol_get_type"); Z(get_symbol_name, "zbar_get_symbol_name");
            Z(symbol_get_data, "zbar_symbol_get_data"); Z(symbol_get_data_length, "zbar_symbol_get_data_length");
            Z(symbol_get_quality, "zbar_symbol_get_quality"); Z(symbol_get_loc_size, "zbar_symbol_get_loc_size");
            Z(symbol_get_loc_x, "zbar_symbol_get_loc_x"); Z(symbol_get_loc_y, "zbar_symbol_get_loc_y");
#undef Z
            zb.ok = zb.scanner_create && zb.scanner_destroy && zb.scanner_set_config && zb.image_create && zb.image_destroy &&
                    zb.image_set_format && zb.image_set_size && zb.image_set_data && zb.scan_image && zb.first_symbol &&
                    zb.symbol_next && zb.symbol_get_type && zb.get_symbol_name && zb.symbol_get_data && zb.symbol_get_data_length &&
                    zb.symbol_get_quality && zb.symbol_get_loc_size && zb.symbol_get_loc_x && zb.symbol_get_loc_y;
        }
        if (!zb.ok) fprintf(stderr, "isim vision: barcode and QR code detection needs libzbar (zbar) on the host\n");
    }
    int ok = zb.ok;
    pthread_mutex_unlock(&zb_mtx);
    return ok;
}

/* what the host can do: 1 barcodes/QR (zbar), 2 text recognition (tesseract), 3 face detection (never) */
ISIM_GUEST_ABI int isim_vision_available(int kind) {
    if (kind == 1) return zbar_load();
    if (kind == 2) return on_path("tesseract");
    if (kind == 3) return on_path("ZXingReader");       /* zxing-cpp's reader: Aztec, Data Matrix, Micro QR */
    return 0;
}

/* The symbols zbar cannot read (Aztec, Data Matrix, Micro QR, rMQR, MaxiCode) through zxing-cpp's ZXingReader:
   appends lines in isim_vision_barcodes' format to out. Returns 0 when the tool is missing or fails. */
static int zxing_scan(const unsigned char *gray, int w, int h, char **out, size_t *n, size_t *cap) {
    if (!on_path("ZXingReader")) return 0;
    char path[512];
    if (!temp_path(path, sizeof path, ".pgm")) return 0;
    FILE *f = fopen(path, "wb");
    if (!f) { unlink(path); return 0; }
    fprintf(f, "P5\n%d %d\n255\n", w, h);
    fwrite(gray, 1, (size_t)w * h, f);
    fclose(f);
    char *argv[] = { "ZXingReader", "-format", "Aztec,DataMatrix,MicroQRCode,rMQRCode,MaxiCode", path, NULL };
    char *res = run_capture(argv, NULL);
    unlink(path);
    if (!res) return 1;                                  /* nothing found (or unreadable): no symbols */
    char fmt[64] = "", pos[256] = "", bytes[8192] = "";
    for (char *line = res; line && *line; ) {
        char *end = strchr(line, '\n'); if (end) *end = 0;
        int last = !end || !end[1] || end[1] == '\n';
        if (!strncmp(line, "Format:", 7)) sscanf(line + 7, " %63s", fmt);
        else if (!strncmp(line, "Position:", 9)) snprintf(pos, sizeof pos, "%s", line + 9);
        else if (!strncmp(line, "Bytes:", 6)) snprintf(bytes, sizeof bytes, "%s", line + 6);
        if ((!*line || last) && *fmt) {
            const char *name = !strcmp(fmt, "MicroQRCode") ? "MicroQR" : fmt;
            size_t need = *n + 64 + strlen(name) + strlen(pos) * 2 + strlen(bytes);
            if (need > *cap) { *cap = need * 2; *out = realloc(*out, *cap); }
            *n += (size_t)sprintf(*out + *n, "%s\t100\t", name);
            int first = 1, x, y, k; const char *p = pos;
            while (sscanf(p, " %dx%d%n", &x, &y, &k) == 2) { *n += (size_t)sprintf(*out + *n, "%s%d,%d", first ? "" : ";", x, y); first = 0; p += k; }
            (*out)[(*n)++] = '\t';
            for (const char *b = bytes; *b; b++) if (*b != ' ') (*out)[(*n)++] = (char)tolower((unsigned char)*b);
            (*out)[(*n)++] = '\n'; (*out)[*n] = 0;
            fmt[0] = pos[0] = bytes[0] = 0;
        }
        line = end ? end + 1 : NULL;
    }
    free(res);
    return 1;
}

/* Scans BGRA pixels for barcodes. Returns malloc'd lines "SYMBOLOGY\tQUALITY\tx,y;x,y;...\tHEXDATA\n" (pixel
 * corner points), "" when nothing was found, NULL without zbar. Free with isim_media_free.
 * extended: also look for Aztec, Data Matrix and Micro QR with zxing-cpp's ZXingReader (a process per call). */
ISIM_GUEST_ABI char *isim_vision_barcodes_ex(const unsigned char *bgra, int w, int h, int stride, int extended) {
    int zbar = zbar_load(), zx = extended && on_path("ZXingReader");
    if (!bgra || w <= 0 || h <= 0 || (!zbar && !zx)) return NULL;
    if (stride <= 0) stride = w * 4;
    unsigned char *gray = malloc((size_t)w * h);
    for (int y = 0; y < h; y++) {
        const unsigned char *p = bgra + (size_t)y * stride;
        for (int x = 0; x < w; x++, p += 4) gray[(size_t)y * w + x] = (unsigned char)((p[0] * 29 + p[1] * 150 + p[2] * 77) >> 8);
    }
    size_t cap = 256, n = 0; char *out = malloc(cap); out[0] = 0;
    if (zx) zxing_scan(gray, w, h, &out, &n, &cap);
    if (!zbar) { free(gray); return out; }
    void *sc = zb.scanner_create();
    zb.scanner_set_config(sc, 0, 0 /* ZBAR_CFG_ENABLE */, 1);
    void *img = zb.image_create();
    zb.image_set_format(img, 0x30303859ul /* 'Y800' */);
    zb.image_set_size(img, (unsigned)w, (unsigned)h);
    zb.image_set_data(img, gray, (unsigned long)w * h, NULL);
    zb.scan_image(sc, img);
    for (const void *s = zb.first_symbol(img); s; s = zb.symbol_next(s)) {
        const char *name = zb.get_symbol_name(zb.symbol_get_type(s));
        unsigned dl = zb.symbol_get_data_length(s), loc = zb.symbol_get_loc_size(s);
        const unsigned char *d = (const unsigned char *)zb.symbol_get_data(s);
        size_t need = n + 64 + strlen(name ? name : "") + (size_t)loc * 24 + (size_t)dl * 2;
        if (need > cap) { cap = need * 2; out = realloc(out, cap); }
        n += (size_t)sprintf(out + n, "%s\t%d\t", name ? name : "?", zb.symbol_get_quality(s));
        for (unsigned i = 0; i < loc; i++) n += (size_t)sprintf(out + n, "%s%d,%d", i ? ";" : "", zb.symbol_get_loc_x(s, i), zb.symbol_get_loc_y(s, i));
        out[n++] = '\t';
        for (unsigned i = 0; i < dl; i++) n += (size_t)sprintf(out + n, "%02x", d[i]);
        out[n++] = '\n'; out[n] = 0;
    }
    zb.image_destroy(img); zb.scanner_destroy(sc);
    free(gray);
    return out;
}
ISIM_GUEST_ABI char *isim_vision_barcodes(const unsigned char *bgra, int w, int h, int stride) { return isim_vision_barcodes_ex(bgra, w, h, stride, 0); }

/* Text recognition with the host's tesseract. langs: tesseract language codes joined by '+' ("eng", "eng+fra").
 * Returns tesseract's TSV output (level, page, block, par, line, word, left, top, width, height, conf, text),
 * or NULL without tesseract. Free with isim_media_free. */
ISIM_GUEST_ABI char *isim_vision_text(const unsigned char *bgra, int w, int h, int stride, const char *langs) {
    if (!bgra || w <= 0 || h <= 0 || !on_path("tesseract")) return NULL;
    if (stride <= 0) stride = w * 4;
    char path[512];
    if (!temp_path(path, sizeof path, ".ppm")) return NULL;
    FILE *f = fopen(path, "wb");
    if (!f) { unlink(path); return NULL; }
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    unsigned char *row = malloc((size_t)w * 3);
    for (int y = 0; y < h; y++) {
        const unsigned char *p = bgra + (size_t)y * stride;
        for (int x = 0; x < w; x++) {      /* composite over white (premultiplied BGRA) */
            unsigned a = p[4 * x + 3];
            row[3 * x] = (unsigned char)(p[4 * x + 2] + 255 - a); row[3 * x + 1] = (unsigned char)(p[4 * x + 1] + 255 - a); row[3 * x + 2] = (unsigned char)(p[4 * x] + 255 - a);
        }
        fwrite(row, 3, (size_t)w, f);
    }
    free(row); fclose(f);
    char *argv[] = { "tesseract", path, "stdout", "-l", (char *)(langs && *langs ? langs : "eng"), "tsv", NULL };
    char *out = run_capture(argv, NULL);
    unlink(path);
    if (!out) fprintf(stderr, "isim vision: tesseract failed (is the language data for '%s' installed?)\n", langs && *langs ? langs : "eng");
    return out;
}
/* installed tesseract languages, one per line (NULL without tesseract) */
ISIM_GUEST_ABI char *isim_vision_text_languages(void) {
    if (!on_path("tesseract")) return NULL;
    char *argv[] = { "tesseract", "--list-langs", NULL };
    return run_capture(argv, NULL);
}

/* ================= RAW photos (Core Image's CIRAWFilter) ================= */
ISIM_GUEST_ABI int isim_raw_available(void) { return on_path("dcraw_emu") && on_path("raw-identify"); }
/* raw-identify -v: the camera, exposure and size metadata as text (NULL: no LibRaw tools or not a RAW file) */
ISIM_GUEST_ABI char *isim_raw_identify(const char *path) {
    if (!path || !on_path("raw-identify")) return NULL;
    char *argv[] = { "raw-identify", "-v", (char *)path, NULL };
    char *out = run_capture(argv, NULL);
    if (out && !strstr(out, "Filter pattern") && !strstr(out, "Raw colors")) { free(out); out = NULL; }
    return out;
}
/* Decodes a RAW file to linear 16-bit RGB (sRGB primaries, the camera's as-shot white balance, not rotated) with
 * dcraw_emu. half: half size (draft mode); highlight: dcraw's -H mode (0 clip, 2 blend). *rgb is malloc'd w*h*3
 * values (free with isim_media_free). Returns 0 when the tools are missing or the file is not readable RAW. */
ISIM_GUEST_ABI int isim_raw_decode(const char *path, int half, int highlight, int *w, int *h, unsigned short **rgb) {
    if (!path || !rgb || !on_path("dcraw_emu")) return 0;
    char hl[8]; snprintf(hl, sizeof hl, "%d", highlight < 0 ? 0 : highlight > 9 ? 9 : highlight);
    char *argv[16]; int n = 0;
    argv[n++] = "dcraw_emu"; argv[n++] = "-4"; argv[n++] = "-o"; argv[n++] = "1"; argv[n++] = "-w";
    argv[n++] = "-t"; argv[n++] = "0"; argv[n++] = "-H"; argv[n++] = hl;
    if (half) argv[n++] = "-h";
    argv[n++] = "-Z"; argv[n++] = "-"; argv[n++] = (char *)path; argv[n] = NULL;
    size_t len = 0;
    char *out = run_capture(argv, &len);
    if (!out) return 0;
    int W = 0, H = 0, max = 0, off = 0;
    if (sscanf(out, "P6 %d %d %d%n", &W, &H, &max, &off) != 3 || W <= 0 || H <= 0 || max != 65535 ||
        (size_t)off + 1 + (size_t)W * H * 6 > len) { free(out); return 0; }
    const unsigned char *p = (const unsigned char *)out + off + 1;
    unsigned short *px = malloc(sizeof(unsigned short) * 3 * (size_t)W * H);
    for (size_t i = 0; i < (size_t)W * H * 3; i++) px[i] = (unsigned short)(p[2 * i] << 8 | p[2 * i + 1]);
    free(out);
    *w = W; *h = H; *rgb = px;
    return 1;
}
/* LibRaw's supported cameras, one per line (NULL without libraw.so.23) */
ISIM_GUEST_ABI char *isim_raw_camera_list(void) {
    void *lib = dlopen("libraw.so.23", RTLD_NOW | RTLD_LOCAL);
    if (!lib) return NULL;
    const char **(*list)(void) = (const char **(*)(void))dlsym(lib, "libraw_cameraList");
    int (*count)(void) = (int (*)(void))dlsym(lib, "libraw_cameraCount");
    if (!list || !count) return NULL;
    const char **l = list(); int c = count();
    size_t total = 1;
    for (int i = 0; i < c && l[i]; i++) total += strlen(l[i]) + 1;
    char *out = malloc(total), *o = out;
    for (int i = 0; i < c && l[i]; i++) { size_t k = strlen(l[i]); memcpy(o, l[i], k); o[k] = '\n'; o += k + 1; }
    *o = 0;
    return out;
}

/* ================= speech recognition ================= */
static const char *whisper_tool(void) {
    static const char *tools[] = { "whisper-cli", "whisper-cpp", NULL };
    for (int i = 0; tools[i]; i++) if (on_path(tools[i])) return tools[i];
    return NULL;
}
/* 1 whisper.cpp with ISIM_WHISPER_MODEL, 2 vosk-transcriber with ISIM_VOSK_MODEL, 0 nothing */
ISIM_GUEST_ABI int isim_speech_available(void) {
    const char *wm = getenv("ISIM_WHISPER_MODEL"), *vm = getenv("ISIM_VOSK_MODEL");
    if (wm && *wm && !access(wm, R_OK) && whisper_tool()) return 1;
    if (vm && *vm && !access(vm, R_OK) && on_path("vosk-transcriber")) return 2;
    return 0;
}
/* Transcribes 16 kHz mono float PCM. lang: two-letter code ("en"); prompt: words and phrases that bias recognition
 * (whisper.cpp's --prompt; Vosk ignores it), or NULL. Returns malloc'd lines "START\tEND\tTEXT\n" (seconds; -1 when the
 * backend gives no times) or NULL. Free with isim_media_free. */
ISIM_GUEST_ABI char *isim_speech_transcribe_prompt(const float *pcm, long frames, const char *lang, const char *prompt) {
    int kind = isim_speech_available();
    if (!kind || !pcm || frames <= 0) return NULL;
    char wav[512];
    if (!temp_path(wav, sizeof wav, ".wav")) return NULL;
    FILE *f = fopen(wav, "wb");
    if (!f) { unlink(wav); return NULL; }
    unsigned data = (unsigned)frames * 2, rate = 16000;
    unsigned char hd[44] = { 'R','I','F','F', 0,0,0,0, 'W','A','V','E', 'f','m','t',' ', 16,0,0,0, 1,0, 1,0,
                             0,0,0,0, 0,0,0,0, 2,0, 16,0, 'd','a','t','a', 0,0,0,0 };
    unsigned riff = 36 + data, br = rate * 2;
    memcpy(hd + 4, &riff, 4); memcpy(hd + 24, &rate, 4); memcpy(hd + 28, &br, 4); memcpy(hd + 40, &data, 4);
    fwrite(hd, 1, 44, f);
    for (long i = 0; i < frames; i++) { float x = fmaxf(-1, fminf(1, pcm[i])); short s = (short)lrintf(x * 32767); fwrite(&s, 2, 1, f); }
    fclose(f);
    char *raw = NULL;
    char l2[8]; snprintf(l2, sizeof l2, "%.2s", lang && *lang ? lang : "en");
    if (kind == 1) {
        char *argv[] = { (char *)whisper_tool(), "-m", getenv("ISIM_WHISPER_MODEL"), "-f", wav, "-l", l2, "-np",
                         prompt && *prompt ? "--prompt" : NULL, (char *)prompt, NULL };
        raw = run_capture(argv, NULL);
    } else {
        char *argv[] = { "vosk-transcriber", "-m", getenv("ISIM_VOSK_MODEL"), "-i", wav, NULL };
        raw = run_capture(argv, NULL);
    }
    unlink(wav);
    if (!raw) return NULL;
    size_t cap = strlen(raw) + 64, n = 0; char *out = malloc(cap); out[0] = 0;
    char *save = NULL;
    for (char *line = strtok_r(raw, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        int h1, m1, h2, m2; double s1, s2; int off = 0;
        double a = -1, b = -1;
        /* whisper.cpp: "[00:00:00.000 --> 00:00:02.000]  text" */
        if (sscanf(line, " [%d:%d:%lf --> %d:%d:%lf]%n", &h1, &m1, &s1, &h2, &m2, &s2, &off) == 6 && off > 0) {
            a = h1 * 3600 + m1 * 60 + s1; b = h2 * 3600 + m2 * 60 + s2; line += off;
        }
        while (*line == ' ' || *line == '\t') line++;
        if (!*line) continue;
        size_t need = n + strlen(line) + 64;
        if (need > cap) { cap = need * 2; out = realloc(out, cap); }
        n += (size_t)sprintf(out + n, "%.3f\t%.3f\t%s\n", a, b, line);
    }
    free(raw);
    return out;
}
ISIM_GUEST_ABI char *isim_speech_transcribe(const float *pcm, long frames, const char *lang) {
    return isim_speech_transcribe_prompt(pcm, frames, lang, NULL);
}

/* ================= AVAudioSession events (the `audio` script command) ================= */
static char as_q[32][64];
static int asq_head, asq_count;
static pthread_mutex_t asq_mtx = PTHREAD_MUTEX_INITIALIZER;
void isim_audio_session_post(const char *ev) {
    pthread_mutex_lock(&asq_mtx);
    if (asq_count < 32) { snprintf(as_q[(asq_head + asq_count) % 32], 64, "%s", ev); asq_count++; }
    pthread_mutex_unlock(&asq_mtx);
}
ISIM_GUEST_ABI int isim_audio_session_poll(char *buf, int len) {
    pthread_mutex_lock(&asq_mtx);
    int got = asq_count > 0;
    if (got) { snprintf(buf, len, "%s", as_q[asq_head]); asq_head = (asq_head + 1) % 32; asq_count--; }
    pthread_mutex_unlock(&asq_mtx);
    return got;
}

/* ================= language models (Foundation Models, issue #277) ================= */
/* llama.cpp's llama-server serving a GGUF model on a free local port, started once (it dies with the runtime): writes
   its OpenAI-compatible base URL (http://127.0.0.1:PORT/v1) to `out` and returns 1 once it answers /health (loading a
   model can take a while); 0 if llama-server is missing or does not come up */
static int llm_health(int port) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 0;
    struct sockaddr_in a = { .sin_family = AF_INET, .sin_port = htons((unsigned short)port) };
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    int ok = 0;
    if (connect(fd, (struct sockaddr *)&a, sizeof a) == 0) {
        const char *req = "GET /health HTTP/1.0\r\nHost: 127.0.0.1\r\n\r\n";
        char buf[64] = { 0 };
        if (write(fd, req, strlen(req)) > 0 && read(fd, buf, sizeof buf - 1) > 12) ok = strncmp(buf + 9, "200", 3) == 0;
    }
    close(fd);
    return ok;
}
ISIM_GUEST_ABI int isim_llm_server(const char *gguf, char *out, int cap) {
    static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;
    static int state;                               /* 0 not tried, 1 running, -1 failed */
    static char url[64];
    pthread_mutex_lock(&m);
    if (!state) {
        state = -1;
        int port = 0, fd = socket(AF_INET, SOCK_STREAM, 0);
        struct sockaddr_in a = { .sin_family = AF_INET };
        a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
        socklen_t len = sizeof a;
        if (fd >= 0 && bind(fd, (struct sockaddr *)&a, sizeof a) == 0 && getsockname(fd, (struct sockaddr *)&a, &len) == 0) port = ntohs(a.sin_port);
        if (fd >= 0) close(fd);
        if (gguf && !access(gguf, R_OK) && port && on_path("llama-server")) {
            char p[16]; snprintf(p, sizeof p, "%d", port);
            char *argv[] = { "llama-server", "-m", (char *)gguf, "--host", "127.0.0.1", "--port", p, "--jinja", NULL };
            struct isim_spawn s = { .path = "llama-server", .argv = argv, .null_stdin = 1, .null_stdout = 1, .null_stderr = 1, .die_with_parent = 1 };
            pid_t pid = isim_spawn(&s);
            for (int i = 0; pid > 0 && i < 1200; i++) {               /* up to 5 minutes */
                if (llm_health(port)) { snprintf(url, sizeof url, "http://127.0.0.1:%d/v1", port); state = 1; break; }
                int st;
                if (waitpid(pid, &st, WNOHANG) == pid) break;           /* it exited: a bad model, say */
                struct timespec t = { 0, 250 * 1000 * 1000 }; nanosleep(&t, NULL);
            }
            if (state != 1 && pid > 0) { kill(pid, SIGKILL); int st; waitpid(pid, &st, 0); }
        }
    }
    int ok = state == 1;
    if (ok && out && cap > 0) snprintf(out, (size_t)cap, "%s", url);
    pthread_mutex_unlock(&m);
    return ok;
}
