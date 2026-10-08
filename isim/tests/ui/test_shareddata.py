"""HelloSharedData: plural localization (String Catalog plurals + substitutions compiled to .stringsdict, a
hand-written .stringsdict with a zero rule, English and Russian CLDR categories), LocalizedStringResource, app group
container + shared defaults across launches, the local iCloud key-value store (persistence and an external change
while the app runs), ubiquity containers with and without an account, NotificationQueue.
Port of tests/ui/shareddata.sh."""
import plistlib

import pytest
from PIL import ImageStat


@pytest.fixture(scope="module")
def runs(launch_module, tmp_path_factory):
    data = tmp_path_factory.mktemp("shareddata")
    kvs = data / "Mobile Documents" / "KeyValueStore" / "dev.isim.samples.HelloSharedData.plist"
    # 1: English, first launch; another "device" changes the key-value store while the app runs
    app = launch_module("HelloSharedData", data=data, device="iphone17", env={"ISIM_LANGUAGES": "en"})
    app.wait_log(r"kvs launches 1 ")
    app.wait_log(r"notification queue ")
    kvs.parent.mkdir(parents=True, exist_ok=True)
    with open(kvs, "wb") as f:
        plistlib.dump({"launches": 1, "color": "teal"}, f)
    app.wait_log(r"kvs external change")
    dump1 = app.wait_view(r"text=color teal")
    en = app.screenshot("en")
    rc1 = app.quit()
    log1 = app.log + "\n" + dump1
    # 2: Russian, second launch
    app = launch_module("HelloSharedData", data=data, device="iphone17", env={"ISIM_LANGUAGES": "ru"})
    app.wait_log(r"notification queue ")
    dump2 = app.view_dump()
    rc2 = app.quit()
    log2 = app.log + "\n" + dump2
    # 3: signed out of iCloud
    app = launch_module("HelloSharedData", data=data, device="iphone17", env={"ISIM_ICLOUD": "noAccount"})
    app.wait_log(r"ubiquity ")
    log3 = app.log
    rc3 = app.quit()
    return dict(log1=log1, log2=log2, log3=log3, rcs=(rc1, rc2, rc3), en=en, data=data)


def test_plurals(runs):
    log1, log2 = runs["log1"], runs["log2"]
    assert all(s in log1 for s in ("plural files-0: 0 files", "plural files-1: 1 file", "plural files-2: 2 files",
                                   "plural files-21: 21 files")), "String Catalog plurals (en): 0/1/2/5/21 files"
    assert "plural photos: 1 photo in 3 albums" in log1, "String Catalog substitutions (two plural variables)"
    assert all(s in log1 for s in ("plural songs-0: No songs in the playlist", "plural songs-1: One song in the playlist",
                                   "plural songs-11: 11 songs in the playlist")), \
        ".stringsdict with a zero rule via localizedStringWithFormat"
    assert "plural welcome: Welcome" in log1, "LocalizedStringResource (source language)"
    assert "id=files-1" in log1 and "text=1 file" in log1, "plurals shown in the UI"
    assert all(s in log2 for s in ("plural files-1: 1 файл", "plural files-2: 2 файла", "plural files-5: 5 файлов",
                                   "plural files-21: 21 файл")), "Russian CLDR categories (one/few/many) from the catalog"
    assert all(s in log2 for s in ("plural songs-1: 1 песня в плейлисте", "plural songs-3: 3 песни в плейлисте",
                                   "plural songs-11: 11 песен в плейлисте")), "Russian .stringsdict (one/few/many)"
    assert "plural welcome: Добро пожаловать" in log2, "LocalizedStringResource (Russian)"


def test_containers(runs):
    log1, log2, log3 = runs["log1"], runs["log2"], runs["log3"]
    assert "previous=nothing" in log1 and "previous=written by HelloSharedData" in log2, \
        "app group container: empty on first launch, file kept for the next"
    assert (runs["data"] / "Shared/AppGroup/group.dev.isim.samples.shared/shared.txt").is_file(), \
        "app group container lives in the device data"
    assert "group defaults opens 1" in log1 and "group defaults opens 2" in log2, \
        "UserDefaults(suiteName:) of the group persists"
    assert "kvs launches 1 color -" in log1 and "kvs launches 2 color teal" in log2, \
        "iCloud key-value store persists across launches"
    assert 'kvs external change keys=["color"] reason=0 color=teal' in log1 and "text=color teal" in log1, \
        "external change -> didChangeExternallyNotification (server change)"
    assert "ubiquity iCloud iCloud.dev.isim.samples.HelloSharedData token true" in log1, \
        "ubiquity container with the simulated account"
    assert "ubiquity no iCloud account token false" in log3, "ISIM_ICLOUD=noAccount: no container, no token"
    assert "notification queue pings 2 (before run loop 0)" in log1, \
        "NotificationQueue: ASAP posts coalesce, whenIdle without coalescing posts too"


def test_rendered(runs):
    sd = ImageStat.Stat(runs["en"]).stddev
    assert sum(sd) / len(sd) / 255 > 0.02, "screenshot rendered"
    assert runs["rcs"] == (0, 0, 0), "exits cleanly"
