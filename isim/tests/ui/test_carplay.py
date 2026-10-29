"""CarPlay (issue #410) on the simulated CarPlay screen (`carplay connect`): HelloCarPlay, an audio app (a tab bar of a
list and a grid, the Now Playing template driving MPRemoteCommandCenter, an alert, an action sheet, an image row), and
HelloCarPlayMaps, a navigation app (its map in the car window under the map template: trip previews, a navigation
session's guidance, a navigation alert, the panning interface, search). Templates an app's category does not allow
raise, as on iOS; without a CarPlay entitlement CarPlay does not show the app. CARPLAY_SHOTS=DIR keeps the screenshots."""
import os

SHOTS = os.environ.get("CARPLAY_SHOTS")


def shot(app, tmp_path, name):
    app.send(f"carplay shot {SHOTS or tmp_path}/{name}.png")
    app.wait_log(rf"isim CarPlay: shot .*/{name}\.png \(800x480\)$")


def test_carplay_audio(launch, tmp_path):
    app = launch("HelloCarPlay")
    app.wait_log(r"cpa launched")
    app.send("carplay connect")
    app.wait_log(r"isim CarPlay: CarPlay screen connected \(800x480 @2x, audio\)")
    app.wait_log(r"isim CarPlay: root template CPTabBarTemplate")
    app.wait_log(r"cpa connected dark tabs=2")
    app.wait_log(r"cpa root true")
    app.send("carplay dump")
    app.wait_log(r"isim CarPlay: dump cp-item-Morning-Mix “Morning Mix / 12 songs”")
    app.wait_log(r"isim CarPlay: dump cp-tab-Featured “Featured”")      # the grid's tab: its system item
    app.wait_log(r"isim CarPlay: dump end")
    shot(app, tmp_path, "carplay-library")

    app.send("carplay tap cp-item-Morning-Mix")                          # a playlist: Now Playing
    app.wait_log(r"cpa selected Morning Mix")
    app.wait_log(r"isim CarPlay: push CPNowPlayingTemplate")
    app.wait_log(r"cpa now playing true")
    app.wait_log(r"cpa appeared CPNowPlayingTemplate")
    app.wait_log(r"isim MediaPlayer: now playing Sunrise — The isim Band")
    shot(app, tmp_path, "carplay-now-playing")
    app.send("carplay tap cp-np-pause")                                  # the transport buttons: the app's remote commands
    app.wait_log(r"cpa remote pause")
    app.send("carplay tap cp-np-play")
    app.wait_log(r"cpa remote play")
    app.send("carplay tap cp-np-next")
    app.wait_log(r"cpa remote next")
    app.wait_log(r"isim MediaPlayer: now playing Coffee Run")
    app.send("carplay tap cp-np-shuffle")
    app.wait_log(r"cpa shuffle true")
    app.send("carplay tap cp-np-upnext")
    app.wait_log(r"cpa up next")
    app.send("carplay back")
    app.wait_log(r"isim CarPlay: pop CPNowPlayingTemplate")
    app.wait_log(r"cpa appeared CPTabBarTemplate")

    app.send("carplay tap cp-image-Stations-1")                          # an image of the image row
    app.wait_log(r"cpa station 1")
    app.send("carplay tap cp-tab-Featured")                              # the grid
    app.send("carplay tap cp-grid-Jazz")
    app.wait_log(r"cpa genre Jazz")
    app.wait_log(r"isim CarPlay: push CPListTemplate “Jazz”")
    app.send("carplay dump")
    app.wait_log(r"isim CarPlay: dump cp-item-Jazz-Hits-1 “Jazz Hits 1 / Playlist”")
    app.send("carplay back")
    app.wait_log(r"isim CarPlay: pop CPListTemplate “Jazz”")
    app.send("carplay tap cp-tab-Library")

    app.send("carplay tap cp-bar-Sign-Out")                              # an alert
    app.wait_log(r"isim CarPlay: present CPAlertTemplate")
    app.wait_log(r"cpa alert true")
    shot(app, tmp_path, "carplay-alert")
    app.send("carplay tap cp-alert-Cancel")
    app.wait_log(r"cpa alert cancel")
    app.wait_log(r"isim CarPlay: dismiss CPAlertTemplate")
    app.send("carplay tap cp-bar-Sort")                                  # an action sheet
    app.wait_log(r"isim CarPlay: present CPActionSheetTemplate")
    app.send("carplay taptext Recently Played")
    app.wait_log(r"cpa sort Recently Played")

    app.send("carplay style light")
    app.wait_log(r"isim CarPlay: content style light")
    app.send("carplay disconnect")
    app.wait_log(r"cpa disconnected")
    app.wait_log(r"isim CarPlay: CarPlay screen disconnected")


