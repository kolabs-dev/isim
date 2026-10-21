"""No Swift overlay puts @objcMembers on an open class (docs/BUILD.md, "Adding things"; issue #636): apps' Swift
subclasses inherit the attribute, so their own members are inferred @objc and clash with the superclass's selectors (a
method constraints() against a constraints property), which the same code on iOS does not. Members are marked @objc one
by one instead. No build needed."""
import re
from pathlib import Path

OVERLAYS = Path(__file__).resolve().parents[2] / "swift" / "overlays"
# the attribute and `open class` in one declaration, possibly with other attributes and modifiers between them
DECL = re.compile(r"@objcMembers\b(?:\s+@[\w.]+(?:\([^)]*\))?|\s+(?:public|final|nonisolated|@unchecked))*\s+open\s+class\b")


def test_no_objc_members_on_open_classes():
    found = [f"{p.relative_to(OVERLAYS)}:{i}: {line.strip()}" for p in sorted(OVERLAYS.rglob("*.swift"))
             for i, line in enumerate(p.read_text().splitlines(), 1) if DECL.search(line)]
    assert not found, "@objcMembers on open classes (mark the members @objc instead):\n" + "\n".join(found)


def test_the_check_finds_one():
    assert DECL.search("@objc(SCNNode) @objcMembers open class SCNNode: NSObject {")
    assert not DECL.search("@objc(CKShareMetadata) @objcMembers public final class X: NSObject {")
