#pragma once
/* isim Core Motion for Objective-C: the classes are the CoreMotion Swift overlay's (CoreMotion.framework re-exports
   libswiftCoreMotion.dylib): an iPhone held upright and at rest (see the overlay). Swift uses the overlay; these
   declarations are hidden from Swift. Like the Simulator, the pedometer, motion activity, the altimeter and headphone
   motion are not available. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef struct { double x, y, z; } CMAcceleration;
typedef struct { double x, y, z; } CMRotationRate;
typedef struct { double x, y, z; } CMMagneticField;
typedef struct { double x, y, z, w; } CMQuaternion;
typedef struct { double m11, m12, m13, m21, m22, m23, m31, m32, m33; } CMRotationMatrix;
typedef NS_ENUM(int, CMMagneticFieldCalibrationAccuracy) {
    CMMagneticFieldCalibrationAccuracyUncalibrated = -1, CMMagneticFieldCalibrationAccuracyLow, CMMagneticFieldCalibrationAccuracyMedium,
    CMMagneticFieldCalibrationAccuracyHigh,
};
typedef struct { CMMagneticField field; CMMagneticFieldCalibrationAccuracy accuracy; } CMCalibratedMagneticField;
typedef NS_OPTIONS(NSUInteger, CMAttitudeReferenceFrame) {
    CMAttitudeReferenceFrameXArbitraryZVertical = 1 << 0, CMAttitudeReferenceFrameXArbitraryCorrectedZVertical = 1 << 1,
    CMAttitudeReferenceFrameXMagneticNorthZVertical = 1 << 2, CMAttitudeReferenceFrameXTrueNorthZVertical = 1 << 3,
};
typedef NS_ENUM(NSInteger, CMDeviceMotionSensorLocation) { CMDeviceMotionSensorLocationDefault, CMDeviceMotionSensorLocationHeadphoneLeft, CMDeviceMotionSensorLocationHeadphoneRight };
FOUNDATION_EXPORT NSString * const CMErrorDomain;

@interface CMLogItem : NSObject
@property (readonly, nonatomic) NSTimeInterval timestamp;
@end
@interface CMAccelerometerData : CMLogItem
@property (readonly, nonatomic) CMAcceleration acceleration;
@end
@interface CMGyroData : CMLogItem
@property (readonly, nonatomic) CMRotationRate rotationRate;
@end
@interface CMMagnetometerData : CMLogItem
@property (readonly, nonatomic) CMMagneticField magneticField;
@end
@interface CMAttitude : NSObject <NSCopying>
@property (readonly, nonatomic) double roll;
@property (readonly, nonatomic) double pitch;
@property (readonly, nonatomic) double yaw;
@property (readonly, nonatomic) CMRotationMatrix rotationMatrix;
@property (readonly, nonatomic) CMQuaternion quaternion;
- (void)multiplyByInverseOfAttitude:(CMAttitude *)attitude;
@end
@interface CMDeviceMotion : CMLogItem
@property (readonly, nonatomic) CMAttitude *attitude;
@property (readonly, nonatomic) CMRotationRate rotationRate;
@property (readonly, nonatomic) CMAcceleration gravity;
@property (readonly, nonatomic) CMAcceleration userAcceleration;
@property (readonly, nonatomic) CMCalibratedMagneticField magneticField;
@property (readonly, nonatomic) double heading;
@property (readonly, nonatomic) CMDeviceMotionSensorLocation sensorLocation;
@end
typedef void (^CMAccelerometerHandler)(CMAccelerometerData * _Nullable accelerometerData, NSError * _Nullable error);
typedef void (^CMGyroHandler)(CMGyroData * _Nullable gyroData, NSError * _Nullable error);
typedef void (^CMMagnetometerHandler)(CMMagnetometerData * _Nullable magnetometerData, NSError * _Nullable error);
typedef void (^CMDeviceMotionHandler)(CMDeviceMotion * _Nullable motion, NSError * _Nullable error);
@interface CMMotionManager : NSObject
@property (assign, nonatomic) NSTimeInterval accelerometerUpdateInterval;
@property (readonly, nonatomic, getter=isAccelerometerAvailable) BOOL accelerometerAvailable;
@property (readonly, nonatomic, getter=isAccelerometerActive) BOOL accelerometerActive;
@property (readonly, nullable) CMAccelerometerData *accelerometerData;
- (void)startAccelerometerUpdates;
- (void)startAccelerometerUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAccelerometerHandler)handler;
- (void)stopAccelerometerUpdates;
@property (assign, nonatomic) NSTimeInterval gyroUpdateInterval;
@property (readonly, nonatomic, getter=isGyroAvailable) BOOL gyroAvailable;
@property (readonly, nonatomic, getter=isGyroActive) BOOL gyroActive;
@property (readonly, nullable) CMGyroData *gyroData;
- (void)startGyroUpdates;
- (void)startGyroUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMGyroHandler)handler;
- (void)stopGyroUpdates;
@property (assign, nonatomic) NSTimeInterval magnetometerUpdateInterval;
@property (readonly, nonatomic, getter=isMagnetometerAvailable) BOOL magnetometerAvailable;
@property (readonly, nonatomic, getter=isMagnetometerActive) BOOL magnetometerActive;
@property (readonly, nullable) CMMagnetometerData *magnetometerData;
- (void)startMagnetometerUpdates;
- (void)startMagnetometerUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMMagnetometerHandler)handler;
- (void)stopMagnetometerUpdates;
@property (assign, nonatomic) NSTimeInterval deviceMotionUpdateInterval;
+ (CMAttitudeReferenceFrame)availableAttitudeReferenceFrames;
@property (readonly, nonatomic) CMAttitudeReferenceFrame attitudeReferenceFrame;
@property (readonly, nonatomic, getter=isDeviceMotionAvailable) BOOL deviceMotionAvailable;
@property (readonly, nonatomic, getter=isDeviceMotionActive) BOOL deviceMotionActive;
@property (readonly, nullable) CMDeviceMotion *deviceMotion;
- (void)startDeviceMotionUpdates;
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler;
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)referenceFrame;
- (void)startDeviceMotionUpdatesUsingReferenceFrame:(CMAttitudeReferenceFrame)referenceFrame toQueue:(NSOperationQueue *)queue
                                        withHandler:(CMDeviceMotionHandler)handler;
- (void)stopDeviceMotionUpdates;
@property (assign, nonatomic) BOOL showsDeviceMovementDisplay;
@end

typedef NS_ENUM(NSInteger, CMAuthorizationStatus) {
    CMAuthorizationStatusNotDetermined = 0, CMAuthorizationStatusRestricted, CMAuthorizationStatusDenied, CMAuthorizationStatusAuthorized,
};
typedef NS_ENUM(NSInteger, CMError) {
    CMErrorNULL = 100, CMErrorDeviceRequiresMovement, CMErrorTrueNorthNotAvailable, CMErrorUnknown, CMErrorMotionActivityNotAvailable,
    CMErrorMotionActivityNotAuthorized, CMErrorMotionActivityNotEntitled, CMErrorInvalidParameter, CMErrorInvalidAction,
    CMErrorNotAvailable, CMErrorNotEntitled, CMErrorNotAuthorized, CMErrorNilData, CMErrorSize,
};

/* the pedometer, motion activity and the altimeter: unavailable like the Simulator; queries fail with
   CMErrorMotionActivityNotAvailable (CMErrorMotionActivityNotAuthorized without NSMotionUsageDescription) */
