#pragma once
/* isim AudioToolbox for C: CAShow (Apple's CAShow.h): descriptions of AudioToolbox objects, over isim's Swift implementation (swift/overlays/AudioToolbox/AudioFunctions.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#if !defined(__swift__)
#include <stdio.h>
__BEGIN_DECLS
#pragma clang assume_nonnull begin
AT_EXPORT void CAShow(void *inObject);
AT_EXPORT void CAShowFile(void *inObject, FILE *inFile);
#pragma clang assume_nonnull end
__END_DECLS
#endif
