"""HelloDiagnostics: logging & diagnostics (issue #33).

- The log store: Swift Logger / os_log, C os_log, NSLog and signposts (OSSignposter, C os_signpost) read back with
  OSLogStore(scope: .currentProcessIdentifier): levels, categories, privacy, format strings and components, signpost
  types, predicates, reverse order; the system scope throws. The `signposts` script command summarizes intervals.
- MetricKit measured: a hang of the main thread is a hang diagnostic (with its stack) as soon as it ends;
  `metrickit deliver` brings this run's metric payload (CPU, memory, launch, hangs, foreground time, display
  luminance, MetricKit signposts, disk space usage); GPU 0, no cellular.
- iOS 27 (issue #354): MetricManager's reports as async sequences: the metric report (one interval entry, a state entry
  per StateReporting state with its metadata, Codable grouped by domain) and the hang's diagnostic report (call stack
  tree, the states then); trackLaunchTask before the first frame, and too late after it; @ReportableMetadata.
- Crash reports: a SIGSEGV in C, an uncaught NSRangeException and a Swift fatalError each write an .ips report
  (`isim crashlog list/show`); the next launch gets an MXCrashDiagnostic and the crashed run's metrics with its exit.
- A slow launch (2.5 s) is an MXAppLaunchDiagnostic.
- CFRunLoop on the main loop UIKit drives: an observer (CFRunLoopObserverCreateWithHandler) sees the hang between two
  waits, a CFRunLoopTimer fires, a CFRunLoopPerformBlock block runs in the default mode.
"""
import os
import re
import subprocess

from isimtest import ISIM

APP = "HelloDiagnostics"


def crashlog(data, *args):
    r = subprocess.run([str(ISIM), "crashlog", *args], env=dict(os.environ, ISIM_DATA=str(data)), capture_output=True, text=True, timeout=60)
    return r.stdout + r.stderr


def test_log_store_signposts_metrickit(launch):
    app = launch(APP)
    app.wait_log(r"diag store system")
    log = app.log
    assert ('diag store logs=5 signposts=8 info="Loaded 3 items for <private>" level=2 category=ui '
            'format="Loaded %@ items for %@" components=%@=3,%@=<private> error="Failed with code 404"') in log, \
        "OSLogStore: Logger entries (level, category, redacted message, format, components)"
    assert "diag store signposts CWork:begin CTick:event CWork:end Load:begin Load:end Fetch:begin Fetch:end Tap:event" in log, \
        "OSLogStore: C and Swift signposts in order"
    assert 'diag store c="C says 42 and hello" legacy=true' in log, "C os_log and Swift os_log in the store"
    assert "diag store nslog=1 reverse=true errors=1 pid=true" in log, "NSLog, reverse order, messageType predicate"
    assert "diag store system throws" in log, "the system scope is not available to apps"
    assert "diag signposter enabled=true disabled=false" in log

    app.wait_log(r"diag hang duration=true stack=true frames=true", timeout=30)   # a hang diagnostic, right away
    # CFRunLoop: the block and the timer ran on the main loop; its observer saw the hang (busy between two waits)
    assert "diag runloop block mode=kCFRunLoopDefaultMode observing=true" in app.log and "diag runloop timer fired" in app.log
    hang = app.wait_log(r"diag runloop hang (\d+\.\d) s")
    assert 0.5 <= float(hang.group(1)) < 3, hang.group(0)
    app.send("signposts dev.isim.diag")
    load = app.wait_log(r"isim signposts: dev.isim.diag:PointsOfInterest Load events 0 intervals 1 open 0 total (\d+\.\d) ms")
    assert float(load.group(1)) >= 45, f"interval duration measured: {load.group(0)}"
    app.wait_log(r"isim signposts: dev.isim.diag:PointsOfInterest Tap events 1 intervals 0")   # printed after Load

    app.send("metrickit deliver")
    m = app.wait_log(r"diag metric payload .*")
    line = m.group(0)
    for part in ("version=2.1", "cpu=true", "peak=true", "launch=1", "hangs=1", "fg=true", "gpu=0.0", "cellular=nil",
                 "apl=true", "signposts=Diag:Mark=1/0,Diag:Work=2/1", "json=true", "disk=true"):
        assert part in line, f"measured metric payload: {part} in {line}"
    app.wait_log(r"diag past payloads 1")
    assert "no crash reports" in crashlog(app.data, "list")


