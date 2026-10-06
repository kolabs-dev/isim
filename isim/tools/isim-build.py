#!/usr/bin/env python3
"""isim build: build an Xcode project's iOS targets for the isim simulator, on Linux.

  isim build -project App.xcodeproj [-target NAME | -scheme NAME] [-configuration Debug] [-o OUTDIR]

What it does per target (dependencies first):
  * compiles Swift sources with `isim swiftc` (whole-module) and C/ObjC sources with `isim cc`
  * links the executable (apps: MH_EXECUTE; app extensions: entry point _NSExtensionMain)
  * Info.plist: expands $(VARS) from build settings, applies INFOPLIST_KEY_*, sets MinimumOSVersion
  * resources: .xcstrings -> <lang>.lproj/<Table>.strings, .strings/.lproj copied,
    .xcassets -> <bundle>/isim-assets.json + images (isim's asset format; NOT Apple's Assets.car),
    .xcprivacy and other files copied
  * embeds app extensions into <App>.app/PlugIns/
  * Swift packages: local packages are built from source (targets as modules, manifest read with
    `swift package dump-package`); remote packages are NOT fetched -- a remote product builds only
    if isim ships a declared stand-in for it (usr/share/isim/package-standins.json), and the log says so

It never writes Xcode/SDK identity keys (DTXcode, DTSDKName, ...): products are honest isim builds.
"""
import argparse
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from xcodeproj import Project, expand  # noqa: E402

BIN = os.path.dirname(os.path.realpath(__file__))
ISIM = os.path.join(BIN, 'isim')
SDK = os.environ.get('ISIM_SDK') or os.path.normpath(os.path.join(BIN, '..', 'sdk'))


def log(msg):
    print(f'isim build: {msg}', flush=True)


def run(cmd, **kw):
    r = subprocess.run(cmd, **kw)
    if r.returncode:
        sys.exit(f'isim build: command failed ({r.returncode}): {" ".join(cmd[:6])} ...')


# ---------------- resources ----------------
def compile_xcstrings(path, bundle):
    """String catalog -> <lang>.lproj/<table>.strings (stringUnit values; plural variations use 'other')."""
    table = os.path.splitext(os.path.basename(path))[0]
    with open(path, encoding='utf-8') as f:
        cat = json.load(f)
    source = cat.get('sourceLanguage', 'en')
    per_lang = {}
    for key, entry in cat.get('strings', {}).items():
        locs = entry.get('localizations', {})
        if source not in locs:
            per_lang.setdefault(source, {})[key] = key        # source text is the key itself
        for lang, loc in locs.items():
            unit = loc.get('stringUnit')
            if not unit:
                plural = loc.get('variations', {}).get('plural', {})
                unit = (plural.get('other') or {}).get('stringUnit')
            if unit and unit.get('value') is not None:
                per_lang.setdefault(lang, {})[key] = unit['value']
    def esc(s):
        return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
    for lang, strings in per_lang.items():
        d = os.path.join(bundle, f'{lang}.lproj')
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f'{table}.strings'), 'w', encoding='utf-8') as f:
            for k, v in sorted(strings.items()):
                f.write(f'"{esc(k)}" = "{esc(v)}";\n')
    return sorted(per_lang)


