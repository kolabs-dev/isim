#pragma once
/* Darwin dirent layout (64-bit inodes); isim translates from the host */
#include <_isim_cdefs.h>
#include <stdint.h>
__BEGIN_DECLS
#define DT_UNKNOWN 0
#define DT_FIFO 1
#define DT_CHR 2
#define DT_DIR 4
#define DT_BLK 6
#define DT_REG 8
#define DT_LNK 10
#define DT_SOCK 12
struct dirent { uint64_t d_ino; uint64_t d_seekoff; uint16_t d_reclen; uint16_t d_namlen; uint8_t d_type; char d_name[1024]; };
typedef struct __isim_DIR DIR;
DIR *opendir(const char *name);
struct dirent *readdir(DIR *dir);
int closedir(DIR *dir);
void rewinddir(DIR *dir);
int dirfd(DIR *dir);
__END_DECLS
