#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKSnapshotConfiguration : NSObject
@property (nonatomic) CGRect rect;
@property (nullable, nonatomic, copy) NSNumber *snapshotWidth;
@property (nonatomic) BOOL afterScreenUpdates;
@end
NS_ASSUME_NONNULL_END
