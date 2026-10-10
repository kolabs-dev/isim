#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURLCredential, NSURLProtectionSpace, NSString, NSDictionary<KeyType, ObjectType>;
FOUNDATION_EXPORT NSString *const NSURLCredentialStorageChangedNotification;
ISIM_RUNTIME_VISIBLE
@interface NSURLCredentialStorage : NSObject
@property (class, readonly, strong) NSURLCredentialStorage *sharedCredentialStorage;
- (nullable NSDictionary<NSString *, NSURLCredential *> *)credentialsForProtectionSpace:(NSURLProtectionSpace *)space;
@property (readonly, copy) NSDictionary<NSURLProtectionSpace *, NSDictionary<NSString *, NSURLCredential *> *> *allCredentials;
- (void)setCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space;
- (void)removeCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space;
- (nullable NSURLCredential *)defaultCredentialForProtectionSpace:(NSURLProtectionSpace *)space;
- (void)setDefaultCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space;
@end
NS_ASSUME_NONNULL_END
#endif
