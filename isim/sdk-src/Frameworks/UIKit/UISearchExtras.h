#pragma once
/* isim: search members from the documentation sweep (#9): search tokens in the search text field, the search bar's
   icon images, bookmark and results list buttons and legacy images, the scope bar's activation, attributed
   suggestions and the search container view controller. UISearch.m. Categories (no ivars). */
#import <UIKit/UISearchBar.h>
#import <UIKit/UINavigationController.h>
NS_ASSUME_NONNULL_BEGIN

/* a token (an icon and a title) at the start of the search text field (iOS 13): a tinted capsule before the text;
   Delete with the insertion point at the start removes the last one */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UISearchToken : NSObject
+ (UISearchToken *)tokenWithIcon:(nullable UIImage *)icon text:(NSString *)text NS_SWIFT_NAME(init(icon:text:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, strong) id representedObject;
@end
@class NSItemProvider;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@protocol UISearchTextFieldDelegate <UITextFieldDelegate>
@optional
- (NSItemProvider *)searchTextField:(UISearchTextField *)searchTextField itemProviderForCopyingToken:(UISearchToken *)token;
- (void)searchTextField:(UISearchTextField *)searchTextField didSelectSuggestion:(id<UISearchSuggestion>)suggestion API_AVAILABLE(ios(16.0));
@end
@interface UISearchTextField (UISearchTextFieldTokens)
@property (nonatomic, copy) NSArray<UISearchToken *> *tokens API_AVAILABLE(ios(13.0));
- (void)insertToken:(UISearchToken *)token atIndex:(NSInteger)tokenIndex;
- (void)removeTokenAtIndex:(NSInteger)tokenIndex;
/* the tokens sit before the text: the text is the textual range, every token's position is the start */
- (UITextPosition *)positionOfTokenAtIndex:(NSInteger)tokenIndex;
- (NSArray<UISearchToken *> *)tokensInRange:(UITextRange *)textRange;
@property (nonatomic, readonly) UITextRange *textualRange;
- (void)replaceTextualPortionOfRange:(UITextRange *)textRange withToken:(UISearchToken *)token atIndex:(NSInteger)tokenIndex;
@property (null_resettable, nonatomic, strong) UIColor *tokenBackgroundColor;     /* default: the tint colour */
@property (nonatomic) BOOL allowsDeletingTokens;                                  /* default YES */
@property (nonatomic) BOOL allowsCopyingTokens;                                   /* default YES (isim: stored) */
@end

typedef NS_ENUM(NSInteger, UISearchBarIcon) { UISearchBarIconSearch, UISearchBarIconClear, UISearchBarIconBookmark,
    UISearchBarIconResultsList } NS_SWIFT_NAME(UISearchBar.Icon);
@interface UISearchBar (UISearchBarExtras)
/* the icons: the search icon is drawn in the field, the bookmark / results list ones on their buttons */
- (void)setImage:(nullable UIImage *)iconImage forSearchBarIcon:(UISearchBarIcon)icon state:(UIControlState)state;
- (nullable UIImage *)imageForSearchBarIcon:(UISearchBarIcon)icon state:(UIControlState)state;
- (void)setPositionAdjustment:(UIOffset)adjustment forSearchBarIcon:(UISearchBarIcon)icon;
- (UIOffset)positionAdjustmentForSearchBarIcon:(UISearchBarIcon)icon;
/* the results list button (shown with showsSearchResultsButton) can be selected */
@property (nonatomic, getter=isSearchResultsButtonSelected) BOOL searchResultsButtonSelected;
- (void)setShowsScopeBar:(BOOL)show animated:(BOOL)animate NS_SWIFT_NAME(setShowsScope(_:animated:));
/* legacy images and offsets (stored; the scope bar's title attributes go to its segmented control) */
- (void)setBackgroundImage:(nullable UIImage *)backgroundImage forBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics;
- (nullable UIImage *)backgroundImageForBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics;
- (void)setSearchFieldBackgroundImage:(nullable UIImage *)backgroundImage forState:(UIControlState)state;
- (nullable UIImage *)searchFieldBackgroundImageForState:(UIControlState)state;
@property (nonatomic) UIOffset searchFieldBackgroundPositionAdjustment;
@property (nonatomic) UIOffset searchTextPositionAdjustment;
@property (nullable, nonatomic, strong) UIImage *scopeBarBackgroundImage;
- (void)setScopeBarButtonBackgroundImage:(nullable UIImage *)backgroundImage forState:(UIControlState)state;
- (nullable UIImage *)scopeBarButtonBackgroundImageForState:(UIControlState)state;
- (void)setScopeBarButtonDividerImage:(nullable UIImage *)dividerImage forLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState;
- (nullable UIImage *)scopeBarButtonDividerImageForLeftSegmentState:(UIControlState)leftState rightSegmentState:(UIControlState)rightState;
- (void)setScopeBarButtonTitleTextAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attributes forState:(UIControlState)state;
- (nullable NSDictionary<NSAttributedStringKey, id> *)scopeBarButtonTitleTextAttributesForState:(UIControlState)state;
/* visionOS look-to-dictate (stored) */
@property (nonatomic, getter=isLookToDictateEnabled) BOOL lookToDictateEnabled API_AVAILABLE(ios(17.0));
@end

/* when the scope bar shows: automatic (the old automaticallyShowsScopeBar), never on its own (manual), once text is
   typed, or as soon as the search is active */
typedef NS_ENUM(NSInteger, UISearchControllerScopeBarActivation) { UISearchControllerScopeBarActivationAutomatic, UISearchControllerScopeBarActivationManual,
    UISearchControllerScopeBarActivationOnTextEntry, UISearchControllerScopeBarActivationOnSearchActivation }
    NS_SWIFT_NAME(UISearchController.ScopeBarActivation) API_AVAILABLE(ios(16.0));
@interface UISearchController (UISearchControllerExtras)
@property (nonatomic) UISearchControllerScopeBarActivation scopeBarActivation API_AVAILABLE(ios(16.0));
/* suggestions are not shown under a stacked search bar (isim: stored) */
@property (nonatomic) BOOL ignoresSearchSuggestionsForSearchBarPlacementStacked API_AVAILABLE(ios(16.0));
@end

/* attributed suggestions (iOS 16): the attributed text wins over the plain one */
@interface UISearchSuggestionItem (UISearchSuggestionItemAttributed)
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion NS_SWIFT_UNAVAILABLE("use init");
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(nullable NSString *)description NS_SWIFT_UNAVAILABLE("use init");
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(nullable NSString *)description iconImage:(nullable UIImage *)iconImage NS_SWIFT_UNAVAILABLE("use init");
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion;
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(nullable NSString *)description;
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)suggestion localizedDescription:(nullable NSString *)description iconImage:(nullable UIImage *)iconImage;
@property (nullable, nonatomic, readonly) NSAttributedString *localizedAttributedSuggestion;
@end

/* a container for a search controller (iOS 9): the search bar at the top of its view and the results below */
NS_SWIFT_UI_ACTOR
@interface UISearchContainerViewController : UIViewController
- (instancetype)initWithSearchController:(UISearchController *)searchController;
@property (nonatomic, readonly, strong) UISearchController *searchController;
@end
NS_ASSUME_NONNULL_END
