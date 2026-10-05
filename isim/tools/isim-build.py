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
                    files.append({'file': f'isim-assets/{dst}', 'scale': img.get('scale', '1x'),
                                  'idiom': img.get('idiom', 'universal'), 'appearance': appearance,
                                  'size': img.get('size')})
                index['appIcons' if kind == '.appiconset' else 'images'][name] = files
    with open(index_path, 'w') as f:
        json.dump(index, f, indent=1, sort_keys=True)
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
            info.setdefault(key, {'YES': True, 'NO': False}.get(v, v))
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
    if swift:
        obj = os.path.join(objdir, f'{s["PRODUCT_MODULE_NAME"]}.o')
        cmd = [ISIM, 'swiftc', '-module-name', s['PRODUCT_MODULE_NAME'], '-wmo', '-c', '-o', obj]
        if not any(os.path.basename(f) == 'main.swift' for f in swift):
            cmd.append('-parse-as-library')                     # Xcode does the same when there is no main.swift
        sv = str(s.get('SWIFT_VERSION', '5')).split('.')[0]
        cmd += ['-swift-version', sv]
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
    for fw in target.frameworks():
        n = fw.replace('.framework', '')
        if n not in ('Foundation', 'UIKit'):
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
    make_info_plist(target, s, bundle, localizations)

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
