#pragma once
/* isim AVFAudio: AVAudioBuffer, AVAudioPCMBuffer and AVAudioCompressedBuffer, over the overlay's classes. */
#import <AVFAudio/AVAudioFormat.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface AVAudioBuffer : NSObject <NSCopying, NSMutableCopying>
@property (nonatomic, readonly) AVAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;
@end
@interface AVAudioPCMBuffer : AVAudioBuffer
- (nullable instancetype)initWithPCMFormat:(AVAudioFormat *)format frameCapacity:(AVAudioFrameCount)frameCapacity NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithPCMFormat:(AVAudioFormat *)format bufferListNoCopy:(const AudioBufferList *)bufferList
                               deallocator:(nullable void (^)(const AudioBufferList *))deallocator;
@property (nonatomic, readonly) AVAudioFrameCount frameCapacity;
@property (nonatomic) AVAudioFrameCount frameLength;
@property (nonatomic, readonly) NSUInteger stride;
@property (nonatomic, readonly) float * const _Nonnull * _Nullable floatChannelData;
@property (nonatomic, readonly) int16_t * const _Nonnull * _Nullable int16ChannelData;
@property (nonatomic, readonly) int32_t * const _Nonnull * _Nullable int32ChannelData;
@end
@interface AVAudioCompressedBuffer : AVAudioBuffer
- (instancetype)initWithFormat:(AVAudioFormat *)format packetCapacity:(AVAudioPacketCount)packetCapacity maximumPacketSize:(NSInteger)maximumPacketSize;
- (instancetype)initWithFormat:(AVAudioFormat *)format packetCapacity:(AVAudioPacketCount)packetCapacity;
@property (nonatomic, readonly) AVAudioPacketCount packetCapacity;
@property (nonatomic) AVAudioPacketCount packetCount;
@property (nonatomic, readonly) NSInteger maximumPacketSize;
@property (nonatomic, readonly) void *data;
@property (nonatomic, readonly) uint32_t byteCapacity;
@property (nonatomic) uint32_t byteLength;
@property (nonatomic, readonly, nullable) AudioStreamPacketDescription *packetDescriptions;
@end
NS_ASSUME_NONNULL_END
#endif
