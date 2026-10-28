"""MusicKit (HelloMusic, -musickit): authorization, library requests over the simulated music library (sorting, filters,
albums, artists, playlists) and library search, ApplicationMusicPlayer playing an album, no Apple Music subscription
(and the offer sheet saying so), ArtworkImage, and the catalog: requests go to the Apple Music API with the developer
token from ISIM_MUSICKIT_DEVELOPER_TOKEN (here a local server standing in for api.music.apple.com, ISIM_MUSICKIT_API),
and fail with developerTokenRequestFailed without one. Charts, with(_:) relationships and views, music videos,
stations, record labels and genres (issue #384); recently played items and recommendations with the user token
(ISIM_MUSICKIT_USER_TOKEN)."""
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
GENRE = {"id": "7", "type": "genres", "attributes": {"name": "Electronic", "parentId": "34", "parentName": "Music"}}
VIDEO = {"id": "1440858000", "type": "music-videos", "attributes": {
    "name": "Sine Wave (Video)", "artistName": "Test Tones", "has4K": True, "hasHDR": False, "contentRating": "clean",
    "durationInMillis": 200000, "previews": [{"url": "https://example.invalid/preview.m4v", "hlsUrl": "https://example.invalid/p.m3u8"}]}}
STATION = {"id": "ra.123", "type": "stations", "attributes": {"name": "Signals Radio", "isLive": True, "stationProviderName": "isim FM"}}
LABEL = {"id": "1543411840", "type": "record-labels", "attributes": {"name": "Signal Records", "description": {"short": "Tones"}}}
RECOMMENDATION = {"id": "6-27s5hU6azhJY", "type": "personal-recommendation", "attributes": {
    "title": {"stringForDisplay": "Made for You"}, "resourceTypes": ["albums", "stations"]},
    "relationships": {"contents": {"data": [ALBUM, STATION]}}}


def route(path):
    """the stub Apple Music API's answer"""
    if path.startswith("/v1/catalog/us/search") and "music-videos" in path:
        return {"results": {"music-videos": {"data": [VIDEO]}, "stations": {"data": [STATION]}, "record-labels": {"data": [LABEL]}}}
    if path.startswith("/v1/catalog/us/search"):
        return {"results": {"songs": {"data": [SONG]}, "albums": {"data": [ALBUM]}}}
    if path.startswith("/v1/catalog/us/songs/"):
        return {"data": [dict(SONG, relationships={"albums": {"data": [ALBUM]}, "genres": {"data": [GENRE]}, "music-videos": {"data": [VIDEO]}})]}
    if path.startswith("/v1/catalog/us/songs"):
        return {"data": [SONG]}
    if path.startswith("/v1/catalog/us/record-labels/"):
        return {"data": [dict(LABEL, views={"latest-releases": {"data": [ALBUM]}})]}
    if path.startswith("/v1/catalog/us/genres"):
        return {"data": [GENRE]}
    if path.startswith("/v1/me/recent/played/tracks"):
        return {"data": [SONG]}
    if path.startswith("/v1/me/recent/played"):
        return {"data": [ALBUM, STATION]}
    if path.startswith("/v1/me/recommendations"):
        return {"data": [RECOMMENDATION]}
    return {"results": {"songs": [{"chart": "most-played", "name": "Top Songs", "orderId": "most-played:songs", "data": [SONG]}],
                        "music-videos": [{"chart": "most-played", "name": "Top Music Videos", "data": [VIDEO]}]}}


@pytest.fixture
def api():
    seen = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            seen.append((self.path, self.headers.get("Authorization"), self.headers.get("Music-User-Token")))
            data = json.dumps(route(self.path)).encode()
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
    app = launch("HelloMusic", args=["-musickit"], env={"ISIM_MEDIALIBRARY_PERMISSION": "allow", "SDL_AUDIO_DRIVER": "dummy", **env})
    app.wait_log(r"HelloMusicKit: done", timeout=30)
    app.wait_view(r"id=MusicSubscriptionOffer\b")
    assert app.quit() == 0, "exits cleanly"
    return app.log


def test_musickit(launch, api):
    url, seen = api
    log = run(launch, {"ISIM_MUSICKIT_API": url, "ISIM_MUSICKIT_DEVELOPER_TOKEN": "test-developer-token", "ISIM_MUSICKIT_USER_TOKEN": "test-user-token"})

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
    # issue #384
    assert has(r"charts songs Top Songs \[mostPlayed\] Sine Wave videos Sine Wave \(Video\)"), "MusicCatalogChartsRequest"
    assert has(r"with albums=Pure Signals genres=Electronic<Music videos=1"), "with(_:) loads relationships (genre parent)"
    assert has(r"music video Sine Wave \(Video\) 4K=true rating=clean previews=1"), "MusicVideo"
    assert has(r"station Signals Radio live=true provider=isim FM"), "Station"
    assert has(r"record label Signal Records latest=Pure Signals"), "RecordLabel and a view (latest releases)"
    assert has(r"genre Electronic$"), "Genre resource request"
    assert has(r"recently played songs Sine Wave$") and has(r"recently played containers Pure Signals, Signals Radio"), "MusicRecentlyPlayedRequest"
    assert has(r"recommendations Made for You: Pure Signals/Signals Radio"), "MusicPersonalRecommendationsRequest"
    assert has(r"library search songs [^\n]*Render Loop[^\n]* top \w"), "MusicLibrarySearchRequest with top results"
    assert has(r"offer loaded error=none"), "the subscription offer sheet"
    paths = [p for p, _, _ in seen]
    assert any(p.startswith("/v1/catalog/us/search?term=sine%20wave&types=songs,albums&limit=5") for p in paths), paths
    assert any(p == "/v1/catalog/us/songs?ids=1440857781" for p in paths), paths
    assert "/v1/catalog/us/songs/1440857781?include=albums,genres,music-videos" in paths, paths
    assert "/v1/catalog/us/record-labels/1543411840?views=latest-releases" in paths, paths
    assert any(p.startswith("/v1/catalog/us/charts?types=songs,music-videos&chart=most-played&limit=10") for p in paths), paths
    assert all(auth == "Bearer test-developer-token" for _, auth, _ in seen), "the developer token is sent"
    assert all(user == "test-user-token" for p, _, user in seen if p.startswith("/v1/me/")), "the user token is sent to /v1/me"


def test_musickit_no_token(launch, monkeypatch):
    monkeypatch.delenv("ISIM_MUSICKIT_DEVELOPER_TOKEN", raising=False)
    log = run(launch, {})
    assert re.search(r"catalog error developerTokenRequestFailed", log), "no developer token: the catalog is unavailable"
    assert re.search(r"user error developerTokenRequestFailed", log), "nor the requests about the user"
    assert re.search(r"library search songs .*Render Loop", log), "library search needs no token"


def test_musickit_no_user_token(launch, api, monkeypatch):
    """a developer token without a user token: the catalog works, recently played and recommendations do not"""
    url, seen = api
    monkeypatch.delenv("ISIM_MUSICKIT_USER_TOKEN", raising=False)
    log = run(launch, {"ISIM_MUSICKIT_API": url, "ISIM_MUSICKIT_DEVELOPER_TOKEN": "test-developer-token"})
    assert re.search(r"charts songs Top Songs", log), "the catalog"
    assert re.search(r"user error userTokenRequestFailed", log), "no user token"
    assert not any(p.startswith("/v1/me/") for p, _, _ in seen), "no request about the user is sent"
