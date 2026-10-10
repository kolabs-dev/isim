// Swift <-> Foundation interop self-test on isim (overlays: ObjectiveC, Foundation; UIKit for UIColor's coding).
import Foundation
import UIKit
import UniformTypeIdentifiers

var failures = 0, checks = 0
func check(_ ok: @autoclosure () -> Bool, _ what: String) {
    checks += 1
    if ok() { print("PASS  \(what)") } else { failures += 1; print("FAIL  \(what)") }
}

/// an NSError subclass with its own state, archived through super (issue #39)
final class AppError: NSError, @unchecked Sendable {
    let screen: String
    override class var supportsSecureCoding: Bool { true }
    init(screen: String) { self.screen = screen; super.init(domain: "app", code: 9, userInfo: [NSLocalizedDescriptionKey: "failed"]) }
    required init?(coder: NSCoder) {
        screen = coder.decodeObject(of: NSString.self, forKey: "screen") as String? ?? ""
        super.init(coder: coder)
    }
    override func encode(with coder: NSCoder) { super.encode(with: coder); coder.encode(screen, forKey: "screen") }
}

/// NSCoding of Foundation's and UIKit's own classes (issue #39)
func codingChecks() {
    func rgba(_ c: UIColor?) -> [CGFloat] { var r: CGFloat = -1, g: CGFloat = -1, b: CGFloat = -1, a: CGFloat = -1; _ = c?.getRed(&r, green: &g, blue: &b, alpha: &a); return [r, g, b, a] }
    func near(_ x: [CGFloat], _ y: [CGFloat]) -> Bool { zip(x, y).allSatisfy { abs($0 - $1) < 1e-6 } }
    let color = UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
    let colorData = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
    let color2 = colorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: $0) }
    check(UIColor.supportsSecureCoding && near(rgba(color2), [0.2, 0.4, 0.6, 0.8]), "UIColor archives and unarchives with secure coding (\(rgba(color2)))")
    let dynamic = (try? NSKeyedArchiver.archivedData(withRootObject: UIColor.systemBackground, requiringSecureCoding: true))
        .flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: $0) }
    check(dynamic != nil && rgba(dynamic)[3] == 1, "a dynamic color archives as its current color")
    let appError = AppError(screen: "settings")
    let errorData = try? NSKeyedArchiver.archivedData(withRootObject: appError, requiringSecureCoding: true)
    let appError2 = errorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: AppError.self, from: $0) }
    check(appError2?.screen == "settings" && appError2?.code == 9 && appError2?.localizedDescription == "failed",
          "an NSError subclass archives through super.encode(with:) / super.init(coder:)")
    // Core Data's transformable attributes: the default transformer only allows Foundation's types, a subclass adds UIColor
    let packed = try? NSKeyedArchiver.archivedData(withRootObject: [UIColor.red, color] as NSArray, requiringSecureCoding: true)
    let refused = packed.flatMap { ValueTransformer(forName: .secureUnarchiveFromDataTransformerName)?.transformedValue($0) }
    let colors = packed.flatMap { ColorsTransformer().transformedValue($0) } as? [UIColor]
    check(refused == nil && colors?.count == 2 && near(rgba(colors?.last), [0.2, 0.4, 0.6, 0.8]),
          "NSSecureUnarchiveFromDataTransformer: UIColor only through a subclass's allowedTopLevelClasses (\(colors?.count ?? -1))")
}

/// FileManager attributes (issue #102)
func fileAttributeChecks() {
    let fm = FileManager.default
    let dir = (NSTemporaryDirectory() as NSString).appendingPathComponent("swift-attrs")
    try? fm.removeItem(atPath: dir)
    check((try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])) != nil,
          "createDirectory(atPath:withIntermediateDirectories:attributes:) with FileAttributeKey")
    let path = (dir as NSString).appendingPathComponent("f.bin")
    check(fm.createFile(atPath: path, contents: Data(count: 1000), attributes: [.posixPermissions: 0o600]), "createFile(atPath:contents:attributes:)")
    let attrs = try? fm.attributesOfItem(atPath: path)
    let size = try? fm.attributesOfItem(atPath: path)[.size] as? Int
    check(size == 1000 && (attrs?[.size] as? UInt64) == 1000 && (attrs as NSDictionary?)?.fileSize() == 1000, "attributesOfItem(atPath:)[.size] (\(size ?? -1))")
    check(attrs?[.type] as? FileAttributeType == .typeRegular && (attrs?[.posixPermissions] as? Int) == 0o600, "attributes: .type, .posixPermissions")
    let modified = attrs?[.modificationDate] as? Date, created = attrs?[.creationDate] as? Date
    check(modified.map { abs($0.timeIntervalSinceNow) < 60 } == true && created != nil && created! <= modified!, "attributes: .modificationDate, .creationDate")
    check(attrs?[.ownerAccountName] as? String != nil && attrs?[.referenceCount] as? Int == 1 && attrs?[.systemFileNumber] != nil, "attributes: owner, reference count, inode")
    let past = Date(timeIntervalSince1970: 1_500_000_000)
    check((try? fm.setAttributes([.modificationDate: past, .posixPermissions: 0o644, .protectionKey: FileProtectionType.complete], ofItemAtPath: path)) != nil,
          "setAttributes(_:ofItemAtPath:)")
    let after = try? fm.attributesOfItem(atPath: path)
    check(after?[.modificationDate] as? Date == past && (after?[.posixPermissions] as? NSNumber)?.intValue == 0o644, "setAttributes applies the date and permissions")
    check((try? fm.attributesOfItem(atPath: dir))?[.type] as? FileAttributeType == .typeDirectory, "a directory's .type")
    do { _ = try fm.attributesOfItem(atPath: (dir as NSString).appendingPathComponent("missing")); check(false, "missing file throws") }
    catch { check((error as? CocoaError)?.code == .fileReadNoSuchFile, "a missing file throws CocoaError.fileReadNoSuchFile (\(error))") }
    let fs = try? fm.attributesOfFileSystem(forPath: dir)
    let total = (fs?[.systemSize] as? NSNumber)?.int64Value ?? 0, free = (fs?[.systemFreeSize] as? NSNumber)?.int64Value ?? -1
    check(total > 0 && free >= 0 && free <= total && fs?[.systemNodes] != nil, "attributesOfFileSystem(forPath:) (\(total), \(free))")
    try? fm.removeItem(atPath: dir)
}

