#pragma once
/* isim: Scribble (handwriting into text fields with Apple Pencil, iPad). isim has no Pencil: the script command
   `scribble X Y TEXT` writes TEXT by hand at (X, Y) (the ink is drawn, then turns into text). Editable UITextField /
   UITextView accept it without an interaction; UIScribbleInteraction lets a view veto or observe it;
   UIIndirectScribbleInteraction turns views that are not text inputs (a "search" button, a label) into writable
   elements. See UITextServices.m. */
#import <UIKit/UIInteraction.h>
#import <UIKit/UITextInput.h>
NS_ASSUME_NONNULL_BEGIN
@class UIScribbleInteraction, UIIndirectScribbleInteraction, UIResponder;

NS_SWIFT_UI_ACTOR
@protocol UIScribbleInteractionDelegate <NSObject>
@optional
- (BOOL)scribbleInteraction:(UIScribbleInteraction *)interaction shouldBeginAtLocation:(CGPoint)location NS_SWIFT_NAME(scribbleInteraction(_:shouldBeginAt:));
- (BOOL)scribbleInteractionShouldDelayFocus:(UIScribbleInteraction *)interaction;
- (void)scribbleInteractionWillBeginWriting:(UIScribbleInteraction *)interaction;
- (void)scribbleInteractionDidFinishWriting:(UIScribbleInteraction *)interaction;
@end

NS_SWIFT_UI_ACTOR
@interface UIScribbleInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIScribbleInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly, weak) id<UIScribbleInteractionDelegate> delegate;
@property (nonatomic, readonly, getter=isHandlingWriting) BOOL handlingWriting;
/* YES once the user has written with the Pencil (isim: after a `scribble` command) */
@property (class, nonatomic, readonly, getter=isPencilInputExpected) BOOL pencilInputExpected;
@end

typedef id<NSCopying, NSObject> UIScribbleElementIdentifier;

/* Swift: UIIndirectScribbleInteractionDelegate is a protocol with an ElementIdentifier: Hashable associated type
   (UIKit+TextServices.swift adapts it to this one) */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(_UIIndirectScribbleInteractionDelegateObjC)
@protocol UIIndirectScribbleInteractionDelegate <NSObject>
- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction requestElementsInRect:(CGRect)rect
                         completion:(void (^)(NSArray<UIScribbleElementIdentifier> *elements))completion;
- (BOOL)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction isElementFocused:(UIScribbleElementIdentifier)elementIdentifier;
- (CGRect)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction frameForElement:(UIScribbleElementIdentifier)elementIdentifier;
- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction focusElementIfNeeded:(UIScribbleElementIdentifier)elementIdentifier
                     referencePoint:(CGPoint)focusReferencePoint completion:(void (^)(UIResponder<UITextInput> *_Nullable focusedInput))completion;
@optional
- (BOOL)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction shouldDelayFocusForElement:(UIScribbleElementIdentifier)elementIdentifier;
- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction willBeginWritingInElement:(UIScribbleElementIdentifier)elementIdentifier;
- (void)indirectScribbleInteraction:(UIIndirectScribbleInteraction *)interaction didFinishWritingInElement:(UIScribbleElementIdentifier)elementIdentifier;
@end

NS_SWIFT_UI_ACTOR
@interface UIIndirectScribbleInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIIndirectScribbleInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly, weak) id<UIIndirectScribbleInteractionDelegate> delegate NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly, getter=isHandlingWriting) BOOL handlingWriting;
@end
NS_ASSUME_NONNULL_END
