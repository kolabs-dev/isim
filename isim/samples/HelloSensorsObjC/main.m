// Sample: sensors and health from Objective-C (issue #315): HealthKit (authorization, saving a sample, a sample query and
// a statistics query, units), Core Motion's pedometer, motion activity and altimeter (unavailable, like the Simulator),
// Core Bluetooth (central and peripheral managers: unsupported, a mutable service) and Core NFC (an NDEF reader session
// that is invalidated, NDEF payloads, an APDU). Each step prints a "po ..." line the test checks.
#import <UIKit/UIKit.h>
#import <HealthKit/HealthKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreNFC/CoreNFC.h>

static void say(NSString *fmt, ...) NS_FORMAT_FUNCTION(1, 2);
static void say(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    printf("po %s\n", s.UTF8String); fflush(stdout);
}
static NSString *errText(NSError *e) { return e ? [NSString stringWithFormat:@"%@/%ld", e.domain, (long)e.code] : @"nil"; }

@interface ViewController : UIViewController <CBCentralManagerDelegate, CBPeripheralManagerDelegate, NFCNDEFReaderSessionDelegate,
                                              CMWaterSubmersionManagerDelegate>
@property (nonatomic, strong) HKHealthStore *health;
@property (nonatomic, strong) CMPedometer *pedometer;
@property (nonatomic, strong) CMAltimeter *altimeter;
@property (nonatomic, strong) CMWaterSubmersionManager *water;
@property (nonatomic, strong) CMBatchedSensorManager *batched;
@property (nonatomic, strong) CBCentralManager *central;
@property (nonatomic, strong) CBPeripheralManager *peripheral;
@property (nonatomic, strong) NFCNDEFReaderSession *nfc;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, 300, 40)];
    title.text = @"Sensors ObjC"; title.font = [UIFont boldSystemFontOfSize:28];
    [self.view addSubview:title];
    [self health:nil];
}

// MARK: HealthKit
- (void)health:(id)sender {
    say(@"health available %d", HKHealthStore.isHealthDataAvailable);
    self.health = [HKHealthStore new];
    HKQuantityType *steps = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
    HKUnit *kmh = [[HKUnit meterUnitWithMetricPrefix:HKMetricPrefixKilo] unitDividedByUnit:HKUnit.hourUnit];
    HKQuantity *mile = [HKQuantity quantityWithUnit:HKUnit.mileUnit doubleValue:1];
    say(@"health units %@ mile %.0f m compatible %d", kmh.unitString, [mile doubleValueForUnit:HKUnit.meterUnit], [steps isCompatibleWithUnit:HKUnit.countUnit]);
    [self.health requestAuthorizationToShareTypes:[NSSet setWithObject:steps] readTypes:[NSSet setWithObject:steps] completion:^(BOOL ok, NSError *e) {
        say(@"health authorized %d status %ld error %@", ok, (long)[self.health authorizationStatusForType:steps], errText(e));
        NSDate *now = NSDate.date;
        HKQuantitySample *s = [HKQuantitySample quantitySampleWithType:steps quantity:[HKQuantity quantityWithUnit:HKUnit.countUnit doubleValue:1200]
                                                             startDate:[now dateByAddingTimeInterval:-600] endDate:now];
        [self.health saveObject:s withCompletion:^(BOOL saved, NSError *se) {
            say(@"health saved %d error %@", saved, errText(se));
            NSPredicate *p = [HKQuery predicateForSamplesWithStartDate:[now dateByAddingTimeInterval:-3600] endDate:nil options:HKQueryOptionNone];
            HKSampleQuery *q = [[HKSampleQuery alloc] initWithSampleType:steps predicate:p limit:HKObjectQueryNoLimit
                sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:NO]]
                resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *qe) {
                    HKQuantitySample *first = results.firstObject;
                    say(@"health query %lu first %.0f source %@", (unsigned long)results.count, [first.quantity doubleValueForUnit:HKUnit.countUnit],
                        first.sourceRevision.source.bundleIdentifier);
                    HKStatisticsQuery *sum = [[HKStatisticsQuery alloc] initWithQuantityType:steps quantitySamplePredicate:p
                        options:HKStatisticsOptionCumulativeSum completionHandler:^(HKStatisticsQuery *sq, HKStatistics *st, NSError *ste) {
                            say(@"health sum %.0f", [st.sumQuantity doubleValueForUnit:HKUnit.countUnit]);
                            [self changes:steps];
                        }];
                    [self.health executeQuery:sum];
                }];
            [self.health executeQuery:q];
        }];
    }];
}

// anchored object query (archived anchor), source query, background delivery
- (void)changes:(HKQuantityType *)steps {
    HKAnchoredObjectQuery *q = [[HKAnchoredObjectQuery alloc] initWithType:steps predicate:nil anchor:nil limit:HKObjectQueryNoLimit
        resultsHandler:^(HKAnchoredObjectQuery *query, NSArray<HKSample *> *added, NSArray<HKDeletedObject *> *deleted, HKQueryAnchor *anchor, NSError *e) {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:anchor requiringSecureCoding:YES error:nil];
            HKQueryAnchor *back = [NSKeyedUnarchiver unarchivedObjectOfClass:HKQueryAnchor.class fromData:data error:nil];
            say(@"health anchored added %lu deleted %lu archived %d", (unsigned long)added.count, (unsigned long)deleted.count, [back isEqual:anchor]);
            HKSourceQuery *sq = [[HKSourceQuery alloc] initWithSampleType:steps samplePredicate:nil
                completionHandler:^(HKSourceQuery *sourceQuery, NSSet<HKSource *> *sources, NSError *se) {
                    say(@"health sources %lu %@", (unsigned long)sources.count, sources.anyObject.bundleIdentifier);
                    [self.health enableBackgroundDeliveryForType:steps frequency:HKUpdateFrequencyImmediate withCompletion:^(BOOL ok, NSError *be) {
                        say(@"health background %d error %@", ok, errText(be));
                        dispatch_async(dispatch_get_main_queue(), ^{ [self motion]; });
                    }];
                }];
            [self.health executeQuery:sq];
        }];
    [self.health executeQuery:q];
}

