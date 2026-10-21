// isim CoreHaptics for Objective-C (issue #548): the string constants (the Swift overlay's structs' raw values) and
// -initAndReturnError:, which Swift's non-throwing init() leaves out.
#import <CoreHaptics/CoreHaptics.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // categories implement what the header declares

NSString * const CHHapticErrorDomain = @"com.apple.CoreHaptics";
CHHapticEventParameterID const CHHapticEventParameterIDHapticIntensity = @"HapticIntensity";
CHHapticEventParameterID const CHHapticEventParameterIDHapticSharpness = @"HapticSharpness";
CHHapticEventParameterID const CHHapticEventParameterIDAttackTime = @"AttackTime";
CHHapticEventParameterID const CHHapticEventParameterIDDecayTime = @"DecayTime";
CHHapticEventParameterID const CHHapticEventParameterIDReleaseTime = @"ReleaseTime";
CHHapticEventParameterID const CHHapticEventParameterIDSustained = @"Sustained";
CHHapticEventParameterID const CHHapticEventParameterIDAudioVolume = @"AudioVolume";
CHHapticEventParameterID const CHHapticEventParameterIDAudioPitch = @"AudioPitch";
CHHapticEventParameterID const CHHapticEventParameterIDAudioPan = @"AudioPan";
CHHapticEventParameterID const CHHapticEventParameterIDAudioBrightness = @"AudioBrightness";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticIntensityControl = @"HapticIntensityControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticSharpnessControl = @"HapticSharpnessControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticAttackTimeControl = @"HapticAttackTimeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticDecayTimeControl = @"HapticDecayTimeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDHapticReleaseTimeControl = @"HapticReleaseTimeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioVolumeControl = @"AudioVolumeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioPanControl = @"AudioPanControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioBrightnessControl = @"AudioBrightnessControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioPitchControl = @"AudioPitchControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioAttackTimeControl = @"AudioAttackTimeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioDecayTimeControl = @"AudioDecayTimeControl";
CHHapticDynamicParameterID const CHHapticDynamicParameterIDAudioReleaseTimeControl = @"AudioReleaseTimeControl";
CHHapticEventType const CHHapticEventTypeHapticTransient = @"HapticTransient";
CHHapticEventType const CHHapticEventTypeHapticContinuous = @"HapticContinuous";
CHHapticEventType const CHHapticEventTypeAudioContinuous = @"AudioContinuous";
CHHapticEventType const CHHapticEventTypeAudioCustom = @"AudioCustom";
CHHapticPatternKey const CHHapticPatternKeyVersion = @"Version";
CHHapticPatternKey const CHHapticPatternKeyPattern = @"Pattern";
CHHapticPatternKey const CHHapticPatternKeyEvent = @"Event";
CHHapticPatternKey const CHHapticPatternKeyEventType = @"EventType";
CHHapticPatternKey const CHHapticPatternKeyTime = @"Time";
CHHapticPatternKey const CHHapticPatternKeyEventDuration = @"EventDuration";
CHHapticPatternKey const CHHapticPatternKeyEventWaveformPath = @"EventWaveformPath";
CHHapticPatternKey const CHHapticPatternKeyEventParameters = @"EventParameters";
CHHapticPatternKey const CHHapticPatternKeyEventWaveformUseVolumeEnvelope = @"EventWaveformUseVolumeEnvelope";
CHHapticPatternKey const CHHapticPatternKeyParameter = @"Parameter";
CHHapticPatternKey const CHHapticPatternKeyParameterID = @"ParameterID";
CHHapticPatternKey const CHHapticPatternKeyParameterValue = @"ParameterValue";
CHHapticPatternKey const CHHapticPatternKeyParameterCurve = @"ParameterCurve";
CHHapticPatternKey const CHHapticPatternKeyParameterCurveControlPoints = @"ParameterCurveControlPoints";
CHHapticAudioResourceKey const CHHapticAudioResourceKeyUseVolumeEnvelope = @"UseVolumeEnvelope";
CHHapticAudioResourceKey const CHHapticAudioResourceKeyLoopEnabled = @"LoopEnabled";

@interface CHHapticEngine (ISIMInit)
- (instancetype)init;
@end
@implementation CHHapticEngine (ISIMErrors)
- (instancetype)initAndReturnError:(NSError **)error { return [self init]; }
@end
