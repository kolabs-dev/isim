#pragma once
#import <WebKit/WKFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class WKFrameInfo;
typedef NS_ENUM(NSInteger, WKNavigationType) {
    WKNavigationTypeLinkActivated, WKNavigationTypeFormSubmitted, WKNavigationTypeBackForward, WKNavigationTypeReload,
    WKNavigationTypeFormResubmitted, WKNavigationTypeOther = -1,
};
@interface WKNavigationAction : NSObject
@property (nonatomic, readonly, copy) WKFrameInfo *sourceFrame;
@property (nullable, nonatomic, readonly, copy) WKFrameInfo *targetFrame;
@property (nonatomic, readonly) WKNavigationType navigationType;
@property (nonatomic, readonly, copy) NSURLRequest *request;
@property (nonatomic, readonly) BOOL shouldPerformDownload;
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags;
@property (nonatomic, readonly) NSInteger buttonNumber;
@end
NS_ASSUME_NONNULL_END
