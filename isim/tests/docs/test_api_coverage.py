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
