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
    NSTextBlockValueTypeAbsolute = 0,
    NSTextBlockValueTypePercentage = 1,
} NS_SWIFT_NAME(NSTextBlock.ValueType);
typedef NS_ENUM(NSUInteger, NSTextBlockDimension) {
    NSTextBlockDimensionWidth = 0,
    NSTextBlockDimensionMinimumWidth = 1,
    NSTextBlockDimensionMaximumWidth = 2,
    NSTextBlockDimensionHeight = 4,
    NSTextBlockDimensionMinimumHeight = 5,
    NSTextBlockDimensionMaximumHeight = 6,
} NS_SWIFT_NAME(NSTextBlock.Dimension);
typedef NS_ENUM(NSInteger, NSTextBlockLayer) {
    NSTextBlockLayerPadding = -1,
    NSTextBlockLayerBorder = 0,
    NSTextBlockLayerMargin = 1,
} NS_SWIFT_NAME(NSTextBlock.Layer);
typedef NS_ENUM(NSUInteger, NSTextBlockVerticalAlignment) {
    NSTextBlockVerticalAlignmentTop = 0,
    NSTextBlockVerticalAlignmentMiddle = 1,
    NSTextBlockVerticalAlignmentBottom = 2,
    NSTextBlockVerticalAlignmentBaseline = 3,
} NS_SWIFT_NAME(NSTextBlock.VerticalAlignment);
typedef NS_ENUM(NSUInteger, NSTextTableLayoutAlgorithm) {
    NSTextTableLayoutAlgorithmAutomatic = 0,
    NSTextTableLayoutAlgorithmFixed = 1,
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
- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer rectEdge:(CGRectEdge)edge API_AVAILABLE(ios(27.0));
- (CGFloat)widthForLayer:(NSTextBlockLayer)layer rectEdge:(CGRectEdge)edge API_AVAILABLE(ios(27.0));
- (NSTextBlockValueType)widthValueTypeForLayer:(NSTextBlockLayer)layer rectEdge:(CGRectEdge)edge API_AVAILABLE(ios(27.0));
@property NSTextBlockVerticalAlignment verticalAlignment;
@property (nullable, copy) UIColor *backgroundColor;
- (void)setBorderColor:(nullable UIColor *)color;
- (void)setBorderColor:(nullable UIColor *)color rectEdge:(CGRectEdge)edge API_AVAILABLE(ios(27.0));
- (nullable UIColor *)borderColorForRectEdge:(CGRectEdge)edge NS_SWIFT_NAME(borderColor(for:)) API_AVAILABLE(ios(27.0));
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
