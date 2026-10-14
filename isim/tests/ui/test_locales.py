"""Locale's preferences and Locale.Components, TimeZone's daylight saving time and zone list, Calendar's weekends,
ordinality and date enumeration (HelloLocales, issue #218). The locale data comes from the host's ICU (CLDR)."""
import re


def report(app):
    app.wait_log(r"^hl reported$")
    return {m[0]: m[1] for m in re.findall(r"^hl (\S+) (.*)$", app.log, re.M)}


def test_locales(launch):
    app = launch("HelloLocales")
    r = report(app)
    assert r["locale[en_US]"] == "region=US currency=USD measure=ussystem hours=h12 fw=sun collation=standard numbers=latn", r["locale[en_US]"]
    assert r["locale[en_GB]"] == "region=GB currency=GBP measure=uksystem hours=h23 fw=mon collation=standard numbers=latn", r["locale[en_GB]"]
    assert r["locale[de_DE]"] == "region=DE currency=EUR measure=metric hours=h23 fw=mon collation=standard numbers=latn", r["locale[de_DE]"]
    assert r["locale[ar_EG]"] == "region=EG currency=EGP measure=metric hours=h12 fw=sat collation=standard numbers=arab", r["locale[ar_EG]"]
    assert r["locale[en_US@hours=h23;fw=mon;measure=metric;currency=eur]"] == \
        "region=US currency=EUR measure=metric hours=h23 fw=mon collation=standard numbers=latn", "ICU keywords override the region"
    assert r["locale[en-US-u-hc-h23-fw-mon]"] == \
        "region=US currency=USD measure=ussystem hours=h23 fw=mon collation=standard numbers=latn", "BCP 47 -u- keywords"
    assert r["components-locale"] == "en_US@calendar=buddhist;fw=mon;hours=h23 hours=h23 calendar=buddhist fw=mon", r["components-locale"]
    assert r["components-parse"] == "lang=sr script=Latn region=RS collation=search currency=EUR", r["components-parse"]
    assert r["available"] == "many=true en_US=true", r["available"]
    assert r["iso"] == "US=true XX=false EUR=true regions=true currencies=true", r["iso"]
    assert r["collations"] == "standard=true", r["collations"]

    assert r["zones"] == "many=true newyork=true tokyo=true", r["zones"]
    assert r["dst"] == "july=true january=false offset=3600 winter-offset=0", r["dst"]
    assert r["dst-next"] == "2024-03-10T07:00:00Z 2024-11-03T06:00:00Z", f"New York springs forward, then falls back: {r['dst-next']}"
    assert r["dst-none"] == "nil", r["dst-none"]

    assert r["weekend-us"] == "sat=true sun=true fri=false", r["weekend-us"]
    assert r["weekend-sa"] == "fri=true sat=true sun=false", f"Saudi Arabia's weekend is Friday and Saturday: {r['weekend-sa']}"
    assert r["weekend-interval"] == "2024-07-06T00:00:00Z 2024-07-08T00:00:00Z", r["weekend-interval"]
    assert r["weekend-next"] == "2024-07-06T00:00:00Z 2024-07-13T00:00:00Z", r["weekend-next"]
    assert r["ordinality"] == "dayOfYear=61 dayOfMonth=13 hour=14 minute=31 weekday=2 monthOfQuarter=2 quarter=2 bad=nil", r["ordinality"]
    assert r["enumerate-daily"] == "2024-01-01T09:30:00Z 2024-01-02T09:30:00Z 2024-01-03T09:30:00Z", r["enumerate-daily"]
    assert r["enumerate-hourly"] == "2024-01-01T00:15:00Z 2024-01-01T01:15:00Z 2024-01-01T02:15:00Z", r["enumerate-hourly"]
    assert r["enumerate-weekly"] == "2024-01-01T08:00:00Z 2024-01-08T08:00:00Z 2024-01-15T08:00:00Z", r["enumerate-weekly"]
    assert app.quit() == 0
