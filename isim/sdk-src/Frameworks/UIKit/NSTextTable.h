#pragma once
/* Text blocks and tables in attributed strings (public in UIKit with iOS 27; Apple's documentation lists iOS 6).
   A paragraph's NSParagraphStyle.textBlocks puts it in a block (margin, border, padding, background) or in a table
   cell (NSTextTableBlock). isim (adapted): UILabel, CATextLayer and NSAttributedString drawing / boundingRect lay the
   blocks out in a box model of their own (not TextKit's); table columns are as wide as their cells ask
   (absolute / percentage), the rest shared by content width (automatic) or equally (fixed). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGGeometry.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor;
typedef NS_ENUM(NSUInteger, NSTextBlockValueType) {
    NSTextBlockAbsoluteValueType NS_SWIFT_NAME(absolute) = 0,
    NSTextBlockPercentageValueType NS_SWIFT_NAME(percentage) = 1,
} NS_SWIFT_NAME(NSTextBlock.ValueType);
typedef NS_ENUM(NSUInteger, NSTextBlockDimension) {
    NSTextBlockWidth NS_SWIFT_NAME(width) = 0,
    NSTextBlockMinimumWidth NS_SWIFT_NAME(minimumWidth) = 1,
    NSTextBlockMaximumWidth NS_SWIFT_NAME(maximumWidth) = 2,
    NSTextBlockHeight NS_SWIFT_NAME(height) = 4,
    NSTextBlockMinimumHeight NS_SWIFT_NAME(minimumHeight) = 5,
    NSTextBlockMaximumHeight NS_SWIFT_NAME(maximumHeight) = 6,
} NS_SWIFT_NAME(NSTextBlock.Dimension);
typedef NS_ENUM(NSInteger, NSTextBlockLayer) {
    NSTextBlockPadding NS_SWIFT_NAME(padding) = -1,
    NSTextBlockBorder NS_SWIFT_NAME(border) = 0,
    NSTextBlockMargin NS_SWIFT_NAME(margin) = 1,
} NS_SWIFT_NAME(NSTextBlock.Layer);
typedef NS_ENUM(NSUInteger, NSTextBlockVerticalAlignment) {
    NSTextBlockTopAlignment NS_SWIFT_NAME(top) = 0,
    NSTextBlockMiddleAlignment NS_SWIFT_NAME(middle) = 1,
    NSTextBlockBottomAlignment NS_SWIFT_NAME(bottom) = 2,
    NSTextBlockBaselineAlignment NS_SWIFT_NAME(baseline) = 3,
} NS_SWIFT_NAME(NSTextBlock.VerticalAlignment);
typedef NS_ENUM(NSUInteger, NSTextTableLayoutAlgorithm) {
    NSTextTableAutomaticLayoutAlgorithm NS_SWIFT_NAME(automatic) = 0,
    NSTextTableFixedLayoutAlgorithm NS_SWIFT_NAME(fixed) = 1,
} NS_SWIFT_NAME(NSTextTable.LayoutAlgorithm);

NS_SWIFT_UI_ACTOR
@interface NSTextBlock : NSObject <NSSecureCoding, NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (void)setValue:(CGFloat)val type:(NSTextBlockValueType)type forDimension:(NSTextBlockDimension)dimension;
- (CGFloat)valueForDimension:(NSTextBlockDimension)dimension;
- (NSTextBlockValueType)valueTypeForDimension:(NSTextBlockDimension)dimension;
- (void)setContentWidth:(CGFloat)val type:(NSTextBlockValueType)type;
@property (readonly) CGFloat contentWidth;
@property (readonly) NSTextBlockValueType contentWidthValueType;
- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer;
- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer edge:(CGRectEdge)edge NS_SWIFT_NAME(setWidth(_:type:for:rectEdge:)) API_AVAILABLE(ios(27.0));
- (CGFloat)widthForLayer:(NSTextBlockLayer)layer edge:(CGRectEdge)edge NS_SWIFT_NAME(width(for:rectEdge:));
- (NSTextBlockValueType)widthValueTypeForLayer:(NSTextBlockLayer)layer edge:(CGRectEdge)edge NS_SWIFT_NAME(widthValueType(for:rectEdge:));
@property NSTextBlockVerticalAlignment verticalAlignment;
@property (nullable, copy) UIColor *backgroundColor;
- (void)setBorderColor:(nullable UIColor *)color;
- (void)setBorderColor:(nullable UIColor *)color forEdge:(CGRectEdge)edge NS_SWIFT_NAME(setBorderColor(_:rectEdge:)) API_AVAILABLE(ios(27.0));
- (nullable UIColor *)borderColorForEdge:(CGRectEdge)edge NS_SWIFT_NAME(borderColor(for:));
@end

NS_SWIFT_UI_ACTOR
@interface NSTextTable : NSTextBlock
@property NSUInteger numberOfColumns;
@property NSTextTableLayoutAlgorithm layoutAlgorithm;
@property BOOL collapsesBorders;
@property BOOL hidesEmptyCells;
@end

NS_SWIFT_UI_ACTOR
@interface NSTextTableBlock : NSTextBlock
- (instancetype)initWithTable:(NSTextTable *)table startingRow:(NSInteger)row rowSpan:(NSInteger)rowSpan startingColumn:(NSInteger)col columnSpan:(NSInteger)colSpan NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly) NSTextTable *table;
@property (readonly) NSInteger startingRow;
@property (readonly) NSInteger rowSpan;
@property (readonly) NSInteger startingColumn;
@property (readonly) NSInteger columnSpan;
@end
NS_ASSUME_NONNULL_END
