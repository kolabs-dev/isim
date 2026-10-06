"""Minimal reader for Xcode projects (project.pbxproj, OpenStep plist format).

Resolves native targets, their build phases (sources, resources, frameworks, copy-files),
file references with group paths, target dependencies, and merged build settings
(project config -> target config) with $(VAR) / ${VAR} expansion.
"""
import os
import re


class PBXParseError(Exception):
    pass


def parse_openstep(text):
    """Parse an OpenStep (ASCII) property list into Python dicts/lists/strings."""
    i, n = 0, len(text)

    def skip():
        nonlocal i
        while i < n:
            c = text[i]
            if c in ' \t\r\n':
                i += 1
            elif text.startswith('/*', i):
                j = text.find('*/', i + 2)
                i = n if j < 0 else j + 2
            elif text.startswith('//', i):
                j = text.find('\n', i)
                i = n if j < 0 else j + 1
            else:
                return

    def string():
        nonlocal i
        if text[i] == '"':
            i += 1
            out = []
            while i < n and text[i] != '"':
                if text[i] == '\\':
                    i += 1
                    esc = text[i]
                    out.append({'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}.get(esc, esc))
                else:
                    out.append(text[i])
                i += 1
            i += 1
            return ''.join(out)
        m = re.compile(r'[A-Za-z0-9_$+./:\-]+').match(text, i)
        if not m:
            raise PBXParseError(f'unexpected character {text[i]!r} at {i}')
        i = m.end()
        return m.group(0)

    def value():
        nonlocal i
        skip()
        c = text[i]
        if c == '{':
            i += 1
            d = {}
            while True:
                skip()
                if text[i] == '}':
                    i += 1
                    return d
                k = string()
                skip()
                if text[i] != '=':
                    raise PBXParseError(f'expected = at {i}')
                i += 1
                d[k] = value()
                skip()
                if text[i] == ';':
                    i += 1
        if c == '(':
            i += 1
            arr = []
            while True:
                skip()
                if text[i] == ')':
                    i += 1
                    return arr
                arr.append(value())
                skip()
                if text[i] == ',':
                    i += 1
        return string()

    if text.startswith('// !$*UTF8*$!'):
        i = text.index('\n') + 1
    return value()


SOURCE_EXTS = ('.swift', '.m', '.mm', '.c', '.cpp', '.cc')
HEADER_EXTS = ('.h', '.hpp', '.pch', '.modulemap')
FOLDER_RESOURCE_EXTS = ('.xcassets', '.lproj', '.bundle', '.scnassets', '.spriteatlas', '.xcdatamodeld', '.storyboard', '.xib')
# files Xcode does not copy into the product from a synchronized folder
NON_RESOURCE_EXTS = ('.entitlements', '.xcconfig', '.storekit', '.xctestplan', '.docc')


class Project:
    def __init__(self, xcodeproj):
        self.xcodeproj = os.path.abspath(xcodeproj)
        self.root = os.path.dirname(self.xcodeproj)          # $(SRCROOT)
        with open(os.path.join(self.xcodeproj, 'project.pbxproj'), encoding='utf-8') as f:
            data = parse_openstep(f.read())
        self.objects = data['objects']
        self.project_id = data["rootObject"]
        self.project = self.objects[self.project_id]
        self._parents = {}
        self._index_groups(self.project['mainGroup'], None)

    # ---- file references and groups ----
    def _index_groups(self, gid, parent):
        self._parents[gid] = parent
        for child in self.objects[gid].get('children', []):
            obj = self.objects.get(child, {})
            self._parents[child] = gid
            if obj.get('isa') in ('PBXGroup', 'PBXVariantGroup', 'XCVersionGroup', 'PBXFileSystemSynchronizedRootGroup'):
                self._index_groups(child, gid)

    def path_of(self, ref):
        """Absolute path of a PBXFileReference/group (handles <group>, SOURCE_ROOT, absolute)."""
        obj = self.objects[ref]
        tree = obj.get('sourceTree', '<group>')
        path = obj.get('path', '')
        if tree == '<absolute>':
            return path
        if tree == 'SOURCE_ROOT':
            return os.path.normpath(os.path.join(self.root, path))
        if tree in ('BUILT_PRODUCTS_DIR', 'SDKROOT', 'DEVELOPER_DIR'):
            return '$(' + tree + ')/' + path
        parent = self._parents.get(ref)
        base = self.root if parent is None else self.path_of(parent)
        return os.path.normpath(os.path.join(base, path)) if path else base

    def configuration(self, list_id, name):
        confs = [self.objects[c] for c in self.objects[list_id]['buildConfigurations']]
        for c in confs:
            if c['name'] == name:
                return c
        default = self.objects[list_id].get('defaultConfigurationName')
        return next((c for c in confs if c['name'] == default), confs[0] if confs else {})

    def configurations(self):
        return [self.objects[c]['name'] for c in self.objects[self.project['buildConfigurationList']]['buildConfigurations']]

    def product_owner(self, ref):
        """Name of the target in this project whose productReference is ref (or None)."""
        for t in self.project['targets']:
            if self.objects[t].get('productReference') == ref:
                return self.objects[t]['name']
        return None

    # ---- targets ----
    def targets(self):
        return {self.objects[t]['name']: t for t in self.project['targets']}

    def target(self, name):
        return Target(self, self.targets()[name])


class Target:
    def __init__(self, project, tid):
        self.p = project
        self.id = tid
        self.obj = project.objects[tid]
        self.name = self.obj['name']
        self.product_type = self.obj.get('productType', '')

    def phases(self, isa):
        return [self.p.objects[ph] for ph in self.obj.get('buildPhases', []) if self.p.objects[ph]['isa'] == isa]

    def _files(self, phase):
        out = []
        for bf in phase.get('files', []):
            b = self.p.objects[bf]
            ref = b.get('fileRef') or b.get('productRef')
            if ref:
                out.append((ref, b))
        return out

    def sources(self):
        out = [self.p.path_of(ref) for ph in self.phases('PBXSourcesBuildPhase') for ref, _ in self._files(ph)]
        return out + [f for f in self.synchronized_files() if f.endswith(SOURCE_EXTS)]

    def synchronized_files(self):
        """Files of Xcode 16 folder-synchronized groups that belong to this target (membership exceptions
        removed). Bundle-like folders (.xcassets, .lproj, .bundle, ...) count as one file."""
        out = []
        for gid in self.obj.get('fileSystemSynchronizedGroups', []):
            root = self.p.path_of(gid)
            excluded = set()
            for ex in self.p.objects[gid].get('exceptions', []):
                e = self.p.objects[ex]
                if e.get('isa') == 'PBXFileSystemSynchronizedBuildFileExceptionSet' and e.get('target') == self.id:
                    excluded.update(os.path.normpath(os.path.join(root, m)) for m in e.get('membershipExceptions', []))
            for dirpath, dirnames, filenames in os.walk(root):
                keep = []
                for d in sorted(dirnames):
                    full = os.path.join(dirpath, d)
                    if d.startswith('.') or full in excluded:
                        continue
                    if d.endswith(FOLDER_RESOURCE_EXTS):
                        out.append(full)
                    else:
                        keep.append(d)
                dirnames[:] = keep
                for f in sorted(filenames):
                    full = os.path.join(dirpath, f)
                    if not f.startswith('.') and full not in excluded and not f.endswith(NON_RESOURCE_EXTS):
                        out.append(full)
        return out

    def package_products(self):
        """Swift package products this target depends on: [(product name, package reference object or None)]."""
        out = []
        for pid in self.obj.get('packageProductDependencies', []):
            dep = self.p.objects[pid]
            ref = dep.get('package')
            out.append((dep.get('productName'), self.p.objects[ref] if ref else None))
        return out

    def resources(self):
        out = []
        for ph in self.phases('PBXResourcesBuildPhase'):
            for ref, _ in self._files(ph):
                obj = self.p.objects[ref]
                if obj['isa'] == 'PBXVariantGroup':     # localized resources: one child per language
                    for child in obj.get('children', []):
                        out.append(self.p.path_of(child))
                else:
                    out.append(self.p.path_of(ref))
        return out + [f for f in self.synchronized_files() if not f.endswith(SOURCE_EXTS + HEADER_EXTS)]

    def frameworks(self):
        names = []
        for ph in self.phases('PBXFrameworksBuildPhase'):
            for ref, _ in self._files(ph):
                obj = self.p.objects[ref]
                names.append(obj.get('name') or os.path.basename(obj.get('path', '')))
        return names

    def embedded(self):
        """Products copied by copy-files phases: [(dstSubfolderSpec, target name or path)]."""
        out = []
        for ph in self.phases('PBXCopyFilesBuildPhase'):
            for ref, _ in self._files(ph):
                for tname, tid in self.p.targets().items():
                    if self.p.objects[tid].get('productReference') == ref:
                        out.append((ph.get('dstSubfolderSpec'), tname))
        return out

    def dependencies(self):
        out = []
        for d in self.obj.get('dependencies', []):
            t = self.p.objects[d].get('target')
            if t:
                out.append(self.p.objects[t]['name'])
        return out

    # ---- build settings ----
    def settings(self, configuration='Debug', defaults=None, overrides=None):
        """Merged build settings, Xcode order: defaults < project xcconfig < project < target xcconfig < target
        < overrides (command line). $(inherited) refers to the level below; KEY[sdk=...][config=...] conditions apply."""
        base = {
            'SRCROOT': self.p.root, 'PROJECT_DIR': self.p.root, 'TARGET_NAME': self.name,
            'PRODUCT_NAME': self.name, 'CONFIGURATION': configuration,
            'PROJECT_NAME': os.path.splitext(os.path.basename(self.p.xcodeproj))[0],
            'PROJECT_FILE_PATH': self.p.xcodeproj,
            'SDKROOT': 'iphoneos', 'DEVELOPMENT_LANGUAGE': 'en',
            'PLATFORM_NAME': 'iphonesimulator', 'EFFECTIVE_PLATFORM_NAME': '-iphonesimulator',
            'ARCHS': 'x86_64', 'CURRENT_ARCH': 'x86_64', 'NATIVE_ARCH': 'x86_64',
            'PRODUCT_TYPE': self.product_type,
        }
        base.update(defaults or {})
        levels = [base]
        for list_id in (self.p.project['buildConfigurationList'], self.obj['buildConfigurationList']):
            conf = self.p.configuration(list_id, configuration)
            ref = conf.get('baseConfigurationReference')
            if ref:
                levels.append(parse_xcconfig(self.p.path_of(ref)))
            levels.append(conf.get('buildSettings', {}))
        levels.append(overrides or {})
        s = merge_levels(levels, configuration)
        expanded = {k: expand(v, s) for k, v in s.items()}
        expanded.setdefault('PRODUCT_MODULE_NAME', re.sub(r'[^A-Za-z0-9_]', '_', expanded['PRODUCT_NAME']))
        expanded.setdefault('EXECUTABLE_NAME', expanded['PRODUCT_NAME'])
        return expanded

    # ---- more build phases ----
    def headers(self):
        """PBXHeadersBuildPhase: [(path, 'public'|'private'|'project')]."""
        out = []
        for ph in self.phases('PBXHeadersBuildPhase'):
            for ref, b in self._files(ph):
                attrs = [a.lower() for a in b.get('settings', {}).get('ATTRIBUTES', [])]
                vis = 'public' if 'public' in attrs else 'private' if 'private' in attrs else 'project'
                out.append((self.p.path_of(ref), vis))
        return out

    def link_items(self):
        """Frameworks phase entries: dicts with kind 'product' (built by a target in this project), 'built'
        (a BUILT_PRODUCTS_DIR file made elsewhere, e.g. another project of the workspace), 'package',
        'sdk' (SDK framework or library) or 'file' (a framework/library/xcframework in the source tree)."""
        out = []
        for ph in self.phases('PBXFrameworksBuildPhase'):
            for bf in ph.get('files', []):
                b = self.p.objects[bf]
                weak = 'Weak' in b.get('settings', {}).get('ATTRIBUTES', [])
                if b.get('productRef'):
                    out.append({'kind': 'package', 'name': self.p.objects[b['productRef']].get('productName'), 'weak': weak})
                    continue
                ref = b.get('fileRef')
                if not ref:
                    continue
                obj = self.p.objects[ref]
                name = obj.get('name') or os.path.basename(obj.get('path', ''))
                owner = self.p.product_owner(ref)
                if owner:
                    out.append({'kind': 'product', 'name': os.path.basename(obj.get('path', name)), 'target': owner, 'weak': weak})
                elif obj.get('isa') == 'PBXReferenceProxy' or obj.get('sourceTree') == 'BUILT_PRODUCTS_DIR':
                    out.append({'kind': 'built', 'name': os.path.basename(obj.get('path', name)), 'weak': weak})
                elif obj.get('sourceTree') == 'SDKROOT' or (obj.get('sourceTree') == '<group>' and obj.get('path', '').startswith('System/')):
                    out.append({'kind': 'sdk', 'name': os.path.basename(obj.get('path', name)), 'weak': weak})
                else:
                    out.append({'kind': 'file', 'name': name, 'path': self.p.path_of(ref), 'weak': weak})
        return out

    def copy_phases(self):
        """PBXCopyFilesBuildPhase: [(dstSubfolderSpec, dstPath, [('target', name) | ('file', path)])]."""
        out = []
        for ph in self.phases('PBXCopyFilesBuildPhase'):
            items = []
            for ref, _ in self._files(ph):
                owner = self.p.product_owner(ref)
                obj = self.p.objects[ref]
                if owner:
                    items.append(('target', owner))
                elif obj.get('isa') == 'PBXReferenceProxy' or obj.get('sourceTree') == 'BUILT_PRODUCTS_DIR':
                    items.append(('built', os.path.basename(obj.get('path', ''))))
                else:
                    items.append(('file', self.p.path_of(ref)))
            out.append((str(ph.get('dstSubfolderSpec', '')), ph.get('dstPath', ''), items))
        return out

    def script_phases(self):
        return [{'name': ph.get('name', 'Run Script'), 'shell': ph.get('shellPath', '/bin/sh'), 'script': ph.get('shellScript', ''),
                 'inputs': ph.get('inputPaths', []), 'outputs': ph.get('outputPaths', [])}
                for ph in self.phases('PBXShellScriptBuildPhase')]


def _match_conditions(conds, configuration):
    import fnmatch
    for k, v in conds:
        if k == 'sdk' and not (fnmatch.fnmatch('iphonesimulator', v) or fnmatch.fnmatch('iphonesimulator17.0', v)):
            return False
        if k == 'arch' and not fnmatch.fnmatch('x86_64', v):
            return False
        if k == 'config' and not fnmatch.fnmatch(configuration, v):
            return False
        if k not in ('sdk', 'arch', 'config'):
            return False
    return True


def setting_str(v):
    if isinstance(v, list):
        return ' '.join(f'"{x}"' if (' ' in x and not x.startswith('"')) else x for x in v)
    return v


def merge_levels(levels, configuration):
    """Applies setting levels in order; $(inherited) / ${inherited} expands to the value of the level below."""
    env = {}
    for level in levels:
        plain, cond = [], []
        for k, v in level.items():
            m = re.match(r'^([A-Za-z0-9_]+)((?:\[[^\]]*\])*)$', k)
            if not m:
                continue
            conds = re.findall(r'\[([a-z]+)=([^\]]*)\]', m.group(2))
            (cond if conds else plain).append((m.group(1), conds, v))
        for name, conds, v in plain + cond:
            if conds and not _match_conditions(conds, configuration):
                continue
            v = setting_str(v)
            if isinstance(v, str) and 'inherited' in v:
                v = re.sub(r'\$[({]inherited[)}]', lambda _m: str(env.get(name, '')), v).strip()
            env[name] = v
    return env


def parse_xcconfig(path, seen=None):
    """.xcconfig -> {KEY or KEY[cond]: value}; #include / #include? are followed (relative to the file)."""
    seen = seen or set()
    out = {}
    path = os.path.normpath(path)
    if path in seen or not os.path.exists(path):
        return out
    seen.add(path)
    with open(path, encoding='utf-8') as f:
        lines = f.read().splitlines()
    for line in lines:
        line = line.strip()
        m = re.match(r'#include(\?)?\s+"([^"]+)"', line)
        if m:
            inc = m.group(2)
            inc = inc if os.path.isabs(inc) else os.path.join(os.path.dirname(path), inc)
            if not os.path.exists(inc) and not m.group(1):
                print(f'isim build: warning: {path}: #include "{m.group(2)}" not found', flush=True)
            # an included file is a level below the including file: its values are inherited
            for k, v in parse_xcconfig(inc, seen).items():
                out[k] = v.replace('$(inherited)', out.get(k, '$(inherited)')) if isinstance(v, str) else v
            continue
        if not line or line.startswith('//'):
            continue
        # strip trailing // comments (not inside a URL-like value with "://")
        line = re.sub(r'(?<!:)//.*$', '', line).strip()
        m = re.match(r'^([A-Za-z0-9_]+(?:\[[^\]]*\])*)\s*=\s*(.*?);?$', line)
        if m:
            k, v = m.group(1), m.group(2).strip()
            out[k] = v.replace('$(inherited)', out[k]) if k in out and '$(inherited)' in v else v
    return out


def expand(value, settings, depth=0):
    """Expand $(VAR), ${VAR}, $(VAR:rfc1034identifier)-style references (recursive)."""
    if isinstance(value, list):
        return [expand(v, settings, depth) for v in value]
    if not isinstance(value, str) or depth > 8 or '$' not in value:
        return value

    def repl(m):
        name, _, mod = m.group(1).partition(':')
        v = settings.get(name, '')
        v = expand(v, settings, depth + 1) if isinstance(v, str) else ' '.join(v)
        if mod in ('rfc1034identifier', 'identifier'):
            v = re.sub(r'[^A-Za-z0-9.\-]' if mod == 'rfc1034identifier' else r'[^A-Za-z0-9_]', '-' if mod == 'rfc1034identifier' else '_', v)
        return v
    return re.sub(r'\$[({]([A-Za-z0-9_:]+)[)}]', repl, value)


# ---------------- cross-project dependencies, workspaces and schemes ----------------
def cross_dependencies(target):
    """Target dependencies on targets of other projects (PBXContainerItemProxy into a referenced .xcodeproj):
    [(absolute .xcodeproj path, target name)]."""
    out = []
    p = target.p
    for d in target.obj.get('dependencies', []):
        dep = p.objects[d]
        if dep.get('target'):
            continue
        proxy = p.objects.get(dep.get('targetProxy', ''), {})
        portal = proxy.get('containerPortal')
        if portal and portal != p.project_id and portal in p.objects and proxy.get('remoteInfo'):
            out.append((p.path_of(portal), proxy['remoteInfo']))
    return out


class Workspace:
    """An .xcworkspace (contents.xcworkspacedata): its projects, in order."""
    def __init__(self, path):
        import xml.etree.ElementTree as ET
        self.path = os.path.abspath(path)
        self.root = os.path.dirname(self.path)
        self.projects = []
        tree = ET.parse(os.path.join(self.path, 'contents.xcworkspacedata')).getroot()

        def walk(node, base):
            for child in node:
                loc = child.get('location', '')
                kind, _, rel = loc.partition(':')
                if kind == 'container':
                    full = os.path.normpath(os.path.join(self.root, rel))
                elif kind == 'absolute':
                    full = rel
                elif kind == 'self':
                    full = self.path
                else:                                  # group: relative to the enclosing group
                    full = os.path.normpath(os.path.join(base, rel))
                if child.tag == 'Group':
                    walk(child, full)
                elif child.tag == 'FileRef' and full.endswith('.xcodeproj') and os.path.isdir(full):
                    self.projects.append(full)
        walk(tree, self.root)


def scheme_files(containers):
    """Shared and user schemes of .xcodeproj/.xcworkspace containers: {scheme name: (path, container)}."""
    import glob
    out = {}
    for c in containers:
        for f in sorted(glob.glob(os.path.join(c, 'xcshareddata', 'xcschemes', '*.xcscheme')) +
                        glob.glob(os.path.join(c, 'xcuserdata', '*', 'xcschemes', '*.xcscheme'))):
            out.setdefault(os.path.splitext(os.path.basename(f))[0], (f, c))
    return out


class Scheme:
    """An .xcscheme: build entries, testables (with skipped/selected tests), launch/test environment and arguments."""
    def __init__(self, path, container):
        import xml.etree.ElementTree as ET
        self.path = path
        self.name = os.path.splitext(os.path.basename(path))[0]
        self.root = ET.parse(path).getroot()
        self.container_dir = os.path.dirname(os.path.abspath(container))   # "container:" paths resolve here

    def _ref(self, br):
        kind, _, rel = br.get('ReferencedContainer', '').partition(':')
        proj = os.path.normpath(os.path.join(self.container_dir, rel)) if kind == 'container' else None
        return {'target': br.get('BlueprintName'), 'project': proj, 'product': br.get('BuildableName')}

    def build_targets(self):
        out = []
        ba = self.root.find('BuildAction')
        if ba is not None:
            for e in ba.iter('BuildActionEntry'):
                br = e.find('BuildableReference')
                if br is not None:
                    r = self._ref(br)
                    r['for_running'] = e.get('buildForRunning', 'YES') == 'YES'
                    r['for_testing'] = e.get('buildForTesting', 'YES') == 'YES'
                    out.append(r)
        return out

    def testables(self):
        out = []
        ta = self.root.find('TestAction')
        if ta is None:
            return out
        for t in ta.iter('TestableReference'):
            if t.get('skipped', 'NO') == 'YES':
                continue
            br = t.find('BuildableReference')
            if br is None:
                continue
            r = self._ref(br)
            sk, sel = t.find('SkippedTests'), t.find('SelectedTests')
            r['skipped_tests'] = [s.get('Identifier') for s in sk] if sk is not None else []
            r['selected_tests'] = [s.get('Identifier') for s in sel] if sel is not None else []
            out.append(r)
        return out

    def configuration(self, action):
        a = self.root.find(action)
        return a.get('buildConfiguration', 'Debug') if a is not None else 'Debug'

    def _env_args(self, action):
        a = self.root.find(action)
        env, args = {}, []
        if a is None:
            return env, args
        for e in a.iter('EnvironmentVariable'):
            if e.get('isEnabled', 'YES') == 'YES':
                env[e.get('key')] = e.get('value', '')
        for e in a.iter('CommandLineArgument'):
            if e.get('isEnabled', 'YES') == 'YES':
                args.append(e.get('argument', ''))
        return env, args

    def test_environment(self):
        env, args = self._env_args('TestAction')
        ta = self.root.find('TestAction')
        if ta is not None and ta.get('shouldUseLaunchSchemeArgsEnv', 'YES') == 'YES':
            lenv, largs = self._env_args('LaunchAction')
            lenv.update(env)
            return lenv, largs + args
        return env, args
