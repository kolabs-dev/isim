// isim WeatherKit (issue #415): climate statistics, past-day summaries, forecast changes and comparisons with the
// climate (iOS 18). They come from the same simulation: its climate (the mean of each day of the year, without the
// day's anomaly) is the statistics' baseline, and its past days are the summaries. Days of the year count from 1,
// months from 1, hours of the year from 0.
import Foundation
import CoreLocation

// MARK: - collections

@available(iOS 18.0, *)
public struct DailyWeatherStatistics<T>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = T
    public var days: [T]
    public var baselineStartDate: Date
    public var metadata: WeatherMetadata
    public var startIndex: Int { days.startIndex }
    public var endIndex: Int { days.endIndex }
    public subscript(position: Int) -> T { days[position] }
}

@available(iOS 18.0, *)
public struct HourlyWeatherStatistics<T>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = T
    public var hours: [T]
    public var baselineStartDate: Date
    public var metadata: WeatherMetadata
    public var startIndex: Int { hours.startIndex }
    public var endIndex: Int { hours.endIndex }
    public subscript(position: Int) -> T { hours[position] }
}

@available(iOS 18.0, *)
public struct MonthlyWeatherStatistics<T>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = T
    public var months: [T]
    public var baselineStartDate: Date
    public var metadata: WeatherMetadata
    public var startIndex: Int { months.startIndex }
    public var endIndex: Int { months.endIndex }
    public subscript(position: Int) -> T { months[position] }
}

@available(iOS 18.0, *)
public struct DailyWeatherSummary<T>: RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = T
    public var days: [T]
    public var metadata: WeatherMetadata
    public var startIndex: Int { days.startIndex }
    public var endIndex: Int { days.endIndex }
    public subscript(position: Int) -> T { days[position] }
}

@available(iOS 18.0, *)
extension DailyWeatherStatistics: Sendable where T: Sendable {}
@available(iOS 18.0, *)
extension HourlyWeatherStatistics: Sendable where T: Sendable {}
@available(iOS 18.0, *)
extension MonthlyWeatherStatistics: Sendable where T: Sendable {}
@available(iOS 18.0, *)
extension DailyWeatherSummary: Sendable where T: Sendable {}

// MARK: - values

@available(iOS 18.0, *)
public struct Percentiles<Dimension: Foundation.Dimension>: Sendable {
    public var p10: Measurement<Dimension>
    public var p50: Measurement<Dimension>
    public var p90: Measurement<Dimension>
}

@available(iOS 18.0, *)
public struct DayTemperatureStatistics: Codable, Equatable, Sendable {
    public var day: Int
    public var averageHighTemperature: Measurement<UnitTemperature>
    public var averageLowTemperature: Measurement<UnitTemperature>
}

@available(iOS 18.0, *)
public struct DayPrecipitationStatistics: Codable, Equatable, Sendable {
    public var day: Int
    public var averagePrecipitationAmount: Measurement<UnitLength>
    public var averagePrecipitationProbability: Double
    public var averageSnowfallAmount: Measurement<UnitLength>
}

@available(iOS 18.0, *)
public struct HourTemperatureStatistics: Sendable {
    public var hour: Int
    public var percentiles: Percentiles<UnitTemperature>
}

@available(iOS 18.0, *)
public struct MonthTemperatureStatistics: Codable, Equatable, Sendable {
    public var month: Int
    public var averageHighTemperature: Measurement<UnitTemperature>
    public var averageLowTemperature: Measurement<UnitTemperature>
}

@available(iOS 18.0, *)
public struct MonthPrecipitationStatistics: Codable, Equatable, Sendable {
    public var month: Int
    public var averagePrecipitationAmount: Measurement<UnitLength>
    public var averagePrecipitationProbability: Double
    public var averageSnowfallAmount: Measurement<UnitLength>
}

@available(iOS 18.0, *)
public struct DayTemperatureSummary: Codable, Equatable, Sendable {
    public var date: Date
    public var highTemperature: Measurement<UnitTemperature>
    public var lowTemperature: Measurement<UnitTemperature>
}

@available(iOS 18.0, *)
public struct DayPrecipitationSummary: Codable, Equatable, Sendable {
    public var date: Date
    public var precipitationAmount: Measurement<UnitLength>
    public var snowfallAmount: Measurement<UnitLength>
}

