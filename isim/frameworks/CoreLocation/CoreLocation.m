// isim CoreLocation for Objective-C: the C functions and constants, and the members that take or return
// CLLocationCoordinate2D, which the Swift overlay's classes cannot declare (it is a Swift struct there); they pass its
// components to the overlay's _isim_ members. The values match the overlay's.
#import <CoreLocation/CoreLocation.h>
// the categories implement what the header declares on the classes (the overlay's Swift classes cannot)
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

CLLocationCoordinate2D CLLocationCoordinate2DMake(CLLocationDegrees latitude, CLLocationDegrees longitude) {
    return (CLLocationCoordinate2D){ latitude, longitude };
}
BOOL CLLocationCoordinate2DIsValid(CLLocationCoordinate2D c) {
    return c.latitude >= -90 && c.latitude <= 90 && c.longitude >= -180 && c.longitude <= 180;
}
const CLLocationCoordinate2D kCLLocationCoordinate2DInvalid = { -180, -180 };
const CLLocationAccuracy kCLLocationAccuracyBestForNavigation = -2;
const CLLocationAccuracy kCLLocationAccuracyBest = -1;
const CLLocationAccuracy kCLLocationAccuracyNearestTenMeters = 10;
const CLLocationAccuracy kCLLocationAccuracyHundredMeters = 100;
const CLLocationAccuracy kCLLocationAccuracyKilometer = 1000;
const CLLocationAccuracy kCLLocationAccuracyThreeKilometers = 3000;
const CLLocationAccuracy kCLLocationAccuracyReduced = 3000;
const CLLocationDistance kCLDistanceFilterNone = -1;
const CLLocationDegrees kCLHeadingFilterNone = -1;
const CLLocationDistance CLLocationDistanceMax = __DBL_MAX__;
const NSTimeInterval CLTimeIntervalMax = __DBL_MAX__;
NSErrorDomain const kCLErrorDomain = @"kCLErrorDomain";
NSString * const kCLErrorUserInfoAlternateRegionKey = @"alternateRegion";

@interface CLLocation (ISIMCoordinates)
- (instancetype)_isim_initWithLatitude:(double)lat longitude:(double)lon altitude:(double)alt horizontalAccuracy:(double)h
                      verticalAccuracy:(double)v course:(double)course speed:(double)speed timestamp:(NSDate *)t __attribute__((objc_method_family(init)));
- (double)_isim_latitude;
- (double)_isim_longitude;
@end
@implementation CLLocation (ISIMStructs)
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)c altitude:(CLLocationDistance)alt horizontalAccuracy:(CLLocationAccuracy)h
                  verticalAccuracy:(CLLocationAccuracy)v timestamp:(NSDate *)t {
    return [self _isim_initWithLatitude:c.latitude longitude:c.longitude altitude:alt horizontalAccuracy:h verticalAccuracy:v course:-1 speed:-1 timestamp:t];
}
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)c altitude:(CLLocationDistance)alt horizontalAccuracy:(CLLocationAccuracy)h
                  verticalAccuracy:(CLLocationAccuracy)v course:(CLLocationDirection)course speed:(CLLocationSpeed)speed timestamp:(NSDate *)t {
    return [self _isim_initWithLatitude:c.latitude longitude:c.longitude altitude:alt horizontalAccuracy:h verticalAccuracy:v course:course speed:speed timestamp:t];
}
- (CLLocationCoordinate2D)coordinate { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
@end

@interface CLVisit (ISIMCoordinates)
- (double)_isim_latitude;
- (double)_isim_longitude;
@end
@implementation CLVisit (ISIMStructs)
- (CLLocationCoordinate2D)coordinate { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
@end

@interface CLCircularRegion (ISIMCoordinates)
- (instancetype)_isim_initWithLatitude:(double)lat longitude:(double)lon radius:(double)r identifier:(NSString *)identifier __attribute__((objc_method_family(init)));
- (double)_isim_latitude;
- (double)_isim_longitude;
- (BOOL)_isim_containsLatitude:(double)lat longitude:(double)lon;
@end
@implementation CLCircularRegion (ISIMStructs)
- (instancetype)initWithCenter:(CLLocationCoordinate2D)c radius:(CLLocationDistance)radius identifier:(NSString *)identifier {
    return [self _isim_initWithLatitude:c.latitude longitude:c.longitude radius:radius identifier:identifier];
}
- (CLLocationCoordinate2D)center { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)c { return [self _isim_containsLatitude:c.latitude longitude:c.longitude]; }
@end
