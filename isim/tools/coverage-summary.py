#!/usr/bin/env python3
"""Builds the generated parts of docs/COVERAGE.md and docs/frameworks/*.md (run after editing rows, before a release).

Inputs:
- docs/frameworks/<Module>.md: the hand-written rows (| API / feature | Status | iOS | Notes |), one page per framework;
- isim/data/frameworks.json: the areas, and the frameworks that are out of scope;
- isim/data/api-coverage.json.gz and isim/data/apple-api/apple-api.json.gz: Apple's iOS API and how much of it isim has
  (isim/tools/api-coverage.py).

Outputs, between `<!-- generated:NAME -->` and `<!-- /generated:NAME -->` markers only (the rest is hand-written):
- COVERAGE.md: the summary per area, the summary per iOS version, the framework index, the frameworks out of scope and
  the Objective-C interfaces;
- each framework page: its header line (symbol and row coverage) and its "Not yet in isim" list.

Row coverage = (✅ + 0.5 × 🟡) / rows; stubs (🧩), missing (❌) and blocked (⛔) rows count as zero. The iOS column (the
version that introduced the API: `≤17`, `18.0`, `26.0`, `27.1`, ...) gives the per-version summary: a row counts toward
iOS N when it was introduced at or before N.

Pull requests edit rows only; the Release workflow runs this (and api-coverage.py measure), so the generated parts do not
conflict between pull requests (AGENTS.md, "Coverage").
Usage: tools/coverage-summary.py [--check]   (--check: exit 1 when a generated part is out of date, write nothing)
"""
import glob
import gzip
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
DOCS = os.path.join(ROOT, 'docs')
PAGES = os.path.join(DOCS, 'frameworks')
DATA = os.path.join(ROOT, 'isim', 'data')
MARKS = ['✅', '🟡', '🧩', '❌', '⛔']
VERSIONS = [17, 18, 26, 27]
MISSING_LIST_MAX = 300           # symbols listed on a page (all of them: isim/data/api-coverage.json.gz)
ISSUES = 'https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3A'


def introduced(cell):
    """major version a row was introduced in (≤17 and older releases count as 17); None if not a version"""
    m = re.match(r'^(≤|<=)?\s*(\d+)(\.\d+)*$', cell.strip())
    return max(17, int(m.group(2))) if m else None


def parse_rows(text):
    """[(status, introduced version)] of the page's API tables"""
    rows = []
    for ln in text.split('\n'):
        if not ln.startswith('| '):
            continue
        cells = [c.strip() for c in ln.strip().strip('|').split('|')]
        if len(cells) >= 4 and cells[1] in MARKS:
            rows.append((cells[1], introduced(cells[2]) or 17))
    return rows


def counts(rows, upto=None):
    c = [0] * len(MARKS)
    for status, v in rows:
        if upto is None or v <= upto:
            c[MARKS.index(status)] += 1
    return c


def pct(c):
    n = sum(c)
    return f'{round(100 * (c[0] + 0.5 * c[1]) / n)}%' if n else '–'


def replace(text, name, body):
    pat = re.compile(r'(<!-- generated:%s\b[^>]*-->\n).*?(<!-- /generated:%s -->)' % (re.escape(name), re.escape(name)), re.S)
    if not pat.search(text):
        sys.exit(f'missing <!-- generated:{name} --> markers')
    return pat.sub(lambda m: m.group(1) + body.rstrip('\n') + '\n' + m.group(2), text)


