/* libisim_host audio codecs: AAC (and MP3 decoding) through the host's libavcodec, loaded with dlopen only when an
 * app converts compressed audio (AudioToolbox's AudioConverter). Without libavcodec the functions report that the
 * codec is unavailable and AudioConverterNew returns kAudioConverterErr_FormatNotSupported.
 *
 * No FFmpeg headers are needed: the few functions are declared here, options are set through AVOptions, and the
 * fields that are not options are found at run time (stable since FFmpeg 5.1):
 *   - AVPacket: data, size (offsets 24, 32 since FFmpeg 4);
 *   - AVFrame: data[], extended_data, nb_samples, format (offsets 0, 96, 112, 116); sample_rate and ch_layout are
 *     located by decoding one PCM packet and finding the values the decoder wrote;
 *   - AVCodecContext.sample_fmt: after sample_rate (the "ar" option), and the old "channels" field when "ac" is it. */
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct { const char *name, *help; int offset; } avopt;
static struct {
    int state;                         /* 0 not tried, 1 ok, -1 unavailable */
    void *(*find_encoder)(const char *), *(*find_decoder)(const char *), *(*alloc_ctx)(const void *);
    int (*open2)(void *, const void *, void *);
    void (*free_ctx)(void **);
    int (*send_frame)(void *, void *), (*receive_packet)(void *, void *), (*send_packet)(void *, void *), (*receive_frame)(void *, void *);
    void *(*packet_alloc)(void); void (*packet_free)(void **); int (*new_packet)(void *, int); void (*packet_unref)(void *);
    void *(*frame_alloc)(void); void (*frame_free)(void **); void (*frame_unref)(void *);
    int (*opt_set)(void *, const char *, const char *, int), (*opt_set_int)(void *, const char *, int64_t, int);
    int (*opt_get_int)(void *, const char *, int, int64_t *);
    const avopt *(*opt_find)(void *, const char *, const char *, int, int);
    int frame_rate_off, frame_layout_off;
} av;

#define PKT_DATA(p) (*(uint8_t **)((char *)(p) + 24))
#define PKT_SIZE(p) (*(int *)((char *)(p) + 32))
#define FR_DATA(f) ((uint8_t **)(f))
#define FR_LINESIZE(f) ((int *)((char *)(f) + 64))
#define FR_EXT(f) (*(uint8_t ***)((char *)(f) + 96))
#define FR_SAMPLES(f) (*(int *)((char *)(f) + 112))
#define FR_FORMAT(f) (*(int *)((char *)(f) + 116))
enum { FMT_U8 = 0, FMT_S16 = 1, FMT_S32 = 2, FMT_FLT = 3, FMT_DBL = 4, FMT_U8P = 5, FMT_S16P = 6, FMT_S32P = 7, FMT_FLTP = 8, FMT_DBLP = 9 };

static void *sym(void *lib, const char *name, int *ok) { void *p = lib ? dlsym(lib, name) : NULL; if (!p) *ok = 0; return p; }

/* the AVFrame offsets of sample_rate and ch_layout, from a frame the PCM decoder fills in */
static int find_frame_offsets(void) {
    void *dec = av.find_decoder("pcm_f32le");
    if (!dec) return 0;
    void *ctx = av.alloc_ctx(dec);
    av.opt_set_int(ctx, "ar", 44123, 0);
    av.opt_set(ctx, "ch_layout", "stereo", 0);
    int ok = 0;
    if (av.open2(ctx, dec, NULL) == 0) {
        void *pkt = av.packet_alloc(), *fr = av.frame_alloc();
        av.new_packet(pkt, 64);
        memset(PKT_DATA(pkt), 0, 64);
        if (av.send_packet(ctx, pkt) == 0 && av.receive_frame(ctx, fr) == 0) {
            const unsigned char *f = fr;
            for (int o = 120; o < 1024 && !(av.frame_rate_off && av.frame_layout_off); o += 4) {
                if (!av.frame_rate_off && *(const int *)(f + o) == 44123) av.frame_rate_off = o;
                if (!av.frame_layout_off && *(const int *)(f + o) == 1 && *(const int *)(f + o + 4) == 2 && *(const uint64_t *)(f + o + 8) == 3)
                    av.frame_layout_off = o;
            }
            ok = av.frame_rate_off && av.frame_layout_off;
            av.frame_unref(fr);
        }
        av.packet_free(&pkt); av.frame_free(&fr);
    }
    av.free_ctx(&ctx);
    return ok;
}

