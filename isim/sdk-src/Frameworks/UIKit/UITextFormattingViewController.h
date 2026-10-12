#pragma once
/* isim: the text formatting panel (iOS 18) and the text formatting coordinator. The panel shows the configured
   components (font attributes, font, size, colour, highlight, lists, indentation, alignment, line height, formatting
   styles) in rows and reports each change to its delegate. A text view with allowsEditingTextAttributes offers it in
   its edit menu (Format) and applies the changes to its selection. Adapted: isim's own drawing of the panel, a
   sheet on iPhone, a popover on iPad. Its controls have the ids isim-format-* (UITextFormattingViewController.m). */
#import <UIKit/UIViewController.h>
#import <UIKit/UIFontPickerViewController.h>
#import <UIKit/UIEditMenuInteraction.h>
#import <UIKit/UITextView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColorPickerViewController, UIWindowScene, UIFont, UIColor;

typedef NSString *UITextFormattingViewControllerComponentKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UITextFormattingViewController.ComponentKey) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFontAttributesComponentKey NS_SWIFT_NAME(fontAttributes) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFontPickerComponentKey NS_SWIFT_NAME(fontPicker) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFontPointSizeComponentKey NS_SWIFT_NAME(fontPointSize) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFontSizeComponentKey NS_SWIFT_NAME(fontSize) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFormattingStylesComponentKey NS_SWIFT_NAME(formattingStyles) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerHighlightComponentKey NS_SWIFT_NAME(highlight) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerHighlightPickerComponentKey NS_SWIFT_NAME(highlightPicker) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerLineHeightComponentKey NS_SWIFT_NAME(lineHeight) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerListStylesComponentKey NS_SWIFT_NAME(listStyles) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerTextAlignmentComponentKey NS_SWIFT_NAME(textAlignment) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerTextAlignmentAndJustificationComponentKey NS_SWIFT_NAME(textAlignmentAndJustification) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerTextColorComponentKey NS_SWIFT_NAME(textColor) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerTextIndentationComponentKey NS_SWIFT_NAME(textIndentation) API_AVAILABLE(ios(18.0));

typedef NS_ENUM(NSInteger, UITextFormattingViewControllerComponentSize) {
    UITextFormattingViewControllerComponentSizeAutomatic = 0, UITextFormattingViewControllerComponentSizeMini, UITextFormattingViewControllerComponentSizeSmall,
    UITextFormattingViewControllerComponentSizeRegular, UITextFormattingViewControllerComponentSizeLarge, UITextFormattingViewControllerComponentSizeExtraLarge,
} NS_SWIFT_NAME(UITextFormattingViewController.ComponentSize) API_AVAILABLE(ios(18.0));

/* highlight colours (NSTextHighlightColorScheme values) */
typedef NSString *UITextFormattingViewControllerHighlight NS_TYPED_ENUM NS_SWIFT_NAME(UITextFormattingViewController.Highlight) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightDefault NS_SWIFT_NAME(default) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightPurple NS_SWIFT_NAME(purple) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightPink NS_SWIFT_NAME(pink) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightOrange NS_SWIFT_NAME(orange) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightMint NS_SWIFT_NAME(mint) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightBlue NS_SWIFT_NAME(blue) API_AVAILABLE(ios(18.0));

typedef NSString *UITextFormattingViewControllerTextAlignment NS_TYPED_ENUM NS_SWIFT_NAME(UITextFormattingViewController.TextAlignment) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentLeft NS_SWIFT_NAME(left) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentCenter NS_SWIFT_NAME(center) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentRight NS_SWIFT_NAME(right) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentJustified NS_SWIFT_NAME(justified) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentNatural NS_SWIFT_NAME(natural) API_AVAILABLE(ios(18.0));

