"""UIKit animation (HelloAnimations): keyframes (segments in order), layer property animation (corner radius, border),
UIViewPropertyAnimator (pause, scrub to 50%, reverse back to the start, run to the end, stop + finish at the current
position, spring, runningPropertyAnimator), transition(with:) flip and transition(from:to:) cross dissolve.
Mid-animation values come from layer.presentation(), so the pauses before each Report are real time.
Port of tests/ui/animations.sh."""
import re


def test_animations(launch):
    app = launch("HelloAnimations")
    app.wait_tap_id("btn-Keyframes")
    app.sleep(0.3)                                            # mid-way through keyframe 1
    app.tap_id("btn-Report")
    app.sleep(0.6)                                            # mid-way through keyframe 2
    app.tap_id("btn-Report")
    app.wait_log(r"keyframes done")

    app.tap_id("btn-Round")
    app.sleep(0.5)                                            # mid-way through the layer animation
    app.tap_id("btn-Report")
    app.wait_log(r"round done")

    app.tap_id("btn-Animator")
    app.sleep(0.5)                                            # the animator runs a while before the pause
    app.tap_id("btn-Pause")
    app.tap_id("btn-Scrub")
    app.wait_log(r"^presentation", count=4)
    app.tap_id("btn-Reverse")
    app.wait_log(r"animator finished at start")
    app.tap_id("btn-Animator")
    app.wait_log(r"animator finished at end")
    app.tap_id("btn-Animator")
    app.sleep(0.8)                                            # part-way, then stop
    app.tap_id("btn-Stop")
    app.wait_log(r"animator finished at current")

    app.tap_id("btn-Flip")
    app.sleep(0.2)                                            # mid-flip
    app.tap_id("btn-Report")
    app.wait_log(r"flip done")
    app.tap_id("btn-Swap")
    app.wait_log(r"swap done")
    app.tap_id("btn-Spring")
    app.tap_id("btn-Cubic")
    app.wait_log(r"spring done")
    app.wait_log(r"running animator done")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    reports = [l for l in log.splitlines() if l.startswith("presentation")]

    def nth(n, key):
        m = re.search(rf"{key}=(-?[0-9]+)", reports[n - 1]) if len(reports) >= n else None
        return int(m.group(1)) if m else None

    assert 45 < nth(1, "x") < 135 and nth(1, "y") == 130, f"keyframe 1 (x) runs before keyframe 2 (y): {reports[:1]}"
    assert nth(2, "x") == 140 and 135 < nth(2, "y") < 325, f"keyframe 2 (y) after keyframe 1 finished: {reports[1:2]}"
    assert "keyframes done true x=140 y=330" in log, "keyframes complete"
    assert 12 < nth(3, "radius") < 28 and 2 <= nth(3, "border") <= 6 and "round done radius=40 border=8" in log, \
        f"layer corner radius/border animate: {reports[2:3]}"
    assert "paused: state active, running false, fraction>0 true" in log, "property animator pauses"
    assert "presentation x=190 y=330 radius=45" in log, "fractionComplete scrubs (linear, 50%)"
    assert "animator finished at start, model x=140 radius=40" in log, "reversed animator finishes at the start"
    assert "animator finished at end, model x=240 radius=50" in log, "animator runs to the end"
    assert "stopped: state stopped, model x between true" in log and "animator finished at current" in log, \
        "stop + finish at the current position"
    assert "flip done: Back" in log and nth(5, "card width") is not None, "transition(with:) flip"
    assert re.search(r"card width=([0-9]|[0-9][0-9]|1[0-2][0-9])$", reports[4]), f"flip squashes mid-way: {reports[4]}"
    assert "swap done: A hidden true, B hidden false, alphas 1.0 1.0" in log, "transition(from:to:) cross dissolve"
    assert "spring done y=130" in log, "spring timing parameters"
    assert "running animator done alpha=0.5 at end" in log, "runningPropertyAnimator"
