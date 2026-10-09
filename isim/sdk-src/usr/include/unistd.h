#pragma once
#include <_isim_cdefs.h>
#include <sys/types.h>
__BEGIN_DECLS
ssize_t read(int, void *, size_t);
ssize_t write(int, const void *, size_t);
int close(int);
ssize_t pread(int, void *, size_t, off_t);
ssize_t pwrite(int, const void *, size_t, off_t);
int pipe(int[2]);
int dup(int);
int dup2(int, int);
int fsync(int);
int ftruncate(int, off_t);
off_t lseek(int, off_t, int);
int access(const char *, int);
int unlink(const char *);
int rmdir(const char *);
ssize_t readlink(const char *, char *, size_t);
char *getcwd(char *, size_t);
pid_t getpid(void);
uid_t getuid(void);
int isatty(int);
int getpagesize(void);
unsigned int sleep(unsigned int);
int usleep(unsigned int);
int gethostname(char *, size_t);
#define STDIN_FILENO 0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
#define R_OK 4
#define W_OK 2
#define X_OK 1
#define F_OK 0
__END_DECLS
