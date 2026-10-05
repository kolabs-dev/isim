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
        self.project = self.objects[data['rootObject']]
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
    def settings(self, configuration='Debug'):
        def config(list_id):
            for c in self.p.objects[list_id]['buildConfigurations']:
                if self.p.objects[c]['name'] == configuration:
                    return self.p.objects[c].get('buildSettings', {})
            return {}
        s = {
            'SRCROOT': self.p.root, 'PROJECT_DIR': self.p.root, 'TARGET_NAME': self.name,
            'PRODUCT_NAME': self.name, 'CONFIGURATION': configuration,
            'PROJECT_NAME': os.path.splitext(os.path.basename(self.p.xcodeproj))[0],
            'SDKROOT': 'iphoneos', 'DEVELOPMENT_LANGUAGE': 'en',
        }
        s.update(config(self.p.project['buildConfigurationList']))
        s.update(config(self.obj['buildConfigurationList']))
        expanded = {k: expand(v, s) for k, v in s.items()}
        expanded.setdefault('PRODUCT_MODULE_NAME', re.sub(r'[^A-Za-z0-9_]', '_', expanded['PRODUCT_NAME']))
        expanded.setdefault('EXECUTABLE_NAME', expanded['PRODUCT_NAME'])
        return expanded


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
