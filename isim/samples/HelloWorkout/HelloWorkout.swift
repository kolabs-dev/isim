// Sample: HealthKit workouts on isim (issue #418). A run recorded afterwards with HKWorkoutBuilder (heart rate, energy
// and distance samples, a pause, two activities, a route), then queried back: the workout, its statistics, the samples
// that belong to it and its route. From iOS 26 an iPhone runs its own workout session: HKWorkoutSession with its
// HKLiveWorkoutBuilder, whose data source is isim's simulated runner (heart rate, energy and distance each second).
// `-check` runs both (the live workout pauses at 4 s and ends at 6 s), `-live` starts a live workout that runs until
// you end it; everything is printed, and tests/ui/test_workout.py checks it.
import SwiftUI
import HealthKit
import CoreLocation

@main
struct HelloWorkoutApp: App {
    @StateObject private var model = WorkoutModel()
    var body: some Scene { WindowGroup { ContentView(model: model) } }
}

func say(_ s: String) { print("workout: \(s)") }

let health = HKHealthStore()
let heartRate = HKQuantityType(.heartRate), energy = HKQuantityType(.activeEnergyBurned), distance = HKQuantityType(.distanceWalkingRunning)
let bpm = HKUnit.count().unitDivided(by: .minute())

func stat(_ s: HKStatistics?, _ unit: HKUnit, sum: Bool) -> Double {
    (sum ? s?.sumQuantity() : s?.averageQuantity())?.doubleValue(for: unit) ?? 0
}

final class WorkoutModel: NSObject, ObservableObject, HKWorkoutSessionDelegate {
    @Published var state = "Ready"
    @Published var elapsed: TimeInterval = 0
    @Published var heart = 0.0
    @Published var kcal = 0.0
    @Published var meters = 0.0
    @Published var history: [String] = []
    var session: HKWorkoutSession?
    var collected: Set<String> = []
    var timer: Timer?
    let check = ProcessInfo.processInfo.arguments.contains("-check")
    /// -live: a live workout that runs until you end it
    let live = ProcessInfo.processInfo.arguments.contains("-live")

    func start() {
        let share: Set<HKSampleType> = [HKObjectType.workoutType(), heartRate, energy, distance, HKSeriesType.workoutRoute()]
        health.requestAuthorization(toShare: share, read: Set(share.map { $0 as HKObjectType })) { ok, error in
            say("authorized \(ok) workouts=\(health.authorizationStatus(for: HKObjectType.workoutType()).rawValue)")
            Task { await self.recordRun() }
        }
    }

    // MARK: a workout recorded afterwards (every iOS version)

