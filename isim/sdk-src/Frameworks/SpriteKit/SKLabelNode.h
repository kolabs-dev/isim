#pragma once
/* isim SpriteKit: text labels (drawn with Core Text: any installed or bundled font). */
#import <SpriteKit/SKNode.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, SKLabelVerticalAlignmentMode) {
    SKLabelVerticalAlignmentModeBaseline = 0, SKLabelVerticalAlignmentModeCenter, SKLabelVerticalAlignmentModeTop, SKLabelVerticalAlignmentModeBottom
};
typedef NS_ENUM(NSInteger, SKLabelHorizontalAlignmentMode) {
    SKLabelHorizontalAlignmentModeCenter = 0, SKLabelHorizontalAlignmentModeLeft, SKLabelHorizontalAlignmentModeRight
};
@interface SKLabelNode : SKNode
+ (instancetype)labelNodeWithText:(nullable NSString *)text;
+ (instancetype)labelNodeWithAttributedText:(nullable NSAttributedString *)attributedText;
+ (instancetype)labelNodeWithFontNamed:(nullable NSString *)fontName;
- (instancetype)initWithFontNamed:(nullable NSString *)fontName;
@property (nonatomic) SKLabelVerticalAlignmentMode verticalAlignmentMode;
@property (nonatomic) SKLabelHorizontalAlignmentMode horizontalAlignmentMode;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;
@property (nonatomic, copy, nullable) NSString *fontName;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSAttributedString *attributedText;
@property (nonatomic) CGFloat fontSize;
@property (nonatomic, retain, nullable) UIColor *fontColor;
@property (nonatomic) CGFloat colorBlendFactor;
@property (nonatomic, retain, nullable) UIColor *color;
@property (nonatomic) SKBlendMode blendMode;
@end
NS_ASSUME_NONNULL_END
#endif
