#pragma once
/* isim: find and replace (iOS 16, #9): UIFindInteraction and its find navigator (a bar above the keyboard: the
   search field with the result count, previous / next, an options menu and Done; with replacement a second row with
   Replace and All), UIFindSession, UITextSearchingFindSession over a UITextSearching object, the aggregator and the
   search options. Text views have it built in (isFindInteractionEnabled; Cmd+F, Cmd+G, Shift+Cmd+G, Option+Cmd+F).
   Script: tap the navigator's views by identifier — isim-find-field, isim-find-count, isim-find-previous,
   isim-find-next, isim-find-done, isim-find-replace-field, isim-find-replace, isim-find-replace-all. UIFindInteraction.m. */
#import <UIKit/UIView.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UITextInput.h>
#import <UIKit/UIMoreControls.h>
#import <UIKit/UITextView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFindInteraction, UIFindSession, UITextSearchOptions;

typedef NS_ENUM(NSInteger, UITextSearchFoundTextStyle) {
    UITextSearchFoundTextStyleNormal, UITextSearchFoundTextStyleFound, UITextSearchFoundTextStyleHighlighted,
} API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, UITextSearchMatchMethod) {
    UITextSearchMatchMethodContains, UITextSearchMatchMethodStartsWith, UITextSearchMatchMethodFullWord,
} NS_SWIFT_NAME(UITextSearchOptions.WordMatchMethod) API_AVAILABLE(ios(16.0));
/* how a search compares: the navigator's options menu (Match Case, Contains / Starts With / Whole Words) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UITextSearchOptions : NSObject
@property (nonatomic, readonly) UITextSearchMatchMethod wordMatchMethod;
@property (nonatomic, readonly) NSStringCompareOptions stringCompareOptions;
@end

typedef id UITextSearchDocumentIdentifier API_AVAILABLE(ios(16.0));
/* collects a search's results (the searchable object reports each range, then finishedSearching) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0)) NS_SWIFT_NAME(__UITextSearchAggregator)
@protocol UITextSearchAggregator <NSObject>
@property (nonatomic, readonly, copy) NSOrderedSet<UITextRange *> *allFoundRanges;
- (void)foundRange:(UITextRange *)range forSearchString:(NSString *)string inDocument:(nullable UITextSearchDocumentIdentifier)document
    NS_SWIFT_NAME(foundRange(_:searchString:document:));
- (void)invalidateFoundRange:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document
    NS_SWIFT_NAME(invalidateFoundRange(_:document:));
- (void)invalidate;
- (void)finishedSearching;
@end
/* something searchable: it searches, decorates found ranges, and may replace them */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0)) NS_SWIFT_NAME(__UITextSearching)
@protocol UITextSearching <NSObject>
@property (nullable, nonatomic, readonly) UITextRange *selectedTextRange;
- (NSComparisonResult)compareFoundRange:(UITextRange *)foundRange toRange:(UITextRange *)toRange inDocument:(nullable UITextSearchDocumentIdentifier)document
    NS_SWIFT_NAME(compare(_:toRange:document:));
- (void)performTextSearchWithQueryString:(NSString *)string usingOptions:(UITextSearchOptions *)options resultAggregator:(id<UITextSearchAggregator>)aggregator
    NS_SWIFT_NAME(performTextSearch(queryString:options:resultAggregator:));
- (void)decorateFoundTextRange:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document usingStyle:(UITextSearchFoundTextStyle)style
    NS_SWIFT_NAME(decorate(foundTextRange:document:usingStyle:));
- (void)clearAllDecoratedFoundText;
@optional
@property (nonatomic, readonly) BOOL supportsTextReplacement;
- (BOOL)shouldReplaceFoundTextInRange:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document withText:(NSString *)replacementText
    NS_SWIFT_NAME(shouldReplace(foundTextRange:document:withText:));
- (void)replaceFoundTextInRange:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document withText:(NSString *)replacementText
    NS_SWIFT_NAME(replace(foundTextRange:document:withText:));
- (void)replaceAllOccurrencesOfQueryString:(NSString *)queryString usingOptions:(UITextSearchOptions *)options withText:(NSString *)replacementText
    NS_SWIFT_NAME(replaceAll(queryString:options:withText:));
- (void)willHighlightFoundTextRange:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document
    NS_SWIFT_NAME(willHighlight(foundTextRange:document:));
- (void)scrollRangeToVisible:(UITextRange *)range inDocument:(nullable UITextSearchDocumentIdentifier)document
    NS_SWIFT_NAME(scrollRangeToVisible(_:inDocument:));
