#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSLocale, NSNumberFormatter;
/* isim: unit tables generated from CLDR/Apple-documented conversion factors (out of tree generator). */
NS_SWIFT_NAME(UnitConverter)
@interface NSUnitConverter : NSObject
- (double)baseUnitValueFromValue:(double)value;
- (double)valueFromBaseUnitValue:(double)baseUnitValue;
@end
NS_SWIFT_NAME(UnitConverterLinear)
@interface NSUnitConverterLinear : NSUnitConverter <NSSecureCoding>
@property (readonly) double coefficient;
@property (readonly) double constant;
- (instancetype)initWithCoefficient:(double)coefficient;
- (instancetype)initWithCoefficient:(double)coefficient constant:(double)constant NS_DESIGNATED_INITIALIZER;
@end
NS_SWIFT_NAME(Unit)
@interface NSUnit : NSObject <NSCopying, NSSecureCoding>
@property (readonly, copy) NSString *symbol;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithSymbol:(NSString *)symbol NS_DESIGNATED_INITIALIZER;
@end
NS_SWIFT_NAME(Dimension)
@interface NSDimension : NSUnit <NSSecureCoding>
@property (readonly, copy) NSUnitConverter *converter;
- (instancetype)initWithSymbol:(NSString *)symbol converter:(NSUnitConverter *)converter NS_DESIGNATED_INITIALIZER;
+ (instancetype)baseUnit;
@end
NS_SWIFT_NAME(UnitAcceleration)
@interface NSUnitAcceleration : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitAcceleration *metersPerSecondSquared;
@property (class, readonly, copy) NSUnitAcceleration *gravity;
@end
NS_SWIFT_NAME(UnitAngle)
@interface NSUnitAngle : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitAngle *degrees;
@property (class, readonly, copy) NSUnitAngle *arcMinutes;
@property (class, readonly, copy) NSUnitAngle *arcSeconds;
@property (class, readonly, copy) NSUnitAngle *radians;
@property (class, readonly, copy) NSUnitAngle *gradians;
@property (class, readonly, copy) NSUnitAngle *revolutions;
@end
NS_SWIFT_NAME(UnitArea)
@interface NSUnitArea : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitArea *squareMegameters;
@property (class, readonly, copy) NSUnitArea *squareKilometers;
@property (class, readonly, copy) NSUnitArea *squareMeters;
@property (class, readonly, copy) NSUnitArea *squareCentimeters;
@property (class, readonly, copy) NSUnitArea *squareMillimeters;
@property (class, readonly, copy) NSUnitArea *squareMicrometers;
@property (class, readonly, copy) NSUnitArea *squareNanometers;
@property (class, readonly, copy) NSUnitArea *squareInches;
@property (class, readonly, copy) NSUnitArea *squareFeet;
@property (class, readonly, copy) NSUnitArea *squareYards;
@property (class, readonly, copy) NSUnitArea *squareMiles;
@property (class, readonly, copy) NSUnitArea *acres;
@property (class, readonly, copy) NSUnitArea *ares;
@property (class, readonly, copy) NSUnitArea *hectares;
@end
NS_SWIFT_NAME(UnitDuration)
@interface NSUnitDuration : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitDuration *hours;
@property (class, readonly, copy) NSUnitDuration *minutes;
@property (class, readonly, copy) NSUnitDuration *seconds;
@property (class, readonly, copy) NSUnitDuration *milliseconds;
@property (class, readonly, copy) NSUnitDuration *microseconds;
@property (class, readonly, copy) NSUnitDuration *nanoseconds;
@property (class, readonly, copy) NSUnitDuration *picoseconds;
@end
NS_SWIFT_NAME(UnitElectricCharge)
@interface NSUnitElectricCharge : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitElectricCharge *coulombs;
@property (class, readonly, copy) NSUnitElectricCharge *megaampereHours;
@property (class, readonly, copy) NSUnitElectricCharge *kiloampereHours;
@property (class, readonly, copy) NSUnitElectricCharge *ampereHours;
@property (class, readonly, copy) NSUnitElectricCharge *milliampereHours;
@property (class, readonly, copy) NSUnitElectricCharge *microampereHours;
@end
NS_SWIFT_NAME(UnitElectricCurrent)
@interface NSUnitElectricCurrent : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitElectricCurrent *megaamperes;
@property (class, readonly, copy) NSUnitElectricCurrent *kiloamperes;
@property (class, readonly, copy) NSUnitElectricCurrent *amperes;
@property (class, readonly, copy) NSUnitElectricCurrent *milliamperes;
@property (class, readonly, copy) NSUnitElectricCurrent *microamperes;
@end
NS_SWIFT_NAME(UnitElectricPotentialDifference)
@interface NSUnitElectricPotentialDifference : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitElectricPotentialDifference *megavolts;
@property (class, readonly, copy) NSUnitElectricPotentialDifference *kilovolts;
@property (class, readonly, copy) NSUnitElectricPotentialDifference *volts;
@property (class, readonly, copy) NSUnitElectricPotentialDifference *millivolts;
@property (class, readonly, copy) NSUnitElectricPotentialDifference *microvolts;
@end
NS_SWIFT_NAME(UnitElectricResistance)
@interface NSUnitElectricResistance : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitElectricResistance *megaohms;
@property (class, readonly, copy) NSUnitElectricResistance *kiloohms;
@property (class, readonly, copy) NSUnitElectricResistance *ohms;
@property (class, readonly, copy) NSUnitElectricResistance *milliohms;
@property (class, readonly, copy) NSUnitElectricResistance *microohms;
@end
NS_SWIFT_NAME(UnitEnergy)
@interface NSUnitEnergy : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitEnergy *kilojoules;
@property (class, readonly, copy) NSUnitEnergy *joules;
@property (class, readonly, copy) NSUnitEnergy *kilocalories;
@property (class, readonly, copy) NSUnitEnergy *calories;
@property (class, readonly, copy) NSUnitEnergy *kilowattHours;
@end
NS_SWIFT_NAME(UnitFrequency)
@interface NSUnitFrequency : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitFrequency *terahertz;
@property (class, readonly, copy) NSUnitFrequency *gigahertz;
@property (class, readonly, copy) NSUnitFrequency *megahertz;
@property (class, readonly, copy) NSUnitFrequency *kilohertz;
@property (class, readonly, copy) NSUnitFrequency *hertz;
@property (class, readonly, copy) NSUnitFrequency *millihertz;
@property (class, readonly, copy) NSUnitFrequency *microhertz;
@property (class, readonly, copy) NSUnitFrequency *nanohertz;
@property (class, readonly, copy) NSUnitFrequency *framesPerSecond;
@end
NS_SWIFT_NAME(UnitFuelEfficiency)
@interface NSUnitFuelEfficiency : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitFuelEfficiency *litersPer100Kilometers;
@property (class, readonly, copy) NSUnitFuelEfficiency *milesPerImperialGallon;
@property (class, readonly, copy) NSUnitFuelEfficiency *milesPerGallon;
@end
NS_SWIFT_NAME(UnitIlluminance)
@interface NSUnitIlluminance : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitIlluminance *lux;
@end
NS_SWIFT_NAME(UnitInformationStorage)
@interface NSUnitInformationStorage : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitInformationStorage *bytes;
@property (class, readonly, copy) NSUnitInformationStorage *bits;
@property (class, readonly, copy) NSUnitInformationStorage *nibbles;
@property (class, readonly, copy) NSUnitInformationStorage *yottabytes;
@property (class, readonly, copy) NSUnitInformationStorage *zettabytes;
@property (class, readonly, copy) NSUnitInformationStorage *exabytes;
@property (class, readonly, copy) NSUnitInformationStorage *petabytes;
@property (class, readonly, copy) NSUnitInformationStorage *terabytes;
@property (class, readonly, copy) NSUnitInformationStorage *gigabytes;
@property (class, readonly, copy) NSUnitInformationStorage *megabytes;
@property (class, readonly, copy) NSUnitInformationStorage *kilobytes;
@property (class, readonly, copy) NSUnitInformationStorage *yottabits;
@property (class, readonly, copy) NSUnitInformationStorage *zettabits;
@property (class, readonly, copy) NSUnitInformationStorage *exabits;
@property (class, readonly, copy) NSUnitInformationStorage *petabits;
@property (class, readonly, copy) NSUnitInformationStorage *terabits;
@property (class, readonly, copy) NSUnitInformationStorage *gigabits;
@property (class, readonly, copy) NSUnitInformationStorage *megabits;
@property (class, readonly, copy) NSUnitInformationStorage *kilobits;
@property (class, readonly, copy) NSUnitInformationStorage *yobibytes;
@property (class, readonly, copy) NSUnitInformationStorage *zebibytes;
@property (class, readonly, copy) NSUnitInformationStorage *exbibytes;
@property (class, readonly, copy) NSUnitInformationStorage *pebibytes;
@property (class, readonly, copy) NSUnitInformationStorage *tebibytes;
@property (class, readonly, copy) NSUnitInformationStorage *gibibytes;
@property (class, readonly, copy) NSUnitInformationStorage *mebibytes;
@property (class, readonly, copy) NSUnitInformationStorage *kibibytes;
@property (class, readonly, copy) NSUnitInformationStorage *yobibits;
@property (class, readonly, copy) NSUnitInformationStorage *zebibits;
@property (class, readonly, copy) NSUnitInformationStorage *exbibits;
@property (class, readonly, copy) NSUnitInformationStorage *pebibits;
@property (class, readonly, copy) NSUnitInformationStorage *tebibits;
@property (class, readonly, copy) NSUnitInformationStorage *gibibits;
@property (class, readonly, copy) NSUnitInformationStorage *mebibits;
@property (class, readonly, copy) NSUnitInformationStorage *kibibits;
@end
NS_SWIFT_NAME(UnitLength)
@interface NSUnitLength : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitLength *megameters;
@property (class, readonly, copy) NSUnitLength *kilometers;
@property (class, readonly, copy) NSUnitLength *hectometers;
@property (class, readonly, copy) NSUnitLength *decameters;
@property (class, readonly, copy) NSUnitLength *meters;
@property (class, readonly, copy) NSUnitLength *decimeters;
@property (class, readonly, copy) NSUnitLength *centimeters;
@property (class, readonly, copy) NSUnitLength *millimeters;
@property (class, readonly, copy) NSUnitLength *micrometers;
@property (class, readonly, copy) NSUnitLength *nanometers;
@property (class, readonly, copy) NSUnitLength *picometers;
@property (class, readonly, copy) NSUnitLength *inches;
@property (class, readonly, copy) NSUnitLength *feet;
@property (class, readonly, copy) NSUnitLength *yards;
@property (class, readonly, copy) NSUnitLength *miles;
@property (class, readonly, copy) NSUnitLength *scandinavianMiles;
@property (class, readonly, copy) NSUnitLength *lightyears;
@property (class, readonly, copy) NSUnitLength *nauticalMiles;
@property (class, readonly, copy) NSUnitLength *fathoms;
@property (class, readonly, copy) NSUnitLength *furlongs;
@property (class, readonly, copy) NSUnitLength *astronomicalUnits;
@property (class, readonly, copy) NSUnitLength *parsecs;
@end
NS_SWIFT_NAME(UnitMass)
@interface NSUnitMass : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitMass *kilograms;
@property (class, readonly, copy) NSUnitMass *grams;
@property (class, readonly, copy) NSUnitMass *decigrams;
@property (class, readonly, copy) NSUnitMass *centigrams;
@property (class, readonly, copy) NSUnitMass *milligrams;
@property (class, readonly, copy) NSUnitMass *micrograms;
@property (class, readonly, copy) NSUnitMass *nanograms;
@property (class, readonly, copy) NSUnitMass *picograms;
@property (class, readonly, copy) NSUnitMass *ounces;
@property (class, readonly, copy) NSUnitMass *pounds;
@property (class, readonly, copy) NSUnitMass *stones;
@property (class, readonly, copy) NSUnitMass *metricTons;
@property (class, readonly, copy) NSUnitMass *shortTons;
@property (class, readonly, copy) NSUnitMass *carats;
@property (class, readonly, copy) NSUnitMass *ouncesTroy;
@property (class, readonly, copy) NSUnitMass *slugs;
@end
NS_SWIFT_NAME(UnitPower)
@interface NSUnitPower : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitPower *terawatts;
@property (class, readonly, copy) NSUnitPower *gigawatts;
@property (class, readonly, copy) NSUnitPower *megawatts;
@property (class, readonly, copy) NSUnitPower *kilowatts;
@property (class, readonly, copy) NSUnitPower *watts;
@property (class, readonly, copy) NSUnitPower *milliwatts;
@property (class, readonly, copy) NSUnitPower *microwatts;
@property (class, readonly, copy) NSUnitPower *nanowatts;
@property (class, readonly, copy) NSUnitPower *picowatts;
@property (class, readonly, copy) NSUnitPower *femtowatts;
@property (class, readonly, copy) NSUnitPower *horsepower;
@end
NS_SWIFT_NAME(UnitPressure)
@interface NSUnitPressure : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitPressure *newtonsPerMetersSquared;
@property (class, readonly, copy) NSUnitPressure *gigapascals;
@property (class, readonly, copy) NSUnitPressure *megapascals;
@property (class, readonly, copy) NSUnitPressure *kilopascals;
@property (class, readonly, copy) NSUnitPressure *hectopascals;
@property (class, readonly, copy) NSUnitPressure *inchesOfMercury;
@property (class, readonly, copy) NSUnitPressure *bars;
@property (class, readonly, copy) NSUnitPressure *millibars;
@property (class, readonly, copy) NSUnitPressure *millimetersOfMercury;
@property (class, readonly, copy) NSUnitPressure *poundsForcePerSquareInch;
@end
NS_SWIFT_NAME(UnitSpeed)
@interface NSUnitSpeed : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitSpeed *metersPerSecond;
@property (class, readonly, copy) NSUnitSpeed *kilometersPerHour;
@property (class, readonly, copy) NSUnitSpeed *milesPerHour;
@property (class, readonly, copy) NSUnitSpeed *knots;
@end
NS_SWIFT_NAME(UnitTemperature)
@interface NSUnitTemperature : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitTemperature *kelvin;
@property (class, readonly, copy) NSUnitTemperature *celsius;
@property (class, readonly, copy) NSUnitTemperature *fahrenheit;
@end
NS_SWIFT_NAME(UnitVolume)
@interface NSUnitVolume : NSDimension <NSSecureCoding>
@property (class, readonly, copy) NSUnitVolume *megaliters;
@property (class, readonly, copy) NSUnitVolume *kiloliters;
@property (class, readonly, copy) NSUnitVolume *liters;
@property (class, readonly, copy) NSUnitVolume *deciliters;
@property (class, readonly, copy) NSUnitVolume *centiliters;
@property (class, readonly, copy) NSUnitVolume *milliliters;
@property (class, readonly, copy) NSUnitVolume *cubicKilometers;
@property (class, readonly, copy) NSUnitVolume *cubicMeters;
@property (class, readonly, copy) NSUnitVolume *cubicDecimeters;
@property (class, readonly, copy) NSUnitVolume *cubicCentimeters;
@property (class, readonly, copy) NSUnitVolume *cubicMillimeters;
@property (class, readonly, copy) NSUnitVolume *cubicInches;
@property (class, readonly, copy) NSUnitVolume *cubicFeet;
@property (class, readonly, copy) NSUnitVolume *cubicYards;
@property (class, readonly, copy) NSUnitVolume *cubicMiles;
@property (class, readonly, copy) NSUnitVolume *acreFeet;
@property (class, readonly, copy) NSUnitVolume *bushels;
@property (class, readonly, copy) NSUnitVolume *teaspoons;
@property (class, readonly, copy) NSUnitVolume *tablespoons;
@property (class, readonly, copy) NSUnitVolume *fluidOunces;
@property (class, readonly, copy) NSUnitVolume *cups;
@property (class, readonly, copy) NSUnitVolume *pints;
@property (class, readonly, copy) NSUnitVolume *quarts;
@property (class, readonly, copy) NSUnitVolume *gallons;
@property (class, readonly, copy) NSUnitVolume *imperialTeaspoons;
@property (class, readonly, copy) NSUnitVolume *imperialTablespoons;
@property (class, readonly, copy) NSUnitVolume *imperialFluidOunces;
@property (class, readonly, copy) NSUnitVolume *imperialPints;
@property (class, readonly, copy) NSUnitVolume *imperialQuarts;
@property (class, readonly, copy) NSUnitVolume *imperialGallons;
@property (class, readonly, copy) NSUnitVolume *metricCups;
@end
NS_ASSUME_NONNULL_END
