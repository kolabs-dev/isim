// isim WeatherKit (issue #415): the value types of a forecast. Apple's types have no public initializers; isim's
// simulation (Simulation.swift) makes them. Units are the ones WeatherKit answers in: °C, km/h, mbar, mm, m.
import Foundation
import CoreLocation

// MARK: - Metadata, attribution, availability

public struct WeatherMetadata: Codable, Equatable, Sendable {
    public var date: Date
    public var expirationDate: Date
    public var location: CLLocation

    init(date: Date, expirationDate: Date, location: CLLocation) {
        self.date = date; self.expirationDate = expirationDate; self.location = location
    }
    enum CodingKeys: String, CodingKey { case date, expirationDate, latitude, longitude, altitude }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decode(Date.self, forKey: .date)
        expirationDate = try c.decode(Date.self, forKey: .expirationDate)
        location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: try c.decode(Double.self, forKey: .latitude),
                                                                 longitude: try c.decode(Double.self, forKey: .longitude)),
                              altitude: try c.decode(Double.self, forKey: .altitude), horizontalAccuracy: 0, verticalAccuracy: 0,
                              timestamp: date)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(date, forKey: .date)
        try c.encode(expirationDate, forKey: .expirationDate)
        try c.encode(location.coordinate.latitude, forKey: .latitude)
        try c.encode(location.coordinate.longitude, forKey: .longitude)
        try c.encode(location.altitude, forKey: .altitude)
    }
    public static func == (a: WeatherMetadata, b: WeatherMetadata) -> Bool {
        a.date == b.date && a.expirationDate == b.expirationDate && a.location.coordinate.latitude == b.location.coordinate.latitude
            && a.location.coordinate.longitude == b.location.coordinate.longitude && a.location.altitude == b.location.altitude
    }
}

public struct WeatherAttribution: Sendable {
    public var serviceName: String
    public var legalPageURL: URL
    public var legalAttributionText: String
    public var combinedMarkLightURL: URL
    public var combinedMarkDarkURL: URL
    public var squareMarkURL: URL
}

public struct WeatherAvailability: Codable, Equatable, Sendable {
    public enum AvailabilityKind: String, Codable, Equatable, Sendable {
        case available, temporarilyUnavailable, unsupported, unknown
    }
    public var minuteAvailability: AvailabilityKind
    public var alertAvailability: AvailabilityKind
}

public enum WeatherError: LocalizedError, Sendable {
    case permissionDenied
    case unknown
    public var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permission denied"
        case .unknown: return "An unknown error occurred"
        }
    }
    public var failureReason: String? {
        switch self {
        case .permissionDenied: return "The app does not have the WeatherKit entitlement (com.apple.developer.weatherkit)."
        case .unknown: return "The weather service could not be reached."
        }
    }
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied: return "Add the WeatherKit capability to the app."
        case .unknown: return "Try again later."
        }
    }
    public var helpAnchor: String? { nil }
}

// MARK: - Enumerations

