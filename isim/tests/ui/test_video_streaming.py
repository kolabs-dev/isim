"""Media that is not a file (HelloVideo -streaming, issue #289): AVAssetResourceLoader serving clip.mp4 for a custom URL
scheme (content information first, then byte ranges, answered asynchronously in parts), a loader that declines, and
HLS playback from a local HTTP server (the red / green / blue clip in 1 s segments), each followed to the end with
AVPlayerItemVideoOutput. Needs ffmpeg/ffprobe on the host."""
import functools
import http.server
import re
import shutil
import subprocess
import threading

import pytest
from isimtest import APPS


@pytest.fixture
def hls_server(tmp_path):
    """an HLS VOD stream of the clip (1 s segments, a key frame each second) served on 127.0.0.1"""
    clip = APPS / "HelloVideo.app/clip.mp4"
    if not clip.exists() or not shutil.which("ffmpeg"):
        pytest.skip("HelloVideo not built (needs ffmpeg)")
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-i", str(clip), "-c:v", "libx264", "-preset", "veryfast",
                    "-force_key_frames", "expr:gte(t,n_forced*1)", "-c:a", "aac", "-b:a", "64k", "-f", "hls", "-hls_time", "1",
                    "-hls_playlist_type", "vod", "-hls_segment_filename", str(tmp_path / "seg%d.ts"), str(tmp_path / "index.m3u8")],
                   check=True)
    requests = []

    class Handler(http.server.SimpleHTTPRequestHandler):
        def log_message(self, fmt, *args):
            requests.append(self.path)
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(tmp_path)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}/index.m3u8", requests
    server.shutdown()


def test_streaming(launch, hls_server):
    url, requests = hls_server
    app = launch("HelloVideo", args=["-streaming", "-hls", url])
    app.wait_log(r"HelloVideo: loader ended", timeout=30)
    app.wait_log(r"HelloVideo: hls ended", timeout=30)
    assert app.quit() == 0
    log = app.log

    def line(p):
        m = re.search(f"^.*{p}.*$", log, re.M)
        return m.group(0) if m else f"no {p!r} line"

    m = re.search(r"loader ready duration 3\.00 size 320x180 requests (\d+) info 1 ranges 0-2,2-(\d+)", log)
    assert m and int(m[1]) >= 2, f"the resource loader: content information with 2 bytes, then the ranges: {line('loader ready')}"
    assert re.search(r"loader ended frames red,green,blue type VOD uri isim-sample://media/clip\.mp4", log), \
        f"the loaded clip plays to the end (frames follow the video): {line('loader ended')}"
    assert re.search(r"declined status failed domain AVFoundationErrorDomain code -11828", log), \
        f"a declining loader fails the item: {line('declined')}"
    assert re.search(r"hls ready duration 3\.0\d size 320x180", log), f"HLS: {line('hls ready')}"
    assert re.search(r"hls ended frames (other,)?red,green,blue type VOD uri http://127\.0\.0\.1:\d+/index\.m3u8", log), \
        f"HLS plays to the end: {line('hls ended')}"
    assert any(r.startswith("/seg") for r in requests), f"the segments were fetched over HTTP: {requests}"
