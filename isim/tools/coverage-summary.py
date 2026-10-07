#!/usr/bin/env python3
"""Recomputes the summary tables of docs/COVERAGE.md from its section tables (run after editing rows).

Each `## Area` (and its `### Subarea`s) is counted: table rows whose Status column is ✅ 🟡 🧩 or ❌.
Coverage = (✅ + 0.5 × 🟡) / rows. The iOS column (the version that introduced the API: `≤17`, `18.0`, `26.0`,
`27.0`, ...) gives the per-version summary: a row counts toward iOS N when it was introduced at or before N.
Usage: tools/coverage-summary.py [path/to/COVERAGE.md] [--date YYYY-MM-DD]
"""
import datetime, os, re, sys

MARKS = ['✅', '🟡', '🧩', '❌']
VERSIONS = [17, 18, 26, 27]           # the iOS versions isim emulates (isim --os)


def introduced(cell):
    """major version a row was introduced in (≤17 and older releases count as 17); None if not a version"""
    m = re.match(r'^(≤|<=)?\s*(\d+)(\.\d+)*$', cell.strip())
    if not m:
        return None
    return max(17, int(m.group(2)))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    path = args[0] if args else os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'COVERAGE.md')
    date = sys.argv[sys.argv.index('--date') + 1] if '--date' in sys.argv else datetime.date.today().isoformat()
    lines = open(path, encoding='utf-8').read().split('\n')

    areas = []          # [name, counts, [[sub, counts], ...], {version: counts}]
    cur = sub = None
    for ln in lines:
        if ln.startswith('## '):
            name = ln[3:].strip()
            cur = None if name == 'Summary' else [name, [0] * 4, [], {v: [0] * 4 for v in VERSIONS}]
            if cur: areas.append(cur)
            sub = None
        elif ln.startswith('### ') and cur:
            sub = [ln[4:].strip(), [0] * 4]
            cur[2].append(sub)
        elif cur and ln.startswith('|'):
            cells = [c.strip() for c in ln.strip().strip('|').split('|')]
            if len(cells) >= 2 and cells[1] in MARKS:
                i = MARKS.index(cells[1])
                cur[1][i] += 1
                if sub: sub[1][i] += 1
                intro = introduced(cells[2]) if len(cells) >= 4 else 17
                if intro is None: intro = 17
                for v in VERSIONS:
                    if intro <= v: cur[3][v][i] += 1

    def pct(c):
        n = sum(c)
        return f'{round(100 * (c[0] + 0.5 * c[1]) / n)}%' if n else '–'

    def row(label, c, bold=False):
        vals = [str(x) for x in c] + [str(sum(c)), pct(c)]
        if bold: vals = [f'**{v}**' for v in vals]
        return f'| {label} | ' + ' | '.join(vals) + ' |'

    out = ['| Area | ✅ | 🟡 | 🧩 | ❌ | Rows | Coverage |', '|---|---:|---:|---:|---:|---:|---:|']
    total = [0] * 4
    vtotal = {v: [0] * 4 for v in VERSIONS}
    for name, c, subs, per in areas:
        total = [a + b for a, b in zip(total, c)]
        for v in VERSIONS: vtotal[v] = [a + b for a, b in zip(vtotal[v], per[v])]
        if subs:
            out.append(row(f'**{name}**', c))
            for sname, sc in subs:
                if sum(sc): out.append(row(f'&nbsp;&nbsp;↳ {sname}', sc))
        else:
            out.append(row(name, c))
    out.append(row('**All areas**', total, bold=True))

    # per-version table: coverage of the APIs each iOS version has (rows introduced at or before it)
    vout = ['| Area | ' + ' | '.join(f'iOS {v}' for v in VERSIONS) + ' |', '|---|' + '---:|' * len(VERSIONS)]
    for name, c, subs, per in areas:
        vout.append(f'| {name} | ' + ' | '.join(f'{pct(per[v])} ({sum(per[v])})' for v in VERSIONS) + ' |')
    vout.append('| **All areas** | ' + ' | '.join(f'**{pct(vtotal[v])}** ({sum(vtotal[v])})' for v in VERSIONS) + ' |')

    def replace_table(lines, start_heading, header_prefix, new):
        s = lines.index(start_heading)
        a = next(i for i in range(s, len(lines)) if lines[i].startswith(header_prefix))
        b = a
        while b < len(lines) and lines[b].startswith('|'): b += 1
        lines[a:b] = new

    replace_table(lines, '## Summary', '| Area | ✅', out)
    head = '### Per iOS version'
    if head not in lines:      # first run: add the per-version table right after the summary table
        s = lines.index('## Summary')
        a = next(i for i in range(s, len(lines)) if lines[i].startswith('| Area | ✅'))
        b = a
        while b < len(lines) and lines[b].startswith('|'): b += 1
        lines[b:b] = ['', head, '',
                      'Coverage of the APIs each version has: a row counts toward iOS N when it was introduced at or before N '
                      '(rows in parentheses).', '', vout[0]]
    replace_table(lines, head, '| Area | iOS', vout)
    lines = [f'Last updated: {date}' if l.startswith('Last updated:') else l for l in lines]
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print(f'{path}: {sum(total)} rows, {pct(total)} coverage')
    print('per iOS version: ' + ', '.join(f'iOS {v} {pct(vtotal[v])} ({sum(vtotal[v])} rows)' for v in VERSIONS))


if __name__ == '__main__':
    main()