typedef NSString *UITextFormattingViewControllerTextList NS_TYPED_ENUM NS_SWIFT_NAME(UITextFormattingViewController.TextList) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextList const UITextFormattingViewControllerTextListDisc NS_SWIFT_NAME(disc) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextList const UITextFormattingViewControllerTextListHyphen NS_SWIFT_NAME(hyphen) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextList const UITextFormattingViewControllerTextListDecimal NS_SWIFT_NAME(decimal) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerTextList const UITextFormattingViewControllerTextListOther NS_SWIFT_NAME(other) API_AVAILABLE(ios(18.0));

NS_SWIFT_NAME(UITextFormattingViewController.Component) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerComponent : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithComponentKey:(UITextFormattingViewControllerComponentKey)componentKey preferredSize:(UITextFormattingViewControllerComponentSize)preferredSize NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) UITextFormattingViewControllerComponentKey componentKey;
@property (nonatomic, readonly) UITextFormattingViewControllerComponentSize preferredSize;
@end

NS_SWIFT_NAME(UITextFormattingViewController.ComponentGroup) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerComponentGroup : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithComponents:(NSArray<UITextFormattingViewControllerComponent *> *)components NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSArray<UITextFormattingViewControllerComponent *> *components;
@end

/* a named set of attributes (Title, Heading, Body ...) applied to whole paragraphs; Swift: FormattingStyle */
NS_SWIFT_NAME(__UITextFormattingViewControllerFormattingStyle) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerFormattingStyle : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithStyleKey:(NSString *)styleKey title:(NSString *)title attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *styleKey;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSDictionary<NSAttributedStringKey, id> *attributes;
@end

NS_SWIFT_NAME(UITextFormattingViewController.Configuration) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerConfiguration : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithGroups:(NSArray<UITextFormattingViewControllerComponentGroup *> *)groups NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
/* the standard panel's groups */
- (instancetype)init;
@property (nonatomic, readonly, copy) NSArray<UITextFormattingViewControllerComponentGroup *> *groups;
@property (nonatomic, copy, nullable) UIFontPickerViewControllerConfiguration *fontPickerConfiguration;
@property (nonatomic, copy, nullable) NSArray<UITextFormattingViewControllerFormattingStyle *> *formattingStyles NS_REFINED_FOR_SWIFT;
@end

/* the formatting of the selection, which the panel shows (Swift: FormattingDescriptor) */
NS_SWIFT_NAME(__UITextFormattingViewControllerFormattingDescriptor) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerFormattingDescriptor : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes;
- (instancetype)initWithString:(NSAttributedString *)string range:(NSRange)range;
@property (nonatomic, copy) NSArray<UIFont *> *fonts;
@property (nonatomic, copy) NSArray<UIColor *> *textColors;
@property (nonatomic, copy) NSSet<UITextFormattingViewControllerTextAlignment> *textAlignments;
@property (nonatomic, copy) NSSet<UITextFormattingViewControllerTextList> *textLists;
@property (nonatomic, copy) NSSet<UITextFormattingViewControllerHighlight> *highlights;
@property (nonatomic) BOOL underlinePresent;
@property (nonatomic) BOOL strikethroughPresent;
@property (nonatomic) CGFloat lineHeight;
@property (nonatomic, copy, nullable) NSString *formattingStyleKey;
@end

/* what a change sets (Swift: the ChangeValue enum) */
typedef NSString *UITextFormattingViewControllerChangeType NS_TYPED_ENUM NS_SWIFT_NAME(__UITextFormattingViewControllerChangeType) API_AVAILABLE(ios(18.0));
UIKIT_EXTERN UITextFormattingViewControllerChangeType const UITextFormattingViewControllerChangeTypeFont, UITextFormattingViewControllerChangeTypeTextColor,
    UITextFormattingViewControllerChangeTypeHighlight, UITextFormattingViewControllerChangeTypeUnderline, UITextFormattingViewControllerChangeTypeStrikethrough,
    UITextFormattingViewControllerChangeTypeTextAlignment, UITextFormattingViewControllerChangeTypeTextList, UITextFormattingViewControllerChangeTypeLineHeightPointSize,
    UITextFormattingViewControllerChangeTypeFormattingStyle, UITextFormattingViewControllerChangeTypeIncreaseFontSize,
    UITextFormattingViewControllerChangeTypeDecreaseFontSize, UITextFormattingViewControllerChangeTypeIncreaseIndentation,
    UITextFormattingViewControllerChangeTypeDecreaseIndentation API_AVAILABLE(ios(18.0));
