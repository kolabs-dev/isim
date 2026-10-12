/* UICalendarView (iOS 16): the month title with previous / next month buttons, the weekday row and a six-week day
 * grid, as the inline date picker draws it; decorations (a dot, an image or a custom view) under the days; selection
 * behaviours for one date, several dates or a week of the year. Days outside availableDateRange, or that the
 * selection's delegate refuses, are dimmed and do nothing. Tapping the title (Apple: month / year wheels) is not
 * implemented. Dates are Gregorian (isim's Objective-C NSCalendar has no date arithmetic), in the calendar's time zone,
 * with its first weekday and minimum days in the first week. */
#import "UIKitPrivate.h"
#import <UIKit/UICalendarView.h>
#include <time.h>

/* ---- Gregorian arithmetic ---- */
static BOOL leap(NSInteger y) { return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0; }
static NSInteger days_in(NSInteger y, NSInteger m) { static const int d[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }; return m == 2 && leap(y) ? 29 : d[(m - 1) % 12]; }
static time_t utc_noon(NSInteger y, NSInteger m, NSInteger d) { struct tm t = { 0 }; t.tm_year = (int)y - 1900; t.tm_mon = (int)m - 1; t.tm_mday = (int)d; t.tm_hour = 12; return timegm(&t); }
static NSInteger weekday_of(NSInteger y, NSInteger m, NSInteger d) { time_t t = utc_noon(y, m, d); struct tm g; gmtime_r(&t, &g); return g.tm_wday + 1; }   /* 1 = Sunday */
static NSInteger day_of_year(NSInteger y, NSInteger m, NSInteger d) { NSInteger n = d - 1; for (NSInteger k = 1; k < m; k++) n += days_in(y, k); return n; }
static NSTimeZone *zone_of(NSCalendar *cal) { return cal.timeZone ?: NSTimeZone.localTimeZone; }
/* the start of the day in the calendar's time zone */
static NSDate *day_start(NSCalendar *cal, NSInteger y, NSInteger m, NSInteger d) {
    double t = (double)utc_noon(y, m, d) - 12 * 3600;
    return [NSDate dateWithTimeIntervalSince1970:t - [zone_of(cal) secondsFromGMTForDate:[NSDate dateWithTimeIntervalSince1970:t]]];
}
static void ymd_of(NSCalendar *cal, NSDate *date, NSInteger *y, NSInteger *m, NSInteger *d) {
    time_t t = (time_t)floor(date.timeIntervalSince1970 + [zone_of(cal) secondsFromGMTForDate:date]); struct tm g; gmtime_r(&t, &g);
    *y = g.tm_year + 1900; *m = g.tm_mon + 1; *d = g.tm_mday;
}
/* the week of the year (with its year), by the calendar's first weekday and minimum days in the first week */
static NSInteger week1_start(NSCalendar *cal, NSInteger y) {        /* the day of the year week 1 starts on (may be negative) */
    NSInteger off = (weekday_of(y, 1, 1) - (NSInteger)cal.firstWeekday + 7) % 7, minDays = MAX(1, (NSInteger)cal.minimumDaysInFirstWeek);
    return 7 - off >= minDays ? -off : 7 - off;
}
static void week_of(NSCalendar *cal, NSInteger y, NSInteger m, NSInteger d, NSInteger *week, NSInteger *weekYear) {
    NSInteger doy = day_of_year(y, m, d), s = week1_start(cal, y), next = (leap(y) ? 366 : 365) + week1_start(cal, y + 1);
    if (doy >= next) { *week = 1; *weekYear = y + 1; return; }
    if (doy < s) { week_of(cal, y - 1, 12, 31, week, weekYear); return; }
    *week = (doy - s) / 7 + 1; *weekYear = y;
}

@interface UICalendarView ()
- (void)_isim_selectionChanged;
- (void)_isim_reloadAll;
@end
@interface UICalendarSelection ()
@property (nonatomic, weak) UICalendarView *_isim_view;
- (instancetype)initForIsim NS_DESIGNATED_INITIALIZER;
- (BOOL)_isim_canSelect:(NSDateComponents *)day;
- (BOOL)_isim_isSelected:(NSDateComponents *)day;
- (void)_isim_tapped:(NSDateComponents *)day;
@end

