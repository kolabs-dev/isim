"""UIBezierPath (HelloBezierPaths): dashes, line caps and joins, addClip, contains with nonzero / even-odd rules,
per-corner rounding, reversing, transforms, current point, fill with blend mode and alpha, copying and secure coding.
The app checks pixels of paths it renders into bitmaps; the test checks its tiles on screen."""
import re

from isimtest import close, count_px


def test_bezier_paths(launch):
    app = launch("HelloBezierPaths")
    app.wait_log(r"bezier checks: \d+/\d+ passed")
    dump = app.wait_view(r"id=tiles")
    y0 = float(re.search(r"\(([-\d.]+) ([-\d.]+); [-\d.]+ x [-\d.]+\)[^\n]*id=tiles", dump).group(2))
    blue, white = (0, 122, 255), (255, 255, 255)
    shot = app.wait_shot(lambda s: close(s, 230, y0 + 295, blue), "the even-odd ring is drawn")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    fails = [l for l in log.splitlines() if l.startswith("FAIL")]
    assert not fails, "\n".join(fails)
    m = re.search(r"bezier checks: (\d+)/(\d+) passed", log)
    assert m and m.group(1) == m.group(2) and int(m.group(2)) >= 17, m and m.group(0)
    assert close(shot, 270, y0 + 295, white) and close(shot, 230, y0 + 295, blue), "even-odd ring: the hole stays empty"
    assert close(shot, 22, y0 + 250, white) and not close(shot, 95, y0 + 295, white), "addClip: stripes only inside the oval"
    dashes = count_px(shot, (20, y0 + 38, 160, 4), lambda c: c[2] > 200 and c[0] < 100)
    assert 0.4 * 160 * 4 < dashes < 0.8 * 160 * 4, f"the dashed line is broken into dashes ({dashes} px)"
