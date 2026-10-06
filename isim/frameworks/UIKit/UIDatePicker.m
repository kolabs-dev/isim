/* UIDatePicker: wheels, compact and inline styles.
 *
 *  - wheels: an internal UIPickerView. Time: hour | minute | AM/PM (cyclic hours and minutes, minuteInterval);
 *    date: month | day | year (day | month | year when the locale writes the day first); date and time:
 *    day ("Today", "Tue Oct 7") | hour | minute | AM/PM; count-down timer: hours | minutes; year and month.
 *    Impossible days (Feb 30) and dates outside minimumDate/maximumDate spin back, like iOS.
 *  - compact (the iOS 14+ default): gray pills with the date and/or time; tapping a pill opens a popover with
 *    a month calendar (date) or time wheels (time). Picking a day closes the calendar popover.
 *  - inline: a month calendar (month header, previous/next month, weekday row, day grid) and, for
 *    .dateAndTime, a "Time" row with a time pill.
 * Dates are Gregorian in the device time zone (TZ); text comes from NSDateFormatter (device locale and
 * 12/24-hour setting). Value changes send .valueChanged. */
#import "UIKitPrivate.h"
#import <UIKit/UIPickerView.h>
#import <UIKit/UIDatePicker.h>
#include <math.h>
#include <time.h>

@interface UIPickerView (IsimWheels)
- (void)_isim_setCyclic:(BOOL)c forComponent:(NSInteger)k;
- (void)_isim_setAlignment:(NSTextAlignment)a forComponent:(NSInteger)k;
- (void)set_isim_onSelect:(void (^)(NSInteger row, NSInteger component))b;
- (void)set_isim_font:(UIFont *)f;
@end

static struct tm dp_tm(NSDate *d) { time_t t = (time_t)floor(d.timeIntervalSince1970); struct tm tm; localtime_r(&t, &tm); return tm; }
static NSDate *dp_date(struct tm tm) { tm.tm_isdst = -1; time_t t = mktime(&tm); return [NSDate dateWithTimeIntervalSince1970:(double)t]; }
static int dp_days_in(int year, int mon) {      /* mon 0-11, year since 1900 */
    static const int d[12] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    int y = year + 1900;
    return mon == 1 && ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0) ? 29 : d[mon];
}
static BOOL dp_same_day(struct tm a, struct tm b) { return a.tm_year == b.tm_year && a.tm_mon == b.tm_mon && a.tm_mday == b.tm_mday; }
static NSString *dp_format(NSDate *d, NSString *fmt) { NSDateFormatter *f = [NSDateFormatter new]; f.dateFormat = fmt; return [f stringFromDate:d] ?: @""; }
static NSString *dp_styled(NSDate *d, NSDateFormatterStyle ds, NSDateFormatterStyle ts) { NSDateFormatter *f = [NSDateFormatter new]; f.dateStyle = ds; f.timeStyle = ts; return [f stringFromDate:d] ?: @""; }
static BOOL dp_12h(void) {
    NSLocale *l = NSLocale.currentLocale;
    SEL s = NSSelectorFromString(@"_isim_uses12Hour");
    if ([l respondsToSelector:s]) return ((BOOL (*)(id, SEL))[l methodForSelector:s])(l, s);
    return YES;
}
static BOOL dp_day_first(void) {                /* "6.10.26" vs "10/6/26" */
    NSString *f = dp_styled([NSDate dateWithTimeIntervalSince1970:86400 * 300], NSDateFormatterShortStyle, NSDateFormatterNoStyle);
    return [f hasPrefix:@"2"] || [f hasPrefix:@"02"];   /* 28 Oct 1970 */
}
static NSArray<NSString *> *dp_month_names(BOOL abbreviated) {
    NSMutableArray *a = [NSMutableArray array];
    for (int m = 0; m < 12; m++) {
        struct tm tm = { 0 }; tm.tm_year = 120; tm.tm_mon = m; tm.tm_mday = 15; tm.tm_hour = 12;
        NSString *s = dp_format(dp_date(tm), abbreviated ? @"MMM" : @"MMMM");
        [a addObject:s.length ? s : @[@"January", @"February", @"March", @"April", @"May", @"June", @"July", @"August", @"September", @"October", @"November", @"December"][m]];
    }
    return a;
}
static UIColor *pill_bg(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return [UIColor colorWithRed:118 / 255.0 green:118 / 255.0 blue:128 / 255.0 alpha:t.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.24 : 0.12]; }];
}

