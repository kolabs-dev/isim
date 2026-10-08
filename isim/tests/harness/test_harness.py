"""The isimtest driver itself: an app that dies before it opens its control channel fails the test with its exit status
and output, instead of hanging (opening the control FIFO for writing used to block until a reader appeared)."""
import time

import pytest
from isimtest import App, WaitTimeout


def test_dead_app_does_not_hang(tmp_path):
    app = tmp_path / "Broken.app"
    app.mkdir()
    (app / "Info.plist").write_text('<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict>'
                                    "<key>CFBundleExecutable</key><string>Broken</string>"
                                    "<key>CFBundleIdentifier</key><string>dev.isim.tests.Broken</string></dict></plist>\n")
    exe = app / "Broken"
    exe.write_text("not a Mach-O executable\n")
    exe.chmod(0o755)
    start = time.monotonic()
    with pytest.raises(WaitTimeout, match=r"the app exited with status \S+ before opening its control channel"):
        App(app, data=tmp_path / "data")
    assert time.monotonic() - start < 30, "fails as soon as the app exits"
