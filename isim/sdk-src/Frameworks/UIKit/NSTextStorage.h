#pragma once
/* isim SDK: TextKit 1 (self-authored, API-compatible names): NSTextStorage, NSTextContainer, NSLayoutManager.
 * Adapted: isim lays text out with Pango, one layout per paragraph (its paragraph style: alignment, line and
 * paragraph spacing, indents). A glyph is a UTF-16 unit of the string (glyph index == character index), so glyph
 * ranges equal character ranges; CGGlyph values come from the font (isim's CoreText). A layout manager uses its
 * first text container (others get no text); exclusion paths are stored, not applied. Text tables / blocks
 * (NSTextBlock) are not laid out by TextKit (labels and string drawing show them). */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/NSAttributedString.h>
NS_ASSUME_NONNULL_BEGIN
@class NSLayoutManager, NSTextContainer, NSTextLayoutManager, NSTextStorage, UIFont, UIColor, UIBezierPath, UIView, UITextView;
@protocol NSTextStorageObserving;

typedef NS_OPTIONS(NSUInteger, NSTextStorageEditActions) {
    NSTextStorageEditedAttributes = (1 << 0),
    NSTextStorageEditedCharacters = (1 << 1),
} NS_SWIFT_NAME(NSTextStorage.EditActions);

@protocol NSTextStorageDelegate <NSObject>
@optional
- (void)textStorage:(NSTextStorage *)textStorage willProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
@end

UIKIT_EXTERN NSNotificationName const NSTextStorageWillProcessEditingNotification NS_SWIFT_NAME(NSTextStorage.willProcessEditingNotification);
UIKIT_EXTERN NSNotificationName const NSTextStorageDidProcessEditingNotification NS_SWIFT_NAME(NSTextStorage.didProcessEditingNotification);

/* an attributed string that tells its layout managers (and observer) about edits */
@interface NSTextStorage : NSMutableAttributedString
@property (readonly, copy) NSArray<NSLayoutManager *> *layoutManagers;
- (void)addLayoutManager:(NSLayoutManager *)aLayoutManager;
- (void)removeLayoutManager:(NSLayoutManager *)aLayoutManager;
@property (readonly) NSTextStorageEditActions editedMask;
@property (readonly) NSRange editedRange;
@property (readonly) NSInteger changeInLength;
@property (nullable, weak) id<NSTextStorageDelegate> delegate;
- (void)edited:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;
- (void)processEditing;
@property (readonly) BOOL fixesAttributesLazily;
- (void)invalidateAttributesInRange:(NSRange)range;
- (void)ensureAttributesAreFixedInRange:(NSRange)range;
@property (nullable, weak) id<NSTextStorageObserving> textStorageObserver API_AVAILABLE(ios(15.0));
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextStorageObserving <NSObject>
@property (nullable, weak) NSTextStorage *textStorage;
- (void)processEditingForTextStorage:(NSTextStorage *)textStorage edited:(NSTextStorageEditActions)editMask range:(NSRange)newCharRange
                      changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange;
- (void)performEditingTransactionForTextStorage:(NSTextStorage *)textStorage usingBlock:(void (NS_NOESCAPE ^)(void))transaction;
@end

/* ---------------- NSTextContainer ---------------- */
@interface NSTextContainer : NSObject <NSSecureCoding>
- (instancetype)initWithSize:(CGSize)size NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nullable, assign) NSLayoutManager *layoutManager;
- (void)replaceLayoutManager:(NSLayoutManager *)newLayoutManager;
@property (weak, nullable) NSTextLayoutManager *textLayoutManager API_AVAILABLE(ios(15.0));
@property CGSize size;
@property (copy) NSArray<UIBezierPath *> *exclusionPaths;
@property NSLineBreakMode lineBreakMode;
@property CGFloat lineFragmentPadding;
@property NSUInteger maximumNumberOfLines;
- (CGRect)lineFragmentRectForProposedRect:(CGRect)proposedRect atIndex:(NSUInteger)characterIndex writingDirection:(NSWritingDirection)baseWritingDirection
                            remainingRect:(nullable CGRect *)remainingRect;
@property (getter=isSimpleRectangularTextContainer, readonly) BOOL simpleRectangularTextContainer;
@property BOOL widthTracksTextView;
@property BOOL heightTracksTextView;
@end