/// FileManager: enumerators, links, copy / move / replace, URL resource values (issue #12)
func fileManagerChecks() {
    let fm = FileManager.default
    let root = fm.temporaryDirectory.appendingPathComponent("swift-fm")
    try? fm.removeItem(at: root)
    let tree = root.appendingPathComponent("tree")
    check((try? fm.createDirectory(at: tree.appendingPathComponent("sub"), withIntermediateDirectories: true)) != nil, "createDirectory(at:)")
    fm.createFile(atPath: tree.appendingPathComponent("a.txt").path, contents: Data("alpha".utf8))
    fm.createFile(atPath: tree.appendingPathComponent("sub/b.txt").path, contents: Data("beta".utf8))
    fm.createFile(atPath: tree.appendingPathComponent(".hidden").path, contents: nil)
    let link = tree.appendingPathComponent("link")
    check((try? fm.createSymbolicLink(at: link, withDestinationURL: tree.appendingPathComponent("a.txt"))) != nil, "createSymbolicLink(at:withDestinationURL:)")
    check((try? fm.destinationOfSymbolicLink(atPath: link.path)) == tree.appendingPathComponent("a.txt").path, "destinationOfSymbolicLink(atPath:)")
    check(link.resolvingSymlinksInPath().lastPathComponent == "a.txt", "URL.resolvingSymlinksInPath()")
    // for-in over a path enumerator (NSEnumerator: Sequence), skipDescendants, level
    var paths: [String] = []
    if let e = fm.enumerator(atPath: tree.path) {
        for case let p as String in e { paths.append("\(p):\(e.level)") }
    }
    check(paths == [".hidden:1", "a.txt:1", "link:1", "sub:1", "sub/b.txt:2"], "enumerator(atPath:) in for-in (\(paths))")
    var urls: [String] = []
    let e = fm.enumerator(at: tree, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: [.skipsHiddenFiles])
    while let u = e?.nextObject() as? URL {
        let v = try? u.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
        urls.append(u.lastPathComponent + (v?.isDirectory == true ? "/" : v?.isSymbolicLink == true ? "@" : "=\(v?.fileSize ?? -1)"))
        if u.lastPathComponent == "sub" { e?.skipDescendants() }
    }
    check(urls == ["a.txt=5", "link@", "sub/"], "enumerator(at:includingPropertiesForKeys:options:) with resourceValues (\(urls))")
    let shallow = (try? fm.contentsOfDirectory(at: tree, includingPropertiesForKeys: nil, options: .skipsHiddenFiles))?.map(\.lastPathComponent)
    check(shallow == ["a.txt", "link", "sub"], "contentsOfDirectory(at:includingPropertiesForKeys:options:) (\(shallow ?? []))")
    check((try? fm.subpathsOfDirectory(atPath: tree.path))?.count == 5, "subpathsOfDirectory(atPath:)")
    let values = try? tree.appendingPathComponent("a.txt").resourceValues(forKeys: [.nameKey, .isRegularFileKey, .contentModificationDateKey, .fileResourceTypeKey, .parentDirectoryURLKey])
    check(values?.name == "a.txt" && values?.isRegularFile == true && values?.contentModificationDate != nil && values?.fileResourceType == .regular &&
          values?.parentDirectory?.lastPathComponent == "tree", "URL.resourceValues(forKeys:)")
    do { _ = try root.appendingPathComponent("missing").resourceValues(forKeys: [.nameKey]); check(false, "resourceValues of a missing file throws") }
    catch { check((error as? CocoaError)?.code == .fileReadNoSuchFile, "resourceValues of a missing file throws .fileReadNoSuchFile") }
    var renamed = tree.appendingPathComponent(".hidden")
    var newValues = URLResourceValues(); newValues.name = "visible"; newValues.isExcludedFromBackup = true
    check((try? renamed.setResourceValues(newValues)) != nil && renamed.lastPathComponent == "visible" && fm.fileExists(atPath: renamed.path),
          "URL.setResourceValues renames, accepts isExcludedFromBackup")
    // copy a tree, move it, replace a file
    let copy = root.appendingPathComponent("copy")
    check((try? fm.copyItem(at: tree, to: copy)) != nil && fm.contentsEqual(atPath: tree.path, andPath: copy.path), "copyItem(at:to:) copies a directory tree")
    do { try fm.copyItem(at: tree, to: copy); check(false, "copy onto an existing item throws") }
    catch { check((error as? CocoaError)?.code == .fileWriteFileExists, "copy onto an existing item throws .fileWriteFileExists (\(error))") }
    let moved = root.appendingPathComponent("moved")
    check((try? fm.moveItem(at: copy, to: moved)) != nil && !fm.fileExists(atPath: copy.path) && fm.fileExists(atPath: moved.appendingPathComponent("sub/b.txt").path), "moveItem(at:to:)")
    let doc = root.appendingPathComponent("doc.txt"), new = root.appendingPathComponent("doc.new")
    try? Data("old".utf8).write(to: doc); try? Data("new".utf8).write(to: new)
    let result = try? fm.replaceItemAt(doc, withItemAt: new, backupItemName: "doc.bak", options: .withoutDeletingBackupItem)
    check(result == doc && fm.contents(atPath: doc.path) == Data("new".utf8) && fm.contents(atPath: root.appendingPathComponent("doc.bak").path) == Data("old".utf8) &&
          !fm.fileExists(atPath: new.path), "replaceItemAt(_:withItemAt:backupItemName:options:)")
    check((try? fm.linkItem(at: doc, to: root.appendingPathComponent("hard.txt"))) != nil && fm.isDeletableFile(atPath: doc.path) && !fm.isExecutableFile(atPath: doc.path), "linkItem(at:to:), isDeletableFile, isExecutableFile")
    let rep = fm.withFileSystemRepresentation(for: doc.path) { $0.map { String(cString: $0) } }
    check(rep == doc.path && doc.withUnsafeFileSystemRepresentation { $0.map { String(cString: $0) } } == doc.path && !fm.currentDirectoryPath.isEmpty, "file system representation, currentDirectoryPath")
    check(NSFileNoSuchFileError == 4 && NSFileWriteFileExistsError == CocoaError.fileWriteFileExists.rawValue, "NSFile*Error constants")
    try? fm.removeItem(at: root)
}

