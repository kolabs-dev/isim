"""MusicKit (HelloMusicKit): authorization, library requests over the simulated music library (sorting, filters,
albums, artists, playlists), ApplicationMusicPlayer playing an album, no Apple Music subscription, and the catalog:
requests go to the Apple Music API with the developer token from ISIM_MUSICKIT_DEVELOPER_TOKEN (here a local server
standing in for api.music.apple.com, ISIM_MUSICKIT_API), and fail with developerTokenRequestFailed without one."""
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

SONG = {"id": "1440857781", "type": "songs", "attributes": {
    "name": "Sine Wave", "artistName": "Test Tones", "albumName": "Pure Signals", "durationInMillis": 183000, "trackNumber": 3,
    "genreNames": ["Electronic"], "releaseDate": "2019-05-01", "isrc": "USX9P1900001",
    "artwork": {"url": "https://example.invalid/art/{w}x{h}bb.jpg", "width": 3000, "height": 3000}}}
ALBUM = {"id": "1440857700", "type": "albums", "attributes": {"name": "Pure Signals", "artistName": "Test Tones", "trackCount": 10}}


@pytest.fixture
def api():
    seen = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            seen.append((self.path, self.headers.get("Authorization")))
            if self.path.startswith("/v1/catalog/us/search"):
                body = {"results": {"songs": {"data": [SONG]}, "albums": {"data": [ALBUM]}}}
            elif self.path.startswith("/v1/catalog/us/songs"):
                body = {"data": [SONG]}
            else:
                body = {"results": {"songs": [{"chart": "most-played", "data": [SONG]}]}}
            data = json.dumps(body).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def log_message(self, *a):
            pass
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}", seen
    server.shutdown()


def run(launch, env):
    app = launch("HelloMusicKit", env={"ISIM_MEDIALIBRARY_PERMISSION": "allow", "SDL_AUDIO_DRIVER": "dummy", **env})
    app.wait_log(r"HelloMusicKit: done", timeout=30)
    assert app.quit() == 0, "exits cleanly"
    return app.log


def test_musickit(launch, api):
    url, seen = api
    log = run(launch, {"ISIM_MUSICKIT_API": url, "ISIM_MUSICKIT_DEVELOPER_TOKEN": "test-developer-token"})

    def has(p):
        return re.search(p, log, re.M)
    assert has(r"status before notDetermined") and has(r"HelloMusicKit: status authorized"), "authorization (shared with MPMediaLibrary)"
    m = has(r"library songs 6: (.*)$")
    assert m and m.group(1).split(", ") == sorted(m.group(1).split(", ")), "library songs, sorted by title"
    assert has(r"by artist (\w[^,]*, ){2}\w"), "filter equalTo (an artist's three songs)"
    assert has(r"contains loop Render Loop"), "filter contains"
    assert has(r"albums [^(]+ \(3\), [^(]+ \(3\)") and has(r"artists .+, .+") and has(r"playlists isim Favorites \(3\)"), "albums, artists, playlists"
    assert has(r"song details artwork=true duration=\d+ albums=1"), "song artwork (a file) and relationships"
    assert has(r"playing \S.* status=playing entries=3") and has(r"next \S") and has(r"paused status=paused"), "ApplicationMusicPlayer"
    assert has(r"subscription canPlayCatalogContent=false"), "no Apple Music subscription"
    assert has(r"catalog songs Sine Wave by Test Tones 183s albums Pure Signals"), "catalog search (Apple Music API JSON)"
    assert has(r"resource Sine Wave artwork=https://example.invalid/art/200x200bb.jpg"), "catalog resource request, artwork URL template"
    assert has(r"catalog play error"), "catalog songs cannot play without a subscription"
    assert has(r"data request status=200 bytes=\d+"), "MusicDataRequest"
    paths = [p for p, _ in seen]
    assert any(p.startswith("/v1/catalog/us/search?term=sine%20wave&types=songs,albums&limit=5") for p in paths), paths
    assert any(p == "/v1/catalog/us/songs?ids=1440857781" for p in paths), paths
    assert all(auth == "Bearer test-developer-token" for _, auth in seen), "the developer token is sent"


def test_musickit_no_token(launch, monkeypatch):
    monkeypatch.delenv("ISIM_MUSICKIT_DEVELOPER_TOKEN", raising=False)
    log = run(launch, {})
    assert re.search(r"catalog error developerTokenRequestFailed", log), "no developer token: the catalog is unavailable"
