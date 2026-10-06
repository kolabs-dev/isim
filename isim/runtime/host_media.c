/* libisim_host media: video playback, text-to-speech, audio input and remote-control commands for isim's
 * AVFoundation / AVKit / MediaPlayer. Everything heavy runs in child processes of host tools, like the
 * compressed-audio decoder in host_audio.c, so codecs and their threads stay out of the app process:
 *   - probing and decoding video:   ffprobe / ffmpeg  (local files and http(s) URLs)
 *   - speech synthesis:              espeak-ng (or espeak)
 *   - microphone (opt-in):           ffmpeg -f pulse, or arecord
 * Video frames are decoded to BGRA at a bounded size by `ffmpeg -f rawvideo` and streamed by a host thread
 * into a small ring; the UI thread picks the frame for the current playback time into an image handle
 * (host_image.c) that UIKit draws. The soundtrack streams into the audio mixer (host_audio.c). */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
extern char **environ;

int isim_image_create_bgra(int w, int h);
void isim_image_update_bgra(int hd, const unsigned char *px, int w, int h);
void isim_image_free(int hd);
int isim_image_load_data(const void *data, unsigned long len, double *w, double *h);
int isim_audio_stream_open(double volume);
long isim_audio_stream_write(int s, const float *pcm, long frames);
void isim_audio_stream_control(int s, int paused, double volume);
void isim_audio_stream_close(int s);
int isim_audio_decode_file(const char *path, float **out, long *frames, int *channels, double *rate);

static double mono_now(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }

