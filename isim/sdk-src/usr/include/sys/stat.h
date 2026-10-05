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
#define S_IFMT 0170000
#define S_IFIFO 0010000
#define S_IFCHR 0020000
#define S_IFDIR 0040000
#define S_IFBLK 0060000
#define S_IFREG 0100000
#define S_IFLNK 0120000
#define S_IFSOCK 0140000
#define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
#define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
#define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
int stat(const char *path, struct stat *buf);
int lstat(const char *path, struct stat *buf);
int fstat(int fd, struct stat *buf);
int mkdir(const char *, mode_t);
int chmod(const char *, mode_t);
__END_DECLS
