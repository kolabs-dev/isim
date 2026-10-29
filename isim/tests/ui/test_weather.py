"""WeatherKit (issue #415) with HelloWeather: isim's simulated forecast for a city (ten days with their sun and moon,
25 hours, the next hour's precipitation where WeatherKit has it), queries, Codable forecasts, the iOS 18 statistics,
summaries, changes and comparisons, the attribution with isim's mark; ISIM_WEATHER forcing the current weather and an
alert, or making the service unavailable. WEATHER_SHOTS=DIR keeps the screenshot."""
import os

import pytest

from isimtest import need_apps

APP = "HelloWeather"
SHOTS = os.environ.get("WEATHER_SHOTS")


@pytest.mark.os_matrix                       # the statistics are iOS 18
def test_weather(launch, ios):
    need_apps(APP)
    app = launch(APP, args=["-city", "london"], env={"ISIM_WEATHER": "condition=rain,temperature=12,alert=severe"})
    app.wait_log(r"weather: current rain Rain temperature=12\.0 symbol=cloud\.rain uv=\d+ \w+ wind=[NESW]{1,3} humidity=ok pressure=mbar")
    app.wait_log(r"weather: daily 10 ordered=1 highs>=lows=1")
    app.wait_log(r"weather: sun rises-and-sets dawn<rise=1 moon=\w+ moonphase\.[a-z.]+")
    app.wait_log(r"weather: hourly 25 ordered=1 first<=now=1")
    app.wait_log(r"weather: minute 60 summary=Rain for the hour\.")
    app.wait_log(r"weather: availability minute=available alert=available")
    app.wait_log(r"weather: alerts Severe Severe Thunderstorm Warning source=isim \(simulated\)")
    app.wait_log(r"weather: attribution isim Simulated Weather mark=1 legal=github\.com")
    app.wait_view("Rain")
    app.wait_view("12°")
    app.wait_view("Severe Thunderstorm Warning")
    if SHOTS:
        app.wait_shot_still().save(os.path.join(SHOTS, "weather-london.png"))
    app.wait_log(r"weather: query current=rain days=3")
    app.wait_log(r"weather: query hours=6")
    app.wait_log(r"weather: query minute=60 alerts=1 availability=available")
    app.wait_log(r"weather: codable equal")
    if int(ios[0] or os.environ.get("ISIM_OS_VERSION", "18")) >= 18:
        app.wait_log(r"weather: parts day=\w+ night=\w+ rest=1 clouds=1")
        app.wait_log(r"weather: statistics days=10 first=\d+ highs>=lows=1 rain=10 baseline=1991")
        app.wait_log(r"weather: statistics months=12 hours=24 p10<p90=1")
        app.wait_log(r"weather: summary days=30 past=1")
        app.wait_log(r"weather: changes 9 comparisons=high,low,precipitation,snow")
    else:
        app.wait_log(r"weather: statistics need iOS 18")
    assert app.quit() == 0


def test_weather_regions(launch):
    """WeatherKit's next-hour precipitation only in some regions: none in Tromsø (alerts yes, in Europe), both in
    Sydney"""
    need_apps(APP)
    north = launch(APP, args=["-city", "tromso"])
    north.wait_log(r"weather: minute none")
    north.wait_log(r"weather: availability minute=unsupported alert=available")
    north.wait_log(r"weather: alerts\s*$")
    assert north.quit() == 0
    south = launch(APP, args=["-city", "sydney"])
    south.wait_log(r"weather: minute 60 summary=")
    south.wait_log(r"weather: availability minute=available alert=available")
    south.wait_log(r"weather: sun rises-and-sets")
    assert south.quit() == 0


def test_weather_unavailable(launch):
    need_apps(APP)
    app = launch(APP, env={"ISIM_WEATHER": "unavailable"})
    app.wait_log(r"weather: error unknown An unknown error occurred")
    app.wait_view("An unknown error occurred")
    assert app.quit() == 0