static int load(void) {
    if (av.state) return av.state > 0;
    av.state = -1;
    static const char *const codecs[] = { "libavcodec.so.62", "libavcodec.so.61", "libavcodec.so.60", "libavcodec.so.59", NULL };
    static const char *const utils[] = { "libavutil.so.60", "libavutil.so.59", "libavutil.so.58", "libavutil.so.57", NULL };
    void *c = NULL, *u = NULL;
    for (int i = 0; codecs[i] && !c; i++) if ((c = dlopen(codecs[i], RTLD_NOW | RTLD_LOCAL))) u = dlopen(utils[i], RTLD_NOW | RTLD_LOCAL);
    if (!c || !u) { fprintf(stderr, "isim audio: no libavcodec on the host (compressed audio conversion unavailable)\n"); return 0; }
    int ok = 1;
    av.find_encoder = sym(c, "avcodec_find_encoder_by_name", &ok); av.find_decoder = sym(c, "avcodec_find_decoder_by_name", &ok);
    av.alloc_ctx = sym(c, "avcodec_alloc_context3", &ok); av.open2 = sym(c, "avcodec_open2", &ok); av.free_ctx = sym(c, "avcodec_free_context", &ok);
    av.send_frame = sym(c, "avcodec_send_frame", &ok); av.receive_packet = sym(c, "avcodec_receive_packet", &ok);
    av.send_packet = sym(c, "avcodec_send_packet", &ok); av.receive_frame = sym(c, "avcodec_receive_frame", &ok);
    av.packet_alloc = sym(c, "av_packet_alloc", &ok); av.packet_free = sym(c, "av_packet_free", &ok);
    av.new_packet = sym(c, "av_new_packet", &ok); av.packet_unref = sym(c, "av_packet_unref", &ok);
    av.frame_alloc = sym(u, "av_frame_alloc", &ok); av.frame_free = sym(u, "av_frame_free", &ok); av.frame_unref = sym(u, "av_frame_unref", &ok);
    av.opt_set = sym(u, "av_opt_set", &ok); av.opt_set_int = sym(u, "av_opt_set_int", &ok); av.opt_get_int = sym(u, "av_opt_get_int", &ok);
    av.opt_find = sym(u, "av_opt_find", &ok);
    if (!ok || !find_frame_offsets()) { fprintf(stderr, "isim audio: unsupported libavcodec on the host\n"); return 0; }
    av.state = 1;
    return 1;
}

struct isim_acodec {
    int encode, channels, frame_size;
    double rate;
    void *ctx, *frame, *pkt;
    float *fifo; int fifo_frames, fifo_cap;      /* encoder input not yet sent (interleaved) */
    float *planes;                               /* one frame, planar */
    int flushed;
};

static const char *layout_name(int ch) {
    static const char *const n[] = { "", "mono", "stereo", "2.1", "quad", "5.0", "5.1", "6.1", "7.1" };
    return ch > 0 && ch <= 8 ? n[ch] : "stereo";
}

/* encode: "aac" (AAC-LC); decode: "aac", "mp3float", "alac"... Returns NULL when unavailable. */
struct isim_acodec *isim_acodec_open(int encode, const char *name, double rate, int channels, long bitrate) {
    if (!load()) return NULL;
    void *codec = encode ? av.find_encoder(name) : av.find_decoder(name);
    if (!codec) return NULL;
    void *ctx = av.alloc_ctx(codec);
    if (rate > 0) av.opt_set_int(ctx, "ar", (int64_t)rate, 0);
    if (channels > 0) av.opt_set(ctx, "ch_layout", layout_name(channels), 0);
    if (encode) {
        const avopt *ar = av.opt_find(ctx, "ar", NULL, 0, 0), *ac = av.opt_find(ctx, "ac", NULL, 0, 0);
        if (!ar) { av.free_ctx(&ctx); return NULL; }
        int fmt_off = ar->offset + 4 + (ac && ac->offset == ar->offset + 4 ? 4 : 0);
        *(int *)((char *)ctx + fmt_off) = FMT_FLTP;
        if (bitrate > 0) av.opt_set_int(ctx, "b", bitrate, 0);
    }
    if (av.open2(ctx, codec, NULL) < 0) { av.free_ctx(&ctx); return NULL; }
    struct isim_acodec *h = calloc(1, sizeof *h);
    h->encode = encode; h->ctx = ctx; h->rate = rate; h->channels = channels > 0 ? channels : 2;
    h->frame = av.frame_alloc(); h->pkt = av.packet_alloc();
    int64_t fs = 0;
    av.opt_get_int(ctx, "frame_size", 0, &fs);
    h->frame_size = fs > 0 ? (int)fs : 1024;
    return h;
}
int isim_acodec_frame_size(struct isim_acodec *h) { return h ? h->frame_size : 0; }