public enum WeatherCondition: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
    case blowingDust, clear, cloudy, foggy, haze, mostlyClear, mostlyCloudy, partlyCloudy, smoky
    case breezy, windy
    case drizzle, heavyRain, isolatedThunderstorms, rain, sunShowers, scatteredThunderstorms, strongStorms, thunderstorms
    case frigid, hail, hot
    case flurries, sleet, snow, sunFlurries, wintryMix
    case blizzard, blowingSnow, freezingDrizzle, freezingRain, heavySnow
    case hurricane, tropicalStorm

    public var description: String {
        switch self {
        case .blowingDust: return "Blowing Dust"
        case .mostlyClear: return "Mostly Clear"
        case .mostlyCloudy: return "Mostly Cloudy"
        case .partlyCloudy: return "Partly Cloudy"
        case .heavyRain: return "Heavy Rain"
        case .isolatedThunderstorms: return "Isolated Thunderstorms"
        case .sunShowers: return "Sun Showers"
        case .scatteredThunderstorms: return "Scattered Thunderstorms"
        case .strongStorms: return "Strong Storms"
        case .sunFlurries: return "Sun Flurries"
        case .wintryMix: return "Wintry Mix"
        case .blowingSnow: return "Blowing Snow"
        case .freezingDrizzle: return "Freezing Drizzle"
        case .freezingRain: return "Freezing Rain"
        case .heavySnow: return "Heavy Snow"
        case .tropicalStorm: return "Tropical Storm"
        case .foggy: return "Fog"
        case .smoky: return "Smoke"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
    public var accessibilityDescription: String { description }

    var precipitates: Bool {
        switch self {
        case .drizzle, .heavyRain, .isolatedThunderstorms, .rain, .sunShowers, .scatteredThunderstorms, .strongStorms, .thunderstorms,
             .hail, .flurries, .sleet, .snow, .sunFlurries, .wintryMix, .blizzard, .blowingSnow, .freezingDrizzle, .freezingRain,
             .heavySnow, .hurricane, .tropicalStorm: return true
        default: return false
        }
    }
    var precipitation: Precipitation {
        switch self {
        case .hail: return .hail
        case .sleet, .freezingRain, .freezingDrizzle: return .sleet
        case .wintryMix: return .mixed
        case .flurries, .snow, .sunFlurries, .blizzard, .blowingSnow, .heavySnow: return .snow
        default: return precipitates ? .rain : .none
        }
    }
    // the SF Symbol Apple's Weather app shows for the condition, by day or by night
    func symbolName(daylight: Bool) -> String {
        switch self {
        case .clear, .mostlyClear: return daylight ? "sun.max" : "moon.stars"
        case .partlyCloudy: return daylight ? "cloud.sun" : "cloud.moon"
        case .mostlyCloudy, .cloudy: return "cloud"
        case .foggy: return "cloud.fog"
        case .haze: return daylight ? "sun.haze" : "moon.haze"
        case .smoky: return "smoke"
        case .blowingDust: return "sun.dust"
        case .breezy, .windy: return "wind"
        case .drizzle, .freezingDrizzle: return "cloud.drizzle"
        case .rain: return "cloud.rain"
        case .heavyRain: return "cloud.heavyrain"
        case .sunShowers: return daylight ? "cloud.sun.rain" : "cloud.moon.rain"
        case .isolatedThunderstorms, .scatteredThunderstorms: return daylight ? "cloud.sun.bolt" : "cloud.moon.bolt"
        case .thunderstorms, .strongStorms: return "cloud.bolt.rain"
        case .frigid: return "thermometer.snowflake"
        case .hot: return "thermometer.sun"
        case .hail: return "cloud.hail"
        case .flurries, .snow: return "cloud.snow"
        case .sunFlurries: return "sun.snow"
        case .sleet, .wintryMix, .freezingRain: return "cloud.sleet"
        case .heavySnow: return "snowflake"
        case .blizzard, .blowingSnow: return "wind.snow"
        case .hurricane: return "hurricane"
        case .tropicalStorm: return "tropicalstorm"
        }
    }
}

public enum Precipitation: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
    case none, hail, mixed, rain, sleet, snow
    public var description: String {
        switch self {
        case .none: return "No Precipitation"
        case .mixed: return "Wintry Mix"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
    public var accessibilityDescription: String { description }
}

public enum PressureTrend: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
    case rising, falling, steady
    public var description: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    public var accessibilityDescription: String { description }
}

public enum WeatherSeverity: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
    case minor, moderate, severe, extreme, unknown
    public var description: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    public var accessibilityDescription: String { description }
}