def test_metric_reports_ios27(launch):
    """iOS 27 (issue #354): MetricManager's reports, StateReporting's states, trackLaunchTask, @ReportableMetadata."""
    app = launch(APP, os_version="27", device="iphone17")
    for line in ("diag launch task result=3 errors=0", "diag launch task late reason=pastDeadline", "diag state metadata items,name items=true",
                 "isim state: dev.isim.diag.screen -> home"):
        app.wait_log(re.escape(line))
    app.wait_log(r"diag report hang duration=true frames=true named=true states=(home|detail) pid=true", timeout=30)
    app.wait_log(r"isim state: dev\.isim\.diag\.screen -> detail")
    app.send("metrickit deliver")
    app.wait_log(r"diag report metrics intervals=1 cpu=true disk=true groups=\d+ signposts=Diag:Mark=1,Diag:Work=2 states=detail,home "
                 r"home=true byDomain=2 json=true decoded=2 os=iOS")


def test_crash_reports(launch):
    # a SIGSEGV in C
    app = launch(APP, env={"HELLODIAG": "segv"})
    app.wait_log(r"crash report written to .*\.ips")
    app.wait_exit()
    listing = crashlog(app.data, "list")
    assert "HelloDiagnostics" in listing and "EXC_BAD_ACCESS (SIGSEGV)" in listing, listing
    report = crashlog(app.data, "show")
    assert "Identifier:          dev.isim.samples.HelloDiagnostics" in report and "Version:             2.1 (21)" in report, report
    assert "Exception Type:  EXC_BAD_ACCESS (SIGSEGV) (KERN_INVALID_ADDRESS at 0x0000000000000000)" in report, report
    assert "Thread 0 Crashed::  Dispatch queue: com.apple.main-thread" in report and "cdiag_crash_segv" in report, report
    assert '"bug_type": "309"' in crashlog(app.data, "show", "1", "--json"), "the .ips header line"

    # the next launch: the crash as an MXCrashDiagnostic, the crashed run's metrics with its exit
    app = launch(APP)
    app.wait_log(r'diag crash signal=11 type=1 version=2\.1 reason=- termination="Namespace SIGNAL, Code 11 Segmentation fault: 11" stack=true')
    app.wait_log(r"diag metric payload .*badAccess=1")
    app.quit()

    # an uncaught Objective-C exception
    app = launch(APP, env={"HELLODIAG": "exception"})
    app.wait_log(r"crash report written")
    app.wait_exit()
    report = crashlog(app.data, "show")
    assert "Exception Type:  EXC_CRASH (SIGABRT)" in report, report
    assert "*** Terminating app due to uncaught exception 'NSRangeException', reason: '*** -[NSArray objectAtIndex:]: index 3 beyond bounds [0 .. 1]'" in report, report
    assert "Last Exception Backtrace:" in report, report
    app = launch(APP)
    app.wait_log(r"diag crash signal=6 type=10 version=2\.1 reason=NSRangeException")
    app.wait_log(r"diag metric payload .*abnormal=1")
    app.quit()

    # a Swift fatalError
    app = launch(APP, env={"HELLODIAG": "fatal"})
    app.wait_log(r"crash report written")
    app.wait_exit()
    assert "EXC_BAD_INSTRUCTION (SIGILL)" in crashlog(app.data, "list")
    app = launch(APP)
    app.wait_log(r"diag crash signal=4 type=2 ")
    app.wait_log(r"diag metric payload .*illegal=1")
    app.quit()
    assert len(crashlog(app.data, "list").splitlines()) == 3
    assert "removed 3 crash report(s)" in crashlog(app.data, "clear")


def test_slow_launch(launch):
    app = launch(APP, env={"HELLODIAG": "slowlaunch"})
    app.wait_log(r"diag launch duration=true stack=true", timeout=30)
