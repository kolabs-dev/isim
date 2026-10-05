#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIFont, UIColor;
typedef NS_ENUM(NSInteger, NSTextAlignment) { NSTextAlignmentLeft = 0, NSTextAlignmentCenter = 1, NSTextAlignmentRight = 2, NSTextAlignmentJustified = 3, NSTextAlignmentNatural = 4 };
typedef NS_ENUM(NSInteger, NSLineBreakMode) { NSLineBreakByWordWrapping = 0, NSLineBreakByCharWrapping, NSLineBreakByClipping, NSLineBreakByTruncatingHead, NSLineBreakByTruncatingTail, NSLineBreakByTruncatingMiddle };
@interface UILabel : UIView
@property (nullable, nonatomic, copy) NSString *text;
@property (null_resettable, nonatomic, strong) UIFont *font;
@property (null_resettable, nonatomic, strong) UIColor *textColor;
@property (nonatomic) NSTextAlignment textAlignment;
@property (nonatomic) NSLineBreakMode lineBreakMode;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nullable, nonatomic, strong) UIColor *highlightedTextColor;
@property (nonatomic) NSInteger numberOfLines;
@property (nonatomic) BOOL adjustsFontSizeToFitWidth;
@property (nonatomic) CGFloat minimumScaleFactor;
@property (nonatomic) CGFloat preferredMaxLayoutWidth;
@property (nonatomic) BOOL adjustsFontForContentSizeCategory;
- (CGRect)textRectForBounds:(CGRect)bounds limitedToNumberOfLines:(NSInteger)numberOfLines;
- (void)drawTextInRect:(CGRect)rect;
@end
NS_ASSUME_NONNULL_END
