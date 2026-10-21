#pragma once
/* isim AVFAudio: AVAudioChannelLayout, over the overlay's class (AVAudioConverter.swift). */
#import <AVFAudio/AVAudioTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioChannelLayout : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithLayoutTag:(AudioChannelLayoutTag)layoutTag;
- (instancetype)initWithLayout:(const AudioChannelLayout *)layout NS_DESIGNATED_INITIALIZER;
+ (instancetype)layoutWithLayoutTag:(AudioChannelLayoutTag)layoutTag;
+ (instancetype)layoutWithLayout:(const AudioChannelLayout *)layout;
@property (nonatomic, readonly) AudioChannelLayoutTag layoutTag;
@property (nonatomic, readonly) const AudioChannelLayout *layout;
@property (nonatomic, readonly) AVAudioChannelCount channelCount;
@end
NS_ASSUME_NONNULL_END
#endif