@interface CMPedometerData : NSObject
@property (readonly, nonatomic) NSDate *startDate;
@property (readonly, nonatomic) NSDate *endDate;
@property (readonly, nonatomic) NSNumber *numberOfSteps;
@property (readonly, nonatomic, nullable) NSNumber *distance;
@property (readonly, nonatomic, nullable) NSNumber *floorsAscended;
@property (readonly, nonatomic, nullable) NSNumber *floorsDescended;
@property (readonly, nonatomic, nullable) NSNumber *currentPace;
@property (readonly, nonatomic, nullable) NSNumber *currentCadence;
@property (readonly, nonatomic, nullable) NSNumber *averageActivePace;
@end
typedef NS_ENUM(NSInteger, CMPedometerEventType) { CMPedometerEventTypePause, CMPedometerEventTypeResume };
@interface CMPedometerEvent : NSObject
@property (readonly, nonatomic) NSDate *date;
@property (readonly, nonatomic) CMPedometerEventType type;
@end
typedef void (^CMPedometerHandler)(CMPedometerData * _Nullable pedometerData, NSError * _Nullable error);
typedef void (^CMPedometerEventHandler)(CMPedometerEvent * _Nullable pedometerEvent, NSError * _Nullable error);
@interface CMPedometer : NSObject
+ (BOOL)isStepCountingAvailable;
+ (BOOL)isDistanceAvailable;
+ (BOOL)isFloorCountingAvailable;
+ (BOOL)isPaceAvailable;
+ (BOOL)isCadenceAvailable;
+ (BOOL)isPedometerEventTrackingAvailable;
+ (CMAuthorizationStatus)authorizationStatus;
- (void)queryPedometerDataFromDate:(NSDate *)start toDate:(NSDate *)end withHandler:(CMPedometerHandler)handler;
- (void)startPedometerUpdatesFromDate:(NSDate *)start withHandler:(CMPedometerHandler)handler;
- (void)stopPedometerUpdates;
- (void)startPedometerEventUpdatesWithHandler:(CMPedometerEventHandler)handler;
- (void)stopPedometerEventUpdates;
@end

