#pragma once
#import <UIKit/UIKit.h>
#if !defined(__swift__)
@class LPLinkMetadata;
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(13.0))
@interface LPLinkView : UIView
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (void)encodeWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
/* a placeholder for the URL until metadata is set */
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithMetadata:(LPLinkMetadata *)metadata;
@property (nonatomic, copy) LPLinkMetadata *metadata;
@end
NS_ASSUME_NONNULL_END

#endif
