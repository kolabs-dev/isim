/* BSD sockets for guests (included by libsystem.c). Darwin and Linux share the calls but not the data:
 * sockaddrs start with sa_len + an 8-bit family on Darwin (AF_INET6 is 30, not 10), struct addrinfo orders
 * ai_canonname before ai_addr, SOL_SOCKET/SO_* / IPPROTO_* option numbers, MSG_*, AI_ NI_ EAI_ and POLL constants,
 * fcntl flags and errno values above 34 all differ. These wrappers translate in both directions. */
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/un.h>

/* Linux errno -> Darwin errno */
static int darwin_errno(int e) {
    switch (e) {
    case EAGAIN: return 35; case EINPROGRESS: return 36; case EALREADY: return 37; case ENOTSOCK: return 38;
    case EDESTADDRREQ: return 39; case EMSGSIZE: return 40; case EPROTOTYPE: return 41; case ENOPROTOOPT: return 42;
    case EPROTONOSUPPORT: return 43; case ESOCKTNOSUPPORT: return 44; case EOPNOTSUPP: return 102; case EPFNOSUPPORT: return 46;
    case EAFNOSUPPORT: return 47; case EADDRINUSE: return 48; case EADDRNOTAVAIL: return 49; case ENETDOWN: return 50;
    case ENETUNREACH: return 51; case ENETRESET: return 52; case ECONNABORTED: return 53; case ECONNRESET: return 54;
    case ENOBUFS: return 55; case EISCONN: return 56; case ENOTCONN: return 57; case ESHUTDOWN: return 58;
    case ETOOMANYREFS: return 59; case ETIMEDOUT: return 60; case ECONNREFUSED: return 61; case ELOOP: return 62;
    case ENAMETOOLONG: return 63; case EHOSTDOWN: return 64; case EHOSTUNREACH: return 65; case ENOTEMPTY: return 66;
    case EDEADLK: return 11; case ENOLCK: return 77; case ENOSYS: return 78; case EOVERFLOW: return 84;
    case ECANCELED: return 89; case EILSEQ: return 92; case EPROTO: return 100;
    default: return e;
    }
}
#define NETRET(expr) ({ __typeof__(expr) r_ = (expr); if (r_ < 0) errno = darwin_errno(errno); r_; })

#define D_AF_INET6 30
static int host_af(int d) { return d == D_AF_INET6 ? AF_INET6 : d; }
static int darwin_af(int h) { return h == AF_INET6 ? D_AF_INET6 : h; }

/* Darwin sockaddr (len, family, ...) -> host. Returns the host length, or -1 (EAFNOSUPPORT). */
static socklen_t sa_to_host(const void *dsa, socklen_t dlen, struct sockaddr_storage *h) {
    const unsigned char *d = dsa;
    memset(h, 0, sizeof *h);
    if (!d || dlen < 2) { errno = EINVAL; return (socklen_t)-1; }
    int fam = host_af(d[1]);
    socklen_t n;
    switch (fam) {
    case AF_INET: n = sizeof(struct sockaddr_in); break;
    case AF_INET6: n = sizeof(struct sockaddr_in6); break;
    case AF_UNIX: n = dlen > sizeof(struct sockaddr_un) ? sizeof(struct sockaddr_un) : dlen; break;
    case AF_UNSPEC: n = dlen; break;
    default: errno = EAFNOSUPPORT; return (socklen_t)-1;
    }
    if (dlen < n && fam != AF_UNIX) n = dlen;
    if (n > sizeof *h) n = sizeof *h;
    memcpy((char *)h + 2, d + 2, n > 2 ? n - 2 : 0);       /* port/addr/path start at offset 2 on both */
    h->ss_family = (sa_family_t)fam;
    if (fam == AF_UNIX) {
        size_t pl = strnlen((char *)h + 2, sizeof(struct sockaddr_un) - 2);
        n = (socklen_t)(2 + pl + 1);
    }
    return n;
}
/* host sockaddr -> Darwin into a guest buffer of *dlen bytes; *dlen gets the Darwin length */
static void sa_to_darwin(const struct sockaddr *h, socklen_t hlen, void *dsa, socklen_t *dlen) {
    if (!dsa || !dlen) return;
    unsigned char tmp[128]; memset(tmp, 0, sizeof tmp);
    socklen_t n;
    switch (h->sa_family) {
    case AF_INET: n = 16; break;
    case AF_INET6: n = 28; break;
    case AF_UNIX: { size_t pl = hlen > 2 ? strnlen(((struct sockaddr_un *)h)->sun_path, hlen - 2) : 0; if (pl > 103) pl = 103; n = (socklen_t)(2 + pl + 1); break; }
    default: n = hlen < sizeof tmp ? hlen : sizeof tmp; break;
    }
    if (n > sizeof tmp) n = sizeof tmp;
    if (hlen > 2) memcpy(tmp + 2, (const char *)h + 2, (hlen < n ? hlen : n) - 2);
    tmp[0] = (unsigned char)n; tmp[1] = (unsigned char)darwin_af(h->sa_family);
    memcpy(dsa, tmp, *dlen < n ? *dlen : n);
    *dlen = n;
}