typedef NS_ENUM(NSInteger, CMMotionActivityConfidence) { CMMotionActivityConfidenceLow = 0, CMMotionActivityConfidenceMedium, CMMotionActivityConfidenceHigh };
@interface CMMotionActivity : CMLogItem
@property (readonly, nonatomic) CMMotionActivityConfidence confidence;
@property (readonly, nonatomic) NSDate *startDate;
@property (readonly, nonatomic) BOOL unknown;
@property (readonly, nonatomic) BOOL stationary;
@property (readonly, nonatomic) BOOL walking;
@property (readonly, nonatomic) BOOL running;
@property (readonly, nonatomic) BOOL automotive;
@property (readonly, nonatomic) BOOL cycling;
@end
typedef void (^CMMotionActivityHandler)(CMMotionActivity * _Nullable activity);
typedef void (^CMMotionActivityQueryHandler)(NSArray<CMMotionActivity *> * _Nullable activities, NSError * _Nullable error);
@interface CMMotionActivityManager : NSObject
+ (BOOL)isActivityAvailable;
+ (CMAuthorizationStatus)authorizationStatus;
- (void)queryActivityStartingFromDate:(NSDate *)start toDate:(NSDate *)end toQueue:(NSOperationQueue *)queue withHandler:(CMMotionActivityQueryHandler)handler;
- (void)startActivityUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMMotionActivityHandler)handler;
- (void)stopActivityUpdates;
@end

@interface CMAltitudeData : CMLogItem
@property (readonly, nonatomic) NSNumber *relativeAltitude;
@property (readonly, nonatomic) NSNumber *pressure;
@end
typedef void (^CMAltitudeHandler)(CMAltitudeData * _Nullable altitudeData, NSError * _Nullable error);
@interface CMAltimeter : NSObject
+ (BOOL)isRelativeAltitudeAvailable;
+ (BOOL)isAbsoluteAltitudeAvailable;
+ (CMAuthorizationStatus)authorizationStatus;
- (void)startRelativeAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAltitudeHandler)handler;
- (void)stopRelativeAltitudeUpdates;
@end

