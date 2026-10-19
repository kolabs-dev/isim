/* isim runtime: the platform layer, the operating-system services the runtime needs beyond portable C and its libraries
 * (SDL, cairo, ...): starting processes, opening things on the desktop, shared memory, IPC, control channels, the
 * runtime's own path. Linux implements it in platform_posix.c; another host adds its own file (native Windows,
 * issue #491). Runtime code calls these instead of fork/exec, memfd_create, socketpair, mkfifo or /proc
 * (docs/BUILD.md, "Portability"; isim/tools/portability-check.py keeps those from coming back). */
#pragma once
#include <stddef.h>
#include <sys/types.h>

/* a process to start (isim_spawn) */
struct isim_spawn {
    const char *path;                /* the program: a path, or a name looked up on PATH */
    char *const *argv;               /* its arguments, argv[0] first, NULL-terminated */
    char *const *env;                /* its whole environment ("KEY=VALUE", NULL-terminated); NULL: ours, changed by: */
    const char *const *set_env;      /* "KEY=VALUE" entries to set (NULL-terminated, or NULL) */
    const char *const *unset_env;    /* names to remove (NULL-terminated, or NULL) */
    const int *keep;                 /* handles the child inherits under the same numbers (-1-terminated, or NULL) */
    int remap_from, remap_to;        /* one handle the child gets under another number (remap_to > 0 to use) */
    int null_stdin, null_stdout, null_stderr;   /* the null device instead of ours */
    int close_others;                /* close every other inherited handle (beyond stdio, keep and remap) */
    int die_with_parent;             /* the child is killed when this process exits (apps under the device shell) */
    int new_session;                 /* detached from our terminal and process group (desktop handlers) */
};
/* starts the program; returns the child, or -1 with errno saying why (including the program failing to start) */
pid_t isim_spawn(const struct isim_spawn *s);

/* the desktop's default handler opens a URL, a file or a folder (xdg-open); returns 1 if one was started */
int isim_open_on_desktop(const char *url_or_path);

/* the running runtime's executable (/proc/self/exe); returns its length, or -1 */
int isim_self_path(char *buf, size_t cap);

/* this process's command line: its arguments into argv (pointing into buf), NULL-terminated; returns their count, or -1 */
int isim_self_args(char *buf, size_t cap, char **argv, int max);
/* the runtime starts again in this process's place with argv (the device restarting with other options); open handles
 * that are not close-on-exec stay open (the control FIFO); returns only on failure (-1, errno) */
int isim_restart_self(char *const *argv);

/* shared memory: an object of `size` bytes another process maps too (pass the handle in isim_spawn's keep and its
 * number to the child); returns the handle, or -1 */
int isim_shm_create(const char *name, size_t size);
/* maps a shared-memory handle (from isim_shm_create, here or in the parent); NULL on failure */
void *isim_shm_map(int handle, size_t size, int writable);
void isim_shm_unmap(void *p, size_t size);

/* a connected pair of handles for messages between two processes (packets: message boundaries kept, else a byte
 * stream), both closed when a spawned program starts unless kept; returns 0, or -1 */
int isim_ipc_pair(int handles[2], int packets);

/* a control channel at path (a FIFO): other processes write command lines to it, the device reads them
 * (ISIM_CONTROL, `isim send`); returns 0, or -1 */
int isim_ctl_create(const char *path);
