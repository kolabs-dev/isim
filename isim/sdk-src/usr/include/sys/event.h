#pragma once
/* isim SDK (self-authored, Apple's layout and values): kqueue / kevent. isim runs them on the host's epoll, timerfd
 * and eventfd: EVFILT_READ, EVFILT_WRITE, EVFILT_TIMER and EVFILT_USER (adapted); other filters fail with EINVAL. */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <time.h>
__BEGIN_DECLS
#define EVFILT_READ (-1)
#define EVFILT_WRITE (-2)
#define EVFILT_AIO (-3)
#define EVFILT_VNODE (-4)
#define EVFILT_PROC (-5)
#define EVFILT_SIGNAL (-6)
#define EVFILT_TIMER (-7)
#define EVFILT_MACHPORT (-8)
#define EVFILT_FS (-9)
#define EVFILT_USER (-10)
#define EVFILT_VM (-12)
#define EVFILT_EXCEPT (-15)
#define EVFILT_SYSCOUNT 17
struct kevent {
    uintptr_t ident;
    int16_t filter;
    uint16_t flags;
    uint32_t fflags;
    intptr_t data;
    void *udata;
};
struct kevent64_s {
    uint64_t ident;
    int16_t filter;
    uint16_t flags;
    uint32_t fflags;
    int64_t data;
    uint64_t udata;
    uint64_t ext[2];
};
#define EV_SET(kevp, a, b, c, d, e, f) do {                                                                        \
    struct kevent *__kevp__ = (kevp);                                                                           \
    __kevp__->ident = (a); __kevp__->filter = (int16_t)(b); __kevp__->flags = (uint16_t)(c);                    \
    __kevp__->fflags = (uint32_t)(d); __kevp__->data = (e); __kevp__->udata = (f);                             \
} while (0)
#define EV_SET64(kevp, a, b, c, d, e, f, g, h) do {                                                                \
    struct kevent64_s *__kevp__ = (kevp);                                                                       \
    __kevp__->ident = (a); __kevp__->filter = (int16_t)(b); __kevp__->flags = (uint16_t)(c);                    \
    __kevp__->fflags = (uint32_t)(d); __kevp__->data = (e); __kevp__->udata = (f);                             \
    __kevp__->ext[0] = (g); __kevp__->ext[1] = (h);                                                            \
} while (0)
#define EV_ADD 0x0001
#define EV_DELETE 0x0002
#define EV_ENABLE 0x0004
#define EV_DISABLE 0x0008
#define EV_ONESHOT 0x0010
#define EV_CLEAR 0x0020
#define EV_RECEIPT 0x0040
#define EV_DISPATCH 0x0080
#define EV_UDATA_SPECIFIC 0x0100
#define EV_DISPATCH2 (EV_DISPATCH | EV_UDATA_SPECIFIC)
#define EV_VANISHED 0x0200
#define EV_SYSFLAGS 0xF000
#define EV_FLAG0 0x1000
#define EV_FLAG1 0x2000
#define EV_EOF 0x8000
#define EV_ERROR 0x4000
#define EV_POLL EV_FLAG0
#define EV_OOBAND EV_FLAG1
#define NOTE_TRIGGER 0x01000000
#define NOTE_FFNOP 0x00000000
#define NOTE_FFAND 0x40000000
#define NOTE_FFOR 0x80000000
#define NOTE_FFCOPY 0xc0000000
#define NOTE_FFCTRLMASK 0xc0000000
#define NOTE_FFLAGSMASK 0x00ffffff
#define NOTE_LOWAT 0x00000001
#define NOTE_OOB 0x00000002
#define NOTE_DELETE 0x00000001
#define NOTE_WRITE 0x00000002
#define NOTE_EXTEND 0x00000004
#define NOTE_ATTRIB 0x00000008
#define NOTE_LINK 0x00000010
#define NOTE_RENAME 0x00000020
#define NOTE_REVOKE 0x00000040
#define NOTE_NONE 0x00000080
#define NOTE_FUNLOCK 0x00000100
#define NOTE_EXIT 0x80000000
#define NOTE_FORK 0x40000000
#define NOTE_EXEC 0x20000000
#define NOTE_SIGNAL 0x08000000
#define NOTE_EXITSTATUS 0x04000000
#define NOTE_PDATAMASK 0x000fffff
#define NOTE_SECONDS 0x00000001
#define NOTE_USECONDS 0x00000002
#define NOTE_NSECONDS 0x00000004
#define NOTE_ABSOLUTE 0x00000008
#define NOTE_LEEWAY 0x00000010
#define NOTE_CRITICAL 0x00000020
#define NOTE_BACKGROUND 0x00000040
#define NOTE_MACH_CONTINUOUS_TIME 0x00000080
#define NOTE_MACHTIME 0x00000100
#define KEVENT_FLAG_NONE 0x000
#define KEVENT_FLAG_IMMEDIATE 0x001
#define KEVENT_FLAG_ERROR_EVENTS 0x002
int kqueue(void);
int kevent(int kq, const struct kevent *changelist, int nchanges, struct kevent *eventlist, int nevents, const struct timespec *timeout);
int kevent64(int kq, const struct kevent64_s *changelist, int nchanges, struct kevent64_s *eventlist, int nevents,
             unsigned int flags, const struct timespec *timeout);
__END_DECLS
