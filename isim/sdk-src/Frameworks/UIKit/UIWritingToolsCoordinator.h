#pragma once
/* isim: Writing Tools (iOS 18, #9). Writing Tools needs Apple Intelligence, which isim does not have: as on an iPhone
   without it, UIWritingToolsCoordinator.isWritingToolsAvailable is NO, text views never show Writing Tools
   (showWritingTools: does nothing, isWritingToolsActive stays NO) and a coordinator's delegate is never asked for
   anything. The API is here so apps that adopt it build and run. UIWritingToolsCoordinator.m. */
#import <UIKit/UIView.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UITextInput.h>
#import <UIKit/UITextView.h>
#import <UIKit/UITextField.h>
NS_ASSUME_NONNULL_BEGIN
@class UIBezierPath, UITargetedPreview, UIWritingToolsCoordinator;

typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorState) {
    UIWritingToolsCoordinatorStateInactive, UIWritingToolsCoordinatorStateNoninteractive,
    UIWritingToolsCoordinatorStateInteractiveResting, UIWritingToolsCoordinatorStateInteractiveStreaming,
} NS_SWIFT_NAME(UIWritingToolsCoordinator.State) API_AVAILABLE(ios(18.2));
typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorContextScope) {
    UIWritingToolsCoordinatorContextScopeUserSelection, UIWritingToolsCoordinatorContextScopeFullDocument, UIWritingToolsCoordinatorContextScopeVisibleArea,
} NS_SWIFT_NAME(UIWritingToolsCoordinator.ContextScope) API_AVAILABLE(ios(18.2));
typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorTextReplacementReason) {
    UIWritingToolsCoordinatorTextReplacementReasonInteractive, UIWritingToolsCoordinatorTextReplacementReasonNoninteractive,
} NS_SWIFT_NAME(UIWritingToolsCoordinator.TextReplacementReason) API_AVAILABLE(ios(18.2));
typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorTextUpdateReason) {
    UIWritingToolsCoordinatorTextUpdateReasonTyping, UIWritingToolsCoordinatorTextUpdateReasonUndoRedo,
} NS_SWIFT_NAME(UIWritingToolsCoordinator.TextUpdateReason) API_AVAILABLE(ios(18.2));
typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorTextAnimation) {
    UIWritingToolsCoordinatorTextAnimationAnticipate, UIWritingToolsCoordinatorTextAnimationRemove, UIWritingToolsCoordinatorTextAnimationInsert,
    UIWritingToolsCoordinatorTextAnimationIndicateGrammar API_AVAILABLE(ios(26.0)),
} NS_SWIFT_NAME(UIWritingToolsCoordinator.TextAnimation) API_AVAILABLE(ios(18.2));
typedef NS_ENUM(NSInteger, UIWritingToolsCoordinatorTextDecoration) {
    UIWritingToolsCoordinatorTextDecorationNone, UIWritingToolsCoordinatorTextDecorationGrammarUnderline,
} NS_SWIFT_NAME(UIWritingToolsCoordinator.TextDecoration) API_AVAILABLE(ios(26.0));
UIKIT_EXTERN NSString *UIWritingToolsCoordinatorTextAnimationDebugDescription(UIWritingToolsCoordinatorTextAnimation animationType) API_AVAILABLE(ios(18.2));

/* the text Writing Tools works on: a string and the range in it */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.2)) NS_SWIFT_NAME(UIWritingToolsCoordinator.Context)
@interface UIWritingToolsCoordinatorContext : NSObject
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString range:(NSRange)range;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NSAttributedString *attributedString;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) NSUUID *identifier;
@property (nonatomic, readonly) NSRange resolvedRange;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.2)) NS_SWIFT_NAME(UIWritingToolsCoordinator.AnimationParameters)
@interface UIWritingToolsCoordinatorAnimationParameters : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval delay;
@property (nonatomic, copy, nullable) void (^progressHandler)(float progress);
@property (nonatomic, copy, nullable) void (^completionHandler)(void);
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.2)) NS_SWIFT_NAME(UIWritingToolsCoordinator.Delegate)
@protocol UIWritingToolsCoordinatorDelegate <NSObject>
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsContextsForScope:(UIWritingToolsCoordinatorContextScope)scope
                     completion:(void (^)(NSArray<UIWritingToolsCoordinatorContext *> *contexts))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator replaceRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context
                   proposedText:(NSAttributedString *)replacementText reason:(UIWritingToolsCoordinatorTextReplacementReason)reason
            animationParameters:(nullable UIWritingToolsCoordinatorAnimationParameters *)animationParameters
                     completion:(void (^)(NSAttributedString *_Nullable resultText))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator selectRanges:(NSArray<NSValue *> *)ranges
                      inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(void))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsBoundingBezierPathsForRange:(NSRange)range
                      inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(NSArray<UIBezierPath *> *boundingBezierPaths))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsUnderlinePathsForRange:(NSRange)range
                      inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(NSArray<UIBezierPath *> *underlinePaths))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator prepareForTextAnimation:(UIWritingToolsCoordinatorTextAnimation)textAnimation
                       forRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(void))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsPreviewForTextAnimation:(UIWritingToolsCoordinatorTextAnimation)textAnimation
                        ofRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(UITargetedPreview *_Nullable preview))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator finishTextAnimation:(UIWritingToolsCoordinatorTextAnimation)textAnimation
                       forRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(void))completion;