/* ================= decorations ================= */
@implementation UICalendarViewDecoration {
@public
    UIImage *_image; UIColor *_color; UICalendarViewDecorationSize _size; UIView *(^_provider)(void);
}
- (instancetype)init { if ((self = [super init])) _size = UICalendarViewDecorationSizeMedium; return self; }
+ (instancetype)decorationWithColor:(UIColor *)color size:(UICalendarViewDecorationSize)size { UICalendarViewDecoration *d = [self new]; d->_color = color; d->_size = size; return d; }
+ (instancetype)decorationWithImage:(UIImage *)image { return [self decorationWithImage:image color:nil size:UICalendarViewDecorationSizeMedium]; }
+ (instancetype)decorationWithImage:(UIImage *)image color:(UIColor *)color size:(UICalendarViewDecorationSize)size {
    UICalendarViewDecoration *d = [self new]; d->_image = image; d->_color = color; d->_size = size; return d;
}
+ (instancetype)decorationWithCustomViewProvider:(UIView *(^)(void))provider { UICalendarViewDecoration *d = [self new]; d->_provider = [provider copy]; return d; }
@end

/* ================= selections ================= */
static BOOL same_day(NSDateComponents *a, NSDateComponents *b) {
    return a && b && a.year == b.year && a.month == b.month && a.day == b.day;
}
@implementation UICalendarSelection
- (instancetype)initForIsim { return [super init]; }
- (void)updateSelectableDates { [self._isim_view _isim_reloadAll]; }
- (BOOL)_isim_canSelect:(NSDateComponents *)day { return YES; }
- (BOOL)_isim_isSelected:(NSDateComponents *)day { return NO; }
- (void)_isim_tapped:(NSDateComponents *)day {}
@end

@implementation UICalendarSelectionSingleDate
- (instancetype)initWithDelegate:(id<UICalendarSelectionSingleDateDelegate>)delegate { if ((self = [super initForIsim])) _delegate = delegate; return self; }
- (void)setSelectedDate:(NSDateComponents *)d { _selectedDate = [d copy]; [self._isim_view _isim_selectionChanged]; }
- (void)setSelectedDate:(NSDateComponents *)d animated:(BOOL)animated { self.selectedDate = d; }
- (BOOL)_isim_canSelect:(NSDateComponents *)day {
    id<UICalendarSelectionSingleDateDelegate> d = _delegate;
    return ![d respondsToSelector:@selector(dateSelection:canSelectDate:)] || [d dateSelection:self canSelectDate:day];
}
- (BOOL)_isim_isSelected:(NSDateComponents *)day { return same_day(_selectedDate, day); }
- (void)_isim_tapped:(NSDateComponents *)day {
    if (same_day(_selectedDate, day)) return;
    self.selectedDate = day;
    NSLog(@"isim: calendar selected %ld-%02ld-%02ld", (long)day.year, (long)day.month, (long)day.day);
    [_delegate dateSelection:self didSelectDate:day];
}
@end

@implementation UICalendarSelectionMultiDate
- (instancetype)initWithDelegate:(id<UICalendarSelectionMultiDateDelegate>)delegate { if ((self = [super initForIsim])) { _delegate = delegate; _selectedDates = @[]; } return self; }
- (void)setSelectedDates:(NSArray<NSDateComponents *> *)d { _selectedDates = [d ?: @[] copy]; [self._isim_view _isim_selectionChanged]; }
- (void)setSelectedDates:(NSArray<NSDateComponents *> *)d animated:(BOOL)animated { self.selectedDates = d; }
- (BOOL)_isim_canSelect:(NSDateComponents *)day {
    id<UICalendarSelectionMultiDateDelegate> d = _delegate;
    if ([self _isim_isSelected:day]) return ![d respondsToSelector:@selector(multiDateSelection:canDeselectDate:)] || [d multiDateSelection:self canDeselectDate:day];
    return ![d respondsToSelector:@selector(multiDateSelection:canSelectDate:)] || [d multiDateSelection:self canSelectDate:day];
}
- (BOOL)_isim_isSelected:(NSDateComponents *)day { for (NSDateComponents *c in _selectedDates) if (same_day(c, day)) return YES; return NO; }
- (void)_isim_tapped:(NSDateComponents *)day {
    NSMutableArray *a = [_selectedDates mutableCopy];
    if ([self _isim_isSelected:day]) {
        for (NSDateComponents *c in _selectedDates) if (same_day(c, day)) [a removeObject:c];
        self.selectedDates = a;
        NSLog(@"isim: calendar deselected %ld-%02ld-%02ld (%lu selected)", (long)day.year, (long)day.month, (long)day.day, (unsigned long)a.count);
        [_delegate multiDateSelection:self didDeselectDate:day];
    } else {
        [a addObject:day];
        self.selectedDates = a;
        NSLog(@"isim: calendar selected %ld-%02ld-%02ld (%lu selected)", (long)day.year, (long)day.month, (long)day.day, (unsigned long)a.count);
        [_delegate multiDateSelection:self didSelectDate:day];
    }
}
@end

