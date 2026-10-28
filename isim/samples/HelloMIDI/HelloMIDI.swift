// Sample: CoreMIDI on isim. A MIDI monitor: it lists the endpoints, listens to every source in MIDI 2.0 (the
// `midi` script command plays the simulated "isim MIDI" device) and logs what it hears and the setup's
// notifications. On launch it also checks, and logs:
// - sending to the isim MIDI destination (logged by CoreMIDI as "isim MIDI received ...");
// - a virtual source and destination, a thru connection between them (channel map, transposition, a filter);
// - a system-exclusive message sent in the background (MIDISendSysex), MIDI 2.0 messages down-converted for a
//   MIDI 1.0 destination, the packet and event list builders, a UMP endpoint and the network session.
import UIKit
import CoreMIDI

private func log(_ s: String) { NSLog("HelloMIDI: %@", s) }

func name(_ obj: MIDIObjectRef) -> String {
    var s: Unmanaged<CFString>?
    guard MIDIObjectGetStringProperty(obj, kMIDIPropertyDisplayName, &s) == noErr, let v = s?.takeRetainedValue() else { return "?" }
    return v as String
}
func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02X", $0) }.joined(separator: " ") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MonitorViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class MonitorViewController: UIViewController {
    var client = MIDIClientRef(), input = MIDIPortRef(), output = MIDIPortRef()
    var virtualSource = MIDIEndpointRef(), virtualDest = MIDIEndpointRef(), legacyDest = MIDIEndpointRef()
    let label = UILabel()
    var lines: [String] = []

    func show(_ s: String) {
        log(s)
        DispatchQueue.main.async {
            self.lines = Array((self.lines + [s]).suffix(18))
            self.label.text = self.lines.joined(separator: "\n")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        label.frame = view.bounds.insetBy(dx: 16, dy: 70)
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .green
        label.accessibilityIdentifier = "monitor"
        view.addSubview(label)
        setUpMIDI()
    }

    func setUpMIDI() {
        var st = MIDIClientCreateWithBlock("MIDI Monitor" as CFString, &client) { [weak self] n in
            switch n.pointee.messageID {
            case .msgSetupChanged: self?.show("setup changed")
            case .msgObjectAdded, .msgObjectRemoved:
                n.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
                    self?.show("\($0.pointee.messageID == .msgObjectAdded ? "added" : "removed") \(name($0.pointee.child)) type=\($0.pointee.childType.rawValue)")
                }
            case .msgPropertyChanged:
                n.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
                    self?.show("property \($0.pointee.propertyName.takeUnretainedValue()) of \(name($0.pointee.object))")
                }
            default: break
            }
        }
        log("client status=\(st)")
        // the endpoints
        log("sources=\(MIDIGetNumberOfSources()) destinations=\(MIDIGetNumberOfDestinations()) devices=\(MIDIGetNumberOfDevices())")
        for i in 0..<MIDIGetNumberOfSources() { log("source \(name(MIDIGetSource(i)))") }
        let device = MIDIGetDevice(0), entity = MIDIDeviceGetEntity(device, 0)
        var manufacturer: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(MIDIEntityGetSource(entity, 0), kMIDIPropertyManufacturer, &manufacturer)
        var uid: Int32 = 0, offline: Int32 = -1
        MIDIObjectGetIntegerProperty(device, kMIDIPropertyUniqueID, &uid)
        MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &offline)
        log("device \(name(device)) entities=\(MIDIDeviceGetNumberOfEntities(device)) manufacturer=\(manufacturer?.takeRetainedValue() ?? "-" as CFString) offline=\(offline) uid=\(uid != 0)")

        // listen to every source, in MIDI 2.0
        st = MIDIInputPortCreateWithProtocol(client, "Input" as CFString, ._2_0, &input) { [weak self] list, refCon in
            let from = Int(bitPattern: refCon)
            self?.describe(list, from: from)
        }
        for i in 0..<MIDIGetNumberOfSources() { MIDIPortConnectSource(input, MIDIGetSource(i), UnsafeMutableRawPointer(bitPattern: i + 1)) }
        log("input status=\(st) protocol 2.0")

        // to the isim MIDI destination, with a packet list built in Swift
        MIDIOutputPortCreate(client, "Output" as CFString, &output)
        let isimDest = MIDIEntityGetDestination(entity, 0)
        let packets = MIDIPacketList.Builder(byteSize: 128)
        packets.append(timestamp: 0, data: [0x90, 0x3C, 0x64])
        packets.append(timestamp: 0, data: [0x80, 0x3C, 0x00])
        packets.withUnsafePointer { st = MIDISend(output, isimDest, $0) }
        log("sent to \(name(isimDest)) packets=\(packets.count) status=\(st)")

        // a virtual source and destination, and a thru connection between them
        MIDISourceCreateWithProtocol(client, "Monitor Out" as CFString, ._1_0, &virtualSource)
        MIDIDestinationCreateWithBlock(client, "Monitor In" as CFString, &virtualDest) { [weak self] list, _ in
            for p in list.unsafeSequence() { self?.show("virtual destination got \(hex(Array(p.bytes())))") }
        }
        var params = MIDIThruConnectionParams()
        MIDIThruConnectionParamsInitialize(&params)
        params.numSources = 1; params.sources.0.endpointRef = virtualSource
        params.numDestinations = 1; params.destinations.0.endpointRef = virtualDest
        params.channelMap.0 = 3                                          // channel 1 to channel 4
        params.noteNumber = MIDITransform(transform: .add, param: 12)    // an octave up
        params.filterOutAllControls = 1
        var thru = MIDIThruConnectionRef()
        let data = withUnsafeBytes(of: &params) { Data($0) } as CFData
        st = MIDIThruConnectionCreate(nil, data, &thru)
        log("thru status=\(st)")
        let notes = MIDIEventList.Builder(inProtocol: ._1_0, wordSize: 16)
        notes.append(timestamp: 0, words: [MIDI1UPNoteOn(0, 0, 60, 100)])
        notes.append(timestamp: 0, words: [MIDI1UPControlChange(0, 0, 7, 90)])
        notes.withUnsafePointer { st = MIDIReceivedEventList(virtualSource, $0) }

        // MIDI 2.0 messages to a MIDI 1.0 destination: down-converted
        MIDIDestinationCreateWithProtocol(client, "Legacy" as CFString, ._1_0, &legacyDest) { [weak self] list, _ in
            for p in list.unsafeSequence() { self?.show("legacy got \(p.words().map { String(format: "%08X", $0) }.joined(separator: " "))") }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.secondSteps() }
    }

    func secondSteps() {
        let m2 = MIDI2NoteOn(0, 1, 64, 0, 0xFFFF, 0), pb = MIDI2PitchBend(0, 1, 0x80000000)
        let up = MIDIEventList.Builder(inProtocol: ._2_0, wordSize: 16)
        up.append(timestamp: 0, words: [m2.word0, m2.word1, pb.word0, pb.word1])
        up.withUnsafePointer { _ = MIDISendEventList(output, legacyDest, $0) }

        // system-exclusive, in the background
        let sysex: [UInt8] = [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7]
        let request = UnsafeMutablePointer<MIDISysexSendRequest>.allocate(capacity: 1)
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: sysex.count)
        bytes.initialize(from: sysex, count: sysex.count)
        request.initialize(to: MIDISysexSendRequest(destination: virtualDest, data: bytes, bytesToSend: UInt32(sysex.count), complete: false,
                                                    reserved: (0, 0, 0), completionProc: { r in NSLog("HelloMIDI: sysex complete=%d left=%u", r.pointee.complete.boolValue ? 1 : 0, r.pointee.bytesToSend) },
                                                    completionRefCon: nil))
        log("sysex status=\(MIDISendSysex(request))")

        // the builders and collections
        let packet = MIDIPacket.Builder(maximumNumberMIDIBytes: 8)
        packet.append(0xB0, 0x07, 0x64)
        packet.timeStamp = 42
        let collected = packet.withUnsafePointer { Array(MIDIPacket.ByteCollection($0)) }
        let words = MIDIEventPacket.Builder(maximumNumberMIDIWords: 4)
        words.append(MIDI1UPNoteOn(0, 0, 60, 1))
        log("builders bytes=\(hex(collected)) time=\(packet.timeStamp) words=\(words.count) type=\(MIDIMessageTypeForUPWord(MIDI1UPNoteOn(0, 0, 60, 1)).rawValue)")

        // a UMP endpoint, and the network session
        let info = MIDI2DeviceInfo(manufacturerID: MIDI2DeviceManufacturer(sysExIDByte: (0x7D, 0, 0)), family: 1, modelNumber: 2,
                                   revisionLevel: MIDI2DeviceRevisionLevel(revisionLevel: (1, 0, 0, 0)))
        if let endpoint = MIDIUMPMutableEndpoint(name: "Monitor UMP", deviceInfo: info, productInstanceID: "1", midiProtocol: ._2_0, destinationCallback: { _, _ in }) {
            let block = MIDIUMPMutableFunctionBlock(name: "Keys", direction: .bidirectional, firstGroup: 0, totalGroupsSpanned: 1, maxSysEx8Streams: 0,
                                                    midi1Info: .notMIDI1, uiHint: .senderReceiver, isEnabled: true)!
            try? endpoint.registerFunctionBlocks([block], markAsStatic: true)
            try? endpoint.setEnabled(true)
            log("ump endpoints=\(MIDIUMPEndpointManager.shared.umpEndpoints.map(\.name)) blocks=\(endpoint.functionBlocks.count) source=\(endpoint.midiSource != 0)")
        }
        let session = MIDINetworkSession.default()
        session.isEnabled = true
        session.addContact(MIDINetworkHost(name: "Studio", address: "192.168.1.20", port: 5004))
        log("network enabled=\(session.isEnabled) contacts=\(session.contacts().count) source=\(name(session.sourceEndpoint()))")
        log("ready")
    }

    func describe(_ list: UnsafePointer<MIDIEventList>, from: Int) {
        final class Box { var out: [String] = [] }
        let box = Box()
        MIDIEventListForEachEvent(list, { ctx, _, m in
            let b = Unmanaged<Box>.fromOpaque(ctx).takeUnretainedValue()
            switch m.type {
            case .channelVoice2:
                let v = m.channelVoice2
                switch v.status {
                case .noteOn: b.out.append("note on \(v.note.number) velocity \(String(format: "%04X", v.note.velocity)) channel \(v.channel + 1)")
                case .noteOff: b.out.append("note off \(v.note.number) channel \(v.channel + 1)")
                case .controlChange: b.out.append("control \(v.controlChange.index) \(String(format: "%08X", v.controlChange.data))")
                default: b.out.append("channel voice \(v.status.rawValue)")
                }
            case .sysEx: b.out.append("sysex \(m.sysEx.channel) bytes")
            case .system: b.out.append("system \(String(format: "%02X", m.system.status.rawValue))")
            default: b.out.append("type \(m.type.rawValue)")
            }
        }, Unmanaged.passUnretained(box).toOpaque())
        for s in box.out { show("from \(from == 1 ? "isim MIDI" : "source \(from)"): \(s) (MIDI \(list.pointee.protocol == ._2_0 ? "2.0" : "1.0"))") }
    }
}
