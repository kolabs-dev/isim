"""UIDeviceFamily: iPhone-only apps use iPhone compatibility mode on iPad; iPad-only apps are rejected on iPhone."""
import os
import plistlib
import shutil
import subprocess

from isimtest import APPS, ISIM, rgb


def app_with_family(tmp_path, family):
    app = tmp_path / f"RotationFamily{family}.app"
    shutil.copytree(APPS / "HelloRotation.app", app)
    info_path = app / "Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info["UIDeviceFamily"] = [family]
    info["CFBundleIdentifier"] = f"dev.isim.tests.device-family-{family}"
    info_path.write_bytes(plistlib.dumps(info))
    return app, info["CFBundleIdentifier"]


def test_iphone_app_on_ipad_uses_compatibility_mode(launch, device_data, tmp_path):
    app, bundle_id = app_with_family(tmp_path, 1)
    installed = device_data / "Applications" / app.name
    installed.parent.mkdir(parents=True)
    shutil.copytree(app, installed)

    device = launch(None, device="ipadmini", animations=False)
    device.send(f"launch {bundle_id}")
    device.wait_log(r"isim: using iPhone compatibility mode on iPad \(375 x 667 points\)")
    dump = device.wait_view(lambda d: "id=info" in d and "screen 375x667" in d and "idiom phone" in d,
                            what="iPhone screen metrics and idiom")
    assert "screen 375x667" in dump and "idiom phone" in dump

    def compatibility_frame():
        shot = device.screenshot()
        return shot if rgb(shot, 20, 500) == (0, 0, 0) else None

    shot = device.wait_until(compatibility_frame, what="the launch animation to reveal the black compatibility canvas")
    assert shot.size == (744, 1133), "the shell keeps the physical iPad canvas"
    assert rgb(shot, 20, 500) == (0, 0, 0), "the compatibility app is centred on black"
    assert rgb(shot, 372, 500) != (0, 0, 0), "the scaled iPhone canvas fills the iPad's height"


def test_ipad_only_app_is_rejected_on_iphone(device_data, tmp_path):
    app, _ = app_with_family(tmp_path, 2)
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_DEVICE="iphone15")
    result = subprocess.run([str(ISIM), "install", str(app)], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    assert result.returncode != 0
    assert "UIDeviceFamily [2] does not support iPhone (iphone15)" in result.stdout
    assert not (device_data / "Applications" / app.name).exists()
