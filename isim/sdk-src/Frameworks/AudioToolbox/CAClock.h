#pragma once
/* isim AudioToolbox for C: CAClock (Apple's CoreAudioClock.h, CAClock.h in AudioToolbox): a timeline in seconds, beats and SMPTE time over
 * host time (swift/overlays/AudioToolbox/CAClock.swift). */
#include <AudioToolbox/AudioToolboxBase.h>
#include <CoreMIDI/MIDIServices.h>
#if !defined(__swift__)
__BEGIN_DECLS
#pragma clang assume_nonnull begin
enum {
    kCAClock_UnknownPropertyError = -66816,
    kCAClock_InvalidPropertySizeError = -66815,
    kCAClock_InvalidTimeFormatError = -66814,
    kCAClock_InvalidSyncModeError = -66813,
    kCAClock_InvalidSyncSourceError = -66812,
    kCAClock_InvalidTimebaseError = -66811,
    kCAClock_InvalidTimebaseSourceError = -66810,
    kCAClock_InvalidSMPTEFormatError = -66809,
    kCAClock_InvalidSMPTEOffsetError = -66808,
    kCAClock_InvalidUnitError = -66807,
    kCAClock_InvalidPlayRateError = -66806,
    kCAClock_CannotSetTimeError = -66805,
};
AT_EXPORT OSStatus CAClockNew(UInt32 inReservedFlags, CAClockRef _Nullable *_Nonnull outCAClock);
AT_EXPORT OSStatus CAClockDispose(CAClockRef inCAClock);
AT_EXPORT OSStatus CAClockGetPropertyInfo(CAClockRef inCAClock, CAClockPropertyID inPropertyID, UInt32 * _Nullable outSize, Boolean * _Nullable outWritable);
AT_EXPORT OSStatus CAClockGetProperty(CAClockRef inCAClock, CAClockPropertyID inPropertyID, UInt32 *ioPropertyDataSize, void *outPropertyData);
AT_EXPORT OSStatus CAClockSetProperty(CAClockRef inCAClock, CAClockPropertyID inPropertyID, UInt32 inPropertyDataSize, const void *inPropertyData);
AT_EXPORT OSStatus CAClockAddListener(CAClockRef inCAClock, CAClockListenerProc inListenerProc, void *inUserData);
AT_EXPORT OSStatus CAClockRemoveListener(CAClockRef inCAClock, CAClockListenerProc inListenerProc, void *inUserData);
AT_EXPORT OSStatus CAClockSetCurrentTime(CAClockRef inCAClock, const CAClockTime *inTime);
AT_EXPORT OSStatus CAClockGetCurrentTime(CAClockRef inCAClock, CAClockTimeFormat inTimeFormat, CAClockTime *outTime);
AT_EXPORT OSStatus CAClockGetStartTime(CAClockRef inCAClock, CAClockTimeFormat inTimeFormat, CAClockTime *outTime);
AT_EXPORT OSStatus CAClockTranslateTime(CAClockRef inCAClock, const CAClockTime *inTime, CAClockTimeFormat inOutputTimeFormat, CAClockTime *outTime);
AT_EXPORT OSStatus CAClockStart(CAClockRef inCAClock);
AT_EXPORT OSStatus CAClockStop(CAClockRef inCAClock);
AT_EXPORT OSStatus CAClockArm(CAClockRef inCAClock);
AT_EXPORT OSStatus CAClockDisarm(CAClockRef inCAClock);
AT_EXPORT OSStatus CAClockSetPlayRate(CAClockRef inCAClock, Float64 inPlayRate);
AT_EXPORT OSStatus CAClockGetPlayRate(CAClockRef inCAClock, Float64 *outPlayRate);
AT_EXPORT OSStatus CAClockGetCurrentTempo(CAClockRef inCAClock, CAClockTempo *outTempo, CAClockTime * _Nullable outTimestamp);
AT_EXPORT OSStatus CAClockSetCurrentTempo(CAClockRef inCAClock, CAClockTempo inTempo, const CAClockTime * _Nullable inTimestamp);
AT_EXPORT OSStatus CAClockSecondsToSMPTETime(CAClockRef inCAClock, CAClockSeconds inSeconds, UInt16 inSubframeDivisor, SMPTETime *outSMPTETime);
AT_EXPORT OSStatus CAClockSMPTETimeToSeconds(CAClockRef inCAClock, const SMPTETime *inSMPTETime, CAClockSeconds *outSeconds);
AT_EXPORT OSStatus CAClockBeatsToBarBeatTime(CAClockRef inCAClock, CAClockBeats inBeats, UInt16 inSubbeatDivisor, CABarBeatTime *outBarBeatTime);
AT_EXPORT OSStatus CAClockBarBeatTimeToBeats(CAClockRef inCAClock, const CABarBeatTime *inBarBeatTime, CAClockBeats *outBeats);
AT_EXPORT OSStatus CAClockParseMIDI(CAClockRef inCAClock, const MIDIPacketList *inMIDIPacketList);
#pragma clang assume_nonnull end
__END_DECLS
#endif
