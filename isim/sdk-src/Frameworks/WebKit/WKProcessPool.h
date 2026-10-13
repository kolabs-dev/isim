#pragma once
#import <WebKit/WKFoundation.h>
/* deprecated on iOS 15: every web view shares one engine process on isim */
@interface WKProcessPool : NSObject
@end
