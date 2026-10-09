/* UIColorPickerViewController and UIColorWell.
 *
 * The picker (presented as a sheet) has iOS's layout: "Colors" title with a close button, a Grid / Spectrum /
 * Sliders segmented control, the 12 x 10 color grid (grays, then hues from dark to light), a hue/brightness
 * spectrum, RGB sliders, an opacity slider (supportsAlpha) and a swatch of the current color. Picking a color
 * sets selectedColor and tells the delegate (didSelectColor, continuously while dragging the spectrum or a
 * slider); closing calls colorPickerViewControllerDidFinish. The Sliders page has an sRGB hex field (iOS shows Display P3;
 * isim's colors are sRGB). The eyedropper (top left) hides the picker; the next touch anywhere in the window samples
 * that pixel (drawn by the app's views) and brings the picker back with it. Saved colors: "+" adds the current color
 * to a row of swatches shared by the device's apps (the global defaults, like iOS's favorites); a swatch picks its
 * color, a long press removes it. UIColorWell draws the rainbow ring around its color, presents a picker when tapped
 * and sends .valueChanged as the color changes. */
#import "UIKitPrivate.h"
#import <UIKit/UIColorPickerViewController.h>
#include <math.h>

static NSString *hex(UIColor *c) {
    double v[4]; isim_ui_rgba(c, v);
    return [NSString stringWithFormat:@"#%02X%02X%02X%@", (int)lround(v[0] * 255), (int)lround(v[1] * 255), (int)lround(v[2] * 255),
            v[3] < 0.999 ? [NSString stringWithFormat:@" a%.2f", v[3]] : @""];
}
static const double grid_hues[12] = { 190, 210, 232, 262, 296, 334, 2, 22, 36, 50, 66, 108 };
static UIColor *grid_color(int col, int row) {
    if (row == 0) return [UIColor colorWithWhite:1 - col / 11.0 alpha:1];
    int r = row - 1;
    double s = 1, b = 1;
    if (r < 4) b = 0.32 + r * 0.17; else if (r > 4) s = 1 - (r - 4) * 0.19;
    return [UIColor colorWithHue:grid_hues[col] / 360.0 saturation:s brightness:b alpha:1];
}

