"""HomeKit (issue #416) with HelloHome over the device's simulated home (`isim home seed`): the home, rooms, zones and
accessories; reads, writes and HomeKit's errors; notifications from the simulated lock and garage door; rooms, zones,
service groups, scenes and automations; finding accessories nearby and adding them with a setup code; the doorbell
camera's stream and snapshot. Then the accessories change from outside (`isim home set|reachable`): the delegate hears
it and an automation runs its scene. HOMEKIT_SHOTS=DIR keeps the screenshot."""
import os
import re
import subprocess

import pytest
from isimtest import ISIM, need_apps

APP = "HelloHome"
SHOTS = os.environ.get("HOMEKIT_SHOTS")


def home(device_data, *args):
    return subprocess.run([str(ISIM), "home", *args], env=dict(os.environ, ISIM_DATA=str(device_data)),
                          capture_output=True, text=True, check=True, timeout=60).stdout


def test_homekit(launch, device_data):
    need_apps(APP)
    assert "seeded My Home" in home(device_data, "seed")
    app = launch(APP, args=["-check"], env={"ISIM_HOMEKIT_PERMISSION": "allow"})
    app.wait_log(r"home: authorization authorized")
    app.wait_log(r"home: homes 1 status=5")
    app.wait_log(r"home: home My Home primary=true hub=connected rooms=Bedroom,Entrance,Garage,Kitchen,Living Room zones=Downstairs:2")
    app.wait_log(r"home: accessories 8 user=Anna Haro admin=true")
    app.wait_log(r"home: lamp room=Living Room category=Lightbulb service=Lightbulb primary=true "
                 r"characteristics=Power State,Brightness,Hue,Saturation,Color Temperature")
    app.wait_log(r"home: brightness 80 format=int units=percentage range=0\.\.\.100 writable=true")
    app.wait_log(r"home: wrote brightness 55")
    app.wait_log(r"home: too bright valueHigherThanMaximum")
    app.wait_log(r"home: wrong type invalidValueType")
    app.wait_log(r"home: read-only readOnlyCharacteristic")
    # the simulated accessories: the lock's current state follows its target, the garage door opens through `opening`
    app.wait_log(r"home: updated Front Door Current Lock Mechanism State = 0")
    app.wait_log(r"home: opening garage door current=2")
    app.wait_log(r"home: updated Garage Door Current Door State = 0")
    app.wait_log(r"home: room Study accessories=Kitchen Outlet")
    app.wait_log(r"home: same room objectWithSimilarNameExistsInHome")
    app.wait_log(r"home: zone Downstairs rooms=Kitchen,Living Room,Study")
    app.wait_log(r"home: group Lights services=1")
    app.wait_log(r"home: rooms again 5")
    app.wait_log(r"home: same characteristic actionInAnotherActionSet")
    app.wait_log(r"home: scene Movie Night actions=2 type=user lamp=1 brightness=20 ran=true")
    app.wait_log(r"home: builtin Good Night")
    app.wait_log(r"home: automation Hallway Motion enabled=true state=enabled events=1")
    app.wait_log(r"home: timer Morning recurrence=1 enabled=false")
    app.wait_log(r"home: empty timer noActionsInActionSet")
    app.wait_log(r"home: triggers Hallway Motion$")
    app.wait_log(r"home: found Ceiling Fan home=none")
    app.wait_log(r"home: nearby Ceiling Fan,Window Sensor")
    app.wait_log(r"home: added Ceiling Fan home=true services=2")
    app.wait_log(r"home: setup 1 Study Window home=true")
    app.wait_log(r"home: bad payload nil")
    app.wait_log(r"home: camera streaming state=streaming aspect=1\.78")
    app.wait_log(r"home: camera snapshot 1 error=nil recent=1")
    app.wait_log(r"home: check done")

    # the home changes from outside: motion in the hallway runs the automation's scene
    home(device_data, "set", "Hallway Sensor", "MotionDetected", "1")
    app.wait_log(r"home: updated Hallway Sensor Motion Detected = 1")
    app.wait_log(r"isim HomeKit: trigger Hallway Motion fired")
    app.wait_log(r"home: updated Living Room Lamp Power State = 1")
    home(device_data, "reachable", "Bedroom Blinds", "off")
    app.wait_log(r"home: reachability Bedroom Blinds false")
    app.wait_view("No Response")
    app.wait_view("Living Room Lamp")
    app.tap_id("power-Kitchen Outlet")
    app.wait_log(r"home: toggled Kitchen Outlet 1 error=nil")
    app.wait_log(r"home: updated Kitchen Outlet Outlet In Use = 1")         # the outlet's simulated load follows its power
    if SHOTS:
        app.wait_shot_still().save(os.path.join(SHOTS, "home.png"))
    listed = home(device_data, "list")
    assert "Kitchen Outlet [Kitchen]: PowerState=True OutletInUse=True" in listed, listed
    assert "Movie Night: 2 actions" in listed and "automation Hallway Motion (event, enabled)" in listed, listed
    assert app.quit() == 0


def inline_title(app):
    """The navigation bar's inline title line in the view dump (the large title is a label in the list)."""
    dump = app.view_dump()
    bar = dump[dump.index("_SUINavBar"):]
    return re.search(r"^.*UILabel .* text=My Home$", bar, re.M).group(0)


@pytest.mark.os_matrix
def test_homekit_list_title(launch, device_data):
    """The list is rebuilt (`.id(model.tick)`) when the home changes. Scrolled down, the bar shows the inline title;
    the rebuilt list starts at its top, where only the large title shows (#776: the bar kept the inline one)."""
    need_apps(APP)
    home(device_data, "seed")
    app = launch(APP, env={"ISIM_HOMEKIT_PERMISSION": "allow"})
    app.wait_view("Living Room Lamp")
    assert "alpha<1" in inline_title(app), "at the top: no inline title"
    app.drag(200, 700, 200, 300, 0.4)
    app.wait_until(lambda: "alpha<1" not in inline_title(app), what="the inline title once the large one scrolled away")
    home(device_data, "reachable", "Bedroom Blinds", "off")
    app.wait_log(r"home: reachability Bedroom Blinds false")
    app.wait_view("No Response")
    app.wait_until(lambda: "alpha<1" in inline_title(app), what="the rebuilt list at its top: no inline title")
    assert re.search(r"_SUIListScroll .* text=offset 0,", app.view_dump()), "the rebuilt list is at its top"
    assert app.quit() == 0


def test_homekit_denied(launch, device_data):
    """without the person's permission: no homes, and every change fails"""
    need_apps(APP)
    home(device_data, "seed")
    app = launch(APP, env={"ISIM_HOMEKIT_PERMISSION": "deny"})
    app.wait_log(r"home: authorization denied")
    app.wait_log(r"home: homes 0 status=1")
    app.wait_log(r"home: add home error=homeAccessNotAuthorized")
    assert app.quit() == 0