@implementation UICalendarSelectionWeekOfYear
- (instancetype)initWithDelegate:(id<UICalendarSelectionWeekOfYearDelegate>)delegate { if ((self = [super initForIsim])) _delegate = delegate; return self; }
- (void)setSelectedWeekOfYear:(NSDateComponents *)w { _selectedWeekOfYear = [w copy]; [self._isim_view _isim_selectionChanged]; }
- (void)setSelectedWeekOfYear:(NSDateComponents *)w animated:(BOOL)animated { self.selectedWeekOfYear = w; }
/* the week a day falls in, in the calendar view's calendar */
- (NSDateComponents *)_isim_weekOf:(NSDateComponents *)day {
    NSCalendar *cal = self._isim_view.calendar ?: NSCalendar.currentCalendar;
    NSInteger week, year; week_of(cal, day.year, day.month, day.day, &week, &year);
    NSDateComponents *w = [NSDateComponents new]; w.calendar = cal; w.weekOfYear = week; w.yearForWeekOfYear = year;
    return w;
}
- (BOOL)_isim_canSelect:(NSDateComponents *)day {
    id<UICalendarSelectionWeekOfYearDelegate> d = _delegate;
    return ![d respondsToSelector:@selector(weekOfYearSelection:canSelectWeekOfYear:)] || [d weekOfYearSelection:self canSelectWeekOfYear:[self _isim_weekOf:day]];
}
- (BOOL)_isim_isSelected:(NSDateComponents *)day {
    if (!_selectedWeekOfYear) return NO;
    NSDateComponents *w = [self _isim_weekOf:day];
    return w.weekOfYear == _selectedWeekOfYear.weekOfYear && w.yearForWeekOfYear == _selectedWeekOfYear.yearForWeekOfYear;
}
- (void)_isim_tapped:(NSDateComponents *)day {
    NSDateComponents *w = [self _isim_weekOf:day];
    if ([self _isim_isSelected:day]) return;
    self.selectedWeekOfYear = w;
    NSLog(@"isim: calendar selected week %ld of %ld", (long)w.weekOfYear, (long)w.yearForWeekOfYear);
    [_delegate weekOfYearSelection:self didSelectWeekOfYear:w];
}
@end