/// #Predicate (iOS 17), NSPredicate from a Predicate, Decimal <-> NSDecimalNumber, Progress file properties (issue #12)
struct Book { let title: String; let pages: Int; let tags: [String] }
final class Gadget: NSObject {
    @objc let name: String
    @objc let price: Int
    init(_ name: String, _ price: Int) { self.name = name; self.price = price }
}
func predicateAndDecimalChecks() {
    if #available(iOS 17, *) {
        let books = [Book(title: "Dune", pages: 412, tags: ["sf"]), Book(title: "Emma", pages: 474, tags: []), Book(title: "Odes", pages: 80, tags: ["poems", "sf"])]
        let long = #Predicate<Book> { $0.pages > 400 && !$0.title.isEmpty }
        let tagged = #Predicate<Book> { book in book.tags.contains("sf") }
        let search = #Predicate<Book> { $0.title.localizedStandardContains("dU") }
        let longTitles = (try? books.filter(long))?.map(\.title)
        check(longTitles == ["Dune", "Emma"], "#Predicate with && and ! (\(longTitles ?? []))")
        check((try? books.filter(tagged))?.map(\.title) == ["Dune", "Odes"], "#Predicate with Sequence.contains")
        check((try? search.evaluate(books[0])) == true && (try? search.evaluate(books[1])) == false, "#Predicate with localizedStandardContains")
        let minimum = 300
        let captured = #Predicate<Book> { $0.pages >= minimum ? $0.tags.isEmpty : false }
        check((try? books.filter(captured))?.map(\.title) == ["Emma"], "#Predicate capturing a value, with ?:")
        let nsPredicate = NSPredicate(#Predicate<Gadget> { $0.price > 10 && $0.name != "x" })
        let gadgets = [Gadget("pen", 2), Gadget("lamp", 40)]
        check(nsPredicate != nil && (gadgets as NSArray).filtered(using: nsPredicate!).count == 1, "NSPredicate(_: Predicate) (\(nsPredicate?.predicateFormat ?? "nil"))")
        if #available(iOS 18, *) {
            let doubled = #Expression<Book, Int> { $0.pages * 2 }
            check((try? doubled.evaluate(books[2])) == 160, "#Expression (iOS 18)")
        }
        check(String(describing: long).contains("Predicate<main.Book>") && String(describing: long).contains("400"), "Predicate description")
    }
    // Decimal bridges to NSDecimalNumber, both ways, exactly
    let price = Decimal(string: "19.99")!
    let ns = price as NSDecimalNumber
    let tripled = ns.multiplying(by: 3) as Decimal
    check(ns.stringValue == "19.99" && tripled == Decimal(string: "59.97")!, "Decimal as NSDecimalNumber, arithmetic, back as Decimal (\(ns.stringValue) * 3 = \(tripled))")
    check(NSDecimalNumber(decimal: Decimal(string: "-0.0001")!).decimalValue == Decimal(string: "-0.0001")! && NSNumber(value: 0.1).decimalValue == Decimal(string: "0.1")!,
          "NSDecimalNumber(decimal:), NSNumber.decimalValue")
    let rounded = NSDecimalNumber(string: "2.675").rounding(accordingToBehavior: NSDecimalNumberHandler(roundingMode: .plain, scale: 2, raiseOnExactness: false, raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false))
    check(rounded.stringValue == "2.68" && NSDecimalNumber.notANumber.decimalValue.isNaN, "NSDecimalNumberHandler rounding, NaN")
    let boxed: Any = Decimal(5)
    check((boxed as AnyObject) is NSDecimalNumber, "a Decimal in Any bridges to NSDecimalNumber")
    // Progress file properties as Swift values
    let progress = Progress(totalUnitCount: 100)
    progress.kind = .file
    progress.fileOperationKind = .copying
    progress.fileTotalCount = 3
    progress.fileCompletedCount = 1
    progress.estimatedTimeRemaining = 45
    progress.throughput = 2048
    check(progress.fileTotalCount == 3 && progress.estimatedTimeRemaining == 45 && progress.throughput == 2048 &&
          progress.userInfo[.fileCompletedCountKey] as? Int == 1 && progress.localizedDescription == "Copying 3 files…", "Progress file properties (\(progress.localizedDescription ?? ""))")
    let parent = Progress(totalUnitCount: 10)
    let result = parent.performAsCurrent(withPendingUnitCount: 5) { () -> Int in
        let child = Progress(totalUnitCount: 1); child.completedUnitCount = 1; return 7
    }
    check(result == 7 && parent.completedUnitCount == 5, "Progress.performAsCurrent(withPendingUnitCount:using:)")
}

