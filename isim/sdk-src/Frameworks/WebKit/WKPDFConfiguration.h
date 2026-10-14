#pragma once
#import <WebKit/WKFoundation.h>
@interface WKPDFConfiguration : NSObject
@property (nonatomic) CGRect rect;
@property (nonatomic) BOOL allowTransparentBackground;
@end
