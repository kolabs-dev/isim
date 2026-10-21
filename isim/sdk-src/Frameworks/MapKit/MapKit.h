#pragma once
/* isim MapKit for Objective-C: the classes are the MapKit Swift overlay's (MapKit.framework re-exports
   libswiftMapKit.dylib), with the same map as Swift (isim's offline basemap, annotations and their views, overlays,
   the user location, local search). Swift uses the overlay; these declarations are hidden from Swift. The classes are
   not subclassable from Objective-C. Not from Objective-C yet: the camera and map configurations, directions, the
   search completer, look around, snapshots. */
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MKMapView, MKAnnotationView, MKOverlayRenderer, MKUserLocation, MKPolyline, MKPolygon, MKCircle, MKShape, MKAddress, MKAddressRepresentations, MKMapItem;

typedef struct { CLLocationDegrees latitudeDelta; CLLocationDegrees longitudeDelta; } MKCoordinateSpan;
typedef struct { CLLocationCoordinate2D center; MKCoordinateSpan span; } MKCoordinateRegion;
NS_INLINE MKCoordinateSpan MKCoordinateSpanMake(CLLocationDegrees latitudeDelta, CLLocationDegrees longitudeDelta) {
    return (MKCoordinateSpan){ latitudeDelta, longitudeDelta };
}
NS_INLINE MKCoordinateRegion MKCoordinateRegionMake(CLLocationCoordinate2D center, MKCoordinateSpan span) {
    return (MKCoordinateRegion){ center, span };
}
FOUNDATION_EXPORT MKCoordinateRegion MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2D centerCoordinate,
                                                                        CLLocationDistance latitudinalMeters, CLLocationDistance longitudinalMeters);

typedef NS_ENUM(NSUInteger, MKMapType) {
    MKMapTypeStandard = 0, MKMapTypeSatellite, MKMapTypeHybrid, MKMapTypeSatelliteFlyover, MKMapTypeHybridFlyover, MKMapTypeMutedStandard,
};
typedef NS_ENUM(NSInteger, MKUserTrackingMode) { MKUserTrackingModeNone = 0, MKUserTrackingModeFollow, MKUserTrackingModeFollowWithHeading };
typedef NS_ENUM(NSInteger, MKFeatureVisibility) { MKFeatureVisibilityAdaptive = 0, MKFeatureVisibilityHidden, MKFeatureVisibilityVisible };
typedef float MKFeatureDisplayPriority;
static const MKFeatureDisplayPriority MKFeatureDisplayPriorityRequired = 1000;
static const MKFeatureDisplayPriority MKFeatureDisplayPriorityDefaultHigh = 750;
static const MKFeatureDisplayPriority MKFeatureDisplayPriorityDefaultLow = 250;
typedef NSString *MKPointOfInterestCategory NS_TYPED_EXTENSIBLE_ENUM;
typedef NS_OPTIONS(NSUInteger, MKLocalSearchResultType) {
    MKLocalSearchResultTypeAddress = 1 << 0, MKLocalSearchResultTypePointOfInterest = 1 << 1, MKLocalSearchResultTypePhysicalFeature = 1 << 2,
};

/* annotations */
@protocol MKAnnotation <NSObject>
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@optional
@property (nonatomic, readonly, copy, nullable) NSString *title;
@property (nonatomic, readonly, copy, nullable) NSString *subtitle;
@end
@protocol MKOverlay <MKAnnotation>
@end

@interface MKShape : NSObject <MKAnnotation>
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@end
@interface MKPointAnnotation : MKShape
- (instancetype)init;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@end
@interface MKUserLocation : NSObject <MKAnnotation>
@property (readonly, nonatomic, getter=isUpdating) BOOL updating;
@property (readonly, nonatomic, nullable) CLLocation *location;
@property (readonly, nonatomic, nullable) CLHeading *heading;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *subtitle;
@end
/* a Swift class stub (its superclass is Core Location's): clang loads it with objc_loadClassref */
__attribute__((objc_class_stub)) __attribute__((objc_subclassing_restricted))
@interface MKPlacemark : CLPlacemark <MKAnnotation>
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate;
- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate addressDictionary:(nullable NSDictionary<NSString *, id> *)addressDictionary;
@property (nonatomic, readonly, nullable) NSString *countryCode;
@end

