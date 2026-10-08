#pragma once
/* isim: UIFontDescriptor — font attributes (family, name, size, traits, text style, design, features) and the fonts
 * they describe (UIFont(descriptor:size:)). isim draws the system font with Adwaita Sans; italic, bold, monospaced,
 * tabular digits and the serif design are drawn, the rounded design falls back to the default face (adapted). */
#import <UIKit/UIFont.h>
NS_ASSUME_NONNULL_BEGIN
@class UITraitCollection;

typedef NS_OPTIONS(uint32_t, UIFontDescriptorSymbolicTraits) {
    UIFontDescriptorTraitItalic = 1u << 0,
    UIFontDescriptorTraitBold = 1u << 1,
    UIFontDescriptorTraitExpanded = 1u << 5,
    UIFontDescriptorTraitCondensed = 1u << 6,
    UIFontDescriptorTraitMonoSpace = 1u << 10,
    UIFontDescriptorTraitVertical = 1u << 11,
    UIFontDescriptorTraitUIOptimized = 1u << 12,
    UIFontDescriptorTraitTightLeading = 1u << 15,
    UIFontDescriptorTraitLooseLeading = 1u << 16,
    UIFontDescriptorClassMask = 0xF0000000,
    UIFontDescriptorClassUnknown = 0u << 28,
    UIFontDescriptorClassOldStyleSerifs = 1u << 28,
    UIFontDescriptorClassTransitionalSerifs = 2u << 28,
    UIFontDescriptorClassModernSerifs = 3u << 28,
    UIFontDescriptorClassClarendonSerifs = 4u << 28,
    UIFontDescriptorClassSlabSerifs = 5u << 28,
    UIFontDescriptorClassFreeformSerifs = 7u << 28,
    UIFontDescriptorClassSansSerif = 8u << 28,
    UIFontDescriptorClassOrnamentals = 9u << 28,
    UIFontDescriptorClassScripts = 10u << 28,
    UIFontDescriptorClassSymbolic = 12u << 28,
} NS_SWIFT_NAME(UIFontDescriptor.SymbolicTraits);

typedef NSString *UIFontDescriptorAttributeName NS_TYPED_ENUM NS_SWIFT_NAME(UIFontDescriptor.AttributeName);
typedef NSString *UIFontDescriptorTraitKey NS_TYPED_ENUM NS_SWIFT_NAME(UIFontDescriptor.TraitKey);
typedef NSString *UIFontDescriptorFeatureKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UIFontDescriptor.FeatureKey);
typedef NSString *UIFontDescriptorSystemDesign NS_TYPED_ENUM NS_SWIFT_NAME(UIFontDescriptor.SystemDesign);
typedef CGFloat UIFontWidth NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UIFont.Width);

UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute NS_SWIFT_NAME(family);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute NS_SWIFT_NAME(name);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute NS_SWIFT_NAME(face);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute NS_SWIFT_NAME(size);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorVisibleNameAttribute NS_SWIFT_NAME(visibleName);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorMatrixAttribute NS_SWIFT_NAME(matrix);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorCharacterSetAttribute NS_SWIFT_NAME(characterSet);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorCascadeListAttribute NS_SWIFT_NAME(cascadeList);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorTraitsAttribute NS_SWIFT_NAME(traits);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFixedAdvanceAttribute NS_SWIFT_NAME(fixedAdvance);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorFeatureSettingsAttribute NS_SWIFT_NAME(featureSettings);
UIKIT_EXTERN UIFontDescriptorAttributeName const UIFontDescriptorTextStyleAttribute NS_SWIFT_NAME(textStyle);

UIKIT_EXTERN UIFontDescriptorTraitKey const UIFontSymbolicTrait NS_SWIFT_NAME(symbolic);
UIKIT_EXTERN UIFontDescriptorTraitKey const UIFontWeightTrait NS_SWIFT_NAME(weight);
UIKIT_EXTERN UIFontDescriptorTraitKey const UIFontWidthTrait NS_SWIFT_NAME(width);
UIKIT_EXTERN UIFontDescriptorTraitKey const UIFontSlantTrait NS_SWIFT_NAME(slant);

UIKIT_EXTERN UIFontDescriptorFeatureKey const UIFontFeatureTypeIdentifierKey NS_SWIFT_NAME(type);
UIKIT_EXTERN UIFontDescriptorFeatureKey const UIFontFeatureSelectorIdentifierKey NS_SWIFT_NAME(selector);

UIKIT_EXTERN UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignDefault NS_SWIFT_NAME(default);
UIKIT_EXTERN UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignRounded NS_SWIFT_NAME(rounded);
UIKIT_EXTERN UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignSerif NS_SWIFT_NAME(serif);
UIKIT_EXTERN UIFontDescriptorSystemDesign const UIFontDescriptorSystemDesignMonospaced NS_SWIFT_NAME(monospaced);

UIKIT_EXTERN const UIFontWidth UIFontWidthCondensed, UIFontWidthStandard, UIFontWidthExpanded, UIFontWidthCompressed;

NS_SWIFT_UI_ACTOR
@interface UIFontDescriptor : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes NS_DESIGNATED_INITIALIZER;
+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size;
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)fontName matrix:(CGAffineTransform)matrix;
+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style;
+ (UIFontDescriptor *)preferredFontDescriptorWithTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(nullable UITraitCollection *)traitCollection;

@property (nonatomic, readonly) NSString *postscriptName;
@property (nonatomic, readonly) CGFloat pointSize;
@property (nonatomic, readonly) CGAffineTransform matrix;
@property (nonatomic, readonly) UIFontDescriptorSymbolicTraits symbolicTraits;
@property (nonatomic, readonly) NSDictionary<UIFontDescriptorAttributeName, id> *fontAttributes;
- (nullable id)objectForKey:(UIFontDescriptorAttributeName)anAttribute;
- (NSArray<UIFontDescriptor *> *)matchingFontDescriptorsWithMandatoryKeys:(nullable NSSet<UIFontDescriptorAttributeName> *)mandatoryKeys;

- (UIFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary<UIFontDescriptorAttributeName, id> *)attributes;
- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)newPointSize;
- (UIFontDescriptor *)fontDescriptorWithMatrix:(CGAffineTransform)matrix;
- (UIFontDescriptor *)fontDescriptorWithFace:(NSString *)newFace;
- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)newFamily;
- (nullable UIFontDescriptor *)fontDescriptorWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)symbolicTraits;
- (nullable UIFontDescriptor *)fontDescriptorWithDesign:(UIFontDescriptorSystemDesign)design;
@end

@interface UIFont (UIFontDescriptorSupport)
+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)descriptor size:(CGFloat)pointSize;
@property (nonatomic, readonly) UIFontDescriptor *fontDescriptor;
+ (NSArray<NSString *> *)fontNamesForFamilyName:(NSString *)familyName;
+ (UIFont *)systemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight width:(UIFontWidth)width;
@end
NS_ASSUME_NONNULL_END
