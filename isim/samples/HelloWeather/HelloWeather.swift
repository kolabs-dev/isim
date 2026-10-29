// Sample: WeatherKit on isim (issue #415). A weather screen for a city (launch argument `-city cupertino|london|
// sydney|tromso`): the current conditions, the next hours, ten days with their sun and moon, the next hour's
// precipitation where WeatherKit has it, alerts, and the attribution with its mark. The forecast is isim's simulation
// (ISIM_WEATHER overrides it); everything is printed, and tests/ui/test_weather.py checks it.
import SwiftUI
import CoreLocation
import WeatherKit

@main
struct HelloWeatherApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

let cities: [String: (String, CLLocation)] = [
    "cupertino": ("Cupertino", CLLocation(latitude: 37.3349, longitude: -122.0090)),
    "london": ("London", CLLocation(latitude: 51.5072, longitude: -0.1276)),
    "sydney": ("Sydney", CLLocation(latitude: -33.8688, longitude: 151.2093)),
    "tromso": ("Tromsø", CLLocation(latitude: 69.6492, longitude: 18.9553)),
]

func say(_ s: String) { print("weather: \(s)") }

func deg(_ m: Measurement<UnitTemperature>) -> String { "\(Int(m.converted(to: .celsius).value.rounded()))°" }

