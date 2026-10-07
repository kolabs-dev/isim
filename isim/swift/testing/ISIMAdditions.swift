// isim additions compiled into the Testing module (self-authored; internal, not part of Testing's API).
// They stand in for Darwin SDK API that swift-testing uses on Apple platforms and that isim's SDK does not have:
// isim's `Darwin` is a plain Clang module without Apple's Darwin Swift overlay, and its Foundation is isim's own.
internal import _TestingInternals

/// Darwin overlay: `CLOCK_UPTIME_RAW` (the C macro aliases an enumerator, which Swift does not import).
/// isim's libSystem maps Darwin clock 8 to Linux CLOCK_MONOTONIC_RAW.
var CLOCK_UPTIME_RAW: clockid_t { _CLOCK_UPTIME_RAW }

/// Darwin overlay: `DarwinBoolean` (C `Boolean`); only used to call `_CFErrorSetCallStackCaptureEnabled`, which
/// isim's CoreFoundation does not have, so the call is never made.
typealias DarwinBoolean = Bool

extension UnsafeRawBufferPointer {
  /// Foundation: `UnsafeRawBufferPointer: ContiguousBytes` (isim's Foundation does not declare that conformance).
  func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
    try body(self)
  }
}

// MARK: - C entry point for test runners

/// isim: C-callable entry point for test runners, e.g. isim's XCTest runner after it dlopen()s an `.xctest` bundle
/// (test discovery sees every image loaded so far, including bundles loaded with dlopen()).
///
///     typedef void (*isim_swift_testing_completion)(int exitCode, void *context);
///     void isim_swift_testing_run(int argc, const char *const *argv, isim_swift_testing_completion done, void *context);
///
/// `argv` uses Swift Package Manager's test-runner arguments, `argv[0]` (the program name) is ignored: --filter REGEX,
/// --skip REGEX (both repeatable), --list-tests, --no-parallel, --verbose/--very-verbose/--quiet, --xunit-output PATH,
/// --event-stream-output-path PATH --event-stream-version 0, --repetitions N, --repeat-until pass|fail, ...
/// The run starts on a new task and the call returns at once; the human-readable report goes to stderr, and `done`
/// is called (on an arbitrary thread) with the exit code: 0 all passed, 1 a test failed (or bad arguments),
/// 69 (EX_UNAVAILABLE) no test matched. The caller must keep the main thread servicing the main queue (run loop or
/// dispatch_main()) until then, because @MainActor tests run there.
@_cdecl("isim_swift_testing_run")
@usableFromInline func isim_swift_testing_run(
  _ argc: CInt,
  _ argv: UnsafePointer<UnsafePointer<CChar>?>?,
  _ done: (@convention(c) (CInt, UnsafeMutableRawPointer?) -> Void)?,
  _ context: UnsafeMutableRawPointer?
) {
  var arguments = [String]()
  if let argv {
    for i in 0 ..< Int(max(argc, 0)) {
      arguments.append(argv[i].map { String(cString: $0) } ?? "")
    }
  }
  if arguments.isEmpty {
    arguments = ["swift-testing"]
  }
  let context = UInt(bitPattern: context)
  Task.detached {
    let exitCode: CInt
    do {
      let args = try parseCommandLineArguments(from: arguments)
      exitCode = await entryPoint(passing: args, eventHandler: nil)
    } catch {
      try? FileHandle.stderr.write("\(error)\n")
      exitCode = EXIT_FAILURE
    }
    done?(exitCode, UnsafeMutableRawPointer(bitPattern: context))
  }
}
