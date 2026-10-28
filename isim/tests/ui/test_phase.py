"""PHASE (HelloPHASE; issue #386): isim's renderer behind PHASEEngine, checked in a capture of the output
(ISIM_AUDIO_TAP, 48 kHz stereo float): a spatial mixer pans by the source's direction and spreads with distance, a
channel mixer centres a mono sound, a push stream node plays the app's buffer, a muted group is silent and a switch
node plays its selected branch. Envelopes, meta parameters, blend and random nodes, groups, presets, duckers, errors and
the object tree are checked in the log."""
import array
import math
import re


def segments(path, gap=0.15):
    """the sounding parts of a capture: (left RMS, right RMS) of each run of sound between silences of `gap` seconds"""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    frames = len(a) // 2
    out, start, quiet = [], None, 0
    for i in range(frames):
        loud = abs(a[2 * i]) > 1e-3 or abs(a[2 * i + 1]) > 1e-3
        if loud:
            if start is None:
                start = i
            quiet = 0
        elif start is not None:
            quiet += 1
            if quiet > gap * 48000:
                out.append((start, i - quiet))
                start, quiet = None, 0
    if start is not None:
        out.append((start, frames - quiet))

    def rms(s, e, ch):
        n = max(1, e - s)
        return math.sqrt(sum(a[2 * i + ch] ** 2 for i in range(s, e)) / n)
    return [(rms(s, e, 0), rms(s, e, 1), (e - s) / 48000) for s, e in out]


def test_phase(launch, device_data):
    tap = device_data / "tap.f32"
    app = launch("HelloPHASE", env={"ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy", "ISIM_AUDIO_TAP": str(tap)})
    app.wait_log(r"HelloPHASE: done", timeout=60)
    assert app.quit() == 0
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"asset tone type=resident") and has(r"duplicate asset error code=true"), "sound assets"
    assert has(r"add twice error=true"), "an object has one parent"
    assert has(r"engine started state=true")
    for name in ("right", "left", "near", "far", "centre", "quiet"):
        assert has(fr"segment {name} reason=finished"), name
    assert has(r"segment push rendered=true indefinite=true"), "push stream node"
    assert has(r"muted group reason=finished muted=true")
    assert has(r"envelope 0\.50 0\.75 0\.00 domain 0-20"), "envelope: linear up, squared down, clamped"
    assert has(r"meta clamped=1\.0 faded=0\.0 range=0\.0-1\.0"), "number meta parameter: clamped, faded"
    assert has(r"registered container=true children=1")
    assert has(r"missing mixer parameters error=true") and has(r"unknown asset error=true"), "sound event errors"
    assert has(r"cone inner=90\.0 outer=180\.0 gain=0\.25 subbands=1")
    assert has(r"groups fx gain=0\.50 registered=fx,music preset active=true duckers=1 active=true")
    assert has(r"world x=1\.0 y=2\.0 forward z=-1\.0"), "world transforms through the object tree"
    assert has(r"engine stopped state=true events=0")

    segs = segments(tap)
    # right, left, near, far, centre, push, quiet (the muted group makes none)
    assert len(segs) == 7, segs
    right, left, near, far, centre, push, quiet = segs
    assert right[1] > 4 * right[0] and left[0] > 4 * left[1], f"panning: {right} {left}"
    assert abs(near[0] - near[1]) < 0.05 * near[0], f"in front: centred {near}"
    assert 3.2 < near[0] / far[0] < 4.8, f"geometric spreading: 1 m vs 4 m {near} {far}"
    assert abs(centre[0] - centre[1]) < 0.02 * centre[0] and abs(centre[0] - 0.5 / math.sqrt(2) / math.sqrt(2)) < 0.03, f"channel mixer {centre}"
    assert abs(push[0] - centre[0]) < 0.05 * centre[0], f"push stream at the channel mixer's level {push} {centre}"
    assert 0.4 < quiet[0] / centre[0] < 0.6, f"switch: the quiet branch (-6 dB) {quiet} {centre}"
