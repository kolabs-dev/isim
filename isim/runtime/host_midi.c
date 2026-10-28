/*
 * isim host MIDI (issue #390): the host's MIDI ports for an app's CoreMIDI, through the ALSA sequencer (libasound,
 * loaded with dlopen only when an app uses CoreMIDI; a port lists its own MIDI API). isim opens one sequencer client
 * ("isim") with one port, reads from every readable port of the other clients and writes to a port when the app sends
 * to it. Messages are MIDI 1.0 bytes, encoded and decoded by ALSA's MIDI event parser. Without libasound or a
 * sequencer (/dev/snd/seq), or with ISIM_MIDI_HOST=0, there are no host ports.
 */
#include "guest_abi.h"
#include <dlfcn.h>
#include <poll.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the host's ALSA library names */
static const char *const ASOUND_LIBRARIES[] = { "libasound.so.2", "libasound.so" };

/* the parts of ALSA's sequencer API isim uses (alsa/seq.h, seq_event.h, seqmid.h) */
enum { SEQ_OPEN_DUPLEX = 3, SEQ_NONBLOCK = 1, CAP_READ = 1 << 0, CAP_WRITE = 1 << 1, CAP_SUBS_READ = 1 << 5, CAP_SUBS_WRITE = 1 << 6,
       CAP_NO_EXPORT = 1 << 7, TYPE_MIDI_GENERIC = 1 << 1, TYPE_APPLICATION = 1 << 20, QUEUE_DIRECT = 253, CLIENT_SYSTEM = 0 };
typedef struct { unsigned char client, port; } seq_addr;
typedef struct {
    unsigned char type, flags, tag, queue;
    unsigned char time[8];
    seq_addr source, dest;
    unsigned char data[12];
} seq_event;
typedef struct snd_seq snd_seq_t;
typedef struct snd_info snd_info_t;
typedef struct snd_midi_event snd_midi_event_t;

static struct {
    int (*open)(snd_seq_t **, const char *, int, int);
    int (*set_client_name)(snd_seq_t *, const char *);
    int (*create_simple_port)(snd_seq_t *, const char *, unsigned, unsigned);
    int (*client_id)(snd_seq_t *);
    int (*client_info_malloc)(snd_info_t **);
    void (*client_info_set_client)(snd_info_t *, int);
    int (*client_info_get_client)(const snd_info_t *);
    int (*query_next_client)(snd_seq_t *, snd_info_t *);
    int (*port_info_malloc)(snd_info_t **);
    void (*port_info_set_client)(snd_info_t *, int);
    void (*port_info_set_port)(snd_info_t *, int);
    int (*port_info_get_port)(const snd_info_t *);
    unsigned (*port_info_get_capability)(const snd_info_t *);
    const char *(*port_info_get_name)(const snd_info_t *);
    int (*query_next_port)(snd_seq_t *, snd_info_t *);
    int (*connect_from)(snd_seq_t *, int, int, int);
    int (*event_output_direct)(snd_seq_t *, seq_event *);
    int (*event_input)(snd_seq_t *, seq_event **);
    int (*poll_descriptors)(snd_seq_t *, struct pollfd *, unsigned, short);
    int (*nonblock)(snd_seq_t *, int);
    int (*midi_event_new)(size_t, snd_midi_event_t **);
    long (*midi_event_encode)(snd_midi_event_t *, const unsigned char *, long, seq_event *);
    long (*midi_event_decode)(snd_midi_event_t *, unsigned char *, long, const seq_event *);
    void (*midi_event_reset_encode)(snd_midi_event_t *);
    void (*midi_event_no_status)(snd_midi_event_t *, int);
} A;

static snd_seq_t *seq;
static int my_port = -1;
static snd_midi_event_t *encoder, *decoder;
static pthread_mutex_t midi_mtx = PTHREAD_MUTEX_INITIALIZER;
static int tried;

static void quiet_alsa(const char *file, int line, const char *function, int err, const char *fmt, ...) {}

