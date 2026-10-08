"""The live control FIFO (ISIM_CONTROL, what isimtest drives apps with): commands that arrive while the launch script
(ISIM_SCRIPT) has not finished are queued after it, not lost. On a starved CPU (CI runners) a test's first `dump FILE`
used to arrive before the app ran the script's last command and was glued to it ("wait 0dump FILE"), so the app never
answered and the test timed out after 30 s."""
from isimtest import App, need_apps


def test_commands_during_launch_script(tmp_path):
    need_apps("HelloCounter")
    data = tmp_path / "data"
    data.mkdir()
    # the script's last command still waits to run when the first snapshot request arrives
    with App("HelloCounter", data=data, env={"ISIM_SCRIPT": "wait 2;wait 0"}) as app:   # __enter__: snapshots
        assert app.find(type="window"), "the snapshot sent during the launch script is answered"
        app.wait_log("sceneDidBecomeActive")
        app.tap(196, 444)
        app.wait_log("HelloCounter: count = 1")
        assert app.quit() == 0