public enum MoonPhase: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
    case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent
    public var description: String {
        switch self {
        case .new: return "New"
        case .waxingCrescent: return "Waxing Crescent"
        case .firstQuarter: return "First Quarter"
        case .waxingGibbous: return "Waxing Gibbous"
        case .full: return "Full"
        case .waningGibbous: return "Waning Gibbous"
        case .lastQuarter: return "Last Quarter"
        case .waningCrescent: return "Waning Crescent"
        }
    }
    public var accessibilityDescription: String { description + " Moon" }
    public var symbolName: String {
        switch self {
        case .new: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .full: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        }
    }
}

// MARK: - Measured values

public struct UVIndex: Codable, Equatable, Sendable {
    public enum ExposureCategory: String, CaseIterable, Codable, Comparable, Hashable, Sendable, CustomStringConvertible {
        case low, moderate, high, veryHigh, extreme
        public var rangeValue: ClosedRange<Int> {
            switch self {
            case .low: return 0...2
            case .moderate: return 3...5
            case .high: return 6...7
            case .veryHigh: return 8...10
            case .extreme: return 11...Int.max
            }
        }
        public var description: String { self == .veryHigh ? "Very High" : rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
        public var accessibilityDescription: String { description }
        public static func < (a: Self, b: Self) -> Bool { a.rangeValue.lowerBound < b.rangeValue.lowerBound }
    }
    public var value: Int
    public var category: ExposureCategory

    init(value: Int) {
        self.value = value
        category = ExposureCategory.allCases.first { $0.rangeValue.contains(value) } ?? .low
    }
}

public struct Wind: Codable, Equatable, Sendable {
    public enum CompassDirection: String, CaseIterable, Codable, Hashable, Sendable, CustomStringConvertible {
        case north, northNortheast, northeast, eastNortheast, east, eastSoutheast, southeast, southSoutheast
        case south, southSouthwest, southwest, westSouthwest, west, westNorthwest, northwest, northNorthwest

        public var abbreviation: String {
            switch self {
            case .north: return "N"
            case .northNortheast: return "NNE"
            case .northeast: return "NE"
            case .eastNortheast: return "ENE"
            case .east: return "E"
            case .eastSoutheast: return "ESE"
            case .southeast: return "SE"
            case .southSoutheast: return "SSE"
            case .south: return "S"
            case .southSouthwest: return "SSW"
            case .southwest: return "SW"
            case .westSouthwest: return "WSW"
            case .west: return "W"
            case .westNorthwest: return "WNW"
            case .northwest: return "NW"
            case .northNorthwest: return "NNW"
            }
        }
        public var description: String {
            switch self {
            case .north: return "North"
            case .northNortheast: return "North Northeast"
            case .northeast: return "Northeast"
            case .eastNortheast: return "East Northeast"
            case .east: return "East"
            case .eastSoutheast: return "East Southeast"
            case .southeast: return "Southeast"
            case .southSoutheast: return "South Southeast"
            case .south: return "South"
            case .southSouthwest: return "South Southwest"
            case .southwest: return "Southwest"
            case .westSouthwest: return "West Southwest"
            case .west: return "West"
            case .westNorthwest: return "West Northwest"
            case .northwest: return "Northwest"
            case .northNorthwest: return "North Northwest"
            }
        }
        public var accessibilityDescription: String { description }

        init(degrees: Double) {
            let i = Int(((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 22.5).rounded()) % 16
            self = Self.allCases[i]
        }
    }
    public var compassDirection: CompassDirection
    public var direction: Measurement<UnitAngle>
    public var speed: Measurement<UnitSpeed>
    public var gust: Measurement<UnitSpeed>?

    init(degrees: Double, kmh: Double, gustKmh: Double?) {
        compassDirection = CompassDirection(degrees: degrees)
        direction = Measurement(value: degrees, unit: .degrees)
        speed = Measurement(value: kmh, unit: .kilometersPerHour)
        gust = gustKmh.map { Measurement(value: $0, unit: .kilometersPerHour) }
    }
}

@available(iOS 18.0, *)
public struct CloudCoverByAltitude: Codable, Equatable, Sendable {
    public var low: Double
    public var medium: Double
    public var high: Double
}

public struct SnowfallAmount: Codable, Equatable, Sendable {
    public var amount: Measurement<UnitLength>
    public var amountLiquidEquivalent: Measurement<UnitLength>
    public var maximum: Measurement<UnitLength>
    public var maximumLiquidEquivalent: Measurement<UnitLength>
    public var minimum: Measurement<UnitLength>
    public var minimumLiquidEquivalent: Measurement<UnitLength>

