"""isim boot with HelloBackground: background execution. Without anything keeping it running, an app in the background
is suspended (its timer stops ticking) and resumes when it comes back; background audio (UIBackgroundModes audio + the
playback category) keeps it running and playing (checked on the mixed output, ISIM_AUDIO_TAP); background location
updates (UIBackgroundModes location + allowsBackgroundLocationUpdates) keep it running, deliver locations and show the
blue location indicator (tapping it opens the app). Haptics and vibration are logged. ISIM_SUSPEND=0 turns suspension
off. Port of tests/ui/background.sh (the time in the background is real: the checks count timer ticks there)."""
import array
import math
import re

from isimtest import count

APP = "dev.isim.samples.HelloBackground"
TICK = r"tick [0-9]* state=background"


def bgticks(dev, start, end):
    return len(re.findall(TICK, dev.between(start, end)))


def ticks_since(dev, marker):
    return len(re.findall(TICK, dev.log.split(marker, 1)[-1])) if marker in dev.log else 0


def longest_sound(path):
    """seconds of the longest stretch of sound (RMS > 0.02 per 0.1 s window) in the float32 stereo 48 kHz tap"""
    a = array.array("f")
    a.frombytes(path.read_bytes())
    w, best, run = 4800 * 2, 0, 0
    for i in range(0, len(a) - w, w):
        seg = a[i:i + w]
        loud = math.sqrt(sum(v * v for v in seg) / len(seg)) > 0.02
        run = run + 1 if loud else 0
        best = max(best, run)
    return round(best * 0.1, 1)


def blue(c):
    return math.dist(c, (0, 122, 255)) / math.sqrt(3) <= 0.10 * 255   # #007aff, 10 % fuzz


def test_background(boot, device_data):
    tap = device_data / "tap.f32"
    dev = boot(apps=["HelloBackground"], env={
        "ISIM_LOCATION_PERMISSION": "wheninuse", "ISIM_SUSPEND_SECONDS": "2",
        "ISIM_LOCATION": "37.3349,-122.0090;37.3449,-122.0090@300", "ISIM_AUDIO": "1", "SDL_AUDIO_DRIVER": "dummy",
        "ISIM_AUDIO_TAP": str(tap)})
    dev.launch(APP)
    dev.wait_opened("HelloBackground")
    dev.wait_tap("haptics")
    dev.wait_log(r"haptics done")
    for line in (r"haptic impact \(heavy\)", r"haptic notification \(success\)", r"haptic selection",
                 r"isim AudioToolbox: vibrate"):
        assert dev.has(line), f"haptics and vibration are logged: {line}"
    dev.home()
    dev.wait_log(r"isim shell: suspended HelloBackground\.app")         # nothing keeps it running: suspended
    dev.sleep(2)                                                        # suspended: no ticks meanwhile
    dev.launch(APP)
    dev.wait_log(r"resumed HelloBackground\.app \(foreground\)")         # then resumed
    dev.wait_opened("HelloBackground", count=1)

    dev.wait_tap("play")
    dev.wait_log(r"audio playing")
    assert bgticks(dev, "haptics done", "audio playing") <= 3, "suspended: the timer stops in the background"
    dev.home()
    dev.wait_log(r"running in the background: audio")
    dev.wait_until(lambda: ticks_since(dev, "audio playing") >= 6, timeout=15,
                   what="background audio keeps the app running (ticks)")
    dev.launch(APP)
    dev.wait_opened("HelloBackground", count=1)
    dev.wait_tap("stop")
    dev.wait_log(r"audio stopped")
    assert bgticks(dev, "audio playing", "audio stopped") >= 5, "background audio keeps the app running"
    s = longest_sound(tap)
    assert s >= 5, f"the tone keeps playing while the app is in the background ({s} s)"

    dev.tap_id("track")
    dev.wait_log(r"tracking location")
    dev.home()
    dev.wait_log(r"running in the background: location-indicator")
    dev.wait_log(r"location [0-9]* state=background")                  # background location delivers locations
    dev.wait_until(lambda: ticks_since(dev, "tracking location") >= 6, timeout=15,
                   what="background location keeps the app running (ticks)")
    # the shell prints its own overlays (the indicator) to the log on every dump
    dev.wait_until(lambda: dev.tree() is not None and dev.has(r"IsimLocationIndicator .*id=location-indicator text=Background"),
                   what="the location indicator in the status bar")
    dev.wait_until(lambda: count(dev.screenshot("indicator"), (40, 14, 120, 44), blue) > 400,
                   what="the blue location indicator (pixels)")
    dev.tap_id("location-indicator")
    dev.wait_log(r"location indicator opens HelloBackground\.app")      # tapping it opens the app
    dev.wait_opened("HelloBackground", count=1)
    dev.wait_tap("untrack")
    dev.wait_log(r"location stopped")
    assert bgticks(dev, "tracking location", "location stopped") >= 5, "background location keeps it running"
    dev.home()
    dev.wait_log(r"isim shell: suspended HelloBackground\.app", count=2)   # after the location stops: suspended again
    assert dev.quit() == 0


def test_suspension_off(boot):
    dev = boot(apps=["HelloBackground"], env={"ISIM_SUSPEND": "0", "ISIM_SUSPEND_SECONDS": "2"})
    dev.launch(APP)
    dev.wait_opened("HelloBackground")
    dev.home()
    dev.wait_log(r"isim shell: home")
    dev.wait_until(lambda: dev.count(TICK) >= 5, timeout=15, what="ISIM_SUSPEND=0: ticks in the background")
    assert not dev.has(r"suspended HelloBackground"), "ISIM_SUSPEND=0: never suspended"
    assert dev.quit() == 0
