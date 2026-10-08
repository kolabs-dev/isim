"""UIKit animation (HelloAnimations): keyframes (segments in order), layer property animation (corner radius, border),
UIViewPropertyAnimator (pause, scrub to 50%, reverse back to the start, run to the end, stop + finish at the current
position, spring, runningPropertyAnimator), transition(with:) flip and transition(from:to:) cross dissolve.
Mid-animation values come from layer.presentation(): Report is tapped until it samples the animation part-way.
Port of tests/ui/animations.sh."""
import re


def test_animations(launch):
    app = launch("HelloAnimations")

    def values(line):
        return {k: int(v) for k, v in re.findall(r"(\w+)=(-?[0-9]+)", line)}

    def report():
        n = app.count(r"^presentation")
        app.tap_id("btn-Report")
        return app.wait_log(r"^presentation.*", count=n + 1).group(0)

    def report_until(pred, done):
        """Report the presentation layer until pred(values) holds (the animation is part-way) and return that line;
        None once done() (the animation ended) holds first. Polled rather than slept a fixed time, so a loaded machine
        that renders few frames still samples the animation mid-way."""
        while True:
            line = report()
            if pred(values(line)):
                return line
            if done():
                return None

    app.wait_tap_id("btn-Keyframes")
    key1 = report_until(lambda v: 45 < v["x"] < 135 and v["y"] == 130, lambda: app.has(r"keyframes done"))  # keyframe 1
    key2 = report_until(lambda v: v["x"] == 140 and 135 < v["y"] < 325, lambda: app.has(r"keyframes done"))  # keyframe 2
    app.wait_log(r"keyframes done")

    app.tap_id("btn-Round")
    roundmid = report_until(lambda v: 12 < v["radius"] < 28 and 2 <= v["border"] <= 6,
                            lambda: app.has(r"round done"))  # mid-way through the layer animation
    app.wait_log(r"round done")

    app.tap_id("btn-Animator")
    report_until(lambda v: 145 < v["x"] < 175, lambda: app.has(r"animator finished"))  # runs a while before the pause
    app.tap_id("btn-Pause")
    n = app.count(r"^presentation")
    app.tap_id("btn-Scrub")
    app.wait_log(r"^presentation", count=n + 1)
    app.tap_id("btn-Reverse")
    app.wait_log(r"animator finished at start")
    app.tap_id("btn-Animator")
    app.wait_log(r"animator finished at end")
    app.tap_id("btn-Animator")
    report_until(lambda v: 140 < v["x"] < 230, lambda: app.count(r"animator finished at end") >= 2)
    app.tap_id("btn-Stop")                                    # part-way (in the first half of its 2 s), then stop
    app.wait_log(r"animator finished at current")

    app.tap_id("btn-Flip")
    flipmid = report_until(lambda v: v["width"] < 130, lambda: app.has(r"flip done"))  # mid-flip
    app.wait_log(r"flip done")
    app.tap_id("btn-Swap")
    app.wait_log(r"swap done")
    app.tap_id("btn-Spring")
    app.tap_id("btn-Cubic")
    app.wait_log(r"spring done")
    app.wait_log(r"running animator done")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    v1, v2, v3 = (values(l) if l else {} for l in (key1, key2, roundmid))
    assert key1 and 45 < v1["x"] < 135 and v1["y"] == 130, f"keyframe 1 (x) runs before keyframe 2 (y): {key1}"
    assert key2 and v2["x"] == 140 and 135 < v2["y"] < 325, f"keyframe 2 (y) after keyframe 1 finished: {key2}"
    assert "keyframes done true x=140 y=330" in log, "keyframes complete"
    assert roundmid and 12 < v3["radius"] < 28 and 2 <= v3["border"] <= 6 and "round done radius=40 border=8" in log, \
        f"layer corner radius/border animate: {roundmid}"
    assert "paused: state active, running false, fraction>0 true" in log, "property animator pauses"
    assert "presentation x=190 y=330 radius=45" in log, "fractionComplete scrubs (linear, 50%)"
    assert "animator finished at start, model x=140 radius=40" in log, "reversed animator finishes at the start"
    assert "animator finished at end, model x=240 radius=50" in log, "animator runs to the end"
    assert "stopped: state stopped, model x between true" in log and "animator finished at current" in log, \
        "stop + finish at the current position"
    assert "flip done: Back" in log and flipmid is not None, "transition(with:) flip"
    assert re.search(r"card width=([0-9]|[0-9][0-9]|1[0-2][0-9])$", flipmid), f"flip squashes mid-way: {flipmid}"
    assert "swap done: A hidden true, B hidden false, alphas 1.0 1.0" in log, "transition(from:to:) cross dissolve"
    assert "spring done y=130" in log, "spring timing parameters"
    assert "running animator done alpha=0.5 at end" in log, "runningPropertyAnimator"
