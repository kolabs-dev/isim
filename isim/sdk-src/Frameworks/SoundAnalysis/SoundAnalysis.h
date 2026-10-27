#pragma once
/* isim Sound Analysis for Objective-C: the classes are the SoundAnalysis Swift overlay's (SoundAnalysis.framework
   re-exports libswiftSoundAnalysis.dylib). The built-in classifier is an ONNX audio classifier run with the host's
   ONNX Runtime (ISIM_SOUND_MODEL, YAMNet's ONNX export): its labels are the model's, not Apple's. Core ML sound
   classifiers fail with SNErrorCodeInvalidModel. Swift uses the overlay; these declarations are hidden from Swift. The
   classes are not subclassable from Objective-C. */
#import <SoundAnalysis/SNDefines.h>
#import <SoundAnalysis/SNError.h>
#import <SoundAnalysis/SNTypes.h>
#import <SoundAnalysis/SNRequest.h>
#import <SoundAnalysis/SNResult.h>
#import <SoundAnalysis/SNTimeDurationConstraint.h>
#import <SoundAnalysis/SNClassifySoundRequest.h>
#import <SoundAnalysis/SNClassificationResult.h>
#import <SoundAnalysis/SNAnalyzer.h>
