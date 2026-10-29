// isim WeatherKit (issue #415): the simulated forecast. Apple's service needs a JWT that Apple signs for the app's team,
// so isim never calls it; every answer comes from this model instead, and says so (WeatherService.attribution).
//
// The model is deterministic: the same place (to 0.01°) and the same day give the same weather, on every machine.
// - climate: a mean temperature from the latitude, a seasonal swing (peaking in July in the north, January in the
//   south) and a day-to-day anomaly; a diurnal curve with the low near sunrise and the high at 3 pm solar time;
// - each day's cloud, rain chance and wind come from a hash of the place and the day, the hours vary around them,
//   and the conditions, symbols and amounts follow from those (snow below 0 °C, sleet near it);
// - the sun's events are computed for the place (NOAA's approximate equations; nil in polar day or night), the moon's
//   phase from the synodic month, its rise and set approximately;
// - the local day is the place's solar time zone (its longitude / 15, in whole hours), not its political one.
// ISIM_WEATHER overrides the current weather (docs/SYSTEM-PROMPTS.md): `condition=rain,temperature=12,alert=severe`,
// or `unavailable` (every request fails with WeatherError.unknown, as when the service cannot be reached).
import Foundation
import CoreLocation

struct _WeatherOverrides {
    var unavailable = false
    var condition: WeatherCondition?
    var temperature: Double?
    var alert: WeatherSeverity?

    static func parse(_ s: String?) -> _WeatherOverrides {
        var o = _WeatherOverrides()
        guard let s, !s.isEmpty else { return o }
        for part in s.split(separator: ",") {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            switch (kv[0], kv.count > 1 ? kv[1] : nil) {
            case ("unavailable", _): o.unavailable = true
            case ("condition", let v?): o.condition = WeatherCondition(rawValue: v)
            case ("temperature", let v?): o.temperature = Double(v)
            case ("alert", let v?): o.alert = WeatherSeverity(rawValue: v) ?? .severe
            default: NSLog("isim WeatherKit: ignoring ISIM_WEATHER part '%@'", String(part))
            }
        }
        return o
    }
}

struct _WeatherSim {
    let location: CLLocation
    let now: Date
    var overrides: _WeatherOverrides
    let lat: Double, lon: Double
    let offset: TimeInterval            // the solar time zone, from UTC
    let latKey: Int64, lonKey: Int64
    var todayShift = 0.0                 // ISIM_WEATHER's temperature, spread over the current day

