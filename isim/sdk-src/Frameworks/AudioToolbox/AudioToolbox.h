#pragma once
/* isim AudioToolbox for C and Objective-C: Audio Units, Audio Queues, audio files, converters and system sounds over
 * isim's Swift AudioToolbox (swift/overlays/AudioToolbox, CAPI.swift): an AudioQueueRef or AudioUnit made in C is the
 * object Swift code sees and the other way round. AudioToolbox.framework re-exports libswiftAudioToolbox. Hidden from
 * Swift, which uses the AudioToolbox module. */
#include <AudioToolbox/AudioToolboxBase.h>
#include <AudioToolbox/AudioUnit.h>
#include <AudioToolbox/AUGraph.h>
#include <AudioToolbox/AudioFile.h>
#include <AudioToolbox/ExtendedAudioFile.h>
#include <AudioToolbox/AudioConverter.h>
#include <AudioToolbox/AudioQueue.h>
#include <AudioToolbox/AudioServices.h>
