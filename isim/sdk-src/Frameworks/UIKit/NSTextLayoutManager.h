#pragma once
/* isim SDK: TextKit 2 (self-authored, API-compatible names): locations and ranges, content storage, paragraphs,
 * the layout manager with its layout and line fragments, the viewport layout controller, selections, and text
 * attachment view providers. Adapted: a location is an offset into the content storage's attributed string;
 * a paragraph is one layout fragment laid out by Pango (isim's TextKit 1 engine), with its line fragments.
 * The viewport layout controller lays out the fragments that intersect the delegate's viewport bounds. */
#import <UIKit/NSTextStorage.h>
#import <UIKit/NSTextAttachment.h>
NS_ASSUME_NONNULL_BEGIN
@class NSTextContentManager, NSTextContentStorage, NSTextElement, NSTextParagraph, NSTextLayoutManager, NSTextLayoutFragment,
    NSTextLineFragment, NSTextViewportLayoutController, NSTextSelection, NSTextSelectionNavigation, NSTextAttachmentViewProvider;

/* ---------------- locations and ranges ---------------- */
API_AVAILABLE(ios(15.0))
@protocol NSTextLocation <NSObject>
- (NSComparisonResult)compare:(id<NSTextLocation>)location;
@end

API_AVAILABLE(ios(15.0))
@interface NSTextRange : NSObject
- (nullable instancetype)initWithLocation:(id<NSTextLocation>)location endLocation:(nullable id<NSTextLocation>)endLocation NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithLocation:(id<NSTextLocation>)location;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (getter=isEmpty, readonly) BOOL empty;
@property (strong, readonly) id<NSTextLocation> location;
@property (strong, readonly) id<NSTextLocation> endLocation;
- (BOOL)isEqualToTextRange:(NSTextRange *)textRange;
- (BOOL)containsLocation:(id<NSTextLocation>)location;
- (BOOL)containsRange:(NSTextRange *)textRange;
- (BOOL)intersectsWithTextRange:(NSTextRange *)textRange;
- (nullable NSTextRange *)textRangeByIntersectingWithTextRange:(NSTextRange *)textRange;
- (NSTextRange *)textRangeByFormingUnionWithTextRange:(NSTextRange *)textRange;
@end

/* ---------------- elements ---------------- */
API_AVAILABLE(ios(15.0))
@interface NSTextElement : NSObject
- (instancetype)initWithTextContentManager:(nullable NSTextContentManager *)textContentManager NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nullable, weak) NSTextContentManager *textContentManager;
@property (nullable, strong) NSTextRange *elementRange;
@property (readonly, copy) NSArray<__kindof NSTextElement *> *childElements API_AVAILABLE(ios(16.0));
@property (nullable, readonly, weak) NSTextElement *parentElement API_AVAILABLE(ios(16.0));
@property (readonly) BOOL isRepresentedElement API_AVAILABLE(ios(16.0));
@end

API_AVAILABLE(ios(15.0))
@interface NSTextParagraph : NSTextElement
- (instancetype)initWithAttributedString:(nullable NSAttributedString *)attributedString NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithTextContentManager:(nullable NSTextContentManager *)textContentManager NS_UNAVAILABLE;
@property (strong, readonly) NSAttributedString *attributedString;
@property (nullable, strong, readonly) NSTextRange *paragraphContentRange;
@property (nullable, strong, readonly) NSTextRange *paragraphSeparatorRange;
@end

/* ---------------- content managers ---------------- */
typedef NS_OPTIONS(NSUInteger, NSTextContentManagerEnumerationOptions) {
    NSTextContentManagerEnumerationOptionsNone = 0, NSTextContentManagerEnumerationOptionsReverse = (1 << 0),
} NS_SWIFT_NAME(NSTextContentManager.EnumerationOptions) API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@protocol NSTextElementProvider <NSObject>
@property (strong, readonly) NSTextRange *documentRange;
- (nullable id<NSTextLocation>)enumerateTextElementsFromLocation:(nullable id<NSTextLocation>)textLocation options:(NSTextContentManagerEnumerationOptions)options
                                                       usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block;
- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(nullable NSArray<NSTextElement *> *)textElements;
- (void)synchronizeToBackingStore:(nullable void (^)(NSError *_Nullable error))completionHandler;
@optional
- (nullable id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset NS_SWIFT_NAME(location(_:offsetBy:));
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to;
- (nullable NSTextRange *)adjustedRangeFromRange:(NSTextRange *)textRange forEditingTextSelection:(BOOL)forEditingTextSelection;
@end

@protocol NSTextContentManagerDelegate;
API_AVAILABLE(ios(15.0))
@interface NSTextContentManager : NSObject <NSTextElementProvider, NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nullable, weak) id<NSTextContentManagerDelegate> delegate;
@property (readonly, copy) NSArray<NSTextLayoutManager *> *textLayoutManagers;
- (void)addTextLayoutManager:(NSTextLayoutManager *)textLayoutManager;
- (void)removeTextLayoutManager:(NSTextLayoutManager *)textLayoutManager;
@property (nullable, strong) NSTextLayoutManager *primaryTextLayoutManager;
- (void)synchronizeTextLayoutManagers:(nullable void (^)(NSError *_Nullable error))completionHandler;
- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range;
@property (readonly) BOOL hasEditingTransaction;
- (void)performEditingTransactionUsingBlock:(void (NS_NOESCAPE ^)(void))transaction;
- (void)recordEditActionInRange:(NSTextRange *)originalTextRange newTextRange:(NSTextRange *)newTextRange;
@property BOOL automaticallySynchronizesTextLayoutManagers;
@property BOOL automaticallySynchronizesToBackingStore;
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextContentManagerDelegate <NSObject>
@optional
- (nullable NSTextElement *)textContentManager:(NSTextContentManager *)textContentManager textElementAtLocation:(id<NSTextLocation>)location;
- (BOOL)textContentManager:(NSTextContentManager *)textContentManager shouldEnumerateTextElement:(NSTextElement *)textElement options:(NSTextContentManagerEnumerationOptions)options;
@end

@protocol NSTextContentStorageDelegate;
API_AVAILABLE(ios(15.0))
@interface NSTextContentStorage : NSTextContentManager <NSTextStorageObserving>
@property (nullable, weak) id<NSTextContentStorageDelegate> delegate;
@property (nullable, copy) NSAttributedString *attributedString;
- (nullable NSAttributedString *)attributedStringForTextElement:(NSTextElement *)textElement;
- (nullable NSTextElement *)textElementForAttributedString:(NSAttributedString *)attributedString;
- (nullable id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset NS_SWIFT_NAME(location(_:offsetBy:));
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to;
- (nullable NSTextRange *)adjustedRangeFromRange:(NSTextRange *)textRange forEditingTextSelection:(BOOL)forEditingTextSelection;
@property BOOL includesTextListMarkers API_AVAILABLE(ios(26.0));
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextContentStorageDelegate <NSTextContentManagerDelegate>
@optional
- (nullable NSTextParagraph *)textContentStorage:(NSTextContentStorage *)textContentStorage textParagraphWithRange:(NSRange)range;
@end

/* ---------------- layout ---------------- */
typedef NS_ENUM(NSUInteger, NSTextLayoutFragmentState) {
    NSTextLayoutFragmentStateNone = 0, NSTextLayoutFragmentStateEstimatedUsageBounds = 1, NSTextLayoutFragmentStateCalculatedUsageBounds = 2,
    NSTextLayoutFragmentStateLayoutAvailable = 3,
} NS_SWIFT_NAME(NSTextLayoutFragment.State) API_AVAILABLE(ios(15.0));
typedef NS_OPTIONS(NSUInteger, NSTextLayoutFragmentEnumerationOptions) {
    NSTextLayoutFragmentEnumerationOptionsNone = 0, NSTextLayoutFragmentEnumerationOptionsReverse = (1 << 0),
    NSTextLayoutFragmentEnumerationOptionsEstimatesSize = (1 << 1), NSTextLayoutFragmentEnumerationOptionsEnsuresLayout = (1 << 2),
    NSTextLayoutFragmentEnumerationOptionsEnsuresExtraLineFragment = (1 << 3),
} NS_SWIFT_NAME(NSTextLayoutFragment.EnumerationOptions) API_AVAILABLE(ios(15.0));
typedef NS_ENUM(NSInteger, NSTextLayoutManagerSegmentType) {
    NSTextLayoutManagerSegmentTypeStandard = 0, NSTextLayoutManagerSegmentTypeSelection = 1, NSTextLayoutManagerSegmentTypeHighlight = 2,
} NS_SWIFT_NAME(NSTextLayoutManager.SegmentType) API_AVAILABLE(ios(15.0));
typedef NS_OPTIONS(NSUInteger, NSTextLayoutManagerSegmentOptions) {
    NSTextLayoutManagerSegmentOptionsNone = 0, NSTextLayoutManagerSegmentOptionsRangeNotRequired = (1 << 0),
    NSTextLayoutManagerSegmentOptionsMiddleFragmentsExcluded = (1 << 1), NSTextLayoutManagerSegmentOptionsHeadSegmentExtended = (1 << 2),
    NSTextLayoutManagerSegmentOptionsTailSegmentExtended = (1 << 3), NSTextLayoutManagerSegmentOptionsUpstreamAffinity = (1 << 4),
} NS_SWIFT_NAME(NSTextLayoutManager.SegmentOptions) API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface NSTextLineFragment : NSObject <NSSecureCoding>
- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString range:(NSRange)range NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes range:(NSRange)range;
- (instancetype)init NS_UNAVAILABLE;
@property (strong, readonly) NSAttributedString *attributedString;
@property (readonly) NSRange characterRange;
@property (readonly) CGRect typographicBounds;
@property (readonly) CGPoint glyphOrigin;
- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)context;
- (CGPoint)locationForCharacterAtIndex:(NSInteger)index;
- (NSInteger)characterIndexForPoint:(CGPoint)point;
- (CGFloat)fractionOfDistanceThroughGlyphForPoint:(CGPoint)point;
@end