/* read/write also serve sockets and pipes, where EAGAIN, ECONNRESET, ... must read as Darwin values */
static ssize_t d_read(int fd, void *b, size_t n) { return NETRET(read(fd, b, n)); }
static ssize_t d_write(int fd, const void *b, size_t n) { return NETRET(write(fd, b, n)); }

static int d_socket(int domain, int type, int proto) { return NETRET(socket(host_af(domain), type, proto)); }
static int d_socketpair(int domain, int type, int proto, int sv[2]) { return NETRET(socketpair(host_af(domain), type, proto, sv)); }
static int d_bind(int fd, const void *sa, socklen_t len) {
    struct sockaddr_storage h; socklen_t n = sa_to_host(sa, len, &h);
    if (n == (socklen_t)-1) { errno = darwin_errno(errno); return -1; }
    return NETRET(bind(fd, (struct sockaddr *)&h, n));
}
static int d_connect(int fd, const void *sa, socklen_t len) {
    struct sockaddr_storage h; socklen_t n = sa_to_host(sa, len, &h);
    if (n == (socklen_t)-1) { errno = darwin_errno(errno); return -1; }
    return NETRET(connect(fd, (struct sockaddr *)&h, n));
}
static int d_listen(int fd, int backlog) { return NETRET(listen(fd, backlog)); }
static int d_accept(int fd, void *sa, socklen_t *len) {
    struct sockaddr_storage h; socklen_t hl = sizeof h;
    int r = accept(fd, (struct sockaddr *)&h, &hl);
    if (r < 0) { errno = darwin_errno(errno); return r; }
    sa_to_darwin((struct sockaddr *)&h, hl, sa, len);
    return r;
}
static int d_getsockname(int fd, void *sa, socklen_t *len) {
    struct sockaddr_storage h; socklen_t hl = sizeof h;
    int r = getsockname(fd, (struct sockaddr *)&h, &hl);
    if (r < 0) { errno = darwin_errno(errno); return r; }
    sa_to_darwin((struct sockaddr *)&h, hl, sa, len);
    return 0;
}
static int d_getpeername(int fd, void *sa, socklen_t *len) {
    struct sockaddr_storage h; socklen_t hl = sizeof h;
    int r = getpeername(fd, (struct sockaddr *)&h, &hl);
    if (r < 0) { errno = darwin_errno(errno); return r; }
    sa_to_darwin((struct sockaddr *)&h, hl, sa, len);
    return 0;
}
/* MSG_*: OOB/PEEK/DONTROUTE match; Darwin WAITALL 0x40, DONTWAIT 0x80, NOSIGNAL 0x80000.
 * Sends never raise SIGPIPE (a simulator app should not be killed by a peer closing; SO_NOSIGPIPE is the iOS habit). */
