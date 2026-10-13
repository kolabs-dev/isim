#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKContentWorld;
typedef NS_ENUM(NSInteger, WKUserScriptInjectionTime) { WKUserScriptInjectionTimeAtDocumentStart, WKUserScriptInjectionTimeAtDocumentEnd };
@interface WKUserScript : NSObject
@property (nonatomic, readonly, copy) NSString *source;
@property (nonatomic, readonly) WKUserScriptInjectionTime injectionTime;
@property (nonatomic, readonly, getter=isForMainFrameOnly) BOOL forMainFrameOnly;
- (instancetype)initWithSource:(NSString *)source injectionTime:(WKUserScriptInjectionTime)injectionTime forMainFrameOnly:(BOOL)forMainFrameOnly;
- (instancetype)initWithSource:(NSString *)source injectionTime:(WKUserScriptInjectionTime)injectionTime forMainFrameOnly:(BOOL)forMainFrameOnly
                inContentWorld:(WKContentWorld *)contentWorld;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