def compile_xcassets(path, bundle):
    """Asset catalog -> isim-assets.json (+ copied image files). Colors keep light/dark variants."""
    index_path = os.path.join(bundle, 'isim-assets.json')
    index = {'colors': {}, 'images': {}, 'appIcons': {}}
    if os.path.exists(index_path):
        with open(index_path) as f:
            index = json.load(f)
    outdir = os.path.join(bundle, 'isim-assets')
    for dirpath, dirnames, _ in os.walk(path):
        for d in dirnames:
            name, kind = os.path.splitext(d)
            full = os.path.join(dirpath, d)
            contents = os.path.join(full, 'Contents.json')
            if not os.path.exists(contents):
                continue
            with open(contents) as f:
                meta = json.load(f)
            if kind == '.colorset':
                variants = {}
                for c in meta.get('colors', []):
                    appearance = 'any'
                    for a in c.get('appearances', []):
                        if a.get('appearance') == 'luminosity':
                            appearance = a.get('value')
                    comps = c.get('color', {}).get('components', {})
                    def comp(k, default='1'):
                        v = str(comps.get(k, default))
                        return int(v, 16) / 255 if v.startswith('0x') else (float(v) / 255 if float(v) > 1 else float(v))
                    variants[appearance] = [comp('red', '0'), comp('green', '0'), comp('blue', '0'), comp('alpha')]
                index['colors'][name] = variants
            elif kind in ('.imageset', '.appiconset'):
                files = []
                for img in meta.get('images', []):
                    fn = img.get('filename')
                    if not fn:
                        continue
                    os.makedirs(outdir, exist_ok=True)
                    dst = f'{name}-{fn}'
                    shutil.copy2(os.path.join(full, fn), os.path.join(outdir, dst))
                    appearance = next((a.get('value') for a in img.get('appearances', []) if a.get('appearance') == 'luminosity'), 'any')
                    entry = {'file': f'isim-assets/{dst}', 'scale': img.get('scale', '1x'),
                             'idiom': img.get('idiom', 'universal'), 'appearance': appearance}
                    if img.get('size'):
                        entry['size'] = img['size']
                    if meta.get('properties', {}).get('template-rendering-intent') == 'template':
                        entry['templateRendering'] = True
                    files.append(entry)
                index['appIcons' if kind == '.appiconset' else 'images'][name] = files
                # images in a sprite atlas (Foo.spriteatlas/bar.imageset): SKTextureAtlas(named: "Foo") lists them
                atlas = os.path.basename(dirpath)
                if kind == '.imageset' and atlas.endswith('.spriteatlas'):
                    names = index.setdefault('atlases', {}).setdefault(atlas[:-len('.spriteatlas')], [])
                    if name not in names:
                        names.append(name)
    with open(index_path, 'w') as f:
        json.dump(index, f, indent=1, sort_keys=True)
    # the runtime (UIImage imageNamed:, UIColor colorNamed:, the home screen) reads the plist form
    with open(os.path.join(bundle, 'isim-assets.plist'), 'wb') as f:
        plistlib.dump(json.loads(json.dumps(index)), f, fmt=plistlib.FMT_XML)
    return index


def copy_resource(path, bundle):
    if os.path.isdir(path):
        dst = os.path.join(bundle, os.path.basename(path))
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(path, dst)
    else:
        # localized variant-group children live in <lang>.lproj/
        parent = os.path.basename(os.path.dirname(path))
        dst_dir = os.path.join(bundle, parent) if parent.endswith('.lproj') else bundle
        os.makedirs(dst_dir, exist_ok=True)
        shutil.copy2(path, dst_dir)


