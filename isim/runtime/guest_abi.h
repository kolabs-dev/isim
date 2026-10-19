/* isim runtime: the guest ABI boundary markers (included by runtime.h; host files that hand functions to guests
   without runtime.h include this alone). */
#pragma once

/* The guest ABI boundary (native Windows, issue #491; docs/BUILD.md, "Portability"). Guest code is x86-64 System V
 * (Darwin's calling convention). On Linux that is also the host's own convention, so the attribute changes nothing
 * there; it still makes every Linux build check that each mark sits where a calling convention can go. A Windows host
 * needs it: its own convention is Microsoft's x64, and a function without the mark would read its arguments from the
 * wrong registers.
 *   ISIM_GUEST_ABI       on every host function a symbol table hands to guests (struct shim, runtime.h), at the start
 *                        of its definition and of every prototype: `ISIM_GUEST_ABI static int d_open(...)` (a Windows
 *                        compiler rejects a prototype and a definition that disagree)
 *   ISIM_GUEST_CALLBACK  in function pointer types the host calls guest code through (qsort comparators, thread start
 *                        routines, blocks' invoke functions): `typedef int (ISIM_GUEST_CALLBACK *cmp_fn)(const void *, const void *)`
 * isim/tools/portability-check.py (run by the CI build) reports guest-facing functions without the mark. */
#if defined(__x86_64__)
#define ISIM_GUEST_ABI __attribute__((sysv_abi))
#define ISIM_GUEST_CALLBACK __attribute__((sysv_abi))
#else
#define ISIM_GUEST_ABI
#define ISIM_GUEST_CALLBACK
#endif
