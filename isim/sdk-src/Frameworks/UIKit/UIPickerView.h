#pragma once
/* isim: UIPickerView — spinning wheels (drag, fling, tap a row), data source / delegate. */
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIPickerView;

NS_SWIFT_UI_ACTOR
@protocol UIPickerViewDataSource <NSObject>
@required
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView;
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component;
@end

NS_SWIFT_UI_ACTOR
@protocol UIPickerViewDelegate <NSObject>
@optional
- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component;
- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component;
- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component;
- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(nullable UIView *)view;
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component;
@end

NS_SWIFT_UI_ACTOR
@interface UIPickerView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
@property (nullable, nonatomic, weak) id<UIPickerViewDataSource> dataSource;
@property (nullable, nonatomic, weak) id<UIPickerViewDelegate> delegate;
@property (nonatomic) BOOL showsSelectionIndicator;
@property (nonatomic, readonly) NSInteger numberOfComponents;
- (NSInteger)numberOfRowsInComponent:(NSInteger)component;
- (CGSize)rowSizeForComponent:(NSInteger)component;
- (nullable UIView *)viewForRow:(NSInteger)row forComponent:(NSInteger)component;
- (void)reloadAllComponents;
- (void)reloadComponent:(NSInteger)component;
- (void)selectRow:(NSInteger)row inComponent:(NSInteger)component animated:(BOOL)animated;
- (NSInteger)selectedRowInComponent:(NSInteger)component;
@end
NS_ASSUME_NONNULL_END