/* ================= wheels (data source for the internal UIPickerView) ================= */
enum { COL_MONTH, COL_DAY, COL_YEAR, COL_HOUR, COL_MINUTE, COL_AMPM, COL_DATE, COL_CD_HOURS, COL_CD_MINUTES };
#define DATE_SPAN 1000     /* .dateAndTime day wheel: days either side of its base day */
#define YEAR_MIN 1900
#define YEAR_MAX 2100

@interface __IsimDateWheels : NSObject <UIPickerViewDataSource, UIPickerViewDelegate>
@property (nonatomic, strong) NSArray<NSNumber *> *columns;
@property (nonatomic) NSInteger minuteInterval;
@property (nonatomic) BOOL twelveHour;
@property (nonatomic) struct tm base;          /* .dateAndTime: day of row DATE_SPAN */
@property (nonatomic, strong) NSArray<NSString *> *months;
@end
@implementation __IsimDateWheels
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)p { return (NSInteger)_columns.count; }
- (NSInteger)pickerView:(UIPickerView *)p numberOfRowsInComponent:(NSInteger)k {
    switch (_columns[(NSUInteger)k].intValue) {
    case COL_MONTH: return 12;
    case COL_DAY: return 31;
    case COL_YEAR: return YEAR_MAX - YEAR_MIN + 1;
    case COL_HOUR: return _twelveHour ? 12 : 24;
    case COL_MINUTE: return 60 / MAX(1, _minuteInterval);
    case COL_AMPM: return 2;
    case COL_DATE: return 2 * DATE_SPAN + 1;
    case COL_CD_HOURS: return 24;
    case COL_CD_MINUTES: return 60 / MAX(1, _minuteInterval);
    }
    return 0;
}
- (CGFloat)pickerView:(UIPickerView *)p widthForComponent:(NSInteger)k {
    switch (_columns[(NSUInteger)k].intValue) {
    case COL_MONTH: return 140; case COL_DAY: return 56; case COL_YEAR: return 84;
    case COL_DATE: return 136; case COL_HOUR: case COL_MINUTE: return 56; case COL_AMPM: return 60;
    case COL_CD_HOURS: case COL_CD_MINUTES: return 136;
    }
    return 60;
}
- (NSString *)pickerView:(UIPickerView *)p titleForRow:(NSInteger)row forComponent:(NSInteger)k {
    switch (_columns[(NSUInteger)k].intValue) {
    case COL_MONTH: return _months[(NSUInteger)row];
    case COL_DAY: return [NSString stringWithFormat:@"%ld", (long)row + 1];
    case COL_YEAR: return [NSString stringWithFormat:@"%ld", (long)row + YEAR_MIN];
    case COL_HOUR: return _twelveHour ? [NSString stringWithFormat:@"%ld", (long)row + 1] : [NSString stringWithFormat:@"%02ld", (long)row];
    case COL_MINUTE: return [NSString stringWithFormat:@"%02ld", (long)(row * MAX(1, _minuteInterval))];
    case COL_AMPM: return row ? @"PM" : @"AM";
    case COL_DATE: {
        struct tm t = _base; t.tm_mday += (int)(row - DATE_SPAN); t.tm_hour = 12;
        NSDate *d = dp_date(t);
        struct tm now = dp_tm([NSDate date]), dt = dp_tm(d);
        if (dp_same_day(now, dt)) return @"Today";
        return dp_format(d, @"EEE MMM d");
    }
    case COL_CD_HOURS: return row == 1 ? @"1 hour" : [NSString stringWithFormat:@"%ld hours", (long)row];
    case COL_CD_MINUTES: return [NSString stringWithFormat:@"%ld min", (long)(row * MAX(1, _minuteInterval))];
    }
    return @"";
}
@end

/* ================= calendar (inline style, compact popover) ================= */
@interface __IsimDayCell : UIButton
@property (nonatomic) int day;
@property (nonatomic) BOOL chosen, today;
@end
@implementation __IsimDayCell
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double d = fmin(40, fmin(s.width, s.height) - 2);
    if (_chosen) { double c[4]; isim_ui_rgba(self.tintColor, c); c[3] *= 0.15; isim_gfx_fill_ellipse((s.width - d) / 2, (s.height - d) / 2, d, d, c); }
    UIFont *f = [UIFont systemFontOfSize:20 weight:_chosen ? UIFontWeightSemibold : UIFontWeightRegular];
    UIColor *col = !self.enabled ? UIColor.tertiaryLabelColor : (_chosen || _today) ? self.tintColor : UIColor.labelColor;
    NSString *t = [NSString stringWithFormat:@"%d", _day];
    CGSize ts = isim_ui_measure(t, f, 0, 1);
    isim_ui_draw_text(t, f, col, CGRectMake(0, (s.height - ts.height) / 2, s.width, ts.height), NSTextAlignmentCenter, 1, self.highlighted ? 0.5 : 1);
}
- (NSString *)currentTitle { return [NSString stringWithFormat:@"%d", _day]; }
@end

