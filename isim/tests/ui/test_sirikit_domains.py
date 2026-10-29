"""SiriKit's payments, rides, workouts and photos domains (issue #411) under `isim boot`, with HelloSiri ("Coffee Club")
and its Intents extension (Intents/Domains.swift):
- payments: INSendPaymentIntent (a payee disambiguated, Siri reads the payment back with the app's fee, then sends it),
  INRequestPaymentIntent, amounts the app refuses (above its maximum, another currency);
- rides: INRequestRideIntent from "get me a ride to Apple Park" (the pickup at the device's location, the destination
  from CoreLocation's gazetteer, INListRideOptionsIntent's options offered as a choice, the ride confirmed and booked),
  INGetRideStatusIntent with the app's live updates (INGetRideStatusIntentResponseObserver), INSendRideFeedbackIntent and
  INCancelRideIntent on the ride Siri booked, a place the app cannot find;
- workouts: INStartWorkoutIntent and the pause / resume / end intents handled in the app (.handleInApp), an ongoing
  workout and no workout;
- photos: INSearchForPhotosIntent and INStartPhotoPlaybackIntent continued in the app (NSUserActivity with its
  INInteraction), by place, person (disambiguated), album and year, an album the app does not have.
SIRIKIT_SHOTS=DIR keeps the screenshots."""
import os

import pytest

APP = "dev.isim.samples.HelloSiri"
SHOTS = os.environ.get("SIRIKIT_SHOTS")


def card(dev, text):
    dev.wait_dump(rf"id=siri-card text={text}")


def shot(dev, name):
    if SHOTS:
        dev.screenshot(name).save(os.path.join(SHOTS, f"{name}.png"))


def allow_siri(dev):
    dev.send(f"launch {APP}")
    dev.wait_tap_id("allowSiri")
    dev.wait_view(r"text=“Coffee Club” Would Like to Use Siri")
    dev.send("taptext Allow")
    dev.wait_log(r"HelloSiri: Siri authorization 3")
    dev.send("home")


