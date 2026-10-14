#pragma once
#import <WebKit/WKBackForwardListItem.h>
NS_ASSUME_NONNULL_BEGIN
@interface WKBackForwardList : NSObject
@property (nullable, nonatomic, readonly, strong) WKBackForwardListItem *currentItem;
@property (nullable, nonatomic, readonly, strong) WKBackForwardListItem *backItem;
@property (nullable, nonatomic, readonly, strong) WKBackForwardListItem *forwardItem;
- (nullable WKBackForwardListItem *)itemAtIndex:(NSInteger)index;
@property (nonatomic, readonly, copy) NSArray<WKBackForwardListItem *> *backList;
@property (nonatomic, readonly, copy) NSArray<WKBackForwardListItem *> *forwardList;
@end
NS_ASSUME_NONNULL_END