@interface __IsimCalendarView : UIView
@property (nonatomic, strong) NSDate *date, *minimumDate, *maximumDate;
@property (nonatomic, copy) void (^onPick)(NSDate *day);
- (void)showMonthOf:(NSDate *)d;
@end
@implementation __IsimCalendarView { int _year, _month; UILabel *_title; UIButton *_prev, *_next; NSMutableArray<UILabel *> *_weekdays; NSMutableArray<__IsimDayCell *> *_cells; UIImageView *_chev; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; [self addSubview:_title];
        _chev = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold]]];
        [self addSubview:_chev];
        _prev = [UIButton buttonWithType:UIButtonTypeSystem]; [_prev setImage:[UIImage systemImageNamed:@"chevron.left" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
        _next = [UIButton buttonWithType:UIButtonTypeSystem]; [_next setImage:[UIImage systemImageNamed:@"chevron.right" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
        _prev.accessibilityLabel = @"Previous Month"; _next.accessibilityLabel = @"Next Month";
        _prev.accessibilityIdentifier = @"isim-calendar-prev"; _next.accessibilityIdentifier = @"isim-calendar-next";
        [_prev addTarget:self action:@selector(_isim_prev) forControlEvents:UIControlEventTouchUpInside];
        [_next addTarget:self action:@selector(_isim_next) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_prev]; [self addSubview:_next];
        _weekdays = [NSMutableArray array]; _cells = [NSMutableArray array];
        for (int i = 0; i < 7; i++) {
            UILabel *l = [UILabel new]; l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; l.textColor = UIColor.tertiaryLabelColor;
            l.textAlignment = NSTextAlignmentCenter; [self addSubview:l]; [_weekdays addObject:l];
        }
        for (int i = 0; i < 31; i++) {
            __IsimDayCell *c = [__IsimDayCell new]; c.day = i + 1;
            [c addTarget:self action:@selector(_isim_tapDay:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:c]; [_cells addObject:c];
        }
        _date = [NSDate date];
        [self showMonthOf:_date];
    }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(343, 330); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 && s.width < 1e5 ? s.width : 343, 330); }
- (void)showMonthOf:(NSDate *)d { struct tm t = dp_tm(d); _year = t.tm_year; _month = t.tm_mon; [self _isim_refresh]; }
- (void)setDate:(NSDate *)d { _date = d; [self _isim_refresh]; }
- (void)_isim_prev { if (--_month < 0) { _month = 11; _year--; } [self _isim_refresh]; NSLog(@"isim: calendar shows %d-%02d", _year + 1900, _month + 1); }
- (void)_isim_next { if (++_month > 11) { _month = 0; _year++; } [self _isim_refresh]; NSLog(@"isim: calendar shows %d-%02d", _year + 1900, _month + 1); }
- (void)_isim_refresh {
    struct tm first = { 0 }; first.tm_year = _year; first.tm_mon = _month; first.tm_mday = 1; first.tm_hour = 12;
    NSDate *fd = dp_date(first);
    _title.text = dp_format(fd, @"MMMM yyyy");
    struct tm sel = dp_tm(_date ?: [NSDate date]), now = dp_tm([NSDate date]);
    int days = dp_days_in(_year, _month);
    NSDate *mn = _minimumDate, *mx = _maximumDate;
    for (int i = 0; i < 31; i++) {
        __IsimDayCell *c = _cells[(NSUInteger)i];
        c.hidden = i >= days;
        struct tm t = first; t.tm_mday = i + 1;
        c.chosen = dp_same_day(t, sel); c.today = dp_same_day(t, now);
        struct tm dayStart = t; dayStart.tm_hour = 0; struct tm dayEnd = t; dayEnd.tm_hour = 23; dayEnd.tm_min = 59;
        c.enabled = !(mn && [dp_date(dayEnd) compare:mn] == NSOrderedAscending) && !(mx && [dp_date(dayStart) compare:mx] == NSOrderedDescending);
        [c setNeedsDisplay];
    }
    NSArray *wd = @[@"SUN", @"MON", @"TUE", @"WED", @"THU", @"FRI", @"SAT"];
    for (int i = 0; i < 7; i++) {
        struct tm t = { 0 }; t.tm_year = 120; t.tm_mon = 0; t.tm_mday = 5 + i; t.tm_hour = 12;   /* Jan 5 2020 is a Sunday */
        NSString *s = dp_format(dp_date(t), @"EEE").uppercaseString;
        _weekdays[(NSUInteger)i].text = s.length ? s : wd[(NSUInteger)i];
    }
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, m = 10, cw = (W - 2 * m) / 7, rowH = 44, top = 76;
    CGSize ts = [_title sizeThatFits:CGSizeMake(W, 44)];
    _title.frame = CGRectMake(16, 10, ceil(ts.width), 24);
    CGSize cs = _chev.image.size;
    _chev.tintColor = self.tintColor;
    _chev.frame = CGRectMake(CGRectGetMaxX(_title.frame) + 6, 22 - cs.height / 2, cs.width, cs.height);
    _prev.frame = CGRectMake(W - 92, 0, 44, 44); _next.frame = CGRectMake(W - 48, 0, 44, 44);
    for (int i = 0; i < 7; i++) _weekdays[(NSUInteger)i].frame = CGRectMake(m + i * cw, 50, cw, 18);
    struct tm first = { 0 }; first.tm_year = _year; first.tm_mon = _month; first.tm_mday = 1; first.tm_hour = 12;
    struct tm f2 = dp_tm(dp_date(first));
    int col0 = f2.tm_wday;
    for (int i = 0; i < 31; i++) {
        int idx = col0 + i, r = idx / 7, c = idx % 7;
        _cells[(NSUInteger)i].frame = CGRectMake(m + c * cw, top + r * rowH, cw, rowH);
    }
}
- (void)_isim_tapDay:(__IsimDayCell *)c {
    struct tm t = dp_tm(_date ?: [NSDate date]);
    t.tm_year = _year; t.tm_mon = _month; t.tm_mday = c.day;
    _date = dp_date(t);
    [self _isim_refresh];
    if (self.onPick) self.onPick(_date);
}
@end

/* ================= pills (compact style) ================= */
@interface __IsimDatePill : UIButton
@property (nonatomic, copy) NSString *text;
@property (nonatomic) BOOL open;
@end
@implementation __IsimDatePill
- (CGSize)intrinsicContentSize { return CGSizeMake(ceil(isim_ui_measure(_text ?: @"", [UIFont systemFontOfSize:17], 0, 1).width) + 22, 34); }
- (CGSize)sizeThatFits:(CGSize)s { return [self intrinsicContentSize]; }
- (void)setText:(NSString *)t { _text = [t copy]; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setOpen:(BOOL)o { _open = o; isim_ui_set_needs_display(); }
- (NSString *)currentTitle { return _text; }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double c[4]; isim_ui_rgba(pill_bg(), c);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, 6, c);
    UIFont *f = [UIFont systemFontOfSize:17];
    CGSize ts = isim_ui_measure(_text ?: @"", f, 0, 1);
    isim_ui_draw_text(_text ?: @"", f, _open ? self.tintColor : UIColor.labelColor, CGRectMake(0, (s.height - ts.height) / 2, s.width, ts.height), NSTextAlignmentCenter, 1, self.highlighted ? 0.6 : 1);
}
@end

/* a popover card anchored to a pill; taps outside close it */
@interface __IsimDatePopover : UIView
@property (nonatomic, strong) UIView *card;
@property (nonatomic, copy) void (^onClose)(void);
- (void)close;
@end
@implementation __IsimDatePopover
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self close]; }
- (void)close {
    if (!self.superview || !self.userInteractionEnabled) return;
    self.userInteractionEnabled = NO;
    UIView *card = self.card;
    if (self.onClose) self.onClose();
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{ card.alpha = 0; card.transform = CGAffineTransformMakeScale(0.9, 0.9); }
                     completion:^(BOOL f) { [self removeFromSuperview]; }];
}
@end

