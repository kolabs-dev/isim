#pragma once
/* isim: cell and content configuration members from the documentation sweep (#9): attributed and transformed list
   content, layout guides of list content views, background configurations (insets, stroke, shadow, image, color
   transformers), shadow properties, separator configurations, more cell accessories (insert, multiselect, pop-up
   menu), list cell separator guides. UIConfigurationExtras.m (drawn in UITableView.m / UICollectionView.m).
   Configurations are classes in isim (UIKit's Swift overlay values on iOS); categories keep the classes' sizes. */
#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UIContentUnavailableConfiguration.h>
#import <UIKit/UITargetedPreview.h>             /* UIAxis */
#import <UIKit/UIControlExtras.h>               /* UIConfigurationColorTransformer */
NS_ASSUME_NONNULL_BEGIN
@class UIBezierPath, UIVisualEffect, UIMenu, UILayoutGuide;

/* ---- list content ---- */
typedef NS_ENUM(NSInteger, UIListContentTextTransform) { UIListContentTextTransformNone, UIListContentTextTransformUppercase,
    UIListContentTextTransformLowercase, UIListContentTextTransformCapitalized } NS_SWIFT_NAME(UIListContentConfiguration.TextProperties.TextTransform) API_AVAILABLE(ios(14.0));
@interface UIListContentTextProperties (UIListContentTextPropertiesExtras)
@property (nonatomic) UIListContentTextTransform transform;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer colorTransformer NS_REFINED_FOR_SWIFT;
- (UIColor *)resolvedColor;
@end
/* the image's standard size (UIListContentConfiguration.ImageProperties.standardDimension) */
UIKIT_EXTERN const CGFloat UIListContentImageStandardDimension NS_SWIFT_NAME(UIListContentConfiguration.ImageProperties.standardDimension) API_AVAILABLE(ios(14.0));
@interface UIListContentImageProperties (UIListContentImagePropertiesExtras)
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer tintColorTransformer NS_REFINED_FOR_SWIFT;
- (UIColor *)resolvedTintColorForTintColor:(UIColor *)tintColor NS_SWIFT_NAME(resolvedTintColor(for:));
/* a stroke around the image (iOS 18) */
@property (nullable, nonatomic, strong) UIColor *strokeColor API_AVAILABLE(ios(18.0));
@property (nonatomic) CGFloat strokeWidth API_AVAILABLE(ios(18.0));
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer strokeColorTransformer NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(18.0));
- (UIColor *)resolvedStrokeColorForTintColor:(UIColor *)tintColor NS_SWIFT_NAME(resolvedStrokeColor(for:)) API_AVAILABLE(ios(18.0));
@end
@interface UIListContentConfiguration (UIListContentConfigurationExtras)
+ (instancetype)accompaniedSidebarCellConfiguration NS_SWIFT_NAME(accompaniedSidebarCell());
+ (instancetype)accompaniedSidebarSubtitleCellConfiguration NS_SWIFT_NAME(accompaniedSidebarSubtitleCell());
+ (instancetype)prominentInsetGroupedHeaderConfiguration NS_SWIFT_NAME(prominentInsetGroupedHeader()) API_AVAILABLE(ios(15.0));
+ (instancetype)extraProminentInsetGroupedHeaderConfiguration NS_SWIFT_NAME(extraProminentInsetGroupedHeader()) API_AVAILABLE(ios(15.0));
/* attributed texts are drawn instead of text / secondaryText */
@property (nullable, nonatomic, copy) NSAttributedString *attributedText;
@property (nullable, nonatomic, copy) NSAttributedString *secondaryAttributedText;
/* the gap between side-by-side text and secondary text */
@property (nonatomic) CGFloat textToSecondaryTextHorizontalPadding;
@property (nonatomic) UIAxis axesPreservingSuperviewLayoutMargins;      /* isim: stored */
@end
@interface UIListContentView (UIListContentViewExtras)
/* layout guides that follow the text, secondary text and image (nil while there is none) */
@property (nullable, nonatomic, readonly) UILayoutGuide *textLayoutGuide API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, readonly) UILayoutGuide *secondaryTextLayoutGuide API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, readonly) UILayoutGuide *imageLayoutGuide API_AVAILABLE(ios(16.0));
@end

/* ---- shadows ---- */
/* a shadow drawn behind a background (iOS 18; Swift: a value on iOS) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UIShadowProperties : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) CGFloat opacity;
@property (nonatomic) CGFloat radius;
@property (nonatomic) CGSize offset;
@property (nullable, nonatomic, copy) UIBezierPath *path;
@end

/* ---- backgrounds ---- */
@interface UIBackgroundConfiguration (UIBackgroundConfigurationExtras)
+ (instancetype)listCellConfiguration NS_SWIFT_NAME(listCell()) API_AVAILABLE(ios(18.0));
+ (instancetype)listHeaderConfiguration NS_SWIFT_NAME(listHeader()) API_AVAILABLE(ios(18.0));
+ (instancetype)listFooterConfiguration NS_SWIFT_NAME(listFooter()) API_AVAILABLE(ios(18.0));
+ (instancetype)listAccompaniedSidebarCellConfiguration NS_SWIFT_NAME(listAccompaniedSidebarCell());
+ (instancetype)listSidebarCellConfiguration NS_SWIFT_NAME(listSidebarCell());
/* a view drawn under the background colour's layer (isim: added behind the cell's content) */
@property (nullable, nonatomic, strong) UIView *customView;
@property (nonatomic) NSDirectionalEdgeInsets backgroundInsets;
@property (nonatomic) NSDirectionalRectEdge edgesAddingLayoutMarginsToBackgroundInsets;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer backgroundColorTransformer NS_REFINED_FOR_SWIFT;
- (UIColor *)resolvedBackgroundColorForTintColor:(UIColor *)tintColor NS_SWIFT_NAME(resolvedBackgroundColor(for:));
@property (nullable, nonatomic, copy) UIVisualEffect *visualEffect;     /* isim: stored */
@property (nullable, nonatomic, strong) UIImage *image API_AVAILABLE(ios(15.0));
@property (nonatomic) UIViewContentMode imageContentMode API_AVAILABLE(ios(15.0));
@property (nullable, nonatomic, strong) UIColor *strokeColor;
@property (nonatomic, copy, nullable) UIConfigurationColorTransformer strokeColorTransformer NS_REFINED_FOR_SWIFT;
- (UIColor *)resolvedStrokeColorForTintColor:(UIColor *)tintColor NS_SWIFT_NAME(resolvedStrokeColor(for:));
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic) CGFloat strokeOutset;
@property (nonatomic, copy) UIShadowProperties *shadowProperties API_AVAILABLE(ios(18.0));
@end