/* annotation views */
@interface MKAnnotationView : UIView
- (instancetype)initWithAnnotation:(nullable id<MKAnnotation>)annotation reuseIdentifier:(nullable NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, nullable) NSString *reuseIdentifier;
- (void)prepareForReuse;
@property (nonatomic, strong, nullable) id<MKAnnotation> annotation;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nonatomic) CGPoint centerOffset;
@property (nonatomic) CGPoint calloutOffset;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isSelected) BOOL selected;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
@property (nonatomic) BOOL canShowCallout;
@property (strong, nonatomic, nullable) UIView *leftCalloutAccessoryView;
@property (strong, nonatomic, nullable) UIView *rightCalloutAccessoryView;
@property (nonatomic, strong, nullable) UIView *detailCalloutAccessoryView;
@property (nonatomic, getter=isDraggable) BOOL draggable;
@property (nonatomic, copy, nullable) NSString *clusteringIdentifier;
@property (nonatomic) MKFeatureDisplayPriority displayPriority;
@end
@interface MKMarkerAnnotationView : MKAnnotationView
@property (nonatomic, copy, nullable) UIColor *markerTintColor;
@property (nonatomic, copy, nullable) UIColor *glyphTintColor;
@property (nonatomic, copy, nullable) NSString *glyphText;
@property (nonatomic, copy, nullable) UIImage *glyphImage;
@property (nonatomic, copy, nullable) UIImage *selectedGlyphImage;
@property (nonatomic) MKFeatureVisibility titleVisibility;
@property (nonatomic) MKFeatureVisibility subtitleVisibility;
@property (nonatomic) BOOL animatesWhenAdded;
@end
@interface MKPinAnnotationView : MKAnnotationView
+ (UIColor *)redPinColor;
+ (UIColor *)greenPinColor;
+ (UIColor *)purplePinColor;
@property (nonatomic, strong, null_resettable) UIColor *pinTintColor;
@property (nonatomic) BOOL animatesDrop;
@end

/* overlays */
@interface MKMultiPoint : MKShape
@property (nonatomic, readonly) NSUInteger pointCount;
- (void)getCoordinates:(CLLocationCoordinate2D *)coords range:(NSRange)range;
@end
@interface MKPolyline : MKMultiPoint <MKOverlay>
+ (instancetype)polylineWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end
@interface MKPolygon : MKMultiPoint <MKOverlay>
+ (instancetype)polygonWithCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end
@interface MKCircle : MKShape <MKOverlay>
+ (instancetype)circleWithCenterCoordinate:(CLLocationCoordinate2D)coord radius:(CLLocationDistance)radius;
@property (nonatomic, readonly) CLLocationDistance radius;
@end
@interface MKOverlayRenderer : NSObject
- (instancetype)initWithOverlay:(id<MKOverlay>)overlay;
@property (nonatomic, readonly) id<MKOverlay> overlay;
@property (nonatomic) CGFloat alpha;
- (void)setNeedsDisplay;
@end
@interface MKOverlayPathRenderer : MKOverlayRenderer
@property (nonatomic, strong, nullable) UIColor *fillColor;
@property (nonatomic, strong, nullable) UIColor *strokeColor;
@property (nonatomic) CGFloat lineWidth;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *lineDashPattern;
@end
@interface MKPolylineRenderer : MKOverlayPathRenderer
- (instancetype)initWithPolyline:(MKPolyline *)polyline;
@property (nonatomic, readonly) MKPolyline *polyline;
@end
@interface MKPolygonRenderer : MKOverlayPathRenderer
- (instancetype)initWithPolygon:(MKPolygon *)polygon;
@property (nonatomic, readonly) MKPolygon *polygon;
@end
@interface MKCircleRenderer : MKOverlayPathRenderer
- (instancetype)initWithCircle:(MKCircle *)circle;
@property (nonatomic, readonly) MKCircle *circle;
@end