/// Operation subclasses, OperationQueue, Thread and RunLoop modes (issue #12)
final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock(); private var v: T
    init(_ v: T) { self.v = v }
    var value: T { lock.lock(); defer { lock.unlock() }; return v }
    func mutate(_ f: (inout T) -> Void) { lock.lock(); f(&v); lock.unlock() }
}
final class DelayedOperation: Operation, @unchecked Sendable {
    private let state = Locked((executing: false, finished: false))
    let log: Locked<[String]>
    init(log: Locked<[String]>) { self.log = log }
    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool { state.value.executing }
    override var isFinished: Bool { state.value.finished }
    override func start() {
        if isCancelled { finish(); return }
        willChangeValue(forKey: "isExecuting"); state.mutate { $0.executing = true }; didChangeValue(forKey: "isExecuting")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) { self.log.mutate { $0.append("delayed") }; self.finish() }
    }
    private func finish() {
        willChangeValue(forKey: "isFinished"); willChangeValue(forKey: "isExecuting")
        state.mutate { $0 = (false, true) }
        didChangeValue(forKey: "isExecuting"); didChangeValue(forKey: "isFinished")
    }
}
final class SquareOperation: Operation, @unchecked Sendable {
    let input: Int
    var output = 0
    init(_ n: Int) { input = n }
    override func main() { if !isCancelled { output = input * input } }
}
func operationChecks() {
    let log = Locked<[String]>([])
    let q = OperationQueue()
    q.maxConcurrentOperationCount = 2
    let delayed = DelayedOperation(log: log), square = SquareOperation(7)
    square.addDependency(delayed)
    q.addOperations([square, delayed], waitUntilFinished: true)
    check(square.output == 49 && delayed.isFinished && square.isFinished && log.value == ["delayed"],
          "Operation subclasses: an asynchronous one finishing by KVO, a dependent main()")
    let block = BlockOperation { log.mutate { $0.append("block") } }
    block.addExecutionBlock { log.mutate { $0.append("block2") } }
    block.queuePriority = .veryHigh; block.qualityOfService = .userInitiated
    q.addOperation(block)
    q.addOperation { log.mutate { $0.append("closure") } }
    q.waitUntilAllOperationsAreFinished()
    check(Set(log.value) == ["delayed", "block", "block2", "closure"] && block.executionBlocks.count == 2,
          "BlockOperation with execution blocks, addOperation(_:) with a closure (\(log.value))")
    let cancelled = SquareOperation(3)
    cancelled.cancel()
    q.addOperations([cancelled], waitUntilFinished: true)
    check(cancelled.isFinished && cancelled.output == 0, "a cancelled Operation finishes without running")
    let watched = OperationQueue()
    watched.isSuspended = true
    let counts = Locked<[Int]>([])
    let observation = watched.observe(\.operationCount, options: [.new]) { _, change in counts.mutate { $0.append(change.newValue ?? -1) } }
    watched.addOperation {}
    watched.isSuspended = false
    watched.waitUntilAllOperationsAreFinished()
    observation.invalidate()
    check(counts.value == [1, 0] && OperationQueue.defaultMaxConcurrentOperationCount == -1, "observe(\\.operationCount) (\(counts.value))")
    let current = Locked<OperationQueue?>(nil)
    q.addOperations([BlockOperation { current.mutate { $0 = OperationQueue.current } }], waitUntilFinished: true)
    check(current.value === q && OperationQueue.current === OperationQueue.main, "OperationQueue.current")

    // a Thread with its own RunLoop: a Timer and a perform from the main thread
    let ticks = Locked(0), ownLoop = Locked(false)
    let done = DispatchSemaphore(value: 0)
    let worker = Thread {
        ownLoop.mutate { $0 = RunLoop.current !== RunLoop.main && !Thread.isMainThread }
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { timer in
            ticks.mutate { $0 += 1 }
            if ticks.value == 3 { timer.invalidate() }
        }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))     // returns when the timer is gone
        done.signal()
    }
    worker.name = "swift-worker"
    worker.start()
    check(done.wait(timeout: .now() + 3) == .success && ticks.value == 3 && ownLoop.value, "Thread(block:) runs its RunLoop and Timer")
    // modes: a timer in a custom mode fires only when the loop runs in that mode
    let mode = RunLoop.Mode("isim.swift.mode")
    let firedIn = Locked<RunLoop.Mode?>(nil)
    RunLoop.main.add(Timer(timeInterval: 0.01, repeats: false) { _ in firedIn.mutate { $0 = RunLoop.main.currentMode } }, forMode: mode)
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    check(firedIn.value == nil, "a custom-mode timer waits while the loop runs in the default mode")
    _ = RunLoop.main.run(mode: mode, before: Date(timeIntervalSinceNow: 0.5))
    check(firedIn.value == mode, "RunLoop.run(mode:before:) fires that mode's timers (\(firedIn.value?.rawValue ?? "none"))")
    let performed = Locked(false)
    RunLoop.main.perform { performed.mutate { $0 = true } }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
    check(performed.value && RunLoop.Mode.tracking.rawValue == "UITrackingRunLoopMode", "RunLoop.perform(_:), RunLoop.Mode.tracking")
    let fired = Locked(false)
    let cancellable = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect().sink { _ in fired.mutate { $0 = true } }
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    cancellable.cancel()
    check(fired.value, "Timer.publish(every:on:in:) on the given run loop and mode")
}

/// Objective-C collections of classes bridged to Swift collections of metatypes (issue #49)
/// calendars, collation and formatting from the host's ICU (issue #12)
func localeChecks() {
    let utc = TimeZone(identifier: "UTC")!
    let d = Date(timeIntervalSince1970: 1792065600)   // 2026-10-15 12:00 UTC
    var hebrew = Calendar(identifier: .hebrew); hebrew.timeZone = utc
    let h = hebrew.dateComponents([.era, .year, .month, .day, .weekday], from: d)
    check(h.year == 5787 && h.month == 2 && h.day == 4 && h.weekday == 5, "Calendar(.hebrew) components (\(h))")
    check(hebrew.date(from: DateComponents(year: 5787, month: 2, day: 4, hour: 12)) == d, "Calendar(.hebrew) date(from:)")
    check(hebrew.range(of: .month, in: .year, for: d) == 1..<14 && hebrew.range(of: .day, in: .month, for: d) == 1..<31,
          "Calendar(.hebrew) range: 13 months in a leap year, 30 days in Heshvan 5787 (\(String(describing: hebrew.range(of: .day, in: .month, for: d))))")
    let nextMonth = hebrew.date(byAdding: .month, value: 1, to: d).map { hebrew.dateComponents([.month, .day], from: $0) }
    check(nextMonth?.month == 3 && nextMonth?.day == 4, "Calendar(.hebrew) date(byAdding: .month)")
    var japanese = Calendar(identifier: .japanese); japanese.timeZone = utc
    let j = japanese.dateComponents([.era, .year], from: d)
    check(j.era == 236 && j.year == 8, "Calendar(.japanese): Reiwa 8 (\(j))")
    var buddhist = Calendar(identifier: .buddhist); buddhist.timeZone = utc
    check(buddhist.component(.year, from: d) == 2569, "Calendar(.buddhist) year 2569")
    var islamic = Calendar(identifier: .islamicUmmAlQura); islamic.timeZone = utc
    let i = islamic.dateComponents([.year, .month, .day], from: d)
    check(i.year == 1448 && i.month == 5 && i.day == 4, "Calendar(.islamicUmmAlQura) (\(i))")
    var persian = Calendar(identifier: .persian); persian.timeZone = utc
    check(persian.dateInterval(of: .month, for: d).map { persian.component(.day, from: $0.start) } == 1, "Calendar(.persian) dateInterval(of: .month)")
    hebrew.locale = Locale(identifier: "en_US")
    check(hebrew.monthSymbols.count == 14 && hebrew.monthSymbols[0] == "Tishri", "Calendar(.hebrew).monthSymbols (\(hebrew.monthSymbols.prefix(2)))")
    check(Locale(identifier: "th_TH@calendar=buddhist").calendar.identifier == .buddhist, "Locale.calendar from @calendar=")
    let style = Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "en_US"), calendar: japanese, timeZone: utc)
    check(d.formatted(style) == "October 15, 8 Reiwa", "Date.FormatStyle with a Japanese calendar (\(d.formatted(style)))")
    // collation and case rules
    check("ä".compare("z", locale: Locale(identifier: "sv_SE")) == .orderedDescending && "ä".compare("z", locale: Locale(identifier: "de_DE")) == .orderedAscending,
          "String.compare(_:locale:) follows the locale's collation")
    check(["item 10", "Item 9", "item 1"].sorted { $0.localizedStandardCompare($1) == .orderedAscending } == ["item 1", "Item 9", "item 10"],
          "localizedStandardCompare: numeric, case-insensitive")
    check("istanbul".uppercased(with: Locale(identifier: "tr_TR")) == "İSTANBUL", "uppercased(with:) Turkish dotted I")
    // other languages through ICU
    let ru = Locale(identifier: "ru_RU")
    let dur = Duration.seconds(3700).formatted(.units(allowed: [.hours, .minutes], width: .wide).locale(ru))
    check(dur == "1 час 2 минуты", "Duration.UnitsFormatStyle in Russian (\(dur))")
    let compact = 1_500_000.formatted(.number.notation(.compactName).locale(ru))
    check(compact == "1,5\u{A0}млн", "compact notation in Russian (\(compact))")
    check(d.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: ru, timeZone: utc)) == "четверг, 15 октября 2026\u{202F}г.",
          "Date.FormatStyle in Russian (\(d.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: ru, timeZone: utc))))")
    check(Locale(identifier: "fr_FR").localizedString(forLanguageCode: "de") == "allemand", "Locale.localizedString(forLanguageCode:) in French")
}

