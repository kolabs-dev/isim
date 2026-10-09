#pragma once
/* isim: UIPasteboard. The general pasteboard is shared by the apps of an isim device (every item type is stored in the
   device data directory). Reading another app's content without a user paste (edit menu, Cmd/Ctrl+V, UIPasteControl)
   asks first, like iOS 16 and later ("Paste from Other Apps": Ask, Deny, Allow). No Universal Clipboard (localOnly is
   kept but has nothing to limit). Item providers, setObjects and UIPasteControl: the Swift overlay (UIKit+Pasteboard). */
#import <UIKit/UIKitDefines.h>
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor;
typedef NSString *UIPasteboardName NS_TYPED_EXTENSIBLE_ENUM;
UIKIT_EXTERN UIPasteboardName const UIPasteboardNameGeneral;
UIKIT_EXTERN NSString *const UIPasteboardNameFind API_DEPRECATED("The Find pasteboard is no longer available.", ios(3.0, 10.0));
UIKIT_EXTERN NSNotificationName const UIPasteboardChangedNotification NS_SWIFT_NAME(UIPasteboard.changedNotification);
UIKIT_EXTERN NSString *const UIPasteboardChangedTypesAddedKey NS_SWIFT_NAME(UIPasteboard.changedTypesAddedUserInfoKey);
UIKIT_EXTERN NSString *const UIPasteboardChangedTypesRemovedKey NS_SWIFT_NAME(UIPasteboard.changedTypesRemovedUserInfoKey);
UIKIT_EXTERN NSNotificationName const UIPasteboardRemovedNotification NS_SWIFT_NAME(UIPasteboard.removedNotification);
UIKIT_EXTERN NSArray<NSString *> *UIPasteboardTypeListString NS_SWIFT_NAME(UIPasteboard.typeListString);
UIKIT_EXTERN NSArray<NSString *> *UIPasteboardTypeListURL NS_SWIFT_NAME(UIPasteboard.typeListURL);
UIKIT_EXTERN NSArray<NSString *> *UIPasteboardTypeListImage NS_SWIFT_NAME(UIPasteboard.typeListImage);
UIKIT_EXTERN NSArray<NSString *> *UIPasteboardTypeListColor NS_SWIFT_NAME(UIPasteboard.typeListColor);
UIKIT_EXTERN NSString *const UIPasteboardTypeAutomatic API_AVAILABLE(ios(15.0)) NS_SWIFT_NAME(UIPasteboard.typeAutomatic);

typedef NSString *UIPasteboardOptionsKey NS_TYPED_ENUM NS_SWIFT_NAME(UIPasteboard.OptionsKey);
UIKIT_EXTERN UIPasteboardOptionsKey const UIPasteboardOptionExpirationDate API_AVAILABLE(ios(10.0)) NS_SWIFT_NAME(expirationDate);
UIKIT_EXTERN UIPasteboardOptionsKey const UIPasteboardOptionLocalOnly API_AVAILABLE(ios(10.0)) NS_SWIFT_NAME(localOnly);

/* patterns found without reading the content (no prompt). isim detects probableWebURL, probableWebSearch and number
   (with values) and links, phoneNumbers and emailAddresses (patterns only); the other iOS 15 patterns are never found */
