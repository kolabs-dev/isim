#pragma once
#import <PencilKit/PKToolPickerItem.h>
#import <PencilKit/PKContentVersion.h>
NS_ASSUME_NONNULL_BEGIN
@class PKToolPicker;
API_AVAILABLE(ios(13.0))
@protocol PKToolPickerObserver <NSObject>
@optional
- (void)toolPickerSelectedToolDidChange:(PKToolPicker *)toolPicker API_DEPRECATED("use toolPickerSelectedToolItemDidChange:", ios(13.0, 18.0));
- (void)toolPickerSelectedToolItemDidChange:(PKToolPicker *)toolPicker API_AVAILABLE(ios(18.0));
- (void)toolPickerIsRulerActiveDidChange:(PKToolPicker *)toolPicker;
- (void)toolPickerVisibilityDidChange:(PKToolPicker *)toolPicker;
- (void)toolPickerFramesObscuredDidChange:(PKToolPicker *)toolPicker;
@end

/* isim: a palette at the bottom of the window (inks with their colors, the eraser, the lasso, the ruler), shown while
 * the responder given to setVisible:forFirstResponder: is the first responder */
API_AVAILABLE(ios(13.0))
@interface PKToolPicker : NSObject
- (instancetype)init;
- (instancetype)initWithToolItems:(NSArray<PKToolPickerItem *> *)toolItems API_AVAILABLE(ios(18.0));
- (void)addObserver:(id<PKToolPickerObserver>)observer NS_SWIFT_NAME(addObserver(_:));
- (void)removeObserver:(id<PKToolPickerObserver>)observer NS_SWIFT_NAME(removeObserver(_:));
- (void)setVisible:(BOOL)visible forFirstResponder:(UIResponder *)responder;
@property (nonatomic, readonly) BOOL isVisible;
- (CGRect)frameObscuredInView:(UIView *)view;
@property (nonatomic, strong) PKTool *selectedTool NS_REFINED_FOR_SWIFT API_DEPRECATED("use selectedToolItem", ios(13.0, 18.0));
@property (nonatomic, readonly) NSArray<PKToolPickerItem *> *toolItems API_AVAILABLE(ios(18.0));
@property (nonatomic, strong) PKToolPickerItem *selectedToolItem API_AVAILABLE(ios(18.0));
@property (nonatomic, copy) NSString *selectedToolItemIdentifier API_AVAILABLE(ios(18.0));
@property (nonatomic, getter=isRulerActive) BOOL rulerActive;
@property (nonatomic) UIUserInterfaceStyle colorUserInterfaceStyle;
@property (nonatomic) UIUserInterfaceStyle overrideUserInterfaceStyle;
@property (nonatomic) BOOL showsDrawingPolicyControls API_AVAILABLE(ios(14.0));
@property (nonatomic, copy, nullable) NSString *stateAutosaveName API_AVAILABLE(ios(14.0));
@property (nonatomic, strong, nullable) UIBarButtonItem *accessoryItem API_AVAILABLE(ios(18.0));
@property (nonatomic) PKContentVersion maximumSupportedContentVersion API_AVAILABLE(ios(17.0));
@property (nonatomic) CGFloat colorMaximumLinearExposure API_AVAILABLE(ios(26.0));
@property (nonatomic) BOOL prefersDismissControlVisible API_AVAILABLE(ios(26.0));
@property (class, nonatomic, readonly) NSArray<PKToolPickerItem *> *defaultToolItems API_AVAILABLE(ios(26.0));
+ (nullable PKToolPicker *)sharedToolPickerForWindow:(UIWindow *)window API_DEPRECATED("create a PKToolPicker", ios(13.0, 14.0));
@end
NS_ASSUME_NONNULL_END