/* starts argv with stdout on a pipe (returned in *fd), stdin and stderr on /dev/null */
static pid_t spawn_reader(char *const argv[], int *fd) {
    int fds[2];
    if (pipe2(fds, O_CLOEXEC)) return -1;
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, fds[1], 1);
    posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    int ok = posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ) == 0;
    posix_spawn_file_actions_destroy(&fa);
    close(fds[1]);
    if (!ok) { close(fds[0]); return -1; }
    *fd = fds[0];
    return pid;
}
/* runs argv to completion; returns its whole stdout (malloc'd) or NULL if it failed */
static char *run_capture(char *const argv[], size_t *len) {
    int fd; pid_t pid = spawn_reader(argv, &fd);
    if (pid < 0) return NULL;
    size_t cap = 1 << 16, n = 0; char *buf = malloc(cap + 1);
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
    buf[n] = 0; *len = n;
    return buf;
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
void isim_media_free(void *p) { free(p); }

/* ---------------- probing ---------------- */
struct isim_media_info { double duration, width, height, fps; int has_video, has_audio; };

int isim_media_probe(const char *url, struct isim_media_info *info) {
    memset(info, 0, sizeof *info);
    char *argv[] = { "ffprobe", "-v", "error", "-show_entries", "format=duration:stream=codec_type,width,height,avg_frame_rate,r_frame_rate",
                     "-of", "default=nw=1", (char *)url, NULL };
    size_t len; char *out = run_capture(argv, &len);
    if (!out) { fprintf(stderr, "isim media: cannot open %s (needs ffprobe/ffmpeg on the host, and a readable media file)\n", url); return 0; }
    int video = 0, seen_video = 0;
    for (char *line = strtok(out, "\n"); line; line = strtok(NULL, "\n")) {
        char *eq = strchr(line, '='); if (!eq) continue;
        *eq = 0; const char *k = line, *v = eq + 1;
        if (!strcmp(k, "codec_type")) {
            video = !strcmp(v, "video") && !seen_video;
            if (video) { seen_video = 1; info->has_video = 1; }
            if (!strcmp(v, "audio")) info->has_audio = 1;
        } else if (video && !strcmp(k, "width")) info->width = atof(v);
        else if (video && !strcmp(k, "height")) info->height = atof(v);
        else if (video && (!strcmp(k, "avg_frame_rate") || (!strcmp(k, "r_frame_rate") && info->fps <= 0))) {
            double a = 0, b = 0;
            if (sscanf(v, "%lf/%lf", &a, &b) == 2 && a > 0 && b > 0 && a / b < 1000) info->fps = a / b;
        } else if (!strcmp(k, "duration")) { double d = atof(v); if (d > 0) info->duration = d; }
    }
    free(out);
    if (info->has_video && info->fps <= 0) info->fps = 30;
    return info->has_video || info->has_audio;
}

/* ---------------- playback sessions ---------------- */
#define RING 6
#define MAX_MEDIA 16
#define MAX_SIDE 960            /* decode size bound (keeps the pipe and the per-frame copy small) */
struct media {
    char *url;
    int w, h; double fps, start;
    pthread_mutex_t m; pthread_cond_t cv;
    int stop;
    /* video */
    pid_t vpid; int vfd; pthread_t vth; int vthread;
    unsigned char *ring[RING]; double pts[RING]; int rhead, rcount, veof; long nframes;
    int img; double shown_pts;
    /* audio */
    pid_t apid; int afd; pthread_t ath; int athread; int astream;
};
static struct media *medias[MAX_MEDIA];
static pthread_mutex_t medias_mtx = PTHREAD_MUTEX_INITIALIZER;

static void *video_thread(void *arg) {
    struct media *md = arg;
    size_t fsz = (size_t)md->w * md->h * 4;
    for (;;) {
        pthread_mutex_lock(&md->m);
        while (md->rcount == RING && !md->stop) pthread_cond_wait(&md->cv, &md->m);
        int slot = (md->rhead + md->rcount) % RING, stop = md->stop;
        pthread_mutex_unlock(&md->m);
        if (stop || !read_full(md->vfd, md->ring[slot], fsz)) break;
        pthread_mutex_lock(&md->m);
        md->pts[slot] = md->start + (double)md->nframes++ / md->fps;
        md->rcount++;
        pthread_mutex_unlock(&md->m);
    }
    pthread_mutex_lock(&md->m); md->veof = 1; pthread_mutex_unlock(&md->m);
    return NULL;
}

static void *audio_thread(void *arg) {
    struct media *md = arg;
    enum { CH = 4096 };
    float *buf = malloc(CH * 2 * sizeof(float));
    for (;;) {
        ssize_t got = 0, want = CH * 2 * sizeof(float);
        while (got < want) {
            ssize_t r = read(md->afd, (char *)buf + got, want - got);
            if (r < 0 && errno == EINTR) continue;
            if (r <= 0) break;
            got += r;
        }
        long frames = got / (long)(2 * sizeof(float)), done = 0;
        while (done < frames) {
            pthread_mutex_lock(&md->m); int stop = md->stop; pthread_mutex_unlock(&md->m);
            if (stop) goto out;
            long n = isim_audio_stream_write(md->astream, buf + done * 2, frames - done);
            done += n;
            if (n == 0) usleep(10000);
        }
        if (got < want) break;
    }
out:
    free(buf);
    return NULL;
}

static void fmt_time(char *b, size_t n, double t) { snprintf(b, n, "%.6f", t > 0 ? t : 0); }

/* Opens a playback session at `start` seconds. want_video: decode frames (needs width/height/fps of the
 * video track, from isim_media_probe); want_audio: stream the soundtrack to the mixer when sound is
 * available. Returns a handle (> 0) or 0. */
int isim_media_open(const char *url, double start, double width, double height, double fps, int want_video, int want_audio, double volume) {
    struct media *md = calloc(1, sizeof *md);
    md->url = strdup(url); md->start = start > 0 ? start : 0; md->fps = fps > 0 ? fps : 30;
    md->vpid = md->apid = -1; md->vfd = md->afd = -1;
    pthread_mutex_init(&md->m, NULL); pthread_cond_init(&md->cv, NULL);
    char ss[32]; fmt_time(ss, sizeof ss, md->start);
    if (want_video && width > 0 && height > 0) {
        double sc = fmax(width, height) > MAX_SIDE ? MAX_SIDE / fmax(width, height) : 1;
        md->w = (int)lround(width * sc / 2) * 2; md->h = (int)lround(height * sc / 2) * 2;
        if (md->w < 2) md->w = 2;
        if (md->h < 2) md->h = 2;
        char vf[96]; snprintf(vf, sizeof vf, "scale=%d:%d,fps=%.6f", md->w, md->h, md->fps);
        char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-ss", ss, "-i", md->url, "-an", "-sn", "-vf", vf,
                         "-pix_fmt", "bgra", "-f", "rawvideo", "-", NULL };
        md->vpid = spawn_reader(argv, &md->vfd);
        if (md->vpid > 0) {
            for (int i = 0; i < RING; i++) md->ring[i] = malloc((size_t)md->w * md->h * 4);
            md->vthread = pthread_create(&md->vth, NULL, video_thread, md) == 0;
        } else fprintf(stderr, "isim media: cannot start ffmpeg for %s (video needs ffmpeg on the host)\n", url);
    }
    if (want_audio && (md->astream = isim_audio_stream_open(volume)) > 0) {
        char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-ss", ss, "-i", md->url, "-vn", "-sn",
                         "-f", "f32le", "-ac", "2", "-ar", "48000", "-", NULL };
        md->apid = spawn_reader(argv, &md->afd);
        if (md->apid > 0) md->athread = pthread_create(&md->ath, NULL, audio_thread, md) == 0;
    }
    if (md->vpid <= 0 && md->apid <= 0 && want_video) {
        if (md->astream > 0) isim_audio_stream_close(md->astream);
        free(md->url); free(md); return 0;
    }
    pthread_mutex_lock(&medias_mtx);
    int h = 0;
    for (int i = 0; i < MAX_MEDIA; i++) if (!medias[i]) { medias[i] = md; h = i + 1; break; }
    pthread_mutex_unlock(&medias_mtx);
    if (!h) { fprintf(stderr, "isim media: too many open players\n"); }
    return h;
}
static struct media *lookup(int h) { return h > 0 && h <= MAX_MEDIA ? medias[h - 1] : NULL; }

