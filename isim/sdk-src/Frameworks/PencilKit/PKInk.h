#pragma once
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PencilKit/PKContentVersion.h>
NS_ASSUME_NONNULL_BEGIN
typedef NSString *PKInkType NS_TYPED_ENUM NS_REFINED_FOR_SWIFT;
PENCILKIT_EXTERN PKInkType const PKInkTypePen API_AVAILABLE(ios(13.0));
PENCILKIT_EXTERN PKInkType const PKInkTypePencil API_AVAILABLE(ios(13.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeMarker API_AVAILABLE(ios(13.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeMonoline API_AVAILABLE(ios(17.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeFountainPen API_AVAILABLE(ios(17.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeWatercolor API_AVAILABLE(ios(17.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeCrayon API_AVAILABLE(ios(17.0));
PENCILKIT_EXTERN PKInkType const PKInkTypeReed API_AVAILABLE(ios(26.0));

/* an ink: its type and color */
NS_SWIFT_NAME(PKInkReference) __attribute__((swift_bridge("PKInk"))) API_AVAILABLE(ios(14.0))
@interface PKInk : NSObject <NSCopying>
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) PKInkType inkType;
@property (nonatomic, readonly) UIColor *color;
@property (nonatomic, readonly) PKContentVersion requiredContentVersion API_AVAILABLE(ios(17.0));
@end
NS_ASSUME_NONNULL_END
