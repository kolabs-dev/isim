// isim Core Motion for Objective-C: the C constants, and the methods that return C structs (CMAcceleration...), which
// the Swift overlay's classes cannot declare; they read the components the overlay exposes.
#import <CoreMotion/CoreMotion.h>

NSString * const CMErrorDomain = @"CMErrorDomain";

@interface CMLogItem (ISIMVectors)
- (NSArray<NSNumber *> *)_isim_vector;
- (NSArray<NSNumber *> *)_isim_vectors;
@end
@interface CMAttitude (ISIMVectors)
- (NSArray<NSNumber *> *)_isim_quaternion;
@end
static double at(NSArray<NSNumber *> *a, NSUInteger i) { return i < a.count ? a[i].doubleValue : 0; }

@implementation CMAccelerometerData (ISIMStructs)
- (CMAcceleration)acceleration { NSArray *v = [self _isim_vector]; return (CMAcceleration){ at(v, 0), at(v, 1), at(v, 2) }; }
@end
@implementation CMGyroData (ISIMStructs)
- (CMRotationRate)rotationRate { NSArray *v = [self _isim_vector]; return (CMRotationRate){ at(v, 0), at(v, 1), at(v, 2) }; }
@end
@implementation CMMagnetometerData (ISIMStructs)
- (CMMagneticField)magneticField { NSArray *v = [self _isim_vector]; return (CMMagneticField){ at(v, 0), at(v, 1), at(v, 2) }; }
@end
@implementation CMAttitude (ISIMStructs)
- (CMQuaternion)quaternion { NSArray *q = [self _isim_quaternion]; return (CMQuaternion){ at(q, 0), at(q, 1), at(q, 2), at(q, 3) }; }
- (CMRotationMatrix)rotationMatrix {
    CMQuaternion q = self.quaternion;
    return (CMRotationMatrix){ 1 - 2 * (q.y * q.y + q.z * q.z), 2 * (q.x * q.y + q.z * q.w), 2 * (q.x * q.z - q.y * q.w),
                               2 * (q.x * q.y - q.z * q.w), 1 - 2 * (q.x * q.x + q.z * q.z), 2 * (q.y * q.z + q.x * q.w),
                               2 * (q.x * q.z + q.y * q.w), 2 * (q.y * q.z - q.x * q.w), 1 - 2 * (q.x * q.x + q.y * q.y) };
}
@end
@implementation CMDeviceMotion (ISIMStructs)
- (CMRotationRate)rotationRate { NSArray *v = [self _isim_vectors]; return (CMRotationRate){ at(v, 0), at(v, 1), at(v, 2) }; }
- (CMAcceleration)gravity { NSArray *v = [self _isim_vectors]; return (CMAcceleration){ at(v, 3), at(v, 4), at(v, 5) }; }
- (CMAcceleration)userAcceleration { NSArray *v = [self _isim_vectors]; return (CMAcceleration){ at(v, 6), at(v, 7), at(v, 8) }; }
- (CMCalibratedMagneticField)magneticField {
    NSArray *v = [self _isim_vectors];
    return (CMCalibratedMagneticField){ { at(v, 9), at(v, 10), at(v, 11) }, (CMMagneticFieldCalibrationAccuracy)at(v, 12) };
}
@end