/* UI thread: the frame for playback time t (seconds) as an image handle (0 until the first frame arrives).
 * *eof becomes 1 once the decoder finished and every frame was shown. *pts receives the shown frame's time. */
int isim_media_video_frame(int h, double t, int *eof, double *pts) {
    struct media *md = lookup(h);
    if (eof) *eof = 1;
    if (!md || md->w <= 0) return 0;
    if (!md->img) md->img = isim_image_create_bgra(md->w, md->h);
    double tol = 0.5 / md->fps;
    pthread_mutex_lock(&md->m);
    int k = 0;
    while (k < md->rcount && md->pts[(md->rhead + k) % RING] <= t + tol) k++;
    if (k > 0) {
        int last = (md->rhead + k - 1) % RING;
        isim_image_update_bgra(md->img, md->ring[last], md->w, md->h);
        md->shown_pts = md->pts[last];
        md->rhead = (md->rhead + k) % RING; md->rcount -= k;
        pthread_cond_signal(&md->cv);
    }
    int shown = md->nframes > md->rcount;
    if (eof) *eof = md->veof && md->rcount == 0;
    if (pts) *pts = md->shown_pts;
    pthread_mutex_unlock(&md->m);
    return shown ? md->img : 0;
}
void isim_media_set_audio(int h, int paused, double volume) {
    struct media *md = lookup(h);
    if (md && md->astream > 0) isim_audio_stream_control(md->astream, paused, volume);
}
void isim_media_close(int h) {
    struct media *md = lookup(h);
    if (!md) return;
    pthread_mutex_lock(&medias_mtx); medias[h - 1] = NULL; pthread_mutex_unlock(&medias_mtx);
    pthread_mutex_lock(&md->m); md->stop = 1; pthread_cond_broadcast(&md->cv); pthread_mutex_unlock(&md->m);
    if (md->vpid > 0) kill(md->vpid, SIGKILL);
    if (md->apid > 0) kill(md->apid, SIGKILL);
    if (md->vthread) pthread_join(md->vth, NULL);
    if (md->athread) pthread_join(md->ath, NULL);
    if (md->vfd >= 0) close(md->vfd);
    if (md->afd >= 0) close(md->afd);
    int st;
    if (md->vpid > 0) waitpid(md->vpid, &st, 0);
    if (md->apid > 0) waitpid(md->apid, &st, 0);
    if (md->astream > 0) isim_audio_stream_close(md->astream);
    if (md->img) isim_image_free(md->img);
    for (int i = 0; i < RING; i++) free(md->ring[i]);
    pthread_mutex_destroy(&md->m); pthread_cond_destroy(&md->cv);
    free(md->url); free(md);
}

/* One frame at time t as PNG bytes (AVAssetImageGenerator), scaled to fit max_side (0 = native).
 * Free with isim_media_free. */
int isim_media_thumbnail_png(const char *url, double t, double max_side, void **out, long *len) {
    char ss[32]; fmt_time(ss, sizeof ss, t);
    char vf[96] = "null";
    if (max_side > 0) snprintf(vf, sizeof vf, "scale='if(gt(iw,ih),min(iw,%d),-2)':'if(gt(iw,ih),-2,min(ih,%d))'", (int)max_side, (int)max_side);
    char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-ss", ss, "-i", (char *)url, "-frames:v", "1", "-vf", vf,
                     "-f", "image2pipe", "-c:v", "png", "-", NULL };
    size_t n; char *png = run_capture(argv, &n);
    if (!png || n < 8) { free(png); return 0; }
    *out = png; *len = (long)n;
    return 1;
}

