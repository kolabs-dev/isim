/* isim SDK (self-authored, not Apple's). Common C declarations helpers. */
#pragma once
#ifdef __cplusplus
#define __BEGIN_DECLS extern "C" {
#define __END_DECLS }
#else
#define __BEGIN_DECLS
#define __END_DECLS
#endif
#ifndef NULL
#define NULL ((void *)0)
#endif
