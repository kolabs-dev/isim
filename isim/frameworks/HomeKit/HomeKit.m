// isim HomeKit for Objective-C: the significant events and the generic classes Swift cannot export to Objective-C
// (HMCharacteristicWriteAction and HMCharacteristicEvent are Swift generics in the overlay). These keep their values
// and hand them to the overlay's HMAction and HMEvent (their _isim_ methods), which store them in the device's homes.
// The other classes and protocols are the HomeKit Swift overlay's; the constants are Types.m's.
#import <HomeKit/HomeKit.h>

HMSignificantEvent const HMSignificantEventSunrise = @"sunrise";
HMSignificantEvent const HMSignificantEventSunset = @"sunset";

// the overlay's internal methods these classes use
@interface HMAction (IsimInternal)
- (void)_isim_setIdentifier:(NSString *)identifier;
- (void)_isim_updateTargetValue:(id)value characteristic:(HMCharacteristic *)characteristic completionHandler:(HMErrorBlock)completion;
@end
@interface HMEvent (IsimInternal)
- (void)_isim_setCharacteristic:(HMCharacteristic *)characteristic triggerValue:(nullable id)triggerValue identifier:(nullable NSString *)identifier;
@end

@implementation HMCharacteristicWriteAction {
    HMCharacteristic *_characteristic;
    id _targetValue;
}
- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic targetValue:(id)targetValue {
    if ((self = [super init])) {
        _characteristic = characteristic;
        _targetValue = [targetValue copyWithZone:nil];
    }
    return self;
}
// the overlay makes the actions of an action set it read from the device's homes: [value, identifier]
+ (instancetype)_isim_actionWithCharacteristic:(HMCharacteristic *)characteristic valueAndIdentifier:(NSArray *)valueAndIdentifier {
    HMCharacteristicWriteAction *a = [[self alloc] initWithCharacteristic:characteristic targetValue:valueAndIdentifier[0]];
    [a _isim_setIdentifier:valueAndIdentifier[1]];
    return a;
}
- (HMCharacteristic *)characteristic { return _characteristic; }
- (id)targetValue { return _targetValue; }
- (void)updateTargetValue:(id)targetValue completionHandler:(HMErrorBlock)completion {
    [self _isim_updateTargetValue:targetValue characteristic:_characteristic completionHandler:^(NSError *error) {
        if (!error) self->_targetValue = [targetValue copyWithZone:nil];
        completion(error);
    }];
}
@end

@implementation HMCharacteristicEvent {
    @protected
    HMCharacteristic *_characteristic;
    id _triggerValue;
}
- (instancetype)initWithCharacteristic:(HMCharacteristic *)characteristic triggerValue:(id)triggerValue {
    if ((self = [super init])) {
        _characteristic = characteristic;
        _triggerValue = [triggerValue copyWithZone:nil];
        [self _isim_setCharacteristic:characteristic triggerValue:_triggerValue identifier:nil];
    }
    return self;
}
// the overlay makes the events of a trigger it read from the device's homes: [value or NSNull, identifier]
+ (instancetype)_isim_eventWithCharacteristic:(HMCharacteristic *)characteristic valueAndIdentifier:(NSArray *)valueAndIdentifier {
    id value = valueAndIdentifier[0] == [NSNull null] ? nil : valueAndIdentifier[0];
    HMCharacteristicEvent *e = [[self alloc] initWithCharacteristic:characteristic triggerValue:value];
    [e _isim_setCharacteristic:characteristic triggerValue:value identifier:valueAndIdentifier[1]];
    return e;
}
- (HMCharacteristic *)characteristic { return _characteristic; }
- (id)triggerValue { return _triggerValue; }
- (void)updateTriggerValue:(id)triggerValue completionHandler:(HMErrorBlock)completion {
    _triggerValue = [triggerValue copyWithZone:nil];
    [self _isim_setCharacteristic:_characteristic triggerValue:_triggerValue identifier:self.uniqueIdentifier.UUIDString];
    dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
}
- (id)copyWithZone:(NSZone *)zone {
    HMCharacteristicEvent *e = [[HMCharacteristicEvent alloc] initWithCharacteristic:_characteristic triggerValue:_triggerValue];
    [e _isim_setCharacteristic:_characteristic triggerValue:_triggerValue identifier:self.uniqueIdentifier.UUIDString];
    return e;
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    HMMutableCharacteristicEvent *e = [[HMMutableCharacteristicEvent alloc] initWithCharacteristic:_characteristic triggerValue:_triggerValue];
    [e _isim_setCharacteristic:_characteristic triggerValue:_triggerValue identifier:self.uniqueIdentifier.UUIDString];
    return e;
}
@end

@implementation HMMutableCharacteristicEvent
@dynamic characteristic, triggerValue;
- (void)setCharacteristic:(HMCharacteristic *)characteristic {
    _characteristic = characteristic;
    [self _isim_setCharacteristic:characteristic triggerValue:_triggerValue identifier:self.uniqueIdentifier.UUIDString];
}
- (void)setTriggerValue:(id)triggerValue {
    _triggerValue = [triggerValue copyWithZone:nil];
    [self _isim_setCharacteristic:_characteristic triggerValue:_triggerValue identifier:self.uniqueIdentifier.UUIDString];
}
@end
