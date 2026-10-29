"""HealthKit workouts (issue #418) with HelloWorkout: a run recorded afterwards with HKWorkoutBuilder (samples, a pause,
a lap, two activities, metadata and a route), saved to the device's Health database and read back with the workout
predicates, the samples that belong to it and HKWorkoutRouteQueryDescriptor. From iOS 26 the app also runs a live
workout session on iPhone: HKWorkoutSession and its HKLiveWorkoutBuilder, collecting isim's simulated heart rate,
energy and distance; paused and resumed, then ended and saved. WORKOUT_SHOTS=DIR keeps a screenshot."""
import os

import pytest

from isimtest import need_apps

APP = "HelloWorkout"
ENV = {"ISIM_HEALTH_PERMISSION": "allow"}


@pytest.mark.os_matrix                       # the live workout session on iPhone is iOS 26
def test_workout(launch, ios):
    need_apps(APP)
    app = launch(APP, args=["-check"], env=ENV)
    app.wait_log(r"workout: authorized true workouts=2")
    app.wait_log(r"workout: elapsed at end 1200 s")                      # 22 minutes less the 2-minute pause
    app.wait_log(r"workout: saved running duration=1200 energy=200 distance=3000 hr=140 events=3 activities=2")
    app.wait_log(r"workout: activities walking 300 s, running 900 s distance=2550")
    app.wait_log(r"workout: found 1 runs; same=true brand=HelloWorkout")
    app.wait_log(r"workout: long, 200 kcal and a walk: 1")
    app.wait_log(r"workout: heart rate samples of the workout 20")
    app.wait_log(r"workout: route 6 points count=6 first=37\.3349 last=37\.3399")
    app.wait_view("Run · 20 min · 3.00 km")
    if int(float(ios[0] or 18)) < 26:
        app.wait_log(r"workout: no live workout session on iPhone before iOS 26")
        assert app.quit() == 0
        return
    app.wait_log(r"workout: collects ActiveEnergyBurned,DistanceWalkingRunning,HeartRate")
    app.wait_log(r"workout: session not started -> running")
    app.wait_log(r"workout: collection began true")
    app.wait_log(r"workout: collected HeartRate")
    app.wait_log(r"workout: collected ActiveEnergyBurned")
    app.wait_log(r"workout: collected DistanceWalkingRunning")
    app.wait_log(r"workout: event pause")
    app.wait_log(r"workout: session running -> paused")
    app.wait_log(r"workout: builder events 1")
    app.wait_log(r"workout: session paused -> running")
    app.wait_log(r"workout: event resume")
    app.wait_log(r"workout: session running -> ended")
    app.wait_log(r"workout: live saved duration=[67] hr=\d{2,3} energy=\d+\.\d distance=\d+ events=pause,resume samples=yes")
    app.wait_view(r"Live run · [67] s · \d+ m")
    assert app.quit() == 0
    shots = os.environ.get("WORKOUT_SHOTS")
    if shots:                                # a live workout ten seconds in (-live runs until it is ended)
        app = launch(APP, args=["-live"], env=ENV)
        app.wait_view(r"id=elapsed text=0:1\d")
        app.wait_shot_still().save(os.path.join(shots, f"workout-live-ios{int(float(ios[0] or 18))}.png"))
        app.tap_id("end")
        app.wait_log(r"workout: live saved duration=")
        assert app.quit() == 0


def test_workout_denied(launch):
    """without permission to write workouts the builder cannot begin"""
    need_apps(APP)
    app = launch(APP, args=["-check"], env={"ISIM_HEALTH_PERMISSION": "deny"})
    app.wait_log(r"workout: authorized true workouts=1")
    app.wait_log(r"workout: record error .*Authorization to share workouts is denied")
    assert app.quit() == 0
