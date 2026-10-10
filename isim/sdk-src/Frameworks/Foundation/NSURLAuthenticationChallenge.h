#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURLProtectionSpace, NSURLCredential, NSURLResponse, NSError;
ISIM_RUNTIME_VISIBLE
@interface NSURLAuthenticationChallenge : NSObject
@property (readonly, copy) NSURLProtectionSpace *protectionSpace;
@property (nullable, readonly, copy) NSURLCredential *proposedCredential;
@property (readonly) NSInteger previousFailureCount;
@property (nullable, readonly, copy) NSURLResponse *failureResponse;
@property (nullable, readonly, copy) NSError *error;
@property (nullable, readonly, retain) id sender;
@end
NS_ASSUME_NONNULL_END
#endif
