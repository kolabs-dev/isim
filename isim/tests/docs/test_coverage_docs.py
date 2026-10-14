"""The coverage pages (docs/COVERAGE.md, docs/frameworks/*.md) are well formed: no app runs, no build needed.

Every row has a valid status and iOS cell, every sample or test it cites exists, every page has the generated markers
coverage-summary.py fills in, and every page's module has an area in isim/data/frameworks.json.
"""
import json
import re
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
PAGES = sorted(p for p in (REPO / "docs" / "frameworks").glob("*.md") if not p.name.startswith("_"))
MARKS = {"✅", "🟡", "🧩", "❌", "⛔", "N/A"}
IOS = re.compile(r"^(≤17|\d+(\.\d+)?)$")
SAMPLES = {p.name for p in (REPO / "isim" / "samples").rglob("*") if p.is_dir()}
TESTS = {p.stem for p in (REPO / "isim" / "tests").rglob("*.py")} | {p.name for p in (REPO / "isim" / "tests").rglob("*") if p.is_dir()}
TESTS |= {m for p in (REPO / "isim" / "tests").rglob("*.py") for m in re.findall(r"^\s*def (test_\w+)", p.read_text(errors="ignore"), re.M)}
CITED = re.compile(r"\b(Hello[A-Z]\w*|test_\w+)\b")


def rows(page):
    for n, line in enumerate(page.read_text(encoding="utf-8").split("\n"), 1):
        if line.startswith("| ") and not line.startswith(("| API", "|---")):
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if len(cells) >= 2 and (cells[1] in MARKS or any(m in cells[1] for m in MARKS)):
                yield n, cells


def test_pages_exist():
    assert len(PAGES) > 50


@pytest.mark.parametrize("page", PAGES, ids=lambda p: p.stem)
def test_page_rows(page):
    bad = []
    for n, cells in rows(page):
        if len(cells) < 4:
            bad.append(f"{page.name}:{n}: {len(cells)} cells, want | API | Status | iOS | Notes |")
            continue
        if cells[1] not in MARKS:
            bad.append(f"{page.name}:{n}: status {cells[1]!r}")
        if not IOS.match(cells[2]):
            bad.append(f"{page.name}:{n}: iOS column {cells[2]!r} (≤17, 18.0, 26.0, 27.1, …)")
    assert not bad, "\n".join(bad)


@pytest.mark.parametrize("page", PAGES, ids=lambda p: p.stem)
def test_cited_samples_and_tests_exist(page):
    missing = []
    for n, cells in rows(page):
        for name in CITED.findall(cells[-1]):
            if name not in SAMPLES and name not in TESTS and not name.endswith("_"):
                missing.append(f"{page.name}:{n}: {name}")
    assert not missing, "cited samples or tests that do not exist:\n" + "\n".join(missing)


@pytest.mark.parametrize("page", PAGES, ids=lambda p: p.stem)
def test_page_has_generated_markers(page):
    text = page.read_text(encoding="utf-8")
    for name in ("header", "missing"):
        assert f"<!-- generated:{name}" in text and f"<!-- /generated:{name} -->" in text, f"{page.name}: {name} markers"


def test_every_page_has_an_area():
    cat = json.loads((REPO / "isim" / "data" / "frameworks.json").read_text())
    known = {m for a in cat["areas"] for m in a["frameworks"]}
    assert not [p.stem for p in PAGES if p.stem not in known]


def test_coverage_md_markers():
    text = (REPO / "docs" / "COVERAGE.md").read_text(encoding="utf-8")
    for name in ("summary", "versions", "index", "out-of-scope", "objc"):
        assert f"<!-- generated:{name}" in text and f"<!-- /generated:{name} -->" in text, name
