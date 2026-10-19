#!/usr/bin/env python3
"""Keeps isim's host runtime ready for other host operating systems (native Windows: issue #491).

  portability-check.py            check (the build in CI runs it; exit 1 on a new problem)
  portability-check.py --update   rewrite the baseline after removing Linux-only uses (it may only shrink)
  portability-check.py --list     print every remaining use and unmarked function (the port's checklist)

Two rules for the host code in isim/runtime (docs/BUILD.md, "Portability"):

1. Linux-only operating-system calls go through the platform layer (runtime/platform.h, implemented for Linux in
   runtime/platform_posix.c): spawning processes, opening things on the desktop, shared memory, the IPC pair, control
   FIFOs, the runtime's own path. Outside it, the calls below may not grow: a use that is not in the baseline
   (isim/data/portability-baseline.txt) fails the check. Backends that are Linux-only by design are listed whole.
   isim's own implementation of a Darwin API over Linux (libSystem's kqueue over epoll, say) is part of what a port
   reimplements anyway: such a line says so with a /* linux-only: why */ comment, which exempts it (--list shows it).
2. Every host function guest code calls (the entries of the symbol tables guests link against: libSystem, libobjc,
   libisim_host, ...) is marked ISIM_GUEST_ABI where it is defined: guest code uses the System V x86-64 calling
   convention, which a Windows host has to request per function (__attribute__((sysv_abi))). Exempt: passthrough
   entries (P(name)) and other host-library functions (a port wraps them), data symbols, and the hand-written
   assembly entry points (objc_msgSend...: System V already). A function a macro makes is marked in the macro.
"""
import argparse
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))     # isim/
RUNTIME = os.path.join(ROOT, 'runtime')
BASELINE = os.path.join(ROOT, 'data', 'portability-baseline.txt')
PLATFORM = {'platform_posix.c', 'platform.h'}
# backends that are Linux-only by design (a port replaces the whole file): not scanned for rule 1
LINUX_BACKENDS = {
    'isim-webkit.c': 'the WebKitGTK web-view helper (Windows: WebKit WinCairo)',
}

# rule 1: Linux-only calls and paths (pattern -> what to use instead)
LINUX_ONLY = {
    r'\bfork\s*\(': 'isim_spawn',
    r'\bvfork\s*\(': 'isim_spawn',
    r'\bposix_spawnp?\s*\(': 'isim_spawn',
    r'\bexec(l|lp|le|v|vp|ve|vpe)\s*\(': 'isim_spawn',
    r'\bprctl\s*\(': 'isim_spawn (die_with_parent)',
    r'\bmkfifo\s*\(': 'isim_ctl_create',
    r'\bsocketpair\s*\(': 'isim_ipc_pair',
    r'\bmemfd_create\s*\(': 'isim_shm_create',
    r'MAP_SHARED': 'isim_shm_map',
    r'"/proc/': 'the platform layer (isim_self_path, ...)',
    r'"/dev/(null|shm|urandom)': 'the platform layer',
    r'\bepoll_\w+\s*\(': 'the platform layer',
    r'\binotify_\w+\s*\(': 'the platform layer',
    r'\bSYS_futex\b': 'the platform layer',
    r'\bdlopen\s*\(\s*"lib[^"]*\.so': 'a library name table (per host OS)',
    r'xdg-open': 'isim_open_on_desktop',
}

# rule 2: the symbol tables' entry macros: NAME("symbol", function) or NAME(function)
TABLE_ENTRY = re.compile(r'\b(A|S|I|J)\(\s*"[^"]+"\s*,\s*([A-Za-z_]\w*)\s*\)|\bH\(\s*([A-Za-z_]\w*)\s*\)')


def sources():
    out = []
    for f in sorted(os.listdir(RUNTIME)):
        if f.endswith(('.c', '.inc', '.h')):
            out.append(f)
    return out


