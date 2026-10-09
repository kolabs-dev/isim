#pragma once
/* isim: trait collections. A collection holds the traits it specifies (others read as unspecified); views, view
   controllers, windows and window scenes inherit their parent's traits and apply their overrides
   (overrideUserInterfaceStyle, traitOverrides). Custom traits (iOS 17): Objective-C classes conforming to
   UICGFloatTraitDefinition / UINSIntegerTraitDefinition / UIObjectTraitDefinition, or Swift types conforming to
   UITraitDefinition (UIKit overlay). Trait changes call traitCollectionDidChange: and trait change registrations
   (UILayoutExtras.h) before the next layout pass. */
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIUserInterfaceStyle) { UIUserInterfaceStyleUnspecified, UIUserInterfaceStyleLight, UIUserInterfaceStyleDark };
typedef NS_ENUM(NSInteger, UIUserInterfaceIdiom) { UIUserInterfaceIdiomUnspecified = -1, UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPad,
    UIUserInterfaceIdiomTV, UIUserInterfaceIdiomCarPlay, UIUserInterfaceIdiomMac = 5, UIUserInterfaceIdiomVision = 6 };
typedef NS_ENUM(NSInteger, UIUserInterfaceSizeClass) { UIUserInterfaceSizeClassUnspecified, UIUserInterfaceSizeClassCompact, UIUserInterfaceSizeClassRegular };
typedef NS_ENUM(NSInteger, UIUserInterfaceLevel) { UIUserInterfaceLevelUnspecified = -1, UIUserInterfaceLevelBase, UIUserInterfaceLevelElevated };
typedef NS_ENUM(NSInteger, UITraitEnvironmentLayoutDirection) { UITraitEnvironmentLayoutDirectionUnspecified = -1,
    UITraitEnvironmentLayoutDirectionLeftToRight, UITraitEnvironmentLayoutDirectionRightToLeft };
typedef NS_ENUM(NSInteger, UIDisplayGamut) { UIDisplayGamutUnspecified = -1, UIDisplayGamutSRGB, UIDisplayGamutP3 };
typedef NS_ENUM(NSInteger, UIForceTouchCapability) { UIForceTouchCapabilityUnknown, UIForceTouchCapabilityUnavailable, UIForceTouchCapabilityAvailable };
typedef NS_ENUM(NSInteger, UIUserInterfaceActiveAppearance) { UIUserInterfaceActiveAppearanceUnspecified = -1,
    UIUserInterfaceActiveAppearanceInactive, UIUserInterfaceActiveAppearanceActive } API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, UIListEnvironment) { UIListEnvironmentUnspecified, UIListEnvironmentNone, UIListEnvironmentPlain,
    UIListEnvironmentGrouped, UIListEnvironmentInsetGrouped, UIListEnvironmentSidebar, UIListEnvironmentSidebarPlain } API_AVAILABLE(ios(18.0));
@class UITabAccessory;
/* iOS 26: where a tab bar accessory's content view is shown (above the tab bar: regular; beside a minimized one: inline) */
typedef NS_ENUM(NSInteger, UITabAccessoryEnvironment) { UITabAccessoryEnvironmentUnspecified = 0, UITabAccessoryEnvironmentNone = 1,
    UITabAccessoryEnvironmentRegular = 2, UITabAccessoryEnvironmentInline = 3 } NS_SWIFT_NAME(UITabAccessory.Environment) API_AVAILABLE(ios(26.0));
typedef NSString *UIContentSizeCategory NS_TYPED_ENUM;
typedef NS_ENUM(NSInteger, UIAccessibilityContrast) { UIAccessibilityContrastUnspecified = -1, UIAccessibilityContrastNormal, UIAccessibilityContrastHigh };
typedef NS_ENUM(NSInteger, UILegibilityWeight) { UILegibilityWeightUnspecified = -1, UILegibilityWeightRegular, UILegibilityWeightBold };

/* ---- traits as types (iOS 17) ---- */
/* Swift: the UIKit overlay's UITraitDefinition protocol (with an associated Value) is what custom Swift traits adopt;
   this Objective-C protocol is _UITraitDefinitionObjC there. */
