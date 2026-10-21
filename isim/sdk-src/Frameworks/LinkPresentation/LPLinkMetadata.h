#pragma once
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(13.0))
@interface LPLinkMetadata : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, retain, nullable) NSURL *originalURL;
@property (nonatomic, retain, nullable) NSURL *URL;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, retain, nullable) NSItemProvider *iconProvider;
@property (nonatomic, retain, nullable) NSItemProvider *imageProvider;
@property (nonatomic, retain, nullable) NSItemProvider *videoProvider;
@property (nonatomic, retain, nullable) NSURL *remoteVideoURL;
@end
NS_ASSUME_NONNULL_END

#endif