typedef NSString *UIPasteboardDetectionPattern NS_TYPED_ENUM NS_SWIFT_NAME(UIPasteboard.DetectionPattern) API_AVAILABLE(ios(14.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternProbableWebURL API_AVAILABLE(ios(14.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternProbableWebSearch API_AVAILABLE(ios(14.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternNumber API_AVAILABLE(ios(14.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternLink API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternPhoneNumber API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternEmailAddress API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternPostalAddress API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternCalendarEvent API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternShipmentTrackingNumber API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternFlightNumber API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIPasteboardDetectionPattern const UIPasteboardDetectionPatternMoneyAmount API_AVAILABLE(ios(15.0));

NS_SWIFT_UI_ACTOR
@interface UIPasteboard : NSObject
@property (class, nonatomic, readonly) UIPasteboard *generalPasteboard NS_SWIFT_NAME(general);
+ (nullable UIPasteboard *)pasteboardWithName:(UIPasteboardName)pasteboardName create:(BOOL)create;
+ (UIPasteboard *)pasteboardWithUniqueName;
+ (void)removePasteboardWithName:(UIPasteboardName)pasteboardName;
@property (nonatomic, readonly) UIPasteboardName name;
@property (nonatomic, getter=isPersistent) BOOL persistent API_DEPRECATED("Do not set persistence on pasteboards. This property is set automatically.", ios(3.0, 10.0));
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
@property (nonatomic, readonly) BOOL hasStrings API_AVAILABLE(ios(10.0));
@property (nonatomic, readonly) BOOL hasURLs API_AVAILABLE(ios(10.0));
@property (nonatomic, readonly) BOOL hasImages API_AVAILABLE(ios(10.0));
@property (nonatomic, readonly) BOOL hasColors API_AVAILABLE(ios(10.0));
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
- (void)addItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items options:(NSDictionary<UIPasteboardOptionsKey, id> *)options API_AVAILABLE(ios(10.0));
/* the first item */
@property (nonatomic, readonly) NSArray<NSString *> *pasteboardTypes NS_SWIFT_NAME(types);
- (BOOL)containsPasteboardTypes:(NSArray<NSString *> *)pasteboardTypes NS_SWIFT_NAME(contains(pasteboardTypes:));
- (nullable NSData *)dataForPasteboardType:(NSString *)pasteboardType;
- (nullable id)valueForPasteboardType:(NSString *)pasteboardType;
- (void)setValue:(id)value forPasteboardType:(NSString *)pasteboardType;
- (void)setData:(NSData *)data forPasteboardType:(NSString *)pasteboardType;
/* item sets (nil: every item) */
- (nullable NSArray<NSArray<NSString *> *> *)pasteboardTypesForItemSet:(nullable NSIndexSet *)itemSet NS_SWIFT_NAME(types(forItemSet:));
- (BOOL)containsPasteboardTypes:(NSArray<NSString *> *)pasteboardTypes inItemSet:(nullable NSIndexSet *)itemSet NS_SWIFT_NAME(contains(pasteboardTypes:inItemSet:));
- (nullable NSIndexSet *)itemSetWithPasteboardTypes:(NSArray<NSString *> *)pasteboardTypes;
- (nullable NSArray *)valuesForPasteboardType:(NSString *)pasteboardType inItemSet:(nullable NSIndexSet *)itemSet;
- (nullable NSArray<NSData *> *)dataForPasteboardType:(NSString *)pasteboardType inItemSet:(nullable NSIndexSet *)itemSet;
/* detection (iOS 14): what the content looks like, without the paste prompt; handlers run on the main queue */
- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns
                completionHandler:(void (^)(NSSet<UIPasteboardDetectionPattern> *_Nullable, NSError *_Nullable))completionHandler NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0));
- (void)detectPatternsForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(nullable NSIndexSet *)itemSet
                completionHandler:(void (^)(NSArray<NSSet<UIPasteboardDetectionPattern> *> *_Nullable, NSError *_Nullable))completionHandler NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0));
- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns
              completionHandler:(void (^)(NSDictionary<UIPasteboardDetectionPattern, id> *_Nullable, NSError *_Nullable))completionHandler NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0));
- (void)detectValuesForPatterns:(NSSet<UIPasteboardDetectionPattern> *)patterns inItemSet:(nullable NSIndexSet *)itemSet
              completionHandler:(void (^)(NSArray<NSDictionary<UIPasteboardDetectionPattern, id> *> *_Nullable, NSError *_Nullable))completionHandler NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0));
/* isim: reads the items as a user-initiated paste would (no prompt); UIPasteControl and the overlay's item providers */
- (NSArray<NSDictionary<NSString *, id> *> *)_isim_itemsForUserPaste;
/* isim: whether this read of another app's content may go ahead (asks when "Paste from Other Apps" is Ask) */
- (BOOL)_isim_mayRead;
@end
NS_ASSUME_NONNULL_END
