#pragma once
#import <WebKit/WKFoundation.h>
@interface WKFindConfiguration : NSObject
@property (nonatomic) BOOL backwards;
@property (nonatomic) BOOL caseSensitive;
@property (nonatomic) BOOL wraps;
@end
