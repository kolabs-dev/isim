"""api-coverage.py's exact-mode matching (no build): Apple's documentation keys against symbol-graph keys."""
import importlib.util
from pathlib import Path

TOOL = Path(__file__).resolve().parents[2] / "tools" / "api-coverage.py"
spec = importlib.util.spec_from_file_location("api_coverage", TOOL)
cov = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cov)

# what isim's symbol graphs give for a GKGoal with class functions and only init(), and a type inheriting a protocol's
# initializer (keys: lowercased path components, '~' without the signature; MEMBERS_OF / PARENTS for inheritance)
KEYS = {"gkgoal", "~gkgoal", "gkgoal/init()", "~gkgoal/init", "gkgoal/toseekagent(_:)", "~gkgoal/toseekagent",
        "gkgoal/weight", "~gkgoal/weight", "text", "~text", "proto", "~proto"}
cov.MEMBERS_OF.update({"proto": {cov.member_key("init(stringLiteral:)")}})
cov.PARENTS.update({"text": {"proto"}})


def test_initializer_is_not_a_class_function():
    # issue #729: init(toSeekAgent:) used to match any GKGoal initializer through the name without signature
    assert not cov.matches("gkgoal/init(toseekagent:)", KEYS)
    assert cov.matches("gkgoal/toseekagent(_:)", KEYS)
    assert cov.matches("gkgoal/init()", KEYS)


def test_labels_count_for_functions():
    assert not cov.matches("gkgoal/toseekagent(other:)", KEYS)


def test_properties_match_by_name():
    assert cov.matches("gkgoal/weight", KEYS)
    assert not cov.matches("gkgoal/speed", KEYS)


def test_inherited_members_match_by_signature():
    assert cov.matches("text/init(stringliteral:)", KEYS)
    assert not cov.matches("text/init(unicodescalarliteral:)", KEYS)


def test_disambiguation_suffixes():
    assert cov.norm_component("flatmap(_:)-ibzs") == "flatmap(_:)"      # a hash without digits, after a signature
    assert cov.norm_component("init(_:)-1a2b3") == "init(_:)"
    assert cov.norm_component("index-swift.typealias") == "index"
    assert cov.norm_component("stage") == "stage"


def test_each_documentation_path_counts_once():
    # issue #840: Apple's navigator index lists a page under each topic group it is in (Date's == 72 times)
    tree = [{"children": [
        {"path": "/documentation/foundation/date", "type": "struct", "title": "Date", "children": [
            {"path": "/documentation/foundation/date/==(_:_:)", "type": "op", "title": "=="},
            {"type": "groupMarker", "title": "Comparing", "children": [
                {"path": "/documentation/foundation/date/==(_:_:)", "type": "op", "title": "=="}]}]},
        {"path": "/documentation/foundation/date", "type": "struct", "title": "Date"}]}]
    paths = [s[0] for s in cov.walk_index(tree, "Foundation")]
    assert paths == ["/documentation/foundation/date", "/documentation/foundation/date/==(_:_:)"]
    assert [s[0] for s in cov.dedup([["/a", "", "func", None, 0], ["/a", "", "func", "/b", 0], ["/c", "", "var", None, 0]])] == ["/a", "/c"]


def test_snapshot_holds_each_path_once():
    snap = cov.load_snapshot()
    for m, syms in snap["symbols"].items():
        paths = [s[0] for s in syms]
        assert len(paths) == len(set(paths)), m


def test_xcuiautomation_and_darwin_notify_are_measured_exactly():
    # issue #842: XCUIAutomation is isim's XCTest (Apple's SDK before Xcode 26); Darwin Notify is the notify C module
    assert cov.IMPLEMENTED_IN["XCUIAutomation"] == "XCTest"
    assert cov.IMPLEMENTED_IN["DarwinNotify"] == "notify"
    assert "notify" in cov.c_modules(str(TOOL.parents[1] / "sdk-src" / "usr" / "include" / "module.modulemap"))
    assert cov.doc_key("/documentation/darwinnotify/notify_post(_:)", "DarwinNotify") == "notify_post(_:)"


def test_impossible_frameworks_are_out_of_scope():
    # issue #841: Hypervisor, DriverKit and IOKit need the Darwin kernel or Apple hardware
    import json
    cat = json.load(open(cov.CATALOG))
    assert {"Hypervisor", "DriverKit", "IOKit"} <= set(cat["impossible"])
    in_areas = {f for a in cat["areas"] for f in a["frameworks"]}
    assert not in_areas & (set(cat["impossible"]) | set(cat["deprecated"]))