/// files from Swift: resource values, streams, iCloud documents (issue #12)
func fileChecks() {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    var url = dir.appendingPathComponent("photo.png")
    try? Data([1, 2, 3]).write(to: url)
    let v = try? url.resourceValues(forKeys: [.contentTypeKey, .typeIdentifierKey, .volumeAvailableCapacityForImportantUsageKey, .volumeIsEncryptedKey, .fileProtectionKey])
    check(v?.contentType == .png && v?.typeIdentifier == "public.png", "URLResourceValues.contentType (\(String(describing: v?.typeIdentifier)))")
    check((v?.volumeAvailableCapacityForImportantUsage ?? 0) > 0 && v?.volumeIsEncrypted == true, "volume capacity for important usage (Int64), volumeIsEncrypted")
    check(v?.fileProtection == .completeUntilFirstUserAuthentication, "fileProtection")
    var set = URLResourceValues()
    set.isExcludedFromBackup = true
    set.name = "renamed.png"
    try? url.setResourceValues(set)
    check(url.lastPathComponent == "renamed.png" && (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup == true,
          "setResourceValues: name and isExcludedFromBackup")
    // a bound pair in Swift
    var input: InputStream?, output: OutputStream?
    Stream.getBoundStreams(withBufferSize: 16, inputStream: &input, outputStream: &output)
    input?.open(); output?.open()
    let bytes: [UInt8] = Array("swift".utf8)
    _ = output?.write(bytes, maxLength: bytes.count)
    var buf = [UInt8](repeating: 0, count: 16)
    let n = input?.read(&buf, maxLength: buf.count) ?? 0
    check(n == 5 && String(decoding: buf[0..<n], as: UTF8.self) == "swift", "Stream.getBoundStreams(withBufferSize:inputStream:outputStream:)")
    // iCloud documents
    guard let container = fm.url(forUbiquityContainerIdentifier: nil) else { check(false, "ubiquity container"); return }
    let doc = container.appendingPathComponent("Documents/notes.md")
    try? "# Notes".write(to: doc, atomically: true, encoding: .utf8)
    try? fm.evictUbiquitousItem(at: doc)
    let status = (try? URL(fileURLWithPath: doc.path).resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey]))
    check(status?.ubiquitousItemDownloadingStatus == .notDownloaded && status?.isUbiquitousItem == true, "evictUbiquitousItem(at:), downloading status")
    var text: String?
    var err: NSError?
    NSFileCoordinator().coordinate(readingItemAt: doc, options: [], error: &err) { text = try? String(contentsOf: $0, encoding: .utf8) }
    check(text == "# Notes" && err == nil, "NSFileCoordinator coordinated read downloads the item")
    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    query.predicate = NSPredicate(format: "%K ENDSWITH '.md'", NSMetadataItemFSNameKey)
    var gathered = false
    let token = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: nil) { _ in gathered = true }
    _ = query.start()
    let deadline = Date(timeIntervalSinceNow: 5)
    while !gathered && Date() < deadline { RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05)) }
    check(gathered && query.resultCount == 1 && (query.result(at: 0) as? NSMetadataItem)?.value(forAttribute: NSMetadataItemFSNameKey) as? String == "notes.md",
          "NSMetadataQuery in Swift")
    query.stop()
    NotificationCenter.default.removeObserver(token)
    try? fm.removeItem(at: dir)
}

func classBridgingChecks() {
    let classes = [NSString.self, UIColor.self] as [AnyClass] as NSArray
    let any = classes as! [AnyClass]
    check(any.map(ObjectIdentifier.init) == [ObjectIdentifier(NSString.self), ObjectIdentifier(UIColor.self)], "NSArray of classes as! [AnyClass]")
    let objects = (classes as? [NSObject.Type])?.map { NSStringFromClass($0) }
    check(objects == ["NSString", "UIColor"], "NSArray of classes as? [NSObject.Type] (\(objects ?? []))")
    check((([NSString.self, "text"] as [Any] as NSArray) as? [AnyClass]) == nil, "an NSArray with a non-class as? [AnyClass] is nil")
    check((([NSString.self] as [AnyClass] as NSArray) as? [UIColor.Type]) == nil, "NSArray of classes as? [UIColor.Type] with another class is nil")
    let byName = (["color": UIColor.self] as [String: AnyClass] as NSDictionary) as? [String: AnyClass]
    check(byName?["color"].map(ObjectIdentifier.init) == ObjectIdentifier(UIColor.self), "NSDictionary of classes as? [String: AnyClass]")
    let inherited = NSSecureUnarchiveFromDataTransformer.allowedTopLevelClasses.map { NSStringFromClass($0) }
    check(inherited.contains("NSArray") && ColorsTransformer.allowedTopLevelClasses.count == inherited.count + 1,
          "super.allowedTopLevelClasses bridges to [AnyClass] (\(inherited))")
}

final class ColorsTransformer: NSSecureUnarchiveFromDataTransformer {
    // the documented way: super's classes (an NSArray of classes bridged to [AnyClass], issue #49) plus UIColor
    override class var allowedTopLevelClasses: [AnyClass] { super.allowedTopLevelClasses + [UIColor.self] }
}

class Greeter: NSObject {
    var greeting = "Hello"
    @objc func greet(_ name: String) -> String { "\(greeting), \(name)!" }
    @objc dynamic var count: Int = 0
}