/* ================= UIDatePicker ================= */
@implementation UIDatePicker {
    UIPickerView *_wheels; __IsimDateWheels *_ds;
    __IsimCalendarView *_calendar; UILabel *_timeLabel;
    __IsimDatePill *_datePill, *_timePill;
    __weak __IsimDatePopover *_popover;
    __weak UIDatePicker *_popoverPicker;
    BOOL _building;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _date = [NSDate date]; _datePickerMode = UIDatePickerModeDateAndTime; _minuteInterval = 1; _countDownDuration = 0;
        [self _isim_rebuild];
    }
    return self;
}
- (UIDatePickerStyle)datePickerStyle {
    if (_datePickerMode == UIDatePickerModeCountDownTimer || _datePickerMode == UIDatePickerModeYearAndMonth) return UIDatePickerStyleWheels;
    if (_preferredDatePickerStyle == UIDatePickerStyleAutomatic) return UIDatePickerStyleCompact;
    if (_preferredDatePickerStyle == UIDatePickerStyleInline && _datePickerMode == UIDatePickerModeTime) return UIDatePickerStyleCompact;
    return _preferredDatePickerStyle;
}
- (void)setDatePickerMode:(UIDatePickerMode)m { _datePickerMode = m; [self _isim_rebuild]; }
- (void)setPreferredDatePickerStyle:(UIDatePickerStyle)s { _preferredDatePickerStyle = s; [self _isim_rebuild]; }
- (void)setMinuteInterval:(NSInteger)i { _minuteInterval = (i >= 1 && i <= 30 && 60 % i == 0) ? i : 1; [self _isim_rebuild]; }
- (void)setMinimumDate:(NSDate *)d { _minimumDate = d; _calendar.minimumDate = d; [self _isim_sync:NO]; }
- (void)setMaximumDate:(NSDate *)d { _maximumDate = d; _calendar.maximumDate = d; [self _isim_sync:NO]; }
- (void)setDate:(NSDate *)d { [self setDate:d animated:NO]; }
- (void)setDate:(NSDate *)d animated:(BOOL)a { _date = d ?: [NSDate date]; [self _isim_sync:a]; }
- (void)setCountDownDuration:(NSTimeInterval)t { _countDownDuration = fmax(0, fmin(t, 23 * 3600 + 59 * 60)); [self _isim_sync:NO]; }
- (NSString *)_isim_dumpText {
    if (_datePickerMode == UIDatePickerModeCountDownTimer) return [NSString stringWithFormat:@"countdown %g", _countDownDuration];
    return [NSString stringWithFormat:@"%@ (%@)", dp_format(_date, @"yyyy-MM-dd HH:mm"), @[@"automatic", @"wheels", @"compact", @"inline"][self.datePickerStyle]];
}

