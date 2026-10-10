#pragma once
#import <Foundation/NSObject.h>
/* isim: the URL loading system for Objective-C. The classes are Foundation's Swift overlay classes (objc_runtime_visible:
   Objective-C code finds them through the runtime, so it cannot subclass them or add categories to them); Swift code
   uses URLSession, URLRequest... from the overlay, so this header is hidden from Swift. */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSString, NSDictionary;
#define NSURLResponseUnknownLength ((long long)-1)
ISIM_RUNTIME_VISIBLE
@interface NSURLResponse : NSObject
- (instancetype)initWithURL:(NSURL *)URL MIMEType:(nullable NSString *)MIMEType expectedContentLength:(NSInteger)length textEncodingName:(nullable NSString *)name;
@property (nullable, readonly, copy) NSURL *URL;
@property (nullable, readonly, copy) NSString *MIMEType;
@property (readonly) long long expectedContentLength;
@property (nullable, readonly, copy) NSString *textEncodingName;
@property (nullable, readonly, copy) NSString *suggestedFilename;
@end

ISIM_RUNTIME_VISIBLE
@interface NSHTTPURLResponse : NSURLResponse
- (nullable instancetype)initWithURL:(NSURL *)url statusCode:(NSInteger)statusCode HTTPVersion:(nullable NSString *)HTTPVersion
                        headerFields:(nullable NSDictionary<NSString *, NSString *> *)headerFields;
@property (readonly) NSInteger statusCode;
@property (readonly, copy) NSDictionary *allHeaderFields;
- (nullable NSString *)valueForHTTPHeaderField:(NSString *)field;
+ (NSString *)localizedStringForStatusCode:(NSInteger)statusCode;
@end
NS_ASSUME_NONNULL_END
#endif