/* the map view */
@protocol MKMapViewDelegate <NSObject>
@optional
- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated;
- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated;
- (void)mapViewDidChangeVisibleRegion:(MKMapView *)mapView;
- (void)mapViewWillStartLoadingMap:(MKMapView *)mapView;
- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView;
- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered;
- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation;
- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views;
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control;
- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view;
- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view;
- (void)mapView:(MKMapView *)mapView didSelectAnnotation:(id<MKAnnotation>)annotation;
- (void)mapView:(MKMapView *)mapView didDeselectAnnotation:(id<MKAnnotation>)annotation;
- (void)mapViewWillStartLocatingUser:(MKMapView *)mapView;
- (void)mapViewDidStopLocatingUser:(MKMapView *)mapView;
- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation;
- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error;
- (void)mapView:(MKMapView *)mapView didChangeUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated;
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay;
- (void)mapView:(MKMapView *)mapView didAddOverlayRenderers:(NSArray<MKOverlayRenderer *> *)renderers;
@end

@interface MKMapView : UIView
@property (nonatomic, weak, nullable) id<MKMapViewDelegate> delegate;
@property (nonatomic) MKMapType mapType;
@property (nonatomic) MKCoordinateRegion region;
- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated;
- (MKCoordinateRegion)regionThatFits:(MKCoordinateRegion)region;
@property (nonatomic) CLLocationCoordinate2D centerCoordinate;
- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated;
- (CGPoint)convertCoordinate:(CLLocationCoordinate2D)coordinate toPointToView:(nullable UIView *)view;
- (CLLocationCoordinate2D)convertPoint:(CGPoint)point toCoordinateFromView:(nullable UIView *)view;
@property (nonatomic, getter=isZoomEnabled) BOOL zoomEnabled;
@property (nonatomic, getter=isScrollEnabled) BOOL scrollEnabled;
@property (nonatomic, getter=isRotateEnabled) BOOL rotateEnabled;
@property (nonatomic, getter=isPitchEnabled) BOOL pitchEnabled;
@property (nonatomic) BOOL showsCompass;
@property (nonatomic) BOOL showsScale;
@property (nonatomic) BOOL showsBuildings;
@property (nonatomic) BOOL showsTraffic;
@property (nonatomic) BOOL showsPointsOfInterest;
@property (nonatomic) BOOL showsUserLocation;
@property (nonatomic, readonly) MKUserLocation *userLocation;
@property (nonatomic, readonly, getter=isUserLocationVisible) BOOL userLocationVisible;
@property (nonatomic) MKUserTrackingMode userTrackingMode;
- (void)setUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated;
@property (nonatomic, readonly) NSArray<id<MKAnnotation>> *annotations;
- (void)addAnnotation:(id<MKAnnotation>)annotation;
- (void)addAnnotations:(NSArray<id<MKAnnotation>> *)annotations;
- (void)removeAnnotation:(id<MKAnnotation>)annotation;
- (void)removeAnnotations:(NSArray<id<MKAnnotation>> *)annotations;
- (nullable MKAnnotationView *)viewForAnnotation:(id<MKAnnotation>)annotation;
- (void)registerClass:(nullable Class)viewClass forAnnotationViewWithReuseIdentifier:(NSString *)identifier;
- (nullable __kindof MKAnnotationView *)dequeueReusableAnnotationViewWithIdentifier:(NSString *)identifier;
- (__kindof MKAnnotationView *)dequeueReusableAnnotationViewWithIdentifier:(NSString *)identifier forAnnotation:(id<MKAnnotation>)annotation;
- (void)showAnnotations:(NSArray<id<MKAnnotation>> *)annotations animated:(BOOL)animated;
@property (nonatomic, copy) NSArray<id<MKAnnotation>> *selectedAnnotations;
- (void)selectAnnotation:(id<MKAnnotation>)annotation animated:(BOOL)animated;
- (void)deselectAnnotation:(nullable id<MKAnnotation>)annotation animated:(BOOL)animated;
@property (nonatomic, readonly) NSArray<id<MKOverlay>> *overlays;
- (void)addOverlay:(id<MKOverlay>)overlay;
- (void)removeOverlay:(id<MKOverlay>)overlay;
- (nullable MKOverlayRenderer *)rendererForOverlay:(id<MKOverlay>)overlay;
@end

