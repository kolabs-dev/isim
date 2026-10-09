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
