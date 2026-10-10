#pragma once
/* isim: band selection (iOS 15). Dragging with the iPad pointer (a trackpad or mouse click; script `pointerdrag`) on
   the interaction's view draws a selection band and reports its rect while it grows; finger drags don't start one,
   like iPadOS. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIEvent.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIBandSelectionInteractionState) {
    UIBandSelectionInteractionStatePossible = 0, UIBandSelectionInteractionStateBegan, UIBandSelectionInteractionStateSelecting,
    UIBandSelectionInteractionStateEnded } NS_SWIFT_NAME(UIBandSelectionInteraction.State) API_AVAILABLE(ios(15.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface UIBandSelectionInteraction : NSObject <UIInteraction>
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly) UIBandSelectionInteractionState state;
/* the band in the view's coordinates; CGRectNull when there is none (Swift: nil) */
@property (nonatomic, readonly) CGRect selectionRect NS_REFINED_FOR_SWIFT;
/* the keyboard modifiers held when the band started (shift / command extend a selection) */
@property (nonatomic, readonly) UIKeyModifierFlags initialModifierFlags;
/* asked with the point where a band would start; NO keeps it from starting (e.g. over a selected item) */
@property (nonatomic, copy, nullable) BOOL (^shouldBeginHandler)(UIBandSelectionInteraction *interaction, CGPoint point);
- (instancetype)initWithSelectionHandler:(void (^)(UIBandSelectionInteraction *interaction))selectionHandler NS_SWIFT_NAME(init(_:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
