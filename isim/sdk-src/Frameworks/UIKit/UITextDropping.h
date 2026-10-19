#pragma once
/* isim: dropping text into text views and fields for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITextView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIDropInteraction.h>
#import <UIKit/UIPasteConfiguration.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UITextDropProposal, UITextPosition;
@protocol UITextDropDelegate, UITextDropRequest, UIDropSession;
typedef NS_ENUM(NSUInteger, UITextDropEditability) {
    UITextDropEditabilityNo = 0, UITextDropEditabilityTemporary, UITextDropEditabilityYes,
} API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSUInteger, UITextDropAction) { UITextDropActionInsert = 0, UITextDropActionReplaceSelection, UITextDropActionReplaceAll } API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSUInteger, UITextDropProgressMode) { UITextDropProgressModeSystem = 0, UITextDropProgressModeCustom } API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSUInteger, UITextDropPerformer) { UITextDropPerformerView = 0, UITextDropPerformerDelegate } API_AVAILABLE(ios(11.0));
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UITextDropProposal : UIDropProposal <NSCopying>
@property (nonatomic) UITextDropAction dropAction;
@property (nonatomic) UITextDropProgressMode dropProgressMode;
@property (nonatomic) BOOL useFastSameViewOperations;
@property (nonatomic) UITextDropPerformer dropPerformer;
@end
NS_SWIFT_UI_ACTOR
@protocol UITextDropRequest <NSObject>
@property (nonatomic, readonly) UITextPosition *dropPosition;
@property (nonatomic, readonly) UITextDropProposal *suggestedProposal;
@property (nonatomic, readonly, getter=isSameView) BOOL sameView;
@property (nonatomic, readonly) id<UIDropSession> dropSession;
@end
NS_SWIFT_UI_ACTOR
@protocol UITextDroppable <UITextInput, UIPasteConfigurationSupporting>   /* (Apple: UITextPasteConfigurationSupporting, not declared for Objective-C yet) */
@property (nullable, nonatomic, weak) id<UITextDropDelegate> textDropDelegate;
@property (nullable, nonatomic, readonly) UIDropInteraction *textDropInteraction;
@property (nonatomic, readonly, getter=isTextDropActive) BOOL textDropActive;
@end
NS_SWIFT_UI_ACTOR
@protocol UITextDropDelegate <NSObject>
@optional
- (UITextDropEditability)textDroppableView:(UIView<UITextDroppable> *)textDroppableView willBecomeEditableForDrop:(id<UITextDropRequest>)drop;
- (UITextDropProposal *)textDroppableView:(UIView<UITextDroppable> *)textDroppableView proposalForDrop:(id<UITextDropRequest>)drop;
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView willPerformDrop:(id<UITextDropRequest>)drop;
- (nullable UITargetedDragPreview *)textDroppableView:(UIView<UITextDroppable> *)textDroppableView previewForDroppingAllItemsWithDefault:(UITargetedDragPreview *)defaultPreview;
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidEnter:(id<UIDropSession>)session;
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidUpdate:(id<UIDropSession>)session;
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidExit:(id<UIDropSession>)session;
- (void)textDroppableView:(UIView<UITextDroppable> *)textDroppableView dropSessionDidEnd:(id<UIDropSession>)session;
@end
@interface UITextView (UITextDroppable) <UITextDroppable>
@end
@interface UITextField (UITextDroppable) <UITextDroppable>
@end
NS_ASSUME_NONNULL_END
#endif
