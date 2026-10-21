#pragma once
/* isim CoreLocationUI: the location button. A tap grants the app when-in-use location authorization for the rest of
   the run (temporary, not remembered), like iOS, then sends the control's actions. SwiftUI's LocationButton is in the
   CoreLocationUI overlay. */
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CLLocationButtonIcon) {
    CLLocationButtonIconNone = 0,
    CLLocationButtonIconArrowFilled,
    CLLocationButtonIconArrowOutline,
} API_AVAILABLE(ios(15.0));

typedef NS_ENUM(NSInteger, CLLocationButtonLabel) {
    CLLocationButtonLabelNone = 0,
    CLLocationButtonLabelCurrentLocation,
    CLLocationButtonLabelSendCurrentLocation,
    CLLocationButtonLabelSendMyCurrentLocation,
    CLLocationButtonLabelShareCurrentLocation,
    CLLocationButtonLabelShareMyCurrentLocation,
} API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface CLLocationButton : UIControl <NSSecureCoding>
@property (nonatomic, readwrite, assign) CLLocationButtonIcon icon;
@property (nonatomic, readwrite, assign) CLLocationButtonLabel label;
@property (nonatomic, readwrite, assign) CGFloat fontSize;
@property (nonatomic, readwrite, assign) CGFloat cornerRadius;
@end

NS_ASSUME_NONNULL_END
