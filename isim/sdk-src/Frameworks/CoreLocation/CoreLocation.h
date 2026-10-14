#pragma once
/* isim CoreLocation for Objective-C: the classes are the CoreLocation Swift overlay's (CoreLocation.framework re-exports
   libswiftCoreLocation.dylib), with the same simulated location as Swift (the `location` script command, routes and
   the permission prompts), region monitoring, visits and geocoding. Swift uses the overlay; these declarations are
   hidden from Swift. The classes are not subclassable from Objective-C. Not from Objective-C yet: beacons,
   CLMonitor and the live updates (Swift concurrency APIs). */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CLLocationManager, CLHeading, CLRegion, CLVisit;

typedef double CLLocationDegrees;
typedef double CLLocationAccuracy;
typedef double CLLocationSpeed;
typedef double CLLocationSpeedAccuracy;
typedef double CLLocationDirection;
typedef double CLLocationDirectionAccuracy;
typedef double CLLocationDistance;
typedef double CLHeadingComponentValue;
typedef struct { CLLocationDegrees latitude; CLLocationDegrees longitude; } CLLocationCoordinate2D;

FOUNDATION_EXPORT CLLocationCoordinate2D CLLocationCoordinate2DMake(CLLocationDegrees latitude, CLLocationDegrees longitude);
FOUNDATION_EXPORT BOOL CLLocationCoordinate2DIsValid(CLLocationCoordinate2D coord);
FOUNDATION_EXPORT const CLLocationCoordinate2D kCLLocationCoordinate2DInvalid;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyBestForNavigation;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyBest;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyNearestTenMeters;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyHundredMeters;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyKilometer;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyThreeKilometers;
FOUNDATION_EXPORT const CLLocationAccuracy kCLLocationAccuracyReduced;
FOUNDATION_EXPORT const CLLocationDistance kCLDistanceFilterNone;
FOUNDATION_EXPORT const CLLocationDegrees kCLHeadingFilterNone;
FOUNDATION_EXPORT const CLLocationDistance CLLocationDistanceMax;
FOUNDATION_EXPORT const NSTimeInterval CLTimeIntervalMax;

FOUNDATION_EXPORT NSErrorDomain const kCLErrorDomain;
FOUNDATION_EXPORT NSString * const kCLErrorUserInfoAlternateRegionKey;
typedef NS_ENUM(NSInteger, CLError) {
    kCLErrorLocationUnknown = 0, kCLErrorDenied, kCLErrorNetwork, kCLErrorHeadingFailure, kCLErrorRegionMonitoringDenied,
    kCLErrorRegionMonitoringFailure, kCLErrorRegionMonitoringSetupDelayed, kCLErrorRegionMonitoringResponseDelayed,
    kCLErrorGeocodeFoundNoResult, kCLErrorGeocodeFoundPartialResult, kCLErrorGeocodeCanceled, kCLErrorDeferredFailed,
    kCLErrorDeferredNotUpdatingLocation, kCLErrorDeferredAccuracyTooLow, kCLErrorDeferredDistanceFiltered, kCLErrorDeferredCanceled,
    kCLErrorRangingUnavailable, kCLErrorRangingFailure, kCLErrorPromptDeclined, kCLErrorHistoricalLocationError,
};

typedef NS_ENUM(int, CLAuthorizationStatus) {
    kCLAuthorizationStatusNotDetermined = 0, kCLAuthorizationStatusRestricted = 1, kCLAuthorizationStatusDenied = 2,
    kCLAuthorizationStatusAuthorizedAlways = 3, kCLAuthorizationStatusAuthorizedWhenInUse = 4,
    kCLAuthorizationStatusAuthorized API_DEPRECATED_WITH_REPLACEMENT("kCLAuthorizationStatusAuthorizedAlways", ios(2.0, 8.0)) = 3,
};
typedef NS_ENUM(NSInteger, CLAccuracyAuthorization) { CLAccuracyAuthorizationFullAccuracy = 0, CLAccuracyAuthorizationReducedAccuracy = 1 };
typedef NS_ENUM(NSInteger, CLActivityType) {
    CLActivityTypeOther = 1, CLActivityTypeAutomotiveNavigation, CLActivityTypeFitness, CLActivityTypeOtherNavigation, CLActivityTypeAirborne,
};
typedef NS_ENUM(NSInteger, CLRegionState) { CLRegionStateUnknown = 0, CLRegionStateInside, CLRegionStateOutside };

