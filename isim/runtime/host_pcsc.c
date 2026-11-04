/* libisim_host PC/SC (issue #745): CryptoTokenKit's real card readers over the host's pcsclite (passthrough), dlopen'd
   the first time an app lists its slots, and only when ISIM_PCSC=1. The readers are pcscd's (SCardListReaders), their
   state and cards' ATRs come from SCardGetStatusChange, a session is SCardConnect (shared) + SCardBeginTransaction, and
   each APDU is one SCardTransmit. Without pcsclite, without a running pcscd or without ISIM_PCSC=1 there are no readers
   (isim_pcsc_readers gives NULL), and apps see only the virtual readers of readers.json. */
#include "guest_abi.h"
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* pcsclite's types on Linux: LONG is long, DWORD unsigned long, the contexts and card handles LONG */
typedef long pc_long;
typedef unsigned long pc_dword;
typedef struct { const char *reader; void *user; pc_dword current, event, atr_len; unsigned char atr[33]; } pc_state;
typedef struct { pc_dword protocol, pci_length; } pc_io;

enum {
    SCOPE_SYSTEM = 2, SHARE_SHARED = 2, PROTO_T0 = 1, PROTO_T1 = 2, LEAVE_CARD = 0, RESET_CARD = 1,
    STATE_EMPTY = 0x10, STATE_PRESENT = 0x20, STATE_MUTE = 0x200,
};

static struct {
    int state;
    pc_long ctx;
    pc_long (*establish)(pc_dword, const void *, const void *, pc_long *);
    pc_long (*release)(pc_long);
    pc_long (*valid)(pc_long);
    pc_long (*list)(pc_long, const char *, char *, pc_dword *);
    pc_long (*status)(pc_long, pc_dword, pc_state *, pc_dword);
    pc_long (*connect)(pc_long, const char *, pc_dword, pc_dword, pc_long *, pc_dword *);
    pc_long (*disconnect)(pc_long, pc_dword);
    pc_long (*begin)(pc_long);
    pc_long (*end)(pc_long, pc_dword);
    pc_long (*transmit)(pc_long, const pc_io *, const unsigned char *, pc_dword, pc_io *, unsigned char *, pc_dword *);
} pc;
static pthread_mutex_t pc_lock = PTHREAD_MUTEX_INITIALIZER;

static int load(void) {
    if (pc.state) return pc.state > 0;
    pc.state = -1;
    const char *on = getenv("ISIM_PCSC");
    if (!on || strcmp(on, "1")) return 0;
    void *lib = dlopen("libpcsclite.so.1", RTLD_NOW | RTLD_LOCAL);   /* linux-only: pcsclite's soname (until #491's library table) */
    if (!lib) { fprintf(stderr, "isim: ISIM_PCSC=1 but the host has no libpcsclite.so.1: no PC/SC readers\n"); return 0; }
#define SYM(field, name) if (!(*(void **)&pc.field = dlsym(lib, name))) return 0
    SYM(establish, "SCardEstablishContext"); SYM(release, "SCardReleaseContext"); SYM(valid, "SCardIsValidContext");
    SYM(list, "SCardListReaders"); SYM(status, "SCardGetStatusChange"); SYM(connect, "SCardConnect");
    SYM(disconnect, "SCardDisconnect"); SYM(begin, "SCardBeginTransaction"); SYM(end, "SCardEndTransaction");
    SYM(transmit, "SCardTransmit");
#undef SYM
    pc.state = 1;
    return 1;
}

/* a context, (re-)established when pcscd was not running or restarted; the caller holds pc_lock */
static int context(void) {
    if (!load()) return 0;
    if (pc.ctx && pc.valid(pc.ctx) == 0) return 1;
    if (pc.ctx) { pc.release(pc.ctx); pc.ctx = 0; }
    pc_long c = 0;
    if (pc.establish(SCOPE_SYSTEM, NULL, NULL, &c) != 0) return 0;
    pc.ctx = c;
    return 1;
}

static void hex(char *out, const unsigned char *b, size_t n) {
    for (size_t i = 0; i < n; i++) sprintf(out + 2 * i, "%02X", b[i]);
    out[2 * n] = 0;
}

/* one line per reader: name \t state (empty, present, mute) \t ATR (hex, "" without a card) \t the reader's event count
   (it changes when a card is inserted or removed); "" when pcscd has no readers, NULL without PC/SC (or ISIM_PCSC=1).
   The caller frees it (isim_media_free). */
