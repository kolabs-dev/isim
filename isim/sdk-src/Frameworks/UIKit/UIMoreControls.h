#pragma once
/* isim: UISlider, UIStepper, UISegmentedControl, UIProgressView, UIActivityIndicatorView, UIPageControl,
   UIMenu / UIMenuElement, CADisplayLink. */
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor, UIImage, UIFont;

NS_SWIFT_UI_ACTOR
@interface UISlider : UIControl
@property (nonatomic) float value;
@property (nonatomic) float minimumValue;
@property (nonatomic) float maximumValue;
@property (nonatomic, getter=isContinuous) BOOL continuous;
@property (nullable, nonatomic, strong) UIColor *minimumTrackTintColor;
@property (nullable, nonatomic, strong) UIColor *maximumTrackTintColor;
@property (nullable, nonatomic, strong) UIColor *thumbTintColor;
@property (nullable, nonatomic, strong) UIImage *minimumValueImage;
@property (nullable, nonatomic, strong) UIImage *maximumValueImage;
- (void)setValue:(float)value animated:(BOOL)animated;
@end

NS_SWIFT_UI_ACTOR
@interface UIStepper : UIControl
@property (nonatomic) double value;
@property (nonatomic) double minimumValue;
@property (nonatomic) double maximumValue;
@property (nonatomic) double stepValue;
@property (nonatomic) BOOL wraps;
@property (nonatomic) BOOL autorepeat;
@property (nonatomic, getter=isContinuous) BOOL continuous;
@end

UIKIT_EXTERN const NSInteger UISegmentedControlNoSegment;
NS_SWIFT_UI_ACTOR
@interface UISegmentedControl : UIControl
- (instancetype)initWithItems:(nullable NSArray *)items;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic, readonly) NSUInteger numberOfSegments;
@property (nonatomic) NSInteger selectedSegmentIndex;
@property (nullable, nonatomic, strong) UIColor *selectedSegmentTintColor;
@property (nonatomic) BOOL apportionsSegmentWidthsByContent;
@property (nonatomic, getter=isMomentary) BOOL momentary;
- (void)insertSegmentWithTitle:(nullable NSString *)title atIndex:(NSUInteger)segment animated:(BOOL)animated;
- (void)insertSegmentWithImage:(nullable UIImage *)image atIndex:(NSUInteger)segment animated:(BOOL)animated;
- (void)removeSegmentAtIndex:(NSUInteger)segment animated:(BOOL)animated;
- (void)removeAllSegments;
- (void)setTitle:(nullable NSString *)title forSegmentAtIndex:(NSUInteger)segment;
- (nullable NSString *)titleForSegmentAtIndex:(NSUInteger)segment;
- (void)setImage:(nullable UIImage *)image forSegmentAtIndex:(NSUInteger)segment;
- (nullable UIImage *)imageForSegmentAtIndex:(NSUInteger)segment;
- (void)setEnabled:(BOOL)enabled forSegmentAtIndex:(NSUInteger)segment;
- (BOOL)isEnabledForSegmentAtIndex:(NSUInteger)segment;
- (void)setWidth:(CGFloat)width forSegmentAtIndex:(NSUInteger)segment;
@end

typedef NS_ENUM(NSInteger, UIProgressViewStyle) { UIProgressViewStyleDefault, UIProgressViewStyleBar };
NS_SWIFT_UI_ACTOR
@interface UIProgressView : UIView
- (instancetype)initWithProgressViewStyle:(UIProgressViewStyle)style;
@property (nonatomic) UIProgressViewStyle progressViewStyle;
@property (nonatomic) float progress;
@property (nullable, nonatomic, strong) UIColor *progressTintColor;
@property (nullable, nonatomic, strong) UIColor *trackTintColor;
- (void)setProgress:(float)progress animated:(BOOL)animated;
@end

typedef NS_ENUM(NSInteger, UIActivityIndicatorViewStyle) {
    UIActivityIndicatorViewStyleMedium = 100, UIActivityIndicatorViewStyleLarge = 101,
    UIActivityIndicatorViewStyleWhiteLarge = 0, UIActivityIndicatorViewStyleWhite = 1, UIActivityIndicatorViewStyleGray = 2,
};
NS_SWIFT_UI_ACTOR
@interface UIActivityIndicatorView : UIView
- (instancetype)initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style NS_SWIFT_NAME(init(style:));
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic) UIActivityIndicatorViewStyle activityIndicatorViewStyle;
@property (nonatomic) BOOL hidesWhenStopped;
@property (null_resettable, nonatomic, strong) UIColor *color;
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;
- (void)startAnimating;
- (void)stopAnimating;
@end

NS_SWIFT_UI_ACTOR
@interface UIPageControl : UIControl
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) BOOL hidesForSinglePage;
@property (nullable, nonatomic, strong) UIColor *pageIndicatorTintColor;
@property (nullable, nonatomic, strong) UIColor *currentPageIndicatorTintColor;
- (CGSize)sizeForNumberOfPages:(NSInteger)pageCount;
@end

/* menus (UIButton.menu, context menus; SwiftUI Menu and Picker .menu) */
typedef NS_OPTIONS(NSUInteger, UIMenuOptions) { UIMenuOptionsDisplayInline = 1 << 0, UIMenuOptionsDestructive = 1 << 1, UIMenuOptionsSingleSelection = 1 << 5 };
NS_SWIFT_UI_ACTOR
@interface UIMenu : UIMenuElement
+ (UIMenu *)menuWithChildren:(NSArray<UIMenuElement *> *)children;
+ (UIMenu *)menuWithTitle:(NSString *)title children:(NSArray<UIMenuElement *> *)children;
+ (UIMenu *)menuWithTitle:(NSString *)title image:(nullable UIImage *)image identifier:(nullable NSString *)identifier
                  options:(UIMenuOptions)options children:(NSArray<UIMenuElement *> *)children
    NS_SWIFT_NAME(init(__title:image:identifier:options:children:));
@property (nonatomic, readonly) UIMenuOptions options;
@property (nonatomic, readonly) NSArray<UIMenuElement *> *children;
@end
/* isim: shows a menu anchored to a rect of a view (as UIKit does for UIButton.menu) */
@interface UIView (IsimMenu)
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect;
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect preview:(nullable UIView *)preview;   /* isim: with a preview view (sized) above the menu */
@end

/* CADisplayLink (QuartzCore): calls its target once per frame while added to a run loop */
@class NSRunLoop;
typedef struct { float minimum, maximum, preferred; } CAFrameRateRange;
NS_SWIFT_UI_ACTOR
@interface CADisplayLink : NSObject
+ (CADisplayLink *)displayLinkWithTarget:(id)target selector:(SEL)sel;
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSString *)mode;
- (void)invalidate;
@property (readonly, nonatomic) double timestamp;
@property (readonly, nonatomic) double duration;
@property (readonly, nonatomic) double targetTimestamp;
@property (getter=isPaused, nonatomic) BOOL paused;
@property (nonatomic) NSInteger preferredFramesPerSecond;
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@end
NS_ASSUME_NONNULL_END
