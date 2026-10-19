#pragma once
/* isim SDK (self-authored): AXCustomContent — extra information about an accessibility element (a label and a value),
 * which VoiceOver reads after the element (high importance) or on request (More Content in the rotor). */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, AXCustomContentImportance) {
    AXCustomContentImportanceDefault,
    AXCustomContentImportanceHigh,
} NS_SWIFT_NAME(AXCustomContent.Importance) API_AVAILABLE(ios(14.0));

API_AVAILABLE(ios(14.0))
@interface AXCustomContent : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)customContentWithLabel:(NSString *)label value:(NSString *)value;
+ (instancetype)customContentWithAttributedLabel:(NSAttributedString *)label attributedValue:(NSAttributedString *)value;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, copy, readonly) NSString *label;
@property (nonatomic, copy, readonly) NSAttributedString *attributedLabel;
@property (nonatomic, copy, readonly) NSString *value;
@property (nonatomic, copy, readonly) NSAttributedString *attributedValue;
@property (nonatomic, assign) AXCustomContentImportance importance;
@end

typedef NSArray<AXCustomContent *> *_Nullable (^AXCustomContentReturnBlock)(void);

API_AVAILABLE(ios(14.0))
@protocol AXCustomContentProvider <NSObject>
@property (nonatomic, copy, null_unspecified) NSArray<AXCustomContent *> *accessibilityCustomContent;
@optional
@property (nonatomic, copy, nullable) AXCustomContentReturnBlock accessibilityCustomContentBlock API_AVAILABLE(ios(17.0));
@end

NS_ASSUME_NONNULL_END