@pytest.mark.os_matrix
def test_sirikit_payments(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    allow_siri(dev)
    dev.send("siri pay Anna $20 for coffee")                             # two Annas
    dev.wait_dump(r"id=siri-option-0 text=Anna Haro")
    dev.tap_id("siri-option-0")
    card(dev, r"Send \$20\.00 to Anna Haro\?")                           # read back with the app's fee
    dev.wait_dump(r"id=siri-detail text=To: Anna Haro.*For: coffee.*Fee: \$0\.25")
    dev.wait_dump(r"id=siri-confirm text=Send")
    shot(dev, "sirikit-payment")
    dev.tap_id("siri-confirm")
    card(dev, r"OK, I sent \$20\.00 to Anna Haro\.")
    dev.send("siri request $15 from Ben for lunch")
    card(dev, r"Request \$15\.00 from Ben Ito\?")
    dev.send("siri yes")
    card(dev, r"OK, I requested \$15\.00 from Ben Ito\.")
    dev.send("siri send Ben 600 dollars")                                # above the app's maximum
    card(dev, r"Sorry, Coffee Club can’t do that with “\$600\.00”\.")
    dev.send("siri send 5 euros to Ben")                                 # a currency it does not take
    card(dev, r"Sorry, Coffee Club can’t do that with “€5\.00”\.")
    dev.send("siri dismiss")
    dev.send(f"launch {APP}")
    dev.wait_view(r"id=paid text=Paid: requested \$15 from Ben Ito")
    assert dev.quit() == 0
    log = dev.log
    assert "HelloSiri: extension: paid Anna Haro $20 for coffee" in log and "HelloSiri: extension: requested $15 from Ben Ito" in log
    assert "isim Intents: INSendPaymentIntent response code 3 (success)" in log


@pytest.mark.os_matrix
def test_sirikit_rides(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    allow_siri(dev)
    dev.send("siri get me a ride to Apple Park")
    card(dev, r"Which ride\?")                                           # INListRideOptionsIntent's options
    dev.wait_dump(r"id=siri-option-0 text=Club Car")
    dev.wait_dump(r"id=siri-option-1 text=Club XL")
    shot(dev, "sirikit-ride-options")
    dev.tap_id("siri-option-1")
    card(dev, r"Request a Club XL ride to Apple Park\?")
    dev.wait_dump(r"id=siri-detail text=Club XL · \$18\.00–\$22\.00 · 7 min.*From: Current Location.*To: Apple Park.*Pay with: Club Card")
    dev.tap_id("siri-confirm")
    card(dev, r"Your ride is confirmed\. It’ll be there in 7 min\.")
    dev.wait_dump(r"id=siri-detail text=Club XL.*Sam Rivera · 4\.9 ★.*Toyota Prius · 7CLB123")
    shot(dev, "sirikit-ride-booked")

    dev.send("siri where's my ride")                                     # the app's live updates
    card(dev, r"Your ride is confirmed\.")
    card(dev, r"Your driver is almost there\.")
    card(dev, r"Your driver has arrived\.")
    dev.wait_log(r"HelloSiri: extension: stopped ride updates", timeout=30)    # after Siri's 8 seconds
    dev.send("siri rate my ride 5 stars")                                # the ride Siri booked
    card(dev, r"Thanks for your feedback\.")
    dev.send("siri cancel my ride")
    card(dev, r"OK, I cancelled your ride\.")
    dev.send("siri where's my ride")
    card(dev, r"Sorry, there was a problem with Coffee Club\.")
    dev.send("siri get me a Club Car ride to Nowhere Land")              # a place it cannot find
    card(dev, r"Sorry, Coffee Club can’t do that with “Nowhere Land”\.")
    dev.send("siri dismiss")
    assert dev.quit() == 0
    log = dev.log
    assert "isim Intents: pickup at the current location" in log and "isim Intents: listing ride options" in log
    assert "HelloSiri: extension: 2 ride options to Apple Park from Current Location" in log
    assert "HelloSiri: extension: booked Club XL to Apple Park from Current Location for - with Club Card" in log
    assert "SpringBoard: Siri updates the ride: “Your driver has arrived.”" in log
    assert "HelloSiri: extension: feedback for ride-" in log and "rating 5" in log
    assert "HelloSiri: extension: cancelled ride-" in log


def test_sirikit_workouts(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    allow_siri(dev)
    dev.send("siri start a 5 mile outdoor run")                          # handled in the app
    card(dev, r"OK, starting an outdoor run with a goal of 5 miles\.")
    dev.wait_log(r"HelloSiri: workout run started \(goal 5\.0, outdoor\)")
    dev.send("siri pause my workout")
    card(dev, r"OK, I paused your workout\.")
    dev.wait_log(r"HelloSiri: workout paused")
    dev.send("siri resume my workout")
    card(dev, r"OK, I resumed your workout\.")
    dev.send("siri start an indoor walk")                                # one at a time
    card(dev, r"You already have a workout in progress in Coffee Club\.")
    dev.send("siri end my workout")
    card(dev, r"OK, I ended your workout\.")
    dev.wait_log(r"HelloSiri: workout run ended")
    dev.send("siri pause my workout")
    card(dev, r"Sorry, you don’t have a workout in progress in Coffee Club\.")
    dev.send("siri dismiss")
    dev.send(f"launch {APP}")
    dev.wait_view(r"id=workout text=Workout: -")
    assert dev.quit() == 0
    assert "SpringBoard: Siri asks Coffee Club to handle INStartWorkoutIntent in the app" in dev.log


def test_sirikit_photos(launch):
    dev = launch(None, install=["HelloSiri"])
    dev.wait_log(r"SpringBoard: Coffee Club: 4 App Shortcut")
    allow_siri(dev)
    dev.send("siri show photos from Apple Park")                         # continued in the app
    dev.wait_log(r"SpringBoard: Siri says “I found 2 photos from Apple Park in Coffee Club\.”")
    dev.wait_view(r"id=last text=Photos: Apple Park \(2\)")
    shot(dev, "sirikit-photos")
    dev.send("home")
    dev.send("siri find photos of Anna")                                 # two Annas
    dev.wait_dump(r"id=siri-option-1 text=Anna Lee")
    dev.tap_id("siri-option-1")
    dev.wait_log(r"SpringBoard: Siri says “I found 1 photo of Anna Lee in Coffee Club\.”")
    dev.wait_view(r"id=last text=Photos: Anna Lee \(1\)")
    dev.send("home")
    dev.send("siri play a slideshow of my Latte Art album")
    dev.wait_log(r"SpringBoard: Siri says “OK, here’s a slideshow of your Latte Art album in Coffee Club\.”")
    dev.wait_view(r"id=last text=Slideshow: Latte Art \(2\)")
    dev.send("home")
    dev.send("siri intent SearchForPhotos year=2023")                    # the structured form
    dev.wait_log(r"SpringBoard: Siri says “I found 1 photo from 2023 in Coffee Club\.”")
    dev.send("home")
    dev.send("siri show my Holiday album")                               # an album it does not have
    card(dev, r"Sorry, Coffee Club can’t do that with “Holiday”\.")
    dev.send("siri dismiss")
    assert dev.quit() == 0
    log = dev.log
    assert "HelloSiri: extension: 2 photo(s) album - place Apple Park" in log
    assert "HelloSiri: continued INStartPhotoPlaybackIntent: Slideshow: Latte Art (2)" in log
