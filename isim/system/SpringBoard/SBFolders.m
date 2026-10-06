// isim home screen: folders (made in edit mode by dropping an icon on another) and the open-folder view.
#import "SpringBoard.h"

@implementation HSFolderIcon { UIView *_box; UILabel *_label; }
- (instancetype)initWithFolder:(NSMutableDictionary *)folder apps:(NSArray<HSApp *> *)apps size:(CGFloat)s {
    if ((self = [super initWithFrame:CGRectZero])) {
        _folder = folder;
        _box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, s, s)];
        _box.backgroundColor = [UIColor colorWithWhite:1 alpha:0.32];
        _box.layer.cornerRadius = s * 0.225; _box.clipsToBounds = YES; _box.userInteractionEnabled = NO;
        CGFloat pad = s * 0.12, cell = (s - 2 * pad) / 3, mini = cell * 0.78;
        for (NSUInteger i = 0; i < MIN((NSUInteger)9, apps.count); i++) {
            HSApp *a = apps[i];
            UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(pad + (i % 3) * cell + (cell - mini) / 2, pad + (i / 3) * cell + (cell - mini) / 2, mini, mini)];
            iv.layer.cornerRadius = mini * 0.225; iv.clipsToBounds = YES;
            UIImage *img = a.iconPath ? [UIImage imageWithContentsOfFile:a.iconPath] : nil;
            NSUInteger h = a.bundleID.hash;
            if (img) iv.image = img; else iv.backgroundColor = [UIColor colorWithRed:0.25 + (h % 7) / 12.0 green:0.35 + (h / 7 % 5) / 10.0 blue:0.55 + (h / 35 % 4) / 10.0 alpha:1];
            [_box addSubview:iv];
        }
        [self addSubview:_box];
        _label = [UILabel new];
        _label.text = folder[@"folder"]; _label.font = [UIFont systemFontOfSize:12]; _label.textColor = UIColor.whiteColor;
        _label.textAlignment = NSTextAlignmentCenter; _label.userInteractionEnabled = NO;
        [self addSubview:_label];
        self.accessibilityIdentifier = [@"folder-" stringByAppendingString:folder[@"folder"] ?: @""];
        self.accessibilityLabel = folder[@"folder"];
    }
    return self;
}
- (UIView *)iconView { return _box; }
- (void)layoutSubviews {
    CGFloat s = _box.bounds.size.width, w = self.bounds.size.width;
    _box.frame = CGRectMake((w - s) / 2, 0, s, s);
    _label.frame = CGRectMake(-10, s + 5, w + 20, 16);
}
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; _box.alpha = h ? 0.6 : 1; }
@end

static UIView *folder_view;
@implementation HomeViewController (Folders)
- (void)openFolder:(HSFolderIcon *)icon {
    [self closeFolder];
    CGRect b = self.view.bounds;
    UIView *ov = [[UIView alloc] initWithFrame:b];
    ov.accessibilityIdentifier = @"folder-view";
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blur.frame = b; blur.userInteractionEnabled = NO;
    [ov addSubview:blur];
    [ov addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(closeFolder)]];
    CGFloat W = MIN(b.size.width - 64, 330), s = self.iconSize;
    NSArray *ids = icon.folder[@"apps"];
    NSUInteger rows = MAX((NSUInteger)1, (ids.count + 2) / 3);
    CGFloat cell = W / 3, H = rows * (s + 40) + 40, top = (b.size.height - H) / 2;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(32, top - 64, b.size.width - 64, 40)];
    title.text = icon.folder[@"folder"]; title.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold]; title.textColor = UIColor.whiteColor;
    title.accessibilityIdentifier = @"folder-title";
    [ov addSubview:title];
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake((b.size.width - W) / 2, top, W, H)];
    panel.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22]; panel.layer.cornerRadius = 36;
    [ov addSubview:panel];
    NSUInteger i = 0;
    for (NSString *ident in ids) {
        HSApp *a = nil; for (HSApp *x in self.apps) if ([x.bundleID isEqualToString:ident]) a = x;
        if (!a) continue;
        HSIcon *ai = [[HSIcon alloc] initWithApp:a size:s label:YES];
        ai.frame = CGRectMake((i % 3) * cell + (cell - s) / 2, 24 + (i / 3) * (s + 40), s, s + 22);
        [ai addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        [panel addSubview:ai];
        i++;
    }
    [self.view addSubview:ov];
    folder_view = ov;
    ov.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ ov.alpha = 1; }];
    NSLog(@"SpringBoard: opened folder “%@” (%lu apps)", icon.folder[@"folder"], (unsigned long)i);
}
- (void)closeFolder {
    if (!folder_view) return;
    [folder_view removeFromSuperview]; folder_view = nil;
}
@end
