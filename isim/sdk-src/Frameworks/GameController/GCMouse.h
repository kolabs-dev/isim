#pragma once
#import <GameController/GCController.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class GCMouseInput;
typedef void (^GCMouseMoved)(GCMouseInput *mouse, float deltaX, float deltaY);
API_AVAILABLE(ios(14.0))
@interface GCMouseInput : GCPhysicalInputProfile
@property (nonatomic, copy, nullable) GCMouseMoved mouseMovedHandler;
@property (nonatomic, readonly) GCDeviceCursor *scroll;
@property (nonatomic, readonly) GCControllerButtonInput *leftButton;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *rightButton;
@property (nonatomic, readonly, nullable) GCControllerButtonInput *middleButton;
@property (nonatomic, readonly, nullable) NSArray<GCControllerButtonInput *> *auxiliaryButtons;
@end
API_AVAILABLE(ios(14.0))
@interface GCMouse : NSObject <GCDevice>
@property (nonatomic, readonly, strong, nullable) GCMouseInput *mouseInput;
@property (class, atomic, readonly, nullable) GCMouse *current;
+ (NSArray<GCMouse *> *)mice;
@end
NS_ASSUME_NONNULL_END
#endif