    init(location: CLLocation, now: Date = Date(), overrides: _WeatherOverrides) {
        self.location = location; self.now = now; self.overrides = overrides
        lat = location.coordinate.latitude; lon = location.coordinate.longitude
        offset = (lon / 15).rounded() * 3600
        latKey = Int64((lat * 100).rounded()); lonKey = Int64((lon * 100).rounded())
        if let forced = overrides.temperature {
            var model = self
            model.overrides.temperature = nil
            todayShift = forced - model.hour(now).temperature
        }
    }

    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: Int(offset)) ?? .gmt
        return c
    }

    // MARK: noise

    func noise(_ index: Int64, _ salt: Int64) -> Double {
        var x = UInt64(bitPattern: latKey &* 73_856_093 ^ lonKey &* 19_349_663 ^ index &* 83_492_791 ^ salt &* 2_654_435_761)
        x = x &+ 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31
        return Double(x >> 11) / Double(1 << 53)
    }

    // MARK: days

    func dayIndex(_ d: Date) -> Int64 { Int64(((d.timeIntervalSince1970 + offset) / 86400).rounded(.down)) }
    func dayStart(_ day: Int64) -> Date { Date(timeIntervalSince1970: Double(day) * 86400 - offset) }
    func dayOfYear(_ day: Int64) -> Int { calendar.ordinality(of: .day, in: .year, for: dayStart(day).addingTimeInterval(43200)) ?? 1 }

    // the climatological mean temperature of a day of the year, without the day's anomaly
    func climateMean(doy: Int) -> Double {
        let a = abs(lat)
        let annual = 28 - 0.25 * a - max(0, a - 35) * 0.15 - location.altitude / 150
        let swing = min(14, 0.18 * a)
        let peak = lat >= 0 ? 200.0 : 17.0
        return annual + swing * cos(2 * .pi * (Double(doy) - peak) / 365.25)
    }
    func climateRange() -> Double { 9 }

    struct Day {
        var mean: Double, range: Double
        var cloud: Double, chance: Double
        var windKmh: Double, windDeg: Double
        var humidity: Double
        var pressure: Double
    }

    func day(_ d: Int64) -> Day {
        let doy = dayOfYear(d)
        // a smooth anomaly: this day's draw averaged with its neighbours'
        let anomaly = ((noise(d - 1, 1) + 2 * noise(d, 1) + noise(d + 1, 1)) / 4 - 0.5) * 9
        let cloud = min(1, max(0, (noise(d, 2) * 0.7 + noise(d - 1, 2) * 0.3)))
        let chance = min(1, max(0, (cloud - 0.45) * 1.9 * (0.55 + 0.45 * noise(d, 3))))
        let range = 4 + 9 * (1 - cloud)
        return Day(mean: climateMean(doy: doy) + anomaly + (d == dayIndex(now) ? todayShift : 0), range: range, cloud: cloud, chance: (chance * 20).rounded() / 20,
                   windKmh: 4 + 34 * pow(noise(d, 4), 2), windDeg: (noise(d, 5) * 360).rounded(),
                   humidity: min(0.98, 0.42 + 0.45 * cloud + 0.1 * noise(d, 6)), pressure: 1024 - 22 * cloud)
    }

    // MARK: the sun and the moon

    func declination(doy: Int) -> Double { 23.44 * .pi / 180 * sin(2 * .pi * (284 + Double(doy)) / 365) }
    func solarNoon(_ d: Int64) -> Date {
        let n = Double(dayOfYear(d))
        let b = 2 * Double.pi * (n - 81) / 364
        let eot = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)          // minutes
        return Date(timeIntervalSince1970: Double(d) * 86400 + (720 - 4 * lon - eot) * 60)
    }
    // the time the sun crosses `altitude` degrees, before (rising) or after (setting) noon; nil when it never does
    func sunCrossing(_ d: Int64, altitude: Double, rising: Bool) -> Date? {
        let phi = lat * .pi / 180, delta = declination(doy: dayOfYear(d))
        let c = (sin(altitude * .pi / 180) - sin(phi) * sin(delta)) / (cos(phi) * cos(delta))
        guard c >= -1, c <= 1 else { return nil }
        let hours = acos(c) * 180 / .pi / 15
        return solarNoon(d).addingTimeInterval((rising ? -hours : hours) * 3600)
    }
    func sunAltitude(_ t: Date) -> Double {
        let d = dayIndex(t)
        let phi = lat * .pi / 180, delta = declination(doy: dayOfYear(d))
        let h = t.timeIntervalSince(solarNoon(d)) / 3600 * 15 * .pi / 180
        return asin(sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)) * 180 / .pi
    }
    func isDaylight(_ t: Date) -> Bool { sunAltitude(t) > -0.833 }

    func sunEvents(_ d: Int64) -> SunEvents {
        let noon = solarNoon(d)
        return SunEvents(astronomicalDawn: sunCrossing(d, altitude: -18, rising: true), nauticalDawn: sunCrossing(d, altitude: -12, rising: true),
                         civilDawn: sunCrossing(d, altitude: -6, rising: true), sunrise: sunCrossing(d, altitude: -0.833, rising: true),
                         solarNoon: noon, sunset: sunCrossing(d, altitude: -0.833, rising: false),
                         civilDusk: sunCrossing(d, altitude: -6, rising: false), nauticalDusk: sunCrossing(d, altitude: -12, rising: false),
                         astronomicalDusk: sunCrossing(d, altitude: -18, rising: false), solarMidnight: noon.addingTimeInterval(-43200))
    }

    static let synodicMonth = 29.530588853
    func moonAge(_ t: Date) -> Double {                   // days since the new moon of 6 January 2000, 18:14 UTC
        let a = (t.timeIntervalSince1970 - 947_182_440) / 86400
        return a - (a / Self.synodicMonth).rounded(.down) * Self.synodicMonth
    }
    func moonEvents(_ d: Int64) -> MoonEvents {
        let noon = solarNoon(d)
        let age = moonAge(noon)
        let phases: [MoonPhase] = [.new, .waxingCrescent, .firstQuarter, .waxingGibbous, .full, .waningGibbous, .lastQuarter, .waningCrescent]
        let phase = phases[Int((age / Self.synodicMonth * 8 + 0.5).rounded(.down)) % 8]
        // the moon rises about 50 minutes later each day: at sunrise when new, at sunset when full
        let start = dayStart(d).timeIntervalSince1970
        func inDay(_ t: Double) -> Date? {
            let r = (t - start).truncatingRemainder(dividingBy: 86400)
            return Date(timeIntervalSince1970: start + (r < 0 ? r + 86400 : r))
        }
        let rise = noon.timeIntervalSince1970 - 6 * 3600 + age / Self.synodicMonth * 86400
        return MoonEvents(phase: phase, moonrise: inDay(rise), moonset: inDay(rise + 12.4 * 3600))
    }

    // MARK: hours

    struct Hour {
        var temperature: Double, cloud: Double, chance: Double, amount: Double
        var humidity: Double, windKmh: Double, windDeg: Double, gust: Double?
        var pressure: Double, condition: WeatherCondition, daylight: Bool, uv: Int, visibility: Double
    }

    func hour(_ t: Date) -> Hour {
        let d = dayIndex(t), dd = day(d)
        let h = Int64((t.timeIntervalSince1970 / 3600).rounded(.down))
        // solar hour of the day, 0..<24
        let solar = (t.timeIntervalSince(solarNoon(d)) / 3600 + 12 + 24).truncatingRemainder(dividingBy: 24)
        // blend into the next or previous day across midnight so the curve is continuous
        let next = day(solar >= 15 ? d + 1 : d - 1)
        let w = solar >= 15 ? (solar - 15) / 12 * 0.5 : (15 - solar) / 15 * 0.5
        let mean = dd.mean * (1 - w) + next.mean * w
        let range = dd.range * (1 - w) + next.range * w
        var temperature = mean + range / 2 * cos(2 * .pi * (solar - 15) / 24)
        let cloud = min(1, max(0, dd.cloud + (noise(h, 7) - 0.5) * 0.3))
        var chance = min(1, max(0, dd.chance * (0.5 + noise(h, 8))))
        chance = (chance * 20).rounded() / 20
        let windKmh = max(0, dd.windKmh * (0.7 + 0.6 * noise(h, 9)))
        let daylight = isDaylight(t)
        var amount = chance >= 0.5 ? (chance - 0.4) * 3.5 * (dd.chance > 0.8 ? 2 : 1) : 0
        var condition = _WeatherSim.condition(cloud: cloud, chance: chance, amountPerHour: amount, temperature: temperature,
                                              windKmh: windKmh, dayChance: dd.chance)
        // ISIM_WEATHER: the current hour, and the current weather (WeatherService), take the forced values
        if dayIndex(now) == d, Int64((now.timeIntervalSince1970 / 3600).rounded(.down)) == h {
            if let c = overrides.condition {
                condition = c
                if c.precipitates { chance = 1; amount = max(amount, 1.5) } else { chance = 0; amount = 0 }
            }
            if let v = overrides.temperature { temperature = v }
        }
        let alt = sunAltitude(t)
        let uv = alt > 0 ? Int((13 * pow(sin(alt * .pi / 180), 1.5) * (1 - 0.7 * cloud)).rounded()) : 0
        let humidity = min(0.99, dd.humidity + (daylight ? -0.08 : 0.08) + (amount > 0 ? 0.1 : 0))
        return Hour(temperature: temperature, cloud: cloud, chance: chance, amount: amount, humidity: humidity,
                    windKmh: windKmh, windDeg: (dd.windDeg + (noise(h, 10) - 0.5) * 40 + 360).truncatingRemainder(dividingBy: 360),
                    gust: windKmh > 15 ? windKmh * 1.5 : nil, pressure: dd.pressure + (noise(h, 11) - 0.5) * 2,
                    condition: condition, daylight: daylight, uv: uv,
                    visibility: condition == .foggy ? 800 : max(2000, 24_000 * (1 - 0.6 * chance) * (1 - 0.3 * cloud)))
    }

    static func condition(cloud: Double, chance: Double, amountPerHour: Double, temperature: Double, windKmh: Double,
                          dayChance: Double) -> WeatherCondition {
        if chance >= 0.5 {
            if temperature <= 0 { return amountPerHour > 2.5 ? .heavySnow : amountPerHour < 0.6 ? .flurries : .snow }
            if temperature <= 2 { return .sleet }
            if dayChance > 0.85, temperature > 18 { return .thunderstorms }
            if amountPerHour > 3 { return .heavyRain }
            if amountPerHour < 0.6 { return .drizzle }
            return cloud < 0.6 ? .sunShowers : .rain
        }
        if windKmh >= 45 { return .windy }
        if windKmh >= 32 { return .breezy }
        if temperature >= 35, cloud < 0.6 { return .hot }
        if temperature <= -18 { return .frigid }
        switch cloud {
        case ..<0.2: return .clear
        case ..<0.4: return .mostlyClear
        case ..<0.6: return .partlyCloudy
        case ..<0.8: return .mostlyCloudy
        default: return .cloudy
        }
    }

    static func dewPoint(_ t: Double, humidity: Double) -> Double {            // Magnus
        let g = log(max(0.01, humidity)) + 17.62 * t / (243.12 + t)
        return 243.12 * g / (17.62 - g)
    }
    static func apparent(_ t: Double, humidity: Double, windKmh: Double) -> Double {
        if t <= 10, windKmh > 4.8 {                                             // wind chill
            let v = pow(windKmh, 0.16)
            return 13.12 + 0.6215 * t - 11.37 * v + 0.3965 * t * v
        }
        if t >= 27 { return t + 0.33 * humidity * 6.105 * exp(17.27 * t / (237.7 + t)) - 4 }   // Steadman's apparent temperature
        return t
    }
    static func precipitation(_ c: WeatherCondition, temperature: Double) -> Precipitation {
        c.precipitates ? c.precipitation : .none
    }

    // MARK: making WeatherKit's values

    var metadata: WeatherMetadata {
        WeatherMetadata(date: now, expirationDate: now.addingTimeInterval(600), location: location)
    }

    func clouds(_ c: Double, _ salt: Int64) -> _CloudLayers {
        _CloudLayers(low: min(1, c * (0.6 + 0.6 * noise(salt, 12))), medium: min(1, c * (0.4 + 0.6 * noise(salt, 13))),
                     high: min(1, c * (0.2 + 0.6 * noise(salt, 14))))
    }

    func pressureTrend(_ t: Date) -> PressureTrend {
        let a = hour(t.addingTimeInterval(-3 * 3600)).pressure, b = hour(t).pressure
        return b - a > 1 ? .rising : a - b > 1 ? .falling : .steady
    }

    func hourWeather(_ t: Date) -> HourWeather {
        let x = hour(t)
        let type = _WeatherSim.precipitation(x.condition, temperature: x.temperature)
        let h = Int64((t.timeIntervalSince1970 / 3600).rounded(.down))
        return HourWeather(date: t, condition: x.condition, symbolName: x.condition.symbolName(daylight: x.daylight), isDaylight: x.daylight,
                           temperature: Measurement(value: x.temperature, unit: .celsius),
                           apparentTemperature: Measurement(value: _WeatherSim.apparent(x.temperature, humidity: x.humidity, windKmh: x.windKmh), unit: .celsius),
                           dewPoint: Measurement(value: _WeatherSim.dewPoint(x.temperature, humidity: x.humidity), unit: .celsius),
                           humidity: x.humidity, pressure: Measurement(value: x.pressure, unit: .millibars), pressureTrend: pressureTrend(t),
                           wind: Wind(degrees: x.windDeg, kmh: x.windKmh, gustKmh: x.gust), cloudCover: x.cloud,
                           _cloudCoverByAltitude: clouds(x.cloud, h), precipitation: type, precipitationChance: x.chance,
                           precipitationAmount: Measurement(value: x.amount, unit: .millimeters),
                           snowfallAmount: Measurement(value: type == .snow ? x.amount * 10 : 0, unit: .millimeters),
                           uvIndex: UVIndex(value: x.uv), visibility: Measurement(value: x.visibility, unit: .meters))
    }

    func currentWeather() -> CurrentWeather {
        let x = hour(now), hw = hourWeather(now)
        return CurrentWeather(date: now, metadata: metadata, condition: x.condition, symbolName: hw.symbolName, isDaylight: x.daylight,
                              temperature: hw.temperature, apparentTemperature: hw.apparentTemperature, dewPoint: hw.dewPoint,
                              humidity: x.humidity, pressure: hw.pressure, pressureTrend: hw.pressureTrend, wind: hw.wind,
                              cloudCover: x.cloud, _cloudCoverByAltitude: hw._cloudCoverByAltitude,
                              precipitationIntensity: Measurement(value: x.amount, unit: UnitSpeed._millimetersPerHour),
                              uvIndex: hw.uvIndex, visibility: hw.visibility)
    }

    func part(_ hours: [Hour], dayChance: Double, salt: Int64) -> _DayPart {
        let temps = hours.map(\.temperature), winds = hours.map(\.windKmh)
        let cloud = hours.map(\.cloud).reduce(0, +) / Double(max(1, hours.count))
        let chance = hours.map(\.chance).max() ?? 0
        let amount = hours.map(\.amount).reduce(0, +)
        let warmest = temps.max() ?? 0
        let condition = _WeatherSim.condition(cloud: cloud, chance: chance, amountPerHour: amount / Double(max(1, hours.count)) * 3,
                                              temperature: warmest, windKmh: winds.max() ?? 0, dayChance: dayChance)
        let calm = hours.max { $0.windKmh < $1.windKmh }
        return _DayPart(condition: condition, cloudCover: cloud, clouds: clouds(cloud, salt), high: warmest, low: temps.min() ?? 0,
                        highWind: winds.max() ?? 0, wind: Wind(degrees: calm?.windDeg ?? 0, kmh: winds.reduce(0, +) / Double(max(1, winds.count)),
                                                               gustKmh: calm?.gust),
                        maxHumidity: hours.map(\.humidity).max() ?? 0, minHumidity: hours.map(\.humidity).min() ?? 0,
                        maxVisibility: hours.map(\.visibility).max() ?? 0, minVisibility: hours.map(\.visibility).min() ?? 0,
                        chance: chance, amount: PrecipitationAmountByType(type: _WeatherSim.precipitation(condition, temperature: warmest), mm: amount))
    }

    func dayWeather(_ d: Int64) -> DayWeather {
        let start = dayStart(d)
        let times = (0..<24).map { start.addingTimeInterval(Double($0) * 3600) }
        let hours = times.map(hour)
        let dd = day(d)
        let high = hours.map(\.temperature).max() ?? 0, low = hours.map(\.temperature).min() ?? 0
        let amount = hours.map(\.amount).reduce(0, +)
        let chance = hours.map(\.chance).max() ?? 0
        let windiest = hours.max { $0.windKmh < $1.windKmh }!
        var condition = _WeatherSim.condition(cloud: dd.cloud, chance: chance, amountPerHour: amount / 6, temperature: chance >= 0.5 ? low : high,
                                              windKmh: windiest.windKmh, dayChance: dd.chance)
        if dayIndex(now) == d, let c = overrides.condition { condition = c }
        let type = _WeatherSim.precipitation(condition, temperature: high)
        let daytime = part(Array(hours[7..<19]), dayChance: dd.chance, salt: d * 3)
        // overnight: 7 pm to 7 am the next morning
        let night = (19..<31).map { hour(start.addingTimeInterval(Double($0) * 3600)) }
        let overnight = part(night, dayChance: dd.chance, salt: d * 3 + 1)
        var rest: _DayPart?
        if dayIndex(now) == d {
            let from = Int(now.timeIntervalSince(start) / 3600)
            if from < 24 { rest = part(Array(hours[from...]), dayChance: dd.chance, salt: d * 3 + 2) }
        }
        let parts = _DayParts(highTime: times[hours.firstIndex { $0.temperature == high }!],
                              lowTime: times[hours.firstIndex { $0.temperature == low }!],
                              highWind: Measurement(value: windiest.windKmh, unit: .kilometersPerHour),
                              maxHumidity: hours.map(\.humidity).max()!, minHumidity: hours.map(\.humidity).min()!,
                              maxVisibility: hours.map(\.visibility).max()!, minVisibility: hours.map(\.visibility).min()!,
                              daytime: daytime, overnight: overnight, restOfDay: rest)
        return DayWeather(date: start, condition: condition, symbolName: condition.symbolName(daylight: true),
                          highTemperature: Measurement(value: high, unit: .celsius), lowTemperature: Measurement(value: low, unit: .celsius),
                          precipitation: type, precipitationChance: chance,
                          precipitationAmountByType: PrecipitationAmountByType(type: type, mm: amount),
                          wind: Wind(degrees: dd.windDeg, kmh: dd.windKmh, gustKmh: windiest.gust),
                          uvIndex: UVIndex(value: hours.map(\.uv).max() ?? 0), sun: sunEvents(d), moon: moonEvents(d), _parts: parts)
    }

    // MARK: forecasts

    func hourStart(_ t: Date) -> Date { Date(timeIntervalSince1970: (t.timeIntervalSince1970 / 3600).rounded(.down) * 3600) }

    func daily(from: Date? = nil, to: Date? = nil) -> Forecast<DayWeather> {
        let first = from.map(dayIndex) ?? dayIndex(now)
        // the days that start before the end date; ten from today when no range is given
        let last = to.map { dayIndex($0.addingTimeInterval(-1)) } ?? first + 9
        return Forecast(first > last ? [] : (first...last).map(dayWeather), metadata: metadata)
    }

    func hourly(from: Date? = nil, to: Date? = nil) -> Forecast<HourWeather> {
        let first = hourStart(from ?? now)
        let end = to ?? first.addingTimeInterval(25 * 3600)
        var hours: [HourWeather] = []
        var t = first
        while t < end { hours.append(hourWeather(t)); t.addTimeInterval(3600) }
        return Forecast(hours, metadata: metadata)
    }

    // next-hour precipitation; WeatherKit has it only in some regions
    static let minuteRegions: [(ClosedRange<Double>, ClosedRange<Double>)] = [
        (24.5...49.5, -125...(-66.9)),       // the contiguous United States
        (41.7...70, -141...(-52.6)),         // Canada
        (49.8...60.9, -10.7...1.8),          // the United Kingdom and Ireland
        (24...45.6, 122.9...146),            // Japan
        (-44...(-10), 112...154),            // Australia
    ]
    static let alertRegions = minuteRegions + [(35...71, -10...40)]   // and Europe

    func supported(_ regions: [(ClosedRange<Double>, ClosedRange<Double>)]) -> Bool {
        regions.contains { $0.0.contains(lat) && $0.1.contains(lon) }
    }

    var availability: WeatherAvailability {
        WeatherAvailability(minuteAvailability: supported(Self.minuteRegions) ? .available : .unsupported,
                            alertAvailability: supported(Self.alertRegions) ? .available : .unsupported)
    }

    func minute() -> Forecast<MinuteWeather>? {
        guard supported(Self.minuteRegions) else { return nil }
        let start = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / 60).rounded(.down) * 60)
        let a = hour(now), b = hour(now.addingTimeInterval(3600))
        let wet = a.chance >= 0.5 || overrides.condition?.precipitates == true
        let later = b.chance >= 0.5
        // when it changes within the hour
        let change = overrides.condition != nil ? 60 : 10 + Int(noise(Int64(start.timeIntervalSince1970 / 3600), 15) * 45)
        let type = _WeatherSim.precipitation(a.condition.precipitates ? a.condition : b.condition, temperature: a.temperature)
        let kind = type == .none ? Precipitation.rain : type
        var minutes: [MinuteWeather] = []
        for m in 0..<60 {
            let raining = m < change ? wet : later
            let mmh = raining ? max(0.3, (wet ? a.amount : b.amount)) : 0
            minutes.append(MinuteWeather(date: start.addingTimeInterval(Double(m) * 60), precipitation: raining ? kind : .none,
                                         precipitationChance: raining ? max(0.5, max(a.chance, b.chance)) : min(0.1, a.chance),
                                         precipitationIntensity: Measurement(value: mmh, unit: UnitSpeed._millimetersPerHour)))
        }
        let name = kind.description
        let summary: String
        switch (wet, later, change < 60) {
        case (true, false, true): summary = "\(name) stopping in \(change) min."
        case (false, true, true): summary = "\(name) starting in \(change) min."
        case (true, _, _): summary = "\(name) for the hour."
        default: summary = "No precipitation for the hour."
        }
        return Forecast(minutes, metadata: metadata, summary: summary)
    }

    func alerts() -> [WeatherAlert]? {
        guard supported(Self.alertRegions) else { return nil }
        guard let s = overrides.alert else { return [] }
        let summary: String
        switch s {
        case .extreme: summary = "Extreme Heat Warning"
        case .severe: summary = "Severe Thunderstorm Warning"
        case .moderate: summary = "Wind Advisory"
        case .minor: summary = "Special Weather Statement"
        case .unknown: summary = "Weather Alert"
        }
        return [WeatherAlert(metadata: WeatherMetadata(date: now, expirationDate: now.addingTimeInterval(6 * 3600), location: location),
                             summary: summary, region: String(format: "%.2f, %.2f", lat, lon), severity: s,
                             source: "isim (simulated)", detailsURL: _WeatherService.docsURL)]
    }

    func weather() -> Weather {
        Weather(currentWeather: currentWeather(), minuteForecast: minute(), hourlyForecast: hourly(), dailyForecast: daily(),
                weatherAlerts: alerts(), availability: availability)
    }
}
