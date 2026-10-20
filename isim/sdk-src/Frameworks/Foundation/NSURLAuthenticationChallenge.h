#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURLProtectionSpace, NSURLCredential, NSURLResponse, NSError, NSURLAuthenticationChallenge;
@protocol NSURLAuthenticationChallengeSender <NSObject>
- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
@optional
- (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge *)challenge;
@end
ISIM_RUNTIME_VISIBLE
@interface NSURLAuthenticationChallenge : NSObject
@property (readonly, copy) NSURLProtectionSpace *protectionSpace;
@property (nullable, readonly, copy) NSURLCredential *proposedCredential;
@property (readonly) NSInteger previousFailureCount;
@property (nullable, readonly, copy) NSURLResponse *failureResponse;
@property (nullable, readonly, copy) NSError *error;
@property (nullable, readonly, retain) id<NSURLAuthenticationChallengeSender> sender;
- (instancetype)initWithProtectionSpace:(NSURLProtectionSpace *)space proposedCredential:(nullable NSURLCredential *)credential
                   previousFailureCount:(NSInteger)previousFailureCount failureResponse:(nullable NSURLResponse *)response
                                  error:(nullable NSError *)error sender:(id<NSURLAuthenticationChallengeSender>)sender;
- (instancetype)initWithAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge sender:(id<NSURLAuthenticationChallengeSender>)sender;
@end
NS_ASSUME_NONNULL_END
#endif