static int msg_flags(int d) {
    int f = d & 7;
    if (d & 0x40) f |= MSG_WAITALL;
    if (d & 0x80) f |= MSG_DONTWAIT;
    return f;
}
static ssize_t d_send(int fd, const void *b, size_t n, int fl) { return NETRET(send(fd, b, n, msg_flags(fl) | MSG_NOSIGNAL)); }
static ssize_t d_recv(int fd, void *b, size_t n, int fl) { return NETRET(recv(fd, b, n, msg_flags(fl))); }
static ssize_t d_sendto(int fd, const void *b, size_t n, int fl, const void *sa, socklen_t len) {
    if (!sa) return NETRET(sendto(fd, b, n, msg_flags(fl) | MSG_NOSIGNAL, NULL, 0));
    struct sockaddr_storage h; socklen_t hl = sa_to_host(sa, len, &h);
    if (hl == (socklen_t)-1) { errno = darwin_errno(errno); return -1; }
    return NETRET(sendto(fd, b, n, msg_flags(fl) | MSG_NOSIGNAL, (struct sockaddr *)&h, hl));
}
static ssize_t d_recvfrom(int fd, void *b, size_t n, int fl, void *sa, socklen_t *len) {
    struct sockaddr_storage h; socklen_t hl = sizeof h;
    ssize_t r = recvfrom(fd, b, n, msg_flags(fl), (struct sockaddr *)&h, &hl);
    if (r < 0) { errno = darwin_errno(errno); return r; }
    if (sa && len) { if (hl) sa_to_darwin((struct sockaddr *)&h, hl, sa, len); else *len = 0; }
    return r;
}
static int d_shutdown(int fd, int how) { return NETRET(shutdown(fd, how)); }

/* socket options: (Darwin level, name) -> host; returns 0 if unknown */
static int sockopt_map(int dlevel, int dname, int *level, int *name) {
    switch (dlevel) {
    case 0xffff:            /* SOL_SOCKET */
        *level = SOL_SOCKET;
        switch (dname) {
        case 0x0004: *name = SO_REUSEADDR; return 1;   case 0x0008: *name = SO_KEEPALIVE; return 1;
        case 0x0020: *name = SO_BROADCAST; return 1;   case 0x0080: *name = SO_LINGER; return 1;
        case 0x0200: *name = SO_REUSEPORT; return 1;   case 0x1001: *name = SO_SNDBUF; return 1;
        case 0x1002: *name = SO_RCVBUF; return 1;      case 0x1003: *name = SO_SNDLOWAT; return 1;
        case 0x1004: *name = SO_RCVLOWAT; return 1;    case 0x1005: *name = SO_SNDTIMEO; return 1;
        case 0x1006: *name = SO_RCVTIMEO; return 1;    case 0x1007: *name = SO_ERROR; return 1;
        case 0x1008: *name = SO_TYPE; return 1;        case 0x0002: *name = SO_ACCEPTCONN; return 1;
        case 0x0010: *name = SO_DONTROUTE; return 1;   case 0x0100: *name = SO_OOBINLINE; return 1;
        default: return 0;
        }
    case IPPROTO_TCP:
        *level = IPPROTO_TCP;
        switch (dname) {
        case 0x01: *name = TCP_NODELAY; return 1;   case 0x02: *name = TCP_MAXSEG; return 1;
        case 0x10: *name = TCP_KEEPIDLE; return 1;  case 0x101: *name = TCP_KEEPINTVL; return 1;
        case 0x102: *name = TCP_KEEPCNT; return 1;  default: return 0;
        }
    case IPPROTO_IP:
        *level = IPPROTO_IP;
        switch (dname) {
        case 3: *name = IP_TOS; return 1;  case 4: *name = IP_TTL; return 1;  case 2: *name = IP_HDRINCL; return 1;
        case 9: *name = IP_MULTICAST_IF; return 1; case 10: *name = IP_MULTICAST_TTL; return 1; case 11: *name = IP_MULTICAST_LOOP; return 1;
        case 12: *name = IP_ADD_MEMBERSHIP; return 1; case 13: *name = IP_DROP_MEMBERSHIP; return 1;
        default: return 0;
        }
    case IPPROTO_IPV6:
        *level = IPPROTO_IPV6;
        switch (dname) {
        case 27: *name = IPV6_V6ONLY; return 1; case 4: *name = IPV6_UNICAST_HOPS; return 1;
        case 12: *name = IPV6_JOIN_GROUP; return 1; case 13: *name = IPV6_LEAVE_GROUP; return 1;
        default: return 0;
        }
    default: *level = dlevel; *name = dname; return 1;
    }
}
struct d_timeval { long tv_sec; int tv_usec; };
static int d_setsockopt(int fd, int dlevel, int dname, const void *val, socklen_t len) {
    if (dlevel == 0xffff && (dname == 0x1022 || dname == 0x1134)) return 0;   /* SO_NOSIGPIPE (sends never signal), SO_NOADDRERR */
    int level, name;
    if (!sockopt_map(dlevel, dname, &level, &name)) { errno = 42; return -1; }   /* ENOPROTOOPT */
    if (level == SOL_SOCKET && (name == SO_RCVTIMEO || name == SO_SNDTIMEO) && val && len >= sizeof(struct d_timeval)) {
        const struct d_timeval *dt = val; struct timeval tv = { dt->tv_sec, dt->tv_usec };
        return NETRET(setsockopt(fd, level, name, &tv, sizeof tv));
    }
    return NETRET(setsockopt(fd, level, name, val, len));
}
static int d_getsockopt(int fd, int dlevel, int dname, void *val, socklen_t *len) {
    if (dlevel == 0xffff && dname == 0x1022) { if (val && len && *len >= sizeof(int)) { *(int *)val = 1; *len = sizeof(int); } return 0; }
    int level, name;
    if (!sockopt_map(dlevel, dname, &level, &name)) { errno = 42; return -1; }
    if (level == SOL_SOCKET && (name == SO_RCVTIMEO || name == SO_SNDTIMEO)) {
        struct timeval tv; socklen_t l = sizeof tv;
        int r = getsockopt(fd, level, name, &tv, &l);
        if (r < 0) { errno = darwin_errno(errno); return r; }
        if (val && len && *len >= sizeof(struct d_timeval)) { struct d_timeval *dt = val; dt->tv_sec = tv.tv_sec; dt->tv_usec = (int)tv.tv_usec; *len = sizeof *dt; }
        return 0;
    }
    int r = getsockopt(fd, level, name, val, len);
    if (r < 0) { errno = darwin_errno(errno); return r; }
    if (level == SOL_SOCKET && name == SO_ERROR && val) *(int *)val = darwin_errno(*(int *)val);
    return r;
}

