// os.Logger / os_log on isim (output checked by test_security.py); os_unfair_lock and OSAllocatedUnfairLock.
import Foundation
import os.log
import OSLog

func logTests() {
    let user = "alice@example.com", count = 3
    let logger = Logger(subsystem: "dev.isim.test", category: "security")
    // the messages go to stderr; tests/security/test_security.py checks the lines (format, levels, privacy)
    logger.notice("Loaded \(count) items for \(user)")
    logger.info("public \(user, privacy: .public) hex \(255, format: .hex, privacy: .public) pad [\(7, format: .decimal(minDigits: 3))]")
    logger.error("failed: \(true) \(2.5, format: .fixed(precision: 2))")
    logger.debug("hashed \(user, privacy: .private(mask: .hash))")
    os_log("legacy %{public}@ %d %@", log: OSLog(subsystem: "dev.isim.test", category: "legacy"), type: .fault, "visible", 42, "hidden")
    os_log("plain default log")
    Logger().log(level: .info, "no subsystem")
    check(OSLog.default.isEnabled(type: .debug) && !OSLog.disabled.isEnabled(type: .fault), "OSLog.isEnabled")

    let signposter = OSSignposter(logger: logger)
    let state = signposter.beginInterval("load", id: signposter.makeSignpostID())
    signposter.endInterval("load", state)
    check(signposter.withIntervalSignpost("compute") { 6 * 7 } == 42, "OSSignposter intervals run their work")

    var ul = os_unfair_lock()
    os_unfair_lock_lock(&ul)
    check(!os_unfair_lock_trylock(&ul), "os_unfair_lock is held")
    os_unfair_lock_unlock(&ul)
    let counter = OSAllocatedUnfairLock(initialState: 0)
    let group = DispatchGroup()
    for _ in 0..<8 { DispatchQueue.global().async(group: group) { for _ in 0..<1000 { counter.withLock { $0 += 1 } } } }
    group.wait()
    check(counter.withLock { $0 } == 8000, "OSAllocatedUnfairLock under contention")
}
