"""Darwin notifications (NotifyTest.app, issue #263): notify(3) and CFNotificationCenter's Darwin center reach other
processes of the device (two copies of the app on one ISIM_DATA: one listens, one posts and waits for its answer);
the local center's name and object filters; notify(3)'s extras."""
import os
import subprocess
import threading

from isimtest import APPS, ISIM, need_apps, run_app, selftest


def test_notify_local(device_data):
    need_apps("NotifyTest")
    selftest("NotifyTest", data=device_data, args=["local"])


def test_notify_across_processes(device_data):
    need_apps("NotifyTest")
    env = dict(os.environ, ISIM_DATA=str(device_data), ISIM_STANDALONE="1")
    listener = subprocess.Popen([str(ISIM), "run", str(APPS / "NotifyTest.app"), "listen"], env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, errors="replace")
    lines, ready = [], threading.Event()

    def read():
        for line in listener.stdout:
            lines.append(line)
            if line.startswith("listening"):
                ready.set()
    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    try:
        assert ready.wait(60), "the listener starts\n" + "".join(lines[-30:])
        poster = run_app("NotifyTest", data=device_data, args=["post"], timeout=60)
        assert poster.returncode == 0 and "pong received" in poster.output, poster.output[-2000:]
        assert listener.wait(60) == 0
    finally:
        if listener.poll() is None:
            listener.kill()
    reader.join(5)
    out = "".join(lines)
    assert "notify test (listen): 4/4 passed" in out and "cf notification dev.isim.notify.cf (observer listener)" in out, out[-2000:]