/* ---- name resolution ---- */
struct d_addrinfo { int ai_flags, ai_family, ai_socktype, ai_protocol; socklen_t ai_addrlen; char *ai_canonname; void *ai_addr; struct d_addrinfo *ai_next; };
static int ai_flags_host(int d) {
    int f = d & 7;                                     /* PASSIVE, CANONNAME, NUMERICHOST */
    if (d & 0x1000) f |= AI_NUMERICSERV;
    if (d & 0x0400) f |= AI_ADDRCONFIG;
    if (d & 0x0800) f |= AI_V4MAPPED;
    if (d & 0x0100) f |= AI_ALL;
    if (d & 0x0200) f |= AI_V4MAPPED;                  /* AI_V4MAPPED_CFG */
    return f;
}
static int eai_darwin(int e) {
    switch (e) {
    case 0: return 0;
    case EAI_AGAIN: return 2; case EAI_BADFLAGS: return 3; case EAI_FAIL: return 4; case EAI_FAMILY: return 5;
    case EAI_MEMORY: return 6; case EAI_NODATA: return 7; case EAI_NONAME: return 8; case EAI_SERVICE: return 9;
    case EAI_SOCKTYPE: return 10; case EAI_SYSTEM: errno = darwin_errno(errno); return 11; case EAI_OVERFLOW: return 14;
    default: return 4;
    }
}
static int d_getaddrinfo(const char *node, const char *service, const struct d_addrinfo *dh, struct d_addrinfo **res) {
    struct addrinfo hints, *hres = NULL;
    memset(&hints, 0, sizeof hints);
    if (dh) {
        hints.ai_flags = ai_flags_host(dh->ai_flags); hints.ai_family = host_af(dh->ai_family);
        hints.ai_socktype = dh->ai_socktype; hints.ai_protocol = dh->ai_protocol;
    } else hints.ai_flags = AI_V4MAPPED | AI_ADDRCONFIG;     /* Darwin's AI_DEFAULT */
    int e = getaddrinfo(node, service, &hints, &hres);
    if (e) return eai_darwin(e);
    struct d_addrinfo *head = NULL, **tail = &head;
    for (struct addrinfo *a = hres; a; a = a->ai_next) {
        struct d_addrinfo *d = calloc(1, sizeof *d + 128);
        d->ai_flags = dh ? dh->ai_flags : 0; d->ai_family = darwin_af(a->ai_family);
        d->ai_socktype = a->ai_socktype; d->ai_protocol = a->ai_protocol;
        d->ai_addr = d + 1; socklen_t n = 128;
        sa_to_darwin(a->ai_addr, a->ai_addrlen, d->ai_addr, &n);
        d->ai_addrlen = n;
        if (a->ai_canonname) d->ai_canonname = strdup(a->ai_canonname);
        *tail = d; tail = &d->ai_next;
    }
    freeaddrinfo(hres);
    *res = head;
    return 0;
}
static void d_freeaddrinfo(struct d_addrinfo *a) {
    while (a) { struct d_addrinfo *n = a->ai_next; free(a->ai_canonname); free(a); a = n; }
}
static const char *d_gai_strerror(int e) {
    static const char *msg[] = { "Unknown error", "Address family for hostname not supported", "Temporary failure in name resolution",
        "Invalid value for ai_flags", "Non-recoverable failure in name resolution", "ai_family not supported", "Memory allocation failure",
        "No address associated with hostname", "nodename nor servname provided, or not known", "servname not supported for ai_socktype",
        "ai_socktype not supported", "System error returned in errno", "Invalid value for hints", "Resolved protocol is unknown",
        "Argument buffer overflow" };
    return e >= 0 && e < (int)(sizeof msg / sizeof *msg) ? msg[e] : "Unknown error";
}
static int d_getnameinfo(const void *sa, socklen_t salen, char *host, socklen_t hostlen, char *serv, socklen_t servlen, int dflags) {
    struct sockaddr_storage h; socklen_t n = sa_to_host(sa, salen, &h);
    if (n == (socklen_t)-1) return 5;   /* EAI_FAMILY */
    int f = 0;
    if (dflags & 1) f |= NI_NOFQDN; if (dflags & 2) f |= NI_NUMERICHOST; if (dflags & 4) f |= NI_NAMEREQD;
    if (dflags & 8) f |= NI_NUMERICSERV; if (dflags & 16) f |= NI_DGRAM;
    return eai_darwin(getnameinfo((struct sockaddr *)&h, n, host, hostlen, serv, servlen, f));
}
static int d_inet_pton(int af, const char *src, void *dst) { return NETRET(inet_pton(host_af(af), src, dst)); }
static const char *d_inet_ntop(int af, const void *src, char *dst, socklen_t size) {
    const char *r = inet_ntop(host_af(af), src, dst, size);
    if (!r) errno = darwin_errno(errno);
    return r;
}