NS_SWIFT_NAME(_UITraitDefinitionObjC)
@protocol UITraitDefinition <NSObject>
@optional
@property (class, nonatomic, readonly, copy) NSString *identifier;
@property (class, nonatomic, readonly, copy) NSString *name;
@property (class, nonatomic, readonly) BOOL affectsColorAppearance;
@end
NS_SWIFT_NAME(_UICGFloatTraitDefinitionObjC) API_AVAILABLE(ios(17.0))
@protocol UICGFloatTraitDefinition <UITraitDefinition>
@property (class, nonatomic, readonly) CGFloat defaultValue;
@end
NS_SWIFT_NAME(_UINSIntegerTraitDefinitionObjC) API_AVAILABLE(ios(17.0))
@protocol UINSIntegerTraitDefinition <UITraitDefinition>
@property (class, nonatomic, readonly) NSInteger defaultValue;
@end
NS_SWIFT_NAME(_UIObjectTraitDefinitionObjC) API_AVAILABLE(ios(17.0))
@protocol UIObjectTraitDefinition <UITraitDefinition>
@property (class, nonatomic, readonly, nullable) id defaultValue;
@end
/* the system traits */
@interface UITraitUserInterfaceStyle : NSObject <UITraitDefinition> @end
@interface UITraitHorizontalSizeClass : NSObject <UITraitDefinition> @end
@interface UITraitVerticalSizeClass : NSObject <UITraitDefinition> @end
@interface UITraitUserInterfaceIdiom : NSObject <UITraitDefinition> @end
@interface UITraitDisplayScale : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitLayoutDirection : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitForceTouchCapability : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitPreferredContentSizeCategory : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitDisplayGamut : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitAccessibilityContrast : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitUserInterfaceLevel : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitLegibilityWeight : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(17.0)) @interface UITraitActiveAppearance : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(18.0)) @interface UITraitListEnvironment : NSObject <UITraitDefinition> @end
API_AVAILABLE(ios(26.0)) @interface UITraitTabAccessoryEnvironment : NSObject <UITraitDefinition> @end

/* writable traits: the block of +traitCollectionWithTraits: and traitOverrides */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UIMutableTraits <NSObject>
- (void)setCGFloatValue:(CGFloat)value forTrait:(Class)trait NS_REFINED_FOR_SWIFT;
- (void)setNSIntegerValue:(NSInteger)value forTrait:(Class)trait NS_REFINED_FOR_SWIFT;
- (void)setObject:(nullable id)object forTrait:(Class)trait NS_REFINED_FOR_SWIFT;
@property (nonatomic) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic) UITraitEnvironmentLayoutDirection layoutDirection;
@property (nonatomic) CGFloat displayScale;
@property (nonatomic) UIUserInterfaceSizeClass horizontalSizeClass;
@property (nonatomic) UIUserInterfaceSizeClass verticalSizeClass;
@property (nonatomic) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, copy) UIContentSizeCategory preferredContentSizeCategory;
@property (nonatomic) UIDisplayGamut displayGamut;
@property (nonatomic) UIAccessibilityContrast accessibilityContrast;
@property (nonatomic) UIUserInterfaceLevel userInterfaceLevel;
@property (nonatomic) UILegibilityWeight legibilityWeight;
@property (nonatomic) UIUserInterfaceActiveAppearance activeAppearance;
@property (nonatomic) UITabAccessoryEnvironment tabAccessoryEnvironment API_AVAILABLE(ios(26.0));
/* isim: storage for Swift custom traits (keyed by the trait's identifier); used by the UIKit overlay */
- (void)_isim_setObject:(nullable id)object forTraitIdentifier:(NSString *)identifier;
- (nullable id)_isim_objectForTraitIdentifier:(NSString *)identifier;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UITraitOverrides <UIMutableTraits>
- (BOOL)containsTrait:(Class)trait NS_REFINED_FOR_SWIFT;
- (void)removeTrait:(Class)trait NS_REFINED_FOR_SWIFT;
- (BOOL)_isim_containsTraitIdentifier:(NSString *)identifier;
- (void)_isim_removeTraitIdentifier:(NSString *)identifier;
@end

typedef NS_ENUM(NSInteger, UIVerticalBarEdge) { UIVerticalBarEdgeUnspecified = 0, UIVerticalBarEdgeLeading = 1, UIVerticalBarEdgeTrailing = 2 } API_AVAILABLE(ios(27.1));
@interface UITraitCollection : NSObject <NSCopying, NSSecureCoding>
/* the traits used to resolve dynamic colors and images right now (set while UIKit lays out and draws a view, or by
   performAsCurrentTraitCollection:) */