struct ContentView: View {
    @State private var weather: Weather?
    @State private var attribution: WeatherAttribution?
    @State private var error: String?
    let city: (String, CLLocation) = {
        let args = ProcessInfo.processInfo.arguments
        let key = args.firstIndex(of: "-city").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } ?? "cupertino"
        return cities[key] ?? cities["cupertino"]!
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let w = weather {
                    header(w)
                    hours(w)
                    days(w)
                    if let a = attribution { footer(a) }
                } else if let error {
                    Text(error).accessibilityIdentifier("error").padding(.top, 80)
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
            .padding()
        }
        .background(LinearGradient(colors: [Color(red: 0.25, green: 0.5, blue: 0.85), Color(red: 0.45, green: 0.7, blue: 0.95)],
                                   startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .foregroundStyle(.white)
        .task { await load() }
    }

    func header(_ w: Weather) -> some View {
        let today = w.dailyForecast.first
        return VStack(spacing: 4) {
            Text(city.0).font(.largeTitle)
            Text(deg(w.currentWeather.temperature)).font(.system(size: 80, weight: .thin)).accessibilityIdentifier("temperature")
            Text(w.currentWeather.condition.description).font(.title3).accessibilityIdentifier("condition")
            if let t = today { Text("H:\(deg(t.highTemperature))  L:\(deg(t.lowTemperature))").font(.headline) }
            if let alert = w.weatherAlerts?.first {
                Label(alert.summary, systemImage: "exclamationmark.triangle").font(.subheadline).padding(8)
                    .background(.red.opacity(0.6), in: RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("alert")
            }
            if let m = w.minuteForecast { Text(m.summary).font(.footnote).accessibilityIdentifier("minute") }
        }
    }

    func hours(_ w: Weather) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(Array(w.hourlyForecast.prefix(12).enumerated()), id: \.offset) { i, h in
                    VStack(spacing: 8) {
                        Text(i == 0 ? "Now" : h.date.formatted(.dateTime.hour())).font(.footnote)
                        Image(systemName: h.symbolName).font(.title2).frame(height: 28)
                        Text(deg(h.temperature)).font(.headline)
                    }
                }
            }
            .padding()
        }
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
    }

    func days(_ w: Weather) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("10-DAY FORECAST", systemImage: "calendar").font(.caption)
            ForEach(Array(w.dailyForecast.enumerated()), id: \.offset) { i, d in
                HStack {
                    Text(i == 0 ? "Today" : d.date.formatted(.dateTime.weekday(.abbreviated))).frame(width: 60, alignment: .leading)
                    Image(systemName: d.symbolName).frame(width: 30)
                    Text(d.precipitationChance >= 0.3 ? "\(Int(d.precipitationChance * 100))%" : "").font(.caption).frame(width: 36)
                    Text(deg(d.lowTemperature)).frame(width: 40)
                    Capsule().fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing)).frame(height: 5)
                    Text(deg(d.highTemperature)).frame(width: 40)
                }
            }
        }
        .padding()
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("days")
    }

    func footer(_ a: WeatherAttribution) -> some View {
        VStack(spacing: 6) {
            if let image = UIImage(contentsOfFile: a.combinedMarkDarkURL.path) {
                Image(uiImage: image).resizable().scaledToFit().frame(height: 18)
            }
            Link("Other data sources", destination: a.legalPageURL).font(.caption)
        }
        .accessibilityIdentifier("attribution")
    }

    func load() async {
        let service = WeatherService.shared
        do {
            let w = try await service.weather(for: city.1)
            report(w)
            weather = w
            let a = try await service.attribution
            say("attribution \(a.serviceName) mark=\(FileManager.default.fileExists(atPath: a.squareMarkURL.path) ? 1 : 0) "
                + "legal=\(a.legalPageURL.host ?? "-")")
            attribution = a
            try await queries(service)
        } catch let e as WeatherError {
            say("error \(e) \(e.localizedDescription)")
            error = e.localizedDescription
        } catch {
            say("error \(error)")
        }
    }

    func report(_ w: Weather) {
        let c = w.currentWeather
        say("current \(c.condition.rawValue) \(c.condition.description) temperature=\(String(format: "%.1f", c.temperature.value))"
            + " symbol=\(c.symbolName) uv=\(c.uvIndex.value) \(c.uvIndex.category) wind=\(c.wind.compassDirection.abbreviation)"
            + " humidity=\((0...1).contains(c.humidity) ? "ok" : "bad") pressure=\(c.pressure.unit.symbol)")
        let days = w.dailyForecast
        let ordered = zip(days, days.dropFirst()).allSatisfy { $1.date.timeIntervalSince($0.date) == 86400 }
        say("daily \(days.count) ordered=\(ordered ? 1 : 0) highs>=lows=\(days.allSatisfy { $0.highTemperature >= $0.lowTemperature } ? 1 : 0)")
        if let d = days.first {
            let s = d.sun
            let sunOK = s.sunrise.map { r in s.sunset.map { r < $0 && s.solarNoon! > r && s.solarNoon! < $0 } ?? false }
            say("sun \(sunOK.map { $0 ? "rises-and-sets" : "bad" } ?? "polar") dawn<rise=\(s.civilDawn.flatMap { a in s.sunrise.map { a < $0 } } == true ? 1 : 0) "
                + "moon=\(d.moon.phase.rawValue) \(d.moon.phase.symbolName)")
        }
        let hours = w.hourlyForecast
        let hourly = zip(hours, hours.dropFirst()).allSatisfy { $1.date.timeIntervalSince($0.date) == 3600 }
        say("hourly \(hours.count) ordered=\(hourly ? 1 : 0) first<=now=\(hours.first.map { $0.date <= Date() } == true ? 1 : 0)")
        if let m = w.minuteForecast { say("minute \(m.count) summary=\(m.summary)") } else { say("minute none") }
        say("availability minute=\(w.availability.minuteAvailability) alert=\(w.availability.alertAvailability)")
        say("alerts \(w.weatherAlerts.map { $0.map { "\($0.severity) \($0.summary) source=\($0.source)" }.joined(separator: "; ") } ?? "unsupported")")
    }

    func queries(_ service: WeatherService) async throws {
        let location = city.1
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86400)
        let (current, daily) = try await service.weather(for: location, including: .current, .daily(startDate: start, endDate: start.addingTimeInterval(3 * 86400)))
        say("query current=\(current.condition.rawValue) days=\(daily.count)")
        let hourly = try await service.weather(for: location, including: .hourly(startDate: start, endDate: start.addingTimeInterval(6 * 3600)))
        say("query hours=\(hourly.count)")
        let (a, b, c) = try await service.weather(for: location, including: .minute, .alerts, .availability)
        say("query minute=\(a?.count ?? 0) alerts=\(b?.count ?? -1) availability=\(c.minuteAvailability)")
        // Codable: a forecast round-trips through JSON
        let data = try JSONEncoder().encode(daily)
        let back = try JSONDecoder().decode(Forecast<DayWeather>.self, from: data)
        say("codable \(back == daily ? "equal" : "different")")
        if #available(iOS 18.0, *) {
            guard let today = (try await service.weather(for: location, including: .daily)).first else { return }
            say("parts day=\(today.daytimeForecast.condition.rawValue) night=\(today.overnightForecast.condition.rawValue) "
                + "rest=\(today.restOfDayForecast != nil ? 1 : 0) clouds=\(today.daytimeForecast.cloudCoverByAltitude.low <= 1 ? 1 : 0)")
            let (temps, rain) = try await service.dailyStatistics(for: location, including: .temperature, .precipitation)
            say("statistics days=\(temps.count) first=\(temps.first?.day ?? 0) highs>=lows=\(temps.allSatisfy { $0.averageHighTemperature >= $0.averageLowTemperature } ? 1 : 0) "
                + "rain=\(rain.count) baseline=\(Calendar(identifier: .gregorian).component(.year, from: temps.baselineStartDate))")
            let months = try await service.monthlyStatistics(for: location, including: .temperature)
            let hoursStats = try await service.hourlyStatistics(for: location, including: .temperature)
            say("statistics months=\(months.count) hours=\(hoursStats.count) p10<p90=\(hoursStats.allSatisfy { $0.percentiles.p10 < $0.percentiles.p90 } ? 1 : 0)")
            let summary = try await service.dailySummary(for: location, including: .temperature)
            say("summary days=\(summary.count) past=\(summary.allSatisfy { $0.date < Date() } ? 1 : 0)")
            let (changes, comparisons) = try await service.weather(for: location, including: .changes, .historicalComparisons)
            let kinds = comparisons?.map { c -> String in
                switch c {
                case .highTemperature: return "high"
                case .lowTemperature: return "low"
                case .precipitationAmount: return "precipitation"
                case .snowfallAmount: return "snow"
                @unknown default: return "other"
                }
            } ?? []
            say("changes \(changes?.count ?? 0) comparisons=\(kinds.joined(separator: ","))")
        } else {
            say("statistics need iOS 18")
        }
    }
}