/* ---------------- NSLayoutManager ---------------- */
typedef NS_ENUM(NSInteger, NSTextLayoutOrientation) {
    NSTextLayoutOrientationHorizontal = 0, NSTextLayoutOrientationVertical = 1,
} NS_SWIFT_NAME(NSLayoutManager.TextLayoutOrientation);
typedef NS_OPTIONS(NSInteger, NSGlyphProperty) {
    NSGlyphPropertyNull = (1 << 0), NSGlyphPropertyControlCharacter = (1 << 1), NSGlyphPropertyElastic = (1 << 2), NSGlyphPropertyNonBaseCharacter = (1 << 3)
} NS_SWIFT_NAME(NSLayoutManager.GlyphProperty);
typedef NS_OPTIONS(NSInteger, NSControlCharacterAction) {
    NSControlCharacterActionZeroAdvancement = (1 << 0), NSControlCharacterActionWhitespace = (1 << 1), NSControlCharacterActionHorizontalTab = (1 << 2),
    NSControlCharacterActionLineBreak = (1 << 3), NSControlCharacterActionParagraphBreak = (1 << 4), NSControlCharacterActionContainerBreak = (1 << 5)
} NS_SWIFT_NAME(NSLayoutManager.ControlCharacterAction);

@protocol NSLayoutManagerDelegate <NSObject>
@optional
- (void)layoutManagerDidInvalidateLayout:(NSLayoutManager *)sender;
- (void)layoutManager:(NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer:(nullable NSTextContainer *)textContainer atEnd:(BOOL)layoutFinishedFlag;
- (void)layoutManager:(NSLayoutManager *)layoutManager textContainer:(NSTextContainer *)textContainer didChangeGeometryFromSize:(CGSize)oldSize;
- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager lineSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(CGRect)rect;
- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager paragraphSpacingBeforeGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(CGRect)rect;
- (CGFloat)layoutManager:(NSLayoutManager *)layoutManager paragraphSpacingAfterGlyphAtIndex:(NSUInteger)glyphIndex withProposedLineFragmentRect:(CGRect)rect;
- (NSUInteger)layoutManager:(NSLayoutManager *)layoutManager shouldGenerateGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props
           characterIndexes:(const NSUInteger *)charIndexes font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange;
- (NSControlCharacterAction)layoutManager:(NSLayoutManager *)layoutManager shouldUseAction:(NSControlCharacterAction)action forControlCharacterAtIndex:(NSUInteger)charIndex;
- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldBreakLineByWordBeforeCharacterAtIndex:(NSUInteger)charIndex;
- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldBreakLineByHyphenatingBeforeCharacterAtIndex:(NSUInteger)charIndex;
- (CGRect)layoutManager:(NSLayoutManager *)layoutManager boundingBoxForControlGlyphAtIndex:(NSUInteger)glyphIndex forTextContainer:(NSTextContainer *)textContainer
   proposedLineFragment:(CGRect)proposedRect glyphPosition:(CGPoint)glyphPosition characterIndex:(NSUInteger)charIndex;
- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldSetLineFragmentRect:(inout CGRect *)lineFragmentRect lineFragmentUsedRect:(inout CGRect *)lineFragmentUsedRect
       baselineOffset:(inout CGFloat *)baselineOffset inTextContainer:(NSTextContainer *)textContainer forGlyphRange:(NSRange)glyphRange;
@end

@interface NSLayoutManager : NSObject <NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nullable, assign) NSTextStorage *textStorage;
@property (nullable, weak) id<NSLayoutManagerDelegate> delegate;
@property (readonly) NSArray<NSTextContainer *> *textContainers;
- (void)addTextContainer:(NSTextContainer *)container;
- (void)insertTextContainer:(NSTextContainer *)container atIndex:(NSUInteger)index;
- (void)removeTextContainerAtIndex:(NSUInteger)index;
- (void)textContainerChangedGeometry:(NSTextContainer *)container;
@property BOOL showsInvisibleCharacters;
@property BOOL showsControlCharacters;
@property BOOL usesFontLeading;
@property BOOL allowsNonContiguousLayout;
@property (readonly) BOOL hasNonContiguousLayout;
@property BOOL limitsLayoutForSuspiciousContents API_AVAILABLE(ios(12.0));
@property BOOL usesDefaultHyphenation API_AVAILABLE(ios(13.0));

/* invalidation */
- (void)invalidateGlyphsForCharacterRange:(NSRange)charRange changeInLength:(NSInteger)delta actualCharacterRange:(nullable NSRangePointer)actualCharRange;
- (void)invalidateLayoutForCharacterRange:(NSRange)charRange actualCharacterRange:(nullable NSRangePointer)actualCharRange;
- (void)invalidateDisplayForCharacterRange:(NSRange)charRange;
- (void)invalidateDisplayForGlyphRange:(NSRange)glyphRange;
- (void)processEditingForTextStorage:(NSTextStorage *)textStorage edited:(NSTextStorageEditActions)editMask range:(NSRange)newCharRange
                      changeInLength:(NSInteger)delta invalidatedRange:(NSRange)invalidatedCharRange;