def test_carplay_navigation(launch, tmp_path):
    app = launch("HelloCarPlayMaps")
    app.wait_log(r"cpm launched")
    app.send("carplay connect")
    app.wait_log(r"isim CarPlay: CarPlay screen connected \(800x480 @2x, navigation\)")
    app.wait_log(r"cpm connected window 720x480")                        # the car window: the screen less the status bar
    app.wait_log(r"isim CarPlay: root template CPMapTemplate")
    app.send("carplay tap cp-map-button-1")                              # zoom in: the app's map button
    app.wait_log(r"cpm zoom in")

    app.send("carplay tap cp-bar-Places")                                # a destination from a list: trip previews
    app.wait_log(r"isim CarPlay: push CPListTemplate “Places”")
    app.send("carplay tap cp-item-Apple-Park")
    app.wait_log(r"cpm preview Apple Park")
    app.wait_log(r"isim CarPlay: trip previews Apple Park")
    app.wait_log(r"cpm selected route Fastest route")
    shot(app, tmp_path, "carplay-trip-preview")
    app.send("carplay tap cp-route-1")
    app.wait_log(r"cpm selected route Scenic route")
    app.send("carplay tap cp-trip-start")                                # Go: the app starts a navigation session
    app.wait_log(r"isim CarPlay: start trip to Apple Park")
    app.wait_log(r"cpm started trip to Apple Park")
    app.wait_log(r"isim CarPlay: navigation session to Apple Park")
    app.wait_log(r"isim CarPlay: guidance Turn right onto Stevens Creek Blvd")
    app.wait_log(r"isim CarPlay: navigation alert Faster route available")
    shot(app, tmp_path, "carplay-navigation")
    app.send("carplay tap cp-nav-alert-1")                               # Ignore
    app.wait_log(r"cpm alert ignore")
    app.wait_log(r"cpm alert dismissed 1")                               # userDismissed
    app.send("carplay tap cp-guidance")
    app.wait_log(r"cpm selected maneuver Turn right onto Stevens Creek Blvd")

    app.send("carplay tap cp-map-button-0")                              # the panning interface
    app.wait_log(r"cpm panning shown")
    app.send("carplay pan up")
    app.wait_log(r"cpm pan 4")
    app.send("carplay tap cp-pan-left")
    app.wait_log(r"cpm pan 1")
    app.send("carplay tap cp-trip-end")                                  # End
    app.wait_log(r"isim CarPlay: trip cancelled")
    app.wait_log(r"cpm navigation cancelled")

    app.send("carplay tap cp-bar-trailing-0")                            # search
    app.wait_log(r"isim CarPlay: push CPSearchTemplate")
    app.send("carplay search coffee")
    app.wait_log(r"cpm search coffee: 1")
    app.send("carplay tap cp-item-Coffee-Corner")
    app.wait_log(r"cpm preview Coffee Corner")
    app.send("carplay disconnect")
    app.wait_log(r"cpm disconnected")


def test_carplay_other_app(launch):
    app = launch("HelloCounterSwift")                                    # no CarPlay scene, does not link CarPlay
    app.send("carplay connect")
    app.wait_log(r"isim: carplay: the app does not use CarPlay")