enum PlainError: Error { case first, second }
enum CodedError: Int, Error { case a = 3, b = 42 }
enum ShopError: LocalizedError {
    case outOfStock(String)
    var errorDescription: String? { if case .outOfStock(let s) = self { return "\(s) is out of stock" }; return nil }
    var failureReason: String? { "The shelf is empty." }
    var recoverySuggestion: String? { "Try again tomorrow." }
    var helpAnchor: String? { "stock-help" }
}
struct NetError: CustomNSError, LocalizedError {
    var status: Int
    static var errorDomain: String { "com.example.net" }
    var errorCode: Int { status }
    var errorUserInfo: [String: Any] { ["status": status, NSLocalizedDescriptionKey: "HTTP \(status)"] }
}
struct BareCustom: CustomNSError { static var errorDomain: String { "com.example.bare" }; var errorCode: Int { 9 } }

struct RetryError: RecoverableError {
    var recoveryOptions: [String] { ["Retry", "Cancel"] }
    func attemptRecovery(optionIndex i: Int) -> Bool { i == 0 }
}

/// adopts NSItemProviderWriting with Apple's Swift signature: the block's NSError * comes in as Error? (issue #99) and
/// the handler is @Sendable (NS_SWIFT_SENDABLE, issue #119); this app builds with -warnings-as-errors, so a mismatch fails
final class FailingWriter: NSObject, NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] { ["public.data"] }
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress? {
        completionHandler(nil, ShopError.outOfStock("Tea"))
        return nil
    }
}

/// Objective-C NSError * parameters import as Error, as on iOS (issue #99)
func nsErrorParameterChecks() {
    let done = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var got: Error?
    NSItemProvider(object: FailingWriter()).loadDataRepresentation(forTypeIdentifier: "public.data") { _, e in got = e; done.signal() }
    done.wait()
    if case .outOfStock(let what)? = got as? ShopError { check(what == "Tea", "Swift error through an Objective-C NSError * block keeps its type") }
    else { check(false, "Swift error through an Objective-C NSError * block keeps its type (\(String(describing: got)))") }
    let p = NSItemProvider()
    p.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in completion(nil, NetError(status: 500)); return nil }
    nonisolated(unsafe) var net: Error?
    p.loadDataRepresentation(forTypeIdentifier: "public.text") { _, e in net = e; done.signal() }
    done.wait()
    check((net as? NetError)?.status == 500 && (net as NSError?)?.domain == "com.example.net", "Swift error passed to an NSError * argument (no as NSError)")
}

/// Swift errors bridged to NSError: domain/code/userInfo from Error, LocalizedError, CustomNSError and
/// RecoverableError (the runtime's NSError box + Foundation._getErrorDefaultUserInfo), and back.
func errorBridgingChecks() {
    let p: Error = PlainError.second
    let pn = p as NSError
    check(pn.code == 1 && pn.domain.hasSuffix("PlainError"), "plain enum: domain/code")
    check(p.localizedDescription == "The operation couldn’t be completed. (\(pn.domain) error 1.)", "plain enum: localizedDescription")
    let c = CodedError.b as NSError
    check(c.code == 42, "Int raw enum: code = rawValue")
    let s: Error = ShopError.outOfStock("Milk")
    let sn = s as NSError
    check(s.localizedDescription == "Milk is out of stock", "LocalizedError: Error.localizedDescription")
    check(sn.localizedDescription == "Milk is out of stock", "LocalizedError: (as NSError).localizedDescription")
    check(sn.localizedFailureReason == "The shelf is empty.", "LocalizedError: localizedFailureReason")
    check(sn.userInfo["NSLocalizedRecoverySuggestion"] as? String == "Try again tomorrow.", "LocalizedError: recovery suggestion key")
    let n: Error = NetError(status: 404)
    let nn = n as NSError
    check(nn.domain == "com.example.net" && nn.code == 404, "CustomNSError: domain/code")
    check(nn.userInfo["status"] as? Int == 404 && nn.localizedDescription == "HTTP 404", "CustomNSError: userInfo")
    let b = BareCustom() as NSError
    check(b.domain == "com.example.bare" && b.code == 9 && b.localizedDescription == "The operation couldn’t be completed. (com.example.bare error 9.)", "CustomNSError: default description")
    // round trips
    let arr = [s] as NSArray
    check((arr[0] as? Error) as? ShopError != nil, "Swift error through NSArray -> as? ShopError")
    let back: Error = sn
    if case .outOfStock(let what)? = back as? ShopError { check(what == "Milk", "NSError box -> as? ShopError keeps payload") } else { check(false, "NSError box -> as? ShopError") }
    let conv = _convertErrorToNSError(n)
    check(_convertNSErrorToError(conv) as? NetError != nil, "_convertErrorToNSError -> back to NetError")
    check(conv.domain == "com.example.net" && conv.code == 404, "_convertErrorToNSError domain/code")
    let plainNS = NSError(domain: "x.y", code: 5, userInfo: [NSLocalizedDescriptionKey: "five"])
    let asErr: Error = plainNS
    check((asErr as NSError) === plainNS && asErr.localizedDescription == "five", "NSError -> Error -> NSError identity")
    check(asErr as? ShopError == nil, "foreign NSError is not ShopError")
    check((URLError(.timedOut) as NSError).domain == NSURLErrorDomain, "URLError as NSError")
    let un = NSError(domain: NSURLErrorDomain, code: -1001, userInfo: nil)
    check((un as Error as? URLError)?.code == .timedOut, "NSError -> URLError")
    do { try { throw ShopError.outOfStock("Eggs") }() } catch let e as ShopError { check(e.localizedDescription == "Eggs is out of stock", "catch as ShopError") } catch { check(false, "catch as ShopError") }
    check(sn.localizedRecoverySuggestion == "Try again tomorrow." && sn.helpAnchor == "stock-help", "LocalizedError: localizedRecoverySuggestion / helpAnchor")
    let cocoa = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: [NSFilePathErrorKey: "/x"])
    check((cocoa as Error as? CocoaError)?.code == .fileReadNoSuchFile && (cocoa as Error as? CocoaError)?.filePath == "/x", "NSError -> CocoaError")
    do { throw cocoa as Error } catch CocoaError.fileReadNoSuchFile { check(true, "catch CocoaError.code") } catch { check(false, "catch CocoaError.code") }
    check((CocoaError(.fileNoSuchFile) as NSError).code == 4 && (CocoaError(.fileNoSuchFile) as NSError).domain == NSCocoaErrorDomain, "CocoaError as NSError")
    let r = RetryError() as NSError
    check(r.localizedRecoveryOptions == ["Retry", "Cancel"] && r.recoveryAttempter != nil, "RecoverableError: recovery options + attempter")
    let ns = NSError(domain: "x.y", code: 1, userInfo: [NSLocalizedFailureReasonErrorKey: "Disk full."])
    check(ns.localizedDescription == "The operation couldn’t be completed. Disk full.", "NSError description from failure reason")
    NSError.setUserInfoValueProvider(forDomain: "x.provided") { _, key in key == NSLocalizedDescriptionKey ? "from provider" : nil }
    check(NSError(domain: "x.provided", code: 2, userInfo: nil).localizedDescription == "from provider", "NSError.setUserInfoValueProvider(forDomain:)")
}