/* ---- readiness ---- */
struct d_pollfd { int fd; short events, revents; };
static short poll_host(short d) { short h = d & (POLLIN | POLLPRI | POLLOUT | POLLERR | POLLHUP | POLLNVAL | POLLRDNORM | POLLRDBAND); if (d & 0x100) h |= POLLWRBAND; return h; }
static short poll_darwin(short h) { short d = h & (POLLIN | POLLPRI | POLLOUT | POLLERR | POLLHUP | POLLNVAL | POLLRDNORM | POLLRDBAND); if (h & POLLWRNORM) d |= POLLOUT; if (h & POLLWRBAND) d |= 0x100; return d; }
static int d_poll(struct d_pollfd *fds, unsigned int n, int timeout) {   /* Darwin nfds_t is 32-bit */
    for (unsigned i = 0; i < n; i++) fds[i].events = poll_host(fds[i].events);
    int r = poll((struct pollfd *)fds, n, timeout);                     /* same layout */
    int e = errno;
    for (unsigned i = 0; i < n; i++) { fds[i].events = poll_darwin(fds[i].events); fds[i].revents = poll_darwin(fds[i].revents); }
    if (r < 0) errno = darwin_errno(e);
    return r;
}
/* fd_set: 1024 bits in 128 bytes on both, same bit order */
static int d_select(int n, fd_set *r, fd_set *w, fd_set *x, struct d_timeval *dt) {
    struct timeval tv, *tp = NULL;
    if (dt) { tv.tv_sec = dt->tv_sec; tv.tv_usec = dt->tv_usec; tp = &tv; }
    int res = select(n, r, w, x, tp);
    if (res < 0) errno = darwin_errno(errno);
    if (dt) { dt->tv_sec = tv.tv_sec; dt->tv_usec = (int)tv.tv_usec; }
    return res;
}