NS_SWIFT_NAME(__UITextFormattingViewControllerChangeValue) API_AVAILABLE(ios(18.0))
@interface UITextFormattingViewControllerChangeValue : NSObject
- (instancetype)initWithChangeType:(UITextFormattingViewControllerChangeType)changeType value:(nullable id)value NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) UITextFormattingViewControllerChangeType changeType;
/* a UIFont, UIColor, NSNumber (BOOL, point size), alignment / list / highlight / style key string, or nil */
@property (nonatomic, readonly, nullable) id value;
@end

@class UITextFormattingViewController;
NS_SWIFT_NAME(__UITextFormattingViewControllerDelegate) API_AVAILABLE(ios(18.0)) NS_SWIFT_UI_ACTOR
@protocol UITextFormattingViewControllerDelegate <NSObject>
@optional
- (void)textFormattingViewController:(UITextFormattingViewController *)viewController didChangeValue:(UITextFormattingViewControllerChangeValue *)changeValue;
- (BOOL)textFormattingViewController:(UITextFormattingViewController *)viewController shouldPresentFontPicker:(UIFontPickerViewController *)fontPicker;
- (BOOL)textFormattingViewController:(UITextFormattingViewController *)viewController shouldPresentColorPicker:(UIColorPickerViewController *)colorPicker;
- (void)textFormattingDidFinish:(UITextFormattingViewController *)viewController;
@end

API_AVAILABLE(ios(18.0)) NS_SWIFT_UI_ACTOR
@interface UITextFormattingViewController : UIViewController
- (instancetype)initWithConfiguration:(UITextFormattingViewControllerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) UITextFormattingViewControllerConfiguration *configuration;
@property (nonatomic, copy, nullable) UITextFormattingViewControllerFormattingDescriptor *formattingDescriptor NS_REFINED_FOR_SWIFT;
@property (nonatomic, weak, nullable) id<UITextFormattingViewControllerDelegate> delegate NS_REFINED_FOR_SWIFT;
@end

/* the system font panel's coordinator (Mac Catalyst): on iPhone and iPad there is no font panel, as on iOS */
API_AVAILABLE(ios(13.0)) NS_SWIFT_UI_ACTOR
@protocol UITextFormattingCoordinatorDelegate <NSObject>
- (void)updateTextAttributesWithConversionHandler:(NS_NOESCAPE UITextAttributesConversionHandler)conversionHandler NS_SWIFT_NAME(updateTextAttributes(conversionHandler:));
@end
API_AVAILABLE(ios(13.0)) NS_SWIFT_UI_ACTOR
@interface UITextFormattingCoordinator : NSObject <UIFontPickerViewControllerDelegate>
+ (instancetype)textFormattingCoordinatorForWindowScene:(UIWindowScene *)windowScene NS_SWIFT_NAME(init(for:));
- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene;
@property (nullable, nonatomic, weak) id<UITextFormattingCoordinatorDelegate> delegate;
- (void)setSelectedAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes isMultiple:(BOOL)flag;
@property (class, readonly, getter=isFontPanelVisible) BOOL fontPanelVisible;
+ (void)toggleFontPanel:(id)sender;
@end

@interface UITextView (UITextFormatting)
/* the panel the edit menu's Format shows (nil: the standard one) */
@property (nonatomic, copy, nullable) UITextFormattingViewControllerConfiguration *textFormattingConfiguration API_AVAILABLE(ios(18.0));
@end
NS_ASSUME_NONNULL_END
