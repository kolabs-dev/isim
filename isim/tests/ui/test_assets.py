"""AVAssetWriter / AVAssetReader in depth (HelloAssets): frames written at uneven times keep them; metadata items
(title, QuickTime location) written and read back; a pass-through copy of the compressed samples (reader and writer
with nil settings) keeps times and sync samples and decodes; an audio mix with a volume ramp across two composition
tracks; a video composition output at its render size and frame rate; a composition read through a track output;
random access to time ranges; CoreMedia timebases with a timer. Needs ffmpeg."""
import re
import shutil

import pytest

pytestmark = pytest.mark.skipif(not shutil.which("ffmpeg"), reason="asset reading and writing need ffmpeg")


def test_assets(launch):
    app = launch("HelloAssets")
    app.wait_log(r"HelloAssets: done", timeout=60)
    app.wait_log(r"HelloAssets: timebases done", timeout=20)
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"uneven written status=completed"), "writer finishes"
    assert has(r"uneven times 0\.00,0\.10,0\.30,0\.35,0\.80,1\.00"), "frames keep their uneven times"
    assert has(r"metadata title=Uneven frames location=\+48\.8584\+002\.2945/"), "metadata items written and read back"
    assert has(r"format codec=avc1 160x120 parameterSets=2 nal=4"), "compressed format description: avcC, SPS + PPS"
    assert has(r"passthrough copied=6 syncs=\d status=completed times=0\.00,0\.10,0\.30,0\.35,0\.80,1\.00"), "pass-through copy"
    assert has(r"copy decodes frames=\d+ duration=1\.\d\d"), "the copy decodes"
    assert has(r"ramp found=true 0\.0->1\.0 over 2\.00"), "getVolumeRamp"
    m = has(r"audio mix frames=(\d+) start=([\d.]+) end=([\d.]+) status=completed")
    assert m and int(m.group(1)) > 90000 and float(m.group(2)) < 0.08 and float(m.group(3)) > 0.15, "audio mix: muted track, ramped track fades in"
    assert has(r"video composition frames=1[0-2] size=80x60"), "video composition output: render size and frame rate"
    assert has(r"composition read frames=\d+ last=2\.[0-3]\d duration=2\.40"), "composition read through a track output"
    assert has(r"random access first=0\.00,0\.10 second=(0\.\d\d,)*0\.80,1\.00 status=completed"), "random access: time ranges"
    t = has(r"timebase timer at ([\d.]+) after ([\d.]+) s rate=2\.0")
    assert t and 0.55 < float(t.group(1)) < 0.8 and 0.25 < float(t.group(2)) < 0.45, "timebase timer fires at its time (rate 2)"
    assert has(r"child effective rate=1\.0 sync=1\.00"), "timebase on a timebase"
