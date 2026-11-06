#pragma once
/* isim AVFoundation for Objective-C (issue #707): compositions, export, asset readers and writers, video compositions
   and custom compositors. The classes are the AVFoundation Swift overlay's (media encoded and decoded by the host's
   FFmpeg, see the overlay); Swift uses the overlay, these declarations are hidden from Swift. The members with a CMTime,
   CMTimeRange, CMSampleBufferRef or CVPixelBufferRef are categories in AVFoundation.m. A custom compositor is an
   Objective-C class adopting AVVideoCompositing; instructions are AVVideoCompositionInstruction objects (custom
   instruction classes are not available from Objective-C yet). The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class AVAsset, AVAssetTrack, AVVideoComposition, AVAudioMix, AVVideoCompositionRenderContext, AVAsynchronousVideoCompositionRequest;

FOUNDATION_EXPORT NSString * const AVAssetExportPresetPassthrough, * const AVAssetExportPresetLowQuality, * const AVAssetExportPresetMediumQuality,
    * const AVAssetExportPresetHighestQuality, * const AVAssetExportPresetHEVCHighestQuality, * const AVAssetExportPreset640x480,
    * const AVAssetExportPreset960x540, * const AVAssetExportPreset1280x720, * const AVAssetExportPreset1920x1080, * const AVAssetExportPreset3840x2160,
    * const AVAssetExportPresetHEVC1920x1080, * const AVAssetExportPresetHEVC3840x2160, * const AVAssetExportPresetAppleM4A;

// MARK: tracks and compositions
@interface AVAssetTrack (AVAssetTrackEditing)
@property (nonatomic, readonly) CMPersistentTrackID trackID;
@property (nonatomic, readonly, weak, nullable) AVAsset *asset;
@property (nonatomic, readonly) CMTimeRange timeRange;                                     // AVFoundation.m
@property (nonatomic, readonly) CGAffineTransform preferredTransform;
@end
@interface AVCompositionTrackSegment : NSObject
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;
@property (nonatomic, readonly, nullable) NSURL *sourceURL;
@property (nonatomic, readonly) CMPersistentTrackID sourceTrackID;
@end
@interface AVCompositionTrack : AVAssetTrack
@property (nonatomic, readonly, copy) NSArray<AVCompositionTrackSegment *> *segments;
@end
@interface AVMutableCompositionTrack : AVCompositionTrack
- (BOOL)insertTimeRange:(CMTimeRange)timeRange ofTrack:(AVAssetTrack *)track atTime:(CMTime)startTime
                  error:(NSError * _Nullable * _Nullable)outError;                          // AVFoundation.m
- (void)insertEmptyTimeRange:(CMTimeRange)timeRange;                                       // AVFoundation.m
- (void)removeTimeRange:(CMTimeRange)timeRange;                                            // AVFoundation.m
- (void)scaleTimeRange:(CMTimeRange)timeRange toDuration:(CMTime)duration;                 // AVFoundation.m
@property (nonatomic) CGAffineTransform preferredTransform;
@property (nonatomic) CMTimeScale naturalTimeScale;
@end
@interface AVComposition : AVAsset
@end
@interface AVMutableComposition : AVComposition
+ (instancetype)composition;
- (nullable AVMutableCompositionTrack *)addMutableTrackWithMediaType:(AVMediaType)mediaType preferredTrackID:(CMPersistentTrackID)preferredTrackID;
- (void)removeTrack:(AVCompositionTrack *)track;
- (nullable AVMutableCompositionTrack *)mutableTrackCompatibleWithTrack:(AVAssetTrack *)track;
- (BOOL)insertTimeRange:(CMTimeRange)timeRange ofAsset:(AVAsset *)asset atTime:(CMTime)startTime
                  error:(NSError * _Nullable * _Nullable)outError;                          // AVFoundation.m
- (void)insertEmptyTimeRange:(CMTimeRange)timeRange;                                       // AVFoundation.m
- (void)removeTimeRange:(CMTimeRange)timeRange;                                            // AVFoundation.m
- (void)scaleTimeRange:(CMTimeRange)timeRange toDuration:(CMTime)duration;                 // AVFoundation.m
@end
@interface AVAudioMixInputParameters : NSObject
@end
@interface AVMutableAudioMixInputParameters : AVAudioMixInputParameters
+ (instancetype)audioMixInputParametersWithTrack:(nullable AVAssetTrack *)track;
@property (nonatomic) CMPersistentTrackID trackID;
- (void)setVolume:(float)volume atTime:(CMTime)time;                                       // AVFoundation.m
- (void)setVolumeRampFromStartVolume:(float)startVolume toEndVolume:(float)endVolume timeRange:(CMTimeRange)timeRange;   // AVFoundation.m
@end
@interface AVAudioMix : NSObject
@end
@interface AVMutableAudioMix : AVAudioMix
+ (instancetype)audioMix;
@property (nonatomic, copy) NSArray<AVAudioMixInputParameters *> *inputParameters;
@end

// MARK: video compositions
@interface AVVideoCompositionLayerInstruction : NSObject <NSSecureCoding, NSCopying, NSMutableCopying>
@property (nonatomic, readonly) CMPersistentTrackID trackID;
@end
@interface AVMutableVideoCompositionLayerInstruction : AVVideoCompositionLayerInstruction
+ (instancetype)videoCompositionLayerInstruction;
+ (instancetype)videoCompositionLayerInstructionWithAssetTrack:(AVAssetTrack *)track;
@property (nonatomic) CMPersistentTrackID trackID;
- (void)setTransform:(CGAffineTransform)transform atTime:(CMTime)time;                     // AVFoundation.m
- (void)setTransformRampFromStartTransform:(CGAffineTransform)startTransform toEndTransform:(CGAffineTransform)endTransform
                                 timeRange:(CMTimeRange)timeRange;                         // AVFoundation.m
- (void)setOpacity:(float)opacity atTime:(CMTime)time;                                     // AVFoundation.m
- (void)setOpacityRampFromStartOpacity:(float)startOpacity toEndOpacity:(float)endOpacity timeRange:(CMTimeRange)timeRange;   // AVFoundation.m
- (void)setCropRectangle:(CGRect)cropRectangle atTime:(CMTime)time;                        // AVFoundation.m
@end
@protocol AVVideoCompositionInstruction <NSObject>
@property (nonatomic, readonly) CMTimeRange timeRange;
@property (nonatomic, readonly) BOOL enablePostProcessing;
@end
@interface AVVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction, NSSecureCoding, NSCopying, NSMutableCopying>
@property (nonatomic, readonly) CMTimeRange timeRange;                                     // AVFoundation.m
@property (nonatomic, readonly, copy) NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions;
@property (nonatomic, readonly, nullable) CGColorRef backgroundColor;
@property (nonatomic, readonly) BOOL enablePostProcessing;
@end
@interface AVMutableVideoCompositionInstruction : AVVideoCompositionInstruction
+ (instancetype)videoCompositionInstruction;
@property (nonatomic) CMTimeRange timeRange;                                               // AVFoundation.m
@property (nonatomic, copy) NSArray<AVVideoCompositionLayerInstruction *> *layerInstructions;
@property (nonatomic, nullable) CGColorRef backgroundColor;
@property (nonatomic) BOOL enablePostProcessing;
@end
@interface AVVideoCompositionCoreAnimationTool : NSObject
+ (instancetype)videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:(CALayer *)videoLayer inLayer:(CALayer *)animationLayer;
+ (instancetype)videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayers:(NSArray<CALayer *> *)videoLayers inLayer:(CALayer *)animationLayer;
+ (instancetype)videoCompositionCoreAnimationToolWithAdditionalLayer:(CALayer *)layer asTrackID:(CMPersistentTrackID)trackID;
@end
@protocol AVVideoCompositing <NSObject>
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *sourcePixelBufferAttributes;
@property (nonatomic, readonly) NSDictionary<NSString *, id> *requiredPixelBufferAttributesForRenderContext;
- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext;
- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)asyncVideoCompositionRequest;
@optional
- (void)cancelAllPendingVideoCompositionRequests;
@property (nonatomic, readonly) BOOL supportsWideColorSourceFrames;
@property (nonatomic, readonly) BOOL supportsHDRSourceFrames;
@property (nonatomic, readonly) BOOL canConformColorOfSourceFrames;
@end
@interface AVVideoComposition : NSObject
+ (instancetype)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset;
@property (nonatomic, readonly, nullable) Class<AVVideoCompositing> customVideoCompositorClass;
@property (nonatomic, readonly) CMTime frameDuration;                                      // AVFoundation.m
@property (nonatomic, readonly) CGSize renderSize;
@property (nonatomic, readonly) float renderScale;
@property (nonatomic, readonly, copy) NSArray<id<AVVideoCompositionInstruction>> *instructions;
@property (nonatomic, readonly, retain, nullable) AVVideoCompositionCoreAnimationTool *animationTool;
@end
@interface AVMutableVideoComposition : AVVideoComposition
+ (instancetype)videoComposition;
+ (instancetype)videoCompositionWithPropertiesOfAsset:(AVAsset *)asset;
@property (nonatomic, retain, nullable) Class<AVVideoCompositing> customVideoCompositorClass;
@property (nonatomic) CMTime frameDuration;                                                // AVFoundation.m
@property (nonatomic) CGSize renderSize;
@property (nonatomic) float renderScale;
@property (nonatomic, copy) NSArray<id<AVVideoCompositionInstruction>> *instructions;
@property (nonatomic, retain, nullable) AVVideoCompositionCoreAnimationTool *animationTool;
@end
@interface AVVideoCompositionRenderContext : NSObject
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) float renderScale;
@property (nonatomic, readonly) CGAffineTransform renderTransform;
@property (nonatomic, readonly) BOOL highQualityRendering;
@property (nonatomic, readonly) AVVideoComposition *videoComposition;
- (nullable CVPixelBufferRef)newPixelBuffer CF_RETURNS_RETAINED;                           // AVFoundation.m
@end
@interface AVAsynchronousVideoCompositionRequest : NSObject
@property (nonatomic, readonly) AVVideoCompositionRenderContext *renderContext;
@property (nonatomic, readonly) CMTime compositionTime;                                    // AVFoundation.m
@property (nonatomic, readonly) NSArray<NSNumber *> *sourceTrackIDs;
@property (nonatomic, readonly) id<AVVideoCompositionInstruction> videoCompositionInstruction;
- (nullable CVPixelBufferRef)sourceFrameByTrackID:(CMPersistentTrackID)trackID CF_RETURNS_NOT_RETAINED;   // AVFoundation.m
- (void)finishWithComposedVideoFrame:(CVPixelBufferRef)composedVideoFrame;                 // AVFoundation.m
- (void)finishWithError:(NSError *)error;
- (void)finishCancelledRequest;
@end

// MARK: export
typedef NS_ENUM(NSInteger, AVAssetExportSessionStatus) {
    AVAssetExportSessionStatusUnknown = 0, AVAssetExportSessionStatusWaiting, AVAssetExportSessionStatusExporting, AVAssetExportSessionStatusCompleted,
    AVAssetExportSessionStatusFailed, AVAssetExportSessionStatusCancelled,
};
@interface AVAssetExportSession : NSObject
+ (nullable instancetype)exportSessionWithAsset:(AVAsset *)asset presetName:(NSString *)presetName;
- (nullable instancetype)initWithAsset:(AVAsset *)asset presetName:(NSString *)presetName;
+ (NSArray<NSString *> *)allExportPresets;
+ (NSArray<NSString *> *)exportPresetsCompatibleWithAsset:(AVAsset *)asset;
@property (nonatomic, readonly, retain) AVAsset *asset;
@property (nonatomic, readonly) NSString *presetName;
@property (nonatomic, copy, nullable) NSURL *outputURL;
@property (nonatomic, copy, nullable) AVFileType outputFileType;
@property (nonatomic, readonly) NSArray<AVFileType> *supportedFileTypes;
@property (nonatomic) CMTimeRange timeRange;                                               // AVFoundation.m
@property (nonatomic) BOOL shouldOptimizeForNetworkUse;
@property (nonatomic, copy, nullable) AVVideoComposition *videoComposition;
@property (nonatomic, copy, nullable) AVAudioMix *audioMix;
@property (nonatomic, readonly, nullable) id<AVVideoCompositing> customVideoCompositor;
@property (nonatomic) long long fileLengthLimit;
@property (nonatomic, readonly) AVAssetExportSessionStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly) float progress;
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;
- (void)cancelExport;
@end

// MARK: readers
typedef NS_ENUM(NSInteger, AVAssetReaderStatus) {
    AVAssetReaderStatusUnknown = 0, AVAssetReaderStatusReading, AVAssetReaderStatusCompleted, AVAssetReaderStatusFailed, AVAssetReaderStatusCancelled,
};
@interface AVAssetReaderOutput : NSObject
@property (nonatomic, readonly) AVMediaType mediaType;
@property (nonatomic) BOOL alwaysCopiesSampleData;
@property (nonatomic) BOOL supportsRandomAccess;
- (nullable CMSampleBufferRef)copyNextSampleBuffer CF_RETURNS_RETAINED;                    // AVFoundation.m
- (void)resetForReadingTimeRanges:(NSArray<NSValue *> *)timeRanges;
- (void)markConfigurationAsFinal;
@end
@interface AVAssetReaderTrackOutput : AVAssetReaderOutput
+ (instancetype)assetReaderTrackOutputWithTrack:(AVAssetTrack *)track outputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings;
- (instancetype)initWithTrack:(AVAssetTrack *)track outputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings;
@property (nonatomic, readonly) AVAssetTrack *track;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *outputSettings;
@end
@interface AVAssetReaderAudioMixOutput : AVAssetReaderOutput
+ (instancetype)assetReaderAudioMixOutputWithAudioTracks:(NSArray<AVAssetTrack *> *)audioTracks audioSettings:(nullable NSDictionary<NSString *, id> *)audioSettings;
@property (nonatomic, copy, nullable) AVAudioMix *audioMix;
@end
@interface AVAssetReaderVideoCompositionOutput : AVAssetReaderOutput
+ (instancetype)assetReaderVideoCompositionOutputWithVideoTracks:(NSArray<AVAssetTrack *> *)videoTracks videoSettings:(nullable NSDictionary<NSString *, id> *)videoSettings;
@property (nonatomic, copy, nullable) AVVideoComposition *videoComposition;
@property (nonatomic, readonly, nullable) id<AVVideoCompositing> customVideoCompositor;
@end
@interface AVAssetReader : NSObject
+ (nullable instancetype)assetReaderWithAsset:(AVAsset *)asset error:(NSError * _Nullable * _Nullable)outError;
- (nullable instancetype)initWithAsset:(AVAsset *)asset error:(NSError * _Nullable * _Nullable)outError;
@property (nonatomic, readonly, retain) AVAsset *asset;
@property (nonatomic, readonly) AVAssetReaderStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic) CMTimeRange timeRange;                                               // AVFoundation.m
@property (nonatomic, readonly) NSArray<AVAssetReaderOutput *> *outputs;
- (BOOL)canAddOutput:(AVAssetReaderOutput *)output;
- (void)addOutput:(AVAssetReaderOutput *)output;
- (BOOL)startReading;
- (void)cancelReading;
@end

// MARK: writers
typedef NS_ENUM(NSInteger, AVAssetWriterStatus) {
    AVAssetWriterStatusUnknown = 0, AVAssetWriterStatusWriting, AVAssetWriterStatusCompleted, AVAssetWriterStatusFailed, AVAssetWriterStatusCancelled,
};
@interface AVAssetWriterInput : NSObject
+ (instancetype)assetWriterInputWithMediaType:(AVMediaType)mediaType outputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings;
- (instancetype)initWithMediaType:(AVMediaType)mediaType outputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings;
@property (nonatomic, readonly) AVMediaType mediaType;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *outputSettings;
@property (nonatomic) BOOL expectsMediaDataInRealTime;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CMTimeScale mediaTimeScale;
@property (nonatomic) CGSize naturalSize;
@property (nonatomic, copy, nullable) NSString *languageCode;
@property (nonatomic, readonly, getter=isReadyForMoreMediaData) BOOL readyForMoreMediaData;
- (void)requestMediaDataWhenReadyOnQueue:(dispatch_queue_t)queue usingBlock:(void (^)(void))block;
- (BOOL)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer;                                // AVFoundation.m
- (void)markAsFinished;
@end
@interface AVAssetWriterInputPixelBufferAdaptor : NSObject
+ (instancetype)assetWriterInputPixelBufferAdaptorWithAssetWriterInput:(AVAssetWriterInput *)input
                                           sourcePixelBufferAttributes:(nullable NSDictionary<NSString *, id> *)sourcePixelBufferAttributes;
@property (nonatomic, readonly) AVAssetWriterInput *assetWriterInput;
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *sourcePixelBufferAttributes;
- (BOOL)appendPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime;   // AVFoundation.m
@end
@interface AVAssetWriter : NSObject
+ (nullable instancetype)assetWriterWithURL:(NSURL *)outputURL fileType:(AVFileType)outputFileType error:(NSError * _Nullable * _Nullable)outError;
- (nullable instancetype)initWithURL:(NSURL *)outputURL fileType:(AVFileType)outputFileType error:(NSError * _Nullable * _Nullable)outError;
@property (nonatomic, readonly, copy) NSURL *outputURL;
@property (nonatomic, readonly, copy) AVFileType outputFileType;
@property (nonatomic, readonly) NSArray<AVMediaType> *availableMediaTypes;
@property (nonatomic, readonly) AVAssetWriterStatus status;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic) BOOL shouldOptimizeForNetworkUse;
@property (nonatomic, readonly) NSArray<AVAssetWriterInput *> *inputs;
- (BOOL)canApplyOutputSettings:(nullable NSDictionary<NSString *, id> *)outputSettings forMediaType:(AVMediaType)mediaType;
- (BOOL)canAddInput:(AVAssetWriterInput *)input;
- (void)addInput:(AVAssetWriterInput *)input;
- (BOOL)startWriting;
- (void)startSessionAtSourceTime:(CMTime)startTime;                                       // AVFoundation.m
- (void)endSessionAtSourceTime:(CMTime)endTime;                                           // AVFoundation.m
- (void)cancelWriting;
- (void)finishWritingWithCompletionHandler:(void (^)(void))handler;
@end

/* captions (issue #877, part 2; the overlay's AVCaption.swift). The CMTime-valued members (time ranges, rendering) are
   Swift-only in isim. */
