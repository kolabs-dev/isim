# WeatherKit

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 100.0% of Apple's iOS API (427 of 427, exact) · **Rows:** 9: 2 ✅ 7 🟡 · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [Location, personal data & sensors](../COVERAGE.md#location) · **Apple:** [WeatherKit](https://developer.apple.com/documentation/weatherkit) · **Issues:** [`area:location`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Alocation)

## How isim implements it

- **Decided (issue #415): a labelled simulated forecast.** Apple's Weather service only answers requests with a JWT
  that Apple signs for the app's developer team, so isim never calls it. Every request is answered by isim's own model
  (`isim/swift/overlays/WeatherKit/Simulation.swift`), and `WeatherService.attribution` says so: the service name is
  "isim Simulated Weather", the legal text says the data is simulated and is not a forecast, and the marks are isim's
  own (written to the app's caches). This is not Apple Weather data.
- **The model** is deterministic: the same place (to 0.01°) and day give the same weather on every machine.
  - Climate: a mean temperature from the latitude and altitude, a seasonal swing (peaking in July in the north and
    January in the south) and a day-to-day anomaly.
  - Diurnal curve: the low near sunrise and the high at 3 pm solar time.
  - Each day's cloud, rain chance and wind come from a hash of the place and the day. The hours vary around them, and
    the conditions, SF Symbol names and amounts follow from those (snow below 0 °C, sleet near it).
  - The sun's events are computed for the place: NOAA's approximate equations, nil in polar day or night.
  - The moon's phase comes from the synodic month. Its rise and set times are approximate.
  - Days follow the place's solar time zone (its longitude ÷ 15, in whole hours), not its political one.
- **Defaults:** ten days and 25 hours from now. Next-hour precipitation and alerts are available only in rough
  regions, like WeatherKit's: next-hour precipitation in the contiguous United States, Canada, the United Kingdom and
  Ireland, Japan and Australia; alerts there and in Europe.
- **`ISIM_WEATHER`** overrides the current weather ([SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)), for example
  `condition=rain,temperature=12,alert=severe` (any `WeatherCondition` and `WeatherSeverity` name). `unavailable`
  makes every request fail with `WeatherError.unknown`, as when the service cannot be reached.
- Requests need the `com.apple.developer.weatherkit` entitlement, as on iOS. Without it they throw
  `WeatherError.permissionDenied`.
- **Objective-C / C interface:** Swift only, as in Apple's SDK.
- **Versus Apple's Simulator:** the Simulator fetches real forecasts from Apple's service (with a signed app). isim's
  forecast is plausible but invented, so it can't stand in for checking real data. It works offline and is
  repeatable, which suits tests.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `WeatherService` (`shared`, `init()`), `weather(for:)`, `weather(for:including:)` (one query, a parameter pack, and the overloads of two to six queries), `attribution`, `WeatherAttribution` | 🟡 | 16.0 | adapted: the simulated forecast, labelled in the attribution. Tested (HelloWeather, test_weather) |
| `WeatherQuery`: `current`, `minute`, `hourly`, `hourly(startDate:endDate:)`, `daily`, `daily(startDate:endDate:)`, `alerts`, `availability` | 🟡 | 16.0 | adapted: day ranges are the place's solar days, hour ranges whole hours. Tested (HelloWeather, test_weather: a tuple of queries, date ranges) |
| `Weather`, `CurrentWeather`, `HourWeather`, `DayWeather`, `MinuteWeather`, `Forecast` (a random-access collection, `summary`, Codable), `WeatherMetadata` | 🟡 | 16.0 | adapted: the model above, in °C, km/h, mbar, mm and m. A Codable round trip is tested |
| `DayWeather`'s iOS 18 values: `daytimeForecast`, `overnightForecast`, `restOfDayForecast`, `DayPartForecast`, `highTemperatureTime`, `lowTemperatureTime`, `highWindSpeed`, minimum and maximum humidity and visibility, `precipitationAmountByType`, `PrecipitationAmountByType`, `SnowfallAmount`, `cloudCoverByAltitude`, `CloudCoverByAltitude` | 🟡 | 18.0 | adapted: daytime is 7 am to 7 pm, overnight 7 pm to 7 am. Tested (test_weather, `os_matrix`) |
| `WeatherCondition`, `Precipitation`, `PressureTrend`, `UVIndex` (`ExposureCategory`), `Wind` (`CompassDirection`), `SunEvents`, `MoonEvents`, `MoonPhase` (`symbolName`), `WeatherSeverity` | ✅ | 16.0 | the cases, descriptions and SF Symbol names of Apple's |
| `WeatherAlert`, `WeatherAvailability` | 🟡 | 16.0 | adapted: alerts only from `ISIM_WEATHER=alert=…`; availability by region (tested: London, Tromsø, Sydney) |
| `WeatherError` (`permissionDenied`, `unknown`) | ✅ | 16.0 | without the entitlement, or `ISIM_WEATHER=unavailable` (tested) |
| `dailyStatistics`, `hourlyStatistics`, `monthlyStatistics` (by default, by range and by interval), their queries and results (`DayTemperatureStatistics`, `DayPrecipitationStatistics`, `HourTemperatureStatistics`, `Percentiles`, `MonthTemperatureStatistics`, `MonthPrecipitationStatistics`) | 🟡 | 18.0 | adapted: the model's climate, with a 1991 baseline. Days and months count from 1, hours of the year from 0. Tested (test_weather, `os_matrix`) |
| `dailySummary` (`DailyWeatherSummary`, `DayTemperatureSummary`, `DayPrecipitationSummary`), `WeatherQuery.changes` (`WeatherChanges`, `WeatherChange`), `WeatherQuery.historicalComparisons` (`HistoricalComparisons`, `HistoricalComparison`, `Trend`, `TrendBaseline`, `Deviation`) | 🟡 | 18.0 | adapted: the past 30 simulated days; how each of the next nine days differs from the day before; today against the climate. Tested (test_weather, `os_matrix`) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
Nothing (or not measured yet).
<!-- /generated:missing -->
