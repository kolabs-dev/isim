"""App Intents beyond parameters (HelloBookshelfIntents, issue #230), driven the way the system does: the metadata
the home screen reads (ISIM_EXTENSION_REQUEST appintents-list: parameter summaries with When / Summary tables,
DynamicOptionsProvider options, entity @Property titles, EntityPropertyQuery properties / comparators / sort options),
and runs through the intent request protocol (isim-intent:): a "find" request answered by the EntityPropertyQuery,
@Dependency from AppDependencyManager, a choice from the options provider, IntentPerson / IntentCurrencyAmount values
and an IntentFile result, AppIntentError's message as the failure dialog and restartPerform."""
import plistlib
import re
import time

from isimtest import run_app


def metadata(tmp_path, device_data):
    req, out = tmp_path / "list.plist", tmp_path / "list-out.plist"
    req.write_bytes(plistlib.dumps({"mode": "appintents-list", "out": str(out)}))
    r = run_app("HelloBookshelfIntents", data=device_data, env={"ISIM_EXTENSION_REQUEST": str(req)}, timeout=60)
    assert r.returncode == 0 and out.exists(), r.output[-2000:]
    return plistlib.loads(out.read_bytes())


def test_bookshelf_metadata(tmp_path, device_data):
    m = metadata(tmp_path, device_data)
    intents = m["intents"]
    assert intents["HelloBookshelfIntents.OpenBookIntent"]["summary"] == "Open ${book}"
    shelve = intents["HelloBookshelfIntents.ShelveBookIntent"]
    # the When: no shelf yet, so the otherwise branch, with the note listed under the sentence
    assert shelve["summary"] == "Put ${book} on ${shelf}" and shelve["summaryTable"] == ["note"], shelve
    shelf = next(p for p in shelve["parameters"] if p["name"] == "shelf")
    assert shelf.get("dynamicOptions") and [o["title"] for o in shelf["options"]] == ["Favorites", "To Read", "Book Club"], shelf
    assert shelf["options"][0]["subtitle"] == "the best ones"
    lend = intents["HelloBookshelfIntents.LendBookIntent"]
    assert lend["summary"] == "Lend ${book} to ${friend}" and lend["summaryTable"] == ["deposit"]
    kinds = {p["name"]: p["kind"] for p in lend["parameters"]}
    assert kinds == {"book": "entity", "friend": "person", "deposit": "currency"}, kinds
    assert "summary" not in intents["HelloBookshelfIntents.MissingBookIntent"], "no parameterSummary, no sentence"

    book = m["entities"]["HelloBookshelfIntents.BookEntity"]
    assert book["name"] == "Book"
    assert [(p["name"], p["title"]) for p in book["properties"]] == [("title", "Title"), ("author", "Author"), ("pages", "Pages")], book
    q = book["query"]
    assert [(p["name"], p["comparators"]) for p in q["properties"]] == [("title", ["equalTo", "contains", "hasPrefix"]),
                                                                        ("pages", ["lessThan", "greaterThan"])], q
    assert q["sortable"] == ["title", "pages"]


def _read(path):
    """the plist once it is complete (written atomically, but read it defensively)"""
    try:
        return plistlib.loads(path.read_bytes()) and path.read_bytes()
    except Exception:
        return None


class Run:
    """one intent request: the app is launched with isim-intent:<dir>/request.plist and writes step-N.plist"""

    def __init__(self, launch, tmp_path, request):
        self.dir = tmp_path / f"run-{time.monotonic_ns()}"
        self.dir.mkdir()
        (self.dir / "request.plist").write_bytes(plistlib.dumps({**request, "dir": str(self.dir)}))
        self.app = launch("HelloBookshelfIntents", env={"ISIM_LAUNCH_URL": f"isim-intent:{self.dir}/request.plist"})

    def step(self, n):
        path = self.dir / f"step-{n}.plist"
        self.app.wait_until(path.exists, what=f"step-{n}.plist")
        return plistlib.loads(self.app.wait_until(lambda: _read(path), what=f"step-{n}.plist written"))

    def answer(self, n, d):
        (self.dir / f"answer-{n}.plist").write_bytes(plistlib.dumps(d))


def test_bookshelf_runs(launch, tmp_path):
    # Find Books where title contains "swift" and pages < 400, sorted by pages descending
    r = Run(launch, tmp_path, {"find": "HelloBookshelfIntents.BookEntity", "where": [["title", "contains", "swift"]],
                               "sort": "pages", "order": "descending"})
    s = r.step(1)
    assert s["outcome"] == "success" and [e["title"] for e in s["entities"]] == ["Advanced Swift", "Swift Basics"], s
    r.app.quit()
    r = Run(launch, tmp_path, {"find": "HelloBookshelfIntents.BookEntity", "where": [["title", "contains", "swift"], ["pages", "lessThan", "400"]]})
    assert [e["title"] for e in r.step(1)["entities"]] == ["Swift Basics"], "mode and: both comparisons"
    r.app.quit()

    # Shelve Book: the shelf comes from the DynamicOptionsProvider; the Library from @Dependency
    r = Run(launch, tmp_path, {"intent": "HelloBookshelfIntents.ShelveBookIntent", "params": {"book": "3"}})
    s = r.step(1)
    assert s["type"] == "choice" and [o["title"] for o in s["options"]] == ["Favorites", "To Read", "Book Club"], s
    r.answer(1, {"kind": "option", "index": 1})
    assert r.step(2)["dialog"] == "Gardening is on To Read (1 there)."
    assert re.search(r"^bi dependency 3 books$", r.app.log, re.M)
    r.app.quit()

    # Lend Book: a person and a currency amount from text; an IntentFile comes back
    r = Run(launch, tmp_path, {"intent": "HelloBookshelfIntents.LendBookIntent",
                               "params": {"book": "1", "friend": "Ana Lima <ana@example.com>", "deposit": "12.50 USD"}})
    s = r.step(1)
    assert s["outcome"] == "success" and s["dialog"] == "Swift Basics lent to Ana Lima (ana@example.com) for $12.50.", s
    assert s["value"] == "loan-slip.txt", "the IntentFile result is described by its name"
    r.app.quit()

    # AppIntentError: its message is the failure dialog; restartPerform runs perform() again
    r = Run(launch, tmp_path, {"intent": "HelloBookshelfIntents.MissingBookIntent"})
    s = r.step(1)
    assert s["outcome"] == "failure" and s["dialog"] == "The item couldn’t be found.", s
    r.app.quit()
    r = Run(launch, tmp_path, {"intent": "HelloBookshelfIntents.SyncLibraryIntent"})
    assert r.step(1)["dialog"] == "Synced after 2 attempts."