# ---------------- Swift packages ----------------
def dump_package(path, cache_dir):
    """Package.swift -> manifest JSON (evaluated by SwiftPM in the swift:6.2 container; cached)."""
    os.makedirs(cache_dir, exist_ok=True)
    cache = os.path.join(cache_dir, re.sub(r'[^A-Za-z0-9]', '_', path) + '.json')
    manifest = os.path.join(path, 'Package.swift')
    if os.path.exists(cache) and os.path.getmtime(cache) >= os.path.getmtime(manifest):
        with open(cache) as f:
            return json.load(f)
    r = subprocess.run(['docker', 'run', '--rm', '-u', f'{os.getuid()}:{os.getgid()}', '-e', 'HOME=/tmp',
                        '--mount', f'type=bind,src={path},dst={path},readonly', '-w', '/tmp', 'swift:6.2',
                        'swift', 'package', '--package-path', path, '--scratch-path', '/tmp/spm', 'dump-package'],
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(f'isim build: cannot read {manifest}:\n{r.stderr}')
    with open(cache, 'w') as f:
        f.write(r.stdout)
    return json.loads(r.stdout)


def load_standins():
    path = os.path.join(SDK, 'usr', 'share', 'isim', 'package-standins.json')
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return {k.lower().rstrip('/').removesuffix('.git'): v for k, v in json.load(f).items()}


def build_package_product(project, product, ref, objdir, built):
    """Builds a package product's targets as Swift modules into objdir/modules. Returns object files."""
    isa = ref.get('isa') if ref else 'XCLocalSwiftPackageReference'
    if isa == 'XCRemoteSwiftPackageReference':
        url = ref.get('repositoryURL', '').lower().rstrip('/').removesuffix('.git')
        standin = load_standins().get(url)
        if not standin or product not in standin.get('products', {}):
            sys.exit(f'isim build: remote package product {product!r} ({ref.get("repositoryURL")}) is not available: '
                     'isim does not fetch or run binary SDKs, and has no stand-in for it')
        log(f'{product}: isim stand-in ({standin.get("kind", "stub")}): {standin.get("note", "")}')
        return []
    if ref is None:                                 # product of a local package: find the package that has it
        refs = [project.objects[r] for r in project.project.get('packageReferences', [])
                if project.objects[r].get('isa') == 'XCLocalSwiftPackageReference']
    else:
        refs = [ref]
    for r in refs:
        pkg_path = os.path.normpath(os.path.join(project.root, r.get('relativePath', '')))
        m = dump_package(pkg_path, os.path.join(objdir, '..', 'packages'))
        prod = next((p for p in m.get('products', []) if p['name'] == product), None)
        if not prod:
            continue
        version = m.get('toolsVersion', {}).get('_version', '5.9')
        swift_version = '6' if int(version.split('.')[0]) >= 6 else '5'
        targets = {t['name']: t for t in m.get('targets', [])}
        objs = []

        def build(tname):
            if tname in built:
                return
            built[tname] = True
            t = targets[tname]
            for d in t.get('dependencies', []):
                name = (d.get('byName') or d.get('target') or [None])[0]
                if name in targets:
                    build(name)
                elif d.get('product'):
                    sys.exit(f'isim build: {tname}: dependencies on other packages are not supported yet')
            if t.get('resources'):
                log(f'{tname}: package resources are not copied yet (Bundle.module unavailable)')
            src = os.path.join(pkg_path, t.get('path') or os.path.join('Sources', tname))
            files = sorted(os.path.join(dp, f) for dp, _, fs in os.walk(src) for f in fs if f.endswith('.swift'))
            if not files:
                sys.exit(f'isim build: {tname}: only Swift package targets are supported so far')
            mdir = os.path.join(objdir, 'modules')
            os.makedirs(mdir, exist_ok=True)
            obj = os.path.join(objdir, f'pkg-{tname}.o')
            log(f'{product}: package target {tname} ({len(files)} Swift files)')
            run([ISIM, 'swiftc', '-parse-as-library', '-module-name', tname, '-swift-version', swift_version,
                 '-D', 'SWIFT_PACKAGE', '-I', mdir, '-emit-module', '-emit-module-path', os.path.join(mdir, tname + '.swiftmodule'),
                 '-wmo', '-c', '-o', obj] + files)
            objs.append(obj)
        for tname in prod['targets']:
            build(tname)
        return objs
    sys.exit(f'isim build: package product {product!r} not found in the local packages')


# ---------------- schemes ----------------
def storekit_configuration(project, target_name):
    """The StoreKit configuration file the target's scheme uses for local testing (Xcode: Run > Options)."""
    import glob, xml.etree.ElementTree as ET
    xp = project.xcodeproj
    for scheme in sorted(glob.glob(os.path.join(xp, 'xcshareddata', 'xcschemes', '*.xcscheme')) +
                         glob.glob(os.path.join(xp, 'xcuserdata', '*', 'xcschemes', '*.xcscheme'))):
        try:
            root = ET.parse(scheme).getroot()
        except ET.ParseError:
            continue
        launch = root.find('LaunchAction')
        if launch is None:
            continue
        names = [b.get('BlueprintName') for b in launch.iter('BuildableReference')]
        ref = launch.find('StoreKitConfigurationFileReference')
        if target_name not in names or ref is None:
            continue
        ident = ref.get('identifier', '')
        for base in (os.path.join(xp, 'xcshareddata'), os.path.dirname(scheme), xp, os.path.dirname(xp)):
            cand = os.path.normpath(os.path.join(base, ident))
            if os.path.isfile(cand):
                return cand
    return None


# ---------------- Info.plist ----------------
def make_info_plist(target, settings, bundle, extra_localizations):
    src = settings.get('INFOPLIST_FILE')
    info = {}
    if src:
        with open(os.path.join(target.p.root, src), 'rb') as f:
            info = plistlib.load(f)
    elif settings.get('GENERATE_INFOPLIST_FILE') != 'YES':
        sys.exit(f'isim build: {target.name}: no INFOPLIST_FILE')

    def exp(v):
        if isinstance(v, str):
            return expand(v, settings)
        if isinstance(v, list):
            return [exp(x) for x in v]
        if isinstance(v, dict):
            return {k: exp(x) for k, x in v.items()}
        return v
    info = exp(info)
    for k, v in settings.items():          # INFOPLIST_KEY_<Key> build settings (Xcode 13+)
        if k.startswith('INFOPLIST_KEY_'):
            key = k[len('INFOPLIST_KEY_'):]
            # device-specific keys: Xcode writes UISupportedInterfaceOrientations_iPhone as ..~iphone
            for suffix, plist in (('_iPhone', '~iphone'), ('_iPad', '~ipad')):
                if key.endswith(suffix): key = key[:-len(suffix)] + plist
            if key.startswith('UISupportedInterfaceOrientations') and isinstance(v, str):
                v = v.split()                # a space-separated list in build settings, an array in Info.plist
            info.setdefault(key, {'YES': True, 'NO': False}.get(v, v) if isinstance(v, str) else v)
    info.setdefault('CFBundleExecutable', settings['EXECUTABLE_NAME'])
    info.setdefault('CFBundleIdentifier', settings.get('PRODUCT_BUNDLE_IDENTIFIER', ''))
    info.setdefault('CFBundleName', settings['PRODUCT_NAME'])
    info.setdefault('CFBundleInfoDictionaryVersion', '6.0')
    info['MinimumOSVersion'] = settings.get('IPHONEOS_DEPLOYMENT_TARGET', '15.0')
    info['CFBundleSupportedPlatforms'] = ['iPhoneSimulator']
    if 'TARGETED_DEVICE_FAMILY' in settings:
        info['UIDeviceFamily'] = [int(x) for x in str(settings['TARGETED_DEVICE_FAMILY']).split(',') if x.strip()]
    if settings.get('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'):
        info['ISIMGlobalAccentColorName'] = settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME']   # isim-private key
    if extra_localizations and 'CFBundleLocalizations' not in info:
        info['CFBundleLocalizations'] = sorted(extra_localizations)
    info['ISIMBuild'] = {'tool': 'isim build', 'configuration': settings['CONFIGURATION'],
                         'note': 'Built on Linux by isim with a self-authored SDK; not an Xcode build.'}
    with open(os.path.join(bundle, 'Info.plist'), 'wb') as f:
        plistlib.dump(info, f)
    return info


# ---------------- targets ----------------
def build_target(project, name, configuration, outdir, built):
    if name in built:
        return built[name]
    target = project.target(name)
    for dep in target.dependencies():
        build_target(project, dep, configuration, outdir, built)
    s = target.settings(configuration)
    ptype = target.product_type
    if ptype.endswith('.application'):
        ext = '.app'
    elif ptype.endswith('.app-extension'):
        ext = '.appex'
    elif ptype.endswith('.unit-test') or ptype.endswith('.ui-testing'):
        log(f'{name}: test bundles are built by `isim test` (skipped here)')
        built[name] = None
        return None
    else:
        log(f'{name}: product type {ptype} not supported yet (skipped)')
        built[name] = None
        return None

    product = s['PRODUCT_NAME']
    bundle = os.path.join(outdir, product + ext)
    objdir = os.path.join(outdir, 'obj', name)
    shutil.rmtree(bundle, ignore_errors=True)
    os.makedirs(bundle)
    os.makedirs(objdir, exist_ok=True)
    log(f'{name}: {ptype.split(".")[-1]} -> {os.path.relpath(bundle)}')

    sources = target.sources()
    swift = [f for f in sources if f.endswith('.swift')]
    other = [f for f in sources if f.endswith(('.m', '.mm', '.c', '.cpp'))]
    objs = []
    pkg_built = {}
    for product, ref in target.package_products():
        objs += build_package_product(project, product, ref, objdir, pkg_built)
    if swift:
        obj = os.path.join(objdir, f'{s["PRODUCT_MODULE_NAME"]}.o')
        cmd = [ISIM, 'swiftc', '-module-name', s['PRODUCT_MODULE_NAME'], '-wmo', '-c', '-o', obj, '-I', os.path.join(objdir, 'modules')]
        if not any(os.path.basename(f) == 'main.swift' for f in swift):
            cmd.append('-parse-as-library')                     # Xcode does the same when there is no main.swift
        sv = str(s.get('SWIFT_VERSION', '5')).split('.')[0]
        cmd += ['-swift-version', sv]
        if str(s.get('SWIFT_ENABLE_BARE_SLASH_REGEX', 'NO')).upper() == 'YES' and sv < '6':
            cmd.append('-enable-bare-slash-regex')              # Swift 6 has /regex/ literals on by default
        for flag in str(s.get('OTHER_SWIFT_FLAGS', '')).split():
            if flag != '$(inherited)':
                cmd.append(flag)
        for cond in str(s.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS', '')).split():
            if cond != '$(inherited)':
                cmd += ['-D', cond]
        run(cmd + swift)
        objs.append(obj)
    for f in other:
        obj = os.path.join(objdir, os.path.basename(f) + '.o')
        run([ISIM, 'cc', '-c', f, '-o', obj, '-I', os.path.dirname(f)])
        objs.append(obj)
    exe = os.path.join(bundle, s['EXECUTABLE_NAME'])
    link = [ISIM, 'cc'] + objs + ['-o', exe, '-framework', 'Foundation', '-framework', 'UIKit']
    products = {p for p, _ in target.package_products()}
    for fw in target.frameworks():
        n = fw.replace('.framework', '')
        if n in products or not n:
            continue
        if n not in ('Foundation', 'UIKit'):
            # frameworks isim implements only as Swift modules (SpriteKit, GameplayKit, ...) are autolinked
            if not os.path.isdir(os.path.join(SDK, 'System/Library/Frameworks', n + '.framework')) and \
                    os.path.exists(os.path.join(SDK, 'usr/lib/swift', f'libswift{n}.dylib')):
                continue
            link += ['-framework', n]
    if ext == '.appex':
        link += ['-Wl,-e,_NSExtensionMain']
    run(link)

    localizations = set()
    for res in target.resources():
        if res.endswith('.xcstrings'):
            localizations.update(compile_xcstrings(res, bundle))
        elif res.endswith('.xcassets'):
            compile_xcassets(res, bundle)
        elif res.endswith('.lproj'):
            copy_resource(res, bundle)
            localizations.add(os.path.basename(res)[:-6])
        else:
            copy_resource(res, bundle)
    info = make_info_plist(target, s, bundle, localizations)
    if ext == '.app':
        sk = storekit_configuration(project, name)
        if sk:
            shutil.copy2(sk, os.path.join(bundle, 'isim-StoreKitConfiguration.storekit'))
            info['ISIMStoreKitConfiguration'] = 'isim-StoreKitConfiguration.storekit'      # isim-private key
            with open(os.path.join(bundle, 'Info.plist'), 'wb') as f:
                plistlib.dump(info, f)
            log(f'{name}: StoreKit local testing with {os.path.basename(sk)} (from the scheme; nothing is charged)')

    for spec, emb in target.embedded():
        product_path = build_target(project, emb, configuration, outdir, built)
        if not product_path:
            continue
        sub = {'13': 'PlugIns', '16': 'Watch', '10': 'Frameworks'}.get(str(spec), 'PlugIns')
        dst = os.path.join(bundle, sub, os.path.basename(product_path))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(product_path, dst)
        log(f'{name}: embedded {os.path.basename(product_path)} in {sub}/')
    built[name] = bundle
    return bundle


def main():
    ap = argparse.ArgumentParser(prog='isim build')
    ap.add_argument('-project', required=True)
    ap.add_argument('-target')
    ap.add_argument('-scheme')
    ap.add_argument('-configuration', default='Debug')
    ap.add_argument('-o', '--output', default=None)
    a = ap.parse_args()
    project = Project(a.project)
    targets = project.targets()
    name = a.target or a.scheme
    if not name:                                   # default: first application target
        name = next((n for n, t in targets.items() if project.objects[t].get('productType', '').endswith('.application')), None)
    if name not in targets:
        sys.exit(f'isim build: no target named {name!r}; available: {", ".join(targets)}')
    outdir = os.path.abspath(a.output or os.path.join(BIN, '..', 'projects', os.path.splitext(os.path.basename(project.xcodeproj))[0]))
    os.makedirs(outdir, exist_ok=True)
    product = build_target(project, name, a.configuration, outdir, {})
    log(f'done: {product}')


if __name__ == '__main__':
    main()