/* Re-encodes a media file (e.g. a recorded WAV to AAC .m4a); the format follows out's extension. */
int isim_media_transcode(const char *in, const char *out) {
    char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-y", "-i", (char *)in, (char *)out, NULL };
    size_t n; char *o = run_capture(argv, &n);
    if (!o) { fprintf(stderr, "isim media: cannot encode %s (needs ffmpeg on the host)\n", out); return 0; }
    free(o); return 1;
}

/* ---------------- text to speech ---------------- */
/* Synthesizes text with espeak-ng (or espeak). voice: an espeak voice/language ("en-us", "fr", ...);
 * wpm: words per minute; pitch: 0-99 (50 = normal). Returns mono float PCM (free with isim_media_free). */
int isim_tts_synthesize(const char *text, const char *voice, double wpm, double pitch, float **out, long *frames, double *rate) {
    char path[] = "/tmp/isim-tts-XXXXXX";
    int fd = mkstemp(path);
    if (fd < 0) return 0;
    size_t tl = strlen(text);
    if (write(fd, text, tl) != (ssize_t)tl) { close(fd); unlink(path); return 0; }
    close(fd);
    char s[16], p[16]; snprintf(s, sizeof s, "%d", (int)fmin(fmax(wpm, 80), 500)); snprintf(p, sizeof p, "%d", (int)fmin(fmax(pitch, 0), 99));
    const char *tools[] = { "espeak-ng", "espeak" };
    char *wav = NULL; size_t n = 0;
    for (int i = 0; i < 2 && !wav; i++) {
        char *argv[] = { (char *)tools[i], "--stdout", "-v", (char *)(voice && *voice ? voice : "en-us"), "-s", s, "-p", p, "-f", path, NULL };
        wav = run_capture(argv, &n);
    }
    unlink(path);
    if (!wav) { fprintf(stderr, "isim speech: no text-to-speech on the host (install espeak-ng)\n"); return 0; }
    /* RIFF/WAVE, 16-bit PCM; espeak streams with a placeholder data size, so read to the end */
    const unsigned char *b = (const unsigned char *)wav;
    int ok = 0;
    if (n > 44 && !memcmp(b, "RIFF", 4) && !memcmp(b + 8, "WAVE", 4)) {
        size_t o = 12; int ch = 1, bits = 16; double sr = 22050;
        while (o + 8 <= n) {
            unsigned sz = b[o + 4] | b[o + 5] << 8 | b[o + 6] << 16 | (unsigned)b[o + 7] << 24;
            if (!memcmp(b + o, "fmt ", 4)) { ch = b[o + 10] | b[o + 11] << 8; sr = b[o + 12] | b[o + 13] << 8 | b[o + 14] << 16 | (unsigned)b[o + 15] << 24; bits = b[o + 22] | b[o + 23] << 8; }
            else if (!memcmp(b + o, "data", 4)) {
                size_t start = o + 8, end = (size_t)sz > n - start ? n : start + sz;
                if (bits != 16 || ch < 1) break;
                long fr = (long)((end - start) / (2 * ch));
                float *pcm = malloc(sizeof(float) * (fr > 0 ? fr : 1));
                for (long i = 0; i < fr; i++) { const unsigned char *q = b + start + (size_t)i * 2 * ch; pcm[i] = (short)(q[0] | q[1] << 8) / 32768.f; }
                *out = pcm; *frames = fr; *rate = sr; ok = fr > 0;
                if (!ok) free(pcm);
                break;
            }
            o += 8 + sz + (sz & 1);
        }
    }
    free(wav);
    return ok;
}

/* ---------------- audio input (AVAudioRecorder, AVAudioEngine.inputNode) ----------------
 * ISIM_AUDIO_INPUT=<file>: the file (any format the host can decode) is the microphone, delivered in real
 * time and followed by silence. ISIM_AUDIO_INPUT=mic: the host's default capture device (ffmpeg -f pulse or
 * arecord). Unset: silence — isim never opens the host microphone unless asked to. 48 kHz stereo float. */
static struct { int on, kind; double t0; long consumed; float *file; long file_frames;
                pid_t pid; int fd; pthread_t th; float *ring; long rd, wr; pthread_mutex_t m; } in = { .m = PTHREAD_MUTEX_INITIALIZER };
