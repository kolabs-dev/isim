"""isim boot with HelloTransfers: a background URLSession. The download keeps going while the app is in the
background (the app reports "transfer", so the shell does not suspend it); when it finishes there, the app delegate's
handleEventsForBackgroundURLSession runs, the session's delegate events follow (the file is complete), then
urlSessionDidFinishEvents; once the app calls the completion handler it can be suspended again."""
import http.server
import threading
import time

APP = "dev.isim.samples.HelloTransfers"
SIZE = 300_000                                                         # (30 equal chunks)


class SlowFile(http.server.BaseHTTPRequestHandler):
    """SIZE bytes over about three seconds, so the app is in the background before the download ends"""
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(SIZE))
        self.end_headers()
        chunk = b"x" * (SIZE // 30)
        for _ in range(30):
            self.wfile.write(chunk)
            self.wfile.flush()
            time.sleep(0.1)

    def log_message(self, *args):
        pass


def test_background_download(launch):
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SlowFile)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        url = f"http://127.0.0.1:{server.server_address[1]}/file"
        dev = launch(None, install=["HelloTransfers"], env={"TRANSFER_URL": url, "ISIM_SUSPEND_SECONDS": "1"})
        dev.send(f"launch {APP}")
        dev.wait_opened("HelloTransfers")
        dev.wait_tap_id("download")
        dev.wait_log(r"^download started")
        dev.send("home")                                                    # the transfer keeps the app running
        dev.wait_log(r"isim: running in the background: transfer")
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.transfers finished: waking the app")
        dev.wait_log(r"^handle events for dev\.isim\.samples\.transfers")
        dev.wait_log(rf"^download finished: {SIZE} bytes, app in the background")
        dev.wait_log(r"^task complete, error none")
        dev.wait_log(r"^session finished events")
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.transfers events handled")
        dev.wait_log(r"isim shell: suspended HelloTransfers\.app")         # nothing left to do: suspended
        log = dev.log
        assert "suspended HelloTransfers.app" not in log.split("waking the app")[0], "not suspended while the transfer ran"
        assert log.index("handle events for") < log.index("download finished"), "the app delegate hears it before the session's events"
    finally:
        server.shutdown()


def test_unfinished_transfer_restarts(launch, device_data):
    """the app is terminated during a background download: recreating the session starts it again (adapted: isim has
    no transfer daemon that would finish it meanwhile)"""
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SlowFile)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        env = {"TRANSFER_URL": f"http://127.0.0.1:{server.server_address[1]}/file"}
        app = launch("HelloTransfers", env=env)
        app.wait_tap_id("download")
        app.wait_log(r"^download started")
        assert app.quit() == 0                                              # terminated mid-transfer
        app = launch("HelloTransfers", env=env, data=device_data)
        app.wait_log(r"isim: background URL session dev\.isim\.samples\.transfers: starting 1 unfinished transfer\(s\) again")
        app.wait_log(rf"^download finished: {SIZE} bytes, app active")
        app.wait_log(r"^task complete, error none")
        assert app.quit() == 0
    finally:
        server.shutdown()


def slow_server():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), SlowFile)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_address[1]}/file"


def test_terminated_app_relaunched_for_transfers(launch):
    """the system ends the app during a background download (script `terminate`, like iOS reclaiming memory): the home
    screen relaunches it in the background, the recreated session finishes the download there and wakes the app as
    usual (adapted: iOS's transfer daemon would finish it while the app is not running)"""
    server, url = slow_server()
    try:
        dev = launch(None, install=["HelloTransfers"], env={"TRANSFER_URL": url, "ISIM_SUSPEND_SECONDS": "1"})
        dev.send(f"launch {APP}")
        dev.wait_opened("HelloTransfers")
        dev.wait_tap_id("download")
        dev.wait_log(r"^download started")
        dev.send(f"terminate {APP}")
        dev.wait_log(r"isim shell: terminated .*HelloTransfers\.app \(system\)")
        dev.wait_log(r"SpringBoard: Transfers ended with unfinished background transfers \(dev\.isim\.samples\.transfers\): relaunching")
        dev.wait_log(r"isim: launched in the background")
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.transfers: starting 1 unfinished transfer\(s\) again")
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.transfers finished: waking the app")
        dev.wait_log(r"^handle events for dev\.isim\.samples\.transfers")
        dev.wait_log(rf"^download finished: {SIZE} bytes, app in the background")
        dev.wait_log(r"^session finished events")
        dev.wait_log(r"isim shell: suspended HelloTransfers\.app")
    finally:
        server.shutdown()


def test_force_quit_cancels_transfers(launch):
    """closing the app in the app switcher cancels its background transfers, as on iOS: no relaunch"""
    server, url = slow_server()
    try:
        dev = launch(None, install=["HelloTransfers"], env={"TRANSFER_URL": url})
        dev.send(f"launch {APP}")
        dev.wait_opened("HelloTransfers")
        dev.wait_tap_id("download")
        dev.wait_log(r"^download started")
        dev.send("switcher")
        dev.wait_log(r"app switcher \(")
        dev.send("swipeid switcher-HelloTransfers 0 -300 0.3")
        dev.wait_log(r"HelloTransfers\.app exited")
        dev.send("home")
        dev.send(f"launch {APP}")                                          # a fresh launch: nothing to start again
        dev.wait_log(r"isim: launching Transfers \(dev\.isim\.samples\.HelloTransfers\)", count=2)
        dev.wait_log(r"isim shell: launched .*HelloTransfers\.app", count=2)
        assert dev.quit() == 0
        assert "relaunching it in the background" not in dev.log and "unfinished transfer" not in dev.log, \
            "a force-quit discards the background transfers"
    finally:
        server.shutdown()


def test_swiftui_url_session_background_task(launch):
    """SwiftUI: .backgroundTask(.urlSession(id)) runs where a UIKit app's handleEventsForBackgroundURLSession would,
    both when the download ends in the background and after a system termination, where the app recreates the session
    only in that action"""
    scenes = "dev.isim.samples.HelloScenes"
    server, url = slow_server()
    try:
        dev = launch(None, install=["HelloScenes"], env={"TRANSFER_URL": url, "ISIM_SUSPEND_SECONDS": "1"})
        dev.send(f"launch {scenes}")
        dev.wait_tap_id("download")
        dev.wait_log(r"HelloScenes: download started")
        dev.send("home")
        dev.wait_log(r"isim SwiftUI: background URL session dev\.isim\.samples\.HelloScenes\.transfers \(\.backgroundTask\(\.urlSession\)\)")
        dev.wait_log(rf"HelloScenes: download finished: {SIZE} bytes")
        dev.wait_log(r"HelloScenes: session finished events")

        dev.send(f"launch {scenes}")                                       # again, and the system ends the app
        dev.wait_tap_id("download")
        dev.wait_log(r"HelloScenes: download started", count=2)
        dev.send(f"terminate {scenes}")
        dev.wait_log(r"relaunching it in the background")
        dev.wait_log(r"isim: relaunched for background URL session dev\.isim\.samples\.HelloScenes\.transfers")
        dev.wait_log(r"HelloScenes: SwiftUI background URL session dev\.isim\.samples\.HelloScenes\.transfers")
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.HelloScenes\.transfers finished$")
        dev.wait_log(rf"HelloScenes: download finished: {SIZE} bytes", count=2)
        dev.wait_log(r"HelloScenes: session finished events", count=2)
        dev.wait_log(r"isim: background URL session dev\.isim\.samples\.HelloScenes\.transfers events handled")
    finally:
        server.shutdown()
