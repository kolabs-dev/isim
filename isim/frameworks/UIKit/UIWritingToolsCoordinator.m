/* Writing Tools (UIWritingToolsCoordinator.h): isim has no Apple Intelligence, so Writing Tools is unavailable, as
 * on an iPhone without it. Coordinators keep their settings; text views and fields keep their Writing Tools traits. */
#import "UIKitPrivate.h"
#import <UIKit/UIWritingToolsCoordinator.h>
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

NSString *UIWritingToolsCoordinatorTextAnimationDebugDescription(UIWritingToolsCoordinatorTextAnimation a) {
    switch (a) {
    case UIWritingToolsCoordinatorTextAnimationAnticipate: return @"anticipate";
    case UIWritingToolsCoordinatorTextAnimationRemove: return @"remove";
    case UIWritingToolsCoordinatorTextAnimationInsert: return @"insert";
    case UIWritingToolsCoordinatorTextAnimationIndicateGrammar: return @"indicateGrammar";
    }
    return @"unknown";
}

@implementation UIWritingToolsCoordinatorContext
- (instancetype)initWithAttributedString:(NSAttributedString *)s range:(NSRange)r {
    if ((self = [super init])) { _attributedString = [s copy]; _range = r; _identifier = [NSUUID UUID]; }
    return self;
}
- (NSRange)resolvedRange { return _range; }
@end
@implementation UIWritingToolsCoordinatorAnimationParameters @end

@implementation UIWritingToolsCoordinator { __weak UIView *_view; }
+ (BOOL)isWritingToolsAvailable { return NO; }
- (instancetype)initWithDelegate:(id<UIWritingToolsCoordinatorDelegate>)d { if ((self = [super init])) _delegate = d; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
- (UIWritingToolsBehavior)behavior { return UIWritingToolsBehaviorNone; }      /* unavailable */
- (UIWritingToolsResultOptions)resultOptions { return _preferredResultOptions; }
- (UIWritingToolsCoordinatorState)state { return UIWritingToolsCoordinatorStateInactive; }
- (void)stopWritingTools {}
- (void)updateRange:(NSRange)r withText:(NSAttributedString *)t reason:(UIWritingToolsCoordinatorTextUpdateReason)reason forContextWithIdentifier:(NSUUID *)c {}
- (void)updateForReflowedTextInContextWithIdentifier:(NSUUID *)c {}
- (BOOL)showGrammarPresentationForRange:(NSRange)r inContext:(UIWritingToolsCoordinatorContext *)c { return NO; }
- (NSUUID *)startTextAnimation:(UIWritingToolsCoordinatorTextAnimation)a forRange:(NSRange)r inContext:(UIWritingToolsCoordinatorContext *)c writingDirection:(NSWritingDirection)d { return nil; }
- (void)cancelTextAnimationsWithIdentifiers:(NSArray *)ids {}
@end

static char kBehavior, kResults;
#define ISIM_WRITING_TOOLS_TRAITS \
- (UIWritingToolsBehavior)writingToolsBehavior { return [get(self, &kBehavior) integerValue]; } \
- (void)setWritingToolsBehavior:(UIWritingToolsBehavior)b { put(self, &kBehavior, @(b)); } \
- (UIWritingToolsResultOptions)allowedWritingToolsResultOptions { return [get(self, &kResults) unsignedIntegerValue]; } \
- (void)setAllowedWritingToolsResultOptions:(UIWritingToolsResultOptions)o { put(self, &kResults, @(o)); }
@implementation UITextView (UIWritingTools)
ISIM_WRITING_TOOLS_TRAITS
- (BOOL)isWritingToolsActive { return NO; }
- (UIWritingToolsCoordinator *)writingToolsCoordinator { return nil; }
@end
@implementation UITextField (UIWritingTools)
ISIM_WRITING_TOOLS_TRAITS
@end
