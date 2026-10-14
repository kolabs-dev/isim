#pragma once
/* isim SDK (self-authored, Apple's values): extended attributes. isim keeps them as the host file system's "user."
 * attributes (adapted: `position` must be 0, resource forks are not supported). */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <sys/types.h>
__BEGIN_DECLS
#define XATTR_NOFOLLOW 0x0001
#define XATTR_CREATE 0x0002
#define XATTR_REPLACE 0x0004
#define XATTR_NOSECURITY 0x0008
#define XATTR_NODEFAULT 0x0010
#define XATTR_SHOWCOMPRESSION 0x0020
#define XATTR_NOFOLLOW_ANY 0x0040
#define XATTR_MAXNAMELEN 127
#define XATTR_FINDERINFO_NAME "com.apple.FinderInfo"
#define XATTR_RESOURCEFORK_NAME "com.apple.ResourceFork"
ssize_t getxattr(const char *path, const char *name, void *value, size_t size, uint32_t position, int options);
ssize_t fgetxattr(int fd, const char *name, void *value, size_t size, uint32_t position, int options);
int setxattr(const char *path, const char *name, const void *value, size_t size, uint32_t position, int options);
int fsetxattr(int fd, const char *name, const void *value, size_t size, uint32_t position, int options);
int removexattr(const char *path, const char *name, int options);
int fremovexattr(int fd, const char *name, int options);
ssize_t listxattr(const char *path, char *namebuff, size_t size, int options);
ssize_t flistxattr(int fd, char *namebuff, size_t size, int options);
__END_DECLS
