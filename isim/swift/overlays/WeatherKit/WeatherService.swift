// isim WeatherKit (issue #415): WeatherService and its queries. Every request is answered by isim's simulated
// forecast (Simulation.swift), labelled as such in `attribution`; Apple's Weather service is never called. Like
// Apple's, requests need the com.apple.developer.weatherkit entitlement (else WeatherError.permissionDenied).
import Foundation
import CoreLocation
import UIKit

enum _WeatherService {
    static let docsURL = URL(string: "https://github.com/kolabs-dev/isim/blob/main/docs/frameworks/WeatherKit.md")!

    static var entitled: Bool {
        let xcent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return ((NSDictionary(contentsOfFile: xcent) as? [String: Any])?["com.apple.developer.weatherkit"] as? Bool) == true
    }

    static func sim(_ location: CLLocation) throws -> _WeatherSim {
        guard entitled else {
            NSLog("isim WeatherKit: the app does not have the com.apple.developer.weatherkit entitlement")
            throw WeatherError.permissionDenied
        }
        let overrides = _WeatherOverrides.parse(ProcessInfo.processInfo.environment["ISIM_WEATHER"])
        if overrides.unavailable {
            NSLog("isim WeatherKit: the weather service is unavailable (ISIM_WEATHER)")
            throw WeatherError.unknown
        }
        return _WeatherSim(location: location, overrides: overrides)
    }

    // the attribution marks: isim's own, never Apple's (written once per launch to the app's caches)
    static func marks() throws -> (light: URL, dark: URL, square: URL) {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("isim-weatherkit")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let light = dir.appendingPathComponent("combined-mark-light.png"), dark = dir.appendingPathComponent("combined-mark-dark.png")
        let square = dir.appendingPathComponent("square-mark.png")
        if !FileManager.default.fileExists(atPath: square.path) {
            try combinedMark(color: .black).write(to: light)
            try combinedMark(color: .white).write(to: dark)
            try squareMark().write(to: square)
        }
        return (light, dark, square)
    }

    static func combinedMark(color: UIColor) -> Data {
        let size = CGSize(width: 330, height: 60)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { _ in
            let text = NSAttributedString(string: "isim Simulated Weather", attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold), .foregroundColor: color])
            let r = text.boundingRect(with: size, options: [.usesLineFragmentOrigin], context: nil)
            text.draw(at: CGPoint(x: (size.width - r.width) / 2, y: (size.height - r.height) / 2))
        }
    }

    static func squareMark() -> Data {
        let size = CGSize(width: 120, height: 120)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { ctx in
            UIColor(red: 0.16, green: 0.47, blue: 0.95, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 26).fill()
            let text = NSAttributedString(string: "isim", attributes: [.font: UIFont.systemFont(ofSize: 38, weight: .bold),
                                                                       .foregroundColor: UIColor.white])
            let r = text.boundingRect(with: size, options: [.usesLineFragmentOrigin], context: nil)
            text.draw(at: CGPoint(x: (size.width - r.width) / 2, y: (size.height - r.height) / 2))
        }
    }
}

public final class WeatherService: Sendable {
    public static let shared = WeatherService(_shared: ())

    private init(_shared: Void) {}
    public convenience init() { self.init(_shared: ()) }

    public var attribution: WeatherAttribution {
        get async throws {
            let marks = try _WeatherService.marks()
            return WeatherAttribution(serviceName: "isim Simulated Weather", legalPageURL: _WeatherService.docsURL,
                                      legalAttributionText: "Weather data is simulated by isim for development. It is not a forecast, and not Apple Weather data.",
                                      combinedMarkLightURL: marks.light, combinedMarkDarkURL: marks.dark, squareMarkURL: marks.square)
        }
    }

    public func weather(for location: CLLocation) async throws -> Weather {
        try _WeatherService.sim(location).weather()
    }

    public func weather<T>(for location: CLLocation, including dataSet: WeatherQuery<T>) async throws -> T {
        try dataSet.make(try _WeatherService.sim(location))
    }