typedef NS_ENUM(NSInteger, AVCaptionTextAlignment) { AVCaptionTextAlignmentStart = 0, AVCaptionTextAlignmentEnd, AVCaptionTextAlignmentCenter,
    AVCaptionTextAlignmentLeft, AVCaptionTextAlignmentRight } API_AVAILABLE(ios(18.0));
typedef NS_ENUM(NSInteger, AVCaptionFontWeight) { AVCaptionFontWeightUnknown = 0, AVCaptionFontWeightNormal, AVCaptionFontWeightBold } API_AVAILABLE(ios(18.0));
typedef NS_ENUM(NSInteger, AVCaptionFontStyle) { AVCaptionFontStyleUnknown = 0, AVCaptionFontStyleNormal, AVCaptionFontStyleItalic } API_AVAILABLE(ios(18.0));
typedef NS_OPTIONS(NSUInteger, AVCaptionDecoration) { AVCaptionDecorationNone = 0, AVCaptionDecorationUnderline = 1 << 0,
    AVCaptionDecorationLineThrough = 1 << 1, AVCaptionDecorationOverline = 1 << 2 } API_AVAILABLE(ios(18.0));
API_AVAILABLE(ios(18.0))
@interface AVCaptionRegion : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (class, nonatomic, readonly) AVCaptionRegion *appleITTTopRegion, *appleITTBottomRegion, *appleITTLeftRegion, *appleITTRightRegion, *subRipTextBottomRegion;
@property (nonatomic, readonly, nullable) NSString *identifier;
@end
API_AVAILABLE(ios(18.0))
@interface AVMutableCaptionRegion : AVCaptionRegion
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaption : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly, nullable) AVCaptionRegion *region;
@property (nonatomic, readonly) AVCaptionTextAlignment textAlignment;
@end
API_AVAILABLE(ios(18.0))
@interface AVMutableCaption : AVCaption
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy, nullable) AVCaptionRegion *region;
@property (nonatomic) AVCaptionTextAlignment textAlignment;
- (void)setTextColor:(CGColorRef)color inRange:(NSRange)range;
- (void)removeTextColorInRange:(NSRange)range;
- (void)setBackgroundColor:(CGColorRef)color inRange:(NSRange)range;
- (void)removeBackgroundColorInRange:(NSRange)range;
- (void)setFontWeight:(AVCaptionFontWeight)fontWeight inRange:(NSRange)range;
- (void)removeFontWeightInRange:(NSRange)range;
- (void)setFontStyle:(AVCaptionFontStyle)fontStyle inRange:(NSRange)range;
- (void)removeFontStyleInRange:(NSRange)range;
- (void)setDecoration:(AVCaptionDecoration)decoration inRange:(NSRange)range;
- (void)removeDecorationInRange:(NSRange)range;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptionGroup : NSObject
@property (nonatomic, readonly) NSArray<AVCaption *> *captions;
@end
API_AVAILABLE(ios(18.0))
@interface AVCaptionGrouper : NSObject
- (void)addCaption:(AVCaption *)input;
@end
NS_ASSUME_NONNULL_END
#endif
