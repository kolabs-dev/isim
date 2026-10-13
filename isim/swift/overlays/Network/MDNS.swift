// isim Network framework: multicast DNS (RFC 6762) and DNS service discovery (RFC 6763) on the host's network, so
// Bonjour services of NWListener / NWBrowser (and MultipeerConnectivity, which uses them) reach other machines and
// other isim devices, like an iPhone on the same Wi-Fi.
//
// Adapted: one responder per app process. It shares UDP port 5353 with the host's own responder (Avahi), answers
// queries for the services this app advertises (PTR, SRV, TXT and the host's IPv4 addresses as A records, under the
// host name "isim-<host>.local"), announces them when they start and says goodbye (TTL 0) when they stop. Browsing
// sends PTR queries (at once, after 1 s and 3 s, then every 20 s) and caches the answers until their TTL runs out.
// The local registry (Listener.swift) stays: apps of the same isim device find each other there at once.
// No probing: a name already seen on the network gets " (2)" before it is announced. ISIM_MDNS=0 turns it off
// (the local registry only, like isim before; the test driver's default).
@_exported import Foundation

final class _NWMDNS: @unchecked Sendable {
    static let enabled = ProcessInfo.processInfo.environment["ISIM_MDNS"] != "0"
    static let shared = _NWMDNS()

    struct Remote: Hashable {
        var name: String, type: String, domain: String
        var target: String? = nil, port: UInt16? = nil, txt: [String: String] = [:], expires: Date
    }

    let lock = NSLock()
    var fd: Int32 = -1
    var started = false
    var remotes: [String: Remote] = [:]                 // lowercased full instance name -> record
    var addresses: [String: [String]] = [:]            // lowercased host name -> IPv4 addresses
    var published: [String: _NWService] = [:]          // lowercased full instance name -> our service
    var browsing: [String: Int] = [:]                  // service type -> browsers
    var queryTimer: DispatchSourceTimer?
    let hostName: String = {
        var b = [CChar](repeating: 0, count: 256)
        gethostname(&b, 255)
        let h = String(cString: b).split(separator: ".").first.map(String.init) ?? "host"
        let clean = String(h.map { $0.isLetter || $0.isNumber ? $0 : "-" })
        return "isim-\(clean.isEmpty ? "host" : clean).local"
    }()

    static func fullName(_ name: String, _ type: String) -> String { "\(name).\(_NWBonjour.normType(type)).local" }
    static func typeName(_ type: String) -> String { "\(_NWBonjour.normType(type)).local" }

    // MARK: socket

