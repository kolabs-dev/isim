#pragma once
/* isim SDK (self-authored, Apple's values): sysctl. isim answers the device and process names apps read (hw.machine,
 * hw.ncpu, hw.memsize, kern.osversion, kern.proc for the own process ...) like Apple's Simulator; others fail
 * with ENOENT. */
#include <_isim_cdefs.h>
#include <sys/types.h>
#include <sys/time.h>
__BEGIN_DECLS
#define CTL_MAXNAME 12
#define CTL_UNSPEC 0
#define CTL_KERN 1
#define CTL_VM 2
#define CTL_VFS 3
#define CTL_NET 4
#define CTL_DEBUG 5
#define CTL_HW 6
#define CTL_MACHDEP 7
#define CTL_USER 8
#define KERN_OSTYPE 1
#define KERN_OSRELEASE 2
#define KERN_OSREV 3
#define KERN_VERSION 4
#define KERN_MAXVNODES 5
#define KERN_MAXPROC 6
#define KERN_MAXFILES 7
#define KERN_ARGMAX 8
#define KERN_SECURELVL 9
#define KERN_HOSTNAME 10
#define KERN_HOSTID 11
#define KERN_CLOCKRATE 12
#define KERN_PROC 14
#define KERN_BOOTTIME 21
#define KERN_OSVERSION 65
#define KERN_PROC_ALL 0
#define KERN_PROC_PID 1
#define KERN_PROC_PGRP 2
#define KERN_PROC_SESSION 3
#define KERN_PROC_TTY 4
#define KERN_PROC_UID 5
#define KERN_PROC_RUID 6
#define HW_MACHINE 1
#define HW_MODEL 2
#define HW_NCPU 3
#define HW_BYTEORDER 4
#define HW_PHYSMEM 5
#define HW_USERMEM 6
#define HW_PAGESIZE 7
#define HW_CPU_FREQ 15
#define HW_MEMSIZE 24
#define HW_AVAILCPU 25
#define P_TRACED 0x00000800
/* struct kinfo_proc (KERN_PROC): Apple's size (648 bytes) and the fields apps read; the rest is opaque */
struct extern_proc {
    char __p_un[16];
    void *p_vmspace;
    void *p_sigacts;
    int p_flag;
    char p_stat;
    pid_t p_pid;
    pid_t p_oppid;
    char __rest[244];
};
struct eproc { char __opaque[352]; };
struct kinfo_proc {
    struct extern_proc kp_proc;
    struct eproc kp_eproc;
};
int sysctl(int *, unsigned int, void *, size_t *, void *, size_t);
int sysctlbyname(const char *, void *, size_t *, void *, size_t);
int sysctlnametomib(const char *, int *, size_t *);
__END_DECLS