@interface CLFloor : NSObject
@property (readonly, nonatomic) NSInteger level;
@end

@interface CLLocation : NSObject <NSCopying>
- (instancetype)initWithLatitude:(CLLocationDegrees)latitude longitude:(CLLocationDegrees)longitude;
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate altitude:(CLLocationDistance)altitude
                horizontalAccuracy:(CLLocationAccuracy)hAccuracy verticalAccuracy:(CLLocationAccuracy)vAccuracy timestamp:(NSDate *)timestamp;
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate altitude:(CLLocationDistance)altitude
                horizontalAccuracy:(CLLocationAccuracy)hAccuracy verticalAccuracy:(CLLocationAccuracy)vAccuracy
                            course:(CLLocationDirection)course speed:(CLLocationSpeed)speed timestamp:(NSDate *)timestamp;
@property (readonly, nonatomic) CLLocationCoordinate2D coordinate;
@property (readonly, nonatomic) CLLocationDistance altitude;
@property (readonly, nonatomic) CLLocationDistance ellipsoidalAltitude;
@property (readonly, nonatomic) CLLocationAccuracy horizontalAccuracy;
@property (readonly, nonatomic) CLLocationAccuracy verticalAccuracy;
@property (readonly, nonatomic) CLLocationDirection course;
@property (readonly, nonatomic) CLLocationDirectionAccuracy courseAccuracy;
@property (readonly, nonatomic) CLLocationSpeed speed;
@property (readonly, nonatomic) CLLocationSpeedAccuracy speedAccuracy;
@property (readonly, nonatomic, copy) NSDate *timestamp;
@property (readonly, nonatomic, copy, nullable) CLFloor *floor;
- (CLLocationDistance)distanceFromLocation:(const CLLocation *)location;
@end

@interface CLHeading : NSObject
@property (readonly, nonatomic) CLLocationDirection magneticHeading;
@property (readonly, nonatomic) CLLocationDirection trueHeading;
@property (readonly, nonatomic) CLLocationDirection headingAccuracy;
@property (readonly, nonatomic) CLHeadingComponentValue x;
@property (readonly, nonatomic) CLHeadingComponentValue y;
@property (readonly, nonatomic) CLHeadingComponentValue z;
@property (readonly, nonatomic, copy) NSDate *timestamp;
@end

@interface CLVisit : NSObject <NSSecureCoding, NSCopying>
@property (nonatomic, readonly, copy) NSDate *arrivalDate;
@property (nonatomic, readonly, copy) NSDate *departureDate;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) CLLocationAccuracy horizontalAccuracy;
@end

@interface CLRegion : NSObject <NSCopying>
@property (readonly, nonatomic, copy) NSString *identifier;
@property (nonatomic, assign) BOOL notifyOnEntry;
@property (nonatomic, assign) BOOL notifyOnExit;
@end
@interface CLCircularRegion : CLRegion
- (instancetype)initWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius identifier:(NSString *)identifier;
@property (readonly, nonatomic) CLLocationCoordinate2D center;
@property (readonly, nonatomic) CLLocationDistance radius;
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate;
@end

@interface CLPlacemark : NSObject <NSCopying>
- (instancetype)initWithPlacemark:(CLPlacemark *)placemark;
@property (nonatomic, readonly, copy, nullable) CLLocation *location;
@property (nonatomic, readonly, copy, nullable) CLRegion *region;
@property (nonatomic, readonly, copy, nullable) NSTimeZone *timeZone;
@property (nonatomic, readonly, copy, nullable) NSString *name;
@property (nonatomic, readonly, copy, nullable) NSString *thoroughfare;
@property (nonatomic, readonly, copy, nullable) NSString *subThoroughfare;
@property (nonatomic, readonly, copy, nullable) NSString *locality;
@property (nonatomic, readonly, copy, nullable) NSString *subLocality;
@property (nonatomic, readonly, copy, nullable) NSString *administrativeArea;
@property (nonatomic, readonly, copy, nullable) NSString *subAdministrativeArea;
@property (nonatomic, readonly, copy, nullable) NSString *postalCode;
@property (nonatomic, readonly, copy, nullable) NSString *ISOcountryCode;
@property (nonatomic, readonly, copy, nullable) NSString *country;
@property (nonatomic, readonly, copy, nullable) NSString *inlandWater;
@property (nonatomic, readonly, copy, nullable) NSString *ocean;
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *areasOfInterest;
@end

