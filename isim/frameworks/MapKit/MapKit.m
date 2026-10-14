// isim MapKit for Objective-C: the C functions, and the members that take or return Core Location's and MapKit's
// structs (CLLocationCoordinate2D, MKCoordinateRegion), which the Swift overlay's classes cannot declare (they are Swift
// structs there); they pass the components to the overlay's _isim_ members.
#import <MapKit/MapKit.h>
// the categories implement what the header declares on the classes (the overlay's Swift classes cannot)
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static MKCoordinateRegion regionFrom(NSArray<NSNumber *> *v) {
    if (v.count != 4) return (MKCoordinateRegion){ { 0, 0 }, { 0, 0 } };
    return (MKCoordinateRegion){ { v[0].doubleValue, v[1].doubleValue }, { v[2].doubleValue, v[3].doubleValue } };
}
static NSArray<NSNumber *> *regionTo(MKCoordinateRegion r) {
    return @[@(r.center.latitude), @(r.center.longitude), @(r.span.latitudeDelta), @(r.span.longitudeDelta)];
}

@interface MKMapView (ISIMComponents)
+ (NSArray<NSNumber *> *)_isim_regionWithLatitude:(double)lat longitude:(double)lon latitudinalMeters:(double)m longitudinalMeters:(double)n;
- (NSArray<NSNumber *> *)_isim_region;
- (void)_isim_setRegion:(NSArray<NSNumber *> *)region animated:(BOOL)animated;
- (NSArray<NSNumber *> *)_isim_regionThatFits:(NSArray<NSNumber *> *)region;
- (void)_isim_setCenterLatitude:(double)lat longitude:(double)lon animated:(BOOL)animated;
- (CGPoint)_isim_convertLatitude:(double)lat longitude:(double)lon toPointToView:(UIView *)view;
- (CGPoint)_isim_convertPoint:(CGPoint)point toCoordinateFromView:(UIView *)view;
@end

MKCoordinateRegion MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D c, CLLocationDistance latitudinalMeters, CLLocationDistance longitudinalMeters) {
    return regionFrom([MKMapView _isim_regionWithLatitude:c.latitude longitude:c.longitude latitudinalMeters:latitudinalMeters
                                       longitudinalMeters:longitudinalMeters]);
}

@implementation MKMapView (ISIMStructs)
- (MKCoordinateRegion)region { return regionFrom([self _isim_region]); }
- (void)setRegion:(MKCoordinateRegion)region { [self _isim_setRegion:regionTo(region) animated:NO]; }
- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated { [self _isim_setRegion:regionTo(region) animated:animated]; }
- (MKCoordinateRegion)regionThatFits:(MKCoordinateRegion)region { return regionFrom([self _isim_regionThatFits:regionTo(region)]); }
- (CLLocationCoordinate2D)centerCoordinate { return self.region.center; }
- (void)setCenterCoordinate:(CLLocationCoordinate2D)c { [self _isim_setCenterLatitude:c.latitude longitude:c.longitude animated:NO]; }
- (void)setCenterCoordinate:(CLLocationCoordinate2D)c animated:(BOOL)animated {
    [self _isim_setCenterLatitude:c.latitude longitude:c.longitude animated:animated];
}
- (CGPoint)convertCoordinate:(CLLocationCoordinate2D)c toPointToView:(UIView *)view {
    return [self _isim_convertLatitude:c.latitude longitude:c.longitude toPointToView:view];
}
- (CLLocationCoordinate2D)convertPoint:(CGPoint)point toCoordinateFromView:(UIView *)view {
    CGPoint c = [self _isim_convertPoint:point toCoordinateFromView:view];
    return (CLLocationCoordinate2D){ c.x, c.y };
}
@end