// MARK: Core Motion
- (void)motion {
    say(@"motion steps %d floors %d activity %d altimeter %d status %ld", CMPedometer.isStepCountingAvailable, CMPedometer.isFloorCountingAvailable,
        CMMotionActivityManager.isActivityAvailable, CMAltimeter.isRelativeAltitudeAvailable, (long)CMPedometer.authorizationStatus);
    self.pedometer = [CMPedometer new];
    [self.pedometer queryPedometerDataFromDate:[NSDate dateWithTimeIntervalSinceNow:-3600] toDate:NSDate.date withHandler:^(CMPedometerData *d, NSError *e) {
        say(@"motion pedometer %@ error %@", d.numberOfSteps, errText(e));
        dispatch_async(dispatch_get_main_queue(), ^{
            self.altimeter = [CMAltimeter new];
            [self.altimeter startRelativeAltitudeUpdatesToQueue:NSOperationQueue.mainQueue withHandler:^(CMAltitudeData *a, NSError *ae) {
                say(@"motion altimeter %@ error %@", a.relativeAltitude, errText(ae));
                [self motionExtras];
                [self bluetooth];
            }];
        });
    }];
}

// issue #414: the sensors the Simulator lacks answer "not available"
- (void)motionExtras {
    CMHeadphoneMotionManager *h = [CMHeadphoneMotionManager new];
    [h startConnectionStatusUpdates];
    CMSensorRecorder *r = [CMSensorRecorder new];
    say(@"motion extras headphones %d connection %d batched %d %d recorder %d data %@ water %d", h.deviceMotionAvailable, h.connectionStatusActive,
        CMBatchedSensorManager.accelerometerSupported, CMBatchedSensorManager.deviceMotionSupported, CMSensorRecorder.isAccelerometerRecordingAvailable,
        [r accelerometerDataFromDate:[NSDate dateWithTimeIntervalSinceNow:-60] toDate:NSDate.date], CMWaterSubmersionManager.waterSubmersionAvailable);
    self.batched = [CMBatchedSensorManager new];
    [self.batched startAccelerometerUpdatesWithHandler:^(NSArray<CMAccelerometerData *> *batch, NSError *e) {
        say(@"motion batched %@ error %@", batch, errText(e));
    }];
    [self.altimeter startAbsoluteAltitudeUpdatesToQueue:NSOperationQueue.mainQueue withHandler:^(CMAbsoluteAltitudeData *a, NSError *e) {
        say(@"motion absolute altitude %@ error %@", a, errText(e));
    }];
    self.water = [CMWaterSubmersionManager new];
    self.water.delegate = self;
}
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateEvent:(CMWaterSubmersionEvent *)event { say(@"motion water event"); }
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateMeasurement:(CMWaterSubmersionMeasurement *)measurement { say(@"motion water depth"); }
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateTemperature:(CMWaterTemperature *)measurement { say(@"motion water temperature"); }
- (void)manager:(CMWaterSubmersionManager *)manager errorOccurred:(NSError *)error { say(@"motion water error %@", errText(error)); }

// MARK: Core Bluetooth
- (void)bluetooth {
    CBUUID *rate = [CBUUID UUIDWithString:@"2a37"];
    CBMutableCharacteristic *c = [[CBMutableCharacteristic alloc] initWithType:rate properties:CBCharacteristicPropertyRead | CBCharacteristicPropertyNotify
                                                                         value:nil permissions:CBAttributePermissionsReadable];
    CBMutableService *service = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:@"180D"] primary:YES];
    service.characteristics = @[c];
    say(@"bluetooth service %@ primary %d characteristic %@ properties %lu linked %d", service.UUID.UUIDString, service.isPrimary,
        c.UUID.UUIDString, (unsigned long)c.properties, c.service == service);
    self.central = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    say(@"bluetooth central state %ld authorization %ld", (long)central.state, (long)CBManager.authorization);
    [central scanForPeripheralsWithServices:nil options:@{ CBCentralManagerScanOptionAllowDuplicatesKey: @NO }];
    self.peripheral = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    say(@"bluetooth peripheral state %ld advertising %d", (long)peripheral.state, peripheral.isAdvertising);
    [peripheral startAdvertising:@{ CBAdvertisementDataLocalNameKey: @"Sensors" }];
    [self nfcSession];
}

// MARK: Core NFC
- (void)nfcSession {
    NFCNDEFPayload *uri = [NFCNDEFPayload wellKnownTypeURIPayloadWithString:@"https://example.com"];
    NFCNDEFMessage *message = [[NFCNDEFMessage alloc] initWithNDEFRecords:@[uri]];
    NFCISO7816APDU *apdu = [[NFCISO7816APDU alloc] initWithData:[NSData dataWithBytes:(uint8_t[]){ 0x00, 0xA4, 0x04, 0x00, 0x00 } length:5]];
    say(@"nfc available %d records %lu format %d apdu ins %02X le %ld", NFCNDEFReaderSession.readingAvailable, (unsigned long)message.records.count,
        uri.typeNameFormat, apdu.instructionCode, (long)apdu.expectedResponseLength);
    self.nfc = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:nil invalidateAfterFirstRead:YES];
    self.nfc.alertMessage = @"Hold your iPhone near a tag";
    [self.nfc beginSession];
}
- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
    say(@"nfc invalidated %@", errText(error));
}
- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [ViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