    /// yesterday's 20-minute run with a 2-minute pause: two activities (a warm-up walk, then the run) and a route
    func recordRun() async {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        let builder = HKWorkoutBuilder(healthStore: health, configuration: config, device: .local())
        let start = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-86_400 + 7 * 3600)
        let end = start.addingTimeInterval(22 * 60)
        do {
            try await builder.beginCollection(at: start)
            var samples: [HKSample] = []
            for minute in 0..<22 where !(10..<12).contains(minute) {
                let a = start.addingTimeInterval(Double(minute) * 60), b = a.addingTimeInterval(60)
                samples.append(HKQuantitySample(type: heartRate, quantity: HKQuantity(unit: bpm, doubleValue: minute < 5 ? 110 : 150), start: a, end: a))
                samples.append(HKQuantitySample(type: energy, quantity: HKQuantity(unit: .kilocalorie(), doubleValue: 10), start: a, end: b))
                samples.append(HKQuantitySample(type: distance, quantity: HKQuantity(unit: .meter(), doubleValue: minute < 5 ? 90 : 170), start: a, end: b))
            }
            try await builder.addSamples(samples)
            try await builder.addWorkoutEvents([
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: start.addingTimeInterval(600), duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: start.addingTimeInterval(720), duration: 0), metadata: nil),
                HKWorkoutEvent(type: .lap, dateInterval: DateInterval(start: start.addingTimeInterval(900), duration: 0), metadata: nil),
            ])
            let walk = HKWorkoutConfiguration(); walk.activityType = .walking; walk.locationType = .outdoor
            try await builder.addWorkoutActivity(HKWorkoutActivity(workoutConfiguration: walk, start: start, end: start.addingTimeInterval(300), metadata: nil))
            try await builder.addWorkoutActivity(HKWorkoutActivity(workoutConfiguration: config, start: start.addingTimeInterval(300), end: nil, metadata: nil))
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "HelloWorkout"])
            if let route = builder.seriesBuilder(for: .workoutRoute()) as? HKWorkoutRouteBuilder {
                let points = (0..<6).map { i in
                    CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.3349 + Double(i) * 0.001, longitude: -122.0090), altitude: 20,
                               horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 2.9, timestamp: start.addingTimeInterval(Double(i) * 240))
                }
                try await route.insertRouteData(points)
            }
            say("elapsed at end \(Int(builder.elapsedTime(at: end))) s")
            try await builder.endCollection(at: end)
            guard let w = try await builder.finishWorkout() else { say("no workout"); return }
            say(String(format: "saved %@ duration=%.0f energy=%.0f distance=%.0f hr=%.0f events=%d activities=%d", name(w.workoutActivityType), w.duration,
                       stat(w.statistics(for: energy), .kilocalorie(), sum: true), stat(w.statistics(for: distance), .meter(), sum: true),
                       stat(w.statistics(for: heartRate), bpm, sum: false), w.workoutEvents?.count ?? 0, w.workoutActivities.count))
            let a = w.workoutActivities
            say(String(format: "activities %@ %.0f s, %@ %.0f s distance=%.0f", name(a[0].workoutConfiguration.activityType), a[0].duration,
                       name(a[1].workoutConfiguration.activityType), a[1].duration, stat(a[1].statistics(for: distance), .meter(), sum: true)))
            await query(w)
        } catch {
            say("record error \(error)")
        }
        if #available(iOS 26.0, *) {
            await MainActor.run { if self.check || self.live { self.startLive() } }
        } else {
            say("no live workout session on iPhone before iOS 26")
        }
    }
    func name(_ t: HKWorkoutActivityType) -> String { t == .running ? "running" : t == .walking ? "walking" : "\(t.rawValue)" }

    /// the saved workouts, back from the database
    func query(_ w: HKWorkout) async {
        let runs = HKQuery.predicateForWorkouts(with: .running)
        let found = (try? await HKSampleQueryDescriptor(predicates: [.workout(runs)], sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]).result(for: health)) ?? []
        say("found \(found.count) runs; same=\(found.first?.uuid == w.uuid) brand=\(found.first?.metadata?[HKMetadataKeyWorkoutBrandName] as? String ?? "-")")
        let long = HKQuery.predicateForWorkouts(with: .greaterThan, duration: 15 * 60)
        let burned = HKQuery.predicateForWorkouts(operatorType: .greaterThanOrEqualTo, quantityType: energy, sumQuantity: HKQuantity(unit: .kilocalorie(), doubleValue: 200))
        let walked = HKQuery.predicateForWorkouts(activityPredicate: HKQuery.predicateForWorkoutActivities(workoutActivityType: .walking))
        let all = NSCompoundPredicate(andPredicateWithSubpredicates: [long, burned, walked])
        let matching = (try? await HKSampleQueryDescriptor(predicates: [.workout(all)], sortDescriptors: []).result(for: health)) ?? []
        say("long, 200 kcal and a walk: \(matching.count)")
        let mine = HKQuery.predicateForObjects(from: w)
        let beats = (try? await HKSampleQueryDescriptor(predicates: [.quantitySample(type: heartRate, predicate: mine)], sortDescriptors: []).result(for: health)) ?? []
        say("heart rate samples of the workout \(beats.count)")
        let routes = (try? await HKSampleQueryDescriptor(predicates: [.workoutRoute(mine)], sortDescriptors: []).result(for: health)) ?? []
        guard let route = routes.first else { say("no route"); return }
        var points: [CLLocation] = []
        do { for try await p in HKWorkoutRouteQueryDescriptor(route).results(for: health) { points.append(p) } } catch { say("route error \(error)") }
        say(String(format: "route %d points count=%d first=%.4f last=%.4f", points.count, route.count, points.first?.coordinate.latitude ?? 0,
                   points.last?.coordinate.latitude ?? 0))
        await MainActor.run { history.insert(String(format: "Run · %.0f min · %.2f km", w.duration / 60, stat(w.statistics(for: distance), .meter(), sum: true) / 1000), at: 0) }
    }

    // MARK: a live workout on iPhone (iOS 26)

    @available(iOS 26.0, *)
    func startLive() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .outdoor
        do {
            let s = try HKWorkoutSession(healthStore: health, configuration: config)
            let builder = s.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: health, workoutConfiguration: config)
            builder.delegate = self
            s.delegate = self
            session = s
            say("collects \(builder.dataSource!.typesToCollect.map { HKObjectType.nameOf($0) }.sorted().joined(separator: ","))")
            let start = Date()
            s.startActivity(with: start)
            builder.beginCollection(withStart: start) { ok, error in say("collection began \(ok) \(error.map { "\($0)" } ?? "")") }
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
        } catch {
            say("session error \(error)")
        }
    }
    @available(iOS 26.0, *)
    func refresh() {
        guard let b = session?.associatedWorkoutBuilder() else { return }
        elapsed = b.elapsedTime
        heart = b.statistics(for: heartRate)?.mostRecentQuantity()?.doubleValue(for: bpm) ?? 0
        kcal = stat(b.statistics(for: energy), .kilocalorie(), sum: true)
        meters = stat(b.statistics(for: distance), .meter(), sum: true)
        guard check, let s = session else { return }
        // the automated run: 4 s, a pause, 2 more seconds, then the end
        if s.state == .running, elapsed >= 4, !collected.contains("paused") { collected.insert("paused"); s.pause() }
        if s.state == .running, elapsed >= 6 { s.end() }
    }
    func pauseOrResume() {
        guard let s = session else { return }
        if s.state == .paused { s.resume() } else { s.pause() }
    }
    func end() { session?.end() }

    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        let names: [HKWorkoutSessionState: String] = [.notStarted: "not started", .prepared: "prepared", .running: "running", .paused: "paused",
                                                      .stopped: "stopped", .ended: "ended"]
        say("session \(names[fromState]!) -> \(names[toState]!)")
        DispatchQueue.main.async {
            self.state = names[toState]!.capitalized
            if toState == .paused, self.check {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { workoutSession.resume() }
            }
        }
        guard #available(iOS 26.0, *), toState == .ended else { return }
        let builder = workoutSession.associatedWorkoutBuilder()
        builder.endCollection(withEnd: date) { _, _ in
            builder.finishWorkout { w, error in
                guard let w else { say("finish error \(error.map { "\($0)" } ?? "")"); return }
                let events = (w.workoutEvents ?? []).map { $0.type == .pause ? "pause" : $0.type == .resume ? "resume" : "other" }
                say(String(format: "live saved duration=%.0f hr=%.0f energy=%.1f distance=%.0f events=%@ samples=%@", w.duration,
                           stat(w.statistics(for: heartRate), bpm, sum: false), stat(w.statistics(for: energy), .kilocalorie(), sum: true),
                           stat(w.statistics(for: distance), .meter(), sum: true), events.joined(separator: ","),
                           w.duration > 4 && (w.statistics(for: heartRate)?.averageQuantity() != nil) ? "yes" : "no"))
                DispatchQueue.main.async {
                    self.timer?.invalidate()
                    self.history.insert(String(format: "Live run · %.0f s · %.0f m", w.duration, stat(w.statistics(for: distance), .meter(), sum: true)), at: 0)
                }
            }
        }
    }
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) { say("session failed \(error)") }
    func workoutSession(_ workoutSession: HKWorkoutSession, didGenerate event: HKWorkoutEvent) {
        say("event \(event.type == .pause ? "pause" : event.type == .resume ? "resume" : "\(event.type.rawValue)")")
    }
}