    public func weather<each T>(for location: CLLocation, including dataSet: repeat WeatherQuery<each T>) async throws -> (repeat each T) {
        let sim = try _WeatherService.sim(location)
        return (repeat try (each dataSet).make(sim))
    }

    public func weather<T1, T2>(for location: CLLocation, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>) async throws -> (T1, T2) {
        let sim = try _WeatherService.sim(location)
        return (try dataSet1.make(sim), try dataSet2.make(sim))
    }

    public func weather<T1, T2, T3>(for location: CLLocation, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>,
                                    _ dataSet3: WeatherQuery<T3>) async throws -> (T1, T2, T3) {
        let sim = try _WeatherService.sim(location)
        return (try dataSet1.make(sim), try dataSet2.make(sim), try dataSet3.make(sim))
    }

    public func weather<T1, T2, T3, T4>(for location: CLLocation, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>,
                                        _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>) async throws -> (T1, T2, T3, T4) {
        let sim = try _WeatherService.sim(location)
        return (try dataSet1.make(sim), try dataSet2.make(sim), try dataSet3.make(sim), try dataSet4.make(sim))
    }

    public func weather<T1, T2, T3, T4, T5>(for location: CLLocation, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>,
                                            _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>,
                                            _ dataSet5: WeatherQuery<T5>) async throws -> (T1, T2, T3, T4, T5) {
        let sim = try _WeatherService.sim(location)
        return (try dataSet1.make(sim), try dataSet2.make(sim), try dataSet3.make(sim), try dataSet4.make(sim), try dataSet5.make(sim))
    }

    public func weather<T1, T2, T3, T4, T5, T6>(for location: CLLocation, including dataSet1: WeatherQuery<T1>, _ dataSet2: WeatherQuery<T2>,
                                                _ dataSet3: WeatherQuery<T3>, _ dataSet4: WeatherQuery<T4>, _ dataSet5: WeatherQuery<T5>,
                                                _ dataSet6: WeatherQuery<T6>) async throws -> (T1, T2, T3, T4, T5, T6) {
        let sim = try _WeatherService.sim(location)
        return (try dataSet1.make(sim), try dataSet2.make(sim), try dataSet3.make(sim), try dataSet4.make(sim), try dataSet5.make(sim),
                try dataSet6.make(sim))
    }
}

public struct WeatherQuery<T> {
    let make: (_WeatherSim) throws -> T
}

extension WeatherQuery where T == CurrentWeather {
    public static var current: WeatherQuery<CurrentWeather> { WeatherQuery { $0.currentWeather() } }
}
extension WeatherQuery where T == Forecast<MinuteWeather>? {
    public static var minute: WeatherQuery<Forecast<MinuteWeather>?> { WeatherQuery { $0.minute() } }
}
extension WeatherQuery where T == Forecast<HourWeather> {
    public static var hourly: WeatherQuery<Forecast<HourWeather>> { WeatherQuery { $0.hourly() } }
    public static func hourly(startDate: Date, endDate: Date) -> WeatherQuery<T> { WeatherQuery { $0.hourly(from: startDate, to: endDate) } }
}
extension WeatherQuery where T == Forecast<DayWeather> {
    public static var daily: WeatherQuery<Forecast<DayWeather>> { WeatherQuery { $0.daily() } }
    public static func daily(startDate: Date, endDate: Date) -> WeatherQuery<T> { WeatherQuery { $0.daily(from: startDate, to: endDate) } }
}
extension WeatherQuery where T == [WeatherAlert]? {
    public static var alerts: WeatherQuery<[WeatherAlert]?> { WeatherQuery { $0.alerts() } }
}
extension WeatherQuery where T == WeatherAvailability {
    public static var availability: WeatherQuery<WeatherAvailability> { WeatherQuery { $0.availability } }
}
@available(iOS 18.0, *)
extension WeatherQuery where T == WeatherChanges? {
    public static var changes: WeatherQuery<WeatherChanges?> { WeatherQuery { $0.changes() } }
}
@available(iOS 18.0, *)
extension WeatherQuery where T == HistoricalComparisons? {
    public static var historicalComparisons: WeatherQuery<HistoricalComparisons?> { WeatherQuery { $0.historicalComparisons() } }
}
