#pragma once
/* isim AVKit for Objective-C: the classes are the AVKit Swift overlay's (AVKit.framework re-exports libswiftAVKit.dylib).
   Capture events (issue #811): while an enabled AVCaptureEventInteraction is in a view on screen and a capture session
   runs, the volume buttons and the Camera Control send it began / ended events instead of changing the volume. Swift
   uses the overlay; these declarations are hidden from Swift. Not available from Objective-C yet: the player view
   controller, picture in picture, the route picker and the rest of AVKit. The classes are not subclassable from
   Objective-C. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, AVCaptureEventPhase) { AVCaptureEventPhaseBegan = 0, AVCaptureEventPhaseEnded = 1, AVCaptureEventPhaseCancelled = 2 };

API_AVAILABLE(ios(26.0))
@interface AVCaptureEventSound : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)outError;
@property (class, nonatomic, readonly) AVCaptureEventSound *cameraShutterSound;
@property (class, nonatomic, readonly) AVCaptureEventSound *beginVideoRecordingSound;
@property (class, nonatomic, readonly) AVCaptureEventSound *endVideoRecordingSound;
@end

@interface AVCaptureEvent : NSObject
@property (nonatomic, readonly) AVCaptureEventPhase phase;
@property (nonatomic, readonly) BOOL shouldPlaySound API_AVAILABLE(ios(26.0));
- (BOOL)playSound:(AVCaptureEventSound *)sound API_AVAILABLE(ios(26.0));
@end

@interface AVCaptureEventInteraction : NSObject <UIInteraction>
- (instancetype)initWithEventHandler:(void (^)(AVCaptureEvent *event))handler;
- (instancetype)initWithPrimaryEventHandler:(void (^)(AVCaptureEvent *event))primaryHandler
                      secondaryEventHandler:(void (^)(AVCaptureEvent *event))secondaryHandler;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (class, nonatomic) BOOL defaultCaptureSoundDisabled API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
#endif
