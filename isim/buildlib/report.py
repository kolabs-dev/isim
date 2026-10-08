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