/* ---- grid ---- */
@interface __IsimColorGrid : UIControl
@property (nonatomic) int selCol, selRow;
@end
@implementation __IsimColorGrid
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { _selCol = -1; self.accessibilityIdentifier = @"color-grid"; } return self; }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; double cw = s.width / 12, ch = s.height / 10;
    isim_gfx_save(); isim_gfx_clip_rounded(0, 0, s.width, s.height, 8);
    for (int r = 0; r < 10; r++) for (int c = 0; c < 12; c++) {
        double v[4]; isim_ui_rgba(grid_color(c, r), v);
        isim_gfx_fill_rounded(c * cw, r * ch, cw + 0.5, ch + 0.5, 0, v);
    }
    isim_gfx_restore();
    if (_selCol >= 0) {
        double w[4] = { 1, 1, 1, 1 }, k[4] = { 0, 0, 0, 0.25 };
        isim_gfx_stroke_rounded(_selCol * cw + 1, _selRow * ch + 1, cw - 2, ch - 2, 3, 3, w);
        isim_gfx_stroke_rounded(_selCol * cw, _selRow * ch, cw, ch, 4, 1, k);
    }
}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e {
    [super touchesEnded:t withEvent:e];
    CGPoint p = [t.anyObject locationInView:self]; CGSize s = self.bounds.size;
    if (!CGRectContainsPoint(self.bounds, p)) return;
    _selCol = MIN(11, (int)(p.x / (s.width / 12))); _selRow = MIN(9, (int)(p.y / (s.height / 10)));
    isim_ui_set_needs_display();
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (UIColor *)color { return _selCol >= 0 ? grid_color(_selCol, _selRow) : nil; }
@end

/* ---- spectrum: hue across, light (top) to dark (bottom) ---- */
@interface __IsimColorSpectrum : UIControl
@property (nonatomic) CGPoint mark; @property (nonatomic) BOOL marked;
@end
@implementation __IsimColorSpectrum
static UIColor *spectrum_at(double x, double y) {            /* unit coordinates */
    double h = fmin(0.999, fmax(0, x)), t = fmin(1, fmax(0, y));
    if (t < 0.5) return [UIColor colorWithHue:h saturation:t * 2 brightness:1 alpha:1];
    return [UIColor colorWithHue:h saturation:1 brightness:1 - (t - 0.5) * 2 * 0.92 alpha:1];
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; int nx = 48, ny = 30; double w = s.width / nx, h = s.height / ny;
    isim_gfx_save(); isim_gfx_clip_rounded(0, 0, s.width, s.height, 8);
    for (int j = 0; j < ny; j++) for (int i = 0; i < nx; i++) {
        double v[4]; isim_ui_rgba(spectrum_at((i + 0.5) / nx, (j + 0.5) / ny), v);
        isim_gfx_fill_rounded(i * w, j * h, w + 0.5, h + 0.5, 0, v);
    }
    isim_gfx_restore();
    if (_marked) { double wc[4] = { 1, 1, 1, 1 }; isim_gfx_stroke_rounded(_mark.x - 10, _mark.y - 10, 20, 20, 10, 3, wc); }
}
- (void)_isim_track:(UITouch *)t done:(BOOL)done {
    CGPoint p = [t locationInView:self]; CGSize s = self.bounds.size;
    p.x = fmin(s.width, fmax(0, p.x)); p.y = fmin(s.height, fmax(0, p.y));
    _mark = p; _marked = YES; isim_ui_set_needs_display();
    self.selected = !done;               /* selected = still dragging (continuous) */
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
- (BOOL)beginTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { [self _isim_track:t done:NO]; return YES; }
- (BOOL)continueTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { [self _isim_track:t done:NO]; return YES; }
- (void)endTrackingWithTouch:(UITouch *)t withEvent:(UIEvent *)e { if (t) [self _isim_track:t done:YES]; }
- (UIColor *)color { CGSize s = self.bounds.size; return spectrum_at(_mark.x / fmax(1, s.width), _mark.y / fmax(1, s.height)); }
@end

/* ================= UIColorPickerViewController ================= */
@implementation UIColorPickerViewController {
    UIScrollView *_scroll; UISegmentedControl *_mode;
    __IsimColorGrid *_grid; __IsimColorSpectrum *_spectrum; UIView *_sliders;
    UISlider *_rgb[3]; UILabel *_rgbValue[3]; UISlider *_alpha; UILabel *_alphaLabel, *_alphaValue; UIView *_swatch;
    UILabel *_title; UIButton *_close, *_eyedropper;
    UITextField *_hex; UILabel *_hexLabel; UIView *_saved; UIButton *_add;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b {
    if ((self = [super initWithNibName:n bundle:b])) { _selectedColor = UIColor.whiteColor; _supportsAlpha = YES; }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *v = self.view;
    v.backgroundColor = UIColor.secondarySystemBackgroundColor;
    _title = [UILabel new]; _title.text = @"Colors"; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _title.textAlignment = NSTextAlignmentCenter;
    [v addSubview:_title];
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    _close.tintColor = UIColor.secondaryLabelColor; _close.backgroundColor = UIColor.tertiarySystemFillColor; _close.layer.cornerRadius = 15;
    _close.accessibilityIdentifier = @"color-close";
    [_close addTarget:self action:@selector(_isim_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_close];
    _scroll = [UIScrollView new]; [v addSubview:_scroll];
    _mode = [[UISegmentedControl alloc] initWithItems:@[@"Grid", @"Spectrum", @"Sliders"]];
    _mode.selectedSegmentIndex = 0; _mode.accessibilityIdentifier = @"color-mode";
    [_mode addTarget:self action:@selector(_isim_modeChanged) forControlEvents:UIControlEventValueChanged];
    [_scroll addSubview:_mode];
    _grid = [__IsimColorGrid new]; [_grid addTarget:self action:@selector(_isim_gridPicked) forControlEvents:UIControlEventValueChanged]; [_scroll addSubview:_grid];
    _spectrum = [__IsimColorSpectrum new]; _spectrum.accessibilityIdentifier = @"color-spectrum"; _spectrum.hidden = YES;
    [_spectrum addTarget:self action:@selector(_isim_spectrumPicked) forControlEvents:UIControlEventValueChanged]; [_scroll addSubview:_spectrum];
    _sliders = [UIView new]; _sliders.hidden = YES; [_scroll addSubview:_sliders];
    NSArray *names = @[@"RED", @"GREEN", @"BLUE"];
    for (int i = 0; i < 3; i++) {
        UILabel *l = [UILabel new]; l.text = names[(NSUInteger)i]; l.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; l.textColor = UIColor.secondaryLabelColor; l.tag = 10 + i;
        [_sliders addSubview:l];
        _rgb[i] = [UISlider new]; _rgb[i].maximumValue = 255; _rgb[i].accessibilityIdentifier = [@"color-" stringByAppendingString:[names[(NSUInteger)i] lowercaseString]];
        _rgb[i].minimumTrackTintColor = @[UIColor.systemRedColor, UIColor.systemGreenColor, UIColor.systemBlueColor][(NSUInteger)i];
        [_rgb[i] addTarget:self action:@selector(_isim_slid:) forControlEvents:UIControlEventValueChanged];
        [_rgb[i] addTarget:self action:@selector(_isim_slideEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [_sliders addSubview:_rgb[i]];
        _rgbValue[i] = [UILabel new]; _rgbValue[i].font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular]; _rgbValue[i].textAlignment = NSTextAlignmentRight;
        [_sliders addSubview:_rgbValue[i]];
    }
    _alphaLabel = [UILabel new]; _alphaLabel.text = @"OPACITY"; _alphaLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold]; _alphaLabel.textColor = UIColor.secondaryLabelColor;
    [_scroll addSubview:_alphaLabel];
    _alpha = [UISlider new]; _alpha.maximumValue = 100; _alpha.accessibilityIdentifier = @"color-opacity";
    [_alpha addTarget:self action:@selector(_isim_slid:) forControlEvents:UIControlEventValueChanged];
    [_alpha addTarget:self action:@selector(_isim_slideEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_scroll addSubview:_alpha];
    _alphaValue = [UILabel new]; _alphaValue.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular]; _alphaValue.textAlignment = NSTextAlignmentRight;
    [_scroll addSubview:_alphaValue];
    _swatch = [UIView new]; _swatch.layer.cornerRadius = 10; _swatch.layer.borderWidth = 0.5; _swatch.layer.borderColor = UIColor.separatorColor.CGColor;
    _swatch.accessibilityIdentifier = @"color-swatch";
    [_scroll addSubview:_swatch];
    _eyedropper = [UIButton buttonWithType:UIButtonTypeSystem];
    [_eyedropper setImage:[UIImage systemImageNamed:@"eyedropper" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium]] forState:UIControlStateNormal];
    _eyedropper.accessibilityIdentifier = @"color-eyedropper"; _eyedropper.accessibilityLabel = @"Eyedropper";
    [_eyedropper addTarget:self action:@selector(_isim_eyedropper) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_eyedropper];
    _hexLabel = [UILabel new]; _hexLabel.text = @"sRGB Hex Color #"; _hexLabel.font = [UIFont systemFontOfSize:17]; _hexLabel.textAlignment = NSTextAlignmentRight;
    [_sliders addSubview:_hexLabel];
    _hex = [UITextField new]; _hex.borderStyle = UITextBorderStyleRoundedRect; _hex.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _hex.autocorrectionType = UITextAutocorrectionTypeNo; _hex.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
    _hex.accessibilityIdentifier = @"color-hex"; _hex.returnKeyType = UIReturnKeyDone;
    [_hex addTarget:self action:@selector(_isim_hexEntered) forControlEvents:UIControlEventEditingDidEndOnExit];
    [_hex addTarget:self action:@selector(_isim_hexEntered) forControlEvents:UIControlEventEditingDidEnd];
    [_sliders addSubview:_hex];
    _saved = [UIView new]; _saved.accessibilityIdentifier = @"color-saved"; [_scroll addSubview:_saved];
    _add = [UIButton buttonWithType:UIButtonTypeSystem];
    [_add setImage:[UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
    _add.backgroundColor = UIColor.tertiarySystemFillColor; _add.layer.cornerRadius = 15;
    _add.accessibilityIdentifier = @"color-save"; _add.accessibilityLabel = @"Add to saved colors";
    [_add addTarget:self action:@selector(_isim_saveColor) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:_add];
    [self _isim_reloadSaved];
    [self _isim_syncControls];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGSize b = self.view.bounds.size;
    CGFloat W = b.width, m = 16, cw = W - 2 * m;
    _title.frame = CGRectMake(60, 14, W - 120, 24);
    _close.frame = CGRectMake(W - m - 30, 11, 30, 30);
    _eyedropper.frame = CGRectMake(m - 6, 7, 38, 38);
    _scroll.frame = CGRectMake(0, 52, W, MAX(0, b.height - 52));
    CGFloat y = 4;
    _mode.frame = CGRectMake(m, y, cw, 32); y += 32 + 16;
    CGFloat gh = cw / 12 * 10;
    _grid.frame = CGRectMake(m, y, cw, gh);
    _spectrum.frame = CGRectMake(m, y, cw, gh);
    _sliders.frame = CGRectMake(m, y, cw, gh);
    for (int i = 0; i < 3; i++) {
        [_sliders viewWithTag:10 + i].frame = CGRectMake(0, i * 72, cw, 18);
        _rgb[i].frame = CGRectMake(0, i * 72 + 24, cw - 64, 31);
        _rgbValue[i].frame = CGRectMake(cw - 56, i * 72 + 24, 56, 31);
    }
    _hexLabel.frame = CGRectMake(0, 3 * 72 + 4, cw - 120, 36);
    _hex.frame = CGRectMake(cw - 110, 3 * 72 + 4, 110, 36);
    y += gh + 20;
    _alphaLabel.hidden = _alpha.hidden = _alphaValue.hidden = !_supportsAlpha;
    if (_supportsAlpha) {
        _alphaLabel.frame = CGRectMake(m, y, cw, 18); y += 24;
        _alpha.frame = CGRectMake(m, y, cw - 64, 31); _alphaValue.frame = CGRectMake(W - m - 56, y, 56, 31); y += 31 + 20;
    }
    _swatch.frame = CGRectMake(m, y, 64, 64);
    /* saved colors right of the swatch: 30 pt circles, then "+" */
    CGFloat sx = m + 64 + 16, sy = y + 2;
    NSUInteger perRow = (NSUInteger)MAX(1, floor((W - m - sx + 8) / 38));
    NSUInteger i = 0;
    for (UIView *c in _saved.subviews) { c.frame = CGRectMake((i % perRow) * 38, (i / perRow) * 38, 30, 30); i++; }
    _add.frame = CGRectMake(sx + (i % perRow) * 38, sy + (i / perRow) * 38, 30, 30);
    _saved.frame = CGRectMake(sx, sy, W - m - sx, (i / perRow + 1) * 38);
    y += MAX(64, (i / perRow + 1) * 38) + 24;
    _scroll.contentSize = CGSizeMake(W, y);
}
- (void)setSelectedColor:(UIColor *)c { _selectedColor = c ?: UIColor.whiteColor; [self _isim_syncControls]; }
- (void)setSupportsAlpha:(BOOL)s { _supportsAlpha = s; [self.viewIfLoaded setNeedsLayout]; }
- (void)_isim_syncControls {
    if (!self.isViewLoaded) return;
    double v[4]; isim_ui_rgba(_selectedColor, v);
    for (int i = 0; i < 3; i++) { _rgb[i].value = (float)(v[i] * 255); _rgbValue[i].text = [NSString stringWithFormat:@"%d", (int)lround(v[i] * 255)]; }
    _alpha.value = (float)(v[3] * 100); _alphaValue.text = [NSString stringWithFormat:@"%d%%", (int)lround(v[3] * 100)];
    _swatch.backgroundColor = _selectedColor;
    if (!_hex.isFirstResponder) _hex.text = [hex(_selectedColor) substringWithRange:NSMakeRange(1, 6)];
}
- (void)_isim_pick:(UIColor *)c continuously:(BOOL)cont {
    double v[4]; isim_ui_rgba(c, v);
    if (_supportsAlpha && _alpha) v[3] = _alpha.value / 100.0;
    if (!_supportsAlpha) v[3] = 1;
    _selectedColor = [UIColor colorWithRed:v[0] green:v[1] blue:v[2] alpha:v[3]];
    [self _isim_syncControls];
    NSLog(@"isim: color picker selected %@", hex(_selectedColor));
    id<UIColorPickerViewControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(colorPickerViewController:didSelectColor:continuously:)]) [d colorPickerViewController:self didSelectColor:_selectedColor continuously:cont];
    if ([d respondsToSelector:@selector(colorPickerViewControllerDidSelectColor:)]) [d colorPickerViewControllerDidSelectColor:self];
}
- (void)_isim_gridPicked { [self _isim_pick:_grid.color continuously:NO]; }
- (void)_isim_spectrumPicked { [self _isim_pick:_spectrum.color continuously:_spectrum.selected]; }
- (void)_isim_slid:(UISlider *)s {
    UIColor *c = [UIColor colorWithRed:_rgb[0].value / 255.0 green:_rgb[1].value / 255.0 blue:_rgb[2].value / 255.0 alpha:1];
    [self _isim_pick:c continuously:YES];                 /* while dragging; the touch-up sends the final one */
}
/* the end of a slider drag: the final, non-continuous selection */
- (void)_isim_slideEnded:(UISlider *)s {
    UIColor *c = [UIColor colorWithRed:_rgb[0].value / 255.0 green:_rgb[1].value / 255.0 blue:_rgb[2].value / 255.0 alpha:1];
    [self _isim_pick:c continuously:NO];
}
- (void)_isim_modeChanged {
    NSInteger m = _mode.selectedSegmentIndex;
    _grid.hidden = m != 0; _spectrum.hidden = m != 1; _sliders.hidden = m != 2;
}
/* ---- hex ---- */
- (void)_isim_hexEntered {
    NSString *t = [[_hex.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned v = 0;
    if (t.length != 6 || ![[NSScanner scannerWithString:t] scanHexInt:&v]) { [self _isim_syncControls]; return; }   /* invalid: back to the color */
    [_hex resignFirstResponder];
    [self _isim_pick:[UIColor colorWithRed:((v >> 16) & 255) / 255.0 green:((v >> 8) & 255) / 255.0 blue:(v & 255) / 255.0 alpha:1] continuously:NO];
}
/* ---- saved colors (shared by the device's apps, like iOS's) ---- */
static NSUserDefaults *global_defaults(void) { return [[NSUserDefaults alloc] initWithSuiteName:@".GlobalPreferences"]; }
static NSArray<NSString *> *saved_colors(void) { NSArray *a = [global_defaults() arrayForKey:@"ISIMColorPickerSavedColors"]; return a ?: @[]; }
static UIColor *color_from_saved(NSString *s) {
    NSArray *c = [s componentsSeparatedByString:@" "];
    return c.count == 4 ? [UIColor colorWithRed:[c[0] doubleValue] green:[c[1] doubleValue] blue:[c[2] doubleValue] alpha:[c[3] doubleValue]] : nil;
}
- (void)_isim_reloadSaved {
    for (UIView *v in _saved.subviews.copy) [v removeFromSuperview];
    NSArray *all = saved_colors();
    for (NSUInteger i = 0; i < all.count; i++) {
        UIColor *c = color_from_saved(all[i]);
        if (!c) continue;
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        b.backgroundColor = c; b.layer.cornerRadius = 15; b.layer.borderWidth = 0.5; b.layer.borderColor = UIColor.separatorColor.CGColor;
        b.accessibilityIdentifier = [NSString stringWithFormat:@"color-saved-%lu", (unsigned long)i];
        b.accessibilityLabel = hex(c);
        __weak UIColorPickerViewController *ws = self;
        [b addAction:[UIAction actionWithHandler:^(UIAction *a) { [ws _isim_pick:c continuously:NO]; }] forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_savedLongPress:)];
        lp.name = all[i];
        [b addGestureRecognizer:lp];
        [_saved addSubview:b];
    }
    [self.viewIfLoaded setNeedsLayout];
}
- (void)_isim_saveColor {
    double v[4]; isim_ui_rgba(_selectedColor, v);
    NSString *entry = [NSString stringWithFormat:@"%g %g %g %g", v[0], v[1], v[2], v[3]];
    NSMutableArray *all = [saved_colors() mutableCopy];
    [all removeObject:entry]; [all addObject:entry];
    [global_defaults() setObject:all forKey:@"ISIMColorPickerSavedColors"];
    NSLog(@"isim: color picker saved %@ (%lu saved colors)", hex(_selectedColor), (unsigned long)all.count);
    [self _isim_reloadSaved];
}
- (void)_isim_savedLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    NSMutableArray *all = [saved_colors() mutableCopy];
    [all removeObject:g.name];
    [global_defaults() setObject:all forKey:@"ISIMColorPickerSavedColors"];
    NSLog(@"isim: color picker removed a saved color (%lu left)", (unsigned long)all.count);
    [self _isim_reloadSaved];
}
/* ---- eyedropper: the picker steps aside; the next touch in the window samples its pixel ---- */
- (UIView *)_isim_topView { UIView *t = self.view; while (t.superview && ![t.superview isKindOfClass:[UIWindow class]]) t = t.superview; return t; }
- (void)_isim_eyedropper {
    UIWindow *w = self.view.window;
    if (!w) return;
    [self _isim_topView].hidden = YES;
    UIControl *catcher = [[UIControl alloc] initWithFrame:w.bounds];
    catcher.accessibilityIdentifier = @"color-eyedropper-overlay";
    catcher.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [catcher addTarget:self action:@selector(_isim_eyedropperTouched:withEvent:) forControlEvents:UIControlEventTouchUpInside];
    [w addSubview:catcher];
    NSLog(@"isim: color picker eyedropper: touch a point to sample its color");
}
- (void)_isim_eyedropperTouched:(UIControl *)catcher withEvent:(UIEvent *)e {
    UIWindow *w = catcher.window;
    CGPoint p = [e.allTouches.anyObject locationInView:w];
    [catcher removeFromSuperview];
    unsigned char px[4] = { 0 };
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(px, 1, 1, 8, 4, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    if (ctx && w) {
        UIGraphicsPushContext(ctx);
        CGContextTranslateCTM(ctx, 0, 1); CGContextScaleCTM(ctx, 1, -1);                  /* UIKit coordinates (y down) */
        [w drawViewHierarchyInRect:CGRectMake(-p.x, -p.y, w.bounds.size.width, w.bounds.size.height) afterScreenUpdates:NO];
        UIGraphicsPopContext();
        CGContextRelease(ctx);
    }
    [self _isim_topView].hidden = NO;
    UIColor *c = [UIColor colorWithRed:px[0] / 255.0 green:px[1] / 255.0 blue:px[2] / 255.0 alpha:1];
    NSLog(@"isim: color picker eyedropper sampled %@ at %.0f,%.0f", hex(c), p.x, p.y);
    [self _isim_pick:c continuously:NO];
}
- (void)_isim_closeTapped {
    __weak UIColorPickerViewController *ws = self;
    [self dismissViewControllerAnimated:YES completion:^{
        UIColorPickerViewController *s = ws;
        id<UIColorPickerViewControllerDelegate> d = s.delegate;
        if ([d respondsToSelector:@selector(colorPickerViewControllerDidFinish:)]) [d colorPickerViewControllerDidFinish:s];
    }];
}
@end

/* ================= UIColorWell ================= */
@interface UIColorWell () <UIColorPickerViewControllerDelegate>
@end
@implementation UIColorWell
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { _supportsAlpha = YES; [self addTarget:self action:@selector(_isim_tapped) forControlEvents:UIControlEventTouchUpInside]; }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(28, 28); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(28, 28); }
- (void)setSelectedColor:(UIColor *)c { _selectedColor = c; isim_ui_set_needs_display(); }
- (NSString *)_isim_dumpText { return _selectedColor ? hex(_selectedColor) : @"none"; }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double d = fmin(s.width, s.height), cx = s.width / 2, cy = s.height / 2, r = d / 2 - 1.5;
    for (int i = 0; i < 48; i++) {                           /* the hue ring */
        double a0 = i * 2 * M_PI / 48 - M_PI / 2, a1 = (i + 1.15) * 2 * M_PI / 48 - M_PI / 2;
        double v[4]; isim_ui_rgba([UIColor colorWithHue:i / 48.0 saturation:0.9 brightness:1 alpha:1], v);
        isim_path_begin(); isim_path_arc(cx, cy, r, a0, a1, 0); isim_path_stroke(3, v);
    }
    if (_selectedColor) {
        double v[4]; isim_ui_rgba(_selectedColor, v);
        double ir = r - 4.5;
        isim_gfx_fill_ellipse(cx - ir, cy - ir, 2 * ir, 2 * ir, v);
    }
    if (self.highlighted) { double k[4] = { 0, 0, 0, 0.15 }; isim_gfx_fill_ellipse(cx - r - 1.5, cy - r - 1.5, 2 * r + 3, 2 * r + 3, k); }
}
- (UIViewController *)_isim_presenter {
    for (UIResponder *r = self.nextResponder; r; r = r.nextResponder) if ([r isKindOfClass:[UIViewController class]]) {
        UIViewController *vc = (UIViewController *)r;
        while (vc.parentViewController) vc = vc.parentViewController;
        while (vc.presentedViewController) vc = vc.presentedViewController;
        return vc;
    }
    UIViewController *vc = self.window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
- (void)_isim_tapped {
    UIColorPickerViewController *p = [UIColorPickerViewController new];
    p.title = _title;
    p.supportsAlpha = _supportsAlpha;
    if (_selectedColor) p.selectedColor = _selectedColor;
    p.delegate = self;
    [[self _isim_presenter] presentViewController:p animated:YES completion:nil];
}
- (void)colorPickerViewController:(UIColorPickerViewController *)vc didSelectColor:(UIColor *)c continuously:(BOOL)cont {
    self.selectedColor = c;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end