/* absolute altitude (iOS 15): unavailable, like the Simulator; the handler gets CMErrorNotAvailable */
API_AVAILABLE(ios(15.0))
@interface CMAbsoluteAltitudeData : CMLogItem
@property (readonly, nonatomic) double altitude;
@property (readonly, nonatomic) double accuracy;
@property (readonly, nonatomic) double precision;
@end
typedef void (^CMAbsoluteAltitudeHandler)(CMAbsoluteAltitudeData * _Nullable altitudeData, NSError * _Nullable error) API_AVAILABLE(ios(15.0));
@interface CMAltimeter (AbsoluteAltitude)
- (void)startAbsoluteAltitudeUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMAbsoluteAltitudeHandler)handler API_AVAILABLE(ios(15.0));
- (void)stopAbsoluteAltitudeUpdates API_AVAILABLE(ios(15.0));
@end

/* AirPods head tracking: no headphones are connected */
@class CMHeadphoneMotionManager;
@protocol CMHeadphoneMotionManagerDelegate <NSObject>
@optional
- (void)headphoneMotionManagerDidConnect:(CMHeadphoneMotionManager *)manager;
- (void)headphoneMotionManagerDidDisconnect:(CMHeadphoneMotionManager *)manager;
@end
@interface CMHeadphoneMotionManager : NSObject
+ (CMAuthorizationStatus)authorizationStatus;
@property (readonly, nonatomic, getter=isDeviceMotionAvailable) BOOL deviceMotionAvailable;
@property (readonly, nonatomic, getter=isDeviceMotionActive) BOOL deviceMotionActive;
@property (readonly, nonatomic, nullable) CMDeviceMotion *deviceMotion;
- (void)startDeviceMotionUpdates;
- (void)startDeviceMotionUpdatesToQueue:(NSOperationQueue *)queue withHandler:(CMDeviceMotionHandler)handler;
- (void)stopDeviceMotionUpdates;
@property (weak, nonatomic, nullable) id<CMHeadphoneMotionManagerDelegate> delegate;
@property (readonly, nonatomic, getter=isConnectionStatusActive) BOOL connectionStatusActive API_AVAILABLE(ios(17.0));
- (void)startConnectionStatusUpdates API_AVAILABLE(ios(17.0));
- (void)stopConnectionStatusUpdates API_AVAILABLE(ios(17.0));
@end

/* batched sensor data (iOS 17): not supported, like the Simulator; the handlers get CMErrorNotAvailable */
API_AVAILABLE(ios(17.0))
@interface CMBatchedSensorManager : NSObject
@property (class, readonly, nonatomic) CMAuthorizationStatus authorizationStatus;
@property (class, readonly, nonatomic, getter=isAccelerometerSupported) BOOL accelerometerSupported;
@property (class, readonly, nonatomic, getter=isDeviceMotionSupported) BOOL deviceMotionSupported;
@property (readonly) NSInteger accelerometerDataFrequency;
@property (readonly) NSInteger deviceMotionDataFrequency;
@property (readonly, getter=isAccelerometerActive) BOOL accelerometerActive;
@property (readonly, getter=isDeviceMotionActive) BOOL deviceMotionActive;
@property (readonly, nullable) NSArray<CMAccelerometerData *> *accelerometerBatch;
@property (readonly, nullable) NSArray<CMDeviceMotion *> *deviceMotionBatch;
- (void)startAccelerometerUpdates;
- (void)startAccelerometerUpdatesWithHandler:(void (^)(NSArray<CMAccelerometerData *> * _Nullable batchedData, NSError * _Nullable error))handler;
- (void)stopAccelerometerUpdates;
- (void)startDeviceMotionUpdates;
- (void)startDeviceMotionUpdatesWithHandler:(void (^)(NSArray<CMDeviceMotion *> * _Nullable batchedData, NSError * _Nullable error))handler;
- (void)stopDeviceMotionUpdates;
@end