/* ---- structure ---- */
- (void)_isim_rebuild {
    _building = YES;
    [_wheels removeFromSuperview]; _wheels = nil; _ds = nil;
    [_calendar removeFromSuperview]; _calendar = nil;
    [_timeLabel removeFromSuperview]; _timeLabel = nil;
    [_datePill removeFromSuperview]; _datePill = nil;
    [_timePill removeFromSuperview]; _timePill = nil;
    UIDatePickerStyle st = self.datePickerStyle;
    UIDatePickerMode m = _datePickerMode;
    __weak UIDatePicker *ws = self;
    if (st == UIDatePickerStyleWheels) {
        _wheels = [self _isim_makeWheelsFor:m];
        [self addSubview:_wheels];
    } else if (st == UIDatePickerStyleInline) {
        _calendar = [__IsimCalendarView new];
        _calendar.minimumDate = _minimumDate; _calendar.maximumDate = _maximumDate;
        _calendar.onPick = ^(NSDate *d) { [ws _isim_pickedDay:d]; };
        [self addSubview:_calendar];
        if (m == UIDatePickerModeDateAndTime) {
            _timeLabel = [UILabel new]; _timeLabel.text = @"Time"; _timeLabel.font = [UIFont systemFontOfSize:17]; [self addSubview:_timeLabel];
            _timePill = [self _isim_pill:NO];
        }
    } else {
        if (m != UIDatePickerModeTime) _datePill = [self _isim_pill:YES];
        if (m != UIDatePickerModeDate) _timePill = [self _isim_pill:NO];
    }
    _building = NO;
    [self _isim_sync:NO];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}
