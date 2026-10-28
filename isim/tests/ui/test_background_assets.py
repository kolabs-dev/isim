"""BackgroundAssets (issue #407, under `isim boot`): HelloBackgroundAssets' downloader extension runs at install (its BAManifestURL
is not served: the manifest fails) and on `isim bgassets run ... install --manifest`: the essential download within
the allowance and the other one arrive in the app group, the one over the allowance fails; the app downloads in the
foreground and schedules a download (BADownloadManager and its delegate), a duplicate and an essential download are
refused, and exclusive control works. HelloAssetPacks (iOS 27): the managed extension downloads the essential hosted
packs it wants at install; the app reads a pack's file, downloads an on-demand pack with status updates, sees a new
version and a removed pack in checkForUpdates and removes a pack."""
import os
import subprocess

from isimtest import ISIM, ROOT, local_server

APP = "dev.isim.samples.HelloBackgroundAssets"
PACKS = "dev.isim.samples.HelloAssetPacks"


def isim(data, *args):
    r = subprocess.run([str(ISIM), *args], env=dict(os.environ, ISIM_DATA=str(data)), stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=60)
    assert r.returncode == 0, r.stdout
    return r.stdout


def test_background_assets(launch, device_data, tmp_path):
    with local_server(ROOT / "samples/HelloBackgroundAssets/server.py", tmp_path / "server.log") as port:
        dev = launch(None, install=["HelloBackgroundAssets"])
        dev.wait_log(rf"SpringBoard: background assets: install for {APP}")
        dev.wait_log(rf"SpringBoard: background assets for {APP}: the manifest could not be downloaded")   # nothing on :8460
        isim(device_data, "bgassets", "run", APP, "install", "--manifest", f"http://127.0.0.1:{port}/manifest.json")
        dev.wait_log(r"bax downloads for install essential budget=100000 budget=200000")
        dev.wait_log(r"bax finished intro essential=true")
        dev.wait_log(r"bax finished level2 essential=false")
        dev.wait_log(r"bax failed huge BAErrorDomain/112")                 # downloadWouldExceedAllowance
        dev.wait_log(rf"SpringBoard: background assets for {APP}: 2 finished, 1 failed")

        dev.quit()                                                        # the app, with the server's address
        dev = launch("HelloBackgroundAssets", data=device_data, args=["-server", f"http://127.0.0.1:{port}"])
        dev.wait_log(r"^ba launched$")
        dev.wait_tap_id("files")
        dev.wait_log(r"^ba files intro\.bin,level2\.bin$")
        dev.tap_id("foreground")
        dev.wait_log(r"^ba began bonus$")
        dev.wait_log(r"^ba wrote bonus 2048$")
        dev.wait_log(r"^ba finished bonus moved=true size=2048$")
        dev.tap_id("schedule")
        dev.wait_log(r"^ba current extra$")
        dev.wait_log(r"^ba again refused BAErrorDomain/100$")              # downloadAlreadyScheduled
        dev.wait_log(r"^ba finished extra moved=true size=1024$")
        dev.tap_id("essential")
        dev.wait_log(r"^ba essential refused BAErrorDomain/109$")          # downloadEssentialDownloadNotPermitted
        dev.tap_id("exclusive")
        dev.wait_log(r"^ba exclusive 42$")
        dev.tap_id("files")
        dev.wait_log(r"^ba files bonus\.bin,extra\.bin,intro\.bin,level2\.bin$")

        dev.quit()
        dev = launch(None, data=device_data)                              # a periodic run: nothing is essential now
        isim(device_data, "bgassets", "run", APP, "periodic", "--manifest", f"http://127.0.0.1:{port}/manifest.json")
        dev.wait_log(r"bax downloads for periodic")
        dev.wait_log(r"bax finished intro essential=false")
        dev.wait_log(rf"SpringBoard: background assets for {APP}: 3 finished, 0 failed")


def test_asset_packs(launch, device_data, tmp_path):
    for pid, files in (("levels", {"levels/1.json": '{"level":1}'}), ("skipped", {"s.txt": "no"}), ("extras", {"extras/bonus.txt": "bonus!"})):
        d = tmp_path / pid
        for name, text in files.items():
            (d / name).parent.mkdir(parents=True, exist_ok=True)
            (d / name).write_text(text)
    isim(device_data, "bgassets", "pack", "add", PACKS, "levels", str(tmp_path / "levels"), "--policy", "essential")
    isim(device_data, "bgassets", "pack", "add", PACKS, "skipped", str(tmp_path / "skipped"), "--policy", "essential")
    assert "extras v1" in isim(device_data, "bgassets", "pack", "add", PACKS, "extras", str(tmp_path / "extras"))
    dev = launch(None, install=["HelloAssetPacks"], os_version="27")
    dev.wait_log(rf"SpringBoard: background assets: install for {PACKS}")
    dev.wait_log(r"baxp should download levels v1: yes")
    dev.wait_log(r"baxp should download skipped v1: no")
    dev.wait_log(rf"SpringBoard: background assets for {PACKS}: 1 finished, 0 failed")
    assert isim(device_data, "bgassets", "local", PACKS).split() == ["levels", "v1"]

    dev.send(f"launch {PACKS}")
    dev.wait_log(r"^bap launched levels=true skipped=false extras=false$")
    dev.wait_tap_id("status")
    dev.wait_log(r"^bap status levels=downloaded\+upToDate skipped=available extras=available$")
    dev.tap_id("read")
    dev.wait_log(r'^bap read \{"level":1\}$')
    dev.wait_log(r"^bap missing missing\.txt$")
    dev.tap_id("ensure")                                                  # an on-demand pack, with status updates
    dev.wait_log(r"^bap extras began v1$")
    dev.wait_log(r"^bap extras downloading 100%$")
    dev.wait_log(r"^bap extras finished v1$")
    dev.wait_log(r"^bap extras local bonus=bonus!$")

    (tmp_path / "levels" / "levels/2.json").write_text('{"level":2}')
    isim(device_data, "bgassets", "pack", "add", PACKS, "levels", str(tmp_path / "levels"), "--version", "2", "--policy", "essential")
    isim(device_data, "bgassets", "pack", "remove", PACKS, "skipped")
    dev.tap_id("status")
    dev.wait_log(r"^bap status levels=downloaded\+outOfDate\+updateAvailable skipped= extras=downloaded\+upToDate$")
    dev.tap_id("updates")
    dev.wait_log(r"^bap updates updating=levels removed=$")
    dev.wait_log(r"isim BackgroundAssets: asset pack levels v2 is local")
    dev.tap_id("remove")
    dev.wait_log(r"^bap removed extras local=false$")
    isim(device_data, "bgassets", "pack", "remove", PACKS, "extras")
    assert isim(device_data, "bgassets", "local", PACKS).split() == ["levels", "v2"]