ISIM_GUEST_ABI char *isim_pcsc_readers(void) {
    pthread_mutex_lock(&pc_lock);
    char *out = NULL;
    if (!context()) goto done;
    pc_dword len = 0;
    pc_long r = pc.list(pc.ctx, NULL, NULL, &len);
    if (r != 0 || len < 2) { out = strdup(""); goto done; }                /* SCARD_E_NO_READERS_AVAILABLE, ... */
    char *names = malloc(len);
    if (pc.list(pc.ctx, NULL, names, &len) != 0) { free(names); out = strdup(""); goto done; }
    int n = 0;
    for (char *p = names; *p; p += strlen(p) + 1) n++;
    pc_state *st = calloc(n ? n : 1, sizeof *st);
    int i = 0;
    for (char *p = names; *p; p += strlen(p) + 1) st[i++].reader = p;
    int known = n && pc.status(pc.ctx, 0, st, (pc_dword)n) == 0;
    size_t cap = 256, used = 0;
    out = malloc(cap);
    out[0] = 0;
    for (i = 0; i < n; i++) {
        pc_dword ev = known ? st[i].event : 0;
        const char *s = (ev & STATE_MUTE) ? "mute" : (ev & STATE_PRESENT) ? "present" : "empty";
        char atr[67] = "";
        if ((ev & STATE_PRESENT) && st[i].atr_len <= sizeof st[i].atr) hex(atr, st[i].atr, st[i].atr_len);
        size_t need = strlen(st[i].reader) + strlen(atr) + 48;
        if (used + need >= cap) { cap = (used + need) * 2; out = realloc(out, cap); }
        used += (size_t)sprintf(out + used, "%s\t%s\t%s\t%lu\n", st[i].reader, s, atr, (unsigned long)(ev >> 16));
    }
    free(st);
    free(names);
done:
    pthread_mutex_unlock(&pc_lock);
    return out;
}

/* a session with the card in a reader: connects (shared, T=0 or T=1 as `protocols` allows: bit 0 T=0, bit 1 T=1) and
   begins a transaction. Returns the card handle (0: failed) and the protocol in use (0 or 1) in *protocol. */
ISIM_GUEST_ABI int64_t isim_pcsc_begin(const char *reader, int protocols, int *protocol) {
    pthread_mutex_lock(&pc_lock);
    int ok = context();
    pc_long ctx = pc.ctx;
    pthread_mutex_unlock(&pc_lock);
    if (!ok || !reader) return 0;
    pc_dword want = ((protocols & 1) ? PROTO_T0 : 0) | ((protocols & 2) ? PROTO_T1 : 0), active = 0;
    pc_long h = 0;
    if (!want || pc.connect(ctx, reader, SHARE_SHARED, want, &h, &active) != 0) return 0;
    if (pc.begin(h) != 0) { pc.disconnect(h, LEAVE_CARD); return 0; }
    if (protocol) *protocol = active == PROTO_T1 ? 1 : 0;
    return (int64_t)h;
}

/* one command APDU; the response (data, SW1, SW2) goes into `out` (at most `cap` bytes). Returns its length, -1 on a
   communication error (the card was removed, the reader is gone). */
ISIM_GUEST_ABI int isim_pcsc_transmit(int64_t handle, int protocol, const uint8_t *apdu, int len, uint8_t *out, int cap) {
    if (pc.state <= 0 || !handle || len < 0 || cap < 2) return -1;
    pc_io send = { protocol == 1 ? PROTO_T1 : PROTO_T0, sizeof(pc_io) };
    pc_dword n = (pc_dword)cap;
    if (pc.transmit((pc_long)handle, &send, apdu, (pc_dword)len, NULL, out, &n) != 0) return -1;
    return (int)n;
}

/* ends the session: the transaction, and the connection (the card is reset when `reset`, which clears its security
   state) */
ISIM_GUEST_ABI void isim_pcsc_end(int64_t handle, int reset) {
    if (pc.state <= 0 || !handle) return;
    pc.end((pc_long)handle, reset ? RESET_CARD : LEAVE_CARD);
    pc.disconnect((pc_long)handle, reset ? RESET_CARD : LEAVE_CARD);
}