// MARK: - queries

@available(iOS 18.0, *)
public struct DailyWeatherStatisticsQuery<T> {
    let make: (_WeatherSim, Int) -> T
}
@available(iOS 18.0, *)
extension DailyWeatherStatisticsQuery where T == DayTemperatureStatistics {
    public static var temperature: DailyWeatherStatisticsQuery<DayTemperatureStatistics> { .init { $0.temperatureStatistics(day: $1) } }
}
@available(iOS 18.0, *)
extension DailyWeatherStatisticsQuery where T == DayPrecipitationStatistics {
    public static var precipitation: DailyWeatherStatisticsQuery<DayPrecipitationStatistics> { .init { $0.precipitationStatistics(day: $1) } }
}

@available(iOS 18.0, *)
public struct HourlyWeatherStatisticsQuery<T> {
    let make: (_WeatherSim, Int) -> T
}
@available(iOS 18.0, *)
extension HourlyWeatherStatisticsQuery where T == HourTemperatureStatistics {
    public static var temperature: HourlyWeatherStatisticsQuery<HourTemperatureStatistics> { .init { $0.temperatureStatistics(hour: $1) } }
}

@available(iOS 18.0, *)
public struct MonthlyWeatherStatisticsQuery<T> {
    let make: (_WeatherSim, Int) -> T
}
@available(iOS 18.0, *)
extension MonthlyWeatherStatisticsQuery where T == MonthTemperatureStatistics {
    public static var temperature: MonthlyWeatherStatisticsQuery<MonthTemperatureStatistics> { .init { $0.temperatureStatistics(month: $1) } }
}
@available(iOS 18.0, *)
extension MonthlyWeatherStatisticsQuery where T == MonthPrecipitationStatistics {
    public static var precipitation: MonthlyWeatherStatisticsQuery<MonthPrecipitationStatistics> { .init { $0.precipitationStatistics(month: $1) } }
}

@available(iOS 18.0, *)
public struct DailyWeatherSummaryQuery<T> {
    let make: (_WeatherSim, Int64) -> T
}
@available(iOS 18.0, *)
extension DailyWeatherSummaryQuery where T == DayTemperatureSummary {
    public static var temperature: DailyWeatherSummaryQuery<DayTemperatureSummary> { .init { $0.temperatureSummary(day: $1) } }
}
@available(iOS 18.0, *)
extension DailyWeatherSummaryQuery where T == DayPrecipitationSummary {
    public static var precipitation: DailyWeatherSummaryQuery<DayPrecipitationSummary> { .init { $0.precipitationSummary(day: $1) } }
}

// MARK: - changes and comparisons

@available(iOS 18.0, *)
public struct WeatherChange: Codable, Equatable, Sendable {
    public enum Direction: String, Codable, Hashable, Sendable {
        case increase, decrease, steady
    }
    public var date: Date
    public var highTemperature: Direction
    public var lowTemperature: Direction
    public var dayPrecipitationAmount: Direction
    public var nightPrecipitationAmount: Direction
}

@available(iOS 18.0, *)
public struct WeatherChanges: RandomAccessCollection, Sendable {
    public typealias Index = Int
    public typealias Element = WeatherChange
    public var changes: [WeatherChange]
    public var metadata: WeatherMetadata
    public var startIndex: Int { changes.startIndex }
    public var endIndex: Int { changes.endIndex }
    public subscript(position: Int) -> WeatherChange { changes[position] }
}

@available(iOS 18.0, *)
public enum Deviation: String, Codable, Hashable, Sendable {
    case muchHigher, higher, normal, lower, muchLower
}

@available(iOS 18.0, *)
public struct TrendBaseline<Dimension: Foundation.Dimension>: Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case mean
    }
    public let kind: Kind
    public let value: Measurement<Dimension>
    public let startDate: Date
}

@available(iOS 18.0, *)
public struct Trend<Dimension: Foundation.Dimension>: Sendable {
    public var baseline: TrendBaseline<Dimension>
    public var currentValue: Measurement<Dimension>
    public var deviation: Deviation
}

@available(iOS 18.0, *)
public enum HistoricalComparison: Sendable {
    case highTemperature(Trend<UnitTemperature>)
    case lowTemperature(Trend<UnitTemperature>)
    case precipitationAmount(Trend<UnitLength>)
    case snowfallAmount(Trend<UnitLength>)
}