API_AVAILABLE(ios(15.0))
@interface NSTextLayoutFragment : NSObject <NSSecureCoding>
- (instancetype)initWithTextElement:(NSTextElement *)textElement range:(nullable NSTextRange *)rangeInElement NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nullable, weak, readonly) NSTextLayoutManager *textLayoutManager;
@property (readonly, strong) NSTextElement *textElement;
@property (readonly, strong) NSTextRange *rangeInElement;
@property (readonly, copy) NSArray<NSTextLineFragment *> *textLineFragments;
- (nullable NSTextLineFragment *)textLineFragmentForVerticalOffset:(CGFloat)verticalOffset requiresExactMatch:(BOOL)requiresExactMatch API_AVAILABLE(ios(17.0));
- (nullable NSTextLineFragment *)textLineFragmentForTextLocation:(id<NSTextLocation>)textLocation isUpstreamAffinity:(BOOL)isUpstreamAffinity API_AVAILABLE(ios(17.0));
@property (nullable, strong) NSOperationQueue *layoutQueue;
@property (readonly) NSTextLayoutFragmentState state;
- (void)invalidateLayout;
@property (readonly) CGRect layoutFragmentFrame;
@property (readonly) CGRect renderingSurfaceBounds;
@property (readonly) CGFloat leadingPadding;
@property (readonly) CGFloat trailingPadding;
@property (readonly) CGFloat topMargin;
@property (readonly) CGFloat bottomMargin;
- (void)drawAtPoint:(CGPoint)point inContext:(CGContextRef)context;
@property (readonly, copy) NSArray<NSTextAttachmentViewProvider *> *textAttachmentViewProviders;
- (CGRect)frameForTextAttachmentAtLocation:(id<NSTextLocation>)location;
@end

@protocol NSTextLayoutManagerDelegate;
@protocol NSTextSelectionDataSource;
API_AVAILABLE(ios(15.0))
@interface NSTextLayoutManager : NSObject <NSSecureCoding, NSTextSelectionDataSource>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nullable, weak) id<NSTextLayoutManagerDelegate> delegate;
@property BOOL usesFontLeading;
@property BOOL limitsLayoutForSuspiciousContents;
@property BOOL usesHyphenation;
@property BOOL resolvesNaturalAlignmentWithBaseWritingDirection API_AVAILABLE(ios(26.0));
@property (nullable, weak, readonly) NSTextContentManager *textContentManager;
- (void)replaceTextContentManager:(NSTextContentManager *)textContentManager;
@property (nullable, strong) NSTextContainer *textContainer;
@property (readonly) CGRect usageBoundsForTextContainer;
@property (readonly, strong) NSTextViewportLayoutController *textViewportLayoutController;
@property (nullable, strong) NSOperationQueue *layoutQueue;
- (void)ensureLayoutForRange:(NSTextRange *)range;
- (void)ensureLayoutForBounds:(CGRect)bounds;
- (void)invalidateLayoutForRange:(NSTextRange *)range;
- (nullable NSTextLayoutFragment *)textLayoutFragmentForPosition:(CGPoint)position;
- (nullable NSTextLayoutFragment *)textLayoutFragmentForLocation:(id<NSTextLocation>)location;
- (nullable id<NSTextLocation>)enumerateTextLayoutFragmentsFromLocation:(nullable id<NSTextLocation>)location options:(NSTextLayoutFragmentEnumerationOptions)options
                                                              usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextLayoutFragment *layoutFragment))block;
