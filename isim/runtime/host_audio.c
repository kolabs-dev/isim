/* libisim_host audio: a small software mixer on an SDL3 playback stream (48 kHz stereo float).
 * Guests upload PCM buffers (float, interleaved, any rate/channel count) and play them as voices
 * with volume, looping and pause; voices are resampled linearly and mixed in the SDL callback.
 * Used by isim's AVFoundation. If no audio device can be opened, everything still works silently. */
#include <SDL3/SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define OUT_RATE 48000
#define MAX_BUFS 1024
#define MAX_VOICES 64

struct abuf { float *pcm; long frames; int channels; double rate; int refs; };
struct voice { int buf, playing, paused, loops; double pos, volume; unsigned gen; };

static struct abuf bufs[MAX_BUFS];
static struct voice voices[MAX_VOICES];
static unsigned voice_gen = 1;
static SDL_Mutex *mtx;
static SDL_AudioStream *stream;
static int audio_state;          /* 0 = not tried, 1 = open, -1 = unavailable */
static int suspended;
static float *mixbuf; static int mixcap;

static void unref(int b) {
    if (b <= 0 || b >= MAX_BUFS || !bufs[b].pcm) return;
    if (--bufs[b].refs == 0) { free(bufs[b].pcm); memset(&bufs[b], 0, sizeof bufs[b]); }
}

/* streams: rings of 48 kHz stereo float filled by a producer thread (video soundtracks, host_media.c) */
#define MAX_STREAMS 8
#define STREAM_FRAMES (OUT_RATE / 2)            /* 0.5 s ring */
struct astream { int used, paused; double volume; float *ring; long rd, wr; /* frame counters */ };
static struct astream streams[MAX_STREAMS];

static void SDLCALL feed(void *ud, SDL_AudioStream *s, int additional, int total) {
    int frames = additional / (int)(2 * sizeof(float));
    if (frames <= 0) return;
    if (frames * 2 > mixcap) { mixcap = frames * 2; mixbuf = realloc(mixbuf, mixcap * sizeof(float)); }
    memset(mixbuf, 0, frames * 2 * sizeof(float));
    SDL_LockMutex(mtx);
    if (!suspended) for (int k = 0; k < MAX_STREAMS; k++) {
        struct astream *st = &streams[k];
        if (!st->used || st->paused) continue;
        float vol = (float)st->volume;
        for (int i = 0; i < frames && st->rd < st->wr; i++, st->rd++) {
            const float *p = st->ring + (st->rd % STREAM_FRAMES) * 2;
            mixbuf[2 * i] += p[0] * vol; mixbuf[2 * i + 1] += p[1] * vol;
        }
    }
    if (!suspended) {
        for (int v = 0; v < MAX_VOICES; v++) {
            struct voice *vo = &voices[v];
            if (!vo->playing || vo->paused) continue;
            struct abuf *b = &bufs[vo->buf];
            if (!b->pcm || b->frames <= 0) { vo->playing = 0; continue; }
            double step = b->rate / OUT_RATE;
            float vol = (float)vo->volume;
            for (int i = 0; i < frames; i++) {
                if (vo->pos >= b->frames) {
                    if (vo->loops != 0) { vo->pos -= b->frames; if (vo->loops > 0) vo->loops--; }
                    else { vo->playing = 0; unref(vo->buf); vo->buf = 0; break; }
                }
                long i0 = (long)vo->pos;
                long i1 = i0 + 1 < b->frames ? i0 + 1 : (vo->loops != 0 ? 0 : i0);
                float t = (float)(vo->pos - (double)i0);
                float l, r;
                if (b->channels == 1) {
                    l = r = b->pcm[i0] + (b->pcm[i1] - b->pcm[i0]) * t;
                } else {
                    const float *a = b->pcm + i0 * b->channels, *c = b->pcm + i1 * b->channels;
                    l = a[0] + (c[0] - a[0]) * t;
                    r = a[1] + (c[1] - a[1]) * t;
                }
                mixbuf[2 * i] += l * vol;
                mixbuf[2 * i + 1] += r * vol;
                vo->pos += step;
            }
        }
    }
    SDL_UnlockMutex(mtx);
    for (int i = 0; i < frames * 2; i++) {          /* soft clip */
        float x = mixbuf[i];
        if (x > 1.f) x = 1.f; else if (x < -1.f) x = -1.f;
        mixbuf[i] = x;
    }
    SDL_PutAudioStreamData(s, mixbuf, frames * 2 * (int)sizeof(float));
}