@property (nullable, nonatomic, readonly) UITextSearchDocumentIdentifier selectedTextSearchDocument;
- (NSComparisonResult)compareOrderFromDocument:(UITextSearchDocumentIdentifier)fromDocument toDocument:(UITextSearchDocumentIdentifier)toDocument
    NS_SWIFT_NAME(compareOrder(fromDocument:toDocument:));
@end

typedef NS_ENUM(NSInteger, UIFindSessionSearchResultDisplayStyle) {
    UIFindSessionSearchResultDisplayStyleCurrentAndTotal, UIFindSessionSearchResultDisplayStyleTotal, UIFindSessionSearchResultDisplayStyleNone,
} NS_SWIFT_NAME(UIFindSession.SearchResultDisplayStyle) API_AVAILABLE(ios(16.0));
/* a find session (subclass it for your own search, or use UITextSearchingFindSession) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UIFindSession : NSObject
@property (nonatomic, readonly) NSInteger resultCount;
@property (nonatomic, readonly) NSInteger highlightedResultIndex;
@property (nonatomic) UIFindSessionSearchResultDisplayStyle searchResultDisplayStyle;
@property (nonatomic, readonly) BOOL supportsReplacement;
@property (nonatomic, readonly) BOOL allowsReplacementForCurrentlyHighlightedResult;
- (void)performSearchWithQuery:(NSString *)query options:(nullable UITextSearchOptions *)options NS_SWIFT_NAME(performSearch(query:options:));
- (void)performSingleReplacementWithSearchQuery:(NSString *)searchQuery replacementString:(NSString *)replacementString options:(nullable UITextSearchOptions *)options
    NS_SWIFT_NAME(performSingleReplacement(query:replacementString:options:));
- (void)replaceAllInstancesOfSearchQuery:(NSString *)searchQuery withReplacementString:(NSString *)replacementString options:(nullable UITextSearchOptions *)options
    NS_SWIFT_NAME(replaceAll(searchQuery:replacementString:options:));
- (void)highlightNextResultInDirection:(UITextStorageDirection)direction NS_SWIFT_NAME(highlightNextResult(in:));
- (void)invalidateFoundResults;
@end
/* a session over a UITextSearching object: it searches, decorates, highlights and replaces through it */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UITextSearchingFindSession : UIFindSession
- (instancetype)initWithSearchableObject:(id<UITextSearching>)searchableObject;
@property (nonatomic, weak, readonly, nullable) id<UITextSearching> searchableObject;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@protocol UIFindInteractionDelegate <NSObject>
- (nullable UIFindSession *)findInteraction:(UIFindInteraction *)interaction sessionForView:(UIView *)view;
@optional
- (void)findInteraction:(UIFindInteraction *)interaction didBeginFindSession:(UIFindSession *)session NS_SWIFT_NAME(findInteraction(_:didBegin:));
- (void)findInteraction:(UIFindInteraction *)interaction didEndFindSession:(UIFindSession *)session NS_SWIFT_NAME(findInteraction(_:didEnd:));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(16.0))
@interface UIFindInteraction : NSObject <UIInteraction>
- (instancetype)initWithSessionDelegate:(id<UIFindInteractionDelegate>)sessionDelegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, weak, readonly) id<UIFindInteractionDelegate> delegate;
@property (nonatomic, readonly, getter=isFindNavigatorVisible) BOOL findNavigatorVisible;
@property (nonatomic, readonly, nullable) UIFindSession *activeFindSession;
@property (nonatomic, copy, nullable) NSString *searchText;
@property (nonatomic, copy, nullable) NSString *replacementText;
/* extra options in the navigator's menu (it gets the system's) */
@property (nonatomic, copy, nullable) UIMenu *_Nullable (^optionsMenuProvider)(NSArray<UIMenuElement *> *defaultOptions);
- (void)presentFindNavigatorShowingReplace:(BOOL)showingReplace NS_SWIFT_NAME(presentFindNavigator(showingReplace:));
- (void)dismissFindNavigator;
- (void)findNext;
- (void)findPrevious;
- (void)updateResultCount;
@end

/* built into text views */
@interface UITextView (UIFindInteraction) <UITextSearching>
@property (nonatomic, getter=isFindInteractionEnabled) BOOL findInteractionEnabled API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, nullable) UIFindInteraction *findInteraction API_AVAILABLE(ios(16.0));
@end
NS_ASSUME_NONNULL_END