@available(iOS 18.0, *)
public struct HistoricalComparisons: RandomAccessCollection, Sendable {
    public typealias Index = Int
    public typealias Element = HistoricalComparison
    public var comparisons: [HistoricalComparison]
    public var metadata: WeatherMetadata
    public var startIndex: Int { comparisons.startIndex }
    public var endIndex: Int { comparisons.endIndex }
    public subscript(position: Int) -> HistoricalComparison { comparisons[position] }
}

// MARK: - WeatherService

@available(iOS 18.0, *)
extension WeatherService {
    public func dailyStatistics<each T>(for location: CLLocation, including query: repeat DailyWeatherStatisticsQuery<each T>)
        async throws -> (repeat DailyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let first = sim.dayOfYear(sim.dayIndex(sim.now))
        return (repeat sim.dailyStatistics(days: (0..<10).map { (first - 1 + $0) % 366 + 1 }, each query))
    }

    public func dailyStatistics<each T>(for location: CLLocation, startDay: Int, endDay: Int,
                                        including query: repeat DailyWeatherStatisticsQuery<each T>) async throws -> (repeat DailyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let days = startDay <= endDay ? Array(startDay...endDay) : Array(startDay...366) + Array(1...max(1, endDay))
        return (repeat sim.dailyStatistics(days: days, each query))
    }

    public func dailyStatistics<each T>(for location: CLLocation, forDaysIn interval: DateInterval,
                                        including query: repeat DailyWeatherStatisticsQuery<each T>) async throws -> (repeat DailyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let days = sim.days(in: interval).map(sim.dayOfYear)
        return (repeat sim.dailyStatistics(days: days, each query))
    }

    public func hourlyStatistics<each T>(for location: CLLocation, including query: repeat HourlyWeatherStatisticsQuery<each T>)
        async throws -> (repeat HourlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let first = sim.hourOfYear(sim.now)
        return (repeat sim.hourlyStatistics(hours: (0..<24).map { (first + $0) % 8784 }, each query))
    }

    public func hourlyStatistics<each T>(for location: CLLocation, startHour: Int, endHour: Int,
                                         including query: repeat HourlyWeatherStatisticsQuery<each T>) async throws -> (repeat HourlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let hours = startHour <= endHour ? Array(startHour...endHour) : Array(startHour..<8784) + Array(0...max(0, endHour))
        return (repeat sim.hourlyStatistics(hours: hours, each query))
    }

    public func hourlyStatistics<each T>(for location: CLLocation, forHoursIn interval: DateInterval,
                                         including query: repeat HourlyWeatherStatisticsQuery<each T>) async throws -> (repeat HourlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        var hours: [Int] = []
        var t = sim.hourStart(interval.start)
        while t < interval.end { hours.append(sim.hourOfYear(t)); t.addTimeInterval(3600) }
        return (repeat sim.hourlyStatistics(hours: hours, each query))
    }

    public func monthlyStatistics<each T>(for location: CLLocation, including query: repeat MonthlyWeatherStatisticsQuery<each T>)
        async throws -> (repeat MonthlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        return (repeat sim.monthlyStatistics(months: Array(1...12), each query))
    }

    public func monthlyStatistics<each T>(for location: CLLocation, startMonth: Int, endMonth: Int,
                                          including query: repeat MonthlyWeatherStatisticsQuery<each T>) async throws -> (repeat MonthlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        let months = startMonth <= endMonth ? Array(startMonth...endMonth) : Array(startMonth...12) + Array(1...max(1, endMonth))
        return (repeat sim.monthlyStatistics(months: months, each query))
    }

    public func monthlyStatistics<each T>(for location: CLLocation, forMonthsIn interval: DateInterval,
                                          including query: repeat MonthlyWeatherStatisticsQuery<each T>) async throws -> (repeat MonthlyWeatherStatistics<each T>) {
        let sim = try _WeatherService.sim(location)
        var months: [Int] = []
        for d in sim.days(in: interval) {
            let m = sim.calendar.component(.month, from: sim.dayStart(d).addingTimeInterval(43200))
            if months.last != m { months.append(m) }
        }
        return (repeat sim.monthlyStatistics(months: months, each query))
    }

