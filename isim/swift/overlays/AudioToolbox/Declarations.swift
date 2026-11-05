// isim AudioToolbox: the C declarations of issue #856 live in <_AudioToolboxTypes/AudioToolboxDecls.h> (seen by Swift
// and C); these two are C string constants, defined here. isim's values: the notifications' names (isim posts neither).
import Foundation

public let kAudioComponentInstanceInvalidationNotification: CFString = "AudioComponentInstanceInvalidationNotification" as CFString
public let kAudioComponentRegistrationsChangedNotification: CFString = "AudioComponentRegistrationsChangedNotification" as CFString
