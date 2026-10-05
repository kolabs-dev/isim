#pragma once
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor;
@interface UISwitch : UIControl
@property (nullable, nonatomic, strong) UIColor *onTintColor;
@property (nullable, nonatomic, strong) UIColor *thumbTintColor;
@property (nonatomic, getter=isOn) BOOL on;
- (void)setOn:(BOOL)on animated:(BOOL)animated;
@end
NS_ASSUME_NONNULL_END