/* ---- separators ---- */
typedef NS_ENUM(NSInteger, UIListSeparatorVisibility) { UIListSeparatorVisibilityAutomatic, UIListSeparatorVisibilityVisible, UIListSeparatorVisibilityHidden }
    NS_SWIFT_NAME(UIListSeparatorConfiguration.Visibility) API_AVAILABLE(ios(14.5));
/* the top / bottom separator of a list row: visibility, insets (automaticInsets: the row's), colours */
UIKIT_EXTERN const NSDirectionalEdgeInsets UIListSeparatorAutomaticInsets NS_SWIFT_NAME(UIListSeparatorConfiguration.automaticInsets) API_AVAILABLE(ios(14.5));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.5))
@interface UIListSeparatorConfiguration : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithListAppearance:(UICollectionLayoutListAppearance)listAppearance;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic) UIListSeparatorVisibility topSeparatorVisibility;
@property (nonatomic) UIListSeparatorVisibility bottomSeparatorVisibility;
@property (nonatomic) NSDirectionalEdgeInsets topSeparatorInsets;
@property (nonatomic) NSDirectionalEdgeInsets bottomSeparatorInsets;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, strong) UIColor *multipleSelectionColor;
@property (nullable, nonatomic, copy) UIVisualEffect *visualEffect;      /* isim: stored */
@end
typedef UIListSeparatorConfiguration *_Nonnull (^UICollectionLayoutListItemSeparatorHandler)(NSIndexPath *indexPath, UIListSeparatorConfiguration *sectionSeparatorConfiguration)
    NS_SWIFT_NAME(UICollectionLayoutListConfiguration.ItemSeparatorHandler) API_AVAILABLE(ios(14.5));
typedef NS_OPTIONS(NSUInteger, UICollectionLayoutListContentHuggingElements) { UICollectionLayoutListContentHuggingElementsNone = 0,
    UICollectionLayoutListContentHuggingElementsSupplementaryHeader = 1 << 0 } NS_SWIFT_NAME(UICollectionLayoutListConfiguration.ContentHuggingElements) API_AVAILABLE(ios(26.0));
@interface UICollectionLayoutListConfiguration (UICollectionLayoutListConfigurationExtras)
@property (nonatomic, copy) UIListSeparatorConfiguration *separatorConfiguration API_AVAILABLE(ios(14.5));
@property (nonatomic, copy, nullable) UICollectionLayoutListItemSeparatorHandler itemSeparatorHandler API_AVAILABLE(ios(14.5));
@property (nonatomic) UICollectionLayoutListContentHuggingElements contentHuggingElements API_AVAILABLE(ios(26.0));   /* isim: stored */
@end
@interface UICollectionViewListCell (UICollectionViewListCellExtras)
/* the accessories move in with the indentation (default YES) */
@property (nonatomic) BOOL indentsAccessories;
/* where the bottom separator starts (constrain its leading anchor to move it) */
@property (nonatomic, readonly) UILayoutGuide *separatorLayoutGuide API_AVAILABLE(ios(14.0));
@end

/* ---- more cell accessories (Swift: UICellAccessory.insert, .multiselect, .popUpMenu) ---- */
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(__UICellAccessoryInsert)
@interface UICellAccessoryInsert : UICellAccessory
@property (nullable, nonatomic, copy) void (^actionHandler)(void);
@property (nullable, nonatomic, strong) UIColor *backgroundColor;
@end
NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(__UICellAccessoryMultiselect)
@interface UICellAccessoryMultiselect : UICellAccessory
@property (nullable, nonatomic, strong) UIColor *backgroundColor;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.0)) NS_SWIFT_NAME(__UICellAccessoryPopUpMenu)
@interface UICellAccessoryPopUpMenu : UICellAccessory
- (instancetype)initWithMenu:(UIMenu *)menu;
@property (nonatomic, readonly, copy) UIMenu *menu;
@property (nullable, nonatomic, copy) void (^selectedElementDidChangeHandler)(UIMenu *menu);
@end

/* ---- content unavailable ---- */
@interface UIContentUnavailableConfiguration (UIContentUnavailableConfigurationExtras)
@property (nullable, nonatomic, copy) NSAttributedString *attributedText;
@property (nullable, nonatomic, copy) NSAttributedString *secondaryAttributedText;
@property (nonatomic) UIAxis axesPreservingSuperviewLayoutMargins;      /* isim: stored */
@end
NS_ASSUME_NONNULL_END