    init(liquidMM: Double) {        // fresh snow: about 10 mm of snow per mm of water
        func mm(_ v: Double) -> Measurement<UnitLength> { Measurement(value: v, unit: .millimeters) }
        amount = mm(liquidMM * 10); amountLiquidEquivalent = mm(liquidMM)
        maximum = mm(liquidMM * 13); maximumLiquidEquivalent = mm(liquidMM * 1.3)
        minimum = mm(liquidMM * 7); minimumLiquidEquivalent = mm(liquidMM * 0.7)
    }
}

public struct PrecipitationAmountByType: Codable, Equatable, Sendable {
    public var precipitation: Measurement<UnitLength>
    public var rainfall: Measurement<UnitLength>
    public var snowfallAmount: SnowfallAmount
    public var sleet: Measurement<UnitLength>
    public var hail: Measurement<UnitLength>
    public var mixed: Measurement<UnitLength>

    init(type: Precipitation, mm total: Double) {
        func mm(_ v: Double) -> Measurement<UnitLength> { Measurement(value: v, unit: .millimeters) }
        precipitation = mm(total)
        rainfall = mm(type == .rain ? total : 0)
        snowfallAmount = SnowfallAmount(liquidMM: type == .snow ? total : 0)
        sleet = mm(type == .sleet ? total : 0)
        hail = mm(type == .hail ? total : 0)
        mixed = mm(type == .mixed ? total : 0)
    }
}

// MARK: - Weather

public struct CurrentWeather: Codable, Equatable, Sendable {
    public var date: Date
    public var metadata: WeatherMetadata
    public var condition: WeatherCondition
    public var symbolName: String
    public var isDaylight: Bool
    public var temperature: Measurement<UnitTemperature>
    public var apparentTemperature: Measurement<UnitTemperature>
    public var dewPoint: Measurement<UnitTemperature>
    public var humidity: Double
    public var pressure: Measurement<UnitPressure>
    public var pressureTrend: PressureTrend
    public var wind: Wind
    public var cloudCover: Double
    var _cloudCoverByAltitude: _CloudLayers
    @available(iOS 18.0, *)
    public var cloudCoverByAltitude: CloudCoverByAltitude { _cloudCoverByAltitude.value }
    public var precipitationIntensity: Measurement<UnitSpeed>
    public var uvIndex: UVIndex
    public var visibility: Measurement<UnitLength>
}

public struct MinuteWeather: Codable, Equatable, Sendable {
    public var date: Date
    public var precipitation: Precipitation
    public var precipitationChance: Double
    public var precipitationIntensity: Measurement<UnitSpeed>
}

public struct HourWeather: Codable, Equatable, Sendable {
    public var date: Date
    public var condition: WeatherCondition
    public var symbolName: String
    public var isDaylight: Bool
    public var temperature: Measurement<UnitTemperature>
    public var apparentTemperature: Measurement<UnitTemperature>
    public var dewPoint: Measurement<UnitTemperature>
    public var humidity: Double
    public var pressure: Measurement<UnitPressure>
    public var pressureTrend: PressureTrend
    public var wind: Wind
    public var cloudCover: Double
    var _cloudCoverByAltitude: _CloudLayers
    @available(iOS 18.0, *)
    public var cloudCoverByAltitude: CloudCoverByAltitude { _cloudCoverByAltitude.value }
    public var precipitation: Precipitation
    public var precipitationChance: Double
    public var precipitationAmount: Measurement<UnitLength>
    public var snowfallAmount: Measurement<UnitLength>
    public var uvIndex: UVIndex
    public var visibility: Measurement<UnitLength>
}

@available(iOS 18.0, *)
public struct DayPartForecast: Codable, Equatable, Sendable {
    public var condition: WeatherCondition
    public var cloudCover: Double
    public var cloudCoverByAltitude: CloudCoverByAltitude
    public var highTemperature: Measurement<UnitTemperature>
    public var lowTemperature: Measurement<UnitTemperature>
    public var highWindSpeed: Measurement<UnitSpeed>
    public var wind: Wind
    public var maximumHumidity: Double
    public var minimumHumidity: Double
    public var maximumVisibility: Measurement<UnitLength>
    public var minimumVisibility: Measurement<UnitLength>
    public var precipitation: Precipitation
    public var precipitationChance: Double
    public var precipitationAmountByType: PrecipitationAmountByType
}

public struct SunEvents: Codable, Equatable, Sendable {
    public var astronomicalDawn: Date?
    public var nauticalDawn: Date?
    public var civilDawn: Date?
    public var sunrise: Date?
    public var solarNoon: Date?
    public var sunset: Date?
    public var civilDusk: Date?
    public var nauticalDusk: Date?
    public var astronomicalDusk: Date?
    public var solarMidnight: Date?
}

public struct MoonEvents: Codable, Equatable, Sendable {
    public var phase: MoonPhase
    public var moonrise: Date?
    public var moonset: Date?
}

public struct DayWeather: Codable, Equatable, Sendable {
    public var date: Date
    public var condition: WeatherCondition
    public var symbolName: String
    public var highTemperature: Measurement<UnitTemperature>
    public var lowTemperature: Measurement<UnitTemperature>
    public var precipitation: Precipitation
    public var precipitationChance: Double
    public var precipitationAmountByType: PrecipitationAmountByType
    @available(iOS, introduced: 16.0, deprecated: 18.0, message: "Use precipitationAmountByType.rainfall")
    public var rainfallAmount: Measurement<UnitLength> { precipitationAmountByType.rainfall }
    @available(iOS, introduced: 16.0, deprecated: 18.0, message: "Use precipitationAmountByType.snowfallAmount.amount")
    public var snowfallAmount: Measurement<UnitLength> { precipitationAmountByType.snowfallAmount.amount }
    @available(iOS, introduced: 16.0, deprecated: 18.0, message: "Use precipitationAmountByType.precipitation")
    public var precipitationAmount: Measurement<UnitLength> { precipitationAmountByType.precipitation }
    public var wind: Wind
    public var uvIndex: UVIndex
    public var sun: SunEvents
    public var moon: MoonEvents
    var _parts: _DayParts
    @available(iOS 18.0, *)
    public var highTemperatureTime: Date? { _parts.highTime }
    @available(iOS 18.0, *)
    public var lowTemperatureTime: Date? { _parts.lowTime }
    @available(iOS 18.0, *)
    public var highWindSpeed: Measurement<UnitSpeed>? { _parts.highWind }
    @available(iOS 18.0, *)
    public var maximumHumidity: Double { _parts.maxHumidity }
    @available(iOS 18.0, *)
    public var minimumHumidity: Double { _parts.minHumidity }
    @available(iOS 18.0, *)
    public var maximumVisibility: Double { _parts.maxVisibility }
    @available(iOS 18.0, *)
    public var minimumVisibility: Double { _parts.minVisibility }
    @available(iOS 18.0, *)
    public var daytimeForecast: DayPartForecast { _parts.daytime.value }
    @available(iOS 18.0, *)
    public var overnightForecast: DayPartForecast { _parts.overnight.value }
    @available(iOS 18.0, *)
    public var restOfDayForecast: DayPartForecast? { _parts.restOfDay?.value }
}

public struct WeatherAlert: Codable, Equatable, Sendable {
    public var metadata: WeatherMetadata
    public var summary: String
    public var region: String?
    public var severity: WeatherSeverity
    public var source: String
    public var detailsURL: URL
}

public struct Forecast<Element>: RandomAccessCollection {
    public typealias Index = Int
    public var forecast: [Element]
    public var metadata: WeatherMetadata
    public var summary: String { _summary ?? "" }
    var _summary: String?

