#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
/* <input type=file> (iOS 18.4): what the page's file input accepts (isim: allowsDirectories is always NO) */
API_AVAILABLE(ios(18.4))
@interface WKOpenPanelParameters : NSObject
@property (nonatomic, readonly) BOOL allowsMultipleSelection;
@property (nonatomic, readonly) BOOL allowsDirectories;
@end
NS_ASSUME_NONNULL_END