/* ---- fcntl / ioctl ---- */
struct d_flock { int64_t l_start, l_len; int32_t l_pid; int16_t l_type, l_whence; };
static int oflags_host(long d) { int f = (int)(d & 3); if (d & 4) f |= O_NONBLOCK; if (d & 8) f |= O_APPEND; if (d & 0x40) f |= O_ASYNC; return f; }
static long oflags_darwin(int h) { long d = h & 3; if (h & O_NONBLOCK) d |= 4; if (h & O_APPEND) d |= 8; if (h & O_ASYNC) d |= 0x40; return d; }
static short lock_type_host(short t) { return t == 1 ? F_RDLCK : t == 3 ? F_WRLCK : F_UNLCK; }      /* Darwin: RD 1, UN 2, WR 3 */
static short lock_type_darwin(short t) { return t == F_RDLCK ? 1 : t == F_WRLCK ? 3 : 2; }
static int d_fcntl(int fd, int cmd, long arg) {
    switch (cmd) {
    case 0: return NETRET(fcntl(fd, F_DUPFD, (int)arg));
    case 67: return NETRET(fcntl(fd, F_DUPFD_CLOEXEC, (int)arg));
    case 1: return NETRET(fcntl(fd, F_GETFD));
    case 2: return NETRET(fcntl(fd, F_SETFD, (int)arg));
    case 3: { int r = fcntl(fd, F_GETFL); if (r < 0) { errno = darwin_errno(errno); return r; } return (int)oflags_darwin(r); }
    case 4: return NETRET(fcntl(fd, F_SETFL, oflags_host(arg)));
    case 7: case 8: case 9: {                         /* F_GETLK, F_SETLK, F_SETLKW */
        struct d_flock *dl = (struct d_flock *)arg;
        struct flock hl = { .l_type = lock_type_host(dl->l_type), .l_whence = dl->l_whence, .l_start = dl->l_start, .l_len = dl->l_len, .l_pid = dl->l_pid };
        int r = fcntl(fd, cmd == 7 ? F_GETLK : cmd == 8 ? F_SETLK : F_SETLKW, &hl);
        if (r < 0) { errno = darwin_errno(errno); return r; }
        if (cmd == 7) { dl->l_type = lock_type_darwin(hl.l_type); dl->l_whence = hl.l_whence; dl->l_start = hl.l_start; dl->l_len = hl.l_len; dl->l_pid = hl.l_pid; }
        return r;
    }
    case 50: {                                        /* F_GETPATH: buffer of MAXPATHLEN (1024) */
        char link[64]; snprintf(link, sizeof link, "/proc/self/fd/%d", fd);
        ssize_t n = readlink(link, (char *)arg, 1023);
        if (n < 0) { errno = darwin_errno(errno); return -1; }
        ((char *)arg)[n] = 0; return 0;
    }
    case 51: return 0;                                /* F_FULLFSYNC */
    case 48: return 0;                                /* F_NOCACHE */
    default: errno = EINVAL; return -1;
    }
}
static int d_ioctl(int fd, unsigned long req, void *arg) {
    switch (req) {
    case 0x8004667eUL: return NETRET(ioctl(fd, FIONBIO, arg));      /* FIONBIO */
    case 0x4004667fUL: return NETRET(ioctl(fd, FIONREAD, arg));     /* FIONREAD */
    case 0x20006601UL: return NETRET(ioctl(fd, FIOCLEX));           /* FIOCLEX */
    case 0x20006602UL: return NETRET(ioctl(fd, FIONCLEX));          /* FIONCLEX */
    default: errno = 25; return -1;                                 /* ENOTTY */
    }
}

