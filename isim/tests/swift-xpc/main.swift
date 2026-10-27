// The Swift XPC API on isim (issue #357): XPCListener and XPCSession between two processes of one device, with Codable
// and XPCDictionary messages, replies (async, sync, handed off), a rejecting listener and an anonymous listener reached
// through its endpoint. The test runs this binary twice on one ISIM_DATA: XPC_ROLE=server, then XPC_ROLE=client.
import Dispatch
import Foundation
import XPC

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: @autoclosure () -> String) {
    checks += 1
    if ok() { print("PASS  \(what())") } else { failures += 1; print("FAIL  \(what())") }
    fflush(stdout)
}

let codableService = "dev.isim.swiftxpc.codable"
let dictionaryService = "dev.isim.swiftxpc.dictionary"
let rejectService = "dev.isim.swiftxpc.reject"

struct Request: Codable { var op: String; var numbers: [Int] }
struct Response: Codable, Equatable { var sum: Int; var pid: Int32; var note: String }

final class Box<T>: @unchecked Sendable { var value: T; init(_ v: T) { value = v } }

func server() {
    let done = DispatchSemaphore(value: 0)
    let later = DispatchQueue(label: "later")
    let codable = try? XPCListener(service: codableService) { request in
        request.accept { (message: XPCReceivedMessage) -> (any Encodable)? in
            guard let r = try? message.decode(as: Request.self) else { return nil }
            switch r.op {
            case "sum": return Response(sum: r.numbers.reduce(0, +), pid: getpid(), note: message.isSync ? "sync" : "async")
            case "later":
                return message.handoffReply(to: later) { message.reply(Response(sum: r.numbers.count, pid: getpid(), note: "handed off")) }
            case "done": done.signal(); return nil
            default: return nil
            }
        }
    }
    check(codable != nil, "an XPCListener for a named service")
    let dictionary = try? XPCListener(service: dictionaryService) { request in
        request.accept { (message: XPCDictionary) -> XPCDictionary? in
            if message["op"] == "done" { done.signal(); return nil }
            let name: String = message["name"] ?? "?"
            let n: Int64 = message["n"] ?? 0
            return ["greeting": XPCLiteralValue("hello \(name)"), "twice": XPCLiteralValue(n * 2), "ok": true]
        }
    }
    check(dictionary != nil, "an XPCListener with an XPCDictionary handler")
    let reject = try? XPCListener(service: rejectService) { $0.reject(reason: "not today") }
    check(reject != nil, "a rejecting XPCListener")
    print("swift xpc server ready"); fflush(stdout)
    for _ in 0..<2 { check(done.wait(timeout: .now() + 60) == .success, "the client says done") }
    codable?.cancel(); dictionary?.cancel(); reject?.cancel()
}

func client() {
    var sessions: (XPCSession, XPCSession)?
    do {
        let session = try XPCSession(machService: codableService)
        let reply: Response = try session.sendSync(Request(op: "sum", numbers: [1, 2, 3, 4]))
        check(reply.sum == 10 && reply.note == "sync" && reply.pid != 0, "sendSync with a Codable request and reply (\(reply))")
        let got = DispatchSemaphore(value: 0)
        let async = Box<Response?>(nil)
        try session.send(Request(op: "sum", numbers: [5, 6])) { (result: Result<Response, any Error>) in
            async.value = try? result.get(); got.signal()
        }
        check(got.wait(timeout: .now() + 10) == .success && async.value?.sum == 11 && async.value?.note == "async",
              "send with a reply handler (\(String(describing: async.value)))")
        let handed: Response = try session.sendSync(Request(op: "later", numbers: [1, 1, 1]))
        check(handed.sum == 3 && handed.note == "handed off", "a reply handed off to another queue")
        let raw = try session.sendSync(Request(op: "sum", numbers: [7]))
        check(raw.isSync == false && (try? raw.decode(as: Response.self))?.sum == 7, "sendSync returning an XPCReceivedMessage")

        let d = try XPCSession(machService: dictionaryService)
        let answer = try d.sendSync(message: ["name": "isim", "n": 21])
        check(answer["greeting"] == "hello isim" && answer["twice"] == Int64(42) && answer["ok"] == true,
              "an XPCDictionary request and reply (\(answer))")
        let dict = Box<XPCDictionary?>(nil)
        d.send(message: ["name": "again", "n": 1]) { result in dict.value = try? result.get(); got.signal() }
        check(got.wait(timeout: .now() + 10) == .success && dict.value?["greeting"] == "hello again", "an XPCDictionary reply handler")
        sessions = (session, d)
    } catch {
        check(false, "the sessions: \(error)")
    }

    // a rejecting listener cancels the session
    let cancelled = DispatchSemaphore(value: 0)
    let why = Box("")
    if let r = try? XPCSession(machService: rejectService, options: .inactive) {
        r.setCancellationHandler { e in why.value = e.description; cancelled.signal() }
        try? r.activate()
        try? r.send(Request(op: "sum", numbers: [1]))
        check(cancelled.wait(timeout: .now() + 10) == .success && why.value.contains("not today"), "a rejected session is cancelled (\(why.value))")
    } else {
        check(false, "a session to the rejecting listener")
    }
    // no listener: activating throws a retryable error
    do {
        _ = try XPCSession(machService: "dev.isim.swiftxpc.nobody")
        check(false, "a session to nobody throws")
    } catch let e as XPCRichError {
        check(e.canRetry, "a session to nobody throws a retryable XPCRichError (\(e))")
    } catch { check(false, "XPCRichError: \(error)") }

    // an anonymous listener in this process, reached through its endpoint
    do {
        let anon = try XPCListener { request in
            request.accept { (n: Int) -> (any Encodable)? in n * n }
        }
        let s = try XPCSession(endpoint: anon.endpoint)
        let squared: Int = try s.sendSync(12)
        check(squared == 144, "an anonymous listener through its endpoint")
        s.cancel(reason: "finished")
        anon.cancel()
    } catch { check(false, "the anonymous listener: \(error)") }

    // done: the server exits once both sessions said so
    if let (session, d) = sessions {
        try? session.send(Request(op: "done", numbers: []))
        try? d.send(message: ["op": "done"])
        usleep(300_000)
        session.cancel(reason: "finished")
        d.cancel(reason: "finished")
    }
}

@main
struct Main {
    static func main() {
        let role = ProcessInfo.processInfo.environment["XPC_ROLE"] ?? "client"
        if role == "server" { server() } else { client() }
        print("swift xpc \(role): \(checks - failures)/\(checks) passed")
        exit(failures == 0 ? 0 : 1)
    }
}
