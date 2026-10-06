#pragma once
#import <Foundation/NSUnit.h>
#import <Foundation/NSFormatter.h>
NS_ASSUME_NONNULL_BEGIN
@class NSLocale, NSNumberFormatter;
@interface NSMeasurement<UnitType: NSUnit *> : NSObject <NSCopying, NSSecureCoding>
@property (readonly, copy) UnitType unit;
@property (readonly) double doubleValue;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDoubleValue:(double)doubleValue unit:(UnitType)unit NS_DESIGNATED_INITIALIZER;
- (BOOL)canBeConvertedToUnit:(NSUnit *)unit;
- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit;
- (NSMeasurement<UnitType> *)measurementByAddingMeasurement:(NSMeasurement<UnitType> *)measurement;
- (NSMeasurement<UnitType> *)measurementBySubtractingMeasurement:(NSMeasurement<UnitType> *)measurement;
/* isim-private: the measurement in the unit the locale prefers (usage: "general", "person", "asProvided") */
@end
@interface NSMeasurement (IsimPreferredImpl)
- (NSMeasurement *)_isim_measurementInPreferredUnitForLocale:(nullable NSLocale *)locale usage:(NSString *)usage;
@end

typedef NS_OPTIONS(NSUInteger, NSMeasurementFormatterUnitOptions) {
    NSMeasurementFormatterUnitOptionsProvidedUnit NS_SWIFT_NAME(providedUnit) = (1UL << 0),
    NSMeasurementFormatterUnitOptionsNaturalScale NS_SWIFT_NAME(naturalScale) = (1UL << 1),
    NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit NS_SWIFT_NAME(temperatureWithoutUnit) = (1UL << 2)
} NS_SWIFT_NAME(MeasurementFormatter.UnitOptions);
@interface NSMeasurementFormatter : NSFormatter <NSSecureCoding>
@property NSMeasurementFormatterUnitOptions unitOptions;
@property NSFormattingUnitStyle unitStyle;
@property (null_resettable, copy) NSLocale *locale;
@property (null_resettable, copy) NSNumberFormatter *numberFormatter;
- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement;
- (NSString *)stringFromUnit:(NSUnit *)unit;
/* isim-private: "5 km" / "5km" / "5 kilometers" for a formatted number (width 0 narrow, 1 abbreviated, 2 wide) */
+ (NSString *)_isim_formatNumber:(NSString *)number value:(double)value unit:(NSUnit *)unit width:(NSInteger)width locale:(NSLocale *)locale;
@end
NS_ASSUME_NONNULL_END