/* ================= the day cells ================= */
@interface __IsimCalendarDay : UIControl
@property (nonatomic, strong) NSDateComponents *components;
@property (nonatomic) BOOL chosen, today, available, weekStart, weekEnd, weekSelection;
@property (nonatomic, strong) UICalendarViewDecoration *decoration;
@property (nonatomic, strong) UIView *customDecoration;
@property (nonatomic) BOOL decorated;               /* the view has room for decorations */
@end
@implementation __IsimCalendarDay
- (CGFloat)_numberCenterY { return _decorated ? self.bounds.size.height / 2 - 7 : self.bounds.size.height / 2; }
- (void)layoutSubviews {
    [super layoutSubviews];
    UIView *v = _customDecoration;
    if (!v) return;
    CGSize s = self.bounds.size, vs = [v sizeThatFits:CGSizeMake(s.width, 16)];
    if (vs.width <= 0 || vs.height <= 0) vs = CGSizeMake(12, 12);
    v.frame = CGRectMake(round((s.width - vs.width) / 2), round([self _numberCenterY] + 15), vs.width, vs.height);
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double d = fmin(40, fmin(s.width, s.height) - 2), cy = [self _numberCenterY];
    if (_chosen && _weekSelection) {                 /* the selected week: one capsule across the row */
        double c[4]; isim_ui_rgba(self.tintColor, c); c[3] *= 0.15;
        double x0 = _weekStart ? (s.width - d) / 2 : 0, x1 = _weekEnd ? (s.width + d) / 2 : s.width;
        isim_gfx_fill_rounded(x0, cy - d / 2, x1 - x0, d, (_weekStart || _weekEnd) ? d / 2 : 0, c);
    } else if (_chosen) {
        double c[4]; isim_ui_rgba(self.tintColor, c); c[3] *= 0.15; isim_gfx_fill_ellipse((s.width - d) / 2, cy - d / 2, d, d, c);
    }
    UIFont *f = [UIFont systemFontOfSize:20 weight:_chosen ? UIFontWeightSemibold : UIFontWeightRegular];
    UIColor *col = !_available ? UIColor.tertiaryLabelColor : (_chosen || _today) ? self.tintColor : UIColor.labelColor;
    NSString *t = [NSString stringWithFormat:@"%ld", (long)_components.day];
    CGSize ts = isim_ui_measure(t, f, 0, 1);
    isim_ui_draw_text(t, f, col, CGRectMake(0, cy - ts.height / 2, s.width, ts.height), NSTextAlignmentCenter, 1, self.highlighted ? 0.5 : 1);
    UICalendarViewDecoration *dec = _decoration;
    if (!dec || dec->_provider) return;
    double size = dec->_size == UICalendarViewDecorationSizeSmall ? 0.7 : dec->_size == UICalendarViewDecorationSizeLarge ? 1.4 : 1;
    UIColor *dc = dec->_color ?: UIColor.secondaryLabelColor;
    double top = cy + 15;
    if (dec->_image) {                               /* an image (symbols tinted with the colour) */
        UIImage *img = dec->_image;
        if (img.symbolImage) img = [img imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:10 * size]];
        CGSize is = img.size;
        [img _isim_drawInRect:CGRectMake(round((s.width - is.width) / 2), round(top), is.width, is.height) tint:dc alpha:_available ? 1 : 0.4];
    } else {                                         /* a dot */
        double r = 6 * size, c[4]; isim_ui_rgba(dc, c); if (!_available) c[3] *= 0.4;
        isim_gfx_fill_ellipse((s.width - r) / 2, top + 2, r, r, c);
    }
}
- (NSString *)accessibilityLabel { return [NSString stringWithFormat:@"%ld", (long)_components.day]; }
- (NSString *)currentTitle { return self.accessibilityLabel; }
@end

/* ================= UICalendarView ================= */
@implementation UICalendarView { NSInteger _year, _month; UILabel *_title; UIImageView *_chev; UIButton *_prev, *_next;
    NSMutableArray<UILabel *> *_weekdays; NSMutableArray<__IsimCalendarDay *> *_days; NSInteger _firstColumn, _dayCount; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _calendar = [NSCalendar.currentCalendar copy]; _locale = NSLocale.currentLocale; _fontDesign = UIFontDescriptorSystemDesignDefault;
        _availableDateRange = [[NSDateInterval alloc] initWithStartDate:NSDate.distantPast endDate:NSDate.distantFuture];
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
        _weekdays = [NSMutableArray array]; _days = [NSMutableArray array];
        for (int i = 0; i < 7; i++) {
            UILabel *l = [UILabel new]; l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; l.textColor = UIColor.tertiaryLabelColor;
            l.textAlignment = NSTextAlignmentCenter; [self addSubview:l]; [_weekdays addObject:l];
        }
        for (int i = 0; i < 31; i++) {
            __IsimCalendarDay *c = [__IsimCalendarDay new];
            c.accessibilityIdentifier = [NSString stringWithFormat:@"calendar-day-%d", i + 1];
            [c addTarget:self action:@selector(_isim_tapDay:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:c]; [_days addObject:c];
        }
        NSInteger d; ymd_of(_calendar, [NSDate date], &_year, &_month, &d);
        [self _isim_reloadAll];
    }
    return self;
}
- (CGFloat)_rowHeight { return _wantsDateDecorations ? 58 : 44; }
- (CGSize)intrinsicContentSize { return CGSizeMake(343, 76 + 6 * [self _rowHeight] + 8); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 && s.width < 1e5 ? s.width : 343, [self intrinsicContentSize].height); }

