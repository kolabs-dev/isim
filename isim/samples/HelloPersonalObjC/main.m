// Sample: location and personal data from Objective-C (issue #232): CoreLocation (the permission prompt, location
// updates, CLLocation, region monitoring, CLGeocoder), MapKit (MKMapView with a region, MKPointAnnotation and an app
// annotation class, MKMarkerAnnotationView from the delegate, an MKPolyline overlay with its renderer, MKLocalSearch),
// Contacts (saving and finding a contact with labeled values), ContactsUI (the contact picker) and EventKit /
// EventKitUI (saving and finding an event, the event editor). Each step prints a "po ..." line the test checks.
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("po %s\n", s.UTF8String); fflush(stdout);
}
static NSString *errText(NSError *e) { return e ? [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code] : @"nil"; }

/// an app's own annotation class, as Objective-C apps write them
@interface Cafe : NSObject <MKAnnotation>
@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@end
@implementation Cafe
@end

@interface ViewController : UIViewController <CLLocationManagerDelegate, MKMapViewDelegate, CNContactPickerDelegate, EKEventEditViewDelegate>
@property (nonatomic, strong) CLLocationManager *manager;
@property (nonatomic, strong) MKMapView *map;
@property (nonatomic, strong) Cafe *cafe;
@property (nonatomic, strong) EKEventStore *events;
@property (nonatomic) BOOL located;
@end

@implementation ViewController
- (UIButton *)button:(NSString *)title id:(NSString *)ident x:(CGFloat)x action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    b.accessibilityIdentifier = ident;
    b.frame = CGRectMake(x, self.view.bounds.size.height - 120, 120, 44);
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:b];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.map = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 140)];
    self.map.delegate = self;
    [self.view addSubview:self.map];
    [self button:@"Contacts" id:@"pick" x:16 action:@selector(pickContact)];
    [self button:@"New Event" id:@"event" x:self.view.bounds.size.width - 136 action:@selector(editEvent)];
    [self location];
    [self mapKit];
    [self contacts];
    [self calendar];
}

#pragma mark CoreLocation
- (void)location {
    self.manager = [[CLLocationManager alloc] init];
    self.manager.delegate = self;
    self.manager.desiredAccuracy = kCLLocationAccuracyBest;
    say(@"location services=%d status=%d delegate=%d", [CLLocationManager locationServicesEnabled], self.manager.authorizationStatus,
        self.manager.delegate == self);
    [self.manager requestWhenInUseAuthorization];
    CLLocation *a = [[CLLocation alloc] initWithLatitude:37.3349 longitude:-122.0090];
    CLLocation *b = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.7749, -122.4194) altitude:10 horizontalAccuracy:5
                                         verticalAccuracy:5 timestamp:[NSDate date]];
    say(@"distance %.0f km lat=%.4f valid=%d", [a distanceFromLocation:b] / 1000, b.coordinate.latitude,
        CLLocationCoordinate2DIsValid(kCLLocationCoordinate2DInvalid));
    CLCircularRegion *r = [[CLCircularRegion alloc] initWithCenter:a.coordinate radius:200 identifier:@"park"];
    say(@"region %@ radius=%.0f contains=%d", r.identifier, r.radius, [r containsCoordinate:CLLocationCoordinate2DMake(37.3350, -122.0091)]);
    [[[CLGeocoder alloc] init] reverseGeocodeLocation:a completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        say(@"geocode %@ error=%@", placemarks.firstObject.locality, errText(error));
    }];
}
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    say(@"authorization %d", manager.authorizationStatus);
    if (manager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) [manager startUpdatingLocation];
}
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    say(@"authorization status callback %d", status);
}
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (self.located) return;
    self.located = YES;
    CLLocation *l = locations.lastObject;
    say(@"located %.4f,%.4f accuracy=%d", l.coordinate.latitude, l.coordinate.longitude, l.horizontalAccuracy >= 0);
    [manager stopUpdatingLocation];
}

