#!/usr/bin/env python3
"""Measures how much of Apple's iOS API isim's SDK has, against Apple's own documentation (docs/API-SWEEP.md).

  api-coverage.py snapshot [--modules M,...]   fetch Apple's documentation data into isim/data/apple-api/ (network)
  api-coverage.py measure [--sdk out/sdk]      compare it with isim -> isim/data/api-coverage.json.gz (no network)
  api-coverage.py updates                      Apple's per-release "updates" pages vs isim (network; a report)

measure has two modes. With a built SDK (--sdk, the default when isim/out/sdk exists) it is exact: every Swift module
of the SDK is read with swift-symbolgraph-extract (swift:6.2 image), which also gives the Swift view of the Objective-C
frameworks, and each Apple symbol is matched by its documentation path (DocC derives the path from the same path
components). Without one (--names) it falls back to names: an Apple symbol counts as present when its name occurs in
that framework's isim sources (a lower bound on what is missing).

In scope: symbols Apple documents for iOS that are usable in at least one of the iOS versions isim emulates (17, 18, 26,
27): not unavailable, and not deprecated at iOS 17 or earlier. Frameworks deprecated before iOS 17 are out of scope
(isim/data/frameworks.json).

Like abi-check.py this is a maintainer tool: pull requests do not run it; the Release workflow refreshes
isim/data/api-coverage.json.gz and the generated parts of docs/COVERAGE.md and docs/frameworks/ (coverage-summary.py).
"""
import concurrent.futures
import datetime
import glob
import gzip
import json
import os
import re
import ssl
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))     # isim/
REPO = os.path.dirname(ROOT)
DATA = os.path.join(ROOT, 'data')
SNAP = os.path.join(DATA, 'apple-api', 'apple-api.json.gz')
CATALOG = os.path.join(DATA, 'frameworks.json')
RESULT = os.path.join(DATA, 'api-coverage.json.gz')
BASE = 'https://developer.apple.com/tutorials/data'
VERSIONS = (17, 18, 26, 27)
TYPES = {'class', 'struct', 'enum', 'protocol', 'typealias', 'func', 'var', 'let', 'macro', 'actor', 'op', 'union'}
MEMBERS = {'property', 'method', 'case', 'subscript', 'associatedtype', 'init'}
# modules whose symbols Apple documents in an archive with another name
ARCHIVE = {'Intents': 'sirikit', 'IntentsUI': 'sirikit', 'Photos': 'photokit', 'PhotosUI': 'photokit'}
# modules isim implements inside another module
IMPLEMENTED_IN = {'AVFAudio': 'AVFoundation', 'CoreAudioTypes': 'AudioToolbox'}
# modules whose symbols are visible through another module (`import Foundation` gives FoundationEssentials' types)
ALSO = {'Foundation': ['FoundationEssentials'], 'CoreAudioTypes': ['_AudioToolboxTypes'],
        'Swift': ['_Concurrency', '_StringProcessing',          # implicitly imported with Swift
                  'Foundation', 'FoundationEssentials', 'Combine', 'Synchronization', 'Intents', 'AppIntents']}  # extensions Apple documents under Swift
BASE_MODULES = {'Foundation', 'Swift', 'ObjectiveC', 'Dispatch', 'Combine', 'os', 'simd', 'CoreGraphics', 'Observation'}


def reexports(module):
    """modules an overlay re-exports (`@_exported import X`), other than the base modules every overlay imports"""
    out = list(ALSO.get(module, []))
    for p in [f'{ROOT}/swift/overlays/{module}.swift'] + glob.glob(f'{ROOT}/swift/overlays/{module}/*.swift'):
        if os.path.isfile(p):
            out += [x for x in re.findall(r'^@_exported import (?:\w+ )?(\w+)', open(p, errors='ignore').read(), re.M)
                    if x not in BASE_MODULES]
    return sorted(set(out))


# Xcode's test frameworks: Apple's pages give no iOS platform for their symbols, so every symbol counts
XCODE = {'XCTest', 'Testing', 'XCUIAutomation'}