def strip_comments(text):
    """C comments and string contents removed, line structure kept (patterns that need strings look at raw text)"""
    text = re.sub(r'/\*.*?\*/', lambda m: '\n' * m.group(0).count('\n'), text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def linux_only_uses():
    """({(file, pattern): count} of rule 1, [(file, line number, reason)] of the linux-only: exemptions)"""
    uses, exempt = {}, []
    for f in sources():
        if f in PLATFORM or f in LINUX_BACKENDS:
            continue
        raw = open(os.path.join(RUNTIME, f), errors='replace').read().split('\n')
        code = strip_comments('\n'.join(raw)).split('\n')
        for i, line in enumerate(code):
            hits = [pat for pat in LINUX_ONLY if re.search(pat, line)]
            if not hits:
                continue
            m = re.search(r'linux-only:\s*([^*]*)', raw[i])
            if m:
                exempt.append((f, i + 1, m.group(1).strip()))
                continue
            for pat in hits:
                uses[(f, pat)] = uses.get((f, pat), 0) + len(re.findall(pat, line))
    return uses, exempt


def guest_functions():
    """(function, file of its table) for every non-passthrough function a symbol table hands to guests"""
    out = set()
    for f in sources():
        code = strip_comments(open(os.path.join(RUNTIME, f), errors='replace').read())
        code = re.sub(r'^\s*#\s*define[^\n]*', '', code, flags=re.M)          # the entry macros' own definitions
        for m in TABLE_ENTRY.finditer(code):
            fn = m.group(2) or m.group(3)
            if fn:
                out.add((fn, f))
    return sorted(out)


def definitions():
    """{function name: [(file, marked)]} for the function definitions and prototypes in the runtime (a line that starts
    one: no indentation, the name and its '(', then a body or a ';' after the parameter list); a Windows compiler
    rejects a prototype and a definition that disagree on the calling convention, so both are checked"""
    defs = {}
    head = re.compile(r'^(?!\s)(?!#)(?!typedef)(?!return)(?:__attribute__\(\(.*?\)\)\s*)*[^;(=]*?\b([A-Za-z_]\w*)\s*\(')
    for f in sources():
        text = strip_comments(open(os.path.join(RUNTIME, f), errors='replace').read())
        lines = text.split('\n')
        for i, line in enumerate(lines):
            m = head.match(line)
            if not m:
                continue
            rest = '\n'.join(lines[i:i + 12])
            brace, semi = rest.find('{'), rest.find(';')
            if semi >= 0 and (brace < 0 or semi < brace):
                if not re.match(r'^\s*\([^;]*\)\s*(__attribute__\(\(.*?\)\)\s*)*;', rest[rest.find('(', m.end(1)):]):
                    continue                                # a statement, not a prototype
            elif brace < 0:
                continue
            name = m.group(1)
            marked = 'ISIM_GUEST_ABI' in line or (i > 0 and lines[i - 1].strip().endswith('ISIM_GUEST_ABI'))
            defs.setdefault(name, []).append((f, marked))
    return defs


def macro_templates():
    """name patterns of the functions macros define with ISIM_GUEST_ABI (#define WCLS(n) ISIM_GUEST_ABI ... d_##n(...)"""
    pats = []
    for f in sources():
        for m in re.finditer(r'^\s*#\s*define\s+\w+\(([^)]*)\)([^\n]*)', open(os.path.join(RUNTIME, f), errors='replace').read(), re.M):
            params, body = [p.strip() for p in m.group(1).split(',')], m.group(2)
            if 'ISIM_GUEST_ABI' not in body:
                continue
            for d in re.finditer(r'\b([A-Za-z_][\w#]*##[\w#]*)\s*\(', body):
                tmpl = d.group(1)
                rx = re.escape(tmpl).replace('\\#\\#', '##')
                for p in params:
                    rx = rx.replace('##' + p + '##', r'\w+').replace('##' + p, r'\w+').replace(p + '##', r'\w+')
                pats.append(re.compile('^' + rx.replace('##', '') + '$'))
    return pats


def assembly_entries():
    """functions defined in assembly (.globl NAME in __asm__): the objc_msgSend family speaks System V already"""
    out = set()
    for f in sources():
        text = open(os.path.join(RUNTIME, f), errors='replace').read()
        out.update(re.findall(r'\.globl\s+(\w+)', text))
        out.update(re.findall(r'\bFORWARD\(\s*"(\w+)"', text))       # objc_rt.c: entry points an assembly macro makes
    return out


def data_symbols():
    """names declared as variables in the runtime (a table can hand guests data: tzname, _NSConcreteStackBlock...)"""
    out = set()
    for f in sources():
        code = strip_comments(open(os.path.join(RUNTIME, f), errors='replace').read())
        out.update(re.findall(r'^[A-Za-z_][\w\s\*]*?\b(\w+)\s*(?:\[[^\]]*\])*\s*(?:=|;)', code, re.M))
    return out


def unmarked_functions():
    """{(file of definition, 'unmarked:function'): 1} of rule 2; a function no definition, macro, assembly or data
    explains is listed under its table's file as 'unknown:function'"""
    defs, templates, asm, data = definitions(), macro_templates(), assembly_entries(), data_symbols()
    out = {}
    for fn, table in guest_functions():
        if fn in defs:
            for f, marked in defs[fn]:
                if not marked:
                    out[(f, 'unmarked:' + fn)] = 1
        elif fn in asm or fn in data or any(t.match(fn) for t in templates):
            continue
        elif not fn.startswith(('d_', 'rt_', 'isim_', 'objc_')):
            continue                                       # a host-library function (mktime, _Unwind_*): a port wraps it
        else:
            out[(table, 'unknown:' + fn)] = 1
    return out


def current():
    cur, _ = linux_only_uses()
    cur = dict(cur)
    cur.update(unmarked_functions())
    return cur


def read_baseline():
    base = {}
    if os.path.exists(BASELINE):
        for line in open(BASELINE):
            line = line.split('#', 1)[0].rstrip()
            if line:
                f, pat, n = line.split('\t')
                base[(f, pat)] = int(n)
    return base


def write_baseline(cur):
    with open(BASELINE, 'w') as out:
        out.write('# isim/tools/portability-check.py --update: what the host runtime still has that a non-Linux host\n'
                  '# has to replace (issue #491). It may only shrink: new code uses the platform layer and ISIM_GUEST_ABI\n'
                  '# (docs/BUILD.md, "Portability"). file<TAB>what<TAB>count\n')
        for (f, pat), n in sorted(cur.items()):
            out.write(f'{f}\t{pat}\t{n}\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--update', action='store_true', help='rewrite the baseline (refused if anything grew)')
    ap.add_argument('--list', action='store_true', help='print every remaining item')
    a = ap.parse_args()
    cur, base = current(), read_baseline()
    grew = [(k, n, base.get(k, 0)) for k, n in sorted(cur.items()) if n > base.get(k, 0)]
    shrank = [k for k in base if cur.get(k, 0) < base[k]]
    if a.list:
        for (f, pat), n in sorted(cur.items()):
            hint = LINUX_ONLY.get(pat, 'mark it ISIM_GUEST_ABI' if pat.startswith('unmarked:') else
                                  'define it with ISIM_GUEST_ABI (in the macro that makes it, if one does)')
            print(f'{f}\t{pat}\t{n}\t-> {hint}')
        for f, line, why in linux_only_uses()[1]:
            print(f'{f}:{line}\tlinux-only\t{why}')
        for f, why in sorted(LINUX_BACKENDS.items()):
            print(f'{f}\tLinux-only backend\t{why}')
        print(f'{sum(cur.values())} items')
        return 0
    if a.update and not os.path.exists(BASELINE):           # the first baseline: what the runtime has today
        write_baseline(cur)
        print(f'portability: baseline written ({sum(cur.values())} items)')
        return 0
    if grew:
        for (f, pat), n, was in grew:
            if pat.startswith(('unmarked:', 'unknown:')):
                print(f'portability: {f}: {pat.split(":", 1)[1]} is called by guest code: define it with ISIM_GUEST_ABI '
                      f'(runtime.h; docs/BUILD.md, "Portability")', file=sys.stderr)
            else:
                print(f'portability: {f}: {n} use(s) of {pat!r} (baseline {was}): use {LINUX_ONLY[pat]} '
                      f'(runtime/platform.h; docs/BUILD.md, "Portability")', file=sys.stderr)
        if a.update:
            print('portability: not updating the baseline: it may only shrink', file=sys.stderr)
        return 1
    if a.update:
        write_baseline(cur)
        print(f'portability: baseline rewritten ({sum(cur.values())} items)')
        return 0
    if shrank:
        print(f'portability: OK; the baseline can shrink ({len(shrank)} entries): isim/tools/portability-check.py --update')
    else:
        print(f'portability: OK ({sum(cur.values())} items left for other hosts)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