typedef void (^CLGeocodeCompletionHandler)(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error);
@interface CLGeocoder : NSObject
@property (nonatomic, readonly, getter=isGeocoding) BOOL geocoding;
- (void)reverseGeocodeLocation:(CLLocation *)location completionHandler:(CLGeocodeCompletionHandler)completionHandler;
- (void)reverseGeocodeLocation:(CLLocation *)location preferredLocale:(nullable NSLocale *)locale completionHandler:(CLGeocodeCompletionHandler)completionHandler;
- (void)geocodeAddressString:(NSString *)addressString completionHandler:(CLGeocodeCompletionHandler)completionHandler;
- (void)geocodeAddressString:(NSString *)addressString inRegion:(nullable CLRegion *)region completionHandler:(CLGeocodeCompletionHandler)completionHandler;
- (void)cancelGeocode;
@end

@protocol CLLocationManagerDelegate <NSObject>
@optional
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations;
- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading;
- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager;
- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region;
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region;
- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region;
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error;
- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(nullable CLRegion *)region withError:(NSError *)error;
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
    API_DEPRECATED_WITH_REPLACEMENT("-locationManagerDidChangeAuthorization:", ios(4.2, 14.0));
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager;
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region;
- (void)locationManagerDidPauseLocationUpdates:(CLLocationManager *)manager;
- (void)locationManagerDidResumeLocationUpdates:(CLLocationManager *)manager;
- (void)locationManager:(CLLocationManager *)manager didFinishDeferredUpdatesWithError:(nullable NSError *)error;
- (void)locationManager:(CLLocationManager *)manager didVisit:(CLVisit *)visit;
@end

@interface CLLocationManager : NSObject
+ (BOOL)locationServicesEnabled;
+ (BOOL)headingAvailable;
+ (BOOL)significantLocationChangeMonitoringAvailable;
+ (BOOL)isMonitoringAvailableForClass:(Class)regionClass;
+ (BOOL)isRangingAvailable;
+ (CLAuthorizationStatus)authorizationStatus API_DEPRECATED_WITH_REPLACEMENT("-authorizationStatus", ios(4.2, 14.0));
@property (nonatomic, readonly) CLAuthorizationStatus authorizationStatus;
@property (nonatomic, readonly) CLAccuracyAuthorization accuracyAuthorization;
@property (weak, nonatomic, nullable) id<CLLocationManagerDelegate> delegate;
@property (assign, nonatomic) CLLocationDistance distanceFilter;
@property (assign, nonatomic) CLLocationAccuracy desiredAccuracy;
@property (assign, nonatomic) CLActivityType activityType;
@property (assign, nonatomic) BOOL pausesLocationUpdatesAutomatically;
@property (assign, nonatomic) BOOL allowsBackgroundLocationUpdates;
@property (assign, nonatomic) BOOL showsBackgroundLocationIndicator;
@property (assign, nonatomic) CLLocationDegrees headingFilter;
@property (readonly, nonatomic, copy, nullable) CLLocation *location;
@property (readonly, nonatomic, copy, nullable) CLHeading *heading;
@property (readonly, nonatomic) CLLocationDistance maximumRegionMonitoringDistance;
@property (readonly, nonatomic, copy) NSSet<__kindof CLRegion *> *monitoredRegions;
- (void)requestWhenInUseAuthorization;
- (void)requestAlwaysAuthorization;
- (void)requestTemporaryFullAccuracyAuthorizationWithPurposeKey:(NSString *)purposeKey completion:(nullable void (^)(NSError * _Nullable))completion;
- (void)startUpdatingLocation;
- (void)stopUpdatingLocation;
- (void)requestLocation;
- (void)startUpdatingHeading;
- (void)stopUpdatingHeading;
- (void)startMonitoringSignificantLocationChanges;
- (void)stopMonitoringSignificantLocationChanges;
- (void)startMonitoringVisits;
- (void)stopMonitoringVisits;
- (void)startMonitoringForRegion:(CLRegion *)region;
- (void)stopMonitoringForRegion:(CLRegion *)region;
- (void)requestStateForRegion:(CLRegion *)region;
@end

NS_ASSUME_NONNULL_END
#endif