static int midi_load(void) {
    if (tried) return seq != NULL;
    tried = 1;
    const char *off = getenv("ISIM_MIDI_HOST");
    if (off && !strcmp(off, "0")) return 0;
    void *lib = NULL;
    for (size_t i = 0; !lib && i < sizeof ASOUND_LIBRARIES / sizeof *ASOUND_LIBRARIES; i++) lib = dlopen(ASOUND_LIBRARIES[i], RTLD_NOW | RTLD_LOCAL);
    if (!lib) return 0;
#define L(field, name) if (!(*(void **)&A.field = dlsym(lib, name))) return 0;
    L(open, "snd_seq_open") L(set_client_name, "snd_seq_set_client_name") L(create_simple_port, "snd_seq_create_simple_port")
    L(client_id, "snd_seq_client_id") L(client_info_malloc, "snd_seq_client_info_malloc")
    L(client_info_set_client, "snd_seq_client_info_set_client") L(client_info_get_client, "snd_seq_client_info_get_client")
    L(query_next_client, "snd_seq_query_next_client") L(port_info_malloc, "snd_seq_port_info_malloc")
    L(port_info_set_client, "snd_seq_port_info_set_client") L(port_info_set_port, "snd_seq_port_info_set_port")
    L(port_info_get_port, "snd_seq_port_info_get_port") L(port_info_get_capability, "snd_seq_port_info_get_capability")
    L(port_info_get_name, "snd_seq_port_info_get_name") L(query_next_port, "snd_seq_query_next_port")
    L(connect_from, "snd_seq_connect_from") L(event_output_direct, "snd_seq_event_output_direct")
    L(event_input, "snd_seq_event_input") L(poll_descriptors, "snd_seq_poll_descriptors") L(nonblock, "snd_seq_nonblock")
    L(midi_event_new, "snd_midi_event_new") L(midi_event_encode, "snd_midi_event_encode")
    L(midi_event_decode, "snd_midi_event_decode") L(midi_event_reset_encode, "snd_midi_event_reset_encode")
    L(midi_event_no_status, "snd_midi_event_no_status")
#undef L
    /* libasound reports a missing sequencer (no /dev/snd/seq) on stderr: keep it quiet, that only means no host ports */
    int (*set_error_handler)(void (*)(const char *, int, const char *, int, const char *, ...)) =
        (int (*)(void (*)(const char *, int, const char *, int, const char *, ...)))dlsym(lib, "snd_lib_error_set_handler");
    if (set_error_handler) set_error_handler(quiet_alsa);
    snd_seq_t *s;
    if (A.open(&s, "default", SEQ_OPEN_DUPLEX, SEQ_NONBLOCK) < 0) return 0;
    A.set_client_name(s, "isim");
    my_port = A.create_simple_port(s, "isim", CAP_READ | CAP_WRITE | CAP_SUBS_READ | CAP_SUBS_WRITE, TYPE_MIDI_GENERIC | TYPE_APPLICATION);
    if (my_port < 0 || A.midi_event_new(4096, &encoder) < 0 || A.midi_event_new(4096, &decoder) < 0) return 0;
    A.midi_event_no_status(decoder, 1);       // no running status: each message whole
    seq = s;
    return 1;
}

/* the host's MIDI ports: one line each, "ID\tNAME\tFLAGS" (r: the port sends, w: it receives); their count, or 0 */
ISIM_GUEST_ABI int isim_midi_host_ports(char *buf, int len) {
    pthread_mutex_lock(&midi_mtx);
    int n = 0, used = 0;
    if (buf && len > 0) buf[0] = 0;
    if (!midi_load()) goto out;
    snd_info_t *ci, *pi;
    if (A.client_info_malloc(&ci) < 0 || A.port_info_malloc(&pi) < 0) goto out;
    int me = A.client_id(seq);
    A.client_info_set_client(ci, -1);
    while (A.query_next_client(seq, ci) >= 0) {
        int client = A.client_info_get_client(ci);
        if (client == me || client == CLIENT_SYSTEM) continue;
        A.port_info_set_client(pi, client);
        A.port_info_set_port(pi, -1);
        while (A.query_next_port(seq, pi) >= 0) {
            unsigned caps = A.port_info_get_capability(pi);
            int port = A.port_info_get_port(pi);
            if (caps & CAP_NO_EXPORT) continue;
            int r = (caps & (CAP_READ | CAP_SUBS_READ)) == (CAP_READ | CAP_SUBS_READ);
            int w = (caps & (CAP_WRITE | CAP_SUBS_WRITE)) == (CAP_WRITE | CAP_SUBS_WRITE);
            if (!r && !w) continue;
            if (r) A.connect_from(seq, my_port, client, port);
            if (buf && used < len)
                used += snprintf(buf + used, (size_t)(len - used), "%d\t%s\t%s%s\n", client << 8 | port, A.port_info_get_name(pi), r ? "r" : "", w ? "w" : "");
            n++;
        }
    }
    // (the info structs are small and the listing runs once per process)
out:
    pthread_mutex_unlock(&midi_mtx);
    return n;
}

/* sends MIDI 1.0 bytes to a host port; 0 on success */
ISIM_GUEST_ABI int isim_midi_host_send(int id, const unsigned char *bytes, int n) {
    pthread_mutex_lock(&midi_mtx);
    int rc = -1;
    if (!midi_load() || n <= 0) goto out;
    A.midi_event_reset_encode(encoder);
    for (int i = 0; i < n;) {
        seq_event ev;
        memset(&ev, 0, sizeof ev);
        long used = A.midi_event_encode(encoder, bytes + i, n - i, &ev);
        if (used <= 0) break;
        i += (int)used;
        if (!ev.type) continue;                    // the message is not complete yet
        ev.queue = QUEUE_DIRECT;
        ev.source.port = (unsigned char)my_port;
        ev.dest.client = (unsigned char)(id >> 8); ev.dest.port = (unsigned char)id;
        if (A.event_output_direct(seq, &ev) < 0) goto out;
    }
    rc = 0;
out:
    pthread_mutex_unlock(&midi_mtx);
    return rc;
}

/* the next message from a host port, waiting up to timeout seconds: its length (0: none) and the port's ID */
ISIM_GUEST_ABI int isim_midi_host_receive(unsigned char *buf, int len, int *id, double timeout) {
    if (!seq) return 0;
    struct pollfd fds[4];
    pthread_mutex_lock(&midi_mtx);
    int nfds = A.poll_descriptors(seq, fds, 4, POLLIN);
    pthread_mutex_unlock(&midi_mtx);
    if (nfds <= 0 || poll(fds, (nfds_t)nfds, (int)(timeout * 1000)) <= 0) return 0;
    pthread_mutex_lock(&midi_mtx);
    int n = 0;
    seq_event *ev = NULL;
    while (!n && A.event_input(seq, &ev) >= 0 && ev) {
        long got = A.midi_event_decode(decoder, buf, len, ev);
        if (got > 0) { n = (int)got; if (id) *id = ev->source.client << 8 | ev->source.port; }
    }
    pthread_mutex_unlock(&midi_mtx);
    return n;
}