@property (class, nonatomic, strong) UITraitCollection *currentTraitCollection;
- (void)performAsCurrentTraitCollection:(void (NS_NOESCAPE ^)(void))actions NS_SWIFT_NAME(performAsCurrent(_:));
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIUserInterfaceSizeClass horizontalSizeClass, verticalSizeClass;
@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) UITraitEnvironmentLayoutDirection layoutDirection;
@property (nonatomic, readonly) UIForceTouchCapability forceTouchCapability;
@property (nonatomic, readonly) UIDisplayGamut displayGamut;
@property (nonatomic, readonly) UIUserInterfaceLevel userInterfaceLevel;
@property (nonatomic, readonly) UIUserInterfaceActiveAppearance activeAppearance API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) UIListEnvironment listEnvironment API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly) UITabAccessoryEnvironment tabAccessoryEnvironment API_AVAILABLE(ios(26.0));
+ (UITraitCollection *)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style;
+ (UITraitCollection *)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom;
+ (UITraitCollection *)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass;
+ (UITraitCollection *)traitCollectionWithVerticalSizeClass:(UIUserInterfaceSizeClass)verticalSizeClass;
+ (UITraitCollection *)traitCollectionWithDisplayScale:(CGFloat)scale;
+ (UITraitCollection *)traitCollectionWithLayoutDirection:(UITraitEnvironmentLayoutDirection)layoutDirection;
+ (UITraitCollection *)traitCollectionWithDisplayGamut:(UIDisplayGamut)displayGamut;
+ (UITraitCollection *)traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)accessibilityContrast;
+ (UITraitCollection *)traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)userInterfaceLevel;
+ (UITraitCollection *)traitCollectionWithLegibilityWeight:(UILegibilityWeight)legibilityWeight;
+ (UITraitCollection *)traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)activeAppearance API_AVAILABLE(ios(14.0));
+ (UITraitCollection *)traitCollectionWithTraitsFromCollections:(NSArray<UITraitCollection *> *)traitCollections NS_SWIFT_NAME(init(traitsFrom:));
/* iOS 17: build or modify a collection with a mutable-traits block (Swift: init(mutations:), modifyingTraits(_:)) */
+ (UITraitCollection *)traitCollectionWithTraits:(void (NS_NOESCAPE ^)(id<UIMutableTraits> mutableTraits))mutations NS_SWIFT_NAME(_isim_traitCollection(traits:)) API_AVAILABLE(ios(17.0));
- (UITraitCollection *)traitCollectionByModifyingTraits:(void (NS_NOESCAPE ^)(id<UIMutableTraits> mutableTraits))mutations NS_SWIFT_NAME(_isim_modifyingTraits(_:)) API_AVAILABLE(ios(17.0));
- (BOOL)containsTraitsInCollection:(nullable UITraitCollection *)trait;
- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(nullable UITraitCollection *)traitCollection NS_SWIFT_NAME(hasDifferentColorAppearance(comparedTo:));
/* custom traits (Objective-C trait classes) */
- (CGFloat)valueForCGFloatTrait:(Class)trait NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(17.0));
- (NSInteger)valueForNSIntegerTrait:(Class)trait NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(17.0));
- (nullable id)objectForTrait:(Class)trait NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(17.0));
/* the identifiers of the traits whose values differ (iOS 17 changedTraitsFromTraitCollection:) */
- (NSSet<NSString *> *)_isim_changedTraitIdentifiersFrom:(nullable UITraitCollection *)previous;
- (nullable id)_isim_objectForTraitIdentifier:(NSString *)identifier;   /* the specified value, or nil */
+ (NSString *)_isim_identifierForTrait:(Class)trait;                    /* the key a trait class is stored under */
+ (void)_isim_registerTraitIdentifier:(NSString *)identifier affectsColorAppearance:(BOOL)affectsColorAppearance;
@property (class, nonatomic, readonly) NSArray<Class> *systemTraitsAffectingColorAppearance NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(17.0));
@property (class, nonatomic, readonly) NSArray<Class> *systemTraitsAffectingImageLookup NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(17.0));
/* iOS 27.1: the edge where the system puts the vertical bar; isim's devices have none (unspecified) */
@property (nonatomic, readonly) UIVerticalBarEdge verticalBarEdge API_AVAILABLE(ios(27.1));
@property (class, nonatomic, readonly) NSArray<Class> *systemTraitsAffectingVerticalBarEdge NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(27.1));
@end
NS_SWIFT_UI_ACTOR
@protocol UITraitEnvironment <NSObject>
@property (nonatomic, readonly) UITraitCollection *traitCollection;
- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection;
@end
NS_ASSUME_NONNULL_END
