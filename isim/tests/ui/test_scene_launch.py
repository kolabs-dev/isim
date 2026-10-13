"""How scenes come and go (HelloSceneLaunch): destructionConditions (iOS 26: user dismissal destroys the scene when
the app goes home, a system disconnection discards the session at the next launch), the window scene's focus system,
connection options other frameworks add (launch markers: NFC, credential sessions, marketplace links, workout
recovery), app intents directed to scenes, an app extension's HealthKit authorization request, and app entities
annotated on views."""
import plistlib

import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_user_dismissal(launch, ios):
    if major(ios) < 26:
        pytest.skip("destructionConditions is iOS 26")
    app = launch("HelloSceneLaunch", env={"HELLO_DESTROY": "dismiss"})
    app.wait_log(r"^sl connected 1 conditions 1 restored false$")
    app.send("home")
    app.wait_log(r"dismissed by the user: destroyed \(userInitiatedDismissal\)")
    app.wait_log(r"^sl disconnected$")
    app.wait_log(r"^sl discarded 1$")
    assert app.log.count("sl background") == 1
    app.send("activate")
    app.wait_log(r"^sl connected 2 conditions 1 restored false$")


@pytest.mark.os_matrix
def test_system_disconnection(launch, ios):
    if major(ios) < 26:
        pytest.skip("destructionConditions is iOS 26")
    app = launch("HelloSceneLaunch", env={"HELLO_DESTROY": "system"})
    app.wait_log(r"^sl ready$")
    app.send("home")
    app.wait_log(r"^sl background$")
    assert app.quit() == 0
    again = launch("HelloSceneLaunch")                                    # the same device data
    again.wait_log(r"destroyed by the system disconnection")
    again.wait_log(r"^sl discarded 1$")
    again.wait_log(r"^sl connected 1 conditions 0 restored false$")


def test_kept_session_restores(launch):
    """Without destruction conditions the session's state comes back."""
    app = launch("HelloSceneLaunch")
    app.wait_log(r"^sl ready$")
    app.send("home")
    app.wait_log(r"^sl background$")
    assert app.quit() == 0
    again = launch("HelloSceneLaunch")
    again.wait_log(r"^sl connected 1 conditions 0 restored true$")


@pytest.mark.parametrize("device,has", [("iphone16pro", False), ("ipadpro11", True)])
def test_focus_system(launch, device, has):
    app = launch("HelloSceneLaunch", device=device)
    app.wait_log(rf"^sl focus system {'true' if has else 'false'}$")


@pytest.mark.parametrize("marker,line", [
    ("isim-nfc:readerDetected", "sl nfc readerDetected"),
    ("isim-nfc:presentation", "sl nfc presentation"),
    ("isim-credential:presentation", "sl credential presentation"),
    ("isim-marketplace:product:12345:7", "sl marketplace product 12345 7"),
    ("isim-marketplace:search:maps%20app", "sl marketplace search maps app"),
    ("isim-marketplace:auth:anna", "sl marketplace auth anna"),
    ("isim-workout-recovery", "sl workout recovery"),
])
def test_connection_options(launch, marker, line):
    app = launch("HelloSceneLaunch", os_version="26", env={"ISIM_LAUNCH_URL": marker})
    app.wait_log(r"^sl ready$")
    assert line in app.log
    for other in ("sl nfc", "sl credential", "sl marketplace", "sl workout"):
        if not line.startswith(other):
            assert other not in app.log, other


def test_scene_app_intent(launch, tmp_path):
    run = tmp_path / "intent-run"
    run.mkdir()
    with open(run / "request.plist", "wb") as f:
        plistlib.dump({"kind": "appintent", "intent": "HelloSceneLaunch.OpenNoteIntent", "dir": str(run), "source": "test"}, f)
    app = launch("HelloSceneLaunch", os_version="26", env={"ISIM_LAUNCH_URL": f"isim-intent:{run / 'request.plist'}"})
    app.wait_log(r"^sl launch intent OpenNoteIntent$")                   # connectionOptions.appIntent
    app.wait_log(r"isim AppIntents: “Open Note” goes to scene .* \(content OpenNoteIntent\)")
    app.wait_log(r"^sl scene will perform OpenNoteIntent$")               # AppIntentSceneDelegate
    app.wait_log(r"^sl intent performed scene true content OpenNoteIntent$")
    assert "sl navigation for scene" not in app.log, "the scene delegate handles it, so performNavigation(forScene:) is not called"


def test_health_authorization_request(launch):
    app = launch("HelloSceneLaunch", env={"ISIM_LAUNCH_URL": "isim-health-authorization:read=HKQuantityTypeIdentifierStepCount",
                                          "ISIM_HEALTH_PERMISSION": "allow"})
    app.wait_log(r"^sl health authorization requested$")
    app.wait_log(r"^sl health handled true asked true$")


def test_onscreen_entities(launch):
    """App entities annotated on views show in the view dump (isim has no Apple Intelligence to read them)."""
    app = launch("HelloSceneLaunch")
    app.wait_log(r"^sl ready$")
    t = app.wait_view(r"id=notes")
    assert "id=note text=Connection 1 entity=NoteEntity:n1" in t, t
    assert "id=notes entity=NoteEntity:n2(selected),NoteEntity:n3" in t, t
