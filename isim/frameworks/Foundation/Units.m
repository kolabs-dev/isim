/* isim Foundation (ARC): NSUnit / NSDimension and the standard unit classes (UnitLength, UnitMass, ...),
 * NSUnitConverterLinear, NSMeasurement, NSMeasurementFormatter. Conversion factors are the documented
 * ones; names use isim's built-in locale data (English long names everywhere, plus pt/es/fr/de/it for
 * common units). Formatting converts to the region's preferred units (metric or US) like iOS. */
#import <Foundation/Foundation.h>
#include <math.h>
#include "isim_foundation.h"
#include "isim_locale.h"
#include <objc/message.h>

/* ================= converters ================= */
@implementation NSUnitConverter
- (double)baseUnitValueFromValue:(double)value { return value; }
- (double)valueFromBaseUnitValue:(double)baseUnitValue { return baseUnitValue; }
@end
@implementation NSUnitConverterLinear
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoefficient:(double)c { return [self initWithCoefficient:c constant:0]; }
- (instancetype)initWithCoefficient:(double)c constant:(double)k { if ((self = [super init])) { _coefficient = c; _constant = k; } return self; }
- (double)baseUnitValueFromValue:(double)v { return v * _coefficient + _constant; }
- (double)valueFromBaseUnitValue:(double)b { return (b - _constant) / _coefficient; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSUnitConverterLinear class]] && [(NSUnitConverterLinear *)o coefficient] == _coefficient && [(NSUnitConverterLinear *)o constant] == _constant; }
- (NSUInteger)hash { return (NSUInteger)(_coefficient * 1000003) ^ (NSUInteger)_constant; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithCoefficient:1]; }
@end
/* fuel efficiency: value = k / base (miles per gallon <-> liters per 100 km) */
@interface _IsimUnitConverterReciprocal : NSUnitConverter { double _k; }
- (instancetype)initWithReciprocal:(double)k;
@end
@implementation _IsimUnitConverterReciprocal
- (instancetype)initWithReciprocal:(double)k { if ((self = [super init])) _k = k; return self; }
- (double)baseUnitValueFromValue:(double)v { return v ? _k / v : 0; }
- (double)valueFromBaseUnitValue:(double)b { return b ? _k / b : 0; }
@end

/* ================= units ================= */
@interface NSUnit () { @public NSString *_isimKey, *_isimOne, *_isimOther; }
@end
@implementation NSUnit
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithSymbol:(NSString *)symbol { if ((self = [super init])) _symbol = [symbol copy]; return self; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[NSUnit class]] && [[(NSUnit *)o symbol] isEqualToString:_symbol] && [o class] == [self class]); }
- (NSUInteger)hash { return _symbol.hash; }
- (NSString *)description { return _symbol; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithSymbol:@""]; }
@end
@implementation NSDimension
- (instancetype)initWithSymbol:(NSString *)symbol { return [self initWithSymbol:symbol converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1]]; }
- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter { if ((self = [super initWithSymbol:symbol])) _converter = converter; return self; }
+ (instancetype)baseUnit { return nil; }
- (BOOL)isEqual:(id)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSDimension class]] || [o class] != [self class]) return NO;
    NSDimension *d = o;
    return [d.symbol isEqualToString:self.symbol] && [d.converter isEqual:_converter];
}
@end