@available(iOS 26.0, *)
extension WorkoutModel: HKLiveWorkoutBuilderDelegate {
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for t in collectedTypes where !collected.contains(t.identifier) {
            collected.insert(t.identifier)
            say("collected \(HKObjectType.nameOf(t))")
        }
        DispatchQueue.main.async { self.refresh() }
    }
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        say("builder events \(workoutBuilder.workoutEvents.count)")
    }
}

extension HKObjectType {
    static func nameOf(_ t: HKObjectType) -> String {
        t.identifier.replacingOccurrences(of: "HKQuantityTypeIdentifier", with: "")
    }
}

struct ContentView: View {
    @ObservedObject var model: WorkoutModel
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Duration.seconds(model.elapsed).formatted(.time(pattern: .minuteSecond)))
                            .font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(.yellow)
                            .accessibilityIdentifier("elapsed")
                        metric("heart.fill", .red, "\(Int(model.heart)) BPM", "heart")
                        metric("flame.fill", .pink, String(format: "%.0f CAL", model.kcal), "energy")
                        metric("figure.run", .green, String(format: "%.2f KM", model.meters / 1000), "distance")
                    }
                    .padding(.vertical, 6)
                    HStack {
                        Text(model.state).foregroundStyle(.secondary).accessibilityIdentifier("state")
                        Spacer()
                        Button(model.state == "Paused" ? "Resume" : "Pause") { model.pauseOrResume() }.accessibilityIdentifier("pause")
                        Button("End", role: .destructive) { model.end() }.accessibilityIdentifier("end")
                    }
                    .buttonStyle(.bordered)
                }
                Section("History") {
                    ForEach(model.history, id: \.self) { Text($0) }
                }
            }
            .navigationTitle("Outdoor Run")
            .task { model.start() }
        }
    }
    func metric(_ symbol: String, _ color: Color, _ text: String, _ id: String) -> some View {
        Label { Text(text).font(.title2.weight(.semibold)).monospacedDigit() } icon: { Image(systemName: symbol).foregroundStyle(color) }
            .accessibilityIdentifier(id)
    }
}
