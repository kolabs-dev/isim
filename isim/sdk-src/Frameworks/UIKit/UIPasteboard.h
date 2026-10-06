#pragma once
/* isim: UIPasteboard. The general pasteboard is shared by the apps of an isim device (strings and URLs are
   stored in the device data directory); images and colors stay in the process. No paste permission prompt. */
#import <UIKit/UIKitDefines.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor;
typedef NSString *UIPasteboardName NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN UIPasteboardName const UIPasteboardNameGeneral;
UIKIT_EXTERN NSNotificationName const UIPasteboardChangedNotification NS_SWIFT_NAME(UIPasteboard.changedNotification);

NS_SWIFT_UI_ACTOR
@interface UIPasteboard : NSObject
@property (class, nonatomic, readonly) UIPasteboard *generalPasteboard NS_SWIFT_NAME(general);
+ (nullable UIPasteboard *)pasteboardWithName:(UIPasteboardName)pasteboardName create:(BOOL)create;
+ (UIPasteboard *)pasteboardWithUniqueName;
+ (void)removePasteboardWithName:(UIPasteboardName)pasteboardName;
@property (nonatomic, readonly) UIPasteboardName name;
@property (nonatomic, readonly) NSInteger changeCount;
@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nullable, nonatomic, copy) NSString *string;
@property (nullable, nonatomic, copy) NSArray<NSString *> *strings;
@property (nullable, nonatomic, copy) NSURL *URL;
@property (nullable, nonatomic, copy) NSArray<NSURL *> *URLs;
@property (nullable, nonatomic, copy) UIImage *image;
@property (nullable, nonatomic, copy) NSArray<UIImage *> *images;
@property (nullable, nonatomic, copy) UIColor *color;
@property (nullable, nonatomic, copy) NSArray<UIColor *> *colors;
@property (nonatomic, readonly) BOOL hasStrings;
@property (nonatomic, readonly) BOOL hasURLs;
@property (nonatomic, readonly) BOOL hasImages;
@property (nonatomic, readonly) BOOL hasColors;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
- (void)addItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (nullable id)valueForPasteboardType:(NSString *)pasteboardType;
- (void)setValue:(id)value forPasteboardType:(NSString *)pasteboardType;
- (BOOL)containsPasteboardTypes:(NSArray<NSString *> *)pasteboardTypes;
@property (nonatomic, readonly) NSArray<NSString *> *pasteboardTypes;
@end
NS_ASSUME_NONNULL_END