def main():
    check = '--check' in sys.argv
    cat = json.load(open(os.path.join(DATA, 'frameworks.json')))
    cov_path = os.path.join(DATA, 'api-coverage.json.gz')
    cov = json.load(gzip.open(cov_path, 'rt', encoding='utf-8')) if os.path.exists(cov_path) else {'frameworks': {}}
    snap_path = os.path.join(DATA, 'apple-api', 'apple-api.json.gz')
    apple = json.load(gzip.open(snap_path, 'rt')) if os.path.exists(snap_path) else {'frameworks': {}}
    afw = apple.get('frameworks', {})
    fw_cov = cov.get('frameworks', {})
    pages = {os.path.basename(p)[:-3]: p for p in glob.glob(os.path.join(PAGES, '*.md')) if not os.path.basename(p).startswith('_')}
    texts = {k: open(p, encoding='utf-8').read() for k, p in pages.items()}
    rows = {k: parse_rows(t) for k, t in texts.items()}
    area_of = {m: a['key'] for a in cat['areas'] for m in a['frameworks']}
    out_of_scope = {**cat['deprecated'], **cat.get('impossible', {})}
    changed = []

    def write(path, old, new):
        if old != new:
            changed.append(os.path.relpath(path, ROOT))
            if not check:
                open(path, 'w', encoding='utf-8').write(new)

    # ---- framework pages
    for name, text in texts.items():
        c = counts(rows[name])
        f = fw_cov.get(name)
        parts = []
        if f and f.get('total'):
            kind = 'approximate, by name' if f.get('approximate') else 'exact'
            parts.append(f"**Symbols:** {f['coverage']}% of Apple's iOS API ({f['present']} of {f['total']}, {kind})")
        if sum(c):
            parts.append(f'**Rows:** {pct(c)} ({sum(c)}: ' + ' '.join(f'{n} {m}' for n, m in zip(c, MARKS) if n) + ')')
        if name in afw and afw[name].get('ios'):
            parts.append(f"**iOS:** {afw[name]['ios'][0]}+")
        header = ' · '.join(parts) or 'Not measured yet (isim/tools/api-coverage.py).'
        new = replace(text, 'header', header)
        missing = (f or {}).get('missing_symbols', [])
        if missing:
            lines = [f"{len(missing)} symbols Apple documents for iOS that isim does not have"
                     f" ({'measured by name, so a lower bound' if f.get('approximate') else 'exact'};"
                     f" Apple snapshot {apple.get('date', '?')}). Each links to Apple's documentation.", '',
                     '<details><summary>List</summary>', '']
            for path, title in missing[:MISSING_LIST_MAX]:
                lines.append(f'- [`{title}`](https://developer.apple.com{path})')
            if len(missing) > MISSING_LIST_MAX:
                lines.append(f'- … and {len(missing) - MISSING_LIST_MAX} more (`isim/data/api-coverage.json.gz`)')
            lines += ['', '</details>']
            body = '\n'.join(lines)
        else:
            body = 'Nothing (or not measured yet).'
        new = replace(new, 'missing', body)
        write(pages[name], text, new)

    # ---- COVERAGE.md
    path = os.path.join(DOCS, 'COVERAGE.md')
    text = open(path, encoding='utf-8').read()
    areas = cat['areas']

    def area_rows(a, upto=None):
        r = []
        for m in a['frameworks']:
            r += [x for x in rows.get(m, []) if upto is None or x[1] <= upto]
        return r

    def area_symbols(a):
        p = t = 0
        for m in a['frameworks']:
            f = fw_cov.get(m)
            if f and m not in out_of_scope:
                p += f['present']; t += f['total']
        return p, t

    def area_frameworks(a):
        inscope = [m for m in a['frameworks'] if m in afw and m not in out_of_scope]
        return sum(1 for m in inscope if fw_cov.get(m, {}).get('shipped') or m in pages), len(inscope)

    s = ['| Area | Symbols | Rows | ✅ | 🟡 | 🧩 | ❌ | ⛔ | Frameworks in isim |', '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    tp = tt = 0; tc = [0] * len(MARKS); tf = [0, 0]
    for a in areas:
        p, t = area_symbols(a); c = counts(area_rows(a)); f = area_frameworks(a)
        tp += p; tt += t; tc = [x + y for x, y in zip(tc, c)]; tf = [tf[0] + f[0], tf[1] + f[1]]
        sym = f'{round(100 * p / t)}%' if t else '–'
        s.append(f"| [{a['name']}](#{a['key']}) | {sym} | {pct(c)} | " + ' | '.join(map(str, c)) + f' | {f[0]} of {f[1]} |')
    s.append(f"| **All areas** | **{round(100 * tp / tt) if tt else 0}%** | **{pct(tc)}** | " + ' | '.join(f'**{x}**' for x in tc) +
             f' | **{tf[0]} of {tf[1]}** |')
    mode = cov.get('mode', 'not measured')
    s += ['', f"Symbols: {tp} of {tt} Apple iOS symbols in the frameworks isim has or tracks ({mode}"
          f"{'' if mode == 'exact' else ', a lower bound'}; isim {cov.get('commit', '?')}, Apple snapshot {apple.get('date', '?')})."]
    text = replace(text, 'summary', '\n'.join(s))

    v = ['| Area | ' + ' | '.join(f'iOS {x}' for x in VERSIONS) + ' |', '|---|' + '---:|' * len(VERSIONS)]
    for a in areas:
        v.append(f"| {a['name']} | " + ' | '.join(f'{pct(counts(area_rows(a), x))} ({len(area_rows(a, x))})' for x in VERSIONS) + ' |')
    allr = [r for a in areas for r in area_rows(a)]
    v.append('| **All areas** | ' + ' | '.join(f'**{pct(counts(allr, x))}** ({len([r for r in allr if r[1] <= x])})' for x in VERSIONS) + ' |')
    text = replace(text, 'versions', '\n'.join(v))

    idx = []
    for a in areas:
        idx += ['', f"### {a['name']}", '', f"<a id=\"{a['key']}\"></a>Issues: [`area:{a['key']}`]({ISSUES}{a['key']})", '',
                '| Framework | iOS | In isim | Symbols | Rows | Page |', '|---|---|---|---:|---:|---|']
        for m in sorted(a['frameworks'], key=str.lower):
            if m in out_of_scope or (m not in afw and m not in pages):
                continue
            f = fw_cov.get(m, {})
            ios = (afw.get(m, {}).get('ios') or ['–'])[0]
            have = '✅' if f.get('shipped') or (m in pages and rows.get(m)) else '❌'
            sym = f"{f['coverage']}%{'*' if f.get('approximate') else ''}" if f.get('total') else '–'
            r = pct(counts(rows.get(m, []))) if rows.get(m) else '–'
            title = afw.get(m, {}).get('title', m)
            link = f'[{m}](frameworks/{m}.md)' if m in pages else '–'
            idx.append(f"| [{title}](https://developer.apple.com/documentation/{afw.get(m, {}).get('id', m.lower())}) | {ios} | {have} | {sym} | {r} | {link} |")
        for m in sorted(x for x in pages if area_of.get(x) == a['key'] and x not in afw):
            idx.append(f'| {m} (isim topic) | – | ✅ | – | {pct(counts(rows[m]))} | [{m}](frameworks/{m}.md) |')
    idx += ['', '\\* measured by name (approximate): not built into isim yet, or measured without a built SDK.']
    text = replace(text, 'index', '\n'.join(idx))

    o = ['| Framework | Why |', '|---|---|']
    for m, why in sorted(out_of_scope.items(), key=lambda kv: kv[0].lower()):
        o.append(f'| {m} | {why} |')
    text = replace(text, 'out-of-scope', '\n'.join(o))

    oc = ['| Framework | Objective-C / C interface |', '|---|---|']
    for m in sorted((m for m, f in fw_cov.items() if f.get('shipped')), key=str.lower):
        oc.append(f"| {m} | {'✅ headers in isim/sdk-src/Frameworks/' + m if fw_cov[m].get('objc_interface') else '❌ Swift only'} |")
    text = replace(text, 'objc', '\n'.join(oc))
    write(path, open(path, encoding='utf-8').read(), text)

    if check:
        if changed:
            print('out of date: ' + ', '.join(changed))
            return 1
        print('generated parts are up to date')
        return 0
    print('updated: ' + (', '.join(changed) if changed else 'nothing'))
    return 0


if __name__ == '__main__':
    sys.exit(main())
