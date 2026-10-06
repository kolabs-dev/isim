#pragma once
/* isim: UISearchBar, UISearchTextField, UISearchController (navigation-item integration, results updater,
   dimming, results controller). */
#import <UIKit/UIView.h>
#import <UIKit/UITextField.h>
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UISearchBar, UISearchController, UIColor, UIImage;

typedef NS_ENUM(NSUInteger, UISearchBarStyle) { UISearchBarStyleDefault, UISearchBarStyleProminent, UISearchBarStyleMinimal } NS_SWIFT_NAME(UISearchBar.Style);

NS_SWIFT_UI_ACTOR
@protocol UISearchBarDelegate <NSObject>
@optional
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar;
- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar;
- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar;
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText;
- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text;
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar;
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope;
@end

/* the rounded field inside a search bar (magnifying glass, placeholder, clear button) */
NS_SWIFT_UI_ACTOR
@interface UISearchTextField : UITextField
@end

NS_SWIFT_UI_ACTOR
@interface UISearchBar : UIView <UITextInputTraits>
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, nonatomic, weak) id<UISearchBarDelegate> delegate;
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSString *placeholder;
@property (nullable, nonatomic, copy) NSString *prompt;
@property (nonatomic) BOOL showsCancelButton;
- (void)setShowsCancelButton:(BOOL)showsCancelButton animated:(BOOL)animated;
@property (nonatomic) BOOL showsBookmarkButton;
@property (nonatomic) BOOL showsSearchResultsButton;
@property (nonatomic) UISearchBarStyle searchBarStyle;
@property (nullable, nonatomic, strong) UIColor *barTintColor;
@property (nonatomic, getter=isTranslucent) BOOL translucent;
@property (nonatomic, readonly) UISearchTextField *searchTextField;
@property (nullable, nonatomic, copy) NSArray<NSString *> *scopeButtonTitles;
@property (nonatomic) NSInteger selectedScopeButtonIndex;
@property (nonatomic) BOOL showsScopeBar;
- (void)setShowsScope:(BOOL)show animated:(BOOL)animated;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic) UITextAutocapitalizationType autocapitalizationType;
@property (nonatomic) UITextAutocorrectionType autocorrectionType;
@property (nonatomic) UITextSpellCheckingType spellCheckingType;
@property (nonatomic) UIKeyboardType keyboardType;
@property (nonatomic) UIKeyboardAppearance keyboardAppearance;
@property (nonatomic) UIReturnKeyType returnKeyType;
@property (nonatomic) BOOL enablesReturnKeyAutomatically;
@property (nonatomic, getter=isSecureTextEntry) BOOL secureTextEntry;
@property (null_unspecified, nonatomic, copy) UITextContentType textContentType;
@end

NS_SWIFT_UI_ACTOR
@protocol UISearchResultsUpdating <NSObject>
@required
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController;
@end

NS_SWIFT_UI_ACTOR
@protocol UISearchControllerDelegate <NSObject>
@optional
- (void)willPresentSearchController:(UISearchController *)searchController NS_SWIFT_NAME(willPresentSearchController(_:));
- (void)didPresentSearchController:(UISearchController *)searchController NS_SWIFT_NAME(didPresentSearchController(_:));
- (void)willDismissSearchController:(UISearchController *)searchController NS_SWIFT_NAME(willDismissSearchController(_:));
- (void)didDismissSearchController:(UISearchController *)searchController NS_SWIFT_NAME(didDismissSearchController(_:));
- (void)presentSearchController:(UISearchController *)searchController NS_SWIFT_NAME(presentSearchController(_:));
@end

/* isim: in a navigation item the search bar sits below the title (collapsing on scroll when
   hidesSearchBarWhenScrolling); when active it moves to the top (the navigation bar hides), shows Cancel,
   dims the content (obscuresBackgroundDuringPresentation) and shows the results controller once text is typed. */
NS_SWIFT_UI_ACTOR
@interface UISearchController : UIViewController
- (instancetype)initWithSearchResultsController:(nullable UIViewController *)searchResultsController;
@property (nullable, nonatomic, weak) id<UISearchResultsUpdating> searchResultsUpdater;
@property (nonatomic, getter=isActive) BOOL active;
@property (nullable, nonatomic, weak) id<UISearchControllerDelegate> delegate;
@property (nonatomic) BOOL obscuresBackgroundDuringPresentation;
@property (nonatomic) BOOL dimsBackgroundDuringPresentation;
@property (nonatomic) BOOL hidesNavigationBarDuringPresentation;
@property (nullable, nonatomic, readonly, strong) UIViewController *searchResultsController;
@property (nonatomic, readonly, strong) UISearchBar *searchBar;
@property (nonatomic) BOOL automaticallyShowsCancelButton;
@property (nonatomic) BOOL automaticallyShowsSearchResultsController;
@property (nonatomic) BOOL showsSearchResultsController;
@property (nonatomic) BOOL automaticallyShowsScopeBar;
@end
NS_ASSUME_NONNULL_END