- (__IsimDatePill *)_isim_pill:(BOOL)date {
    __IsimDatePill *p = [__IsimDatePill new];
    p.accessibilityIdentifier = date ? @"isim-datepicker-date" : @"isim-datepicker-time";
    [p addTarget:self action:date ? @selector(_isim_openDate:) : @selector(_isim_openTime:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:p];
    return p;
}
- (UIPickerView *)_isim_makeWheelsFor:(UIDatePickerMode)m {
    UIPickerView *pv = [UIPickerView new];
    __IsimDateWheels *ds = [__IsimDateWheels new];
    ds.minuteInterval = _minuteInterval; ds.twelveHour = dp_12h(); ds.months = dp_month_names(NO);
    NSMutableArray *cols = [NSMutableArray array];
    switch (m) {
    case UIDatePickerModeTime: [cols addObjectsFromArray:@[@(COL_HOUR), @(COL_MINUTE)]]; if (ds.twelveHour) [cols addObject:@(COL_AMPM)]; break;
    case UIDatePickerModeDate: [cols addObjectsFromArray:dp_day_first() ? @[@(COL_DAY), @(COL_MONTH), @(COL_YEAR)] : @[@(COL_MONTH), @(COL_DAY), @(COL_YEAR)]]; break;
    case UIDatePickerModeDateAndTime: [cols addObjectsFromArray:@[@(COL_DATE), @(COL_HOUR), @(COL_MINUTE)]]; if (ds.twelveHour) [cols addObject:@(COL_AMPM)]; break;
    case UIDatePickerModeCountDownTimer: [cols addObjectsFromArray:@[@(COL_CD_HOURS), @(COL_CD_MINUTES)]]; break;
    case UIDatePickerModeYearAndMonth: [cols addObjectsFromArray:@[@(COL_MONTH), @(COL_YEAR)]]; break;
    }
    ds.columns = cols;
    struct tm b = dp_tm(_date); b.tm_hour = 12; b.tm_min = 0; b.tm_sec = 0; ds.base = b;
    for (NSUInteger k = 0; k < cols.count; k++) {
        int c = [cols[k] intValue];
        if (c == COL_MONTH || c == COL_DAY || c == COL_HOUR || c == COL_MINUTE || c == COL_CD_MINUTES) [pv _isim_setCyclic:YES forComponent:(NSInteger)k];
        if (c == COL_HOUR) [pv _isim_setAlignment:NSTextAlignmentRight forComponent:(NSInteger)k];
        if (c == COL_MINUTE || c == COL_AMPM) [pv _isim_setAlignment:NSTextAlignmentLeft forComponent:(NSInteger)k];
        if (c == COL_MONTH || c == COL_DATE) [pv _isim_setAlignment:c == COL_DATE ? NSTextAlignmentRight : NSTextAlignmentLeft forComponent:(NSInteger)k];
    }
    pv.dataSource = ds; pv.delegate = ds;
    _ds = ds;
    __weak UIDatePicker *ws = self; __weak UIPickerView *wp = pv;
    [pv set_isim_onSelect:^(NSInteger row, NSInteger comp) { [ws _isim_wheelsChanged:wp]; }];
    objc_setAssociatedObject(pv, "isim.ds", ds, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return pv;
}

/* model -> views */
- (void)_isim_sync:(BOOL)animated {
    if (_building) return;
    if (_datePickerMode != UIDatePickerModeCountDownTimer) {
        NSDate *c = [self _isim_clamped:_date];
        if (c != _date) _date = c;
    }
    if (_wheels) [self _isim_setWheels:_wheels from:_date animated:animated];
    _calendar.date = _date;
    if (_calendar && !animated) [_calendar showMonthOf:_date];
    _datePill.text = dp_styled(_date, NSDateFormatterMediumStyle, NSDateFormatterNoStyle);
    _timePill.text = dp_styled(_date, NSDateFormatterNoStyle, NSDateFormatterShortStyle);
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (NSDate *)_isim_clamped:(NSDate *)d {
    if (_minimumDate && [d compare:_minimumDate] == NSOrderedAscending) return _minimumDate;
    if (_maximumDate && [d compare:_maximumDate] == NSOrderedDescending) return _maximumDate;
    return d;
}
- (void)_isim_setWheels:(UIPickerView *)pv from:(NSDate *)date animated:(BOOL)a {
    __IsimDateWheels *ds = objc_getAssociatedObject(pv, "isim.ds");
    struct tm t = dp_tm(date);
    for (NSUInteger k = 0; k < ds.columns.count; k++) {
        NSInteger row = 0;
        switch (ds.columns[k].intValue) {
        case COL_MONTH: row = t.tm_mon; break;
        case COL_DAY: row = t.tm_mday - 1; break;
        case COL_YEAR: row = MAX(0, MIN(YEAR_MAX - YEAR_MIN, t.tm_year + 1900 - YEAR_MIN)); break;
        case COL_HOUR: row = ds.twelveHour ? (t.tm_hour % 12 == 0 ? 11 : t.tm_hour % 12 - 1) : t.tm_hour; break;
        case COL_MINUTE: row = t.tm_min / MAX(1, ds.minuteInterval); break;
        case COL_AMPM: row = t.tm_hour >= 12; break;
        case COL_DATE: {
            struct tm b = ds.base, d = t; d.tm_hour = 12; d.tm_min = 0; d.tm_sec = 0;
            row = DATE_SPAN + (NSInteger)llround(([dp_date(d) timeIntervalSince1970] - [dp_date(b) timeIntervalSince1970]) / 86400.0);
            row = MAX(0, MIN(2 * DATE_SPAN, row));
            break;
        }
        case COL_CD_HOURS: row = (NSInteger)(_countDownDuration / 3600); break;
        case COL_CD_MINUTES: row = ((NSInteger)(_countDownDuration / 60) % 60) / MAX(1, ds.minuteInterval); break;
        }
        if ([pv selectedRowInComponent:(NSInteger)k] != row) [pv selectRow:row inComponent:(NSInteger)k animated:a];
    }
}
/* wheels -> model */
- (void)_isim_wheelsChanged:(UIPickerView *)pv {
    __IsimDateWheels *ds = objc_getAssociatedObject(pv, "isim.ds");
    if (_datePickerMode == UIDatePickerModeCountDownTimer && pv == _wheels) {
        NSInteger h = 0, mi = 0;
        for (NSUInteger k = 0; k < ds.columns.count; k++) {
            NSInteger row = [pv selectedRowInComponent:(NSInteger)k];
            if (ds.columns[k].intValue == COL_CD_HOURS) h = row; else mi = row * MAX(1, ds.minuteInterval);
        }
        NSTimeInterval v = h * 3600 + mi * 60;
        if (v < 60) { v = 60 * MAX(1, ds.minuteInterval); [pv selectRow:1 inComponent:1 animated:YES]; }    /* 0 h 0 min is not allowed */
        _countDownDuration = v;
        NSLog(@"isim: date picker countdown %g", v);
        [self sendActionsForControlEvents:UIControlEventValueChanged];
        return;
    }
    struct tm t = dp_tm(_date);
    int hour12 = -1, pm = t.tm_hour >= 12;
    for (NSUInteger k = 0; k < ds.columns.count; k++) {
        NSInteger row = [pv selectedRowInComponent:(NSInteger)k];
        switch (ds.columns[k].intValue) {
        case COL_MONTH: t.tm_mon = (int)row; break;
        case COL_DAY: t.tm_mday = (int)row + 1; break;
        case COL_YEAR: t.tm_year = (int)row + YEAR_MIN - 1900; break;
        case COL_HOUR: if (ds.twelveHour) hour12 = (int)row + 1; else t.tm_hour = (int)row; break;
        case COL_MINUTE: t.tm_min = (int)(row * MAX(1, ds.minuteInterval)); break;
        case COL_AMPM: pm = row == 1; break;
        case COL_DATE: { struct tm b = ds.base; b.tm_mday += (int)(row - DATE_SPAN); struct tm d = dp_tm(dp_date(b)); t.tm_year = d.tm_year; t.tm_mon = d.tm_mon; t.tm_mday = d.tm_mday; break; }
        }
    }
    if (hour12 > 0) t.tm_hour = (hour12 % 12) + (pm ? 12 : 0);
    else if ([ds.columns containsObject:@(COL_AMPM)]) t.tm_hour = t.tm_hour % 12 + (pm ? 12 : 0);
    BOOL fix = NO;
    int dim = dp_days_in(t.tm_year, t.tm_mon);
    if (t.tm_mday > dim) { t.tm_mday = dim; fix = YES; }             /* Feb 30 -> Feb 28/29: the day wheel spins back */
    NSDate *d = dp_date(t), *c = [self _isim_clamped:d];
    if (c != d) fix = YES;
    _date = c;
    if (fix) [self _isim_setWheels:pv from:_date animated:YES];
    [self _isim_changed];
}
- (void)_isim_changed {
    _calendar.date = _date;
    _datePill.text = dp_styled(_date, NSDateFormatterMediumStyle, NSDateFormatterNoStyle);
    _timePill.text = dp_styled(_date, NSDateFormatterNoStyle, NSDateFormatterShortStyle);
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    NSLog(@"isim: date picker value %@", dp_format(_date, @"yyyy-MM-dd HH:mm"));
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (void)_isim_pickedDay:(NSDate *)d {
    struct tm keep = dp_tm(_date), day = dp_tm(d);
    keep.tm_year = day.tm_year; keep.tm_mon = day.tm_mon; keep.tm_mday = day.tm_mday;
    _date = [self _isim_clamped:dp_date(keep)];
    [self _isim_changed];
}

/* ---- compact popovers ---- */
- (void)_isim_openDate:(__IsimDatePill *)pill {
    __IsimCalendarView *cal = [__IsimCalendarView new];
    cal.minimumDate = _minimumDate; cal.maximumDate = _maximumDate; cal.date = _date; [cal showMonthOf:_date];
    __weak UIDatePicker *ws = self;
    __IsimDatePopover *pop = [self _isim_popover:cal size:CGSizeMake(MIN(360, self.window.bounds.size.width - 32), 340) from:pill];
    __weak __IsimDatePopover *wpop = pop;
    cal.onPick = ^(NSDate *day) {
        [ws _isim_pickedDay:day];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [wpop close]; });
    };
}
- (void)_isim_openTime:(__IsimDatePill *)pill {
    UIPickerView *pv = [self _isim_makeWheelsFor:UIDatePickerModeTime];
    [self _isim_setWheels:pv from:_date animated:NO];
    __weak UIDatePicker *ws = self; __weak UIPickerView *wp = pv;
    [pv set_isim_onSelect:^(NSInteger row, NSInteger comp) { [ws _isim_wheelsChanged:wp]; }];
    [self _isim_popover:pv size:CGSizeMake(MIN(300, self.window.bounds.size.width - 32), 216) from:pill];
}
- (__IsimDatePopover *)_isim_popover:(UIView *)content size:(CGSize)size from:(__IsimDatePill *)pill {
    UIWindow *w = self.window;
    if (!w) return nil;
    [_popover removeFromSuperview];
    __IsimDatePopover *o = [[__IsimDatePopover alloc] initWithFrame:w.bounds];
    o.accessibilityIdentifier = @"isim-datepicker-popover";
    o.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:1] : UIColor.whiteColor; }];
    card.layer.cornerRadius = 13;
    card.layer.shadowColor = UIColor.blackColor.CGColor; card.layer.shadowOpacity = 0.1; card.layer.shadowRadius = 12; card.layer.shadowOffset = CGSizeMake(0, 4);
    card.tintColor = self.tintColor;
    content.frame = CGRectMake(0, 4, size.width, size.height);
    [card addSubview:content];
    o.card = card;
    [o addSubview:card];
    [w addSubview:o];
    CGRect a = [pill convertRect:pill.bounds toView:w];
    const struct isim_device *d = isim_ui_device();
    CGFloat H = size.height + 8, x = fmin(fmax(16, CGRectGetMidX(a) - size.width / 2), w.bounds.size.width - size.width - 16);
    CGFloat y = CGRectGetMaxY(a) + 8;
    if (y + H > w.bounds.size.height - d->safe_bottom - 8) y = fmax(d->safe_top + 8, a.origin.y - 8 - H);
    card.frame = CGRectMake(x, y, size.width, H);
    pill.open = YES;
    __weak __IsimDatePill *wpill = pill;
    o.onClose = ^{ wpill.open = NO; };
    _popover = o;
    [UIView performWithoutAnimation:^{ card.alpha = 0; card.transform = CGAffineTransformMakeScale(0.85, 0.85); }];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:0 animations:^{ card.alpha = 1; card.transform = CGAffineTransformIdentity; } completion:nil];
    NSLog(@"isim: date picker popover opened");
    return o;
}

