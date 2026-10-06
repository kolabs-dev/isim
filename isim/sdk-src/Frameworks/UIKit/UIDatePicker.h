#pragma once
/* isim: UIDatePicker — wheels, compact (pill buttons that open a calendar / time popover) and inline
   (month calendar) styles; Gregorian calendar in the device time zone; date/time text from NSDateFormatter. */
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class NSDate, NSLocale, NSTimeZone;

typedef NS_ENUM(NSInteger, UIDatePickerMode) {
    UIDatePickerModeTime, UIDatePickerModeDate, UIDatePickerModeDateAndTime, UIDatePickerModeCountDownTimer,
    UIDatePickerModeYearAndMonth API_AVAILABLE(ios(17.4))
} NS_SWIFT_NAME(UIDatePicker.Mode);
typedef NS_ENUM(NSInteger, UIDatePickerStyle) {
    UIDatePickerStyleAutomatic, UIDatePickerStyleWheels, UIDatePickerStyleCompact, UIDatePickerStyleInline
};

NS_SWIFT_UI_ACTOR
@interface UIDatePicker : UIControl
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic) UIDatePickerMode datePickerMode;
@property (nonatomic) UIDatePickerStyle preferredDatePickerStyle;
@property (nonatomic, readonly) UIDatePickerStyle datePickerStyle;
@property (null_resettable, nonatomic, strong) NSDate *date;
@property (nullable, nonatomic, strong) NSDate *minimumDate;
@property (nullable, nonatomic, strong) NSDate *maximumDate;
@property (nonatomic) NSTimeInterval countDownDuration;
@property (nonatomic) NSInteger minuteInterval;
@property (nonatomic) BOOL roundsToMinuteInterval;
@property (nullable, nonatomic, strong) NSLocale *locale;        /* isim: stored; the device locale formats the text */
@property (nullable, nonatomic, strong) NSTimeZone *timeZone;    /* isim: stored; the device time zone is used */
- (void)setDate:(NSDate *)date animated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