/* the sensor recorder: recording is not available, like the Simulator */
@interface CMRecordedAccelerometerData : CMAccelerometerData
@property (readonly, nonatomic) uint64_t identifier;
@property (readonly, nonatomic) NSDate *startDate;
@end
@interface CMSensorDataList : NSObject <NSFastEnumeration>
@end
@interface CMSensorRecorder : NSObject
+ (BOOL)isAccelerometerRecordingAvailable;
+ (CMAuthorizationStatus)authorizationStatus;
- (void)recordAccelerometerForDuration:(NSTimeInterval)duration;
- (nullable CMSensorDataList *)accelerometerDataFromDate:(NSDate *)fromDate toDate:(NSDate *)toDate;
@end

/* water submersion (iOS 16): no depth gauge; the delegate gets manager:errorOccurred: (CMErrorNotAvailable) */
typedef NS_ENUM(NSInteger, CMWaterSubmersionState) {
    CMWaterSubmersionStateUnknown = 0, CMWaterSubmersionStateNotSubmerged = 1, CMWaterSubmersionStateSubmerged = 2,
} API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, CMWaterSubmersionDepthState) {
    CMWaterSubmersionDepthStateUnknown = 0, CMWaterSubmersionDepthStateNotSubmerged = 100, CMWaterSubmersionDepthStateSubmergedShallow = 200,
    CMWaterSubmersionDepthStateSubmergedDeep = 300, CMWaterSubmersionDepthStateApproachingMaxDepth = 400,
    CMWaterSubmersionDepthStatePastMaxDepth = 500, CMWaterSubmersionDepthStateSensorDepthError = 600,
} API_AVAILABLE(ios(16.0));
API_AVAILABLE(ios(16.0))
@interface CMWaterSubmersionEvent : NSObject <NSSecureCoding, NSCopying>
@property (readonly, nonatomic) NSDate *date;
@property (readonly, nonatomic) CMWaterSubmersionState state;
@end
API_AVAILABLE(ios(16.0))
@interface CMWaterSubmersionMeasurement : NSObject <NSSecureCoding, NSCopying>
@property (readonly, nonatomic) NSDate *date;
@property (readonly, nonatomic, nullable) NSMeasurement<NSUnitLength *> *depth;
@property (readonly, nonatomic, nullable) NSMeasurement<NSUnitPressure *> *pressure;
@property (readonly, nonatomic) NSMeasurement<NSUnitPressure *> *surfacePressure;
@property (readonly, nonatomic) CMWaterSubmersionDepthState submersionState;
@end
API_AVAILABLE(ios(16.0))
@interface CMWaterTemperature : NSObject <NSSecureCoding, NSCopying>
@property (readonly, nonatomic) NSDate *date;
@property (readonly, nonatomic) NSMeasurement<NSUnitTemperature *> *temperature;
@property (readonly, nonatomic) NSMeasurement<NSUnitTemperature *> *temperatureUncertainty;
@end
@class CMWaterSubmersionManager;
API_AVAILABLE(ios(16.0))
@protocol CMWaterSubmersionManagerDelegate <NSObject>
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateEvent:(CMWaterSubmersionEvent *)event;
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateMeasurement:(CMWaterSubmersionMeasurement *)measurement;
- (void)manager:(CMWaterSubmersionManager *)manager didUpdateTemperature:(CMWaterTemperature *)measurement;
- (void)manager:(CMWaterSubmersionManager *)manager errorOccurred:(NSError *)error;
@end
API_AVAILABLE(ios(16.0))
@interface CMWaterSubmersionManager : NSObject
@property (nullable, weak) id<CMWaterSubmersionManagerDelegate> delegate;
@property (class, nonatomic, readonly) BOOL waterSubmersionAvailable;
@property (class, nonatomic, readonly) CMAuthorizationStatus authorizationStatus;
@property (readonly, nonatomic, nullable) NSMeasurement<NSUnitLength *> *maximumDepth;
@end
NS_ASSUME_NONNULL_END
#else
@class CMMotionManager, CMAccelerometerData, CMGyroData, CMMagnetometerData, CMDeviceMotion, CMAttitude, CMLogItem;
#endif
