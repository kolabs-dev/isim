// HelloSiri's Intents extension, continued (issue #411): paying members back and asking them for money (payments), the
// club car (ride options, booking, its status with live updates, cancelling, feedback), workouts (handled in the app:
// .handleInApp) and the club's photo albums (continued in the app).
import Intents
import CoreLocation

let card = INPaymentMethod(type: .credit, name: "Club Card", identificationHint: "•• 4242", icon: nil)
let rideOptions: [(name: String, low: Double, high: Double, minutes: Double)] = [("Club Car", 12, 15, 4), ("Club XL", 18, 22, 7)]

extension IntentHandler: INSendPaymentIntentHandling, INRequestPaymentIntentHandling, INRidesharingDomainHandling, INWorkoutsDomainHandling,
                         INSearchForPhotosIntentHandling, INStartPhotoPlaybackIntentHandling {
    // MARK: payments
    func member(for p: INPerson?) -> INPersonResolutionResult {
        guard let p else { return .needsValue() }
        let found = membersMatching(p)
        return found.count == 1 ? .success(with: person(found[0])) : found.isEmpty ? .unsupported() : .disambiguation(with: found.map(person))
    }
    func resolvePayee(for intent: INSendPaymentIntent, with completion: @escaping (INSendPaymentPayeeResolutionResult) -> Void) {
        let r = member(for: intent.payee)
        completion(intent.payee != nil && membersMatching(intent.payee!).isEmpty ? .unsupported(forReason: .noAccount) : INSendPaymentPayeeResolutionResult(personResolutionResult: r))
    }
    func amount(_ a: INCurrencyAmount?) -> (INCurrencyAmountResolutionResult, Int) {
        guard let a, let v = a.amount?.doubleValue else { return (.needsValue(), 0) }
        if a.currencyCode != "USD" { return (.unsupported(), 3) }            // ...CurrencyUnsupported
        if v > 500 { return (.unsupported(), 2) }                             // ...AmountAboveMaximum
        return (.success(with: a), 0)
    }
    func resolveCurrencyAmount(for intent: INSendPaymentIntent, with completion: @escaping (INSendPaymentCurrencyAmountResolutionResult) -> Void) {
        let (r, reason) = amount(intent.currencyAmount)
        log("extension: amount \(intent.currencyAmount?.amount ?? 0) \(intent.currencyAmount?.currencyCode ?? "")")
        completion(reason == 3 ? .unsupported(forReason: .paymentsCurrencyUnsupported) : reason == 2 ? .unsupported(forReason: .paymentsAmountAboveMaximum)
                   : INSendPaymentCurrencyAmountResolutionResult(currencyAmountResolutionResult: r))
    }
    func resolveNote(for intent: INSendPaymentIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(intent.note.map { .success(with: $0) } ?? .notRequired())
    }
    func confirm(intent: INSendPaymentIntent, completion: @escaping (INSendPaymentIntentResponse) -> Void) {
        let r = INSendPaymentIntentResponse(code: .ready, userActivity: nil)
        r.paymentRecord = INPaymentRecord(payee: intent.payee, payer: nil, currencyAmount: intent.currencyAmount, paymentMethod: card, note: intent.note,
                                          status: .pending, feeAmount: INCurrencyAmount(amount: NSDecimalNumber(string: "0.25"), currencyCode: "USD"))
        completion(r)
    }
    func handle(intent: INSendPaymentIntent, completion: @escaping (INSendPaymentIntentResponse) -> Void) {
        let who = intent.payee?.displayName ?? "?", amt = intent.currencyAmount?.amount?.stringValue ?? "?"
        paymentLog.append("sent \(who) $\(amt)\(intent.note.map { " for \($0)" } ?? "")")
        log("extension: paid \(who) $\(amt) for \(intent.note ?? "-")")
        let r = INSendPaymentIntentResponse(code: .success, userActivity: nil)
        r.paymentRecord = INPaymentRecord(payee: intent.payee, payer: nil, currencyAmount: intent.currencyAmount, paymentMethod: card, note: intent.note, status: .completed)
        completion(r)
    }
    func resolvePayer(for intent: INRequestPaymentIntent, with completion: @escaping (INRequestPaymentPayerResolutionResult) -> Void) {
        completion(INRequestPaymentPayerResolutionResult(personResolutionResult: member(for: intent.payer)))
    }
    func resolveCurrencyAmount(for intent: INRequestPaymentIntent, with completion: @escaping (INRequestPaymentCurrencyAmountResolutionResult) -> Void) {
        let (r, reason) = amount(intent.currencyAmount)
        completion(reason == 3 ? .unsupported(forReason: .paymentsCurrencyUnsupported) : reason == 2 ? .unsupported(forReason: .paymentsAmountAboveMaximum)
                   : INRequestPaymentCurrencyAmountResolutionResult(currencyAmountResolutionResult: r))
    }
    func handle(intent: INRequestPaymentIntent, completion: @escaping (INRequestPaymentIntentResponse) -> Void) {
        let who = intent.payer?.displayName ?? "?", amt = intent.currencyAmount?.amount?.stringValue ?? "?"
        paymentLog.append("requested $\(amt) from \(who)")
        log("extension: requested $\(amt) from \(who)")
        let r = INRequestPaymentIntentResponse(code: .success, userActivity: nil)
        r.paymentRecord = INPaymentRecord(payee: nil, payer: intent.payer, currencyAmount: intent.currencyAmount, paymentMethod: card, note: intent.note, status: .pending)
        completion(r)
    }

    // MARK: the club car
    func place(_ p: CLPlacemark?) -> INPlacemarkResolutionResult {
        guard let p else { return .needsValue() }
        return p.location == nil ? .unsupported() : .success(with: p)       // only places it can find
    }
    func resolvePickupLocation(for intent: INListRideOptionsIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) { completion(place(intent.pickupLocation)) }
    func resolveDropOffLocation(for intent: INListRideOptionsIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) { completion(place(intent.dropOffLocation)) }
    func handle(intent: INListRideOptionsIntent, completion: @escaping (INListRideOptionsIntentResponse) -> Void) {
        let r = INListRideOptionsIntentResponse(code: .success, userActivity: nil)
        r.rideOptions = rideOptions.map { o in
            let opt = INRideOption(name: o.name, estimatedPickupDate: Date(timeIntervalSinceNow: o.minutes * 60))
            opt.priceRange = INPriceRange(firstPrice: NSDecimalNumber(value: o.low), secondPrice: NSDecimalNumber(value: o.high), currencyCode: "USD")
            opt.usesMeteredFare = false
            opt.identifier = o.name
            return opt
        }
        r.paymentMethods = [card]
        r.expirationDate = Date(timeIntervalSinceNow: 300)
        log("extension: \(r.rideOptions?.count ?? 0) ride options to \(intent.dropOffLocation?.name ?? "?") from \(intent.pickupLocation?.name ?? "?")")
        completion(r)
    }
    func resolvePickupLocation(for intent: INRequestRideIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) { completion(place(intent.pickupLocation)) }
    func resolveDropOffLocation(for intent: INRequestRideIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) { completion(place(intent.dropOffLocation)) }
    func resolveRideOptionName(for intent: INRequestRideIntent, with completion: @escaping (INSpeakableStringResolutionResult) -> Void) {
        guard let name = intent.rideOptionName else { completion(.notRequired()); return }       // Siri lists the options
        let known = rideOptions.first { $0.name.lowercased() == name.spokenPhrase.lowercased() || $0.name.lowercased() == "club \(name.spokenPhrase.lowercased())" }
        completion(known.map { .success(with: INSpeakableString(spokenPhrase: $0.name)) } ?? .unsupported())
    }
    func resolvePartySize(for intent: INRequestRideIntent, with completion: @escaping (INIntegerResolutionResult) -> Void) {
        guard let n = intent.partySize else { completion(.notRequired()); return }
        completion(n > 6 ? .unsupported() : .success(with: n))
    }
    func status(_ phase: INRidePhase, intent: INRequestRideIntent? = nil) -> INRideStatus {
        let s = INRideStatus()
        s.rideIdentifier = currentRide?["id"] ?? "ride-1"
        s.phase = phase
        let option = intent?.rideOptionName?.spokenPhrase ?? currentRide?["option"] ?? "Club Car"
        let o = rideOptions.first { $0.name == option } ?? rideOptions[0]
        s.rideOption = INRideOption(name: o.name, estimatedPickupDate: Date(timeIntervalSinceNow: o.minutes * 60))
        s.estimatedPickupDate = phase == .pickup ? Date() : Date(timeIntervalSinceNow: (phase == .approachingPickup ? 1 : o.minutes) * 60)
        var n = PersonNameComponents(); n.givenName = "Sam"; n.familyName = "Rivera"
        s.driver = INRideDriver(phoneNumber: "+1 555 0100", nameComponents: n, displayName: "Sam Rivera", image: nil, rating: "4.9")
        let car = INRideVehicle()
        car.manufacturer = "Toyota"; car.model = "Prius"; car.registrationPlate = "7CLB123"
        car.location = CLLocation(latitude: 37.3318, longitude: -122.0312)
        s.vehicle = car
        s.pickupLocation = intent?.pickupLocation
        s.dropOffLocation = intent?.dropOffLocation ?? knownPlace(currentRide?["to"])
        return s
    }
    func confirm(intent: INRequestRideIntent, completion: @escaping (INRequestRideIntentResponse) -> Void) {
        let r = INRequestRideIntentResponse(code: .ready, userActivity: nil)
        let s = INRideStatus()
        let o = rideOptions.first { $0.name == intent.rideOptionName?.spokenPhrase } ?? rideOptions[0]
        s.rideOption = INRideOption(name: o.name, estimatedPickupDate: Date(timeIntervalSinceNow: o.minutes * 60))
        s.rideOption?.priceRange = INPriceRange(firstPrice: NSDecimalNumber(value: o.low), secondPrice: NSDecimalNumber(value: o.high), currencyCode: "USD")
        r.rideStatus = s
        completion(r)
    }
    func handle(intent: INRequestRideIntent, completion: @escaping (INRequestRideIntentResponse) -> Void) {
        let option = intent.rideOptionName?.spokenPhrase ?? "Club Car", to = intent.dropOffLocation?.name ?? "?"
        currentRide = ["id": "ride-\(Int(Date().timeIntervalSince1970) % 10000)", "option": option, "to": to, "phase": "confirmed"]
        log("extension: booked \(option) to \(to) from \(intent.pickupLocation?.name ?? "?") for \(intent.partySize.map(String.init) ?? "-") with \(intent.paymentMethod?.name ?? "-")")
        let r = INRequestRideIntentResponse(code: .success, userActivity: nil)
        r.rideStatus = status(.confirmed, intent: intent)
        completion(r)
    }
    func handle(intent: INGetRideStatusIntent, completion: @escaping (INGetRideStatusIntentResponse) -> Void) {
        guard currentRide != nil else { log("extension: no ride"); completion(INGetRideStatusIntentResponse(code: .failure, userActivity: nil)); return }
        let r = INGetRideStatusIntentResponse(code: .success, userActivity: nil)
        r.rideStatus = status(.confirmed)
        log("extension: ride status \(r.rideStatus?.rideIdentifier ?? "?")")
        completion(r)
    }
    func startSendingUpdates(for intent: INGetRideStatusIntent, to observer: INGetRideStatusIntentResponseObserver) {
        log("extension: sending ride updates")
        for (i, phase) in [INRidePhase.approachingPickup, .pickup].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(800 * (i + 1))) { [weak self] in
                guard let self, rideUpdating else { return }
                let r = INGetRideStatusIntentResponse(code: .success, userActivity: nil)
                r.rideStatus = self.status(phase)
                observer.didUpdate(getRideStatus: r)
            }
        }
        rideUpdating = true
    }
    func stopSendingUpdates(for intent: INGetRideStatusIntent) { rideUpdating = false; log("extension: stopped ride updates") }
    func handle(cancelRide intent: INCancelRideIntent, completion: @escaping (INCancelRideIntentResponse) -> Void) {
        guard let ride = currentRide, ride["id"] == intent.rideIdentifier else {
            log("extension: no ride \(intent.rideIdentifier) to cancel"); completion(INCancelRideIntentResponse(code: .failure, userActivity: nil)); return
        }
        currentRide = nil
        log("extension: cancelled \(intent.rideIdentifier)")
        completion(INCancelRideIntentResponse(code: .success, userActivity: nil))
    }
    func handle(sendRideFeedback intent: INSendRideFeedbackIntent, completion: @escaping (INSendRideFeedbackIntentResponse) -> Void) {
        log("extension: feedback for \(intent.rideIdentifier): rating \(intent.rating?.stringValue ?? "-"), tip \(intent.tip?.amount?.stringValue ?? "-")")
        completion(INSendRideFeedbackIntentResponse(code: .success, userActivity: nil))
    }

    // MARK: workouts (the app runs them: .handleInApp)
    func resolveWorkoutName(for intent: INStartWorkoutIntent, with completion: @escaping (INSpeakableStringResolutionResult) -> Void) {
        completion(intent.workoutName.map { .success(with: $0) } ?? .needsValue())
    }
    func resolveGoalValue(for intent: INStartWorkoutIntent, with completion: @escaping (INDoubleResolutionResult) -> Void) {
        completion(intent.goalValue.map { .success(with: $0) } ?? .notRequired())
    }
    func resolveWorkoutLocationType(for intent: INStartWorkoutIntent, with completion: @escaping (INWorkoutLocationTypeResolutionResult) -> Void) {
        completion(.success(with: intent.workoutLocationType == .unknown ? .outdoor : intent.workoutLocationType))
    }
    func handle(intent: INStartWorkoutIntent, completion: @escaping (INStartWorkoutIntentResponse) -> Void) {
        if workout?["state"] == "running" { completion(INStartWorkoutIntentResponse(code: .failureOngoingWorkout, userActivity: nil)); return }
        log("extension: start \(intent.workoutName?.spokenPhrase ?? "?") \(intent.goalValue.map { "\($0)" } ?? "open") unit \(intent.workoutGoalUnitType.rawValue) location \(intent.workoutLocationType.rawValue)")
        completion(INStartWorkoutIntentResponse(code: .handleInApp, userActivity: nil))
    }
    func control(_ name: String, _ ok: Bool) -> Bool {
        let has = workout != nil && ok
        log("extension: \(name) workout: \(has ? "handled in the app" : "none")")
        return has
    }
    func handle(intent: INPauseWorkoutIntent, completion: @escaping (INPauseWorkoutIntentResponse) -> Void) {
        completion(INPauseWorkoutIntentResponse(code: control("pause", workout?["state"] == "running") ? .handleInApp : .failureNoMatchingWorkout, userActivity: nil))
    }
    func handle(intent: INResumeWorkoutIntent, completion: @escaping (INResumeWorkoutIntentResponse) -> Void) {
        completion(INResumeWorkoutIntentResponse(code: control("resume", workout?["state"] == "paused") ? .handleInApp : .failureNoMatchingWorkout, userActivity: nil))
    }
    func handle(intent: INEndWorkoutIntent, completion: @escaping (INEndWorkoutIntentResponse) -> Void) {
        completion(INEndWorkoutIntentResponse(code: control("end", true) ? .handleInApp : .failureNoMatchingWorkout, userActivity: nil))
    }
    func handle(intent: INCancelWorkoutIntent, completion: @escaping (INCancelWorkoutIntentResponse) -> Void) {
        completion(INCancelWorkoutIntentResponse(code: control("cancel", true) ? .handleInApp : .failureNoMatchingWorkout, userActivity: nil))
    }

    // MARK: the club's photos (continued in the app)
    func resolvePeopleInPhoto(for intent: INSearchForPhotosIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        completion((intent.peopleInPhoto ?? []).map { member(for: $0) })
    }
    func resolveLocationCreated(for intent: INSearchForPhotosIntent, with completion: @escaping (INPlacemarkResolutionResult) -> Void) {
        completion(intent.locationCreated.map { .success(with: $0) } ?? .notRequired())
    }
    func resolveAlbumName(for intent: INSearchForPhotosIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(album(intent.albumName))
    }
    func album(_ name: String?) -> INStringResolutionResult {
        guard let name else { return .notRequired() }
        let found = Set(clubPhotos.map(\.album)).first { $0.lowercased() == name.lowercased() }
        return found.map { .success(with: $0) } ?? .unsupported()
    }
    func matches(album: String?, place: CLPlacemark?, people: [INPerson]?, terms: [String]?, date: INDateComponentsRange?) -> [ClubPhoto] {
        clubPhotos.filter { p in
            (album == nil || p.album == album) && (place?.name == nil || p.place == place?.name) &&
            (people ?? []).allSatisfy { who in p.people.contains(who.displayName) } && (terms ?? []).allSatisfy { p.tags.contains($0.lowercased()) } &&
            (date?.startDateComponents?.year == nil || p.year == date?.startDateComponents?.year)
        }
    }
    func handle(intent: INSearchForPhotosIntent, completion: @escaping (INSearchForPhotosIntentResponse) -> Void) {
        let found = matches(album: intent.albumName, place: intent.locationCreated, people: intent.peopleInPhoto, terms: intent.searchTerms, date: intent.dateCreated)
        log("extension: \(found.count) photo(s) album \(intent.albumName ?? "-") place \(intent.locationCreated?.name ?? "-") people \((intent.peopleInPhoto ?? []).map(\.displayName).joined(separator: ",")) terms \((intent.searchTerms ?? []).joined(separator: ","))")
        let r = INSearchForPhotosIntentResponse(code: .continueInApp, userActivity: nil)
        r.searchResultsCount = found.count
        completion(r)
    }
    func resolveAlbumName(for intent: INStartPhotoPlaybackIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        completion(album(intent.albumName))
    }
    func handle(intent: INStartPhotoPlaybackIntent, completion: @escaping (INStartPhotoPlaybackIntentResponse) -> Void) {
        let found = matches(album: intent.albumName, place: intent.locationCreated, people: intent.peopleInPhoto, terms: nil, date: intent.dateCreated)
        log("extension: slideshow of \(found.count) photo(s)")
        let r = INStartPhotoPlaybackIntentResponse(code: .continueInApp, userActivity: nil)
        r.searchResultsCount = found.count
        completion(r)
    }
}

/// whether the app is sending ride status updates to Siri
var rideUpdating = false
/// the booked ride's destination, as the app remembers it (nil when there is none)
func knownPlace(_ name: String?) -> CLPlacemark? {
    guard let name else { return nil }
    return CLPlacemark(location: CLLocation(latitude: 37.3349, longitude: -122.009), name: name, postalAddress: nil)
}