#pragma mark MapKit
- (void)mapKit {
    CLLocationCoordinate2D park = CLLocationCoordinate2DMake(37.3349, -122.0090);
    [self.map setRegion:MKCoordinateRegionMakeWithDistance(park, 2000, 2000) animated:NO];
    MKCoordinateRegion r = self.map.region;
    say(@"map region %.3f,%.3f span=%.3f", r.center.latitude, r.center.longitude, r.span.latitudeDelta);
    // map features: the basemap's landmarks and cities can be selected; a bar button cycles the tracking mode
    self.map.selectableMapFeatures = MKMapFeatureOptionPointsOfInterest | MKMapFeatureOptionTerritories;
    MKUserTrackingBarButtonItem *tracking = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.map];
    say(@"map features=%lu tracking item map=%d", (unsigned long)self.map.selectableMapFeatures, tracking.mapView == self.map);
    MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
    pin.coordinate = park;
    pin.title = @"Apple Park";
    self.cafe = [[Cafe alloc] init];
    self.cafe.coordinate = CLLocationCoordinate2DMake(37.3310, -122.0040);
    self.cafe.title = @"Caffè Macs";
    [self.map addAnnotations:@[pin, self.cafe]];
    say(@"annotations %lu cafe=%d", (unsigned long)self.map.annotations.count, [self.map.annotations containsObject:self.cafe]);
    // clustering and dragging (issue #417): a cluster annotation of both, and the café's marker can be dragged (a long
    // press, then move): the map sets its coordinate through the Cafe class's setCoordinate:
    MKClusterAnnotation *cluster = [[MKClusterAnnotation alloc] initWithMemberAnnotations:@[pin, self.cafe]];
    CLLocationCoordinate2D mid = cluster.coordinate;
    say(@"cluster members=%lu cafe=%d title=%@ middle=%d", (unsigned long)cluster.memberAnnotations.count,
        cluster.memberAnnotations[1] == self.cafe, cluster.title ?: @"nil",
        mid.latitude < park.latitude && mid.latitude > self.cafe.coordinate.latitude);
    MKAnnotationView *cafeView = [self.map viewForAnnotation:self.cafe];
    cafeView.draggable = YES;
    say(@"cafe draggable=%d state=%lu cluster view=%@", cafeView.isDraggable, (unsigned long)cafeView.dragState,
        cafeView.clusterAnnotationView ? @"set" : @"nil");
    dispatch_async(dispatch_get_main_queue(), ^{
        CGPoint p = [self.map convertCoordinate:self.cafe.coordinate toPointToView:self.view];
        say(@"cafe marker at %.0f,%.0f", p.x, p.y);
    });
    CLLocationCoordinate2D path[3] = { park, CLLocationCoordinate2DMake(37.3320, -122.0060), self.cafe.coordinate };
    MKPolyline *line = [MKPolyline polylineWithCoordinates:path count:3];
    [self.map addOverlay:line];
    say(@"overlay points=%lu", (unsigned long)line.pointCount);
    MKLocalSearchRequest *q = [[MKLocalSearchRequest alloc] initWithNaturalLanguageQuery:@"coffee"];
    q.region = self.map.region;
    [[[MKLocalSearch alloc] initWithRequest:q] startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        say(@"search error=%@ items=%d", errText(error), response != nil || error != nil);
    }];
}
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if (![annotation isKindOfClass:[Cafe class]]) return nil;
    MKMarkerAnnotationView *v = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"cafe"];
    if (!v) v = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"cafe"];
    v.markerTintColor = UIColor.systemBrownColor;
    v.glyphText = @"☕";
    v.canShowCallout = YES;
    say(@"view for %@ is cafe=%d", annotation.title, v.annotation == annotation);
    return v;
}
- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    MKPolylineRenderer *r = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
    r.strokeColor = UIColor.systemBlueColor;
    r.lineWidth = 5;
    say(@"renderer for polyline");
    return r;
}
- (void)mapView:(MKMapView *)mapView didSelectAnnotation:(id<MKAnnotation>)annotation { say(@"selected %@", annotation.title); }
- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState
   fromOldState:(MKAnnotationViewDragState)oldState {
    CLLocationCoordinate2D c = view.annotation.coordinate;
    say(@"drag %@ %lu from %lu at %.4f,%.4f", view.annotation.title, (unsigned long)newState, (unsigned long)oldState, c.latitude, c.longitude);
}

#pragma mark Contacts
- (void)contacts {
    CNContactStore *store = [[CNContactStore alloc] init];
    [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
        CNMutableContact *c = [[CNMutableContact alloc] init];
        c.givenName = @"Dana";
        c.familyName = @"Objc";
        c.phoneNumbers = @[[CNLabeledValue labeledValueWithLabel:CNLabelPhoneNumberMobile value:[CNPhoneNumber phoneNumberWithStringValue:@"+1 555 0100"]]];
        c.emailAddresses = @[[CNLabeledValue labeledValueWithLabel:CNLabelWork value:@"dana@example.com"]];
        CNSaveRequest *save = [[CNSaveRequest alloc] init];
        [save addContact:c toContainerWithIdentifier:nil];
        NSError *e = nil;
        BOOL ok = [store executeSaveRequest:save error:&e];
        NSArray *keys = @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey, CNContactEmailAddressesKey];
        NSArray<CNContact *> *found = [store unifiedContactsMatchingPredicate:[CNContact predicateForContactsMatchingName:@"Dana"] keysToFetch:keys error:&e];
        CNContact *f = found.firstObject;
        CNLabeledValue<CNPhoneNumber *> *phone = f.phoneNumbers.firstObject;
        say(@"contacts granted=%d saved=%d found=%lu name=%@ phone=%@ label=%@ email=%@ error=%@", granted, ok, (unsigned long)found.count,
            [CNContactFormatter stringFromContact:f style:CNContactFormatterStyleFullName], phone.value.stringValue,
            [phone.label isEqualToString:CNLabelPhoneNumberMobile] ? @"mobile" : phone.label, f.emailAddresses.firstObject.value, errText(e));
    }];
}
- (void)pickContact {
    CNContactPickerViewController *p = [[CNContactPickerViewController alloc] init];
    p.delegate = self;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)contactPicker:(CNContactPickerViewController *)picker didSelectContact:(CNContact *)contact {
    say(@"picked %@ %@", contact.givenName, contact.familyName);
}
- (void)contactPickerDidCancel:(CNContactPickerViewController *)picker { say(@"picker canceled"); }

