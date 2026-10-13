#pragma once
/* isim: private click measurement (iOS 14.5). An app showing an ad puts a UIEventAttributionView over it; when the
   person taps the view and the app then opens the advertised page with an event attribution (UIApplication
   open(_:options:) with .eventAttribution, or UIScene.OpenExternalURLOptions.eventAttribution), the click is recorded.
   Adapted: isim logs the recorded click ("isim: event attribution ...") and keeps it in the device's attribution
   list (script `attributions`); nothing is sent to report endpoints. A click without a tap on an attribution view in
   the last second is dropped (logged), like iOS. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.5))
@interface UIEventAttribution : NSObject <NSCopying>
@property (nonatomic, readonly) uint8_t sourceIdentifier;
@property (nonatomic, readonly, copy) NSURL *destinationURL;
/* the app's NSAdvertisingAttributionReportEndpoint (Info.plist), else nil */
@property (nonatomic, readonly, copy, nullable) NSURL *reportEndpoint;
@property (nonatomic, readonly, copy) NSString *sourceDescription;
@property (nonatomic, readonly, copy) NSString *purchaser;
- (instancetype)initWithSourceIdentifier:(uint8_t)sourceIdentifier destinationURL:(NSURL *)destinationURL
                       sourceDescription:(NSString *)sourceDescription purchaser:(NSString *)purchaser;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
/* a transparent view over the ad: taps on it count as the person's interaction with the ad */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.5))
@interface UIEventAttributionView : UIView
@end
NS_ASSUME_NONNULL_END