/* ---- interfaces ---- */
struct d_ifaddrs { struct d_ifaddrs *ifa_next; char *ifa_name; unsigned int ifa_flags; void *ifa_addr, *ifa_netmask, *ifa_dst; void *ifa_data; };  /* ifa_dst: Darwin ifa_dstaddr (a macro on Linux) */
static unsigned int iff_darwin(unsigned int h) { unsigned int d = h & 0x3ff & ~0x400u; if (h & IFF_MULTICAST) d |= 0x8000; return d; }
static int d_getifaddrs(struct d_ifaddrs **out) {
    struct ifaddrs *list;
    if (getifaddrs(&list) < 0) { errno = darwin_errno(errno); return -1; }
    struct d_ifaddrs *head = NULL, **tail = &head;
    for (struct ifaddrs *a = list; a; a = a->ifa_next) {
        if (a->ifa_addr && a->ifa_addr->sa_family != AF_INET && a->ifa_addr->sa_family != AF_INET6) continue;   /* no AF_LINK equivalent */
        struct d_ifaddrs *d = calloc(1, sizeof *d + 3 * 32 + IFNAMSIZ);
        unsigned char *p = (unsigned char *)(d + 1);
        d->ifa_flags = iff_darwin(a->ifa_flags);
        d->ifa_name = (char *)p + 96; snprintf(d->ifa_name, IFNAMSIZ, "%s", a->ifa_name);
        struct sockaddr *src[3] = { a->ifa_addr, a->ifa_netmask, (a->ifa_flags & IFF_POINTOPOINT) ? a->ifa_dstaddr : a->ifa_broadaddr };
        void **dst[3] = { &d->ifa_addr, &d->ifa_netmask, &d->ifa_dst };
        for (int i = 0; i < 3; i++) {
            if (!src[i] || (src[i]->sa_family != AF_INET && src[i]->sa_family != AF_INET6)) continue;
            socklen_t n = 32;
            sa_to_darwin(src[i], src[i]->sa_family == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6), p + 32 * i, &n);
            *dst[i] = p + 32 * i;
        }
        *tail = d; tail = &d->ifa_next;
    }
    freeifaddrs(list);
    *out = head;
    return 0;
}
static void d_freeifaddrs(struct d_ifaddrs *a) { while (a) { struct d_ifaddrs *n = a->ifa_next; free(a); a = n; } }

#define SOCKET_SHIMS \
    A("_socket", d_socket), A("_socketpair", d_socketpair), A("_bind", d_bind), A("_connect", d_connect), A("_listen", d_listen), \
    A("_accept", d_accept), A("_getsockname", d_getsockname), A("_getpeername", d_getpeername), A("_send", d_send), A("_recv", d_recv), \
    A("_sendto", d_sendto), A("_recvfrom", d_recvfrom), A("_shutdown", d_shutdown), A("_setsockopt", d_setsockopt), A("_getsockopt", d_getsockopt), \
    A("_getaddrinfo", d_getaddrinfo), A("_freeaddrinfo", d_freeaddrinfo), A("_gai_strerror", d_gai_strerror), A("_getnameinfo", d_getnameinfo), \
    A("_inet_pton", d_inet_pton), A("_inet_ntop", d_inet_ntop), P(inet_addr), P(inet_ntoa), P(inet_aton), P(htonl), P(htons), P(ntohl), P(ntohs), \
    A("_poll", d_poll), A("_select", d_select), A("_fcntl", d_fcntl), A("_ioctl", d_ioctl), A("_getifaddrs", d_getifaddrs), A("_freeifaddrs", d_freeifaddrs), \
    P(if_nametoindex), P(if_indextoname), P(gethostname), A("_in6addr_any", &in6addr_any), A("_in6addr_loopback", &in6addr_loopback)
