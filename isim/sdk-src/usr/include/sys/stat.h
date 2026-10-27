#pragma once
/* Darwin struct stat (64-bit inodes); isim translates from the host */
#include <_isim_cdefs.h>
#include <sys/types.h>
#include <time.h>
#include <stdint.h>
__BEGIN_DECLS
struct stat {
    dev_t st_dev; mode_t st_mode; nlink_t st_nlink; ino_t st_ino; uid_t st_uid; gid_t st_gid; dev_t st_rdev;
    struct timespec st_atimespec, st_mtimespec, st_ctimespec, st_birthtimespec;
    off_t st_size; blkcnt_t st_blocks; blksize_t st_blksize; uint32_t st_flags, st_gen; int32_t st_lspare; int64_t st_qspare[2];
};
#define st_atime st_atimespec.tv_sec
#define st_mtime st_mtimespec.tv_sec
#define st_ctime st_ctimespec.tv_sec
/* Typed as mode_t, like Apple's Darwin overlay, so Swift picks open(_:_:_ mode: mode_t) */
#define S_IFMT ((mode_t)0170000)
#define S_IFIFO ((mode_t)0010000)
#define S_IFCHR ((mode_t)0020000)
#define S_IFDIR ((mode_t)0040000)
#define S_IFBLK ((mode_t)0060000)
#define S_IFREG ((mode_t)0100000)
#define S_IFLNK ((mode_t)0120000)
#define S_IFSOCK ((mode_t)0140000)
#define S_IFWHT ((mode_t)0160000)
#define S_IRWXU ((mode_t)0000700)
#define S_IRUSR ((mode_t)0000400)
#define S_IWUSR ((mode_t)0000200)
#define S_IXUSR ((mode_t)0000100)
#define S_IRWXG ((mode_t)0000070)
#define S_IRGRP ((mode_t)0000040)
#define S_IWGRP ((mode_t)0000020)
#define S_IXGRP ((mode_t)0000010)
#define S_IRWXO ((mode_t)0000007)
#define S_IROTH ((mode_t)0000004)
#define S_IWOTH ((mode_t)0000002)
#define S_IXOTH ((mode_t)0000001)
#define S_ISUID ((mode_t)0004000)
#define S_ISGID ((mode_t)0002000)
#define S_ISVTX ((mode_t)0001000)
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
int stat(const char *path, struct stat *buf);
int lstat(const char *path, struct stat *buf);
int fstat(int fd, struct stat *buf);
int mkdir(const char *, mode_t);
int chmod(const char *, mode_t);
int fstatat(int, const char *, struct stat *, int);
mode_t umask(mode_t);
/* st_flags (chflags); isim reports none set */
#define UF_SETTABLE 0x0000ffff
#define UF_NODUMP 0x00000001
#define UF_IMMUTABLE 0x00000002
#define UF_APPEND 0x00000004
#define UF_OPAQUE 0x00000008
#define UF_COMPRESSED 0x00000020
#define UF_TRACKED 0x00000040
#define UF_DATAVAULT 0x00000080
#define UF_HIDDEN 0x00008000
#define SF_SUPPORTED 0x009f0000
#define SF_SETTABLE 0x3fff0000
#define SF_ARCHIVED 0x00010000
#define SF_IMMUTABLE 0x00020000
#define SF_APPEND 0x00040000
#define SF_RESTRICTED 0x00080000
#define SF_NOUNLINK 0x00100000
#define SF_FIRMLINK 0x00800000
#define SF_DATALESS 0x40000000
__END_DECLS