static int ensure_open(void) {
    if (audio_state) return audio_state > 0;
    audio_state = -1;
    if (!mtx) mtx = SDL_CreateMutex();
    int headless = getenv("ISIM_HEADLESS") && atoi(getenv("ISIM_HEADLESS"));
    if ((getenv("ISIM_MUTE") && atoi(getenv("ISIM_MUTE"))) || (headless && !getenv("ISIM_AUDIO"))) return 0;   /* tests: silent */
    if (!SDL_WasInit(SDL_INIT_AUDIO) && !SDL_InitSubSystem(SDL_INIT_AUDIO)) {
        fprintf(stderr, "isim audio: no audio (%s); playing silently\n", SDL_GetError());
        return 0;
    }
    SDL_AudioSpec spec = { SDL_AUDIO_F32, 2, OUT_RATE };
    stream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, feed, NULL);
    if (!stream) { fprintf(stderr, "isim audio: cannot open playback device (%s); playing silently\n", SDL_GetError()); return 0; }
    SDL_ResumeAudioStreamDevice(stream);
    audio_state = 1;
    return 1;
}

/* ---- guest API ---- */
int isim_audio_available(void) { return ensure_open(); }

int isim_audio_buffer_create(const float *pcm, long frames, int channels, double rate) {
    ensure_open();
    if (!pcm || frames <= 0 || channels < 1 || rate <= 0) return 0;
    SDL_LockMutex(mtx);
    int b = 0;
    for (int i = 1; i < MAX_BUFS; i++) if (!bufs[i].pcm) { b = i; break; }
    if (b) {
        size_t n = (size_t)frames * channels;
        bufs[b].pcm = malloc(n * sizeof(float));
        memcpy(bufs[b].pcm, pcm, n * sizeof(float));
        bufs[b].frames = frames; bufs[b].channels = channels; bufs[b].rate = rate; bufs[b].refs = 1;
    } else fprintf(stderr, "isim audio: too many buffers\n");
    SDL_UnlockMutex(mtx);
    return b;
}
void isim_audio_buffer_release(int b) { if (!mtx) return; SDL_LockMutex(mtx); unref(b); SDL_UnlockMutex(mtx); }

/* Returns a voice handle (> 0): index + generation, so stale handles are ignored. loops: 0 = once, n = n extra, -1 = forever. */
long isim_audio_play(int b, double volume, int loops) {
    if (!ensure_open() || b <= 0 || b >= MAX_BUFS) return 0;
    SDL_LockMutex(mtx);
    long h = 0;
    if (bufs[b].pcm) {
        int v = -1;
        for (int i = 0; i < MAX_VOICES; i++) if (!voices[i].playing) { v = i; break; }
        if (v < 0) {                                  /* steal the voice closest to its end */
            double best = -1;
            for (int i = 0; i < MAX_VOICES; i++) {
                struct abuf *bb = &bufs[voices[i].buf];
                double rem = bb->frames ? (double)bb->frames - voices[i].pos : 0;
                if (voices[i].loops == 0 && (v < 0 || rem < best)) { best = rem; v = i; }
            }
            if (v < 0) v = 0;
            unref(voices[v].buf);
        }
        bufs[b].refs++;
        voices[v] = (struct voice){ .buf = b, .playing = 1, .paused = 0, .loops = loops, .pos = 0, .volume = volume, .gen = voice_gen++ };
        h = ((long)voices[v].gen << 8) | v;
    }
    SDL_UnlockMutex(mtx);
    return h;
}
static struct voice *lookup(long h) {
    int v = (int)(h & 0xFF);
    if (h <= 0 || v >= MAX_VOICES || voices[v].gen != (unsigned)(h >> 8)) return NULL;
    return &voices[v];
}
void isim_audio_stop(long h) {
    if (!mtx) return;
    SDL_LockMutex(mtx);
    struct voice *vo = lookup(h);
    if (vo && vo->playing) { vo->playing = 0; unref(vo->buf); vo->buf = 0; }
    SDL_UnlockMutex(mtx);
}
void isim_audio_pause(long h, int paused) {
    if (!mtx) return;
    SDL_LockMutex(mtx); struct voice *vo = lookup(h); if (vo) vo->paused = paused; SDL_UnlockMutex(mtx);
}
void isim_audio_set_volume(long h, double volume) {
    if (!mtx) return;
    SDL_LockMutex(mtx); struct voice *vo = lookup(h); if (vo) vo->volume = volume; SDL_UnlockMutex(mtx);
}
int isim_audio_is_playing(long h) {
    if (!mtx) return 0;
    SDL_LockMutex(mtx); struct voice *vo = lookup(h); int p = vo && vo->playing && !vo->paused; SDL_UnlockMutex(mtx);
    return p;
}
/* playback position in seconds of the voice's buffer (0 when finished) */
double isim_audio_position(long h) {
    if (!mtx) return 0;
    SDL_LockMutex(mtx);
    struct voice *vo = lookup(h);
    double t = vo && vo->playing ? vo->pos / bufs[vo->buf].rate : 0;
    SDL_UnlockMutex(mtx);
    return t;
}
void isim_audio_seek(long h, double seconds) {
    if (!mtx) return;
    SDL_LockMutex(mtx); struct voice *vo = lookup(h); if (vo && vo->playing) vo->pos = seconds * bufs[vo->buf].rate; SDL_UnlockMutex(mtx);
}
/* app moved to the background / foreground (the app's audio session is interrupted like on iOS) */
void isim_audio_suspend(int s) {
    if (!mtx) return;
    SDL_LockMutex(mtx); suspended = s; SDL_UnlockMutex(mtx);
}

