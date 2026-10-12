/* libisim_host speech synthesis with events: the host's libespeak-ng (dlopen'd when an app speaks) renders the text
 * in this process and reports where each word, sentence, SSML <mark> and the end fall in the audio, so
 * AVSpeechSynthesizer's willSpeakRange / willSpeakMarker callbacks follow the speech exactly. Without the library,
 * isim_tts_synthesize (host_media.c: the espeak-ng command) still renders speech, without events.
 * The espeak-ng API is small and stable; it is declared here (speak_lib.h, espeak-ng 1.49+, espeak 1.48). */
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    int type; unsigned int unique_identifier; int text_position, length, audio_position, sample; void *user_data;
    union { int number; const char *name; char string[8]; } id;
} espeak_event;
enum { EV_LIST_TERMINATED = 0, EV_WORD = 1, EV_SENTENCE = 2, EV_MARK = 3, EV_PLAY = 4, EV_END = 5, EV_MSG_TERMINATED = 6, EV_PHONEME = 7 };
typedef int (*synth_cb)(short *, int, espeak_event *);

static struct {
    int state;                                   /* 0 not tried, 1 ok, -1 unavailable */
    int rate;
    int (*initialize)(int, int, const char *, int);
    void (*set_callback)(synth_cb);
    int (*set_voice)(const char *);
    int (*set_parameter)(int, int, int);
    int (*synth)(const void *, size_t, unsigned int, int, unsigned int, unsigned int, unsigned int *, void *);
    int (*synchronize)(void);
} es;
static pthread_mutex_t es_lock = PTHREAD_MUTEX_INITIALIZER;

/* one event of the rendered speech: kind 1 word, 2 sentence, 3 mark, 5 end, 7 phoneme; text position (characters,
   0-based) and length; frame in the audio; the mark's name */
struct isim_tts_event { int kind, text_pos, text_len; long frame; char name[64]; };

static struct { short *pcm; long frames, cap; struct isim_tts_event *ev; int nev, evcap; } cur;

static int collect(short *wav, int n, espeak_event *e) {
    if (wav && n > 0) {
        if (cur.frames + n > cur.cap) { cur.cap = (cur.frames + n) * 2; cur.pcm = realloc(cur.pcm, sizeof(short) * (size_t)cur.cap); }
        memcpy(cur.pcm + cur.frames, wav, sizeof(short) * (size_t)n);
        cur.frames += n;
    }
    for (; e && e->type != EV_LIST_TERMINATED; e++) {
        if (e->type != EV_WORD && e->type != EV_SENTENCE && e->type != EV_MARK && e->type != EV_END && e->type != EV_PHONEME) continue;
        if (cur.nev == cur.evcap) { cur.evcap = cur.evcap ? cur.evcap * 2 : 64; cur.ev = realloc(cur.ev, sizeof *cur.ev * (size_t)cur.evcap); }
        struct isim_tts_event *v = &cur.ev[cur.nev++];
        memset(v, 0, sizeof *v);
        v->kind = e->type; v->text_pos = e->text_position > 0 ? e->text_position - 1 : 0; v->text_len = e->length;
        v->frame = (long)e->audio_position * es.rate / 1000;
        if (e->type == EV_MARK && e->id.name) snprintf(v->name, sizeof v->name, "%s", e->id.name);
        else if (e->type == EV_PHONEME) memcpy(v->name, e->id.string, sizeof e->id.string);
    }
    return 0;
}

static int load(void) {
    if (es.state) return es.state > 0;
    es.state = -1;
    void *lib = dlopen("libespeak-ng.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!lib) lib = dlopen("libespeak.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!lib) return 0;
    es.initialize = dlsym(lib, "espeak_Initialize"); es.set_callback = dlsym(lib, "espeak_SetSynthCallback");
    es.set_voice = dlsym(lib, "espeak_SetVoiceByName"); es.set_parameter = dlsym(lib, "espeak_SetParameter");
    es.synth = dlsym(lib, "espeak_Synth"); es.synchronize = dlsym(lib, "espeak_Synchronize");
    if (!es.initialize || !es.set_callback || !es.set_voice || !es.set_parameter || !es.synth || !es.synchronize) return 0;
    es.rate = es.initialize(2 /* AUDIO_OUTPUT_SYNCHRONOUS */, 200, NULL, 0x8000 /* espeakINITIALIZE_DONT_EXIT */);
    if (es.rate <= 0) return 0;
    es.set_callback(collect);
    es.state = 1;
    return 1;
}

int isim_tts_available(void) { pthread_mutex_lock(&es_lock); int ok = load(); pthread_mutex_unlock(&es_lock); return ok; }

/* Renders `text` (UTF-8; SSML when ssml) with an espeak voice name, words per minute, pitch 0...99 and volume
   0...200. Returns the mono samples (free with isim_media_free) and the events (free with isim_media_free); 0 when
   libespeak-ng is unavailable or the voice is unknown. */
int isim_tts_render(const char *text, int ssml, const char *voice, double wpm, double pitch, double volume,
                    float **out, long *frames, double *rate, struct isim_tts_event **events, int *nevents) {
    pthread_mutex_lock(&es_lock);
    int ok = 0;
    if (load()) {
        if (es.set_voice(voice && *voice ? voice : "en-us") != 0) es.set_voice("en-us");
        es.set_parameter(1 /* espeakRATE */, (int)(wpm < 80 ? 80 : wpm > 450 ? 450 : wpm), 0);
        es.set_parameter(3 /* espeakPITCH */, (int)(pitch < 0 ? 0 : pitch > 99 ? 99 : pitch), 0);
        es.set_parameter(2 /* espeakVOLUME */, (int)(volume < 0 ? 0 : volume > 200 ? 200 : volume), 0);
        memset(&cur, 0, sizeof cur);
        unsigned int uid = 0;
        unsigned int flags = 1 /* espeakCHARS_UTF8 */ | (ssml ? 0x10 /* espeakSSML */ : 0) | 0x1000 /* espeakENDPAUSE */;
        if (es.synth(text, strlen(text) + 1, 0, 1 /* POS_CHARACTER */, 0, flags, &uid, NULL) == 0) {
            es.synchronize();
            float *pcm = malloc(sizeof(float) * (size_t)(cur.frames > 0 ? cur.frames : 1));
            for (long i = 0; i < cur.frames; i++) pcm[i] = cur.pcm[i] / 32768.f;
            *out = pcm; *frames = cur.frames; *rate = es.rate;
            *events = cur.ev; *nevents = cur.nev;
            cur.ev = NULL;
            ok = 1;
        }
        free(cur.pcm); free(cur.ev);
        memset(&cur, 0, sizeof cur);
    }
    pthread_mutex_unlock(&es_lock);
    return ok;
}
