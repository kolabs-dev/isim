#pragma once
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(8))
@interface PHObject : NSObject <NSCopying>
@property (nonatomic, copy, readonly) NSString *localIdentifier;
@end
API_AVAILABLE(ios(8))
@interface PHObjectPlaceholder : PHObject
@end
NS_ASSUME_NONNULL_END
#endif
