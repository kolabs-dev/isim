#pragma once
/* isim AVFAudio: AVAudioEngine (AVAudioEngine.swift; adapted: isim renders the graph itself and plays its main mixer
 * through the host's audio output). */
#import <AVFAudio/AVAudioNode.h>
#import <AVFAudio/AVAudioIONode.h>
#import <AVFAudio/AVAudioMixerNode.h>
#import <AVFAudio/AVAudioConnectionPoint.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingError) {
    AVAudioEngineManualRenderingErrorInvalidMode = -80800, AVAudioEngineManualRenderingErrorInitialized = -80801,
    AVAudioEngineManualRenderingErrorNotRunning = -80802
};
typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingStatus) {
    AVAudioEngineManualRenderingStatusError = -1, AVAudioEngineManualRenderingStatusSuccess = 0,
    AVAudioEngineManualRenderingStatusInsufficientDataFromInputNode = 1, AVAudioEngineManualRenderingStatusCannotDoInCurrentContext = 2
};
typedef NS_ENUM(NSInteger, AVAudioEngineManualRenderingMode) {
    AVAudioEngineManualRenderingModeOffline = 0, AVAudioEngineManualRenderingModeRealtime = 1
};
typedef AVAudioEngineManualRenderingStatus (^AVAudioEngineManualRenderingBlock)(AVAudioFrameCount numberOfFrames, AudioBufferList *outBuffer,
                                                                                OSStatus * _Nullable outError);
FOUNDATION_EXPORT NSNotificationName const AVAudioEngineConfigurationChangeNotification;
@interface AVAudioEngine : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)attachNode:(AVAudioNode *)node;
- (void)detachNode:(AVAudioNode *)node;
- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 fromBus:(AVAudioNodeBus)bus1 toBus:(AVAudioNodeBus)bus2 format:(nullable AVAudioFormat *)format;
- (void)connect:(AVAudioNode *)node1 to:(AVAudioNode *)node2 format:(nullable AVAudioFormat *)format;
- (void)connect:(AVAudioNode *)sourceNode toConnectionPoints:(NSArray<AVAudioConnectionPoint *> *)destNodes fromBus:(AVAudioNodeBus)sourceBus
         format:(nullable AVAudioFormat *)format;
- (void)disconnectNodeInput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus;
- (void)disconnectNodeInput:(AVAudioNode *)node;
- (void)disconnectNodeOutput:(AVAudioNode *)node bus:(AVAudioNodeBus)bus;
- (void)disconnectNodeOutput:(AVAudioNode *)node;
- (void)prepare;
- (BOOL)startAndReturnError:(NSError **)outError;
- (void)pause;
- (void)reset;
- (void)stop;
- (nullable AVAudioConnectionPoint *)inputConnectionPointForNode:(AVAudioNode *)node inputBus:(AVAudioNodeBus)bus;
- (NSArray<AVAudioConnectionPoint *> *)outputConnectionPointsForNode:(AVAudioNode *)node outputBus:(AVAudioNodeBus)bus;
@property (nonatomic, readonly) AVAudioOutputNode *outputNode;
@property (nonatomic, readonly) AVAudioInputNode *inputNode;
@property (nonatomic, readonly) AVAudioMixerNode *mainMixerNode;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
@property (nonatomic, getter=isAutoShutdownEnabled) BOOL autoShutdownEnabled;
@property (nonatomic, readonly) NSSet<AVAudioNode *> *attachedNodes;
- (BOOL)enableManualRenderingMode:(AVAudioEngineManualRenderingMode)mode format:(AVAudioFormat *)pcmFormat
                maximumFrameCount:(AVAudioFrameCount)maximumFrameCount error:(NSError **)outError;
- (void)disableManualRenderingMode;
- (AVAudioEngineManualRenderingStatus)renderOffline:(AVAudioFrameCount)numberOfFrames toBuffer:(AVAudioPCMBuffer *)buffer error:(NSError **)outError;
@property (nonatomic, readonly) AVAudioEngineManualRenderingBlock manualRenderingBlock;
@property (nonatomic, readonly) BOOL isInManualRenderingMode;
@property (nonatomic, readonly) AVAudioEngineManualRenderingMode manualRenderingMode;
@property (nonatomic, readonly) AVAudioFormat *manualRenderingFormat;
@property (nonatomic, readonly) AVAudioFrameCount manualRenderingMaximumFrameCount;
@property (nonatomic, readonly) AVAudioFramePosition manualRenderingSampleTime;
@end
NS_ASSUME_NONNULL_END
#endif