    public func dailySummary<each T>(for location: CLLocation, including query: repeat DailyWeatherSummaryQuery<each T>)
        async throws -> (repeat DailyWeatherSummary<each T>) {
        let sim = try _WeatherService.sim(location)
        let today = sim.dayIndex(sim.now)
        return (repeat sim.dailySummary(days: Array((today - 30)..<today), each query))     // the past 30 days
    }

    public func dailySummary<each T>(for location: CLLocation, forDaysIn interval: DateInterval,
                                     including query: repeat DailyWeatherSummaryQuery<each T>) async throws -> (repeat DailyWeatherSummary<each T>) {
        let sim = try _WeatherService.sim(location)
        return (repeat sim.dailySummary(days: sim.days(in: interval), each query))
    }
}

// MARK: - the simulation's climate

@available(iOS 18.0, *)
extension _WeatherSim {
    static let baselineStart = Date(timeIntervalSince1970: 662_688_000)       // 1 January 1991: the 1991–2020 normals

    func days(in interval: DateInterval) -> [Int64] {
        let first = dayIndex(interval.start), last = dayIndex(interval.end.addingTimeInterval(-1))
        return first > last ? [] : Array(first...last)
    }
    func hourOfYear(_ t: Date) -> Int {
        let d = dayIndex(t)
        return (dayOfYear(d) - 1) * 24 + Int(t.timeIntervalSince(dayStart(d)) / 3600)
    }
    func climateRain(doy: Int) -> (chance: Double, mm: Double) {
        // wetter in the cold half of the year at mid-latitudes, the warm half in the tropics
        let peak = (abs(lat) < 23 ? 200.0 : 17.0) + (lat < 0 ? 182 : 0)
        let chance = 0.28 + 0.12 * cos(2 * .pi * (Double(doy) - peak) / 365.25)
        return (chance, chance * 6)
    }

    func temperatureStatistics(day: Int) -> DayTemperatureStatistics {
        let m = climateMean(doy: day), r = climateRange()
        return DayTemperatureStatistics(day: day, averageHighTemperature: Measurement(value: m + r / 2, unit: .celsius),
                                        averageLowTemperature: Measurement(value: m - r / 2, unit: .celsius))
    }
    func precipitationStatistics(day: Int) -> DayPrecipitationStatistics {
        let rain = climateRain(doy: day), cold = climateMean(doy: day) < 0
        return DayPrecipitationStatistics(day: day, averagePrecipitationAmount: Measurement(value: rain.mm, unit: .millimeters),
                                          averagePrecipitationProbability: rain.chance,
                                          averageSnowfallAmount: Measurement(value: cold ? rain.mm * 10 : 0, unit: .millimeters))
    }
    func temperatureStatistics(hour: Int) -> HourTemperatureStatistics {
        let doy = hour / 24 + 1, solar = Double(hour % 24)
        let p50 = climateMean(doy: doy) + climateRange() / 2 * cos(2 * .pi * (solar - 15) / 24)
        return HourTemperatureStatistics(hour: hour, percentiles: Percentiles(p10: Measurement(value: p50 - 4.5, unit: .celsius),
                                                                              p50: Measurement(value: p50, unit: .celsius),
                                                                              p90: Measurement(value: p50 + 4.5, unit: .celsius)))
    }
    func monthDays(_ month: Int) -> ClosedRange<Int> {
        let starts = [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366]
        return starts[month - 1]...(starts[month] - 1)
    }
    func temperatureStatistics(month: Int) -> MonthTemperatureStatistics {
        let days = monthDays(month), r = climateRange()
        let m = days.map { climateMean(doy: $0) }.reduce(0, +) / Double(days.count)
        return MonthTemperatureStatistics(month: month, averageHighTemperature: Measurement(value: m + r / 2, unit: .celsius),
                                          averageLowTemperature: Measurement(value: m - r / 2, unit: .celsius))
    }
    func precipitationStatistics(month: Int) -> MonthPrecipitationStatistics {
        let days = monthDays(month).map(precipitationStatistics(day:))
        return MonthPrecipitationStatistics(month: month,
                                            averagePrecipitationAmount: Measurement(value: days.map { $0.averagePrecipitationAmount.value }.reduce(0, +), unit: .millimeters),
                                            averagePrecipitationProbability: days.map(\.averagePrecipitationProbability).reduce(0, +) / Double(days.count),
                                            averageSnowfallAmount: Measurement(value: days.map { $0.averageSnowfallAmount.value }.reduce(0, +), unit: .millimeters))
    }
    func temperatureSummary(day: Int64) -> DayTemperatureSummary {
        let w = dayWeather(day)
        return DayTemperatureSummary(date: w.date, highTemperature: w.highTemperature, lowTemperature: w.lowTemperature)
    }
    func precipitationSummary(day: Int64) -> DayPrecipitationSummary {
        let w = dayWeather(day)
        return DayPrecipitationSummary(date: w.date, precipitationAmount: w.precipitationAmountByType.precipitation,
                                       snowfallAmount: w.precipitationAmountByType.snowfallAmount.amount)
    }

