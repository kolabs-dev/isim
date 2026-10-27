"""Translation (HelloTranslation, "Phrasebook", issue #367): passthrough to a LibreTranslate-compatible server on the
host (ISIM_TRANSLATE_URL), scripted here: LanguageAvailability (supported languages, a pair's status, a text's detected
language), a view's translationTask (a batch with client identifiers, a streamed batch, an attributed string, run again
by the configuration's invalidate()), the errors and their ~= matching, iOS 26's sessions for installed languages
(isReady, canRequestDownloads, cancel), and translationPresentation's sheet replacing a phrase with its translation.
Without a server no pair is supported."""
import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import pytest

APP = "HelloTranslation"

LANGUAGES = [{"code": "en", "name": "English", "targets": ["en", "es", "fr"]},
             {"code": "es", "name": "Spanish", "targets": ["en", "es"]},
             {"code": "fr", "name": "French", "targets": ["en", "fr"]}]
WORDS = {("en", "es"): {"Hello, how are you?": "Hola, ¿cómo estás?", "Good morning": "Buenos días", "Thank you": "Gracias", "Hello": "Hola"},
         ("es", "en"): {"Hola, ¿cómo estás?": "Hello, how are you?", "Gracias": "Thank you"}}


class _LibreTranslate(BaseHTTPRequestHandler):
    """GET /languages, POST /translate (q: a string or a list), POST /detect"""
    requests = []

    def log_message(self, *a):
        pass

    def answer(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        _LibreTranslate.requests.append({"path": self.path})
        self.answer(LANGUAGES if self.path.endswith("/languages") else {"error": "not found"}, 200 if self.path.endswith("/languages") else 404)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        _LibreTranslate.requests.append({"path": self.path, **body})
        if self.path.endswith("/detect"):
            spanish = re.search(r"hola|gracias|¿", body["q"].lower())
            return self.answer([{"language": "es" if spanish else "en", "confidence": 90.0}])
        q = body["q"]
        words = WORDS.get((body["source"], body["target"]), {})
        out = [words.get(t, f"[{body['target']}] {t}") for t in (q if isinstance(q, list) else [q])]
        self.answer({"translatedText": out if isinstance(q, list) else out[0]})


@pytest.fixture
def server():
    _LibreTranslate.requests = []
    s = ThreadingHTTPServer(("127.0.0.1", 0), _LibreTranslate)
    threading.Thread(target=s.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{s.server_address[1]}"
    s.shutdown()


def test_translation(launch, server):
    app = launch(APP, os_version="26", env={"ISIM_TRANSLATE_URL": server})
    app.wait_log(r"HelloTranslation: done")
    for line in [
        "supported [\"en\", \"es\", \"fr\"]",
        "status en->es installed en->de unsupported es->en installed en->en unsupported",
        "detected status installed",
        "en->de TranslationError.unsupportedLanguagePairing: Translation between these languages is not supported.",
        "it->en TranslationError.unsupportedSourceLanguage",
        "empty TranslationError.nothingToTranslate",
        "prepare en->es ok",
        "matched unsupportedLanguagePairing",
        "installed ready true canRequestDownloads false de ready false",
        "installed 'Thank you'",
        "after cancel TranslationError.alreadyCancelled true",
    ]:
        assert f"HelloTranslation: {line}" in app.log, line
    app.wait_log(r'task run 1 version 0: \["Hola, ¿cómo estás\?", "Buenos días", "Gracias"\] ids \["p0", "p1", "p2"\] en->es')
    app.wait_log(r"batch 3 in order true")
    app.wait_log(r"attributed 'Gracias' source attributed true target Gracias")
    app.wait_log(r"task session canRequestDownloads true ready true")
    app.wait_view(r"id=spanish-1 .*Buenos días")

    app.wait_tap_id("again")                                     # configuration.invalidate(): the task runs again
    app.wait_log(r"task run 2 version 1: ")

    app.wait_tap_id("present")                                   # the system's translation sheet
    app.wait_view(r"id=translation\.target .*Hello, how are you\?")
    app.wait_still()
    app.screenshot("translation-sheet")
    app.wait_tap_id("translation.replace")
    app.wait_log(r"HelloTranslation: replaced with 'Hello, how are you\?'")
    app.wait_view(r"id=translation\.target", gone=True)
    app.wait_view(r"id=phrase .*Hello, how are you\?")
    assert app.quit() == 0

    paths = [r["path"] for r in _LibreTranslate.requests]
    assert paths.count("/languages") == 1, "the pairs are fetched once"
    batch = [r for r in _LibreTranslate.requests if r["path"] == "/translate" and isinstance(r["q"], list) and len(r["q"]) == 3]
    assert batch and batch[0]["source"] == "en" and batch[0]["target"] == "es" and batch[0]["format"] == "text"
    assert any(r["path"] == "/detect" and r["q"] == "Hola, ¿cómo estás?" for r in _LibreTranslate.requests), "the sheet detects the language"


@pytest.mark.os_matrix
def test_translation_without_engine(launch, ios):
    """no server configured: nothing is supported; sessions throw unsupportedLanguagePairing and say why; the sheet
    (iOS 17.4 and later) says the translation is unavailable"""
    app = launch(APP)
    app.wait_log(r"HelloTranslation: done")
    major = int(str(ios[0] or 18).split(".")[0])
    if major < 18:
        assert "translation sessions need iOS 18" in app.log
        assert app.quit() == 0
        return
    assert "HelloTranslation: supported []" in app.log
    assert "status en->es unsupported en->de unsupported es->en unsupported en->en unsupported" in app.log
    assert "detected status unsupported" in app.log
    app.wait_log(r"task run 1 error TranslationError\.unsupportedLanguagePairing: no translation engine is configured on this host")
    if major >= 26:
        assert "prepare en->es TranslationError.unsupportedLanguagePairing" in app.log
        assert "installed ready false canRequestDownloads false de ready false" in app.log
    app.wait_tap_id("present")
    app.wait_view(r"id=translation\.unavailable .*no translation engine is configured")
    app.wait_still()
    app.screenshot("translation-unavailable")
    app.wait_tap_id("translation.done")
    app.wait_view(r"id=translation\.unavailable", gone=True)
    assert app.quit() == 0