/* ---------------- compressed audio files (AAC/ALAC m4a, MP3, FLAC, Ogg, ...) ----------------
 * Decoded by the host's ffmpeg, or GStreamer's gst-launch-1.0, in a child process (so the decoder's
 * threads and plugins stay out of the app process), to 48 kHz stereo float — the mixer's output format.
 * Without either tool these formats fail to open, like an unreadable file. */
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fcntl.h>
extern char **environ;

static int run_decoder(char *const argv[], float **out, long *frames) {
    int fds[2];
    if (pipe(fds)) return 0;
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_adddup2(&fa, fds[1], 1);
    posix_spawn_file_actions_addclose(&fa, fds[0]);
    posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    int ok = posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ) == 0;
    posix_spawn_file_actions_destroy(&fa);
    close(fds[1]);
    if (!ok) { close(fds[0]); return 0; }
    size_t cap = 1 << 20, len = 0;
    char *buf = malloc(cap);
    for (;;) {
        if (len == cap) { cap *= 2; buf = realloc(buf, cap); }
        ssize_t n = read(fds[0], buf + len, cap - len);
        if (n <= 0) break;
        len += (size_t)n;
    }
    close(fds[0]);
    int status = 0;
    waitpid(pid, &status, 0);
    long fr = (long)(len / (2 * sizeof(float)));
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0 || fr == 0) { free(buf); return 0; }
    *out = (float *)buf; *frames = fr;
    return 1;
}

int isim_audio_decode_file(const char *path, float **out, long *out_frames, int *out_channels, double *out_rate) {
    if (access(path, R_OK)) return 0;
    char *ff[] = { "ffmpeg", "-nostdin", "-v", "error", "-i", (char *)path, "-vn", "-f", "f32le", "-ac", "2", "-ar", "48000", "-", NULL };
    int ok = run_decoder(ff, out, out_frames);
    if (!ok) {
        char loc[4200]; snprintf(loc, sizeof loc, "location=%s", path);
        char *gst[] = { "gst-launch-1.0", "-q", "filesrc", loc, "!", "decodebin", "!", "audioconvert", "!", "audioresample", "!",
                        "audio/x-raw,format=F32LE,layout=interleaved,channels=2,rate=48000", "!", "fdsink", "fd=1", NULL };
        ok = run_decoder(gst, out, out_frames);
    }
    if (!ok) { fprintf(stderr, "isim audio: cannot decode %s (needs ffmpeg or gst-launch-1.0 on the host)\n", path); return 0; }
    *out_channels = 2; *out_rate = OUT_RATE;
    return 1;
}
void isim_audio_free(float *pcm) { free(pcm); }

/* ---------------- streams (host-internal: host_media.c) ----------------
 * A stream is a small ring the mixer drains in real time; the producer writes what fits. Returns 0 when
 * there is no audio device (headless tests), so producers can skip decoding sound altogether. */
int isim_audio_stream_open(double volume) {
    if (!ensure_open()) return 0;
    SDL_LockMutex(mtx);
    int s = 0;
    for (int i = 0; i < MAX_STREAMS; i++) if (!streams[i].used) {
        streams[i] = (struct astream){ .used = 1, .volume = volume, .ring = calloc(STREAM_FRAMES * 2, sizeof(float)) };
        s = i + 1; break;
    }
    SDL_UnlockMutex(mtx);
    return s;
}
/* writes up to `frames` interleaved stereo frames; returns how many fit (0 = ring full, try later) */
long isim_audio_stream_write(int s, const float *pcm, long frames) {
    if (s <= 0 || s > MAX_STREAMS) return 0;
    SDL_LockMutex(mtx);
    struct astream *st = &streams[s - 1];
    long n = 0;
    if (st->used) {
        long room = STREAM_FRAMES - (st->wr - st->rd);
        n = frames < room ? frames : room;
        for (long i = 0; i < n; i++) { float *p = st->ring + ((st->wr + i) % STREAM_FRAMES) * 2; p[0] = pcm[2 * i]; p[1] = pcm[2 * i + 1]; }
        st->wr += n;
    }
    SDL_UnlockMutex(mtx);
    return n;
}
void isim_audio_stream_control(int s, int paused, double volume) {
    if (s <= 0 || s > MAX_STREAMS || !mtx) return;
    SDL_LockMutex(mtx); streams[s - 1].paused = paused; streams[s - 1].volume = volume; SDL_UnlockMutex(mtx);
}
void isim_audio_stream_close(int s) {
    if (s <= 0 || s > MAX_STREAMS || !mtx) return;
    SDL_LockMutex(mtx); free(streams[s - 1].ring); memset(&streams[s - 1], 0, sizeof streams[s - 1]); SDL_UnlockMutex(mtx);
}
