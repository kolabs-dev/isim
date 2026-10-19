// HelloAudioModules, -policies: AVAudioSession's modes, options and policies for call and video apps (issue #224),
// each checked by an "as" log line and shown in a list.
// - the modes videoChat, videoRecording, measurement, voicePrompt; the overrideMutedMicrophoneInterruption option
// - RouteSharingPolicy: setCategory(_:mode:policy:options:) (long-form policies need the playback category)
// - prefersNoInterruptionsFromSystemAlerts and overrideMutedMicrophoneInterruption: the `audio interrupt begin alert`
//   and `audio interrupt begin muted` script commands leave the session running; a plain interruption still arrives
// - echo-cancelled input (iOS 18.2): the preference, its availability (play-and-record with the built-in microphone)
import SwiftUI
import AVFAudio
import Darwin

var policyRows: [(String, String)] = []
private func log(_ key: String, _ value: String) { print("as \(key) \(value)"); fflush(stdout); policyRows.append((key, value)) }
nonisolated(unsafe) private var observer: NSObjectProtocol?

func runPolicyChecks() {
    let s = AVAudioSession.sharedInstance()
    let modes: [AVAudioSession.Mode] = [.videoChat, .videoRecording, .measurement, .voicePrompt]
    log("modes", modes.map(\.rawValue).joined(separator: ","))

    // route sharing policies
    do {
        try s.setCategory(.record, mode: .default, policy: .longFormAudio)
        log("policy-record", "accepted")
    } catch { log("policy-record", "error=\((error as NSError).code)") }
    try? s.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
    log("policy-playback", "category=\(s.category.rawValue) policy=\(s.routeSharingPolicy.rawValue)")

    // a video call: muted-microphone interruptions and system alerts don't interrupt it
    try? s.setCategory(.playAndRecord, mode: .videoChat, policy: .default, options: [.defaultToSpeaker, .overrideMutedMicrophoneInterruption])
    try? s.setPrefersNoInterruptionsFromSystemAlerts(true)
    log("call", "mode=\(s.mode.rawValue) options=\(s.categoryOptions.rawValue) policy=\(s.routeSharingPolicy.rawValue) "
        + "noAlertInterruptions=\(s.prefersNoInterruptionsFromSystemAlerts)")

    if #available(iOS 18.2, *) {
        try? s.setPrefersEchoCancelledInput(true)
        log("echo", "prefers=\(s.prefersEchoCancelledInput) available=\(s.isEchoCancelledInputAvailable) enabled=\(s.isEchoCancelledInputEnabled)")
    } else {
        log("echo", "unavailable before iOS 18.2")
    }

    observer = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: s, queue: .main) { n in
        let type = (n.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue ?? 99
        let reason = (n.userInfo?[AVAudioSessionInterruptionReasonKey] as? NSNumber)?.uintValue ?? 0
        log("interruption", type == AVAudioSession.InterruptionType.began.rawValue ? "began reason=\(reason)" : "ended")
    }
    print("as ready")
    fflush(stdout)
}

struct PoliciesView: View {
    let results: [(String, String)]
    var body: some View {
        NavigationStack {
            List(results.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(results[i].0).font(.headline)
                    Text(results[i].1).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Audio Session")
        }
    }
}
