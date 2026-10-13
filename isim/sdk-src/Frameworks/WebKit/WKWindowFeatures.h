#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKWindowFeatures : NSObject
@property (nullable, nonatomic, readonly) NSNumber *menuBarVisibility;
@property (nullable, nonatomic, readonly) NSNumber *statusBarVisibility;
@property (nullable, nonatomic, readonly) NSNumber *toolbarsVisibility;
@property (nullable, nonatomic, readonly) NSNumber *allowsResizing;
@property (nullable, nonatomic, readonly) NSNumber *x;
@property (nullable, nonatomic, readonly) NSNumber *y;
@property (nullable, nonatomic, readonly) NSNumber *width;
@property (nullable, nonatomic, readonly) NSNumber *height;
@end
NS_ASSUME_NONNULL_END
