#pragma once
/* isim SDK (self-authored, Apple's layout): the user database. Like an iOS device, it has the one user apps run as,
 * "mobile", whose home is the app's container (adapted). */
#include <_isim_cdefs.h>
#include <sys/types.h>
#include <time.h>
__BEGIN_DECLS
struct passwd {
    char *pw_name;
    char *pw_passwd;
    uid_t pw_uid;
    gid_t pw_gid;
    time_t pw_change;
    char *pw_class;
    char *pw_gecos;
    char *pw_dir;
    char *pw_shell;
    time_t pw_expire;
};
struct passwd *getpwnam(const char *);
struct passwd *getpwuid(uid_t);
int getpwnam_r(const char *, struct passwd *, char *, size_t, struct passwd **);
int getpwuid_r(uid_t, struct passwd *, char *, size_t, struct passwd **);
struct passwd *getpwent(void);
void setpwent(void);
void endpwent(void);
__END_DECLS