@property (strong) NSArray<NSTextSelection *> *textSelections;
@property (strong) NSTextSelectionNavigation *textSelectionNavigation;
- (void)enumerateRenderingAttributesFromLocation:(id<NSTextLocation>)location reverse:(BOOL)reverse
                                      usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextLayoutManager *textLayoutManager, NSDictionary<NSAttributedStringKey, id> *attributes, NSTextRange *textRange))block;
- (void)setRenderingAttributes:(NSDictionary<NSAttributedStringKey, id> *)renderingAttributes forTextRange:(NSTextRange *)textRange;
- (void)addRenderingAttribute:(NSAttributedStringKey)renderingAttribute value:(nullable id)value forTextRange:(NSTextRange *)textRange;
- (void)removeRenderingAttribute:(NSAttributedStringKey)renderingAttribute forTextRange:(NSTextRange *)textRange;
- (void)invalidateRenderingAttributesForTextRange:(NSTextRange *)textRange;
@property (nullable, copy) BOOL (^renderingAttributesValidator)(NSTextLayoutManager *textLayoutManager, NSTextLayoutFragment *textLayoutFragment);
@property (class, copy) NSDictionary<NSAttributedStringKey, id> *linkRenderingAttributes;
- (NSDictionary<NSAttributedStringKey, id> *)renderingAttributesForLink:(id)link atLocation:(id<NSTextLocation>)location;
- (void)enumerateTextSegmentsInRange:(NSTextRange *)textRange type:(NSTextLayoutManagerSegmentType)type options:(NSTextLayoutManagerSegmentOptions)options
                          usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextRange *_Nullable textSegmentRange, CGRect textSegmentFrame, CGFloat baselinePosition, NSTextContainer *textContainer))block;
- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)textElements;
- (void)replaceContentsInRange:(NSTextRange *)range withAttributedString:(NSAttributedString *)attributedString;
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextLayoutManagerDelegate <NSObject>
@optional
- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager textLayoutFragmentForLocation:(id<NSTextLocation>)location inTextElement:(NSTextElement *)textElement;
- (BOOL)textLayoutManager:(NSTextLayoutManager *)textLayoutManager shouldBreakLineBeforeLocation:(id<NSTextLocation>)location hyphenating:(BOOL)hyphenating;
- (NSDictionary<NSAttributedStringKey, id> *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager renderingAttributesForLink:(id)link atLocation:(id<NSTextLocation>)location
                                              defaultAttributes:(NSDictionary<NSAttributedStringKey, id> *)renderingAttributes;
/* iOS 27: a view provider is about to be discarded (cache it), and a cached one for an attachment */
- (void)textLayoutManager:(NSTextLayoutManager *)textLayoutManager cacheTextAttachmentViewProvider:(NSTextAttachmentViewProvider *)viewProvider
        forTextAttachment:(NSTextAttachment *)textAttachment API_AVAILABLE(ios(27.0));
- (nullable NSTextAttachmentViewProvider *)textLayoutManager:(NSTextLayoutManager *)textLayoutManager
          retrieveCachedTextAttachmentViewProviderForTextAttachment:(NSTextAttachment *)attachment API_AVAILABLE(ios(27.0));
@end

/* ---------------- viewport ---------------- */
/* iOS 27: a view or layer drawing a layout fragment, and the key it is cached under (a layout fragment or a string) */
API_AVAILABLE(ios(27.0))
@protocol NSTextViewportRenderingSurface <NSObject>
@end
API_AVAILABLE(ios(27.0))
@protocol NSTextViewportRenderingSurfaceKey <NSObject>
@end
@interface NSTextLayoutFragment (NSTextViewportRenderingSurfaceKey) <NSTextViewportRenderingSurfaceKey>
@end
@interface NSString (NSTextViewportRenderingSurfaceKey) <NSTextViewportRenderingSurfaceKey>
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextViewportLayoutControllerDelegate <NSObject>
@required
- (CGRect)viewportBoundsForTextViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController;
- (void)textViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController configureRenderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)textLayoutFragment;
@optional
- (void)textViewportLayoutControllerWillLayout:(NSTextViewportLayoutController *)textViewportLayoutController;
- (void)textViewportLayoutControllerDidLayout:(NSTextViewportLayoutController *)textViewportLayoutController;
- (void)textViewportLayoutControllerReceivedSetNeedsLayout:(NSTextViewportLayoutController *)textViewportLayoutController;
- (void)textViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController cacheRenderingSurface:(id<NSTextViewportRenderingSurface>)renderingSurface
                              forKey:(id<NSTextViewportRenderingSurfaceKey>)renderingSurfaceKey API_AVAILABLE(ios(27.0));
