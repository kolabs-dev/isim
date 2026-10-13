#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKContextMenuElementInfo : NSObject
@property (nonatomic, nullable, readonly) NSURL *linkURL;
@end
NS_ASSUME_NONNULL_END
