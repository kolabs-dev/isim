#pragma once
#import <Foundation/Foundation.h>
#import <QuickLook/QLPreviewingController.h>
NS_ASSUME_NONNULL_BEGIN
/* the principal class of a data-based preview extension: subclasses implement providePreviewForFileRequest:completionHandler: */
API_AVAILABLE(ios(15.0))
@interface QLPreviewProvider : NSObject <NSExtensionRequestHandling>
@end
NS_ASSUME_NONNULL_END