    func start() {
        lock.lock(); defer { lock.unlock() }
        guard !started else { return }
        started = true
        let s = socket(AF_INET, SOCK_DGRAM, 0)
        guard s >= 0 else { return }
        var one: Int32 = 1
        setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &one, 4)
        setsockopt(s, SOL_SOCKET, SO_REUSEPORT, &one, 4)
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET); a.sin_port = UInt16(5353).bigEndian
        var bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        if bound != 0 {
            // port 5353 is taken without address reuse: queries still work from another port (answers come back by unicast)
            print("isim: Bonjour: UDP port 5353 is in use (errno \(errno)); multicast DNS from another port")
            a.sin_port = 0
            bound = withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        }
        guard bound == 0 else { close(s); return }
        var req = ip_mreq()
        req.imr_multiaddr.s_addr = UInt32(0xE00000FB).bigEndian      /* 224.0.0.251 */
        if setsockopt(s, IPPROTO_IP, IP_ADD_MEMBERSHIP, &req, socklen_t(MemoryLayout<ip_mreq>.size)) != 0 {
            print("isim: Bonjour: cannot join the multicast DNS group (errno \(errno)): the host has no multicast route")
        }
        var loop: UInt8 = 1, ttl: UInt8 = 255
        setsockopt(s, IPPROTO_IP, IP_MULTICAST_LOOP, &loop, 1)
        setsockopt(s, IPPROTO_IP, IP_MULTICAST_TTL, &ttl, 1)
        fd = s
        let t = Thread { [weak self] in self?.readLoop(s) }
        t.name = "isim.mDNS"
        t.start()
    }

    func sendPacket(_ p: [UInt8], to dest: (UInt32, UInt16)? = nil) {
        guard fd >= 0 else { return }
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET)
        a.sin_addr.s_addr = (dest?.0 ?? UInt32(0xE00000FB)).bigEndian
        a.sin_port = (dest?.1 ?? 5353).bigEndian
        _ = p.withUnsafeBytes { b in withUnsafePointer(to: &a) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            sendto(fd, b.baseAddress, b.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } } }
    }

    func readLoop(_ s: Int32) {
        var buf = [UInt8](repeating: 0, count: 9000)
        while true {
            var from = sockaddr_in(); var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = buf.withUnsafeMutableBytes { b in withUnsafeMutablePointer(to: &from) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(s, b.baseAddress!, b.count, 0, $0, &len) } } }
            if n < 0 { if errno == EINTR { continue }; return }
            guard let m = _DNSMessage(Array(buf[0..<n])) else { continue }
            let src = (UInt32(bigEndian: from.sin_addr.s_addr), UInt16(bigEndian: from.sin_port))
            if m.isResponse { learn(m) } else { answer(m, from: src) }
        }
    }

    // MARK: responder

    /// the host's IPv4 addresses (not loopback; loopback when there is nothing else)
    func localAddresses() -> [[UInt8]] {
        var out: [[UInt8]] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&list) == 0, let first = list {
            var p: UnsafeMutablePointer<ifaddrs>? = first
            while let i = p {
                let f = Int32(i.pointee.ifa_flags)
                if let sa = i.pointee.ifa_addr, Int32(sa.pointee.sa_family) == AF_INET, f & IFF_UP != 0, f & IFF_LOOPBACK == 0 {
                    let a = UnsafeRawPointer(sa).load(as: sockaddr_in.self).sin_addr.s_addr
                    out.append(withUnsafeBytes(of: a) { Array($0) })
                }
                p = i.pointee.ifa_next
            }
            freeifaddrs(first)
        }
        return out.isEmpty ? [[127, 0, 0, 1]] : out
    }

    func records(for s: _NWService, ttl: UInt32) -> (ptr: _DNSRecord, rest: [_DNSRecord]) {
        let full = _NWMDNS.fullName(s.name, s.type)
        let ptr = _DNSRecord(name: _NWMDNS.typeName(s.type), type: 12, flush: false, ttl: ttl, data: .name(full))
        var rest = [_DNSRecord(name: full, type: 33, flush: true, ttl: ttl, data: .srv(port: s.port, target: hostName)),
                    _DNSRecord(name: full, type: 16, flush: true, ttl: ttl, data: .txt(NWTXTRecord(s.txt).data))]
        for a in localAddresses() { rest.append(_DNSRecord(name: hostName, type: 1, flush: true, ttl: ttl, data: .raw(a))) }
        return (ptr, rest)
    }

    /// announces the service (twice, a second apart) and answers queries for it; returns the name it got
    func publish(_ s: _NWService) -> _NWService {
        start()
        var svc = s
        lock.lock()
        let now = Date()
        var n = 2
        while let r = remotes[_NWMDNS.fullName(svc.name, svc.type).lowercased()], r.expires > now, published[_NWMDNS.fullName(svc.name, svc.type).lowercased()] == nil {
            svc = _NWService(name: "\(s.name) (\(n))", type: s.type, domain: s.domain, port: s.port, pid: s.pid, txt: s.txt); n += 1
        }
        published[_NWMDNS.fullName(svc.name, svc.type).lowercased()] = svc
        lock.unlock()
        let (ptr, rest) = records(for: svc, ttl: 120)
        let pkt = _DNSMessage.response(answers: [ptr] + rest)
        sendPacket(pkt)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self else { return }
            self.lock.lock(); let live = self.published[_NWMDNS.fullName(svc.name, svc.type).lowercased()] != nil; self.lock.unlock()
            if live { self.sendPacket(pkt) }
        }
        return svc
    }

    /// stops answering for the service and says goodbye (TTL 0) so browsers drop it at once
    func unpublish(_ s: _NWService) {
        lock.lock(); let had = published.removeValue(forKey: _NWMDNS.fullName(s.name, s.type).lowercased()) != nil; lock.unlock()
        guard had else { return }
        let (ptr, rest) = records(for: s, ttl: 0)
        sendPacket(_DNSMessage.response(answers: [ptr] + rest.filter { $0.type != 1 }))
    }

    func answer(_ m: _DNSMessage, from src: (UInt32, UInt16)) {
        lock.lock(); let ours = Array(published.values); lock.unlock()
        guard !ours.isEmpty else { return }
        var answers: [_DNSRecord] = [], extra: [_DNSRecord] = []
        for q in m.questions {
            let qn = q.name.lowercased()
            if qn == "_services._dns-sd._udp.local", q.type == 12 || q.type == 255 {
                for t in Set(ours.map { _NWMDNS.typeName($0.type) }) {
                    answers.append(_DNSRecord(name: "_services._dns-sd._udp.local", type: 12, flush: false, ttl: 4500, data: .name(t)))
                }
            }
            for s in ours {
                let (ptr, rest) = records(for: s, ttl: 120)
                if qn == _NWMDNS.typeName(s.type).lowercased(), q.type == 12 || q.type == 255 { answers.append(ptr); extra += rest }
                if qn == _NWMDNS.fullName(s.name, s.type).lowercased() {
                    answers += rest.filter { ($0.type == q.type || q.type == 255) && $0.type != 1 }
                    extra += rest.filter { $0.type == 1 }
                }
                if qn == hostName.lowercased(), q.type == 1 || q.type == 255 { answers += rest.filter { $0.type == 1 } }
            }
        }
        guard !answers.isEmpty else { return }
        var seen = Set<String>()
        answers = answers.filter { seen.insert($0.key).inserted }
        extra = extra.filter { seen.insert($0.key).inserted }
        if src.1 != 5353 {
            // a legacy unicast query (RFC 6762 §6.7): answer the sender with its id and question, no cache-flush bits
            sendPacket(_DNSMessage.response(id: m.id, questions: m.questions, answers: answers.map { $0.unicast }, additional: extra.map { $0.unicast }), to: src)
        } else if m.questions.contains(where: { $0.unicastResponse }) {
            sendPacket(_DNSMessage.response(answers: answers, additional: extra), to: src)
        } else {
            sendPacket(_DNSMessage.response(answers: answers, additional: extra))
        }
    }

    // MARK: browser

    func learn(_ m: _DNSMessage) {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        for r in m.answers + m.additional {
            let key = r.name.lowercased()
            switch (r.type, r.data) {
            case (12, .name(let inst)):
                guard let (name, type) = _NWMDNS.split(inst), type.lowercased() + ".local" == key else { continue }
                let k = inst.lowercased()
                if r.ttl == 0 { remotes[k] = nil; continue }
                var rem = remotes[k] ?? Remote(name: name, type: type, domain: "local.", expires: now)
                rem.expires = now.addingTimeInterval(Double(r.ttl))
                remotes[k] = rem
            case (33, .srv(let port, let target)):
                guard let (name, type) = _NWMDNS.split(r.name) else { continue }
                if r.ttl == 0 { remotes[key] = nil; continue }
                var rem = remotes[key] ?? Remote(name: name, type: type, domain: "local.", expires: now.addingTimeInterval(Double(r.ttl)))
                rem.port = port; rem.target = target
                remotes[key] = rem
            case (16, .txt(let d)):
                guard var rem = remotes[key] else { continue }
                rem.txt = NWTXTRecord(d).dictionary
                remotes[key] = rem
            case (1, .raw(let b)) where b.count == 4:
                let a = b.map(String.init).joined(separator: ".")
                if r.ttl == 0 { addresses[key]?.removeAll { $0 == a }; continue }
                if r.flush { addresses[key] = [a] } else if !(addresses[key] ?? []).contains(a) { addresses[key, default: []].append(a) }
            default: break
            }
        }
    }

    /// "Name With.Dots._type._tcp.local" -> ("Name With.Dots", "_type._tcp")
    static func split(_ full: String) -> (String, String)? {
        var labels = full.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        if labels.last == "" { labels.removeLast() }
        guard labels.count >= 4, labels.last?.lowercased() == "local" else { return nil }
        let proto = labels[labels.count - 2], svc = labels[labels.count - 3]
        guard proto.hasPrefix("_"), svc.hasPrefix("_") else { return nil }
        return (labels[0..<(labels.count - 3)].joined(separator: "."), "\(svc).\(proto)")
    }

    func query(_ names: [(String, UInt16)]) { sendPacket(_DNSMessage.query(names)) }

    func browse(_ type: String) {
        start()
        let t = _NWBonjour.normType(type)
        lock.lock()
        browsing[t, default: 0] += 1
        if queryTimer == nil {
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "isim.mDNS.query"))
            var tick = 0
            timer.schedule(deadline: .now() + 1, repeating: 1)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                tick += 1
                guard tick == 2 || tick % 20 == 0 else { return }       /* after 1 s (the first) and 3 s, then every 20 s */
                self.lock.lock(); let types = Array(self.browsing.keys); self.lock.unlock()
                if !types.isEmpty { self.query(types.map { (_NWMDNS.typeName($0), 12) }) }
            }
            timer.resume()
            queryTimer = timer
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self else { return }
                self.lock.lock(); let types = Array(self.browsing.keys); self.lock.unlock()
                if !types.isEmpty { self.query(types.map { (_NWMDNS.typeName($0), 12) }) }
            }
        }
        lock.unlock()
        query([(_NWMDNS.typeName(t), 12)])
    }
    func stopBrowsing(_ type: String) {
        let t = _NWBonjour.normType(type)
        lock.lock(); browsing[t] = (browsing[t] ?? 1) - 1; if browsing[t]! <= 0 { browsing[t] = nil }; lock.unlock()
    }

    /// services of the type seen on the network (with their port known), not this app's own
    func services(type: String) -> [Remote] {
        let t = _NWBonjour.normType(type).lowercased()
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        return remotes.filter { $0.value.expires > now && $0.value.type.lowercased() == t && $0.value.port != nil && published[$0.key] == nil }
            .map(\.value).sorted { $0.name < $1.name }
    }

    /// a service's address and port, asking the network (SRV, then A) for up to `timeout` seconds
    func resolve(name: String, type: String, timeout: Double = 3) -> (String, UInt16)? {
        start()
        let full = _NWMDNS.fullName(name, type)
        let end = Date().addingTimeInterval(timeout)
        var asked = Set<String>()
        while true {
            lock.lock()
            let mine = published[full.lowercased()]
            let r = remotes[full.lowercased()]
            let addr = r?.target.flatMap { addresses[$0.lowercased()]?.first }
            lock.unlock()
            if let mine { return ("127.0.0.1", mine.port) }
            if let r, let p = r.port, let addr { return (addr, p) }
            if Date() > end { return nil }
            if r?.port == nil, !asked.contains(full) { asked.insert(full); query([(full, 33), (full, 16)]) }
            if let tgt = r?.target, !asked.contains(tgt) { asked.insert(tgt); query([(tgt, 1)]) }
            usleep(20_000)
        }
    }
}

