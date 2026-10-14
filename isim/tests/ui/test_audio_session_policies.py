"""AVAudioSession's modes, options and policies for call and video apps (HelloAudioSessionPolicies, issue #224): the
videoChat / videoRecording / measurement / voicePrompt modes, RouteSharingPolicy, prefersNoInterruptionsFromSystemAlerts
and overrideMutedMicrophoneInterruption against the `audio interrupt begin alert|muted` script commands, and
echo-cancelled input (iOS 18.2 and later: checked under every iOS version)."""
import re

import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_audio_session_policies(launch, ios):
    app = launch("HelloAudioSessionPolicies")
    app.wait_log(r"^as ready$")
    r = {m[0]: m[1] for m in re.findall(r"^as (\S+) (.*)$", app.log, re.M)}
    assert r["modes"] == ("AVAudioSessionModeVideoChat,AVAudioSessionModeVideoRecording,AVAudioSessionModeMeasurement,"
                          "AVAudioSessionModeVoicePrompt"), r["modes"]
    assert r["policy-record"] == "error=-50", "a long-form policy needs the playback category"
    assert r["policy-playback"] == "category=AVAudioSessionCategoryPlayback policy=3", r["policy-playback"]
    assert r["call"] == "mode=AVAudioSessionModeVideoChat options=136 policy=0 noAlertInterruptions=true", r["call"]
    if major(ios) >= 26:   # iOS 18 is 18.0: setPrefersEchoCancelledInput is 18.2
        assert r["echo"] == "prefers=true available=true enabled=true", r["echo"]
    else:
        assert r["echo"] == "unavailable before iOS 18.2", r["echo"]

    # what the app opted out of leaves it running; a plain interruption (a phone call) still arrives
    app.send("audio interrupt begin alert")
    app.wait_log(r"interruption ignored \(prefersNoInterruptionsFromSystemAlerts\)")
    app.send("audio interrupt end")
    app.send("audio interrupt begin muted")
    app.wait_log(r"interruption ignored \(overrideMutedMicrophoneInterruption\)")
    app.send("audio interrupt end")
    app.send("audio interrupt begin")
    app.wait_log(r"^as interruption began reason=0$")
    app.send("audio interrupt end")
    app.wait_log(r"^as interruption ended$")
    assert re.findall(r"^as interruption .*$", app.log, re.M) == ["as interruption began reason=0", "as interruption ended"], \
        "only the plain interruption reaches the app"