    func dailyStatistics<T>(days: [Int], _ q: DailyWeatherStatisticsQuery<T>) -> DailyWeatherStatistics<T> {
        DailyWeatherStatistics(days: days.map { q.make(self, $0) }, baselineStartDate: Self.baselineStart, metadata: metadata)
    }
    func hourlyStatistics<T>(hours: [Int], _ q: HourlyWeatherStatisticsQuery<T>) -> HourlyWeatherStatistics<T> {
        HourlyWeatherStatistics(hours: hours.map { q.make(self, $0) }, baselineStartDate: Self.baselineStart, metadata: metadata)
    }
    func monthlyStatistics<T>(months: [Int], _ q: MonthlyWeatherStatisticsQuery<T>) -> MonthlyWeatherStatistics<T> {
        MonthlyWeatherStatistics(months: months.map { q.make(self, $0) }, baselineStartDate: Self.baselineStart, metadata: metadata)
    }
    func dailySummary<T>(days: [Int64], _ q: DailyWeatherSummaryQuery<T>) -> DailyWeatherSummary<T> {
        DailyWeatherSummary(days: days.map { q.make(self, $0) }, metadata: metadata)
    }

    // how each of the next nine days differs from the day before it
    func changes() -> WeatherChanges {
        let today = dayIndex(now)
        let days = (today...(today + 9)).map(dayWeather)
        func dir(_ a: Double, _ b: Double, _ threshold: Double) -> WeatherChange.Direction {
            b - a > threshold ? .increase : a - b > threshold ? .decrease : .steady
        }
        let changes = zip(days, days.dropFirst()).map { a, b in
            WeatherChange(date: b.date, highTemperature: dir(a.highTemperature.value, b.highTemperature.value, 2),
                          lowTemperature: dir(a.lowTemperature.value, b.lowTemperature.value, 2),
                          dayPrecipitationAmount: dir(a._parts.daytime.amount.precipitation.value, b._parts.daytime.amount.precipitation.value, 1),
                          nightPrecipitationAmount: dir(a._parts.overnight.amount.precipitation.value, b._parts.overnight.amount.precipitation.value, 1))
        }
        return WeatherChanges(changes: changes, metadata: metadata)
    }

    // today against the climate of the day
    func historicalComparisons() -> HistoricalComparisons {
        let today = dayIndex(now), w = dayWeather(today), doy = dayOfYear(today)
        let normal = temperatureStatistics(day: doy), rain = precipitationStatistics(day: doy)
        func deviation(_ v: Double, _ mean: Double, _ step: Double) -> Deviation {
            let d = v - mean
            return d > 2 * step ? .muchHigher : d > step ? .higher : d < -2 * step ? .muchLower : d < -step ? .lower : .normal
        }
        func trend<D: Dimension>(_ value: Measurement<D>, _ mean: Measurement<D>, _ step: Double) -> Trend<D> {
            Trend(baseline: TrendBaseline(kind: .mean, value: mean, startDate: Self.baselineStart), currentValue: value,
                  deviation: deviation(value.value, mean.value, step))
        }
        return HistoricalComparisons(comparisons: [
            .highTemperature(trend(w.highTemperature, normal.averageHighTemperature, 2.5)),
            .lowTemperature(trend(w.lowTemperature, normal.averageLowTemperature, 2.5)),
            .precipitationAmount(trend(w.precipitationAmountByType.precipitation, rain.averagePrecipitationAmount, 3)),
            .snowfallAmount(trend(w.precipitationAmountByType.snowfallAmount.amount, rain.averageSnowfallAmount, 10)),
        ], metadata: metadata)
    }
}