// MARK: - DNS messages

struct _DNSQuestion { let name: String, type: UInt16, unicastResponse: Bool }

struct _DNSRecord {
    enum RData { case name(String), srv(port: UInt16, target: String), txt(Data), raw([UInt8]) }
    let name: String, type: UInt16, flush: Bool, ttl: UInt32, data: RData
    var key: String {
        switch data {
        case .name(let n): return "\(name.lowercased())|\(type)|\(n.lowercased())"
        case .raw(let b): return "\(name.lowercased())|\(type)|\(b)"
        default: return "\(name.lowercased())|\(type)"
        }
    }
    var unicast: _DNSRecord { _DNSRecord(name: name, type: type, flush: false, ttl: Swift.min(ttl, 10), data: data) }
}

struct _DNSMessage {
    var id: UInt16 = 0, isResponse = false
    var questions: [_DNSQuestion] = [], answers: [_DNSRecord] = [], additional: [_DNSRecord] = []

    init?(_ b: [UInt8]) {
        guard b.count >= 12 else { return nil }
        func u16(_ i: Int) -> UInt16 { UInt16(b[i]) << 8 | UInt16(b[i + 1]) }
        func u32(_ i: Int) -> UInt32 { UInt32(u16(i)) << 16 | UInt32(u16(i + 2)) }
        func name(_ start: Int) -> (String, Int)? {
            var labels: [String] = [], i = start, end = -1, jumps = 0
            while true {
                guard i < b.count else { return nil }
                let l = Int(b[i])
                if l == 0 { i += 1; break }
                if l & 0xC0 == 0xC0 {
                    guard i + 1 < b.count, jumps < 16 else { return nil }
                    if end < 0 { end = i + 2 }
                    i = (l & 0x3F) << 8 | Int(b[i + 1]); jumps += 1; continue
                }
                guard i + 1 + l <= b.count else { return nil }
                labels.append(String(decoding: b[(i + 1)..<(i + 1 + l)], as: UTF8.self))
                i += 1 + l
            }
            return (labels.joined(separator: "."), end < 0 ? i : end)
        }
        id = u16(0); isResponse = b[2] & 0x80 != 0
        let qd = Int(u16(4)), an = Int(u16(6)), ns = Int(u16(8)), ar = Int(u16(10))
        var i = 12
        for _ in 0..<qd {
            guard let (n, next) = name(i), next + 4 <= b.count else { return nil }
            questions.append(_DNSQuestion(name: n, type: u16(next), unicastResponse: u16(next + 2) & 0x8000 != 0))
            i = next + 4
        }
        func record() -> _DNSRecord? {
            guard let (n, next) = name(i), next + 10 <= b.count else { return nil }
            let type = u16(next), cls = u16(next + 2), ttl = u32(next + 4), len = Int(u16(next + 8))
            let rd = next + 10
            guard rd + len <= b.count else { return nil }
            i = rd + len
            let data: _DNSRecord.RData
            switch type {
            case 12: guard let (t, _) = name(rd) else { return nil }; data = .name(t)
            case 33: guard len >= 7, let (t, _) = name(rd + 6) else { return nil }; data = .srv(port: u16(rd + 4), target: t)
            case 16: data = .txt(Data(b[rd..<(rd + len)]))
            default: data = .raw(Array(b[rd..<(rd + len)]))
            }
            return _DNSRecord(name: n, type: type, flush: cls & 0x8000 != 0, ttl: ttl, data: data)
        }
        for k in 0..<(an + ns + ar) {
            guard let r = record() else { return nil }
            if k < an { answers.append(r) } else if k >= an + ns { additional.append(r) }
        }
    }
    init() {}

