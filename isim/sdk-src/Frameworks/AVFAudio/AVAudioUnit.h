#pragma once
/* isim AVFAudio: AVAudioUnit (AVAudioEngine.swift; Apple's audio units are isim's AudioToolbox ones). */
#import <AVFAudio/AVAudioNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioUnit : AVAudioNode
+ (void)instantiateWithComponentDescription:(AudioComponentDescription)audioComponentDescription options:(AudioComponentInstantiationOptions)options
                          completionHandler:(void (^)(__kindof AVAudioUnit * _Nullable audioUnit, NSError * _Nullable error))completionHandler;
@property (nonatomic, readonly) AudioComponentDescription audioComponentDescription;
@property (nonatomic, readonly) AudioUnit audioUnit;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *manufacturerName;
@property (nonatomic, readonly) NSUInteger version;
@end
NS_ASSUME_NONNULL_END
#endif
