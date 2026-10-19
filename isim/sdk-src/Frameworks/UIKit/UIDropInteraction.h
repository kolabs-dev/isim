#pragma once
/* isim: drop interactions for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIDragInteraction.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@protocol UIDropInteractionDelegate, UIDropSession;
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIDropProposal : NSObject
- (instancetype)initWithDropOperation:(UIDropOperation)operation NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) UIDropOperation operation;
@property (nonatomic, getter=isPrecise) BOOL precise;
@property (nonatomic) BOOL prefersFullSizePreview;
@end
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UIDropInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIDropInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly, weak) id<UIDropInteractionDelegate> delegate;
@property (nonatomic) BOOL allowsSimultaneousDropSessions;
@end
NS_SWIFT_UI_ACTOR
@protocol UIDropInteractionDelegate <NSObject>
@optional
- (BOOL)dropInteraction:(UIDropInteraction *)interaction canHandleSession:(id<UIDropSession>)session;
- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidEnter:(id<UIDropSession>)session;
- (UIDropProposal *)dropInteraction:(UIDropInteraction *)interaction sessionDidUpdate:(id<UIDropSession>)session;
- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidExit:(id<UIDropSession>)session;
- (void)dropInteraction:(UIDropInteraction *)interaction performDrop:(id<UIDropSession>)session;
- (void)dropInteraction:(UIDropInteraction *)interaction concludeDrop:(id<UIDropSession>)session;
- (void)dropInteraction:(UIDropInteraction *)interaction sessionDidEnd:(id<UIDropSession>)session;
@end
NS_ASSUME_NONNULL_END
#endif