- (nullable id<NSTextViewportRenderingSurface>)textViewportLayoutController:(NSTextViewportLayoutController *)textViewportLayoutController
                                     retrieveCachedRenderingSurfaceForKey:(id<NSTextViewportRenderingSurfaceKey>)renderingSurfaceKey API_AVAILABLE(ios(27.0));
@end

API_AVAILABLE(ios(15.0))
@interface NSTextViewportLayoutController : NSObject
- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)textLayoutManager NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, weak) id<NSTextViewportLayoutControllerDelegate> delegate;
@property (weak, readonly) NSTextLayoutManager *textLayoutManager;
@property (readonly) CGRect viewportBounds;
@property (nullable, readonly) NSTextRange *viewportRange;
- (void)layoutViewport;
- (CGFloat)relocateViewportToTextLocation:(id<NSTextLocation>)textLocation;
- (void)adjustViewportByVerticalOffset:(CGFloat)verticalOffset;
@end

/* ---------------- selections ---------------- */
typedef NS_ENUM(NSInteger, NSTextSelectionGranularity) {
    NSTextSelectionGranularityCharacter, NSTextSelectionGranularityWord, NSTextSelectionGranularityParagraph, NSTextSelectionGranularityLine,
    NSTextSelectionGranularitySentence
} NS_SWIFT_NAME(NSTextSelection.Granularity) API_AVAILABLE(ios(15.0));
typedef NS_ENUM(NSInteger, NSTextSelectionAffinity) {
    NSTextSelectionAffinityUpstream = 0, NSTextSelectionAffinityDownstream = 1
} NS_SWIFT_NAME(NSTextSelection.Affinity) API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface NSTextSelection : NSObject <NSSecureCoding>
- (instancetype)initWithRanges:(NSArray<NSTextRange *> *)textRanges affinity:(NSTextSelectionAffinity)affinity granularity:(NSTextSelectionGranularity)granularity NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithRange:(NSTextRange *)range affinity:(NSTextSelectionAffinity)affinity granularity:(NSTextSelectionGranularity)granularity;
- (instancetype)initWithLocation:(id<NSTextLocation>)location affinity:(NSTextSelectionAffinity)affinity;
- (instancetype)init NS_UNAVAILABLE;
@property (strong, readonly) NSArray<NSTextRange *> *textRanges;
@property (readonly) NSTextSelectionGranularity granularity;
@property (readonly) NSTextSelectionAffinity affinity;
@property (getter=isTransient, readonly) BOOL transient;
@property CGFloat anchorPositionOffset;
@property (getter=isLogical) BOOL logical;
@property (nullable, strong, readonly) id<NSTextLocation> secondarySelectionLocation;
@property (copy) NSDictionary<NSAttributedStringKey, id> *typingAttributes;
- (NSTextSelection *)textSelectionWithTextRanges:(NSArray<NSTextRange *> *)textRanges;
@end

/* the data a selection navigation works on (NSTextLayoutManager adopts it); isim: the navigation itself (moving
   and extending selections) is not implemented yet (#154) */
API_AVAILABLE(ios(15.0))
@protocol NSTextSelectionDataSource <NSObject>
@property (strong, readonly) NSTextRange *documentRange;
@end
API_AVAILABLE(ios(15.0))
@interface NSTextSelectionNavigation : NSObject
- (instancetype)initWithDataSource:(id<NSTextSelectionDataSource>)dataSource NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (weak, readonly) id<NSTextSelectionDataSource> textSelectionDataSource;
@property BOOL allowsNonContiguousRanges;
@property BOOL rotatesCoordinateSystemForLayoutOrientation;
- (void)flushLayoutCache;
@end
NS_ASSUME_NONNULL_END