- (void)setCalendar:(NSCalendar *)c { _calendar = [c ?: NSCalendar.currentCalendar copy]; [self _isim_reloadAll]; }
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; [self _isim_reloadAll]; }
- (void)setTimeZone:(NSTimeZone *)z { _timeZone = z; _calendar.timeZone = z ?: NSTimeZone.localTimeZone; [self _isim_reloadAll]; }
- (void)setAvailableDateRange:(NSDateInterval *)r { _availableDateRange = r ?: [[NSDateInterval alloc] initWithStartDate:NSDate.distantPast endDate:NSDate.distantFuture]; [self _isim_reloadAll]; }
- (void)setWantsDateDecorations:(BOOL)w { _wantsDateDecorations = w; [self invalidateIntrinsicContentSize]; [self _isim_reloadAll]; }
- (void)setSelectionBehavior:(UICalendarSelection *)s { _selectionBehavior._isim_view = nil; _selectionBehavior = s; s._isim_view = self; [self _isim_reloadAll]; }
- (void)setDelegate:(id<UICalendarViewDelegate>)d { _delegate = d; [self _isim_reloadAll]; }
- (NSDateComponents *)visibleDateComponents {
    NSDateComponents *c = [NSDateComponents new]; c.calendar = _calendar; c.year = _year; c.month = _month; c.day = 1;
    return c;
}
- (void)setVisibleDateComponents:(NSDateComponents *)c { [self setVisibleDateComponents:c animated:NO]; }
- (void)setVisibleDateComponents:(NSDateComponents *)c animated:(BOOL)animated {
    if (c.year != NSDateComponentUndefined) _year = c.year;
    if (c.month != NSDateComponentUndefined) _month = c.month;
    [self _isim_reloadAll];
}
- (void)_isim_moveMonths:(NSInteger)n {
    NSDateComponents *was = self.visibleDateComponents;
    _month += n;
    while (_month < 1) { _month += 12; _year--; }
    while (_month > 12) { _month -= 12; _year++; }
    [self _isim_reloadAll];
    NSLog(@"isim: calendar shows %ld-%02ld", (long)_year, (long)_month);
    id<UICalendarViewDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(calendarView:didChangeVisibleDateComponentsFrom:)]) [d calendarView:self didChangeVisibleDateComponentsFrom:was];
}
- (void)_isim_prev { [self _isim_moveMonths:-1]; }
- (void)_isim_next { [self _isim_moveMonths:1]; }
- (NSDateComponents *)_dayComponents:(NSInteger)day {
    NSDateComponents *c = [NSDateComponents new]; c.calendar = _calendar; c.era = _year > 0 ? 1 : 0; c.year = _year; c.month = _month; c.day = day;
    return c;
}
- (BOOL)_available:(NSDateComponents *)c {
    NSDate *start = day_start(_calendar, c.year, c.month, c.day);
    NSDate *end = [start dateByAddingTimeInterval:86399];
    return [end compare:_availableDateRange.startDate] != NSOrderedAscending && [start compare:_availableDateRange.endDate] != NSOrderedDescending;
}
- (void)_isim_selectionChanged { [self _isim_refreshSelection]; }
- (void)_isim_refreshSelection {
    UICalendarSelection *sel = _selectionBehavior;
    BOOL week = [sel isKindOfClass:[UICalendarSelectionWeekOfYear class]];
    for (NSInteger i = 0; i < _dayCount; i++) {
        __IsimCalendarDay *c = _days[(NSUInteger)i];
        c.chosen = [sel _isim_isSelected:c.components];
        c.available = [self _available:c.components] && (!sel || [sel _isim_canSelect:c.components] || c.chosen);
        c.weekSelection = week;
        NSInteger col = (_firstColumn + i) % 7;
        c.weekStart = col == 0 || i == 0 || ![sel _isim_isSelected:_days[(NSUInteger)i - 1].components];
        c.weekEnd = col == 6 || i == _dayCount - 1 || ![sel _isim_isSelected:_days[(NSUInteger)i + 1].components];
        [c setNeedsDisplay];
    }
}
- (void)_isim_decorate:(__IsimCalendarDay *)c {
    UICalendarViewDecoration *dec = nil;
    id<UICalendarViewDelegate> d = _delegate;
    if (_wantsDateDecorations && [d respondsToSelector:@selector(calendarView:decorationForDateComponents:)]) dec = [d calendarView:self decorationForDateComponents:c.components];
    c.decorated = _wantsDateDecorations;
    c.decoration = dec;
    [c.customDecoration removeFromSuperview]; c.customDecoration = nil;
    if (dec && dec->_provider) { UIView *v = dec->_provider(); if (v) { v.userInteractionEnabled = NO; [c addSubview:v]; c.customDecoration = v; } }
    [c setNeedsLayout]; [c setNeedsDisplay];
}
- (void)_isim_reloadAll {
    NSDate *fd = [day_start(_calendar, _year, _month, 1) dateByAddingTimeInterval:12 * 3600];
    NSDateFormatter *f = [NSDateFormatter new]; f.locale = _locale; f.timeZone = zone_of(_calendar); f.dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMMMyyyy" options:0 locale:_locale] ?: @"MMMM yyyy";
    _title.text = [f stringFromDate:fd];
    _dayCount = days_in(_year, _month);
    NSInteger fw = MAX(1, (NSInteger)_calendar.firstWeekday);
    _firstColumn = ((weekday_of(_year, _month, 1) - fw) % 7 + 7) % 7;
    NSDateComponents *today = [NSDateComponents new]; NSInteger ty, tm, td; ymd_of(_calendar, [NSDate date], &ty, &tm, &td); today.year = ty; today.month = tm; today.day = td;
    for (NSInteger i = 0; i < 31; i++) {
        __IsimCalendarDay *c = _days[(NSUInteger)i];
        c.hidden = i >= _dayCount;
        if (c.hidden) continue;
        c.components = [self _dayComponents:i + 1];
        c.today = same_day(c.components, today);
        [self _isim_decorate:c];
    }
    f.dateFormat = @"EEE";
    for (NSInteger i = 0; i < 7; i++) {
        NSDate *k = [day_start(_calendar, 2020, 1, 5 + (fw - 1 + i) % 7) dateByAddingTimeInterval:12 * 3600];   /* Jan 5 2020 is a Sunday */
        _weekdays[(NSUInteger)i].text = [[f stringFromDate:k] uppercaseString];
    }
    [self _isim_refreshSelection];
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (void)reloadDecorationsForDateComponents:(NSArray<NSDateComponents *> *)dates animated:(BOOL)animated {
    for (NSInteger i = 0; i < _dayCount; i++)
        for (NSDateComponents *d in dates) if (same_day(d, _days[(NSUInteger)i].components)) { [self _isim_decorate:_days[(NSUInteger)i]]; break; }
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, m = 10, cw = (W - 2 * m) / 7, rowH = [self _rowHeight], top = 76;
    CGSize ts = [_title sizeThatFits:CGSizeMake(W, 44)];
    _title.frame = CGRectMake(16, 10, ceil(ts.width), 24);
    CGSize cs = _chev.image.size;
    _chev.tintColor = self.tintColor;
    _chev.frame = CGRectMake(CGRectGetMaxX(_title.frame) + 6, 22 - cs.height / 2, cs.width, cs.height);
    _prev.frame = CGRectMake(W - 92, 0, 44, 44); _next.frame = CGRectMake(W - 48, 0, 44, 44);
    BOOL rtl = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    for (NSInteger i = 0; i < 7; i++) _weekdays[(NSUInteger)i].frame = CGRectMake(m + (rtl ? 6 - i : i) * cw, 50, cw, 18);
    for (NSInteger i = 0; i < _dayCount; i++) {
        NSInteger idx = _firstColumn + i, r = idx / 7, c = idx % 7;
        _days[(NSUInteger)i].frame = CGRectMake(m + (rtl ? 6 - c : c) * cw, top + r * rowH, cw, rowH);
    }
}
- (void)_isim_tapDay:(__IsimCalendarDay *)c {
    UICalendarSelection *sel = _selectionBehavior;
    if (!sel || !c.available) return;
    [sel _isim_tapped:c.components];
    [self _isim_refreshSelection];
}
@end