    init(_ forecast: [Element], metadata: WeatherMetadata, summary: String? = nil) {
        self.forecast = forecast; self.metadata = metadata; _summary = summary
    }
    public var startIndex: Int { forecast.startIndex }
    public var endIndex: Int { forecast.endIndex }
    public subscript(position: Int) -> Element { forecast[position] }
}

extension Forecast: Sendable where Element: Sendable {}
extension Forecast: Equatable where Element: Equatable {
    public static func == (a: Forecast, b: Forecast) -> Bool { a.forecast == b.forecast && a.metadata == b.metadata && a._summary == b._summary }
}
extension Forecast: Codable where Element: Codable {
    enum CodingKeys: String, CodingKey { case forecast, metadata, summary }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        forecast = try c.decode([Element].self, forKey: .forecast)
        metadata = try c.decode(WeatherMetadata.self, forKey: .metadata)
        _summary = try c.decodeIfPresent(String.self, forKey: .summary)
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(forecast, forKey: .forecast)
        try c.encode(metadata, forKey: .metadata)
        try c.encodeIfPresent(_summary, forKey: .summary)
    }
}

public struct Weather: Codable, Equatable, Sendable {
    public var currentWeather: CurrentWeather
    public var minuteForecast: Forecast<MinuteWeather>?
    public var hourlyForecast: Forecast<HourWeather>
    public var dailyForecast: Forecast<DayWeather>
    public var weatherAlerts: [WeatherAlert]?
    public var availability: WeatherAvailability
}

// MARK: - storage of the iOS 18 values, which older types cannot name directly

struct _CloudLayers: Codable, Equatable, Sendable {
    var low: Double, medium: Double, high: Double
    @available(iOS 18.0, *)
    var value: CloudCoverByAltitude { CloudCoverByAltitude(low: low, medium: medium, high: high) }
}

struct _DayPart: Codable, Equatable, Sendable {
    var condition: WeatherCondition
    var cloudCover: Double
    var clouds: _CloudLayers
    var high: Double, low: Double                      // °C
    var highWind: Double                               // km/h
    var wind: Wind
    var maxHumidity: Double, minHumidity: Double
    var maxVisibility: Double, minVisibility: Double   // m
    var chance: Double
    var amount: PrecipitationAmountByType