/* map features: isim's basemap labels (landmarks are points of interest, cities territories) */
typedef NS_ENUM(NSInteger, MKMapFeatureType) { MKMapFeatureTypePointOfInterest = 0, MKMapFeatureTypeTerritory, MKMapFeatureTypePhysicalFeature } API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, MKMapFeatureOptions) {
    MKMapFeatureOptionPointsOfInterest = 1 << MKMapFeatureTypePointOfInterest,
    MKMapFeatureOptionTerritories = 1 << MKMapFeatureTypeTerritory,
    MKMapFeatureOptionPhysicalFeatures = 1 << MKMapFeatureTypePhysicalFeature,
} API_AVAILABLE(ios(16.0));
@interface MKMapView (MKMapFeatures)
@property (nonatomic) MKMapFeatureOptions selectableMapFeatures API_AVAILABLE(ios(16.0));
@end
API_AVAILABLE(ios(16.0))
@interface MKIconStyle : NSObject
@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIImage *image;
@end
API_AVAILABLE(ios(16.0))
@interface MKMapFeatureAnnotation : NSObject <MKAnnotation>
@property (nonatomic, readonly) MKMapFeatureType featureType;
@property (nonatomic, readonly, nullable) MKPointOfInterestCategory pointOfInterestCategory;
@property (nonatomic, readonly, nullable) MKIconStyle *iconStyle;
@end
API_AVAILABLE(ios(16.0))
@interface MKMapItemRequest : NSObject
- (instancetype)initWithMapFeatureAnnotation:(MKMapFeatureAnnotation *)mapFeatureAnnotation;
@property (nonatomic, readonly) MKMapFeatureAnnotation *featureAnnotation;
- (void)getMapItemWithCompletionHandler:(void (^)(MKMapItem * _Nullable mapItem, NSError * _Nullable error))completionHandler;
- (void)cancel;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
@end
typedef NS_ENUM(NSInteger, MKLookAroundBadgePosition) {
    MKLookAroundBadgePositionTopLeading = 0, MKLookAroundBadgePositionTopTrailing, MKLookAroundBadgePositionBottomTrailing,
} API_AVAILABLE(ios(16.0));
@interface MKUserTrackingBarButtonItem : UIBarButtonItem
- (instancetype)initWithMapView:(nullable MKMapView *)mapView;
@property (nonatomic, strong, nullable) MKMapView *mapView;
@end

/* map items and local search */
/* addresses (iOS 26) */
API_AVAILABLE(ios(26.0))
@interface MKAddress : NSObject
- (nullable instancetype)initWithFullAddress:(NSString *)fullAddress shortAddress:(nullable NSString *)shortAddress;
@property (nonatomic, readonly, copy) NSString *fullAddress;
@property (nonatomic, readonly, copy, nullable) NSString *shortAddress;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(26.0))
@interface MKAddressRepresentations : NSObject
- (nullable NSString *)fullAddressIncludingRegion:(BOOL)includingRegion singleLine:(BOOL)singleLine;
@property (nonatomic, readonly, copy, nullable) NSString *cityName;
@property (nonatomic, readonly, copy, nullable) NSString *cityWithContext;
@property (nonatomic, readonly, copy, nullable) NSString *regionName;
@property (nonatomic, readonly, copy, nullable) NSString *regionCode;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MKMapItem : NSObject
+ (MKMapItem *)mapItemForCurrentLocation;
- (instancetype)initWithPlacemark:(MKPlacemark *)placemark;
@property (nonatomic, readonly) MKPlacemark *placemark;
@property (nonatomic, readonly) BOOL isCurrentLocation;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *phoneNumber;
@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, copy, nullable) NSTimeZone *timeZone;
@property (nonatomic, copy, nullable) MKPointOfInterestCategory pointOfInterestCategory;
/* iOS 26: the location and its address */
- (instancetype)initWithLocation:(CLLocation *)location address:(nullable MKAddress *)address API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) CLLocation *location API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, nullable) MKAddress *address API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, nullable) MKAddressRepresentations *addressRepresentations API_AVAILABLE(ios(26.0));
@end
@interface MKLocalSearchRequest : NSObject
- (instancetype)init;
- (instancetype)initWithNaturalLanguageQuery:(NSString *)naturalLanguageQuery;
@property (nonatomic, copy, nullable) NSString *naturalLanguageQuery;
@property (nonatomic, assign) MKCoordinateRegion region;
@property (nonatomic, assign) MKLocalSearchResultType resultTypes;
@end
@interface MKLocalSearchResponse : NSObject
@property (nonatomic, readonly) NSArray<MKMapItem *> *mapItems;
@property (nonatomic, readonly) MKCoordinateRegion boundingRegion;
@end
typedef void (^MKLocalSearchCompletionHandler)(MKLocalSearchResponse * _Nullable response, NSError * _Nullable error);
@interface MKLocalSearch : NSObject
- (instancetype)initWithRequest:(MKLocalSearchRequest *)request NS_DESIGNATED_INITIALIZER;
- (void)startWithCompletionHandler:(MKLocalSearchCompletionHandler)completionHandler;
- (void)cancel;
@property (nonatomic, readonly, getter=isSearching) BOOL searching;
@end