    static func encodeName(_ n: String) -> [UInt8] {
        var out: [UInt8] = []
        // the instance label of a service name may contain dots: split off the known suffix first
        if let (inst, type) = _NWMDNS.split(n) {
            let l = Array(inst.utf8.prefix(63)); out.append(UInt8(l.count)); out += l
            for part in type.split(separator: ".").map(String.init) + ["local"] { let p = Array(part.utf8); out.append(UInt8(p.count)); out += p }
        } else {
            for part in n.split(separator: ".") { let p = Array(part.utf8.prefix(63)); out.append(UInt8(p.count)); out += p }
        }
        return out + [0]
    }
    static func u16(_ v: UInt16) -> [UInt8] { [UInt8(v >> 8), UInt8(v & 0xFF)] }
    static func encode(_ r: _DNSRecord) -> [UInt8] {
        var rd: [UInt8]
        switch r.data {
        case .name(let n): rd = encodeName(n)
        case .srv(let port, let target): rd = u16(0) + u16(0) + u16(port) + encodeName(target)
        case .txt(let d): rd = d.isEmpty ? [0] : Array(d)
        case .raw(let b): rd = b
        }
        return encodeName(r.name) + u16(r.type) + u16(1 | (r.flush ? 0x8000 : 0))
            + [UInt8(r.ttl >> 24), UInt8((r.ttl >> 16) & 0xFF), UInt8((r.ttl >> 8) & 0xFF), UInt8(r.ttl & 0xFF)] + u16(UInt16(rd.count)) + rd
    }
    static func response(id: UInt16 = 0, questions: [_DNSQuestion] = [], answers: [_DNSRecord], additional: [_DNSRecord] = []) -> [UInt8] {
        var p = u16(id) + u16(0x8400) + u16(UInt16(questions.count)) + u16(UInt16(answers.count)) + u16(0) + u16(UInt16(additional.count))
        for q in questions { p += encodeName(q.name) + u16(q.type) + u16(1) }
        for r in answers + additional { p += encode(r) }
        return p
    }
    static func query(_ names: [(String, UInt16)]) -> [UInt8] {
        var p = u16(0) + u16(0) + u16(UInt16(names.count)) + u16(0) + u16(0) + u16(0)
        for (n, t) in names { p += encodeName(n) + u16(t) + u16(1) }
        return p
    }
}
