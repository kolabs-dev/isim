"""Test results for CI: a Markdown summary (out/test-summary.md, shown on the workflow run's page) and a GitHub
error annotation per failed test (printed as a workflow command, so it links the failure to the test's source line)."""
import os
import re
import xml.etree.ElementTree as ET


def summarize(xml, log, out, repo):
    try:
        last = {}                       # a rerun test appears once per attempt: its last attempt is the result
        for c in ET.parse(xml).getroot().iter("testcase"):
            last[(c.get("classname"), c.get("name"))] = c
        cases = list(last.values())
    except (OSError, ET.ParseError):
        with open(out, "w") as f:
            f.write("## Tests\n\nNo results (the test run did not finish).\n")
        return
    rows, counts = [], {"passed": 0, "failed": 0, "skipped": 0}
    for c in cases:
        name = f"{c.get('file') or c.get('classname')}::{c.get('name')}"
        bad = c.find("failure") if c.find("failure") is not None else c.find("error")
        if bad is not None:
            counts["failed"] += 1
            msg = (bad.get("message") or "").splitlines()[0][:300] if bad.get("message") else ""
            rows.append((name, msg, float(c.get("time") or 0)))
            f, line = c.get("file"), c.get("line")
            if f:                       # workflow command: an annotation on the test's source line
                path = os.path.relpath(os.path.join(os.path.dirname(xml), "..", "tests", f), repo)
                print(f"::error file={path},line={int(line or 0) + 1},title={c.get('name')}::{msg.replace('%', '%25')}", flush=True)
        elif c.find("skipped") is not None:
            counts["skipped"] += 1
        else:
            counts["passed"] += 1
    try:
        text = open(log, errors="replace").read()
    except OSError:
        text = ""
    flaky = re.findall(r"^FLAKY \(passed on rerun\): (\S+)", text, re.M)
    slow = sorted(((float(c.get("time") or 0), f"{c.get('file') or c.get('classname')}::{c.get('name')}") for c in cases), reverse=True)[:10]
    icon = "✅" if not counts["failed"] else "❌"
    md = [f"## {icon} Tests: {counts['passed']} passed, {counts['failed']} failed, {counts['skipped']} skipped", ""]
    if rows:
        md += ["### Failed", "", "| Test | Error |", "|---|---|"]
        md += ["| `%s` | %s |" % (n, m.replace("|", "\\|")) for n, m, _ in rows] + [""]
    if flaky:
        md += ["### Flaky (passed on the retry)", ""] + [f"- `{f}`" for f in flaky] + [""]
    md += ["### Slowest", "", "| Test | Time |", "|---|---:|"] + [f"| `{n}` | {t:.0f} s |" for t, n in slow]
    with open(out, "w") as f:
        f.write("\n".join(md) + "\n")


def _results(xml):
    """{test name: ("passed" | "failed" | "skipped", message)} of a JUnit file (a rerun test: its last attempt)"""
    out = {}
    for c in ET.parse(xml).getroot().iter("testcase"):
        name = f"{c.get('file') or c.get('classname')}::{c.get('name')}"
        bad = c.find("failure") if c.find("failure") is not None else c.find("error")
        if bad is not None:
            msg = (bad.get("message") or "").splitlines()[0][:200] if bad.get("message") else ""
            out[name] = ("failed", msg)
        elif c.find("skipped") is not None:
            out[name] = ("skipped", "")
        else:
            out[name] = ("passed", "")
    return out


def matrix(versions, out):
    """One summary for the CI run's test jobs, one per iOS version. versions: {"17": junit xml path, ...}. Totals per
    version, the failures, then every test that ran under more than one version with its result in each."""
    res, missing = {}, []
    for v, path in versions.items():
        try:
            res[v] = _results(path)
        except (OSError, ET.ParseError):
            missing.append(v)
    icon = {"passed": "✅", "failed": "❌", "skipped": "⏭"}
    vs = list(versions)
    failed = any(r == "failed" for v in res for r, _ in res[v].values()) or missing
    md = [f"## {'❌' if failed else '✅'} Tests by iOS version", "",
          "| | " + " | ".join(f"iOS {v}" for v in vs) + " |", "|---|" + "---:|" * len(vs)]
    for kind in ("passed", "failed", "skipped"):
        md.append(f"| {icon[kind]} {kind} | " + " | ".join(
            "no results" if v in missing else str(sum(1 for r, _ in res[v].values() if r == kind)) for v in vs) + " |")
    md.append("")
    fails = [(v, n, m) for v in vs if v in res for n, (r, m) in sorted(res[v].items()) if r == "failed"]
    if fails or missing:
        md += ["### Failed", "", "| iOS | Test | Error |", "|---|---|---|"]
        md += [f"| {v} | (the test job did not finish) | |" for v in missing]
        md += ["| %s | `%s` | %s |" % (v, n, m.replace("|", "\\|")) for v, n, m in fails] + [""]
    names = sorted({n for v in res for n in res[v]})
    multi = [n for n in names if sum(n in res[v] for v in res) > 1]
    if multi:
        md += ["### Tests run under every version (os_matrix)", "", "| Test | " + " | ".join(f"iOS {v}" for v in vs) + " |",
               "|---|" + ":---:|" * len(vs)]
        md += ["| `%s` | %s |" % (n, " | ".join(icon[res[v][n][0]] if v in res and n in res[v] else "—" for v in vs)) for n in multi]
    with open(out, "w") as f:
        f.write("\n".join(md) + "\n")
    return 1 if failed else 0


if __name__ == "__main__":       # report.py matrix OUT.md 17=a.xml 18=b.xml ...
    import sys
    if sys.argv[1:2] == ["matrix"]:
        sys.exit(matrix(dict(a.split("=", 1) for a in sys.argv[3:]), sys.argv[2]) and 0)