/* ---- generated unit tables (name, symbol, coefficient, constant, English names) ---- */
@implementation NSUnitAcceleration
+ (instancetype)baseUnit { return [self metersPerSecondSquared]; }
+ (NSUnitAcceleration *)metersPerSecondSquared { static NSUnitAcceleration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAcceleration alloc] initWithSymbol:@"m/s²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"metersPerSecondSquared"; u->_isimOne = @"meter per second squared"; u->_isimOther = @"meters per second squared"; }); return u; }
+ (NSUnitAcceleration *)gravity { static NSUnitAcceleration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAcceleration alloc] initWithSymbol:@"g" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:9.81 constant:0.0]]; u->_isimKey = @"gravity"; u->_isimOne = @"g-force"; u->_isimOther = @"g-force"; }); return u; }
@end
@implementation NSUnitAngle
+ (instancetype)baseUnit { return [self degrees]; }
+ (NSUnitAngle *)degrees { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"°" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"degrees"; u->_isimOne = @"degree"; u->_isimOther = @"degrees"; }); return u; }
+ (NSUnitAngle *)arcMinutes { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"ʹ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.016666666666666666 constant:0.0]]; u->_isimKey = @"arcMinutes"; u->_isimOne = @"arc minute"; u->_isimOther = @"arc minutes"; }); return u; }
+ (NSUnitAngle *)arcSeconds { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"ʺ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0002777777777777778 constant:0.0]]; u->_isimKey = @"arcSeconds"; u->_isimOne = @"arc second"; u->_isimOther = @"arc seconds"; }); return u; }
+ (NSUnitAngle *)radians { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"rad" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:57.2957795130823 constant:0.0]]; u->_isimKey = @"radians"; u->_isimOne = @"radian"; u->_isimOther = @"radians"; }); return u; }
+ (NSUnitAngle *)gradians { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"grad" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.9 constant:0.0]]; u->_isimKey = @"gradians"; u->_isimOne = @"gradian"; u->_isimOther = @"gradians"; }); return u; }
+ (NSUnitAngle *)revolutions { static NSUnitAngle *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitAngle alloc] initWithSymbol:@"rev" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:360.0 constant:0.0]]; u->_isimKey = @"revolutions"; u->_isimOne = @"revolution"; u->_isimOther = @"revolutions"; }); return u; }
@end
@implementation NSUnitArea
+ (instancetype)baseUnit { return [self squareMeters]; }
+ (NSUnitArea *)squareMegameters { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"Mm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000.0 constant:0.0]]; u->_isimKey = @"squareMegameters"; u->_isimOne = @"square megameter"; u->_isimOther = @"square megameters"; }); return u; }
+ (NSUnitArea *)squareKilometers { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"km²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"squareKilometers"; u->_isimOne = @"square kilometer"; u->_isimOther = @"square kilometers"; }); return u; }
+ (NSUnitArea *)squareMeters { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"m²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"squareMeters"; u->_isimOne = @"square meter"; u->_isimOther = @"square meters"; }); return u; }
+ (NSUnitArea *)squareCentimeters { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"cm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0001 constant:0.0]]; u->_isimKey = @"squareCentimeters"; u->_isimOne = @"square centimeter"; u->_isimOther = @"square centimeters"; }); return u; }
+ (NSUnitArea *)squareMillimeters { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"mm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"squareMillimeters"; u->_isimOne = @"square millimeter"; u->_isimOther = @"square millimeters"; }); return u; }
+ (NSUnitArea *)squareMicrometers { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"µm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0.0]]; u->_isimKey = @"squareMicrometers"; u->_isimOne = @"square micrometer"; u->_isimOther = @"square micrometers"; }); return u; }
+ (NSUnitArea *)squareNanometers { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"nm²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-18 constant:0.0]]; u->_isimKey = @"squareNanometers"; u->_isimOne = @"square nanometer"; u->_isimOther = @"square nanometers"; }); return u; }
+ (NSUnitArea *)squareInches { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"in²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00064516 constant:0.0]]; u->_isimKey = @"squareInches"; u->_isimOne = @"square inch"; u->_isimOther = @"square inches"; }); return u; }
+ (NSUnitArea *)squareFeet { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"ft²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.09290304 constant:0.0]]; u->_isimKey = @"squareFeet"; u->_isimOne = @"square foot"; u->_isimOther = @"square feet"; }); return u; }
+ (NSUnitArea *)squareYards { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"yd²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.83612736 constant:0.0]]; u->_isimKey = @"squareYards"; u->_isimOne = @"square yard"; u->_isimOther = @"square yards"; }); return u; }
+ (NSUnitArea *)squareMiles { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"mi²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:2589988.110336 constant:0.0]]; u->_isimKey = @"squareMiles"; u->_isimOne = @"square mile"; u->_isimOther = @"square miles"; }); return u; }
+ (NSUnitArea *)acres { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"ac" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4046.8564224 constant:0.0]]; u->_isimKey = @"acres"; u->_isimOne = @"acre"; u->_isimOther = @"acres"; }); return u; }
+ (NSUnitArea *)ares { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"a" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100.0 constant:0.0]]; u->_isimKey = @"ares"; u->_isimOne = @"are"; u->_isimOther = @"ares"; }); return u; }
+ (NSUnitArea *)hectares { static NSUnitArea *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitArea alloc] initWithSymbol:@"ha" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10000.0 constant:0.0]]; u->_isimKey = @"hectares"; u->_isimOne = @"hectare"; u->_isimOther = @"hectares"; }); return u; }
@end
@implementation NSUnitDuration
+ (instancetype)baseUnit { return [self seconds]; }
+ (NSUnitDuration *)hours { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"hr" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600.0 constant:0.0]]; u->_isimKey = @"hours"; u->_isimOne = @"hour"; u->_isimOther = @"hours"; }); return u; }
+ (NSUnitDuration *)minutes { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"min" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:60.0 constant:0.0]]; u->_isimKey = @"minutes"; u->_isimOne = @"minute"; u->_isimOther = @"minutes"; }); return u; }
+ (NSUnitDuration *)seconds { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"s" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"seconds"; u->_isimOne = @"second"; u->_isimOther = @"seconds"; }); return u; }
+ (NSUnitDuration *)milliseconds { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"ms" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"milliseconds"; u->_isimOne = @"millisecond"; u->_isimOther = @"milliseconds"; }); return u; }
+ (NSUnitDuration *)microseconds { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"µs" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microseconds"; u->_isimOne = @"microsecond"; u->_isimOther = @"microseconds"; }); return u; }
+ (NSUnitDuration *)nanoseconds { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"ns" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09 constant:0.0]]; u->_isimKey = @"nanoseconds"; u->_isimOne = @"nanosecond"; u->_isimOther = @"nanoseconds"; }); return u; }
+ (NSUnitDuration *)picoseconds { static NSUnitDuration *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitDuration alloc] initWithSymbol:@"ps" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0.0]]; u->_isimKey = @"picoseconds"; u->_isimOne = @"picosecond"; u->_isimOther = @"picoseconds"; }); return u; }
@end
@implementation NSUnitElectricCharge
+ (instancetype)baseUnit { return [self coulombs]; }
+ (NSUnitElectricCharge *)coulombs { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"C" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"coulombs"; u->_isimOne = @"coulomb"; u->_isimOther = @"coulombs"; }); return u; }
+ (NSUnitElectricCharge *)megaampereHours { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"MAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000000.0 constant:0.0]]; u->_isimKey = @"megaampereHours"; u->_isimOne = @"megaampere-hour"; u->_isimOther = @"megaampere-hours"; }); return u; }
+ (NSUnitElectricCharge *)kiloampereHours { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"kAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000.0 constant:0.0]]; u->_isimKey = @"kiloampereHours"; u->_isimOne = @"kiloampere-hour"; u->_isimOther = @"kiloampere-hours"; }); return u; }
+ (NSUnitElectricCharge *)ampereHours { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"Ah" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600.0 constant:0.0]]; u->_isimKey = @"ampereHours"; u->_isimOne = @"ampere-hour"; u->_isimOther = @"ampere-hours"; }); return u; }
+ (NSUnitElectricCharge *)milliampereHours { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"mAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.6 constant:0.0]]; u->_isimKey = @"milliampereHours"; u->_isimOne = @"milliampere-hour"; u->_isimOther = @"milliampere-hours"; }); return u; }
+ (NSUnitElectricCharge *)microampereHours { static NSUnitElectricCharge *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCharge alloc] initWithSymbol:@"µAh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0036 constant:0.0]]; u->_isimKey = @"microampereHours"; u->_isimOne = @"microampere-hour"; u->_isimOther = @"microampere-hours"; }); return u; }
@end
@implementation NSUnitElectricCurrent
+ (instancetype)baseUnit { return [self amperes]; }
+ (NSUnitElectricCurrent *)megaamperes { static NSUnitElectricCurrent *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCurrent alloc] initWithSymbol:@"MA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megaamperes"; u->_isimOne = @"megaampere"; u->_isimOther = @"megaamperes"; }); return u; }
+ (NSUnitElectricCurrent *)kiloamperes { static NSUnitElectricCurrent *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCurrent alloc] initWithSymbol:@"kA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kiloamperes"; u->_isimOne = @"kiloampere"; u->_isimOther = @"kiloamperes"; }); return u; }
+ (NSUnitElectricCurrent *)amperes { static NSUnitElectricCurrent *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCurrent alloc] initWithSymbol:@"A" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"amperes"; u->_isimOne = @"ampere"; u->_isimOther = @"amperes"; }); return u; }
+ (NSUnitElectricCurrent *)milliamperes { static NSUnitElectricCurrent *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCurrent alloc] initWithSymbol:@"mA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"milliamperes"; u->_isimOne = @"milliampere"; u->_isimOther = @"milliamperes"; }); return u; }
+ (NSUnitElectricCurrent *)microamperes { static NSUnitElectricCurrent *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricCurrent alloc] initWithSymbol:@"µA" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microamperes"; u->_isimOne = @"microampere"; u->_isimOther = @"microamperes"; }); return u; }
@end
@implementation NSUnitElectricPotentialDifference
+ (instancetype)baseUnit { return [self volts]; }
+ (NSUnitElectricPotentialDifference *)megavolts { static NSUnitElectricPotentialDifference *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"MV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megavolts"; u->_isimOne = @"megavolt"; u->_isimOther = @"megavolts"; }); return u; }
+ (NSUnitElectricPotentialDifference *)kilovolts { static NSUnitElectricPotentialDifference *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"kV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilovolts"; u->_isimOne = @"kilovolt"; u->_isimOther = @"kilovolts"; }); return u; }
+ (NSUnitElectricPotentialDifference *)volts { static NSUnitElectricPotentialDifference *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"V" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"volts"; u->_isimOne = @"volt"; u->_isimOther = @"volts"; }); return u; }
+ (NSUnitElectricPotentialDifference *)millivolts { static NSUnitElectricPotentialDifference *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"mV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"millivolts"; u->_isimOne = @"millivolt"; u->_isimOther = @"millivolts"; }); return u; }
+ (NSUnitElectricPotentialDifference *)microvolts { static NSUnitElectricPotentialDifference *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricPotentialDifference alloc] initWithSymbol:@"µV" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microvolts"; u->_isimOne = @"microvolt"; u->_isimOther = @"microvolts"; }); return u; }
@end
@implementation NSUnitElectricResistance
+ (instancetype)baseUnit { return [self ohms]; }
+ (NSUnitElectricResistance *)megaohms { static NSUnitElectricResistance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricResistance alloc] initWithSymbol:@"MΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megaohms"; u->_isimOne = @"megaohm"; u->_isimOther = @"megaohms"; }); return u; }
+ (NSUnitElectricResistance *)kiloohms { static NSUnitElectricResistance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricResistance alloc] initWithSymbol:@"kΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kiloohms"; u->_isimOne = @"kiloohm"; u->_isimOther = @"kiloohms"; }); return u; }
+ (NSUnitElectricResistance *)ohms { static NSUnitElectricResistance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricResistance alloc] initWithSymbol:@"Ω" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"ohms"; u->_isimOne = @"ohm"; u->_isimOther = @"ohms"; }); return u; }
+ (NSUnitElectricResistance *)milliohms { static NSUnitElectricResistance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricResistance alloc] initWithSymbol:@"mΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"milliohms"; u->_isimOne = @"milliohm"; u->_isimOther = @"milliohms"; }); return u; }
+ (NSUnitElectricResistance *)microohms { static NSUnitElectricResistance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitElectricResistance alloc] initWithSymbol:@"µΩ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microohms"; u->_isimOne = @"microohm"; u->_isimOther = @"microohms"; }); return u; }
@end
@implementation NSUnitEnergy
+ (instancetype)baseUnit { return [self joules]; }
+ (NSUnitEnergy *)kilojoules { static NSUnitEnergy *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitEnergy alloc] initWithSymbol:@"kJ" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilojoules"; u->_isimOne = @"kilojoule"; u->_isimOther = @"kilojoules"; }); return u; }
+ (NSUnitEnergy *)joules { static NSUnitEnergy *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitEnergy alloc] initWithSymbol:@"J" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"joules"; u->_isimOne = @"joule"; u->_isimOther = @"joules"; }); return u; }
+ (NSUnitEnergy *)kilocalories { static NSUnitEnergy *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitEnergy alloc] initWithSymbol:@"kCal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4184.0 constant:0.0]]; u->_isimKey = @"kilocalories"; u->_isimOne = @"kilocalorie"; u->_isimOther = @"kilocalories"; }); return u; }
+ (NSUnitEnergy *)calories { static NSUnitEnergy *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitEnergy alloc] initWithSymbol:@"cal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4.184 constant:0.0]]; u->_isimKey = @"calories"; u->_isimOne = @"calorie"; u->_isimOther = @"calories"; }); return u; }
+ (NSUnitEnergy *)kilowattHours { static NSUnitEnergy *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitEnergy alloc] initWithSymbol:@"kWh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3600000.0 constant:0.0]]; u->_isimKey = @"kilowattHours"; u->_isimOne = @"kilowatt-hour"; u->_isimOther = @"kilowatt-hours"; }); return u; }
@end
@implementation NSUnitFrequency
+ (instancetype)baseUnit { return [self hertz]; }
+ (NSUnitFrequency *)terahertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"THz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000.0 constant:0.0]]; u->_isimKey = @"terahertz"; u->_isimOne = @"terahertz"; u->_isimOther = @"terahertz"; }); return u; }
+ (NSUnitFrequency *)gigahertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"GHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000.0 constant:0.0]]; u->_isimKey = @"gigahertz"; u->_isimOne = @"gigahertz"; u->_isimOther = @"gigahertz"; }); return u; }
+ (NSUnitFrequency *)megahertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"MHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megahertz"; u->_isimOne = @"megahertz"; u->_isimOther = @"megahertz"; }); return u; }
+ (NSUnitFrequency *)kilohertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"kHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilohertz"; u->_isimOne = @"kilohertz"; u->_isimOther = @"kilohertz"; }); return u; }
+ (NSUnitFrequency *)hertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"Hz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"hertz"; u->_isimOne = @"hertz"; u->_isimOther = @"hertz"; }); return u; }
+ (NSUnitFrequency *)millihertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"mHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"millihertz"; u->_isimOne = @"millihertz"; u->_isimOther = @"millihertz"; }); return u; }
+ (NSUnitFrequency *)microhertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"µHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microhertz"; u->_isimOne = @"microhertz"; u->_isimOther = @"microhertz"; }); return u; }
+ (NSUnitFrequency *)nanohertz { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"nHz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09 constant:0.0]]; u->_isimKey = @"nanohertz"; u->_isimOne = @"nanohertz"; u->_isimOther = @"nanohertz"; }); return u; }
+ (NSUnitFrequency *)framesPerSecond { static NSUnitFrequency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFrequency alloc] initWithSymbol:@"FPS" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"framesPerSecond"; u->_isimOne = @"frame per second"; u->_isimOther = @"frames per second"; }); return u; }
@end
@implementation NSUnitFuelEfficiency
+ (instancetype)baseUnit { return [self litersPer100Kilometers]; }
+ (NSUnitFuelEfficiency *)litersPer100Kilometers { static NSUnitFuelEfficiency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFuelEfficiency alloc] initWithSymbol:@"L/100km" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"litersPer100Kilometers"; u->_isimOne = @"liter per 100 kilometers"; u->_isimOther = @"liters per 100 kilometers"; }); return u; }
+ (NSUnitFuelEfficiency *)milesPerImperialGallon { static NSUnitFuelEfficiency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFuelEfficiency alloc] initWithSymbol:@"mpg Imp." converter:[[_IsimUnitConverterReciprocal alloc] initWithReciprocal:282.481]]; u->_isimKey = @"milesPerImperialGallon"; u->_isimOne = @"mile per imperial gallon"; u->_isimOther = @"miles per imperial gallon"; }); return u; }
+ (NSUnitFuelEfficiency *)milesPerGallon { static NSUnitFuelEfficiency *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitFuelEfficiency alloc] initWithSymbol:@"mpg" converter:[[_IsimUnitConverterReciprocal alloc] initWithReciprocal:235.215]]; u->_isimKey = @"milesPerGallon"; u->_isimOne = @"mile per gallon"; u->_isimOther = @"miles per gallon"; }); return u; }
@end
@implementation NSUnitIlluminance
+ (instancetype)baseUnit { return [self lux]; }
+ (NSUnitIlluminance *)lux { static NSUnitIlluminance *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitIlluminance alloc] initWithSymbol:@"lx" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"lux"; u->_isimOne = @"lux"; u->_isimOther = @"lux"; }); return u; }
@end
@implementation NSUnitInformationStorage
+ (instancetype)baseUnit { return [self bytes]; }
+ (NSUnitInformationStorage *)bytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"B" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"bytes"; u->_isimOne = @"byte"; u->_isimOther = @"bytes"; }); return u; }
+ (NSUnitInformationStorage *)bits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"bit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.125 constant:0.0]]; u->_isimKey = @"bits"; u->_isimOne = @"bit"; u->_isimOther = @"bits"; }); return u; }
+ (NSUnitInformationStorage *)nibbles { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"nibble" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.5 constant:0.0]]; u->_isimKey = @"nibbles"; u->_isimOne = @"nibble"; u->_isimOther = @"nibbles"; }); return u; }
+ (NSUnitInformationStorage *)yottabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"YB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e+24 constant:0.0]]; u->_isimKey = @"yottabytes"; u->_isimOne = @"yottabyte"; u->_isimOther = @"yottabytes"; }); return u; }
+ (NSUnitInformationStorage *)zettabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"ZB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e+21 constant:0.0]]; u->_isimKey = @"zettabytes"; u->_isimOne = @"zettabyte"; u->_isimOther = @"zettabytes"; }); return u; }
+ (NSUnitInformationStorage *)exabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"EB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e+18 constant:0.0]]; u->_isimKey = @"exabytes"; u->_isimOne = @"exabyte"; u->_isimOther = @"exabytes"; }); return u; }
+ (NSUnitInformationStorage *)petabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"PB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000000.0 constant:0.0]]; u->_isimKey = @"petabytes"; u->_isimOne = @"petabyte"; u->_isimOther = @"petabytes"; }); return u; }
+ (NSUnitInformationStorage *)terabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"TB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000.0 constant:0.0]]; u->_isimKey = @"terabytes"; u->_isimOne = @"terabyte"; u->_isimOther = @"terabytes"; }); return u; }
+ (NSUnitInformationStorage *)gigabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"GB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000.0 constant:0.0]]; u->_isimKey = @"gigabytes"; u->_isimOne = @"gigabyte"; u->_isimOther = @"gigabytes"; }); return u; }
+ (NSUnitInformationStorage *)megabytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"MB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megabytes"; u->_isimOne = @"megabyte"; u->_isimOther = @"megabytes"; }); return u; }
+ (NSUnitInformationStorage *)kilobytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"kB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilobytes"; u->_isimOne = @"kilobyte"; u->_isimOther = @"kilobytes"; }); return u; }
+ (NSUnitInformationStorage *)yottabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Yb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.25e+23 constant:0.0]]; u->_isimKey = @"yottabits"; u->_isimOne = @"yottabit"; u->_isimOther = @"yottabits"; }); return u; }
+ (NSUnitInformationStorage *)zettabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Zb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.25e+20 constant:0.0]]; u->_isimKey = @"zettabits"; u->_isimOne = @"zettabit"; u->_isimOther = @"zettabits"; }); return u; }
+ (NSUnitInformationStorage *)exabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Eb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.25e+17 constant:0.0]]; u->_isimKey = @"exabits"; u->_isimOne = @"exabit"; u->_isimOther = @"exabits"; }); return u; }
+ (NSUnitInformationStorage *)petabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Pb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:125000000000000.0 constant:0.0]]; u->_isimKey = @"petabits"; u->_isimOne = @"petabit"; u->_isimOther = @"petabits"; }); return u; }
+ (NSUnitInformationStorage *)terabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Tb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:125000000000.0 constant:0.0]]; u->_isimKey = @"terabits"; u->_isimOne = @"terabit"; u->_isimOther = @"terabits"; }); return u; }
+ (NSUnitInformationStorage *)gigabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Gb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:125000000.0 constant:0.0]]; u->_isimKey = @"gigabits"; u->_isimOne = @"gigabit"; u->_isimOther = @"gigabits"; }); return u; }
+ (NSUnitInformationStorage *)megabits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Mb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:125000.0 constant:0.0]]; u->_isimKey = @"megabits"; u->_isimOne = @"megabit"; u->_isimOther = @"megabits"; }); return u; }
+ (NSUnitInformationStorage *)kilobits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"kb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:125.0 constant:0.0]]; u->_isimKey = @"kilobits"; u->_isimOne = @"kilobit"; u->_isimOther = @"kilobits"; }); return u; }
+ (NSUnitInformationStorage *)yobibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"YiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.2089258196146292e+24 constant:0.0]]; u->_isimKey = @"yobibytes"; u->_isimOne = @"yobibyte"; u->_isimOther = @"yobibytes"; }); return u; }
+ (NSUnitInformationStorage *)zebibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"ZiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.1805916207174113e+21 constant:0.0]]; u->_isimKey = @"zebibytes"; u->_isimOne = @"zebibyte"; u->_isimOther = @"zebibytes"; }); return u; }
+ (NSUnitInformationStorage *)exbibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"EiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.152921504606847e+18 constant:0.0]]; u->_isimKey = @"exbibytes"; u->_isimOne = @"exbibyte"; u->_isimOther = @"exbibytes"; }); return u; }
+ (NSUnitInformationStorage *)pebibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"PiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1125899906842624.0 constant:0.0]]; u->_isimKey = @"pebibytes"; u->_isimOne = @"pebibyte"; u->_isimOther = @"pebibytes"; }); return u; }
+ (NSUnitInformationStorage *)tebibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"TiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1099511627776.0 constant:0.0]]; u->_isimKey = @"tebibytes"; u->_isimOne = @"tebibyte"; u->_isimOther = @"tebibytes"; }); return u; }
+ (NSUnitInformationStorage *)gibibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"GiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1073741824.0 constant:0.0]]; u->_isimKey = @"gibibytes"; u->_isimOne = @"gibibyte"; u->_isimOther = @"gibibytes"; }); return u; }
+ (NSUnitInformationStorage *)mebibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"MiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1048576.0 constant:0.0]]; u->_isimKey = @"mebibytes"; u->_isimOne = @"mebibyte"; u->_isimOther = @"mebibytes"; }); return u; }
+ (NSUnitInformationStorage *)kibibytes { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"KiB" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1024.0 constant:0.0]]; u->_isimKey = @"kibibytes"; u->_isimOne = @"kibibyte"; u->_isimOther = @"kibibytes"; }); return u; }
+ (NSUnitInformationStorage *)yobibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Yibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.5111572745182865e+23 constant:0.0]]; u->_isimKey = @"yobibits"; u->_isimOne = @"yobibit"; u->_isimOther = @"yobibits"; }); return u; }
+ (NSUnitInformationStorage *)zebibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Zibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.4757395258967641e+20 constant:0.0]]; u->_isimKey = @"zebibits"; u->_isimOne = @"zebibit"; u->_isimOther = @"zebibits"; }); return u; }
+ (NSUnitInformationStorage *)exbibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Eibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.4411518807585587e+17 constant:0.0]]; u->_isimKey = @"exbibits"; u->_isimOne = @"exbibit"; u->_isimOther = @"exbibits"; }); return u; }
+ (NSUnitInformationStorage *)pebibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Pibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:140737488355328.0 constant:0.0]]; u->_isimKey = @"pebibits"; u->_isimOne = @"pebibit"; u->_isimOther = @"pebibits"; }); return u; }
+ (NSUnitInformationStorage *)tebibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Tibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:137438953472.0 constant:0.0]]; u->_isimKey = @"tebibits"; u->_isimOne = @"tebibit"; u->_isimOther = @"tebibits"; }); return u; }
+ (NSUnitInformationStorage *)gibibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Gibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:134217728.0 constant:0.0]]; u->_isimKey = @"gibibits"; u->_isimOne = @"gibibit"; u->_isimOther = @"gibibits"; }); return u; }
+ (NSUnitInformationStorage *)mebibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Mibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:131072.0 constant:0.0]]; u->_isimKey = @"mebibits"; u->_isimOne = @"mebibit"; u->_isimOther = @"mebibits"; }); return u; }
+ (NSUnitInformationStorage *)kibibits { static NSUnitInformationStorage *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitInformationStorage alloc] initWithSymbol:@"Kibit" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:128.0 constant:0.0]]; u->_isimKey = @"kibibits"; u->_isimOne = @"kibibit"; u->_isimOther = @"kibibits"; }); return u; }
@end
@implementation NSUnitLength
+ (instancetype)baseUnit { return [self meters]; }
+ (NSUnitLength *)megameters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"Mm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megameters"; u->_isimOne = @"megameter"; u->_isimOther = @"megameters"; }); return u; }
+ (NSUnitLength *)kilometers { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"km" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilometers"; u->_isimOne = @"kilometer"; u->_isimOther = @"kilometers"; }); return u; }
+ (NSUnitLength *)hectometers { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"hm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100.0 constant:0.0]]; u->_isimKey = @"hectometers"; u->_isimOne = @"hectometer"; u->_isimOther = @"hectometers"; }); return u; }
+ (NSUnitLength *)decameters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"dam" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10.0 constant:0.0]]; u->_isimKey = @"decameters"; u->_isimOne = @"decameter"; u->_isimOther = @"decameters"; }); return u; }
+ (NSUnitLength *)meters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"m" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"meters"; u->_isimOne = @"meter"; u->_isimOther = @"meters"; }); return u; }
+ (NSUnitLength *)decimeters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"dm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.1 constant:0.0]]; u->_isimKey = @"decimeters"; u->_isimOne = @"decimeter"; u->_isimOther = @"decimeters"; }); return u; }
+ (NSUnitLength *)centimeters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"cm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.01 constant:0.0]]; u->_isimKey = @"centimeters"; u->_isimOne = @"centimeter"; u->_isimOther = @"centimeters"; }); return u; }
+ (NSUnitLength *)millimeters { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"mm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"millimeters"; u->_isimOne = @"millimeter"; u->_isimOther = @"millimeters"; }); return u; }
+ (NSUnitLength *)micrometers { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"µm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"micrometers"; u->_isimOne = @"micrometer"; u->_isimOther = @"micrometers"; }); return u; }
+ (NSUnitLength *)nanometers { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"nm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09 constant:0.0]]; u->_isimKey = @"nanometers"; u->_isimOne = @"nanometer"; u->_isimOther = @"nanometers"; }); return u; }
+ (NSUnitLength *)picometers { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"pm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0.0]]; u->_isimKey = @"picometers"; u->_isimOne = @"picometer"; u->_isimOther = @"picometers"; }); return u; }
+ (NSUnitLength *)inches { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"in" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0254 constant:0.0]]; u->_isimKey = @"inches"; u->_isimOne = @"inch"; u->_isimOther = @"inches"; }); return u; }
+ (NSUnitLength *)feet { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"ft" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.3048 constant:0.0]]; u->_isimKey = @"feet"; u->_isimOne = @"foot"; u->_isimOther = @"feet"; }); return u; }
+ (NSUnitLength *)yards { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"yd" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.9144 constant:0.0]]; u->_isimKey = @"yards"; u->_isimOne = @"yard"; u->_isimOther = @"yards"; }); return u; }
+ (NSUnitLength *)miles { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"mi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1609.344 constant:0.0]]; u->_isimKey = @"miles"; u->_isimOne = @"mile"; u->_isimOther = @"miles"; }); return u; }
+ (NSUnitLength *)scandinavianMiles { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"smi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:10000.0 constant:0.0]]; u->_isimKey = @"scandinavianMiles"; u->_isimOne = @"scandinavian mile"; u->_isimOther = @"scandinavian miles"; }); return u; }
+ (NSUnitLength *)lightyears { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"ly" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:9460730472580800.0 constant:0.0]]; u->_isimKey = @"lightyears"; u->_isimOne = @"light year"; u->_isimOther = @"light years"; }); return u; }
+ (NSUnitLength *)nauticalMiles { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"NM" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1852.0 constant:0.0]]; u->_isimKey = @"nauticalMiles"; u->_isimOne = @"nautical mile"; u->_isimOther = @"nautical miles"; }); return u; }
+ (NSUnitLength *)fathoms { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"ftm" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.8288 constant:0.0]]; u->_isimKey = @"fathoms"; u->_isimOne = @"fathom"; u->_isimOther = @"fathoms"; }); return u; }
+ (NSUnitLength *)furlongs { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"fur" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:201.168 constant:0.0]]; u->_isimKey = @"furlongs"; u->_isimOne = @"furlong"; u->_isimOther = @"furlongs"; }); return u; }
+ (NSUnitLength *)astronomicalUnits { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"ua" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:149597870700.0 constant:0.0]]; u->_isimKey = @"astronomicalUnits"; u->_isimOne = @"astronomical unit"; u->_isimOther = @"astronomical units"; }); return u; }
+ (NSUnitLength *)parsecs { static NSUnitLength *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitLength alloc] initWithSymbol:@"pc" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.085677581491367e+16 constant:0.0]]; u->_isimKey = @"parsecs"; u->_isimOne = @"parsec"; u->_isimOther = @"parsecs"; }); return u; }
@end
@implementation NSUnitMass
+ (instancetype)baseUnit { return [self kilograms]; }
+ (NSUnitMass *)kilograms { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"kg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"kilograms"; u->_isimOne = @"kilogram"; u->_isimOther = @"kilograms"; }); return u; }
+ (NSUnitMass *)grams { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"g" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"grams"; u->_isimOne = @"gram"; u->_isimOther = @"grams"; }); return u; }
+ (NSUnitMass *)decigrams { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"dg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0001 constant:0.0]]; u->_isimKey = @"decigrams"; u->_isimOne = @"decigram"; u->_isimOther = @"decigrams"; }); return u; }
+ (NSUnitMass *)centigrams { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"cg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-05 constant:0.0]]; u->_isimKey = @"centigrams"; u->_isimOne = @"centigram"; u->_isimOther = @"centigrams"; }); return u; }
+ (NSUnitMass *)milligrams { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"mg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"milligrams"; u->_isimOne = @"milligram"; u->_isimOther = @"milligrams"; }); return u; }
+ (NSUnitMass *)micrograms { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"µg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09 constant:0.0]]; u->_isimKey = @"micrograms"; u->_isimOne = @"microgram"; u->_isimOther = @"micrograms"; }); return u; }
+ (NSUnitMass *)nanograms { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"ng" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0.0]]; u->_isimKey = @"nanograms"; u->_isimOne = @"nanogram"; u->_isimOther = @"nanograms"; }); return u; }
+ (NSUnitMass *)picograms { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"pg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-15 constant:0.0]]; u->_isimKey = @"picograms"; u->_isimOne = @"picogram"; u->_isimOther = @"picograms"; }); return u; }
+ (NSUnitMass *)ounces { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"oz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.028349523125 constant:0.0]]; u->_isimKey = @"ounces"; u->_isimOne = @"ounce"; u->_isimOther = @"ounces"; }); return u; }
+ (NSUnitMass *)pounds { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"lb" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.45359237 constant:0.0]]; u->_isimKey = @"pounds"; u->_isimOne = @"pound"; u->_isimOther = @"pounds"; }); return u; }
+ (NSUnitMass *)stones { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"st" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:6.35029318 constant:0.0]]; u->_isimKey = @"stones"; u->_isimOne = @"stone"; u->_isimOther = @"stones"; }); return u; }
+ (NSUnitMass *)metricTons { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"t" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"metricTons"; u->_isimOne = @"metric ton"; u->_isimOther = @"metric tons"; }); return u; }
+ (NSUnitMass *)shortTons { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"ton" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:907.18474 constant:0.0]]; u->_isimKey = @"shortTons"; u->_isimOne = @"short ton"; u->_isimOther = @"short tons"; }); return u; }
+ (NSUnitMass *)carats { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"ct" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0002 constant:0.0]]; u->_isimKey = @"carats"; u->_isimOne = @"carat"; u->_isimOther = @"carats"; }); return u; }
+ (NSUnitMass *)ouncesTroy { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"oz t" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0311034768 constant:0.0]]; u->_isimKey = @"ouncesTroy"; u->_isimOne = @"troy ounce"; u->_isimOther = @"troy ounces"; }); return u; }
+ (NSUnitMass *)slugs { static NSUnitMass *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitMass alloc] initWithSymbol:@"slug" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:14.5939 constant:0.0]]; u->_isimKey = @"slugs"; u->_isimOne = @"slug"; u->_isimOther = @"slugs"; }); return u; }
@end
@implementation NSUnitPower
+ (instancetype)baseUnit { return [self watts]; }
+ (NSUnitPower *)terawatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"TW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000.0 constant:0.0]]; u->_isimKey = @"terawatts"; u->_isimOne = @"terawatt"; u->_isimOther = @"terawatts"; }); return u; }
+ (NSUnitPower *)gigawatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"GW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000.0 constant:0.0]]; u->_isimKey = @"gigawatts"; u->_isimOne = @"gigawatt"; u->_isimOther = @"gigawatts"; }); return u; }
+ (NSUnitPower *)megawatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"MW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megawatts"; u->_isimOne = @"megawatt"; u->_isimOther = @"megawatts"; }); return u; }
+ (NSUnitPower *)kilowatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"kW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilowatts"; u->_isimOne = @"kilowatt"; u->_isimOther = @"kilowatts"; }); return u; }
+ (NSUnitPower *)watts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"W" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"watts"; u->_isimOne = @"watt"; u->_isimOther = @"watts"; }); return u; }
+ (NSUnitPower *)milliwatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"mW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"milliwatts"; u->_isimOne = @"milliwatt"; u->_isimOther = @"milliwatts"; }); return u; }
+ (NSUnitPower *)microwatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"µW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"microwatts"; u->_isimOne = @"microwatt"; u->_isimOther = @"microwatts"; }); return u; }
+ (NSUnitPower *)nanowatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"nW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-09 constant:0.0]]; u->_isimKey = @"nanowatts"; u->_isimOne = @"nanowatt"; u->_isimOther = @"nanowatts"; }); return u; }
+ (NSUnitPower *)picowatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"pW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-12 constant:0.0]]; u->_isimKey = @"picowatts"; u->_isimOne = @"picowatt"; u->_isimOther = @"picowatts"; }); return u; }
+ (NSUnitPower *)femtowatts { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"fW" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-15 constant:0.0]]; u->_isimKey = @"femtowatts"; u->_isimOne = @"femtowatt"; u->_isimOther = @"femtowatts"; }); return u; }
+ (NSUnitPower *)horsepower { static NSUnitPower *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPower alloc] initWithSymbol:@"hp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:745.7 constant:0.0]]; u->_isimKey = @"horsepower"; u->_isimOne = @"horsepower"; u->_isimOther = @"horsepower"; }); return u; }
@end
@implementation NSUnitPressure
+ (instancetype)baseUnit { return [self newtonsPerMetersSquared]; }
+ (NSUnitPressure *)newtonsPerMetersSquared { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"N/m²" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"newtonsPerMetersSquared"; u->_isimOne = @"newton per square meter"; u->_isimOther = @"newtons per square meter"; }); return u; }
+ (NSUnitPressure *)gigapascals { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"GPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000.0 constant:0.0]]; u->_isimKey = @"gigapascals"; u->_isimOne = @"gigapascal"; u->_isimOther = @"gigapascals"; }); return u; }
+ (NSUnitPressure *)megapascals { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"MPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megapascals"; u->_isimOne = @"megapascal"; u->_isimOther = @"megapascals"; }); return u; }
+ (NSUnitPressure *)kilopascals { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"kPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kilopascals"; u->_isimOne = @"kilopascal"; u->_isimOther = @"kilopascals"; }); return u; }
+ (NSUnitPressure *)hectopascals { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"hPa" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100.0 constant:0.0]]; u->_isimKey = @"hectopascals"; u->_isimOne = @"hectopascal"; u->_isimOther = @"hectopascals"; }); return u; }
+ (NSUnitPressure *)inchesOfMercury { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"inHg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3386.39 constant:0.0]]; u->_isimKey = @"inchesOfMercury"; u->_isimOne = @"inch of mercury"; u->_isimOther = @"inches of mercury"; }); return u; }
+ (NSUnitPressure *)bars { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"bar" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100000.0 constant:0.0]]; u->_isimKey = @"bars"; u->_isimOne = @"bar"; u->_isimOther = @"bars"; }); return u; }
+ (NSUnitPressure *)millibars { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"mbar" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:100.0 constant:0.0]]; u->_isimKey = @"millibars"; u->_isimOne = @"millibar"; u->_isimOther = @"millibars"; }); return u; }
+ (NSUnitPressure *)millimetersOfMercury { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"mmHg" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:133.322387415 constant:0.0]]; u->_isimKey = @"millimetersOfMercury"; u->_isimOne = @"millimeter of mercury"; u->_isimOther = @"millimeters of mercury"; }); return u; }
+ (NSUnitPressure *)poundsForcePerSquareInch { static NSUnitPressure *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitPressure alloc] initWithSymbol:@"psi" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:6894.76 constant:0.0]]; u->_isimKey = @"poundsForcePerSquareInch"; u->_isimOne = @"pound-force per square inch"; u->_isimOther = @"pounds-force per square inch"; }); return u; }
@end
@implementation NSUnitSpeed
+ (instancetype)baseUnit { return [self metersPerSecond]; }
+ (NSUnitSpeed *)metersPerSecond { static NSUnitSpeed *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitSpeed alloc] initWithSymbol:@"m/s" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"metersPerSecond"; u->_isimOne = @"meter per second"; u->_isimOther = @"meters per second"; }); return u; }
+ (NSUnitSpeed *)kilometersPerHour { static NSUnitSpeed *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitSpeed alloc] initWithSymbol:@"km/h" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.277777777777778 constant:0.0]]; u->_isimKey = @"kilometersPerHour"; u->_isimOne = @"kilometer per hour"; u->_isimOther = @"kilometers per hour"; }); return u; }
+ (NSUnitSpeed *)milesPerHour { static NSUnitSpeed *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitSpeed alloc] initWithSymbol:@"mph" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.44704 constant:0.0]]; u->_isimKey = @"milesPerHour"; u->_isimOne = @"mile per hour"; u->_isimOther = @"miles per hour"; }); return u; }
+ (NSUnitSpeed *)knots { static NSUnitSpeed *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitSpeed alloc] initWithSymbol:@"kn" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.514444444444444 constant:0.0]]; u->_isimKey = @"knots"; u->_isimOne = @"knot"; u->_isimOther = @"knots"; }); return u; }
@end
@implementation NSUnitTemperature
+ (instancetype)baseUnit { return [self kelvin]; }
+ (NSUnitTemperature *)kelvin { static NSUnitTemperature *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitTemperature alloc] initWithSymbol:@"K" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"kelvin"; u->_isimOne = @"kelvin"; u->_isimOther = @"kelvins"; }); return u; }
+ (NSUnitTemperature *)celsius { static NSUnitTemperature *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitTemperature alloc] initWithSymbol:@"°C" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:273.15]]; u->_isimKey = @"celsius"; u->_isimOne = @"degree Celsius"; u->_isimOther = @"degrees Celsius"; }); return u; }
+ (NSUnitTemperature *)fahrenheit { static NSUnitTemperature *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitTemperature alloc] initWithSymbol:@"°F" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.5555555555555556 constant:255.3722222222222]]; u->_isimKey = @"fahrenheit"; u->_isimOne = @"degree Fahrenheit"; u->_isimOther = @"degrees Fahrenheit"; }); return u; }
@end
@implementation NSUnitVolume
+ (instancetype)baseUnit { return [self liters]; }
+ (NSUnitVolume *)megaliters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"ML" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000.0 constant:0.0]]; u->_isimKey = @"megaliters"; u->_isimOne = @"megaliter"; u->_isimOther = @"megaliters"; }); return u; }
+ (NSUnitVolume *)kiloliters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"kL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"kiloliters"; u->_isimOne = @"kiloliter"; u->_isimOther = @"kiloliters"; }); return u; }
+ (NSUnitVolume *)liters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"L" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"liters"; u->_isimOne = @"liter"; u->_isimOther = @"liters"; }); return u; }
+ (NSUnitVolume *)deciliters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"dL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.1 constant:0.0]]; u->_isimKey = @"deciliters"; u->_isimOne = @"deciliter"; u->_isimOther = @"deciliters"; }); return u; }
+ (NSUnitVolume *)centiliters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"cL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.01 constant:0.0]]; u->_isimKey = @"centiliters"; u->_isimOne = @"centiliter"; u->_isimOther = @"centiliters"; }); return u; }
+ (NSUnitVolume *)milliliters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"mL" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"milliliters"; u->_isimOne = @"milliliter"; u->_isimOther = @"milliliters"; }); return u; }
+ (NSUnitVolume *)cubicKilometers { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"km³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000000000000.0 constant:0.0]]; u->_isimKey = @"cubicKilometers"; u->_isimOne = @"cubic kilometer"; u->_isimOther = @"cubic kilometers"; }); return u; }
+ (NSUnitVolume *)cubicMeters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"m³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1000.0 constant:0.0]]; u->_isimKey = @"cubicMeters"; u->_isimOne = @"cubic meter"; u->_isimOther = @"cubic meters"; }); return u; }
+ (NSUnitVolume *)cubicDecimeters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"dm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.0 constant:0.0]]; u->_isimKey = @"cubicDecimeters"; u->_isimOne = @"cubic decimeter"; u->_isimOther = @"cubic decimeters"; }); return u; }
+ (NSUnitVolume *)cubicCentimeters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"cm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.001 constant:0.0]]; u->_isimKey = @"cubicCentimeters"; u->_isimOne = @"cubic centimeter"; u->_isimOther = @"cubic centimeters"; }); return u; }
+ (NSUnitVolume *)cubicMillimeters { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"mm³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1e-06 constant:0.0]]; u->_isimKey = @"cubicMillimeters"; u->_isimOne = @"cubic millimeter"; u->_isimOther = @"cubic millimeters"; }); return u; }
+ (NSUnitVolume *)cubicInches { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"in³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0163871 constant:0.0]]; u->_isimKey = @"cubicInches"; u->_isimOne = @"cubic inch"; u->_isimOther = @"cubic inches"; }); return u; }
+ (NSUnitVolume *)cubicFeet { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"ft³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:28.3168 constant:0.0]]; u->_isimKey = @"cubicFeet"; u->_isimOne = @"cubic foot"; u->_isimOther = @"cubic feet"; }); return u; }
+ (NSUnitVolume *)cubicYards { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"yd³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:764.555 constant:0.0]]; u->_isimKey = @"cubicYards"; u->_isimOne = @"cubic yard"; u->_isimOther = @"cubic yards"; }); return u; }
+ (NSUnitVolume *)cubicMiles { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"mi³" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4168000000000.0 constant:0.0]]; u->_isimKey = @"cubicMiles"; u->_isimOne = @"cubic mile"; u->_isimOther = @"cubic miles"; }); return u; }
+ (NSUnitVolume *)acreFeet { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"af" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1233000.0 constant:0.0]]; u->_isimKey = @"acreFeet"; u->_isimOne = @"acre foot"; u->_isimOther = @"acre feet"; }); return u; }
+ (NSUnitVolume *)bushels { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"bsh" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:35.2391 constant:0.0]]; u->_isimKey = @"bushels"; u->_isimOne = @"bushel"; u->_isimOther = @"bushels"; }); return u; }
+ (NSUnitVolume *)teaspoons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"tsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00492892 constant:0.0]]; u->_isimKey = @"teaspoons"; u->_isimOne = @"teaspoon"; u->_isimOther = @"teaspoons"; }); return u; }
+ (NSUnitVolume *)tablespoons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"tbsp" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0147868 constant:0.0]]; u->_isimKey = @"tablespoons"; u->_isimOne = @"tablespoon"; u->_isimOther = @"tablespoons"; }); return u; }
+ (NSUnitVolume *)fluidOunces { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"fl oz" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0295735 constant:0.0]]; u->_isimKey = @"fluidOunces"; u->_isimOne = @"fluid ounce"; u->_isimOther = @"fluid ounces"; }); return u; }
+ (NSUnitVolume *)cups { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"cup" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.24 constant:0.0]]; u->_isimKey = @"cups"; u->_isimOne = @"cup"; u->_isimOther = @"cups"; }); return u; }
+ (NSUnitVolume *)pints { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"pt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.473176 constant:0.0]]; u->_isimKey = @"pints"; u->_isimOne = @"pint"; u->_isimOther = @"pints"; }); return u; }
+ (NSUnitVolume *)quarts { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"qt" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.946353 constant:0.0]]; u->_isimKey = @"quarts"; u->_isimOne = @"quart"; u->_isimOther = @"quarts"; }); return u; }
+ (NSUnitVolume *)gallons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"gal" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3.78541 constant:0.0]]; u->_isimKey = @"gallons"; u->_isimOne = @"gallon"; u->_isimOther = @"gallons"; }); return u; }
+ (NSUnitVolume *)imperialTeaspoons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"tsp Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.00591939 constant:0.0]]; u->_isimKey = @"imperialTeaspoons"; u->_isimOne = @"imperial teaspoon"; u->_isimOther = @"imperial teaspoons"; }); return u; }
+ (NSUnitVolume *)imperialTablespoons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"tbsp Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0177582 constant:0.0]]; u->_isimKey = @"imperialTablespoons"; u->_isimOne = @"imperial tablespoon"; u->_isimOther = @"imperial tablespoons"; }); return u; }
+ (NSUnitVolume *)imperialFluidOunces { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"fl oz Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.0284131 constant:0.0]]; u->_isimKey = @"imperialFluidOunces"; u->_isimOne = @"imperial fluid ounce"; u->_isimOther = @"imperial fluid ounces"; }); return u; }
+ (NSUnitVolume *)imperialPints { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"pt Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.568261 constant:0.0]]; u->_isimKey = @"imperialPints"; u->_isimOne = @"imperial pint"; u->_isimOther = @"imperial pints"; }); return u; }
+ (NSUnitVolume *)imperialQuarts { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"qt Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:1.13652 constant:0.0]]; u->_isimKey = @"imperialQuarts"; u->_isimOne = @"imperial quart"; u->_isimOther = @"imperial quarts"; }); return u; }
+ (NSUnitVolume *)imperialGallons { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"gal Imp." converter:[[NSUnitConverterLinear alloc] initWithCoefficient:4.54609 constant:0.0]]; u->_isimKey = @"imperialGallons"; u->_isimOne = @"imperial gallon"; u->_isimOther = @"imperial gallons"; }); return u; }
+ (NSUnitVolume *)metricCups { static NSUnitVolume *u; static dispatch_once_t o; dispatch_once(&o, ^{ u = [[NSUnitVolume alloc] initWithSymbol:@"mcup" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:0.25 constant:0.0]]; u->_isimKey = @"metricCups"; u->_isimOne = @"metric cup"; u->_isimOther = @"metric cups"; }); return u; }
@end