- (void)ensureGlyphsForCharacterRange:(NSRange)charRange;
- (void)ensureGlyphsForGlyphRange:(NSRange)glyphRange;
- (void)ensureLayoutForCharacterRange:(NSRange)charRange;
- (void)ensureLayoutForGlyphRange:(NSRange)glyphRange;
- (void)ensureLayoutForTextContainer:(NSTextContainer *)container;
- (void)ensureLayoutForBoundingRect:(CGRect)bounds inTextContainer:(NSTextContainer *)container;

/* glyphs (one per UTF-16 unit) */
@property (readonly) NSUInteger numberOfGlyphs;
- (CGGlyph)CGGlyphAtIndex:(NSUInteger)glyphIndex isValidIndex:(nullable BOOL *)isValidIndex;
- (CGGlyph)CGGlyphAtIndex:(NSUInteger)glyphIndex;
- (BOOL)isValidGlyphIndex:(NSUInteger)glyphIndex;
- (NSGlyphProperty)propertyForGlyphAtIndex:(NSUInteger)glyphIndex;
- (NSUInteger)getGlyphsInRange:(NSRange)glyphRange glyphs:(nullable CGGlyph *)glyphBuffer properties:(nullable NSGlyphProperty *)props
              characterIndexes:(nullable NSUInteger *)charIndexBuffer bidiLevels:(nullable unsigned char *)bidiLevelBuffer;
- (void)setGlyphs:(const CGGlyph *)glyphs properties:(const NSGlyphProperty *)props characterIndexes:(const NSUInteger *)charIndexes
             font:(UIFont *)aFont forGlyphRange:(NSRange)glyphRange;
- (NSUInteger)characterIndexForGlyphAtIndex:(NSUInteger)glyphIndex;
- (NSUInteger)glyphIndexForCharacterAtIndex:(NSUInteger)charIndex;
- (NSRange)glyphRangeForCharacterRange:(NSRange)charRange actualCharacterRange:(nullable NSRangePointer)actualCharRange;
- (NSRange)characterRangeForGlyphRange:(NSRange)glyphRange actualGlyphRange:(nullable NSRangePointer)actualGlyphRange;

/* layout results (setters: isim lays out on its own; they are accepted and ignored) */
- (void)setTextContainer:(NSTextContainer *)container forGlyphRange:(NSRange)glyphRange;
- (void)setLineFragmentRect:(CGRect)fragmentRect forGlyphRange:(NSRange)glyphRange usedRect:(CGRect)usedRect;
- (void)setExtraLineFragmentRect:(CGRect)fragmentRect usedRect:(CGRect)usedRect textContainer:(NSTextContainer *)container;
- (void)setLocation:(CGPoint)location forStartOfGlyphRange:(NSRange)glyphRange;
- (void)setNotShownAttribute:(BOOL)flag forGlyphAtIndex:(NSUInteger)glyphIndex;
- (void)setDrawsOutsideLineFragment:(BOOL)flag forGlyphAtIndex:(NSUInteger)glyphIndex;
- (void)setAttachmentSize:(CGSize)attachmentSize forGlyphRange:(NSRange)glyphRange;
- (void)getFirstUnlaidCharacterIndex:(nullable NSUInteger *)charIndex glyphIndex:(nullable NSUInteger *)glyphIndex;
- (NSUInteger)firstUnlaidCharacterIndex;
- (NSUInteger)firstUnlaidGlyphIndex;
- (nullable NSTextContainer *)textContainerForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange;
- (nullable NSTextContainer *)textContainerForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange withoutAdditionalLayout:(BOOL)flag;
- (CGRect)usedRectForTextContainer:(NSTextContainer *)container;
- (CGRect)lineFragmentRectForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange;
- (CGRect)lineFragmentRectForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange withoutAdditionalLayout:(BOOL)flag;
- (CGRect)lineFragmentUsedRectForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange;
- (CGRect)lineFragmentUsedRectForGlyphAtIndex:(NSUInteger)glyphIndex effectiveRange:(nullable NSRangePointer)effectiveGlyphRange withoutAdditionalLayout:(BOOL)flag;
@property (readonly) CGRect extraLineFragmentRect;
@property (readonly) CGRect extraLineFragmentUsedRect;
@property (nullable, readonly) NSTextContainer *extraLineFragmentTextContainer;
- (CGPoint)locationForGlyphAtIndex:(NSUInteger)glyphIndex;
- (BOOL)notShownAttributeForGlyphAtIndex:(NSUInteger)glyphIndex;
- (BOOL)drawsOutsideLineFragmentForGlyphAtIndex:(NSUInteger)glyphIndex;
- (CGSize)attachmentSizeForGlyphAtIndex:(NSUInteger)glyphIndex;
- (NSRange)truncatedGlyphRangeInLineFragmentForGlyphAtIndex:(NSUInteger)glyphIndex;

