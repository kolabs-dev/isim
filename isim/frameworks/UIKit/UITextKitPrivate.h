/* isim's TextKit engine: the layout shared by NSLayoutManager (TextKit 1), NSTextLayoutManager (TextKit 2) and
 * UITextView. A string is laid out paragraph by paragraph, each paragraph one Pango layout with its paragraph style
 * (alignment, line spacing, spacing before / after, head / first line / tail indents); text attachments are inline
 * boxes. Coordinates are the text container's: lines start at the line fragment padding. */
#import "UIKitPrivate.h"
#import <UIKit/NSTextStorage.h>
#import <UIKit/NSTextAttachment.h>
#import <UIKit/NSTextLayoutManager.h>
NS_ASSUME_NONNULL_BEGIN

/* a line fragment: its characters (the last line of a paragraph includes the separator), the fragment rect (the
   container's width), the used rect (its text plus padding) and its baseline (from the rect's top) */
@interface __IsimTextLine : NSObject {
@public
    NSRange range;
    CGRect rect, used;
    CGFloat baseline;
}
@end

/* an attachment placed in the layout (container coordinates) */
@interface __IsimTextAttachmentSlot : NSObject {
@public
    NSUInteger index;
    CGRect frame;
}
@property (nonatomic, strong) NSTextAttachment *attachment;
@end

@interface __IsimTextPara : NSObject {
@public
    NSRange range;          /* its characters, separator included */
    NSRange content;        /* without the separator */
    CGFloat y, height;      /* the paragraph's block, spacing before and after included */
    CGFloat textX, textY;   /* where its Pango layout sits */
    void *tl;               /* the Pango layout (host) */
    NSData *u2b;            /* UTF-16 index -> UTF-8 byte offset (length + 1 entries) */
}
@property (nonatomic, copy) NSArray<__IsimTextLine *> *lines;
@property (nonatomic, copy) NSArray<__IsimTextAttachmentSlot *> *attachments;
@property (nonatomic, strong) NSAttributedString *string;   /* its characters (content) */
@end

@interface __IsimTextEngine : NSObject
/* width <= 0 or huge: no wrapping. maxLines 0: no limit */
- (instancetype)initWithString:(NSAttributedString *)string width:(CGFloat)width padding:(CGFloat)padding font:(nullable UIFont *)font
                         color:(nullable UIColor *)color maxLines:(NSUInteger)maxLines;
/* extraLine NO: no extra line fragment after a final paragraph separator (TextKit 2 paragraphs) */
- (instancetype)initWithString:(NSAttributedString *)string width:(CGFloat)width padding:(CGFloat)padding font:(nullable UIFont *)font
                         color:(nullable UIColor *)color maxLines:(NSUInteger)maxLines extraLine:(BOOL)extraLine;
@property (nonatomic, readonly) NSAttributedString *string;
@property (nonatomic, readonly) NSArray<__IsimTextPara *> *paragraphs;
@property (nonatomic, readonly) NSArray<__IsimTextLine *> *lines;          /* all, in order */
@property (nonatomic, readonly) CGRect usedRect;                           /* the union of the used rects (extra line included) */
@property (nonatomic, readonly) CGFloat height;                            /* down to the last line (extra line included) */
@property (nonatomic, readonly) CGRect extraLineRect, extraLineUsedRect;   /* empty without an extra line fragment */
@property (nonatomic, readonly) NSUInteger laidLength;                     /* characters laid out (maxLines can stop early) */
@property (nonatomic, readonly) CGFloat width, padding;
- (nullable __IsimTextLine *)lineForIndex:(NSUInteger)index;
- (nullable __IsimTextPara *)paragraphForIndex:(NSUInteger)index;
/* the insertion point before a character (the text's end: after the last one) */
- (CGRect)caretRectForIndex:(NSUInteger)index;
/* the rect a character covers */
- (CGRect)rectForCharacterAtIndex:(NSUInteger)index;
/* the character under a point (fraction: how far through it the point is) and the nearest insertion point */
- (NSUInteger)characterIndexForPoint:(CGPoint)p fraction:(nullable CGFloat *)fraction;
- (NSUInteger)insertionIndexForPoint:(CGPoint)p;
/* one rect per line covering a range (selection highlighting) */
- (NSArray<NSValue *> *)rectsForRange:(NSRange)range;
- (CGRect)boundingRectForRange:(NSRange)range;
/* draws the paragraphs of a range at the container origin (whole lines); attachments with views are skipped */
- (void)drawRange:(NSRange)range atPoint:(CGPoint)origin skipAttachmentViews:(BOOL)skip;
@property (nonatomic, readonly) NSArray<__IsimTextAttachmentSlot *> *attachments;
@end

/* the size of an attachment in a line: its bounds, else its image's size */
CGRect isim_ui_attachment_bounds(NSTextAttachment *a);

/* a TextKit 2 location: an offset into the content storage */
@interface __IsimTextLocation : NSObject <NSTextLocation, NSCopying>
@property (nonatomic, readonly) NSInteger offset;
+ (instancetype)at:(NSInteger)offset;
@end
NSInteger isim_tk_offset(id<NSTextLocation> _Nullable location);
NSTextRange *isim_tk_range(NSRange r);
NSRange isim_tk_nsrange(NSTextRange *_Nullable r);
/* TextKit 2 internals UITextView uses */
@interface NSTextLayoutManager (IsimTextView)
- (__IsimTextEngine *)_isim_engine;
- (NSArray<NSTextLayoutFragment *> *)_isimFragments;
/* a fragment's attachment view providers: reused ones (reuse(attachment) YES) or new */
- (NSArray<NSTextAttachmentViewProvider *> *)_isimProvidersFor:(NSTextLayoutFragment *)f parentView:(nullable UIView *)parent
                                                          reuse:(BOOL (^_Nullable)(NSTextAttachment *attachment))reuse;
- (void)_isimDropProviderCache;
@end
@interface NSLayoutManager (IsimTextView)
- (__IsimTextEngine *)_isim_engine;
@end
NS_ASSUME_NONNULL_END
