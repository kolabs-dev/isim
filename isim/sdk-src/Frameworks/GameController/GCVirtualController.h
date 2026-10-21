#pragma once
#import <GameController/GCController.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(15.0))
@interface GCVirtualControllerConfiguration : NSObject
@property (nonatomic, strong) NSSet<NSString *> *elements;
@property (nonatomic, assign, getter=isHidden) BOOL hidden API_AVAILABLE(ios(17.0));
@end
API_AVAILABLE(ios(15.0))
@interface GCVirtualControllerElementConfiguration : NSObject
@property (nonatomic, assign, getter=isHidden) BOOL hidden;
@property (nonatomic, strong, nullable) UIBezierPath *path;
@property (nonatomic, assign) BOOL actsAsTouchpad;
@end
/* isim: an on-screen controller drawn over the app, with its GCController */
API_AVAILABLE(ios(15.0))
@interface GCVirtualController : NSObject
+ (instancetype)virtualControllerWithConfiguration:(GCVirtualControllerConfiguration *)configuration;
- (instancetype)initWithConfiguration:(GCVirtualControllerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (void)connectWithReplyHandler:(nullable void (^)(NSError * _Nullable error))reply;
- (void)disconnect;
@property (nonatomic, weak, readonly, nullable) GCController *controller;
- (void)updateConfigurationForElement:(NSString *)element configuration:(GCVirtualControllerElementConfiguration * (^)(GCVirtualControllerElementConfiguration *configuration))config;
@end
NS_ASSUME_NONNULL_END
#endif
