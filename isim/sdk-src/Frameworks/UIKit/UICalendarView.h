#pragma once
/* isim: UICalendarView (iOS 16): a month calendar (month title, previous / next month, weekday row, a six-week day
   grid) with decorations under the days and selection behaviours (one date, several dates, a week of the year).
   UICalendarView.m. The month / year wheels Apple shows when the title is tapped are not drawn. */
#import <UIKit/UIView.h>
#import <UIKit/UIFontDescriptor.h>
NS_ASSUME_NONNULL_BEGIN
@class UICalendarView, UICalendarSelection, UICalendarViewDecoration, UIColor, UIImage;

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@protocol UICalendarViewDelegate <NSObject>
@optional
/* the decoration under a day (nil: none); asked for the visible days when wantsDateDecorations is YES */
- (nullable UICalendarViewDecoration *)calendarView:(UICalendarView *)calendarView decorationForDateComponents:(NSDateComponents *)dateComponents;
/* the user moved to another month */
- (void)calendarView:(UICalendarView *)calendarView didChangeVisibleDateComponentsFrom:(NSDateComponents *)previousDateComponents API_AVAILABLE(ios(16.2));
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UICalendarView : UIView
@property (nonatomic, weak, nullable) id<UICalendarViewDelegate> delegate;
@property (nonatomic, strong, nullable) UICalendarSelection *selectionBehavior;
@property (nonatomic, copy) NSLocale *locale;
@property (nonatomic, copy) NSCalendar *calendar;
@property (nonatomic, copy, nullable) NSTimeZone *timeZone;
@property (nonatomic, copy) UIFontDescriptorSystemDesign fontDesign;
/* the days that can be selected and shown (others are dimmed); default: all */
@property (nonatomic, copy) NSDateInterval *availableDateRange;
/* the month shown (year and month; default: today's) */
@property (nonatomic, copy) NSDateComponents *visibleDateComponents;
- (void)setVisibleDateComponents:(NSDateComponents *)dateComponents animated:(BOOL)animated;
/* asks the delegate for decorations under the days (the rows grow to make room) */
@property (nonatomic) BOOL wantsDateDecorations;
- (void)reloadDecorationsForDateComponents:(NSArray<NSDateComponents *> *)dates animated:(BOOL)animated;
@end

typedef NS_ENUM(NSInteger, UICalendarViewDecorationSize) { UICalendarViewDecorationSizeSmall = 0, UICalendarViewDecorationSizeMedium,
    UICalendarViewDecorationSizeLarge } NS_SWIFT_NAME(UICalendarView.DecorationSize) API_AVAILABLE(ios(16.0));
/* a dot (default), an image, or a custom view under a day (Swift: .default(color:size:), .image(_:color:size:),
   .customView(_:), the UIKit overlay) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0)) NS_SWIFT_NAME(UICalendarView.Decoration)
@interface UICalendarViewDecoration : NSObject
- (instancetype)init;
+ (instancetype)decorationWithColor:(nullable UIColor *)color size:(UICalendarViewDecorationSize)size NS_SWIFT_NAME(__default(color:size:));
+ (instancetype)decorationWithImage:(nullable UIImage *)image NS_SWIFT_NAME(__image(_:));
+ (instancetype)decorationWithImage:(nullable UIImage *)image color:(nullable UIColor *)color size:(UICalendarViewDecorationSize)size NS_SWIFT_NAME(__image(_:color:size:));
+ (instancetype)decorationWithCustomViewProvider:(UIView *(^)(void))customViewProvider NS_SWIFT_NAME(customView(_:));
@end

/* how the calendar view selects days */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UICalendarSelection : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/* asks the delegate again which days can be selected */
- (void)updateSelectableDates;
@end

@class UICalendarSelectionSingleDate, UICalendarSelectionMultiDate, UICalendarSelectionWeekOfYear;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@protocol UICalendarSelectionSingleDateDelegate <NSObject>
- (void)dateSelection:(UICalendarSelectionSingleDate *)selection didSelectDate:(nullable NSDateComponents *)dateComponents;
@optional
- (BOOL)dateSelection:(UICalendarSelectionSingleDate *)selection canSelectDate:(nullable NSDateComponents *)dateComponents;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UICalendarSelectionSingleDate : UICalendarSelection
@property (nonatomic, weak, readonly, nullable) id<UICalendarSelectionSingleDateDelegate> delegate;
@property (nonatomic, copy, nullable) NSDateComponents *selectedDate;
- (void)setSelectedDate:(nullable NSDateComponents *)selectedDate animated:(BOOL)animated NS_SWIFT_NAME(setSelected(_:animated:));
- (instancetype)initWithDelegate:(nullable id<UICalendarSelectionSingleDateDelegate>)delegate NS_DESIGNATED_INITIALIZER;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@protocol UICalendarSelectionMultiDateDelegate <NSObject>
- (void)multiDateSelection:(UICalendarSelectionMultiDate *)selection didSelectDate:(NSDateComponents *)dateComponents;
- (void)multiDateSelection:(UICalendarSelectionMultiDate *)selection didDeselectDate:(NSDateComponents *)dateComponents;
@optional
- (BOOL)multiDateSelection:(UICalendarSelectionMultiDate *)selection canSelectDate:(NSDateComponents *)dateComponents;
- (BOOL)multiDateSelection:(UICalendarSelectionMultiDate *)selection canDeselectDate:(NSDateComponents *)dateComponents;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UICalendarSelectionMultiDate : UICalendarSelection
@property (nonatomic, weak, readonly, nullable) id<UICalendarSelectionMultiDateDelegate> delegate;
@property (nonatomic, copy) NSArray<NSDateComponents *> *selectedDates;
- (void)setSelectedDates:(NSArray<NSDateComponents *> *)selectedDates animated:(BOOL)animated;
- (instancetype)initWithDelegate:(nullable id<UICalendarSelectionMultiDateDelegate>)delegate NS_DESIGNATED_INITIALIZER;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@protocol UICalendarSelectionWeekOfYearDelegate <NSObject>
- (void)weekOfYearSelection:(UICalendarSelectionWeekOfYear *)selection didSelectWeekOfYear:(nullable NSDateComponents *)weekOfYearComponents;
@optional
- (BOOL)weekOfYearSelection:(UICalendarSelectionWeekOfYear *)selection canSelectWeekOfYear:(nullable NSDateComponents *)weekOfYearComponents;
@end
/* a tap selects the day's whole week (components: yearForWeekOfYear and weekOfYear) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0))
@interface UICalendarSelectionWeekOfYear : UICalendarSelection
@property (nonatomic, weak, readonly, nullable) id<UICalendarSelectionWeekOfYearDelegate> delegate;
@property (nonatomic, copy, nullable) NSDateComponents *selectedWeekOfYear;
- (void)setSelectedWeekOfYear:(nullable NSDateComponents *)selectedWeekOfYear animated:(BOOL)animated NS_SWIFT_NAME(setSelected(_:animated:));
- (instancetype)initWithDelegate:(nullable id<UICalendarSelectionWeekOfYearDelegate>)delegate NS_DESIGNATED_INITIALIZER;
@end
NS_ASSUME_NONNULL_END