/* queries */
- (NSRange)glyphRangeForTextContainer:(NSTextContainer *)container;
- (NSRange)rangeOfNominallySpacedGlyphsContainingIndex:(NSUInteger)glyphIndex;
- (CGRect)boundingRectForGlyphRange:(NSRange)glyphRange inTextContainer:(NSTextContainer *)container;
- (NSRange)glyphRangeForBoundingRect:(CGRect)bounds inTextContainer:(NSTextContainer *)container;
- (NSRange)glyphRangeForBoundingRectWithoutAdditionalLayout:(CGRect)bounds inTextContainer:(NSTextContainer *)container;
- (NSUInteger)glyphIndexForPoint:(CGPoint)point inTextContainer:(NSTextContainer *)container fractionOfDistanceThroughGlyph:(nullable CGFloat *)partialFraction;
- (NSUInteger)glyphIndexForPoint:(CGPoint)point inTextContainer:(NSTextContainer *)container;
- (CGFloat)fractionOfDistanceThroughGlyphForPoint:(CGPoint)point inTextContainer:(NSTextContainer *)container;
- (NSUInteger)characterIndexForPoint:(CGPoint)point inTextContainer:(NSTextContainer *)container fractionOfDistanceBetweenInsertionPoints:(nullable CGFloat *)partialFraction;
- (NSUInteger)getLineFragmentInsertionPointsForCharacterAtIndex:(NSUInteger)charIndex alternatePositions:(BOOL)aFlag inDisplayOrder:(BOOL)dFlag
                                                      positions:(nullable CGFloat *)positions characterIndexes:(nullable NSUInteger *)charIndexes;
- (void)enumerateLineFragmentsForGlyphRange:(NSRange)glyphRange
                                 usingBlock:(void (NS_NOESCAPE ^)(CGRect rect, CGRect usedRect, NSTextContainer *textContainer, NSRange glyphRange, BOOL *stop))block;
- (void)enumerateEnclosingRectsForGlyphRange:(NSRange)glyphRange withinSelectedGlyphRange:(NSRange)selectedRange inTextContainer:(NSTextContainer *)textContainer
                                  usingBlock:(void (NS_NOESCAPE ^)(CGRect rect, BOOL *stop))block;

/* drawing (the current graphics context; origin: the container's origin) */
- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin;
- (void)drawGlyphsForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin;
- (void)showCGGlyphs:(const CGGlyph *)glyphs positions:(const CGPoint *)positions count:(NSInteger)glyphCount font:(UIFont *)font
          textMatrix:(CGAffineTransform)textMatrix attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes inContext:(CGContextRef)CGContext API_AVAILABLE(ios(13.0));
- (void)fillBackgroundRectArray:(const CGRect *)rectArray count:(NSUInteger)rectCount forCharacterRange:(NSRange)charRange color:(UIColor *)color;
- (void)drawUnderlineForGlyphRange:(NSRange)glyphRange underlineType:(NSUnderlineStyle)underlineVal baselineOffset:(CGFloat)baselineOffset
                  lineFragmentRect:(CGRect)lineRect lineFragmentGlyphRange:(NSRange)lineGlyphRange containerOrigin:(CGPoint)containerOrigin;
- (void)underlineGlyphRange:(NSRange)glyphRange underlineType:(NSUnderlineStyle)underlineVal lineFragmentRect:(CGRect)lineRect
     lineFragmentGlyphRange:(NSRange)lineGlyphRange containerOrigin:(CGPoint)containerOrigin;
- (void)drawStrikethroughForGlyphRange:(NSRange)glyphRange strikethroughType:(NSUnderlineStyle)strikethroughVal baselineOffset:(CGFloat)baselineOffset
                      lineFragmentRect:(CGRect)lineRect lineFragmentGlyphRange:(NSRange)lineGlyphRange containerOrigin:(CGPoint)containerOrigin;
- (void)strikethroughGlyphRange:(NSRange)glyphRange strikethroughType:(NSUnderlineStyle)strikethroughVal lineFragmentRect:(CGRect)lineRect
         lineFragmentGlyphRange:(NSRange)lineGlyphRange containerOrigin:(CGPoint)containerOrigin;
@end
NS_ASSUME_NONNULL_END
