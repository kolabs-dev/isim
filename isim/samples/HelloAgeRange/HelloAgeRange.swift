// Sample: age assurance and parental permission on isim (issue #397). DeclaredAgeRange asks for the account's age
// range (`isim agerange set <age>` sets it), PermissionKit asks a parent to allow talking to a friend (`isim permission
// <app> approve|decline` answers as the parent), and AppTrackingTransparency's expanded prompt (iOS 27.2) has a
// "Learn More" action. Every answer is printed; tests/ui/test_agerange.py checks them.
import SwiftUI
import DeclaredAgeRange
import PermissionKit
import AppTrackingTransparency

@main
struct HelloAgeRangeApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

let friend = CommunicationHandle(value: "sam@example.com", kind: .emailAddress)

struct ContentView: View {
    @Environment(\.requestAgeRange) var requestAgeRange
    @State private var status = "ready"
    var body: some View {
        List {
            Text(status).accessibilityIdentifier("status")
            Button("Age range") {
                Task {
                    do {
                        switch try await requestAgeRange(ageGates: 13, 16, 18) {
                        case .sharing(let r):
                            report("age range: \(r.lowerBound.map(String.init) ?? "nil")-\(r.upperBound.map(String.init) ?? "nil") declaration \(r.ageRangeDeclaration.map { "\($0)" } ?? "nil") controls \(r.activeParentalControls)")
                        case .declinedSharing: report("age range: declined")
                        @unknown default: report("age range: unknown")
                        }
                    } catch { report("age range: error \(error)") }
                }
            }.accessibilityIdentifier("age")
            Button("Ask to talk to Sam") {
                Task {
                    guard let vc = topController() else { return }
                    let question = PermissionQuestion<CommunicationTopic>(handle: friend)
                    do { try await AskCenter.shared.ask(question, in: vc); report("ask: sent \(question.id.uuidString.prefix(8))") }
                    catch { report("ask: error \(error)") }
                }
            }.accessibilityIdentifier("ask")
            Button("Is Sam known") {
                Task { report("known: \(await CommunicationLimits.current.isKnownHandle(friend))") }
            }.accessibilityIdentifier("known")
            Button("Track (expanded)") {
                if #available(iOS 27.2, *) {
                    ATTrackingManager.requestTrackingAuthorization(preferExpandedInterface: true, additionalInformationAction: { print("tracking: learn more") }) { s in
                        print("tracking: status \(s.rawValue)")
                    }
                } else { report("tracking: needs iOS 27.2") }
            }.accessibilityIdentifier("track")
        }
        .task {
            let eligible = (try? await AgeRangeService.shared.isEligibleForAgeFeatures) ?? false
            report("age features eligible \(eligible)")
            guard #available(iOS 26.0, *) else { return }
            for await r in AskCenter.shared.responses(for: CommunicationTopic.self) {
                report("response: \(r.choice.answer) for \(r.question.topic.personInformation.map(\.handle.value).joined(separator: ","))")
            }
        }
    }
    func report(_ s: String) { print(s); status = s }
    func topController() -> UIViewController? {
        var top = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}