/* ================= NSMeasurement ================= */
@implementation NSMeasurement
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithDoubleValue:(double)v unit:(NSUnit *)unit { if ((self = [super init])) { _doubleValue = v; _unit = unit; } return self; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)canBeConvertedToUnit:(NSUnit *)unit {
    return [unit isKindOfClass:[NSDimension class]] && [_unit isKindOfClass:[NSDimension class]] &&
           ([unit isKindOfClass:[_unit class]] || [_unit isKindOfClass:[unit class]]);
}
- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit {
    if ([unit isEqual:_unit]) return self;
    if (![self canBeConvertedToUnit:unit]) [NSException raise:NSInvalidArgumentException format:@"Cannot convert measurement from %@ to %@", _unit.symbol, unit.symbol];
    double base = [((NSDimension *)_unit).converter baseUnitValueFromValue:_doubleValue];
    return [[NSMeasurement alloc] initWithDoubleValue:[((NSDimension *)unit).converter valueFromBaseUnitValue:base] unit:unit];
}
- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)m {
    NSMeasurement *o = [m measurementByConvertingToUnit:_unit];
    return [[NSMeasurement alloc] initWithDoubleValue:_doubleValue + o.doubleValue unit:_unit];
}
- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)m {
    NSMeasurement *o = [m measurementByConvertingToUnit:_unit];
    return [[NSMeasurement alloc] initWithDoubleValue:_doubleValue - o.doubleValue unit:_unit];
}
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSMeasurement class]]) return NO;
    NSMeasurement *m = o;
    if ([m.unit isEqual:_unit]) return m.doubleValue == _doubleValue;
    return [self canBeConvertedToUnit:m.unit] && fabs([m measurementByConvertingToUnit:_unit].doubleValue - _doubleValue) < 1e-9;
}
- (NSUInteger)hash { return (NSUInteger)_doubleValue ^ _unit.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"%g %@", _doubleValue, _unit.symbol]; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithDoubleValue:0 unit:[[NSUnit alloc] initWithSymbol:@""]]; }
@end

