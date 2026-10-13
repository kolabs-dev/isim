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
/* what VoiceOver says for a component (wheel) */
NS_SWIFT_UI_ACTOR
@protocol UIPickerViewAccessibilityDelegate <UIPickerViewDelegate>
@optional
- (nullable NSString *)pickerView:(UIPickerView *)pickerView accessibilityLabelForComponent:(NSInteger)component;
- (nullable NSString *)pickerView:(UIPickerView *)pickerView accessibilityHintForComponent:(NSInteger)component;
- (NSArray<NSString *> *)pickerView:(UIPickerView *)pickerView accessibilityUserInputLabelsForComponent:(NSInteger)component API_AVAILABLE(ios(13.0));
- (nullable NSAttributedString *)pickerView:(UIPickerView *)pickerView accessibilityAttributedLabelForComponent:(NSInteger)component API_AVAILABLE(ios(11.0));
- (nullable NSAttributedString *)pickerView:(UIPickerView *)pickerView accessibilityAttributedHintForComponent:(NSInteger)component API_AVAILABLE(ios(11.0));
- (NSArray<NSAttributedString *> *)pickerView:(UIPickerView *)pickerView accessibilityAttributedUserInputLabelsForComponent:(NSInteger)component API_AVAILABLE(ios(13.0));
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
