#!/usr/bin/env python3
"""Recomputes the summary table of docs/COVERAGE.md from its section tables (run after editing rows).

Each `## Area` (and its `### Subarea`s) is counted: table rows whose Status column is ✅ 🟡 🧩 or ❌.
Coverage = (✅ + 0.5 × 🟡) / rows. Usage: tools/coverage-summary.py [path/to/COVERAGE.md] [--date YYYY-MM-DD]
"""
import datetime, os, re, sys

MARKS = ['✅', '🟡', '🧩', '❌']

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    path = args[0] if args else os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'COVERAGE.md')
    date = sys.argv[sys.argv.index('--date') + 1] if '--date' in sys.argv else datetime.date.today().isoformat()
    lines = open(path, encoding='utf-8').read().split('\n')

    areas = []          # [name, counts, [[sub, counts], ...]]
    cur = sub = None
    for ln in lines:
        if ln.startswith('## '):
            name = ln[3:].strip()
            cur = None if name == 'Summary' else [name, [0] * 4, []]
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

    def row(label, c, bold=False):
        n = sum(c)
        pct = f'{round(100 * (c[0] + 0.5 * c[1]) / n)}%' if n else '–'
        vals = [str(x) for x in c] + [str(n), pct]
        if bold: vals = [f'**{v}**' for v in vals]
        return f'| {label} | ' + ' | '.join(vals) + ' |'

    out = ['| Area | ✅ | 🟡 | 🧩 | ❌ | Rows | Coverage |', '|---|---:|---:|---:|---:|---:|---:|']
    total = [0] * 4
    for name, c, subs in areas:
        total = [a + b for a, b in zip(total, c)]
        if subs:
            out.append(row(f'**{name}**', c))
            for sname, sc in subs:
                if sum(sc): out.append(row(f'&nbsp;&nbsp;↳ {sname}', sc))
        else:
            out.append(row(name, c))
    out.append(row('**All areas**', total, bold=True))

    # replace the table under "## Summary"
    s = lines.index('## Summary')
    a = next(i for i in range(s, len(lines)) if lines[i].startswith('| Area |'))
    b = a
    while b < len(lines) and lines[b].startswith('|'): b += 1
    lines[a:b] = out
    lines = [f'Last updated: {date}' if l.startswith('Last updated:') else l for l in lines]
    open(path, 'w', encoding='utf-8').write('\n'.join(lines))
    print(f'{path}: {sum(total)} rows, {round(100 * (total[0] + 0.5 * total[1]) / sum(total))}% coverage')

if __name__ == '__main__':
    main()