# ---------------------------------------------------------------- network
def _ctx():
    return ssl.create_default_context(cafile=os.environ.get('SSL_CERT_FILE'))


def fetch(path, ctx=None):
    """Apple's documentation JSON for /documentation/... or /index/... (None when Apple has no such page)"""
    url = BASE + urllib.parse.quote(path) + ('' if path.startswith('/index/') else '.json')
    for _ in range(3):
        try:
            with urllib.request.urlopen(url, context=ctx or _ctx(), timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except Exception:
            pass
    return None


def platforms_of(meta):
    """(introducedAt, deprecatedAt, unavailable, beta) for iOS from a page's metadata.platforms, or None"""
    for p in meta.get('platforms') or []:
        if p.get('name') == 'iOS':
            return [p.get('introducedAt'), p.get('deprecatedAt'), bool(p.get('unavailable')), bool(p.get('beta'))]
    return None


def version(v):
    try:
        parts = [int(x) for x in str(v).split('.')[:2]]
        return parts[0] + (parts[1] / 100 if len(parts) > 1 else 0)
    except ValueError:
        return None


def in_scope(av):
    """av: platforms_of() result. Usable in some emulated iOS version: introduced by the newest, not deprecated by 17."""
    if not av or av[2]:
        return False
    intro, dep = version(av[0]), version(av[1]) if av[1] else None
    if intro is not None and intro >= VERSIONS[-1] + 1:
        return False
    return dep is None or dep >= VERSIONS[0] + 1


# ---------------------------------------------------------------- snapshot
def walk_index(tree, module):
    """symbols of one module from Apple's navigator index: (path, title, kind, owner path, deprecated-somewhere)"""
    prefix = f'/documentation/{module.lower()}/'
    out = []

    def walk(node, owner):
        for c in node.get('children', []):
            p, t = c.get('path'), c.get('type')
            if c.get('external'):
                continue
            mine = bool(p) and p.startswith(prefix)
            if mine and (t in TYPES or t in MEMBERS):
                out.append([p, c.get('title', ''), t, owner, 1 if c.get('deprecated') else 0])
                walk(c, p if t in TYPES else owner)
            else:
                walk(c, owner)      # collections, group markers and other archives' nodes (SiriKit, PhotoKit)
    for root in tree:
        walk(root, None)
    return out


def snapshot(args):
    ctx = _ctx()
    cat = json.load(open(CATALOG))
    tech = fetch('/documentation/technologies', ctx)
    ids = sorted({t['destination']['identifier'].split('/documentation/')[-1]
                  for g in tech['sections'][0]['groups'] for t in g['technologies']})
    ids = [i for i in ids if '/' not in i]
    frameworks = {}
    with concurrent.futures.ThreadPoolExecutor(16) as ex:
        for i, d in zip(ids, ex.map(lambda i: fetch(f'/documentation/{i.lower()}', ctx), ids)):
            if not d:
                continue
            m = d.get('metadata', {})
            av = platforms_of(m)
            if not av:
                continue                          # not an iOS framework
            mods = [x.get('name') for x in m.get('modules') or [] if x.get('name')]
            name = cat['aliases'].get(i.lower()) or re.sub(r'[^A-Za-z0-9]', '', mods[0] if mods else m.get('title', i))
            frameworks[name] = {'id': i.lower(), 'title': m.get('title', name), 'ios': av}
    for name, archive in cat['extra_modules'].items():        # modules documented inside another archive
        parent = next((v for v in frameworks.values() if v['id'] == archive), None)
        if parent:
            frameworks[name] = {'id': archive, 'title': name, 'ios': parent['ios']}
        else:                                                    # its own archive, missing from the technology list
            d = fetch(f'/documentation/{archive}', ctx)
            if d:       # Vision and simd list no platforms on their root page; XCTest & co. list Xcode
                frameworks[name] = {'id': archive, 'title': d['metadata'].get('title', name),
                                    'ios': platforms_of(d.get('metadata', {})) or [None, None, False, False]}
    wanted = set(args.modules.split(',')) if args.modules else set(frameworks)
    old = load_snapshot() if os.path.exists(SNAP) else {'symbols': {}, 'availability': {}}
    frameworks = {**old.get('frameworks', {}), **frameworks} if args.modules else frameworks
    symbols = {k: v for k, v in old.get('symbols', {}).items() if k not in wanted}
    cache = {}
    for name in sorted(wanted & set(frameworks)):
        archive = ARCHIVE.get(name, name.lower())
        if archive not in cache:
            cache[archive] = fetch(f'/index/{archive}', ctx)
        idx = cache[archive]
        if not idx:
            print(f'no index: {name}', file=sys.stderr)
            continue
        tree = idx['interfaceLanguages'].get('swift') or idx['interfaceLanguages'].get('occ') or []
        symbols[name] = walk_index(tree, name)
    snap = {'date': datetime.date.today().isoformat(), 'source': BASE, 'frameworks': frameworks,
            'symbols': symbols, 'availability': old.get('availability', {})}
    save_snapshot(snap)
    print(f'{len(frameworks)} iOS frameworks, {sum(len(v) for v in symbols.values())} symbols -> {os.path.relpath(SNAP, REPO)}')


def load_snapshot():
    with gzip.open(SNAP, 'rt', encoding='utf-8') as f:
        return json.load(f)


def save_snapshot(snap):
    os.makedirs(os.path.dirname(SNAP), exist_ok=True)
    with gzip.open(SNAP, 'wt', encoding='utf-8', compresslevel=9) as f:
        json.dump(snap, f, separators=(',', ':'), sort_keys=True)


def fill_availability(snap, paths):
    """per-symbol iOS availability (cached in the snapshot) for the given doc paths; fetches what is missing"""
    av = snap.setdefault('availability', {})
    todo = [p for p in paths if p not in av]
    if not todo:
        return av
    print(f'fetching availability of {len(todo)} symbols…', file=sys.stderr)
    ctx = _ctx()

    def one(p):
        d = fetch(p, ctx)
        return p, (platforms_of(d.get('metadata', {})) if d else None) or 0
    with concurrent.futures.ThreadPoolExecutor(48) as ex:
        for p, a in ex.map(one, todo):
            av[p] = a
    save_snapshot(snap)
    return av


# ---------------------------------------------------------------- isim's side
KW = re.compile(r'^(?:(?:class|static|var|let|func|case|subscript|macro|typealias|mutating|nonisolated|convenience|'
                r'required|override|final|actor|struct|enum|protocol|associatedtype|indirect|optional|dynamic|'
                r'consuming|borrowing|prefix|postfix|infix|operator)\s+)+')


def base_name(title):
    t = KW.sub('', title.strip()).lstrip('@#')
    if t.startswith(('init', 'subscript')):
        return ''
    t = re.split(r'[(:<\s]', t)[0]
    return t.split('.')[-1].replace('`', '')


# where isim's sources for a module live when it is not swift/overlays/<M>, sdk-src/Frameworks/<M>, frameworks/<M>
SOURCES = {'QuartzCore': ['frameworks/UIKit', 'sdk-src/Frameworks/UIKit'], 'ObjectiveC': ['runtime', 'sdk-src/usr/include/objc'],
           'Dispatch': ['frameworks/Foundation', 'sdk-src/usr/include/dispatch'], 'os': ['runtime', 'sdk-src/usr/include/os'],
           'Swift': ['../third_party/swift/stdlib/public', 'swift/overlays'],
           'Observation': ['../third_party/swift/stdlib/public/Observation'],
           'Synchronization': ['../third_party/swift/stdlib/public/Synchronization'],
           'Distributed': ['../third_party/swift/stdlib/public/Distributed'],
           'RegexBuilder': ['../third_party/swift-experimental-string-processing/Sources/RegexBuilder'],
           'Testing': ['../third_party/swift-testing/Sources/Testing']}


def source_words(module):
    m = IMPLEMENTED_IN.get(module, module)
    paths = [f'{ROOT}/swift/overlays/{m}', f'{ROOT}/swift/overlays/{m}.swift', f'{ROOT}/sdk-src/Frameworks/{m}',
             f'{ROOT}/frameworks/{m}'] + [os.path.join(ROOT, p) for p in SOURCES.get(m, [])] + \
        (glob.glob(f'{ROOT}/swift/overlays/UIKit+*.swift') if m == 'UIKit' else [])
    words = set()
    for p in paths:
        files = [p] if os.path.isfile(p) else [os.path.join(d, f) for d, _, fs in os.walk(p) for f in fs] if os.path.isdir(p) else []
        for f in files:
            if f.endswith(('.swift', '.h', '.m', '.mm', '.c', '.inc', '.swiftinterface')):
                words |= set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*', open(f, errors='ignore').read()))
    return words


def norm_component(c):
    """a documentation path component without DocC's disambiguation suffix (-swift.struct, -1a2b3, -6qo3n)"""
    c = re.sub(r'-swift\.[a-z.]+$', '', c)
    c = re.sub(r'-[0-9a-z]{4,6}$', '', c) if re.search(r'-[0-9a-z]{4,6}$', c) and re.search(r'\d', c.rsplit('-', 1)[1]) else c
    return c


def doc_key(path, module):
    parts = path[len(f'/documentation/{module.lower()}/'):].split('/')
    return '/'.join(norm_component(p) for p in parts)


def member_name(component):
    """a member's base name, without signature, with operators spelled the way DocC writes them in paths ('+=' is '_=')"""
    c = component.lower().lstrip("'")
    name = re.split(r'[(]', c)[0] or c
    if not re.match(r'^[a-z_]', name):                     # an operator
        name = re.sub(r'[+\-*/%&|^~?]', '_', name)
    return re.split(r'<', name)[0] or name


def sdk_modules(sdk):
    mods = set()
    for d in glob.glob(f'{sdk}/usr/lib/swift/*.swiftmodule'):
        mods.add(os.path.basename(d)[:-len('.swiftmodule')])
    for d in glob.glob(f'{sdk}/System/Library/Frameworks/*.framework'):
        mods.add(os.path.basename(d)[:-len('.framework')])
    return mods


def extract_symbol_graphs(sdk, modules, outdir):
    """swift-symbolgraph-extract for each module (swift:6.2 image, like isim swiftc); returns {module: set of keys}"""
    os.makedirs(outdir, exist_ok=True)
    sdk = os.path.abspath(sdk)
    out_root = os.path.dirname(sdk)                          # isim/out
    keys = {}
    for m in sorted(modules):
        d = os.path.join(outdir, m)
        os.makedirs(d, exist_ok=True)
        if not glob.glob(f'{d}/*.symbols.json'):
            cmd = ['docker', 'run', '--rm', '-u', f'{os.getuid()}:{os.getgid()}', '-e', 'HOME=/tmp',
                   '-v', f'{REPO}:{REPO}', '-w', REPO, 'swift:6.2', 'swift-symbolgraph-extract',
                   '-target', 'x86_64-apple-ios27.0-simulator', '-sdk', sdk, '-resource-dir', f'{out_root}/swift/resource',
                   '-I', f'{sdk}/usr/lib/swift', '-F', f'{sdk}/System/Library/Frameworks',
                   '-module-name', m, '-minimum-access-level', 'public', '-output-dir', d]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0:
                print(f'symbol graph of {m} failed: {r.stderr.strip()[:300]}', file=sys.stderr)
        s = set()
        for f in glob.glob(f'{d}/*.symbols.json'):
            g = json.load(open(f))
            usr = {}
            for sym in g.get('symbols', []):
                pc = sym.get('pathComponents') or []
                if pc:
                    path = '/'.join(pc).lower()
                    usr[sym['identifier']['precise']] = path
                    s.add(path)
                    s.add('~' + '/'.join([*pc[:-1], re.split(r'[(<]', pc[-1])[0]]).lower())   # without signature
                    if len(pc) > 1:
                        MEMBERS_OF.setdefault('/'.join(pc[:-1]).lower(), set()).add(member_name(pc[-1]))
            for r in g.get('relationships', []):
                if r.get('kind') in ('inheritsFrom', 'conformsTo'):
                    src = usr.get(r['source'])
                    dst = usr.get(r['target']) or (r.get('targetFallback') or '').split('.')[-1].lower()
                    if src and dst:
                        PARENTS.setdefault(src, set()).add(dst)
        keys[m] = s
    return keys


MEMBERS_OF = {}      # type path -> member names, over every symbol graph read (for inherited members)
PARENTS = {}         # type path -> superclass and protocol paths


def inherits(owner, name, seen=None):
    """whether type `owner` (a lowercase path) or one of its ancestors declares a member called `name`"""
    seen = seen or set()
    if owner in seen:
        return False
    seen.add(owner)
    if name in MEMBERS_OF.get(owner, ()):
        return True
    return any(inherits(p, name, seen) for p in PARENTS.get(owner, ()))


# ---------------------------------------------------------------- measure
def measure(args):
    snap = load_snapshot()
    cat = json.load(open(CATALOG))
    sdk = args.sdk or (os.path.join(ROOT, 'out', 'sdk') if os.path.isdir(os.path.join(ROOT, 'out', 'sdk')) else None)
    mode = 'names' if args.names or not sdk else 'exact'
    shipped = sdk_modules(sdk) if sdk else {os.path.splitext(x)[0] for x in os.listdir(f'{ROOT}/swift/overlays')} | \
        set(os.listdir(f'{ROOT}/sdk-src/Frameworks')) | set(os.listdir(f'{ROOT}/frameworks'))
    objc = set(os.listdir(f'{ROOT}/sdk-src/Frameworks'))
    targets = {m for m in snap['symbols'] if m in shipped and m not in IMPLEMENTED_IN}
    targets |= {IMPLEMENTED_IN[m] for m in snap['symbols'] if m in IMPLEMENTED_IN}
    targets |= {x for m in list(targets) for x in reexports(m) if x in shipped or x.startswith('_') or x == 'FoundationEssentials'}
    graphs = extract_symbol_graphs(sdk, sorted(targets), os.path.join(ROOT, 'out', 'symbolgraph')) if mode == 'exact' else {}
    present, candidates = {}, {}
    for m, syms in snap['symbols'].items():
        if m in cat['deprecated']:
            continue
        impl = IMPLEMENTED_IN.get(m, m)
        have = impl in shipped
        words = source_words(m) if (have and mode == 'names') else set()
        keys = graphs.get(impl, set()) | graphs.get(m, set())
        for x in reexports(impl):
            keys = keys | graphs.get(x, set())
        p, cand = [], []
        for path, title, kind, owner, dep in syms:
            if kind == 'init' and mode == 'names':
                continue
            ok = False
            if have:
                if mode == 'exact':
                    k = doc_key(path, m)
                    ok = k in keys or ('~' + re.split(r'[(<]', k)[0]) in keys
                    if not ok and '/' in k:
                        # a member the type inherits: Apple documents protocol default implementations and
                        # superclass members on each type, the symbol graph declares them once (walk the
                        # inheritsFrom / conformsTo relationships)
                        own, last = k.rsplit('/', 1)
                        ok = (own in keys or ('~' + own) in keys) and inherits(own, member_name(last))
                else:
                    b = base_name(title)
                    ok = bool(b) and b in words
            (p if ok else cand).append(path)
        present[m], candidates[m] = p, cand
    av = fill_availability(snap, [x for m in candidates for x in candidates[m]
                                  if IMPLEMENTED_IN.get(m, m) in shipped]) if not args.offline else snap.get('availability', {})
    result = {'date': datetime.date.today().isoformat(), 'apple_snapshot': snap['date'], 'mode': mode,
              'commit': subprocess.run(['git', '-C', REPO, 'rev-parse', '--short', 'HEAD'], capture_output=True, text=True).stdout.strip(),
              'frameworks': {}}
    for m in sorted(present):
        impl = IMPLEMENTED_IN.get(m, m)
        have = impl in shipped
        titles = {s[0]: s[1] for s in snap['symbols'][m]}
        if have:
            missing = [x for x in candidates[m] if in_scope(av.get(x)) or (m in XCODE and not av.get(x) and x in av)]
            unknown = [x for x in candidates[m] if x not in av]
        else:      # not in isim: every symbol Apple does not flag as deprecated (availability not fetched)
            missing = [s[0] for s in snap['symbols'][m] if not s[4] and (mode == 'exact' or s[2] != 'init')]
            unknown = []
        n_present = len(present[m])
        total = n_present + len(missing)
        result['frameworks'][m] = {
            'shipped': have, 'objc_interface': impl in objc, 'present': n_present, 'missing': len(missing),
            'total': total, 'coverage': round(100 * n_present / total, 1) if total else None,
            'approximate': not have or mode == 'names', 'unchecked': len(unknown),
            'missing_symbols': sorted([[x, titles.get(x, '')] for x in missing]) if have else [],
        }
    with gzip.open(RESULT, 'wt', encoding='utf-8', compresslevel=9) as f:
        json.dump(result, f, indent=0, sort_keys=True, ensure_ascii=False)
    shipped_fw = [v for v in result['frameworks'].values() if v['shipped']]
    tp, tt = sum(v['present'] for v in shipped_fw), sum(v['total'] for v in shipped_fw)
    print(f'{mode}: {len(shipped_fw)} frameworks in isim, {tp} of {tt} Apple symbols ({100 * tp / max(tt, 1):.1f}%) '
          f'-> {os.path.relpath(RESULT, REPO)}')
    for m, v in sorted(result['frameworks'].items(), key=lambda kv: -kv[1]['missing']):
        if v['shipped']:
            print(f"  {m:28} {v['present']:6} / {v['total']:6}  {v['coverage']}%")


# ---------------------------------------------------------------- updates
def updates(args):
    ctx = _ctx()
    upd = fetch('/documentation/updates', ctx)
    fws = [i.split('/')[-1] for s in upd['topicSections'] if s['title'] == 'Technology and frameworks' for i in s['identifiers']]
    month = re.compile(r'^(January|February|March|April|May|June|July|August|September|October|November|December) \d{4}$')

    def text(x):
        return x.get('text', '') + ''.join(text(y) for y in x.get('inlineContent', []))

    def walk(content, refs, cur, out):
        for x in content:
            if x.get('type') == 'heading' and month.match(text(x)):
                cur[0] = text(x)
            if x.get('type') == 'reference' and refs.get(x.get('identifier'), {}).get('kind') == 'symbol':
                r = refs[x['identifier']]
                out.append((cur[0], r.get('url'), r.get('title')))
            for k in ('inlineContent', 'content', 'items'):
                if isinstance(x.get(k), list):
                    walk(x[k], refs, cur, out)
            for col in x.get('columns', []) if x.get('type') == 'row' else []:
                walk(col.get('content', []), refs, cur, out)
    rows = []
    for fw in fws:
        d = fetch('/documentation/updates/' + fw.lower(), ctx)
        out = []
        for sec in (d or {}).get('primaryContentSections', []):
            walk(sec.get('content', []), d['references'], [None], out)
        rows += [(fw, *o) for o in out]
    res = json.load(gzip.open(RESULT, 'rt', encoding='utf-8'))
    missing = {x for v in res['frameworks'].values() for x, _ in v['missing_symbols']}
    for fw, rel, url, title in rows:
        if url in missing:
            print(f'{rel or "?":16} {fw:24} {title}  https://developer.apple.com{url}')


def main():
    import argparse
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('snapshot'); s.add_argument('--modules')
    m = sub.add_parser('measure'); m.add_argument('--sdk'); m.add_argument('--names', action='store_true')
    m.add_argument('--offline', action='store_true', help='do not fetch availability (unknown symbols are skipped)')
    sub.add_parser('updates')
    a = ap.parse_args()
    {'snapshot': snapshot, 'measure': measure, 'updates': updates}[a.cmd](a)


if __name__ == '__main__':
    main()