    @available(iOS 18.0, *)
    var value: DayPartForecast {
        DayPartForecast(condition: condition, cloudCover: cloudCover, cloudCoverByAltitude: clouds.value,
                        highTemperature: Measurement(value: high, unit: .celsius), lowTemperature: Measurement(value: low, unit: .celsius),
                        highWindSpeed: Measurement(value: highWind, unit: .kilometersPerHour), wind: wind,
                        maximumHumidity: maxHumidity, minimumHumidity: minHumidity,
                        maximumVisibility: Measurement(value: maxVisibility, unit: .meters),
                        minimumVisibility: Measurement(value: minVisibility, unit: .meters),
                        precipitation: condition.precipitates ? condition.precipitation : .none, precipitationChance: chance,
                        precipitationAmountByType: amount)
    }
}

struct _DayParts: Codable, Equatable, Sendable {
    var highTime: Date?, lowTime: Date?
    var highWind: Measurement<UnitSpeed>?
    var maxHumidity: Double, minHumidity: Double
    var maxVisibility: Double, minVisibility: Double
    var daytime: _DayPart, overnight: _DayPart, restOfDay: _DayPart?
}

extension UnitSpeed {
    // precipitation intensity, as WeatherKit reports it
    static let _millimetersPerHour = UnitSpeed(symbol: "mm/h", converter: UnitConverterLinear(coefficient: 0.001 / 3600))
}
