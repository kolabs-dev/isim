#pragma once
/* isim: UIRefreshControl — pull to refresh on any UIScrollView (UITableView, UICollectionView). */
#import <UIKit/UIControl.h>
#import <UIKit/UIScrollView.h>
#import <UIKit/UITableView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor;

NS_SWIFT_UI_ACTOR
@interface UIRefreshControl : UIControl
- (instancetype)init;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;
/* drawn centred under the spinner (13 pt, the secondary label colour where the string sets none) */
@property (nullable, nonatomic, strong) NSAttributedString *attributedTitle UI_APPEARANCE_SELECTOR;
- (void)beginRefreshing;
- (void)endRefreshing;
@end

@interface UIScrollView (UIRefreshControl)
@property (nullable, nonatomic, strong) UIRefreshControl *refreshControl;
@end
@interface UITableViewController (UIRefreshControl)
@property (nullable, nonatomic, strong) UIRefreshControl *refreshControl;
@end
NS_ASSUME_NONNULL_END
