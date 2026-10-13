#pragma once
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: a shape is its bounding rectangle (interior and exterior transforms give the same box) */
@interface CIFilterShape : NSObject <NSCopying>
+ (instancetype)shapeWithRect:(CGRect)r;
- (instancetype)initWithRect:(CGRect)r;
- (CIFilterShape *)transformBy:(CGAffineTransform)m interior:(BOOL)flag;
- (CIFilterShape *)insetByX:(int)dx Y:(int)dy;
- (CIFilterShape *)unionWith:(CIFilterShape *)s2;
- (CIFilterShape *)unionWithRect:(CGRect)r;
- (CIFilterShape *)intersectWith:(CIFilterShape *)s2;
- (CIFilterShape *)intersectWithRect:(CGRect)r;
@property (readonly) CGRect extent;
@end
NS_ASSUME_NONNULL_END