@interface MKShape (ISIMComponents)
- (double)_isim_latitude;
- (double)_isim_longitude;
@end
@implementation MKShape (ISIMStructs)
- (CLLocationCoordinate2D)coordinate { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
@end
@interface MKPointAnnotation (ISIMComponents)
- (void)_isim_setLatitude:(double)lat longitude:(double)lon;
@end
@implementation MKPointAnnotation (ISIMStructs)
- (void)setCoordinate:(CLLocationCoordinate2D)c { [self _isim_setLatitude:c.latitude longitude:c.longitude]; }
@end
@interface MKUserLocation (ISIMComponents)
- (double)_isim_latitude;
- (double)_isim_longitude;
@end
@implementation MKUserLocation (ISIMStructs)
- (CLLocationCoordinate2D)coordinate { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
@end
@interface MKPlacemark (ISIMComponents)
- (instancetype)_isim_initWithLatitude:(double)lat longitude:(double)lon addressDictionary:(NSDictionary *)d __attribute__((objc_method_family(init)));
- (double)_isim_latitude;
- (double)_isim_longitude;
@end
@implementation MKPlacemark (ISIMStructs)
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)c { return [self _isim_initWithLatitude:c.latitude longitude:c.longitude addressDictionary:nil]; }
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)c addressDictionary:(NSDictionary<NSString *, id> *)d {
    return [self _isim_initWithLatitude:c.latitude longitude:c.longitude addressDictionary:d];
}
- (CLLocationCoordinate2D)coordinate { return (CLLocationCoordinate2D){ [self _isim_latitude], [self _isim_longitude] }; }
@end

@interface MKMultiPoint (ISIMComponents)
- (NSArray<NSNumber *> *)_isim_coordinates;
@end
@implementation MKMultiPoint (ISIMStructs)
- (void)getCoordinates:(CLLocationCoordinate2D *)coords range:(NSRange)range {
    NSArray<NSNumber *> *v = [self _isim_coordinates];
    for (NSUInteger i = 0; i < range.length; i++) {
        NSUInteger k = (range.location + i) * 2;
        if (k + 1 >= v.count) break;
        coords[i] = (CLLocationCoordinate2D){ v[k].doubleValue, v[k + 1].doubleValue };
    }
}
@end
static NSArray<NSNumber *> *pairs(const CLLocationCoordinate2D *coords, NSUInteger count) {
    NSMutableArray<NSNumber *> *v = [NSMutableArray arrayWithCapacity:count * 2];
    for (NSUInteger i = 0; i < count; i++) { [v addObject:@(coords[i].latitude)]; [v addObject:@(coords[i].longitude)]; }
    return v;
}
@interface MKPolyline (ISIMComponents)
+ (MKPolyline *)_isim_polylineWithCoordinates:(NSArray<NSNumber *> *)v;
@end
@implementation MKPolyline (ISIMStructs)
+ (instancetype)polylineWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count {
    return (id)[MKPolyline _isim_polylineWithCoordinates:pairs(coords, count)];
}
@end
@interface MKPolygon (ISIMComponents)
+ (MKPolygon *)_isim_polygonWithCoordinates:(NSArray<NSNumber *> *)v;
@end
@implementation MKPolygon (ISIMStructs)
+ (instancetype)polygonWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count {
    return (id)[MKPolygon _isim_polygonWithCoordinates:pairs(coords, count)];
}
@end
@interface MKCircle (ISIMComponents)
+ (MKCircle *)_isim_circleWithLatitude:(double)lat longitude:(double)lon radius:(double)radius;
@end
@implementation MKCircle (ISIMStructs)
+ (instancetype)circleWithCenterCoordinate:(CLLocationCoordinate2D)c radius:(CLLocationDistance)radius {
    return (id)[MKCircle _isim_circleWithLatitude:c.latitude longitude:c.longitude radius:radius];
}
@end

@interface MKLocalSearchRequest (ISIMComponents)
- (NSArray<NSNumber *> *)_isim_region;
- (void)_isim_setRegion:(NSArray<NSNumber *> *)region;
@end
@implementation MKLocalSearchRequest (ISIMStructs)
- (MKCoordinateRegion)region { return regionFrom([self _isim_region]); }
- (void)setRegion:(MKCoordinateRegion)region { [self _isim_setRegion:regionTo(region)]; }
@end
@interface MKLocalSearchResponse (ISIMComponents)
- (NSArray<NSNumber *> *)_isim_boundingRegion;
@end
@implementation MKLocalSearchResponse (ISIMStructs)
- (MKCoordinateRegion)boundingRegion { return regionFrom([self _isim_boundingRegion]); }
@end
