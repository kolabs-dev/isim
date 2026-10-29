"""BackgroundTasks' continued processing tasks (iOS 26, issue #413) under `isim boot`, with HelloSystem's photo export:
the task starts at once in the foreground and goes on in the background; two run at a time, a third `.queue` request
waits (pendingTaskRequests) and a `.fail` one is refused with immediateRunIneligible; the system's Live Activity (drawn
by the shell) shows the title, the subtitle the task updates and its progress on the Lock Screen and in the Dynamic
Island, and its cancel button expires the task; a task that finishes ends its Live Activity and the queued one starts.
Before iOS 26 the app says it needs iOS 26. CONTINUED_SHOTS=DIR keeps the screenshots."""
import os

import pytest

APP = "dev.isim.samples.HelloSystem"
SHOTS = os.environ.get("CONTINUED_SHOTS")


def shot(dev, name):
    if SHOTS:
        dev.wait_shot_still().save(os.path.join(SHOTS, f"{name}.png"))


@pytest.mark.os_matrix
def test_continued_processing(launch, ios):
    dev = launch(None, install=["HelloSystem"])
    dev.send(f"launch {APP}")
    dev.wait_tap_id("continued")
    if int(ios[0] or os.environ.get("ISIM_OS_VERSION", "18")) < 26:
        dev.wait_log(r"HelloSystem: continued processing tasks need iOS 26")
        return
    dev.wait_log(r"HelloSystem: export 1 started: Exporting Photos")
    dev.wait_log(r"HelloSystem: export 1 submitted \(gpu supported: false\)")
    dev.wait_log(r"isim shell: continued processing task dev\.isim\.samples\.HelloSystem\.export\.1 of System shown")
    dev.tap_id("continued")
    dev.wait_log(r"HelloSystem: export 2 started")
    dev.tap_id("continuedFail")                                   # two run already: refused
    dev.wait_log(r"HelloSystem: export 3 refused BGTaskSchedulerErrorDomain 4")
    dev.tap_id("continued")                                       # queued
    dev.wait_log(r"isim: BGTaskScheduler: queued continued processing task dev\.isim\.samples\.HelloSystem\.export\.4")
    dev.wait_log(r"HelloSystem: pending continued \[\"dev\.isim\.samples\.HelloSystem\.export\.4\"\]")

    dev.send("home")                                              # the tasks go on in the background
    dev.wait_dump(r"IsimBackgroundTask .* id=bgtask-dev\.isim\.samples\.HelloSystem\.export\.1 text=Exporting Photos — \d+ of 20 photos \(\d+%\)")
    dev.send("lock")
    dev.wait_dump(r"id=live-activity text=bgtask:")
    dev.wait_dump(r"id=bgtask-cancel text=Exporting Photos")
    shot(dev, "continued-lock-screen")
    dev.tap_id("bgtask-cancel")                                   # the first card's task expires
    dev.wait_log(r"isim shell: continued processing task \S+ cancelled by the user")
    dev.wait_log(r"HelloSystem: export [12] expired")
    dev.wait_log(r"HelloSystem: export [12] cancelled")
    dev.wait_log(r"isim: BGTaskScheduler: started continued processing task dev\.isim\.samples\.HelloSystem\.export\.4")
    dev.wait_log(r"HelloSystem: export [12] completed", timeout=30)    # the other one finishes its 20 steps
    dev.wait_log(r"isim shell: continued processing task dev\.isim\.samples\.HelloSystem\.export\.[12] ended")
    dev.send("unlock")
    if "id=dynamic-island" in dev.wait_dump(r"IsimBackgroundTask .*export\.4").string:   # iPhones with the Dynamic Island
        dev.wait_dump(r"id=dynamic-island text=compact")
        dev.tap_id("dynamic-island")
        dev.wait_dump(r"id=dynamic-island text=expanded")
        dev.wait_dump(r"IsimBackgroundTaskButton .* id=bgtask-cancel")
        shot(dev, "continued-island")
        dev.tap_id("dynamic-island")
    dev.wait_log(r"HelloSystem: export 4 completed", timeout=30)
    dev.wait_log(r"isim shell: continued processing task dev\.isim\.samples\.HelloSystem\.export\.4 ended")