/* ================= NSMeasurementFormatter ================= */
/* long unit names in other languages: key -> "one|other" */
static NSString *localized_name(NSString *key, NSString *lang, BOOL one) {
    static NSDictionary *names;
    static dispatch_once_t o;
    dispatch_once(&o, ^{
        names = @{
            @"pt": @{ @"kilometers": @"quilômetro|quilômetros", @"meters": @"metro|metros", @"centimeters": @"centímetro|centímetros", @"millimeters": @"milímetro|milímetros",
                      @"miles": @"milha|milhas", @"feet": @"pé|pés", @"inches": @"polegada|polegadas", @"kilograms": @"quilograma|quilogramas", @"grams": @"grama|gramas",
                      @"pounds": @"libra|libras", @"ounces": @"onça|onças", @"liters": @"litro|litros", @"milliliters": @"mililitro|mililitros",
                      @"celsius": @"grau Celsius|graus Celsius", @"fahrenheit": @"grau Fahrenheit|graus Fahrenheit", @"kilometersPerHour": @"quilômetro por hora|quilômetros por hora",
                      @"milesPerHour": @"milha por hora|milhas por hora", @"hours": @"hora|horas", @"minutes": @"minuto|minutos", @"seconds": @"segundo|segundos" },
            @"es": @{ @"kilometers": @"kilómetro|kilómetros", @"meters": @"metro|metros", @"centimeters": @"centímetro|centímetros", @"millimeters": @"milímetro|milímetros",
                      @"miles": @"milla|millas", @"feet": @"pie|pies", @"inches": @"pulgada|pulgadas", @"kilograms": @"kilogramo|kilogramos", @"grams": @"gramo|gramos",
                      @"pounds": @"libra|libras", @"ounces": @"onza|onzas", @"liters": @"litro|litros", @"milliliters": @"mililitro|mililitros",
                      @"celsius": @"grado Celsius|grados Celsius", @"fahrenheit": @"grado Fahrenheit|grados Fahrenheit", @"kilometersPerHour": @"kilómetro por hora|kilómetros por hora",
                      @"milesPerHour": @"milla por hora|millas por hora", @"hours": @"hora|horas", @"minutes": @"minuto|minutos", @"seconds": @"segundo|segundos" },
            @"fr": @{ @"kilometers": @"kilomètre|kilomètres", @"meters": @"mètre|mètres", @"centimeters": @"centimètre|centimètres", @"millimeters": @"millimètre|millimètres",
                      @"miles": @"mille|milles", @"feet": @"pied|pieds", @"inches": @"pouce|pouces", @"kilograms": @"kilogramme|kilogrammes", @"grams": @"gramme|grammes",
                      @"pounds": @"livre|livres", @"ounces": @"once|onces", @"liters": @"litre|litres", @"milliliters": @"millilitre|millilitres",
                      @"celsius": @"degré Celsius|degrés Celsius", @"fahrenheit": @"degré Fahrenheit|degrés Fahrenheit", @"kilometersPerHour": @"kilomètre par heure|kilomètres par heure",
                      @"milesPerHour": @"mille par heure|milles par heure", @"hours": @"heure|heures", @"minutes": @"minute|minutes", @"seconds": @"seconde|secondes" },
            @"de": @{ @"kilometers": @"Kilometer|Kilometer", @"meters": @"Meter|Meter", @"centimeters": @"Zentimeter|Zentimeter", @"millimeters": @"Millimeter|Millimeter",
                      @"miles": @"Meile|Meilen", @"feet": @"Fuß|Fuß", @"inches": @"Zoll|Zoll", @"kilograms": @"Kilogramm|Kilogramm", @"grams": @"Gramm|Gramm",
                      @"pounds": @"Pfund|Pfund", @"ounces": @"Unze|Unzen", @"liters": @"Liter|Liter", @"milliliters": @"Milliliter|Milliliter",
                      @"celsius": @"Grad Celsius|Grad Celsius", @"fahrenheit": @"Grad Fahrenheit|Grad Fahrenheit", @"kilometersPerHour": @"Kilometer pro Stunde|Kilometer pro Stunde",
                      @"milesPerHour": @"Meile pro Stunde|Meilen pro Stunde", @"hours": @"Stunde|Stunden", @"minutes": @"Minute|Minuten", @"seconds": @"Sekunde|Sekunden" },
            @"it": @{ @"kilometers": @"chilometro|chilometri", @"meters": @"metro|metri", @"centimeters": @"centimetro|centimetri", @"millimeters": @"millimetro|millimetri",
                      @"miles": @"miglio|miglia", @"feet": @"piede|piedi", @"inches": @"pollice|pollici", @"kilograms": @"chilogrammo|chilogrammi", @"grams": @"grammo|grammi",
                      @"pounds": @"libbra|libbre", @"ounces": @"oncia|once", @"liters": @"litro|litri", @"milliliters": @"millilitro|millilitri",
                      @"celsius": @"grado Celsius|gradi Celsius", @"fahrenheit": @"grado Fahrenheit|gradi Fahrenheit", @"kilometersPerHour": @"chilometro orario|chilometri orari",
                      @"milesPerHour": @"miglio orario|miglia orarie", @"hours": @"ora|ore", @"minutes": @"minuto|minuti", @"seconds": @"secondo|secondi" },
        };
    });
    NSString *pair = names[lang][key];
    if (!pair) return nil;
    NSArray *p = [pair componentsSeparatedByString:@"|"];
    return one ? p[0] : p[1];
}
NSString *isim_unit_long_name(NSUnit *unit, NSString *lang, BOOL one) {
    NSString *key = unit->_isimKey;
    if (key && ![lang isEqualToString:@"en"]) { NSString *n = localized_name(key, lang, one); if (n) return n; }
    if (unit->_isimOne) return one ? unit->_isimOne : unit->_isimOther;
    return unit.symbol;
}
static NSUnit *unit_named(Class cls, NSString *name) { return ((NSUnit *(*)(id, SEL))objc_msgSend)(cls, NSSelectorFromString(name)); }
/* the unit the region prefers for a measurement (US customary vs metric), or the unit itself */
NSUnit *isim_preferred_unit(NSMeasurement *m, NSLocale *locale, NSString *usage) {
    BOOL metric = locale ? locale.usesMetricSystem : NSLocale.currentLocale.usesMetricSystem;
    NSUnit *u = m.unit;
    NSString *key = u->_isimKey ?: @"";
    double v = fabs(m.doubleValue);
    if ([u isKindOfClass:[NSUnitTemperature class]]) {
        if ([key isEqualToString:@"kelvin"]) return u;
        return metric ? NSUnitTemperature.celsius : NSUnitTemperature.fahrenheit;
    }
    NSSet *usUnits = [NSSet setWithArray:@[@"inches", @"feet", @"yards", @"miles", @"ounces", @"pounds", @"stones", @"milesPerHour", @"gallons", @"quarts", @"pints",
                                           @"cups", @"fluidOunces", @"teaspoons", @"tablespoons", @"fahrenheit", @"squareFeet", @"squareMiles", @"acres"]];
    BOOL isUS = [usUnits containsObject:key];
    if (metric == !isUS) return u;
    if ([u isKindOfClass:[NSUnitLength class]]) {
        double meters = [((NSDimension *)u).converter baseUnitValueFromValue:v];
        if (metric) return meters >= 1000 ? NSUnitLength.kilometers : meters >= 1 ? NSUnitLength.meters : NSUnitLength.centimeters;
        if ([usage isEqualToString:@"person"]) return meters >= 1 ? NSUnitLength.feet : NSUnitLength.inches;
        return meters >= 1609.344 / 10 && ![usage isEqualToString:@"asProvided"] ? NSUnitLength.miles : meters >= 0.3048 ? NSUnitLength.feet : NSUnitLength.inches;
    }
    if ([u isKindOfClass:[NSUnitMass class]]) {
        double kg = [((NSDimension *)u).converter baseUnitValueFromValue:v];
        if (metric) return kg >= 1 ? NSUnitMass.kilograms : NSUnitMass.grams;
        return kg >= 0.45 ? NSUnitMass.pounds : NSUnitMass.ounces;
    }
    if ([u isKindOfClass:[NSUnitSpeed class]]) return metric ? NSUnitSpeed.kilometersPerHour : NSUnitSpeed.milesPerHour;
    if ([u isKindOfClass:[NSUnitVolume class]]) {
        double l = [((NSDimension *)u).converter baseUnitValueFromValue:v];
        if (metric) return l >= 1 ? NSUnitVolume.liters : NSUnitVolume.milliliters;
        return l >= 3.78541 ? NSUnitVolume.gallons : l >= 0.473176 ? NSUnitVolume.pints : NSUnitVolume.fluidOunces;
    }
    if ([u isKindOfClass:[NSUnitArea class]]) {
        double m2 = [((NSDimension *)u).converter baseUnitValueFromValue:v];
        if (metric) return m2 >= 1e6 ? NSUnitArea.squareKilometers : NSUnitArea.squareMeters;
        return m2 >= 2589988 ? NSUnitArea.squareMiles : NSUnitArea.squareFeet;
    }
    (void)unit_named;
    return u;
}
/* "5 km", "5km", "5 kilometers"; width: 0 narrow/short, 1 abbreviated/medium, 2 wide/long */
NSString *isim_format_measurement(NSString *number, double value, NSUnit *unit, int width, NSLocale *locale) {
    NSString *lang = isim_locale_lang(locale);
    BOOL temp = [unit isKindOfClass:[NSUnitTemperature class]] && ![unit->_isimKey isEqualToString:@"kelvin"];
    if (width == 2) {
        BOOL one = isim_plural_one(lang, value, [number rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@".,"]].location != NSNotFound ? 1 : 0);
        return [NSString stringWithFormat:@"%@ %@", number, isim_unit_long_name(unit, lang, one)];
    }
    NSString *sym = unit.symbol;
    if (temp && width == 0) return [number stringByAppendingString:@"°"];
    if (temp || [sym isEqualToString:@"°"] || [sym isEqualToString:@"ʹ"] || [sym isEqualToString:@"ʺ"]) {
        BOOL space = temp && ([lang isEqualToString:@"de"] || [lang isEqualToString:@"fr"] || [lang isEqualToString:@"es"] || [lang isEqualToString:@"it"]);
        return [NSString stringWithFormat:@"%@%@%@", number, space ? @" " : @"", sym];
    }
    if (width == 0) return [number stringByAppendingString:sym];
    return [NSString stringWithFormat:@"%@ %@", number, sym];
}
@implementation NSMeasurementFormatter
@synthesize locale = _locale;
- (instancetype)init {
    if ((self = [super init])) {
        _unitStyle = NSFormattingUnitStyleMedium; _locale = NSLocale.currentLocale;
        _numberFormatter = [NSNumberFormatter new]; _numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    }
    return self;
}
- (void)setLocale:(NSLocale *)l { _locale = l ?: NSLocale.currentLocale; _numberFormatter.locale = _locale; }
- (NSLocale *)locale { return _locale; }
- (NSString *)stringFromMeasurement:(NSMeasurement *)measurement {
    NSMeasurement *m = measurement;
    if (!(_unitOptions & NSMeasurementFormatterUnitOptionsProvidedUnit) && [m.unit isKindOfClass:[NSDimension class]])
        m = [m measurementByConvertingToUnit:isim_preferred_unit(m, _locale, @"general")];
    if ((_unitOptions & NSMeasurementFormatterUnitOptionsNaturalScale) && [m.unit isKindOfClass:[NSUnitLength class]]) {
        double meters = [((NSDimension *)m.unit).converter baseUnitValueFromValue:fabs(m.doubleValue)];
        NSString *k = m.unit->_isimKey;
        if ([@[@"meters", @"kilometers", @"centimeters", @"millimeters"] containsObject:k ?: @""])
            m = [m measurementByConvertingToUnit:meters >= 1000 ? NSUnitLength.kilometers : meters >= 1 ? NSUnitLength.meters : meters >= 0.01 ? NSUnitLength.centimeters : NSUnitLength.millimeters];
    }
    NSNumberFormatter *nf = _numberFormatter;
    if (!nf.locale || ![nf.locale isEqual:_locale]) { nf = [_numberFormatter copy]; nf.locale = _locale; }
    NSString *num = [nf stringFromNumber:@(m.doubleValue)];
    if ((_unitOptions & NSMeasurementFormatterUnitOptionsTemperatureWithoutUnit) && [m.unit isKindOfClass:[NSUnitTemperature class]])
        return [num stringByAppendingString:@"°"];
    int width = _unitStyle == NSFormattingUnitStyleShort ? 0 : _unitStyle == NSFormattingUnitStyleLong ? 2 : 1;
    return isim_format_measurement(num, m.doubleValue, m.unit, width, _locale);
}
- (NSString *)stringFromUnit:(NSUnit *)unit {
    if (_unitStyle == NSFormattingUnitStyleLong) return isim_unit_long_name(unit, isim_locale_lang(_locale), NO);
    return unit.symbol;
}
- (NSString *)stringForObjectValue:(id)obj { return [obj isKindOfClass:[NSMeasurement class]] ? [self stringFromMeasurement:obj] : nil; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (NSString *)_isim_formatNumber:(NSString *)number value:(double)value unit:(NSUnit *)unit width:(NSInteger)width locale:(NSLocale *)locale {
    return isim_format_measurement(number, value, unit, (int)width, locale ?: NSLocale.currentLocale);
}
@end
@implementation NSMeasurement (IsimPreferredImpl)
- (NSMeasurement *)_isim_measurementInPreferredUnitForLocale:(NSLocale *)locale usage:(NSString *)usage {
    if ([usage isEqualToString:@"asProvided"] || ![self.unit isKindOfClass:[NSDimension class]]) return self;
    return [self measurementByConvertingToUnit:isim_preferred_unit(self, locale, usage)];
}
@end