#pragma mark EventKit
- (void)calendar {
    self.events = [[EKEventStore alloc] init];
    [self.events requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError *error) {
        EKEvent *e = [EKEvent eventWithEventStore:self.events];
        e.title = @"Objective-C sync";
        e.startDate = [NSDate dateWithTimeIntervalSinceNow:3600];
        e.endDate = [e.startDate dateByAddingTimeInterval:1800];
        e.calendar = self.events.defaultCalendarForNewEvents;
        [e addAlarm:[EKAlarm alarmWithRelativeOffset:-600]];
        NSError *err = nil;
        BOOL ok = [self.events saveEvent:e span:EKSpanThisEvent error:&err];
        NSPredicate *p = [self.events predicateForEventsWithStartDate:[NSDate date] endDate:[NSDate dateWithTimeIntervalSinceNow:7200] calendars:nil];
        NSArray<EKEvent *> *found = [self.events eventsMatchingPredicate:p];
        EKEvent *f = [self.events eventWithIdentifier:e.eventIdentifier];
        say(@"calendar granted=%d status=%ld saved=%d found=%lu title=%@ alarms=%lu error=%@", granted,
            (long)[EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent], ok, (unsigned long)found.count, f.title,
            (unsigned long)f.alarms.count, errText(err));
        // the last weekday of each month, twice; a structured location; a location alarm
        NSMutableArray *weekdays = [NSMutableArray array];
        for (NSInteger d = EKWeekdayMonday; d <= EKWeekdayFriday; d++) [weekdays addObject:[EKRecurrenceDayOfWeek dayOfWeek:(EKWeekday)d]];
        EKRecurrenceRule *rule = [[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyMonthly interval:1 daysOfTheWeek:weekdays
            daysOfTheMonth:nil monthsOfTheYear:nil weeksOfTheYear:nil daysOfTheYear:nil setPositions:@[@-1] end:[EKRecurrenceEnd recurrenceEndWithOccurrenceCount:2]];
        EKEvent *r = [EKEvent eventWithEventStore:self.events];
        r.title = @"Month-end review"; r.calendar = self.events.defaultCalendarForNewEvents;
        r.startDate = [NSDate dateWithTimeIntervalSinceNow:600]; r.endDate = [r.startDate dateByAddingTimeInterval:1800];
        [r addRecurrenceRule:rule];
        EKStructuredLocation *office = [EKStructuredLocation locationWithTitle:@"Office"];
        office.geoLocation = [[CLLocation alloc] initWithLatitude:37.3349 longitude:-122.00902]; office.radius = 100;
        r.structuredLocation = office;
        EKAlarm *arrive = [EKAlarm alarmWithRelativeOffset:0]; arrive.structuredLocation = office; arrive.proximity = EKAlarmProximityEnter;
        [r addAlarm:arrive];
        BOOL saved = [self.events saveEvent:r span:EKSpanFutureEvents error:nil];
        NSArray<EKEvent *> *months = [self.events eventsMatchingPredicate:[self.events predicateForEventsWithStartDate:[NSDate date]
            endDate:[NSDate dateWithTimeIntervalSinceNow:75 * 86400] calendars:nil]];
        NSUInteger n = 0, weekday = 0;
        NSDateFormatter *day = [[NSDateFormatter alloc] init];
        day.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; day.dateFormat = @"EEE";
        for (EKEvent *o in months) if ([o.title isEqualToString:@"Month-end review"]) {
            n++; if (![@[@"Sat", @"Sun"] containsObject:[day stringFromDate:o.startDate]]) weekday++;
        }
        EKEvent *back = [self.events eventWithIdentifier:r.eventIdentifier];
        EKRecurrenceRule *br = back.recurrenceRules.firstObject;
        say(@"recurring saved=%d occurrences=%lu weekdays=%lu days=%lu positions=%@ location=%@ radius=%.0f proximity=%ld", saved, (unsigned long)n,
            (unsigned long)weekday, (unsigned long)br.daysOfTheWeek.count, br.setPositions.firstObject, back.structuredLocation.title,
            back.structuredLocation.radius, (long)back.alarms.firstObject.proximity);
    }];
}
- (void)editEvent {
    EKEventEditViewController *v = [[EKEventEditViewController alloc] init];
    v.eventStore = self.events;
    v.editViewDelegate = self;
    [self presentViewController:v animated:YES completion:nil];
}
- (void)eventEditViewController:(EKEventEditViewController *)controller didCompleteWithAction:(EKEventEditViewAction)action {
    say(@"editor done action=%ld", (long)action);
    [controller dismissViewControllerAnimated:YES completion:nil];
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