static int send_planar(struct isim_acodec *h, const float *inter, int n) {
    int ch = h->channels;
    if (!h->planes) h->planes = malloc(sizeof(float) * (size_t)h->frame_size * ch);
    void *f = h->frame;
    for (int c = 0; c < ch && c < 8; c++) {
        float *p = h->planes + (size_t)c * h->frame_size;
        for (int i = 0; i < n; i++) p[i] = inter[(size_t)i * ch + c];
        FR_DATA(f)[c] = (uint8_t *)p;
        FR_LINESIZE(f)[c] = n * 4;
    }
    FR_EXT(f) = FR_DATA(f);
    FR_SAMPLES(f) = n; FR_FORMAT(f) = FMT_FLTP;
    *(int *)((char *)f + av.frame_rate_off) = (int)h->rate;
    int *lay = (int *)((char *)f + av.frame_layout_off);
    lay[0] = 1; lay[1] = ch;                                      /* AV_CHANNEL_ORDER_NATIVE, nb_channels */
    *(uint64_t *)((char *)f + av.frame_layout_off + 8) = ch == 1 ? 0x4 : ch == 2 ? 0x3 : (1ull << ch) - 1;
    return av.send_frame(h->ctx, f);
}
/* encoder input (interleaved float); frames == 0 ends the stream */
int isim_acodec_send_pcm(struct isim_acodec *h, const float *pcm, int frames) {
    if (!h || !h->encode || h->flushed) return -1;
    int ch = h->channels;
    if (frames > 0) {
        if (h->fifo_frames + frames > h->fifo_cap) {
            h->fifo_cap = (h->fifo_frames + frames) * 2;
            h->fifo = realloc(h->fifo, sizeof(float) * (size_t)h->fifo_cap * ch);
        }
        memcpy(h->fifo + (size_t)h->fifo_frames * ch, pcm, sizeof(float) * (size_t)frames * ch);
        h->fifo_frames += frames;
    }
    int sent = 0;
    while (h->fifo_frames >= h->frame_size || (frames == 0 && h->fifo_frames > 0)) {
        int n = h->fifo_frames < h->frame_size ? h->fifo_frames : h->frame_size;
        if (send_planar(h, h->fifo, n) < 0) return -1;
        memmove(h->fifo, h->fifo + (size_t)n * ch, sizeof(float) * (size_t)(h->fifo_frames - n) * ch);
        h->fifo_frames -= n;
        sent++;
    }
    if (frames == 0) { av.send_frame(h->ctx, NULL); h->flushed = 1; }
    return sent;
}
/* an encoded packet: its size, 0 when the encoder needs more input, -1 at the end */
int isim_acodec_receive_packet(struct isim_acodec *h, unsigned char *out, int cap) {
    if (!h || !h->encode) return -1;
    int st = av.receive_packet(h->ctx, h->pkt);
    if (st < 0) return h->flushed ? -1 : 0;
    int n = PKT_SIZE(h->pkt);
    if (n > cap) n = cap;
    memcpy(out, PKT_DATA(h->pkt), (size_t)n);
    av.packet_unref(h->pkt);
    return n;
}
/* decoder input: one packet; size 0 ends the stream */
int isim_acodec_send_packet(struct isim_acodec *h, const unsigned char *data, int size) {
    if (!h || h->encode) return -1;
    if (size <= 0) { h->flushed = 1; return av.send_packet(h->ctx, NULL); }
    if (av.new_packet(h->pkt, size) < 0) return -1;
    memcpy(PKT_DATA(h->pkt), data, (size_t)size);
    int st = av.send_packet(h->ctx, h->pkt);
    av.packet_unref(h->pkt);
    return st;
}
/* decoded audio: frames written (interleaved float, `cap` frames at most), 0 when more input is needed, -1 at the end */
int isim_acodec_receive_pcm(struct isim_acodec *h, float *out, int cap, int *channels, double *rate) {
    if (!h || h->encode) return -1;
    void *f = h->frame;
    int st = av.receive_frame(h->ctx, f);
    if (st < 0) return h->flushed ? -1 : 0;
    int n = FR_SAMPLES(f), fmt = FR_FORMAT(f);
    int ch = *(int *)((char *)f + av.frame_layout_off + 4);
    if (ch <= 0) ch = h->channels;
    if (channels) *channels = ch;
    if (rate) *rate = *(int *)((char *)f + av.frame_rate_off);
    if (n > cap) n = cap;
    uint8_t **d = FR_EXT(f);
    for (int i = 0; i < n; i++) for (int c = 0; c < ch; c++) {
        float v = 0;
        switch (fmt) {
        case FMT_FLTP: v = ((float *)d[c])[i]; break;
        case FMT_FLT: v = ((float *)d[0])[i * ch + c]; break;
        case FMT_DBLP: v = (float)((double *)d[c])[i]; break;
        case FMT_DBL: v = (float)((double *)d[0])[i * ch + c]; break;
        case FMT_S16P: v = ((int16_t *)d[c])[i] / 32768.f; break;
        case FMT_S16: v = ((int16_t *)d[0])[i * ch + c] / 32768.f; break;
        case FMT_S32P: v = ((int32_t *)d[c])[i] / 2147483648.f; break;
        case FMT_S32: v = ((int32_t *)d[0])[i * ch + c] / 2147483648.f; break;
        case FMT_U8P: v = (d[c][i] - 128) / 128.f; break;
        case FMT_U8: v = (d[0][i * ch + c] - 128) / 128.f; break;
        }
        out[(size_t)i * ch + c] = v;
    }
    av.frame_unref(f);
    return n;
}
void isim_acodec_close(struct isim_acodec *h) {
    if (!h) return;
    if (h->encode) { memset(h->frame, 0, 128); }       /* the frame points at our planes: nothing for av_frame_free to unref */
    av.frame_free(&h->frame); av.packet_free(&h->pkt); av.free_ctx(&h->ctx);
    free(h->fifo); free(h->planes); free(h);
}