/* ---- layout ---- */
- (CGSize)intrinsicContentSize {
    switch (self.datePickerStyle) {
    case UIDatePickerStyleWheels: return CGSizeMake(320, 216);
    case UIDatePickerStyleInline: return CGSizeMake(343, 330 + (_timePill ? 52 : 0));
    default: {
        CGFloat w = 0;
        if (_datePill) w += _datePill.intrinsicContentSize.width;
        if (_timePill) w += (w > 0 ? 8 : 0) + _timePill.intrinsicContentSize.width;
        return CGSizeMake(w, 34);
    }
    }
}
- (CGSize)sizeThatFits:(CGSize)s { return [self intrinsicContentSize]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize b = self.bounds.size;
    _wheels.frame = self.bounds;
    if (_calendar) {
        _calendar.frame = CGRectMake(0, 0, b.width, 330);
        _timeLabel.frame = CGRectMake(16, 330 + 9, 120, 34);
        if (_timePill) { CGSize ps = _timePill.intrinsicContentSize; _timePill.frame = CGRectMake(b.width - 16 - ps.width, 330 + 9, ps.width, 34); }
        return;
    }
    /* compact: pills trailing-aligned, vertically centered */
    CGFloat x = b.width, y = floor((b.height - 34) / 2);
    if (_timePill) { CGSize ps = _timePill.intrinsicContentSize; x -= ps.width; _timePill.frame = CGRectMake(x, y, ps.width, 34); x -= 8; }
    if (_datePill) { CGSize ps = _datePill.intrinsicContentSize; x -= ps.width; _datePill.frame = CGRectMake(x, y, ps.width, 34); }
}
@end