#define IN_RING (48000 * 4)
static void *mic_thread(void *arg) {
    float buf[2048 * 2];
    for (;;) {
        ssize_t r = read(in.fd, buf, sizeof buf);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        long fr = r / (long)(2 * sizeof(float));
        pthread_mutex_lock(&in.m);
        for (long i = 0; i < fr; i++) { long k = (in.wr + i) % IN_RING; in.ring[2 * k] = buf[2 * i]; in.ring[2 * k + 1] = buf[2 * i + 1]; }
        in.wr += fr;
        if (in.wr - in.rd > IN_RING) in.rd = in.wr - IN_RING;
        pthread_mutex_unlock(&in.m);
    }
    return NULL;
}
/* returns 2 = microphone, 1 = file, 0 = silence */
int isim_audio_input_start(void) {
    if (in.on) return in.kind;
    in.on = 1; in.kind = 0; in.t0 = mono_now(); in.consumed = 0;
    const char *src = getenv("ISIM_AUDIO_INPUT");
    if (src && *src && strcmp(src, "mic")) {
        int ch; double rate;
        if (isim_audio_decode_file(src, &in.file, &in.file_frames, &ch, &rate)) in.kind = 1;
        else fprintf(stderr, "isim audio input: cannot read ISIM_AUDIO_INPUT=%s; recording silence\n", src);
    } else if (src && !strcmp(src, "mic")) {
        char *ff[] = { "ffmpeg", "-nostdin", "-v", "error", "-f", "pulse", "-i", "default", "-f", "f32le", "-ac", "2", "-ar", "48000", "-", NULL };
        char *ar[] = { "arecord", "-q", "-t", "raw", "-f", "FLOAT_LE", "-r", "48000", "-c", "2", NULL };
        in.pid = spawn_reader(ff, &in.fd);
        if (in.pid < 0) in.pid = spawn_reader(ar, &in.fd);
        if (in.pid > 0) {
            in.ring = calloc(IN_RING * 2, sizeof(float)); in.rd = in.wr = 0;
            pthread_create(&in.th, NULL, mic_thread, NULL);
            in.kind = 2;
        } else fprintf(stderr, "isim audio input: no capture tool (ffmpeg with pulse, or arecord); recording silence\n");
    } else fprintf(stderr, "isim audio input: no input configured (set ISIM_AUDIO_INPUT=<audio file> or =mic); recording silence\n");
    return in.kind;
}
/* Non-blocking: up to max_frames of input that has "arrived" by now (interleaved stereo, 48 kHz). */
long isim_audio_input_read(float *out, long max_frames) {
    if (!in.on) return 0;
    if (in.kind == 2) {
        pthread_mutex_lock(&in.m);
        long n = in.wr - in.rd; if (n > max_frames) n = max_frames;
        for (long i = 0; i < n; i++) { long k = (in.rd + i) % IN_RING; out[2 * i] = in.ring[2 * k]; out[2 * i + 1] = in.ring[2 * k + 1]; }
        in.rd += n;
        pthread_mutex_unlock(&in.m);
        return n;
    }
    long due = (long)((mono_now() - in.t0) * 48000) - in.consumed;
    if (due > max_frames) due = max_frames;
    if (due <= 0) return 0;
    for (long i = 0; i < due; i++) {
        long f = in.consumed + i;
        if (in.kind == 1 && f < in.file_frames) { out[2 * i] = in.file[2 * f]; out[2 * i + 1] = in.file[2 * f + 1]; }
        else out[2 * i] = out[2 * i + 1] = 0;
    }
    in.consumed += due;
    return due;
}
void isim_audio_input_stop(void) {
    if (!in.on) return;
    if (in.kind == 2) {
        kill(in.pid, SIGKILL); pthread_join(in.th, NULL); close(in.fd); int st; waitpid(in.pid, &st, 0);
        free(in.ring); in.ring = NULL;
    }
    free(in.file); in.file = NULL; in.file_frames = 0;
    in.on = 0;
}

/* ---------------- remote-control commands (MPRemoteCommandCenter) ----------------
 * The `remote NAME` script/control command (play, pause, toggle, next, previous, seek SECONDS, ...) queues
 * a command; the app's MediaPlayer polls the queue. */
static char remote_q[32][64];
static int rq_head, rq_count;
static pthread_mutex_t rq_mtx = PTHREAD_MUTEX_INITIALIZER;
void isim_media_remote_post(const char *cmd) {
    pthread_mutex_lock(&rq_mtx);
    if (rq_count < 32) { snprintf(remote_q[(rq_head + rq_count) % 32], 64, "%s", cmd); rq_count++; }
    pthread_mutex_unlock(&rq_mtx);
}
int isim_remote_command_poll(char *buf, int len) {
    pthread_mutex_lock(&rq_mtx);
    int got = rq_count > 0;
    if (got) { snprintf(buf, len, "%s", remote_q[rq_head]); rq_head = (rq_head + 1) % 32; rq_count--; }
    pthread_mutex_unlock(&rq_mtx);
    return got;
}