/* geocoding (iOS 26): answered from isim's offline gazetteer, like CLGeocoder */
API_AVAILABLE(ios(26.0))
@interface MKGeocodingRequest : NSObject
- (nullable instancetype)initWithAddressString:(NSString *)addressString;
@property (nonatomic, readonly, copy) NSString *addressString;
@property (nonatomic, copy, nullable) NSLocale *preferredLocale;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> * _Nullable mapItems, NSError * _Nullable error))completionHandler;
- (void)cancel;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(26.0))
@interface MKReverseGeocodingRequest : NSObject
- (nullable instancetype)initWithLocation:(CLLocation *)location;
@property (nonatomic, readonly, copy) CLLocation *location;
@property (nonatomic, copy, nullable) NSLocale *preferredLocale;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly, getter=isLoading) BOOL loading;
- (void)getMapItemsWithCompletionHandler:(void (^)(NSArray<MKMapItem *> * _Nullable mapItems, NSError * _Nullable error))completionHandler;
- (void)cancel;
- (instancetype)init NS_UNAVAILABLE;
@end

/* the distance formatter: metric (m, km) or imperial (ft then mi; yd) */
typedef NS_ENUM(NSUInteger, MKDistanceFormatterUnits) {
    MKDistanceFormatterUnitsDefault, MKDistanceFormatterUnitsMetric, MKDistanceFormatterUnitsImperial, MKDistanceFormatterUnitsImperialWithYards,
};
typedef NS_ENUM(NSUInteger, MKDistanceFormatterUnitStyle) {
    MKDistanceFormatterUnitStyleDefault = 0, MKDistanceFormatterUnitStyleAbbreviated, MKDistanceFormatterUnitStyleFull,
};
@interface MKDistanceFormatter : NSFormatter
- (NSString *)stringFromDistance:(CLLocationDistance)distance;
- (CLLocationDistance)distanceFromString:(NSString *)distance;
@property (copy, null_resettable) NSLocale *locale;
@property (assign) MKDistanceFormatterUnits units;
@property (assign) MKDistanceFormatterUnitStyle unitStyle;
@end

/* GeoJSON */
@protocol MKGeoJSONObject <NSObject>
@end
@interface MKGeoJSONFeature : NSObject <MKGeoJSONObject>
@property (nonatomic, readonly, nullable) NSString *identifier;
@property (nonatomic, readonly, nullable) NSData *properties;
@property (nonatomic, readonly) NSArray<__kindof MKShape<MKGeoJSONObject> *> *geometry;
@end
@interface MKGeoJSONDecoder : NSObject
- (nullable NSArray<id<MKGeoJSONObject>> *)geoJSONObjectsWithData:(NSData *)data error:(NSError **)errorPtr;
@end

typedef NSString * MKLaunchOptionsKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsMapTypeKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsMapCenterKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsMapSpanKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsShowsTrafficKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsCameraKey;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeDefault;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeDriving;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeWalking;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeTransit;
FOUNDATION_EXPORT NSString * const MKLaunchOptionsDirectionsModeCycling;

NS_ASSUME_NONNULL_END
#endif