@main struct Main {
    static func main() {
        let ns: NSString = "bridged" as NSString
        check(ns.length == 7, "String -> NSString (as)")
        let back = ns as String
        check(back == "bridged", "NSString -> String (as)")
        check(ns.hasPrefix("brid") && ns.appendingPathComponent("x") == "bridged/x", "NSString methods taking/returning String")
        let arr: NSArray = ["a", "b", "c"] as NSArray
        check(arr.count == 3, "[String] -> NSArray")
        let swiftArr = arr as! [String]
        check(swiftArr == ["a", "b", "c"], "NSArray -> [String]")
        let parts = "x,y,z".components(separatedBy: ",")
        check(parts == ["x", "y", "z"], "NSString API returning [String] (componentsSeparatedByString:)")
        let dict = ["one": 1, "two": 2] as NSDictionary
        check(dict.count == 2 && (dict["two"] as? Int) == 2, "[String: Int] -> NSDictionary + subscript")
        check(String(format: "%@ has %d items, pi=%.2f", "list", 3, 3.14159) == "list has 3 items, pi=3.14", "String(format:) with %@")
        let g = Greeter()
        check(g.greet("isim") == "Hello, isim!", "Swift subclass of NSObject")
        check(g.responds(to: #selector(Greeter.greet(_:))) && !g.responds(to: NSSelectorFromString("nope")), "#selector + respondsToSelector")
        let r = g.perform(#selector(Greeter.greet(_:)), with: "ObjC").takeUnretainedValue() as? String
        check(r == "Hello, ObjC!", "dynamic dispatch via performSelector into Swift")
        check(NSStringFromClass(Greeter.self).hasSuffix("Greeter"), "NSStringFromClass on a Swift class")
        check(g.isKind(of: NSObject.self) && g.isEqual(g) && g == g, "NSObject Equatable/isKindOfClass")
        let n = 42 as NSNumber
        check(n.intValue == 42 && (n as! Int) == 42, "Int <-> NSNumber")
        NSLog("NSLog from Swift: %@ / %ld", "string arg", 7)
        let bundleID = Bundle.main.bundleIdentifier
        check(bundleID == nil || bundleID!.contains("."), "Bundle.main")
        let d1 = Date(timeIntervalSince1970: 0)
        check(d1.timeIntervalSinceReferenceDate == -978307200 && Date() > d1, "Date value type")
        let nsd = d1 as NSDate
        check((nsd as Date) == d1, "Date <-> NSDate bridging")
        let loc = Locale(identifier: "pt_BR")
        check(loc.languageCode == "pt" && loc.regionCode == "BR" && loc.decimalSeparator == ",", "Locale value type")
        check(!Locale.current.identifier.isEmpty, "Locale.current")
        check(TimeZone(identifier: "UTC")?.secondsFromGMT() == 0, "TimeZone value type")
        let url = URL(string: "https://example.com:8080/a/b.txt?q=1#f")!
        check(url.host == "example.com", "URL host")
        check(url.port == 8080, "URL port")
        check(url.path == "/a/b.txt", "URL path")
        check(url.pathExtension == "txt", "URL pathExtension")
        check(url.query == "q=1", "URL query")
        check(URL(fileURLWithPath: "/tmp").appendingPathComponent("x").path == "/tmp/x", "file URL")
        let count = 3
        check(String(localized: "You have \(count) items") == "You have 3 items", "String(localized:) fallback with interpolation")
        check(NSLocalizedString("plain", comment: "") == "plain", "NSLocalizedString fallback")
        // thrown NSErrors: the runtime finds their Error conformance through CFError's
        let thrown: Error = NSError(domain: "isim.test", code: 7, userInfo: [NSLocalizedDescriptionKey: "boom"])
        check("\(type(of: thrown))" == "NSError", "NSError as Error: dynamic type")
        check((thrown as NSError).code == 7 && (thrown as NSError).localizedDescription == "boom", "Error as NSError bridging")
        // NSRegularExpression + NSRange <-> Range<String.Index>
        let text = "Café 42, naïve 7 — ok 1000"
        if let re = try? NSRegularExpression(pattern: #"(\p{L}+) (\d+)"#, options: [.caseInsensitive]) {
            let ms = re.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let pairs = ms.compactMap { m in Range(m.range(at: 1), in: text).map { String(text[$0]) } }
            check(pairs == ["Café", "naïve", "ok"], "NSRegularExpression.matches + Range(_:in:) (\(pairs))")
            check(re.numberOfMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length)) == 3, "numberOfMatches(in:range:)")
            let swapped = re.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$2 $1")
            check(swapped == "42 Café, 7 naïve — 1000 ok", "stringByReplacingMatches(withTemplate:)")
            check(re.firstMatch(in: text, range: NSRange(location: 0, length: 4)) == nil, "firstMatch respects the range")
        } else { check(false, "NSRegularExpression(pattern:) threw") }
        do { _ = try NSRegularExpression(pattern: "[a-"); check(false, "invalid pattern throws") } catch { check((error as NSError).code == 2048, "invalid pattern throws NSError 2048") }
        check(text.range(of: #"\d{4}"#, options: .regularExpression).map { String(text[$0]) } == "1000", "String.range(of:options: .regularExpression)")
        check(text.replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression) == "Café #, naïve # — ok #", "replacingOccurrences(.regularExpression)")
        check("Crème brûlée".localizedStandardContains("BRULEE") && "Hello".range(of: "LL", options: .caseInsensitive) != nil, "case/diacritic-insensitive search")
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let links = detector?.matches(in: "go to www.isim.dev now", range: NSRange(location: 0, length: 22)).compactMap { $0.url?.absoluteString }
        check(links == ["http://www.isim.dev"], "NSDataDetector links (\(links ?? []))")
        // key-value coding / observing from Swift
        let g2 = Greeter()
        var seen: [Int] = []
        let observation = g2.observe(\.count, options: [.initial, .new]) { _, change in seen.append(change.newValue ?? -1) }
        g2.count = 3; g2.count = 4
        check(seen == [0, 3, 4], "observe(\\.count) on an @objc dynamic property (\(seen))")
        observation.invalidate(); g2.count = 9
        check(seen == [0, 3, 4], "NSKeyValueObservation.invalidate()")
        check(g2.value(forKey: "count") as? Int == 9, "value(forKey:) on a Swift @objc property")
        g2.setValue(12, forKey: "count")
        check(g2.count == 12, "setValue(_:forKey:) on a Swift @objc property")
        var published: [Int] = []
        let sub = g2.publisher(for: \.count).sink { published.append($0) }
        g2.count = 13
        check(published == [12, 13], "publisher(for:) KVO publisher (\(published))")
        sub.cancel()

        // IndexSet, sorting, predicates
        var idx = IndexSet(integersIn: 2..<5)
        idx.insert(9); idx.remove(3)
        check(Array(idx) == [2, 4, 9] && idx.count == 3 && idx.contains(4) && idx.rangeView.count == 3, "IndexSet")
        let nsIdx = idx as NSIndexSet
        check(nsIdx.count == 3 && nsIdx.contains(9) && (nsIdx as IndexSet) == idx, "IndexSet <-> NSIndexSet bridging")
        var items = ["b", "a", "c"]; items.remove(atOffsets: IndexSet(integer: 0)); items.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        check(items == ["c", "a"], "remove(atOffsets:) / move(fromOffsets:toOffset:)")
        struct Song { var title: String; var plays: Int }
        let songs = [Song(title: "b", plays: 3), Song(title: "A", plays: 9), Song(title: "c", plays: 3)]
        check(songs.sorted(using: KeyPathComparator(\.plays, order: .reverse)).map(\.title) == ["A", "b", "c"], "sorted(using: KeyPathComparator)")
        check(songs.sorted(using: [KeyPathComparator(\Song.plays), KeyPathComparator(\Song.title, order: .reverse)]).map(\.title) == ["c", "b", "A"], "sorted(using: [comparators])")
        check(songs.sorted(using: SortDescriptor(\.title)).map(\.title) == ["A", "b", "c"], "SortDescriptor with localizedStandard strings")
        let people = [Greeter(), Greeter()]; people[0].count = 5; people[1].count = 1
        let byCount = (people as NSArray).sortedArray(using: [NSSortDescriptor(key: "count", ascending: true)]) as! [Greeter]
        check(byCount.first === people[1], "NSSortDescriptor on @objc properties")
        let pred = NSPredicate(format: "count > %d", 2)
        check(pred.evaluate(with: people[0]) && !pred.evaluate(with: people[1]), "NSPredicate(format:_:) with Swift arguments")
        check((["apple", "Banana", "cherry"] as NSArray).filtered(using: NSPredicate(format: "SELF CONTAINS[c] %@", "an")) as! [String] == ["Banana"], "NSArray.filtered(using:)")
        check(NSPredicate { obj, _ in (obj as? Int ?? 0) > 1 }.evaluate(with: 2), "NSPredicate(block:)")
        let os = NSMutableOrderedSet(array: [3, 1, 3, 2])
        check(os.count == 3 && (os.array as! [Int]) == [3, 1, 2], "NSMutableOrderedSet")
        let cache = NSCache<NSString, NSNumber>(); cache.setObject(1, forKey: "a")
        check(cache.object(forKey: "a") == 1, "NSCache<NSString, NSNumber>")
        // FileHandle, Scanner, ProcessInfo
        let fhURL = FileManager.default.temporaryDirectory.appendingPathComponent("swift-fh.txt")
        try? Data().write(to: fhURL)
        if let wh = try? FileHandle(forWritingTo: fhURL) {
            try? wh.write(contentsOf: Data("line one\nline two".utf8))
            check((try? wh.offset()) == 17, "FileHandle.write(contentsOf:) / offset()")
            try? wh.close()
        } else { check(false, "FileHandle(forWritingTo:)") }
        let rh = FileHandle(forReadingAtPath: fhURL.path)
        check(rh.flatMap { try? $0.readToEnd() }.map { String(decoding: $0, as: UTF8.self) } == "line one\nline two", "FileHandle.readToEnd()")
        check((try? rh?.seekToEnd()) == 17 && ((try? rh?.read(upToCount: 4)) ?? nil)?.isEmpty == true, "FileHandle.seekToEnd() / read(upToCount:)")
        let scanner = Scanner(string: "temp: -12.5C, id=0xff; name \"Ana\"")
        check(scanner.scanUpToString(":") == "temp" && scanner.scanString(":") == ":", "Scanner.scanUpToString / scanString")
        check(scanner.scanDouble() == -12.5 && scanner.scanCharacter() == "C", "Scanner.scanDouble / scanCharacter")
        _ = scanner.scanUpToString("=") ; _ = scanner.scanString("=")
        check(scanner.scanInt(representation: .hexadecimal) == 255, "Scanner.scanInt(representation: .hexadecimal)")
        _ = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\""))
        check(scanner.scanString("\"") != nil && scanner.scanCharacters(from: .letters) == "Ana", "Scanner.scanCharacters(from:)")
        check(!scanner.isAtEnd && scanner.currentIndex == scanner.string.index(before: scanner.string.endIndex), "Scanner.currentIndex")
        check(Scanner(string: "3.14159").scanDecimal() == Decimal(string: "3.14159"), "Scanner.scanDecimal()")
        let info = ProcessInfo.processInfo
        check(info.thermalState == .nominal && !info.isLowPowerModeEnabled, "ProcessInfo.thermalState / isLowPowerModeEnabled")
        check(info.processorCount > 0 && info.physicalMemory > 0 && info.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)), "ProcessInfo device facts")
        check(!info.isiOSAppOnMac && !info.isMacCatalystApp && info.environment["HOME"] != nil, "ProcessInfo.isiOSAppOnMac / environment")
        errorBridgingChecks()
        nsErrorParameterChecks()
        codingChecks()
        classBridgingChecks()
        fileAttributeChecks()
        fileManagerChecks()
        predicateAndDecimalChecks()
        operationChecks()
        fileChecks()
        localeChecks()
        print("swift foundation test: \(checks - failures)/\(checks) passed")
        exit(Int32(failures))
    }
}