@optional
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator willChangeToState:(UIWritingToolsCoordinatorState)newState completion:(void (^)(void))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsSingleContainerSubrangesOfRange:(NSRange)range
                      inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(NSArray<NSValue *> *ranges))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsDecorationContainerViewForRange:(NSRange)range
                      inContext:(UIWritingToolsCoordinatorContext *)context completion:(void (^)(UIView *view))completion;
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsGrammarResultsForContext:(UIWritingToolsCoordinatorContext *)context
                     completion:(void (^)(NSArray<NSTextCheckingResult *> *results))completion API_AVAILABLE(ios(26.0));
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator requestsPreviewForTextAnimation:(UIWritingToolsCoordinatorTextAnimation)textAnimation
                        ofRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context textDecoration:(UIWritingToolsCoordinatorTextDecoration)textDecoration
                     completion:(void (^)(UITargetedPreview *_Nullable preview))completion API_AVAILABLE(ios(26.0));
- (void)writingToolsCoordinator:(UIWritingToolsCoordinator *)writingToolsCoordinator setGrammarCheckingEnabled:(BOOL)enabled API_AVAILABLE(ios(26.0));
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.2))
@interface UIWritingToolsCoordinator : NSObject <UIInteraction>
/* NO in isim (no Apple Intelligence) */
@property (class, nonatomic, readonly, getter=isWritingToolsAvailable) BOOL writingToolsAvailable;
- (instancetype)initWithDelegate:(nullable id<UIWritingToolsCoordinatorDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, weak, readonly, nullable) id<UIWritingToolsCoordinatorDelegate> delegate;
@property (nonatomic, weak, nullable) UIView *effectContainerView;
@property (nonatomic, weak, nullable) UIView *decorationContainerView;
@property (nonatomic) UIWritingToolsBehavior preferredBehavior;
@property (nonatomic, readonly) UIWritingToolsBehavior behavior;
@property (nonatomic) UIWritingToolsResultOptions preferredResultOptions;
@property (nonatomic, readonly) UIWritingToolsResultOptions resultOptions;
@property (nonatomic, readonly) UIWritingToolsCoordinatorState state;
- (void)stopWritingTools;
- (void)updateRange:(NSRange)range withText:(NSAttributedString *)replacementText reason:(UIWritingToolsCoordinatorTextUpdateReason)reason
    forContextWithIdentifier:(NSUUID *)contextID NS_SWIFT_NAME(updateRange(_:with:reason:forContextWithIdentifier:));
- (void)updateForReflowedTextInContextWithIdentifier:(NSUUID *)contextID;
- (BOOL)showGrammarPresentationForRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context
    NS_SWIFT_NAME(showGrammarPresentation(for:in:)) API_AVAILABLE(ios(26.0));
- (nullable NSUUID *)startTextAnimation:(UIWritingToolsCoordinatorTextAnimation)textAnimation forRange:(NSRange)range inContext:(UIWritingToolsCoordinatorContext *)context
                       writingDirection:(NSWritingDirection)writingDirection NS_SWIFT_NAME(startTextAnimation(_:for:in:writingDirection:)) API_AVAILABLE(ios(26.0));
- (void)cancelTextAnimationsWithIdentifiers:(NSArray<NSUUID *> *)identifiers NS_SWIFT_NAME(cancelTextAnimations(identifiers:)) API_AVAILABLE(ios(26.0));
@end

/* ---- text views and traits ---- */
@interface UITextView (UIWritingTools)
@property (nonatomic) UIWritingToolsBehavior writingToolsBehavior API_AVAILABLE(ios(18.0));
@property (nonatomic) UIWritingToolsResultOptions allowedWritingToolsResultOptions API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly, getter=isWritingToolsActive) BOOL writingToolsActive API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly, nullable) UIWritingToolsCoordinator *writingToolsCoordinator API_AVAILABLE(ios(18.2));
@end
@interface UITextField (UIWritingTools)
@property (nonatomic) UIWritingToolsBehavior writingToolsBehavior API_AVAILABLE(ios(18.0));
@property (nonatomic) UIWritingToolsResultOptions allowedWritingToolsResultOptions API_AVAILABLE(ios(18.0));
@end
NS_ASSUME_NONNULL_END
