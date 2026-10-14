#!/usr/bin/env python3
"""isim build: build an Xcode project's iOS targets for the isim simulator, on Linux.

  isim build (-project App.xcodeproj | -workspace App.xcworkspace) [-target NAME | -scheme NAME]
             [-configuration Debug|Release] [-o OUTDIR] [-package-cache DIR] [-skip-script-phases]
             [-onlyUsePackageVersionsFromResolvedFile] [-resolvePackageDependencies] [-list | -showBuildSettings [-json]]
             [SETTING=VALUE ...]

  Products (the .app, frameworks, intermediates in obj/) go to OUTDIR, by default ./build in the current folder.

What it does per target (dependencies first, also across the projects of a workspace):
  * product types: applications, app extensions, frameworks (dynamic, embedded in <App>.app/Frameworks and
    loaded through @rpath), static libraries (.a) and static frameworks, dynamic libraries, resource bundles,
    and unit-test / UI-test bundles (.xctest; run them with `isim test`)
  * compiles Swift sources with `isim swiftc` (whole-module) and C/ObjC/C++ sources with `isim cc`;
    mixed targets: bridging headers (SWIFT_OBJC_BRIDGING_HEADER), the generated <Module>-Swift.h header,
    frameworks import their own ObjC headers (umbrella header) into Swift
  * build settings: project/target configurations, .xcconfig files (#include, $(inherited), conditional
    settings), $(VAR) expansion, SETTING=VALUE overrides on the command line; schemes pick the targets
  * links the product (apps: MH_EXECUTE; app extensions: entry point _NSExtensionMain; frameworks:
    install name @rpath/Name.framework/Name; test bundles: MH_BUNDLE with -bundle_loader for hosted tests)
  * Info.plist: expands $(VARS) from build settings, applies INFOPLIST_KEY_*, sets MinimumOSVersion
  * resources: .xcstrings -> <lang>.lproj/<Table>.strings, .strings/.lproj copied,
    .xcassets -> <bundle>/isim-assets.json + images (isim's asset format; NOT Apple's Assets.car),
    .storyboard / .xib -> <Name>.storyboardc / <Name>.nib (isim's IB archive format, NOT Apple's compiled
    nibs; see isim/tools/ibtool.py), Settings.bundle and other folders copied, .xcprivacy and other files copied
    (the app's privacy manifests are checked like App Store Connect does: see isim privacy-report)
  * Metal sources (.metal, Core Image kernels) -> <bundle>/default.metallib holding the sources (isim's format,
    "ISIMMETALLIB 1"; NOT Apple's GPU binary): isim runs Core Image's Metal kernels from their source
  * Core Data models: .xcdatamodeld/.xcdatamodel -> <Name>.momd (isim's own model format, NOT Apple's binary
    .mom; see isim/tools/momc.py) plus the Swift classes Xcode's Class Definition / Category codegen makes
  * embeds app extensions into <App>.app/PlugIns/, App Clips (product type ...application.on-demand-install-capable)
    into <App>.app/AppClips/ and frameworks into <App>.app/Frameworks/ (copy-files phases)
  * Swift packages: local packages are built from source (Swift and C/ObjC targets, dependencies between
    packages, resources with Bundle.module, binary targets with a local .xcframework); manifests are read with
    `swift package dump-package`. Remote packages: a local checkout in -package-cache DIR / $ISIM_PACKAGE_CACHE
    (DIR/<name> or DIR/checkouts/<name>) first, else fetched with git into the package cache (default
    $XDG_CACHE_HOME/isim/packages) at the revision pinned in Package.resolved, or resolved from the requirement and the repository's tags and pinned there
    (-onlyUsePackageVersionsFromResolvedFile / -disableAutomaticPackageResolution refuse; -resolvePackageDependencies
    only fetches); remote binary targets are downloaded and checked against their SHA-256 checksum
  * project view: -list and -showBuildSettings (with -json) like xcodebuild; -tree (isim project) prints the targets,
    build phases and files
  * .xcframeworks: the x86_64 iOS-simulator slice is used; arm64-only XCFrameworks cannot run on isim
    (it executes x86_64 simulator code), and the build says so
  * shell script phases run like Xcode's: in their place among the target's build phases (a code generator before
    Compile Sources runs before compiling; its .swift/.m/.c outputs are compiled), with Xcode's environment (build
    settings, SCRIPT_INPUT_FILE_n, SCRIPT_INPUT_FILE_LIST_n for .xcfilelists, ...), skipped when their outputs are
    newer than their inputs, deployment-only phases only with DEPLOYMENT_POSTPROCESSING=YES; a failing script fails
    the build. -skip-script-phases skips them all (scripts calling macOS-only tools). CocoaPods' "[CP]" phases are
    replaced by isim's own embedding of the frameworks and resource bundles the Pods project builds

It never writes Xcode/SDK identity keys (DTXcode, DTSDKName, ...): products are honest isim builds.
"""
import argparse
import json
import os
import plistlib
import re
import shlex
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from xcodeproj import Project, Workspace, Scheme, scheme_files, cross_dependencies, expand, PHASE_NAMES  # noqa: E402
import momc  # noqa: E402
import ibtool  # noqa: E402

BIN = os.path.dirname(os.path.realpath(__file__))
ISIM = os.path.join(BIN, 'isim')
SDK = os.environ.get('ISIM_SDK') or os.path.normpath(os.path.join(BIN, '..', 'sdk'))
TRIPLE_MODULE = 'x86_64-apple-ios-simulator'


def log(msg):
    print(f'isim build: {msg}', flush=True)


def fail(msg):
    sys.exit(f'isim build: error: {msg}')


def run(cmd, **kw):
    r = subprocess.run(cmd, **kw)
    if r.returncode:
        shown = cmd if os.environ.get('ISIM_BUILD_VERBOSE') else cmd[:6] + ['...']     # ISIM_BUILD_VERBOSE=1: the whole command
        sys.exit(f'isim build: command failed ({r.returncode}): {shlex.join(shown)}')


def split_setting(v):
    """A list-valued build setting (space separated, shell-quoted) -> [items] without $(inherited)."""
    try:
        items = shlex.split(str(v or ''))
    except ValueError:
        items = str(v or '').split()
    return [x for x in items if x and x not in ('$(inherited)', '${inherited}')]


# ---------------- resources ----------------
_FMT_SPEC = re.compile(r'%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?((?:ll|l|h|hh|q|z|j|t|L)?[dDiuUoOxXfFeEgGaAcCsS@p])')


def _plural_rule(variations, fallback_spec='lld', substitution=False):
    """xcstrings plural variations -> .stringsdict rule dictionary (in substitutions, %arg is the argument)."""
    rule = {'NSStringFormatSpecTypeKey': 'NSStringPluralRuleType'}
    spec = fallback_spec if substitution else None
    for cat, v in variations.items():
        value = ((v or {}).get('stringUnit') or {}).get('value')
        if value is None:
            continue
        if substitution:
            value = value.replace('%arg', '%' + fallback_spec)
        rule[cat] = value
        m = _FMT_SPEC.search(value)
        if m and not spec and m.group(1) != '@':
            spec = m.group(1)
    rule['NSStringFormatValueTypeKey'] = spec or fallback_spec
    return rule


def _variation_value(v):
    """a device / width variation: its text, or a plural entry for nested plural variations (else None)"""
    v = v or {}
    if 'plural' in (v.get('variations') or {}):
        return {'NSStringLocalizedFormatKey': '%#@value@', 'value': _plural_rule(v['variations']['plural'])}
    value = (v.get('stringUnit') or {}).get('value')
    return value


def compile_xcstrings(path, bundle):
    """String catalog -> <lang>.lproj/<table>.strings (+ <table>.stringsdict for plural, device and width
    variations and substitutions, like Xcode: NSStringPluralRuleType, NSStringDeviceSpecificRuleType,
    NSStringVariableWidthRuleType). The .strings file keeps the 'other' / first value as a fallback."""
    table = os.path.splitext(os.path.basename(path))[0]
    with open(path, encoding='utf-8') as f:
        cat = json.load(f)
    source = cat.get('sourceLanguage', 'en')
    per_lang, plurals = {}, {}
    for key, entry in cat.get('strings', {}).items():
        locs = entry.get('localizations', {})
        if source not in locs:
            per_lang.setdefault(source, {})[key] = key        # source text is the key itself
        for lang, loc in locs.items():
            unit = loc.get('stringUnit')
            variations = loc.get('variations', {})
            subs = loc.get('substitutions', {})
            if 'plural' in variations:
                rule = _plural_rule(variations['plural'])
                plurals.setdefault(lang, {})[key] = {'NSStringLocalizedFormatKey': '%#@value@', 'value': rule}
                other = (variations['plural'].get('other') or {}).get('stringUnit') or {}
                if other.get('value') is not None:
                    per_lang.setdefault(lang, {})[key] = other['value']     # .strings fallback
                continue
            if not unit:
                for kind, rule_type in (('device', 'NSStringDeviceSpecificRuleType'), ('width', 'NSStringVariableWidthRuleType')):
                    vs = variations.get(kind, {})
                    if not vs:
                        continue
                    rule = {name: val for name, val in ((n, _variation_value(v)) for n, v in vs.items()) if val is not None}
                    if rule:
                        plurals.setdefault(lang, {})[key] = {rule_type: rule}
                    # the .strings fallback: 'other', else the widest / first variation's text
                    order = sorted(vs, key=lambda n: -int(n) if n.isdigit() else 0) if kind == 'width' else ['other'] + list(vs)
                    for n in order:
                        val = _variation_value(vs.get(n))
                        if isinstance(val, dict):
                            val = (vs[n]['variations']['plural'].get('other') or {}).get('stringUnit', {}).get('value')
                        if val is not None:
                            per_lang.setdefault(lang, {})[key] = val
                            break
                    break
                if key in plurals.get(lang, {}):
                    continue
            if unit and unit.get('value') is not None and subs:
                fmt = unit['value']
                d = {}
                for name, sub in subs.items():
                    pos = sub.get('argNum')
                    spec = sub.get('formatSpecifier', 'lld')
                    if pos:
                        fmt = fmt.replace(f'%#@{name}@', f'%{pos}$#@{name}@')
                    d[name] = _plural_rule((sub.get('variations') or {}).get('plural', {}), spec, substitution=True)
                d['NSStringLocalizedFormatKey'] = fmt
                plurals.setdefault(lang, {})[key] = d
                continue
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
    for lang, entries in plurals.items():
        d = os.path.join(bundle, f'{lang}.lproj')
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f'{table}.stringsdict'), 'wb') as f:
            plistlib.dump(entries, f)
    return sorted(set(per_lang) | set(plurals))


def appearance_key(appearances):
    """an asset variant's appearance: 'any' / 'light' / 'dark' (luminosity), '-high' added for the high-contrast variant"""
    lum = next((a.get('value') for a in appearances if a.get('appearance') == 'luminosity'), 'any')
    high = any(a.get('appearance') == 'contrast' and a.get('value') == 'high' for a in appearances)
    return lum + ('-high' if high else '')


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
                    appearance = appearance_key(c.get('appearances', []))
                    comps = c.get('color', {}).get('components', {})
                    def comp(k, default='1'):
                        v = str(comps.get(k, default))
                        return int(v, 16) / 255 if v.startswith('0x') else (float(v) / 255 if float(v) > 1 else float(v))
                    variants[appearance] = [comp('red', '0'), comp('green', '0'), comp('blue', '0'), comp('alpha')]
                index['colors'][name] = variants
            elif kind == '.dataset':
                # NSDataAsset(name:): the data file and its type identifier
                for item in meta.get('data', []):
                    fn = item.get('filename')
                    if not fn:
                        continue
                    os.makedirs(outdir, exist_ok=True)
                    dst = f'{name}-{fn}'
                    shutil.copy2(os.path.join(full, fn), os.path.join(outdir, dst))
                    index.setdefault('data', {})[name] = {'file': f'isim-assets/{dst}',
                                                          'uti': item.get('universal-type-identifier', 'public.data')}
                    break
            elif kind in ('.imageset', '.appiconset'):
                files = []
                for img in meta.get('images', []):
                    fn = img.get('filename')
                    if not fn:
                        continue
                    os.makedirs(outdir, exist_ok=True)
                    dst = f'{name}-{fn}'
                    shutil.copy2(os.path.join(full, fn), os.path.join(outdir, dst))
                    appearance = appearance_key(img.get('appearances', []))
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


SWIFT_KEYWORDS = {'associatedtype', 'class', 'deinit', 'enum', 'extension', 'fileprivate', 'func', 'import', 'init', 'inout',
                  'internal', 'let', 'open', 'operator', 'private', 'protocol', 'public', 'static', 'struct', 'subscript',
                  'typealias', 'var', 'break', 'case', 'continue', 'default', 'defer', 'do', 'else', 'fallthrough', 'for',
                  'guard', 'if', 'in', 'repeat', 'return', 'switch', 'where', 'while', 'as', 'catch', 'false', 'is', 'nil',
                  'rethrows', 'super', 'self', 'throw', 'throws', 'true', 'try', 'Type', 'Self', 'Any'}


def asset_symbol_name(name, kind):
    """Xcode's symbol for an asset: lower camel case of its words, without a trailing "Color" / "Image" ("AccentColor" ->
    accent, "brand-blue" -> brandBlue, "URLIcon" -> urlIcon); "_" before a leading digit, keywords in backticks"""
    words = []
    for part in re.split(r'[^0-9A-Za-z]+', name):
        words += re.findall(r'[A-Z]+(?=[A-Z][a-z]|[0-9]|$)|[A-Z]?[a-z]+|[0-9]+|[A-Z]+', part)
    suffix = 'Color' if kind == 'color' else 'Image'
    if len(words) > 1 and words[-1].lower() == suffix.lower():
        words = words[:-1]
    if not words:
        return None
    sym = words[0].lower() + ''.join(w[:1].upper() + w[1:] for w in words[1:])
    if sym[0].isdigit():
        sym = '_' + sym
    return f'`{sym}`' if sym in SWIFT_KEYWORDS else sym


def asset_names(catalogs):
    """(colors, images) of asset catalogs: their asset names (app icons excluded), in order"""
    colors, images = [], []
    for cat in catalogs:
        for dirpath, dirnames, _ in os.walk(cat):
            dirnames.sort()
            for d in dirnames:
                name, kind = os.path.splitext(d)
                if kind == '.colorset' and name not in colors:
                    colors.append(name)
                elif kind == '.imageset' and name not in images:
                    images.append(name)
    return colors, images


def generate_asset_symbols(catalogs, settings, swift_out, objc_out, bundle_expr='Foundation.Bundle(for: ResourceBundleClass.self)'):
    """Xcode's GeneratedAssetSymbols.swift / .h for asset catalogs (ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS,
    default YES): ColorResource / ImageResource members, and with ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS
    (YES in new projects) UIColor / UIImage / Color / Image / ShapeStyle members for the frameworks in
    ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS (default: SwiftUI and UIKit). Returns the Swift file, or None."""
    yes = lambda k, d: str(settings.get(k, d)).upper() == 'YES'
    if not catalogs or not yes('ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS', 'YES'):
        return None
    colors, images = asset_names(catalogs)
    if not colors and not images:
        return None
    frameworks = split_setting(settings.get('ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOL_FRAMEWORKS')) or ['SwiftUI', 'UIKit']
    extensions = yes('ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS', 'NO')

    def symbols(names, kind):
        out, seen = [], set()
        for n in names:
            sym = asset_symbol_name(n, kind)
            if not sym or sym in seen:
                log(f'asset symbols: no symbol for {kind} "{n}" (empty or clashing name)')
                continue
            seen.add(sym)
            out.append((sym, n))
        return out
    cs, ims = symbols(colors, 'color'), symbols(images, 'image')
    swift = ['import Foundation', '#if canImport(DeveloperToolsSupport)', 'import DeveloperToolsSupport', '#endif', '']
    swift += (['private class ResourceBundleClass {}'] if 'ResourceBundleClass' in bundle_expr else []) + \
        [f'private let resourceBundle = {bundle_expr}', '']
    swift += ['// MARK: - Color Symbols -', '', 'extension DeveloperToolsSupport.ColorResource {']
    for sym, n in cs:
        swift += [f'    /// The "{n}" asset catalog color resource.', f'    static let {sym} = DeveloperToolsSupport.ColorResource(name: "{n}", bundle: resourceBundle)', '']
    swift += ['}', '', '// MARK: - Image Symbols -', '', 'extension DeveloperToolsSupport.ImageResource {']
    for sym, n in ims:
        swift += [f'    /// The "{n}" asset catalog image resource.', f'    static let {sym} = DeveloperToolsSupport.ImageResource(name: "{n}", bundle: resourceBundle)', '']
    swift += ['}', '']
    if extensions:
        if 'UIKit' in frameworks:
            swift += ['// MARK: - Color Symbol Extensions -', '', '#if canImport(UIKit)', 'import UIKit', '', 'extension UIKit.UIColor {']
            for sym, n in cs:
                swift += [f'    /// The "{n}" asset catalog color.', f'    static var {sym}: UIKit.UIColor {{', f'        .init(resource: .{sym})', '    }', '']
            swift += ['}', '', 'extension UIKit.UIImage {']
            for sym, n in ims:
                swift += [f'    /// The "{n}" asset catalog image.', f'    static var {sym}: UIKit.UIImage {{', f'        .init(resource: .{sym})', '    }', '']
            swift += ['}', '#endif', '']
        if 'SwiftUI' in frameworks:
            swift += ['#if canImport(SwiftUI)', 'import SwiftUI', '', 'extension SwiftUI.Color {']
            for sym, n in cs:
                swift += [f'    /// The "{n}" asset catalog color.', f'    static var {sym}: SwiftUI.Color {{ .init(.{sym}) }}', '']
            swift += ['}', '', 'extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {']
            for sym, n in cs:
                swift += [f'    /// The "{n}" asset catalog color.', f'    static var {sym}: SwiftUI.Color {{ .init(.{sym}) }}', '']
            swift += ['}', '#endif', '']
    os.makedirs(os.path.dirname(swift_out), exist_ok=True)
    with open(swift_out, 'w') as f:
        f.write('\n'.join(swift))
    # Objective-C: the asset names as constants (ACColorName... / ACImageName...)
    objc = ['#import <Foundation/Foundation.h>', '', '#if __has_attribute(swift_private)',
            '#define AC_SWIFT_PRIVATE __attribute__((swift_private))', '#else', '#define AC_SWIFT_PRIVATE', '#endif', '']
    def objc_name(n):
        return ''.join(w[:1].upper() + w[1:] for w in re.split(r'[^0-9A-Za-z]+', n) if w)
    for sym, n in cs:
        objc += [f'/// The "{n}" asset catalog color resource.', f'static NSString * const ACColorName{objc_name(n)} AC_SWIFT_PRIVATE = @"{n}";', '']
    for sym, n in ims:
        objc += [f'/// The "{n}" asset catalog image resource.', f'static NSString * const ACImageName{objc_name(n)} AC_SWIFT_PRIVATE = @"{n}";', '']
    objc += ['#undef AC_SWIFT_PRIVATE', '']
    with open(objc_out, 'w') as f:
        f.write('\n'.join(objc))
    log(f'asset symbols: {len(cs)} colors, {len(ims)} images -> {os.path.basename(swift_out)}'
        + (' (with UIKit / SwiftUI extensions)' if extensions else ''))
    return swift_out


def compile_metal(sources, bundle):
    """Metal sources -> <bundle>/default.metallib: isim's library format, the sources after an "ISIMMETALLIB 1" line.
    isim's Core Image interprets the kernels in it (CIKernel(functionName:fromMetalLibraryData:)); it is not GPU code."""
    if not sources:
        return None
    parts = ['ISIMMETALLIB 1\n']
    for f in sorted(sources):
        with open(f, encoding='utf-8') as fh:
            parts.append(f'// file: {os.path.basename(f)}\n' + fh.read() + '\n')
    os.makedirs(bundle, exist_ok=True)
    out = os.path.join(bundle, 'default.metallib')
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write(''.join(parts))
    log(f'{len(sources)} Metal source(s) -> {os.path.relpath(out, os.path.dirname(bundle))} (isim metallib: the sources)')
    return out


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



# ---------------- binary frameworks (.xcframework) ----------------
CXX_RUNTIME = re.compile(r'\s(__ZNSt3__1|__ZNKSt3__1|__ZTVN10__cxxabiv1|__Znwm|__Znam|__ZdlPv|__ZdaPv|___cxa_|___gxx_personality_v0)')


def uses_cxx_runtime(paths):
    """whether objects or static libraries reference the C++ runtime (libc++/libc++abi): the link then adds -lc++, like
    Xcode's link of C++ code and of binary dependencies built from it (Google Mobile Ads)"""
    files = [p for p in paths if os.path.isfile(p) and (p.endswith('.o') or macho_kind(p) in ('static', 'fat'))]
    if not files:
        return False
    r = subprocess.run(['llvm-nm', '--arch=x86_64', '-u', '-j', *files], capture_output=True, text=True)
    return bool(CXX_RUNTIME.search('\n' + r.stdout))


def link_inputs(objs, args):
    """the objects and library files of a link line (-F dir -framework X resolved to dir/X.framework/X)"""
    out, fdirs, prev = list(objs), [], None
    for a in args:
        if prev == '-F':
            fdirs.append(a)
        elif prev == '-framework':
            out += [os.path.join(d, f'{a}.framework', a) for d in fdirs if os.path.isfile(os.path.join(d, f'{a}.framework', a))][:1]
        elif not a.startswith('-') and prev not in ('-o', '-L', '-install_name', '-bundle_loader'):
            out.append(a)
        prev = a
    return out


def macho_kind(path):
    """'dylib', 'static', 'fat' (universal; needs thinning), 'other' or None for a library file."""
    try:
        with open(path, 'rb') as f:
            head = f.read(16)
    except OSError:
        return None
    if head.startswith(b'!<arch>'):
        return 'static'
    if head[:4] in (b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'):
        return 'fat'
    if head[:4] == b'\xcf\xfa\xed\xfe':
        return 'dylib' if int.from_bytes(head[12:16], 'little') == 6 else 'other'
    return 'other'


def xcframework_slice(path):
    """The x86_64 iOS-simulator library of an .xcframework: (library path, headers dir or None)."""
    info_path = os.path.join(path, 'Info.plist')
    if not os.path.exists(info_path):
        fail(f'{path}: not an XCFramework (no Info.plist)')
    with open(info_path, 'rb') as f:
        info = plistlib.load(f)
    libs = info.get('AvailableLibraries', [])
    for lib in libs:
        if lib.get('SupportedPlatform') == 'ios' and lib.get('SupportedPlatformVariant') == 'simulator' \
                and 'x86_64' in lib.get('SupportedArchitectures', []):
            base = os.path.join(path, lib['LibraryIdentifier'])
            hdr = os.path.join(base, lib['HeadersPath']) if lib.get('HeadersPath') else None
            return os.path.join(base, lib['LibraryPath']), hdr
    have = ', '.join(f'{l.get("LibraryIdentifier")} ({"/".join(l.get("SupportedArchitectures", []))})' for l in libs) or 'none'
    fail(f'{os.path.basename(path)} has no x86_64 iOS-simulator slice (it has: {have}). isim runs x86_64 iOS-simulator '
         'code only: arm64 device and arm64-simulator binaries cannot execute here. Rebuild the XCFramework with an '
         'x86_64 simulator slice (xcodebuild ... -sdk iphonesimulator ARCHS=x86_64) or build the library from source.')


def thin_x86_64(src, dst):
    """Copies a Mach-O library, extracting the x86_64 slice of a universal binary (the isim loader takes thin files)."""
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if macho_kind(src) == 'fat':
        run(['llvm-lipo', src, '-thin', 'x86_64', '-output', dst])
    else:
        shutil.copy2(src, dst)


# ---------------- Swift packages ----------------
def dump_package(path, cache_dir):
    """Package.swift -> manifest JSON (evaluated by SwiftPM in the swift:6.2 container; cached)."""
    os.makedirs(cache_dir, exist_ok=True)
    cache = os.path.join(cache_dir, re.sub(r'[^A-Za-z0-9]', '_', path) + '.json')
    manifest = os.path.join(path, 'Package.swift')
    if not os.path.exists(manifest):
        fail(f'{path}: no Package.swift')
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


def privacy_check(app, log):
    """the privacy manifest checks of isim privacy-report (isim-privacy.py), as build warnings"""
    import importlib.util
    spec = importlib.util.spec_from_file_location('isim_privacy', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'isim-privacy.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.check(app, log)


# swift-syntax's libraries in the Swift toolchain (/usr/lib/swift/host of swift:6.2): what macro targets build against
SWIFT_SYNTAX_HOST = set('''SwiftBasicFormat SwiftCompilerPluginMessageHandling SwiftDiagnostics SwiftIDEUtils SwiftIfConfig
SwiftOperators SwiftParser SwiftParserDiagnostics SwiftRefactor SwiftSyntax SwiftSyntaxBuilder SwiftSyntaxMacroExpansion
SwiftSyntaxMacros'''.split())


def norm_url(url):
    return (url or '').lower().rstrip('/').removesuffix('.git')


def package_identity(url):
    """SwiftPM's identity of a remote package: the last path component of its URL, lowercased, without .git."""
    return norm_url(url).split('/')[-1].split(':')[-1]


def resolved_file_path(workspace, projects):
    """Where Xcode keeps the pins: <App>.xcworkspace/xcshareddata/swiftpm/Package.resolved, or for a project
    <App>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved."""
    if workspace:
        return os.path.join(workspace, 'xcshareddata', 'swiftpm', 'Package.resolved')
    if projects:
        return os.path.join(projects[0], 'project.xcworkspace', 'xcshareddata', 'swiftpm', 'Package.resolved')
    return None


def read_pins(path):
    """Package.resolved (version 1, 2 or 3) -> {identity: {'location', 'state': {revision, version|branch}}}."""
    if not path or not os.path.exists(path):
        return {}
    with open(path) as f:
        data = json.load(f)
    out = {}
    if data.get('version') == 1:
        for p in (data.get('object') or {}).get('pins', []):
            url = p.get('repositoryURL', '')
            out[package_identity(url)] = {'location': url, 'state': {k: v for k, v in (p.get('state') or {}).items() if v}}
    else:
        for p in data.get('pins', []):
            if p.get('kind', 'remoteSourceControl') != 'remoteSourceControl':
                continue
            out[p.get('identity') or package_identity(p.get('location'))] = {
                'location': p.get('location', ''), 'state': {k: v for k, v in (p.get('state') or {}).items() if v}}
    return out


def write_pins(path, pins):
    """Package.resolved in Xcode's version 2 format (pins sorted by identity)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = {'pins': [{'identity': ident, 'kind': 'remoteSourceControl', 'location': p['location'],
                      'state': {k: p['state'][k] for k in ('branch', 'revision', 'version') if p['state'].get(k)}}
                     for ident, p in sorted(pins.items())], 'version': 2}
    with open(path, 'w') as f:
        f.write(json.dumps(data, indent=2) + '\n')


_SEMVER = re.compile(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$')


def parse_version(v):
    """'1.2.3' / 'v1.2' -> ((1, 2, 3), prerelease or '') or None."""
    m = _SEMVER.match(str(v or '').strip())
    if not m:
        return None
    return (int(m.group(1)), int(m.group(2) or 0), int(m.group(3) or 0)), (m.group(4) or '')[1:]


def requirement_of_ref(ref):
    """XCRemoteSwiftPackageReference.requirement -> ('range', lo, hi) | ('branch', name) | ('revision', sha)."""
    r = (ref or {}).get('requirement') or {}
    kind = r.get('kind', '')
    lo = parse_version(r.get('minimumVersion') or r.get('version'))
    if kind == 'branch':
        return ('branch', r.get('branch', 'main'))
    if kind == 'revision':
        return ('revision', r.get('revision', ''))
    if kind == 'exactVersion' and lo:
        return ('exact', lo[0])
    if kind == 'upToNextMinorVersion' and lo:
        return ('range', lo[0], (lo[0][0], lo[0][1] + 1, 0))
    if kind == 'versionRange' and lo:
        hi = parse_version(r.get('maximumVersion'))
        return ('range', lo[0], hi[0] if hi else (lo[0][0] + 1, 0, 0))
    if lo:                                            # upToNextMajorVersion (Xcode's default)
        return ('range', lo[0], (lo[0][0] + 1, 0, 0))
    return ('range', (0, 0, 0), (1 << 30, 0, 0))


def requirement_of_manifest(req):
    """A dump-package sourceControl requirement ({'range': [{lowerBound, upperBound}]}, {'exact': [v]}, ...)."""
    req = req or {}
    if 'range' in req:
        r = req['range'][0]
        lo, hi = parse_version(r.get('lowerBound')), parse_version(r.get('upperBound'))
        return ('range', lo[0] if lo else (0, 0, 0), hi[0] if hi else (1 << 30, 0, 0))
    if 'exact' in req:
        v = parse_version(req['exact'][0])
        return ('exact', v[0]) if v else ('range', (0, 0, 0), (1 << 30, 0, 0))
    if 'branch' in req:
        return ('branch', req['branch'][0])
    if 'revision' in req:
        return ('revision', req['revision'][0])
    return ('range', (0, 0, 0), (1 << 30, 0, 0))


def git(*args, cwd=None, check=True):
    r = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True,
                       env=dict(os.environ, GIT_TERMINAL_PROMPT='0'))
    if check and r.returncode:
        fail(f'git {" ".join(args[:3])} ... failed: {(r.stderr or r.stdout).strip()}')
    return r


def extract_zip(zpath, dest):
    """Unzips an artifact (keeping the symbolic links zip files of frameworks carry)."""
    import zipfile
    with zipfile.ZipFile(zpath) as z:
        for info in z.infolist():
            target = os.path.normpath(os.path.join(dest, info.filename))
            if not (target + os.sep).startswith(os.path.normpath(dest) + os.sep):
                fail(f'{zpath}: unsafe path {info.filename!r} in the archive')
            mode = (info.external_attr >> 16) & 0o170777
            if info.is_dir():
                os.makedirs(target, exist_ok=True)
            elif mode & 0o170000 == 0o120000:            # symlink
                os.makedirs(os.path.dirname(target), exist_ok=True)
                link = z.read(info).decode()
                if os.path.isabs(link) or not os.path.normpath(os.path.join(os.path.dirname(target), link)).startswith(os.path.normpath(dest)):
                    fail(f'{zpath}: unsafe link {info.filename!r} in the archive')
                if os.path.lexists(target):
                    os.remove(target)
                os.symlink(link, target)
            else:
                os.makedirs(os.path.dirname(target), exist_ok=True)
                with z.open(info) as src, open(target, 'wb') as out:
                    shutil.copyfileobj(src, out)
                if mode & 0o111:
                    os.chmod(target, 0o755)


class Packages:
    """Builds Swift package products from source as static code linked into the target that uses them (what
    Xcode does for automatic library products). Package targets are built once per build."""

    def __init__(self, builder):
        self.b = builder
        self.manifests = {}       # package dir -> manifest
        self.targets_built = {}   # (package dir, target) -> result dict
        self.resolved_file = None  # the workspace's / project's Package.resolved (pins)
        self.automatic = True     # resolve unpinned packages from their requirements (and write Package.resolved)
        self._pins = None
        self.remotes = {}         # identity -> checkout dir (this build)

    # -- locating packages --
    def cache_dirs(self):
        dirs = list(self.b.package_cache)
        if os.environ.get('ISIM_PACKAGE_CACHE'):
            dirs += os.environ['ISIM_PACKAGE_CACHE'].split(os.pathsep)
        return [d for d in dirs if d and os.path.isdir(d)]

    def checkout(self, url, identity=None):
        """A local checkout of a remote package (never fetched): <cache>/<name> or <cache>/checkouts/<name>."""
        name = norm_url(url).split('/')[-1]
        for d in self.cache_dirs():
            for cand in (os.path.join(d, name), os.path.join(d, 'checkouts', name),
                         os.path.join(d, identity or name), os.path.join(d, 'checkouts', identity or name)):
                if os.path.exists(os.path.join(cand, 'Package.swift')):
                    return cand
            for entry in os.listdir(d):         # case-insensitive match
                if entry.lower() == name and os.path.exists(os.path.join(d, entry, 'Package.swift')):
                    return os.path.join(d, entry)
        return None

    def fetch_dir(self):
        """Where fetched packages and artifacts live: the first -package-cache / $ISIM_PACKAGE_CACHE directory, else
        $XDG_CACHE_HOME/isim/packages (~/.cache/isim/packages)."""
        dirs = list(self.b.package_cache) + [d for d in os.environ.get('ISIM_PACKAGE_CACHE', '').split(os.pathsep) if d]
        if dirs:
            return dirs[0]
        base = os.environ.get('XDG_CACHE_HOME') or os.path.join(os.path.expanduser('~'), '.cache')
        return os.path.join(base, 'isim', 'packages')

    def pins(self):
        if self._pins is None:
            self._pins = read_pins(self.resolved_file)
        return self._pins

    def remote(self, url, requirement, pkg_dir=None):
        """A checkout of a remote package: a local checkout in the package cache (offline), else the pinned revision
        (Package.resolved), else the newest version matching the requirement, fetched with git."""
        ident = package_identity(url)
        if ident in self.remotes:
            return self.remotes[ident]
        local = self.checkout(url, ident)
        if local:
            log(f'{ident}: remote package from the local checkout {local} (not fetched)')
            self.remotes[ident] = local
            return local
        pin = self.pins().get(ident)
        if not pin and pkg_dir:                       # a local package's own Package.resolved
            pin = read_pins(os.path.join(pkg_dir, 'Package.resolved')).get(ident)
        if pin and pin['state'].get('revision'):
            rev, state = pin['state']['revision'], pin['state']
            dest = os.path.join(self.fetch_dir(), 'checkouts', f'{ident}@{rev[:12]}')
            if os.path.exists(os.path.join(dest, 'Package.swift')):          # fetched before: no network needed
                log(f'{ident}: {url} pinned {state.get("version") or state.get("branch") or rev[:12]} -> {dest}')
                self.remotes[ident] = dest
                return dest
        repo = self.mirror(url, ident)
        if pin and pin['state'].get('revision'):
            how = f'pinned {state.get("version") or state.get("branch") or rev[:12]} (Package.resolved)'
        elif pin and pin['state'].get('version'):
            state = pin['state']
            rev = self.tag_revision(repo, state['version'])
            how = f'pinned {state["version"]} (Package.resolved)'
        else:
            if not self.automatic:
                fail(f'{url} is not pinned in {self.resolved_file or "Package.resolved"} and automatic package resolution '
                     'is disabled (-disableAutomaticPackageResolution / -onlyUsePackageVersionsFromResolvedFile)')
            rev, state = self.resolve(repo, url, requirement)
            how = f'resolved {state.get("version") or state.get("branch") or rev[:12]}'
            self.pins()[ident] = {'location': url, 'state': state}
            if self.resolved_file:
                write_pins(self.resolved_file, self.pins())
                log(f'{ident}: pinned in {self.resolved_file}')
        if not git('cat-file', '-e', rev + '^{commit}', cwd=repo, check=False).returncode == 0:
            git('fetch', '--quiet', '--tags', '--force', url, '+refs/heads/*:refs/heads/*', cwd=repo)
        dest = os.path.join(self.fetch_dir(), 'checkouts', f'{ident}@{rev[:12]}')
        if not os.path.exists(os.path.join(dest, 'Package.swift')):
            tmp = dest + '.tmp'
            shutil.rmtree(tmp, ignore_errors=True)
            git('clone', '--quiet', '--shared', '--no-checkout', repo, tmp)
            git('checkout', '--quiet', '--detach', rev, cwd=tmp)
            if os.path.exists(os.path.join(tmp, '.gitmodules')):
                git('submodule', 'update', '--quiet', '--init', '--recursive', cwd=tmp)
            shutil.rmtree(dest, ignore_errors=True)
            os.rename(tmp, dest)
        if not os.path.exists(os.path.join(dest, 'Package.swift')):
            fail(f'{url} at {rev[:12]}: no Package.swift')
        log(f'{ident}: {url} {how} -> {dest}')
        self.remotes[ident] = dest
        return dest

    def mirror(self, url, ident):
        """A bare mirror of the package's repository in the fetch directory (cloned once, fetched when needed)."""
        import hashlib
        repo = os.path.join(self.fetch_dir(), 'repositories', f'{ident}-{hashlib.sha256(url.encode()).hexdigest()[:8]}.git')
        if not os.path.isdir(repo):
            os.makedirs(os.path.dirname(repo), exist_ok=True)
            log(f'{ident}: fetching {url}')
            tmp = repo + '.tmp'
            shutil.rmtree(tmp, ignore_errors=True)
            git('clone', '--quiet', '--mirror', url, tmp)
            os.rename(tmp, repo)
        return repo

    def tag_revision(self, repo, version):
        tags = self.tags(repo)
        want = parse_version(version)
        for name, (v, rev) in tags.items():
            if name == version or (want and v == want):
                return rev
        git('fetch', '--quiet', '--tags', '--force', cwd=repo)
        for name, (v, rev) in self.tags(repo).items():
            if name == version or (want and v == want):
                return rev
        fail(f'{repo}: no tag {version}')

    @staticmethod
    def tags(repo):
        """{tag name: (parsed version, commit)} of the repository's version tags."""
        out, peeled = {}, {}
        for line in git('show-ref', '--tags', '-d', cwd=repo, check=False).stdout.splitlines():
            sha, _, ref = line.partition(' ')
            name = ref.removeprefix('refs/tags/')
            if name.endswith('^{}'):
                peeled[name[:-3]] = sha
            else:
                out[name] = sha
        res = {}
        for name, sha in out.items():
            v = parse_version(name)
            if v:
                res[name] = (v, peeled.get(name, sha))
        return res

    def resolve(self, repo, url, req):
        """(revision, pin state) for a requirement: the newest matching version tag (no pre-releases), a branch head
        or a revision."""
        if req[0] == 'branch':
            git('fetch', '--quiet', '--force', url, f'+refs/heads/{req[1]}:refs/heads/{req[1]}', cwd=repo, check=False)
            r = git('rev-parse', '--verify', '--quiet', f'refs/heads/{req[1]}^{{commit}}', cwd=repo, check=False)
            if r.returncode:
                fail(f'{url}: no branch {req[1]!r}')
            return r.stdout.strip(), {'branch': req[1], 'revision': r.stdout.strip()}
        if req[0] == 'revision':
            r = git('rev-parse', '--verify', '--quiet', req[1] + '^{commit}', cwd=repo, check=False)
            if r.returncode:
                fail(f'{url}: no revision {req[1]}')
            return r.stdout.strip(), {'revision': r.stdout.strip()}
        git('fetch', '--quiet', '--tags', '--force', cwd=repo, check=False)
        cands = []
        for name, (v, rev) in self.tags(repo).items():
            num, pre = v
            if pre:
                continue
            if (req[0] == 'exact' and num == req[1]) or (req[0] == 'range' and req[1] <= num < req[2]):
                cands.append((num, name, rev))
        if not cands:
            what = f'{".".join(map(str, req[1]))}' if req[0] == 'exact' else \
                f'{".".join(map(str, req[1]))}..<{".".join(map(str, req[2]))}'
            fail(f'{url}: no version tag matches {what} (tags: {", ".join(sorted(self.tags(repo))) or "none"})')
        num, name, rev = max(cands)
        return rev, {'revision': rev, 'version': '.'.join(map(str, num))}

    def resolve_all(self, projects):
        """-resolvePackageDependencies: fetch every remote package of the projects and their dependencies."""
        todo = []
        for p in projects:
            for rid in p.project.get('packageReferences', []):
                ref = p.objects[rid]
                if ref.get('isa') == 'XCRemoteSwiftPackageReference':
                    todo.append(self.remote(ref.get('repositoryURL', ''), requirement_of_ref(ref)))
                elif ref.get('isa') == 'XCLocalSwiftPackageReference':
                    todo.append(os.path.normpath(os.path.join(p.root, ref.get('relativePath', ''))))
        seen = set()
        while todo:
            d = todo.pop()
            if d in seen or not isinstance(d, str):
                continue
            seen.add(d)
            todo += list(self.dependency_dirs(d).values())

    def manifest(self, path):
        if path not in self.manifests:
            self.manifests[path] = dump_package(path, os.path.join(self.b.outdir, 'obj', 'packages'))
        return self.manifests[path]

    def dependency_dirs(self, pkg_dir):
        """{identity or name (lowercase): package dir} for the package's declared dependencies."""
        out = {}
        for dep in self.manifest(pkg_dir).get('dependencies', []):
            if 'fileSystem' in dep:
                d = dep['fileSystem'][0]
                path = d.get('path')
                if path and not os.path.isabs(path):
                    path = os.path.normpath(os.path.join(pkg_dir, path))
                out[d.get('identity', os.path.basename(path)).lower()] = path
            elif 'sourceControl' in dep:
                d = dep['sourceControl'][0]
                loc = d.get('location', {})
                url = (loc.get('remote') or [{}])[0]
                url = url.get('urlString') if isinstance(url, dict) else url
                path = (loc.get('local') or [None])[0]
                if path and not os.path.exists(os.path.join(path, 'Package.swift')):
                    url, path = 'file://' + path, None         # a local git repository (file:// URL): fetched like a remote
                path = path or self.remote(url, requirement_of_manifest(d.get('requirement')), pkg_dir)
                ident = d.get('identity', norm_url(url).split('/')[-1]).lower()
                if not path:
                    out[ident] = ('missing', url)
                else:
                    out[ident] = path
        return out

    # -- products --
    def product_from_project(self, project, product, ref):
        """A package product used by an Xcode target: returns the build result (see build_target)."""
        isa = ref.get('isa') if ref else 'XCLocalSwiftPackageReference'
        if isa == 'XCRemoteSwiftPackageReference':
            url = ref.get('repositoryURL', '')
            return self.product(self.remote(url, requirement_of_ref(ref)), product)
        if ref is None:                             # product of a local package: find the package that has it
            refs = [project.objects[r] for r in project.project.get('packageReferences', [])
                    if project.objects[r].get('isa') == 'XCLocalSwiftPackageReference']
            # Xcode also lists local packages as file references (folders with a Package.swift)
            dirs = [os.path.normpath(os.path.join(project.root, r.get('relativePath', ''))) for r in refs]
            dirs += [project.path_of(oid) for oid, o in project.objects.items()
                     if o.get('isa') == 'PBXFileReference' and o.get('lastKnownFileType') == 'wrapper'
                     and os.path.exists(os.path.join(project.path_of(oid), 'Package.swift'))]
        else:
            dirs = [os.path.normpath(os.path.join(project.root, ref.get('relativePath', '')))]
        for d in dirs:
            if any(p['name'] == product for p in self.manifest(d).get('products', [])):
                return self.product(d, product)
        fail(f'package product {product!r} not found in the local packages ({", ".join(dirs) or "none"})')

    @staticmethod
    def empty():
        return {'objs': [], 'swift_flags': [], 'cc_flags': [], 'link': [], 'embed': [], 'bundles': []}

    @staticmethod
    def merge(into, r):
        def chunks(flags):                      # a flag with its argument is one unit ("-I dir", "-Xcc -Idir")
            out, i = [], 0
            while i < len(flags):
                if flags[i] in ('-I', '-F', '-L', '-framework', '-Xcc', '-Xlinker', '-load-plugin-library') and i + 1 < len(flags):
                    out.append(tuple(flags[i:i + 2])); i += 2
                else:
                    out.append((flags[i],)); i += 1
            return out
        for k in into:
            if k in ('swift_flags', 'cc_flags', 'link'):
                have = set(chunks(into[k]))
                for c in chunks(r.get(k, [])):
                    if c not in have:
                        into[k].extend(c); have.add(c)
            else:
                for x in r.get(k, []):
                    if x not in into[k]:
                        into[k].append(x)
        return into

    def product(self, pkg_dir, product):
        m = self.manifest(pkg_dir)
        prod = next((p for p in m.get('products', []) if p['name'] == product), None)
        if not prod:
            fail(f'package {m.get("name")} has no product {product!r}')
        if 'library' in prod.get('type', {}) and prod['type']['library'] == ['dynamic']:
            log(f'{product}: dynamic library product linked statically into the target (isim)')
        out = self.empty()
        for t in prod['targets']:
            self.merge(out, self.target(pkg_dir, t))
        return out

    # -- targets --
    def target(self, pkg_dir, tname):
        key = (pkg_dir, tname)
        if key in self.targets_built:
            return self.targets_built[key]
        m = self.manifest(pkg_dir)
        targets = {t['name']: t for t in m.get('targets', [])}
        if tname not in targets:
            fail(f'package {m.get("name")}: no target {tname!r}')
        t = targets[tname]
        self.targets_built[key] = None             # cycle guard
        if t.get('type') == 'macro':
            res = self.macro_target(pkg_dir, m, t)
            self.targets_built[key] = res
            return res
        deps = self.empty()
        dep_dirs = None
        for d in t.get('dependencies', []):
            if 'byName' in d or 'target' in d:
                name = (d.get('byName') or d.get('target'))[0]
                if name in targets:
                    self.merge(deps, self.target(pkg_dir, name))
                    continue
                # byName may also name a product of a dependency package
                dep_dirs = dep_dirs if dep_dirs is not None else self.dependency_dirs(pkg_dir)
                self.merge(deps, self.product_of_dependency(pkg_dir, dep_dirs, name, None))
            elif 'product' in d:
                pname, ident = d['product'][0], d['product'][1]
                dep_dirs = dep_dirs if dep_dirs is not None else self.dependency_dirs(pkg_dir)
                self.merge(deps, self.product_of_dependency(pkg_dir, dep_dirs, pname, ident))
        kind = t.get('type', 'regular')
        if kind == 'binary':
            res = self.binary_target(pkg_dir, m, t)
        elif kind in ('regular', 'executable', 'test'):
            res = self.source_target(pkg_dir, m, t, deps)
        elif kind == 'system':
            res = self.empty()
            log(f'{tname}: system library target (module map only)')
            mm = os.path.join(pkg_dir, t.get('path') or os.path.join('Sources', tname))
            res['swift_flags'] += ['-I', mm]
            res['cc_flags'] += ['-I', mm]
        else:
            fail(f'{tname}: package target type {kind!r} (build tool / command plugins) is not supported by isim build')
        self.merge(res, deps)
        self.targets_built[key] = res
        return res

    def macro_target(self, pkg_dir, m, t):
        """A macro target: a compiler plugin for the toolchain's host (Linux), built in the swift:6.2 container against
        the toolchain's swift-syntax libraries (/usr/lib/swift/host; the package's swift-syntax dependency is not
        fetched) and isim's SwiftCompilerPlugin module, as lib<Target>.so that the compiler loads in process
        (-load-plugin-library) when it compiles the targets using the macros."""
        tname = t['name']
        host_dir = os.path.normpath(os.path.join(BIN, '..', 'swift', 'host'))
        if not os.path.exists(os.path.join(host_dir, 'SwiftCompilerPlugin.swiftmodule')):
            fail(f'{tname}: macro target needs isim\'s SwiftCompilerPlugin ({host_dir} is missing; build isim)')
        for d in t.get('dependencies', []):
            name = (d.get('byName') or d.get('target') or d.get('product') or [''])[0]
            if name not in SWIFT_SYNTAX_HOST and name != 'SwiftCompilerPlugin':
                fail(f'{tname}: macro target dependency {name!r} is not available: isim builds macros against the '
                     f'Swift toolchain\'s swift-syntax ({", ".join(sorted(SWIFT_SYNTAX_HOST))}) and SwiftCompilerPlugin')
        src = os.path.join(pkg_dir, t.get('path') or os.path.join('Sources', tname))
        excluded = [os.path.normpath(os.path.join(src, e)) for e in t.get('exclude', [])]
        srcs = sorted(os.path.join(d, f) for d, _, fs in os.walk(src) for f in fs if f.endswith('.swift')
                      and not any(os.path.join(d, f).startswith(e) for e in excluded))
        if not srcs:
            fail(f'{tname}: macro target without Swift sources in {src}')
        outdir = os.path.join(self.b.outdir, 'obj', 'packages', 'plugins')
        os.makedirs(outdir, exist_ok=True)
        lib = os.path.join(outdir, f'lib{tname}.so')
        if not os.path.exists(lib) or os.path.getmtime(lib) < max(os.path.getmtime(f) for f in srcs):
            log(f'{tname}: macro target, built as a compiler plugin (lib{tname}.so, the toolchain\'s swift-syntax)')
            _, flags, _ = self.settings_of(t, 'swift')
            libs = [f'-l{n}' for n in sorted(SWIFT_SYNTAX_HOST)]
            r = subprocess.run(['docker', 'run', '--rm', '-u', f'{os.getuid()}:{os.getgid()}', '-e', 'HOME=/tmp',
                                '--mount', f'type=bind,src={src},dst={src},readonly',
                                '--mount', f'type=bind,src={host_dir},dst={host_dir},readonly',
                                '--mount', f'type=bind,src={outdir},dst={outdir}', '-w', '/tmp', 'swift:6.2',
                                'swiftc', '-O', '-emit-library', '-parse-as-library', '-module-name', tname, *flags,
                                '-I', host_dir, '-L', host_dir, '-I', '/usr/lib/swift/host', '-L', '/usr/lib/swift/host',
                                '-lSwiftCompilerPlugin', *libs, '-Xlinker', '-rpath', '-Xlinker', '/usr/lib/swift/host',
                                '-Xlinker', '-rpath', '-Xlinker', host_dir, '-o', lib, *srcs], capture_output=True, text=True)
            if r.returncode:
                fail(f'{tname}: building the macro plugin failed:\n{r.stdout}{r.stderr}')
        res = self.empty()
        res['swift_flags'] += ['-load-plugin-library', lib]
        return res

    def product_of_dependency(self, pkg_dir, dep_dirs, pname, ident):
        cands = [dep_dirs[ident.lower()]] if ident and ident.lower() in dep_dirs else list(dep_dirs.values())
        for c in cands:
            if isinstance(c, tuple):
                continue
            if any(p['name'] == pname for p in self.manifest(c).get('products', [])):
                return self.product(c, pname)
        missing = [c[1] for c in dep_dirs.values() if isinstance(c, tuple)]
        fail(f'package {os.path.basename(pkg_dir)}: product {pname!r} not found in its dependencies'
             + (f' (not available locally: {", ".join(missing)}; use -package-cache DIR)' if missing else ''))

    def binary_target(self, pkg_dir, m, t):
        res = self.empty()
        path = t.get('path')
        if not path:
            url = t.get('url', '')
            for d in self.cache_dirs():
                for cand in (os.path.join(d, 'artifacts', m['name'].lower(), t['name'], t['name'] + '.xcframework'),
                             os.path.join(d, 'artifacts', m['name'].lower(), t['name'] + '.xcframework'),
                             os.path.join(d, t['name'] + '.xcframework')):
                    if os.path.isdir(cand) and not path:
                        path = cand
            if not path:
                path = self.download_artifact(m, t)
        full = path if os.path.isabs(path) else os.path.join(pkg_dir, path)
        self.b.add_binary(full, res)
        log(f'{t["name"]}: binary target {os.path.basename(full)}')
        return res

    def download_artifact(self, m, t):
        """A remote binary target: the zip at its url, verified against its checksum (SHA-256, what
        `swift package compute-checksum` prints), extracted into <fetch dir>/artifacts/<package>/<target>/."""
        import hashlib
        import urllib.request
        url, want = t.get('url', ''), (t.get('checksum') or '').lower()
        dest = os.path.join(self.fetch_dir(), 'artifacts', m['name'].lower(), t['name'])
        stamp = os.path.join(dest, '.isim-checksum')
        if not (os.path.exists(stamp) and open(stamp).read().strip() == want):
            os.makedirs(dest, exist_ok=True)
            zpath = os.path.join(dest, os.path.basename(url.split('?')[0]) or 'artifact.zip')
            log(f'{t["name"]}: downloading {url}')
            try:
                with urllib.request.urlopen(url, timeout=120) as r, open(zpath, 'wb') as f:
                    shutil.copyfileobj(r, f)
            except Exception as e:  # noqa: BLE001
                fail(f'binary target {t["name"]}: cannot download {url}: {e}')
            h = hashlib.sha256()
            with open(zpath, 'rb') as f:
                for chunk in iter(lambda: f.read(1 << 20), b''):
                    h.update(chunk)
            if want and h.hexdigest() != want:
                os.remove(zpath)
                fail(f'binary target {t["name"]}: checksum of {url} is {h.hexdigest()}, the package declares {want}')
            for e in os.listdir(dest):
                if e.endswith('.xcframework'):
                    shutil.rmtree(os.path.join(dest, e), ignore_errors=True)
            extract_zip(zpath, dest)
            os.remove(zpath)
            with open(stamp, 'w') as f:
                f.write(want + '\n')
            log(f'{t["name"]}: checksum verified ({want[:12]}...)')
        for dp, dn, _ in os.walk(dest):
            for d in dn:
                if d.endswith('.xcframework'):
                    return os.path.join(dp, d)
        fail(f'binary target {t["name"]}: {url} has no .xcframework')

    def settings_of(self, t, tool):
        """(defines, flags, header paths) of a package target for tool 'swift' or 'c'/'cxx'."""
        defines, flags, headers = [], [], []
        for s in t.get('settings', []):
            if s.get('tool') not in ((tool,) if tool == 'swift' else ('c', 'cxx')):
                continue
            cond = s.get('condition') or {}
            plats = cond.get('platformNames')
            if plats and 'ios' not in plats:
                continue
            if cond.get('config') and cond['config'] != self.b.configuration.lower():
                continue
            kind = s.get('kind', {})
            if 'define' in kind:
                defines.append(kind['define']['_0'])
            elif 'unsafeFlags' in kind:
                flags += kind['unsafeFlags']['_0']
            elif 'headerSearchPath' in kind:
                headers.append(kind['headerSearchPath']['_0'])
            elif 'enableUpcomingFeature' in kind:
                flags += ['-enable-upcoming-feature', kind['enableUpcomingFeature']['_0']]
            elif 'enableExperimentalFeature' in kind:
                flags += ['-enable-experimental-feature', kind['enableExperimentalFeature']['_0']]
        return defines, flags, headers

    def source_target(self, pkg_dir, m, t, deps):
        tname = t['name']
        res = self.empty()
        default_dir = 'Tests' if t.get('type') == 'test' else 'Sources'
        src = os.path.join(pkg_dir, t.get('path') or os.path.join(default_dir, tname))
        excluded = [os.path.normpath(os.path.join(src, e)) for e in t.get('exclude', [])]
        res_paths = [os.path.normpath(os.path.join(src, r['path'])) for r in t.get('resources', [])]
        explicit = [os.path.normpath(os.path.join(src, s)) for s in (t.get('sources') or [])]

        def wanted(f):
            if any(f == e or f.startswith(e + os.sep) for e in excluded + res_paths):
                return False
            return not explicit or any(f == s or f.startswith(s + os.sep) for s in explicit)
        files = sorted(os.path.join(dp, f) for dp, dn, fs in os.walk(src) for f in fs
                       if not f.startswith('.') and wanted(os.path.join(dp, f)))
        swift = [f for f in files if f.endswith('.swift')]
        csrc = [f for f in files if f.endswith(('.c', '.m', '.mm', '.cpp', '.cc'))]
        objdir = os.path.join(self.b.outdir, 'obj', 'Packages', m['name'], tname)
        os.makedirs(objdir, exist_ok=True)
        modules = self.b.modules_dir
        # resources -> <Package>_<Target>.bundle with a generated Bundle.module accessor
        bundle_name = f'{m["name"]}_{tname}.bundle'
        auto = [f for f in files if f.endswith(('.xcassets', '.xcstrings', '.xcdatamodeld', '.storyboard', '.xib'))]
        metal = [f for f in files if f.endswith('.metal')]
        if t.get('resources') or auto or metal:
            bundle = os.path.join(self.b.outdir, bundle_name)
            shutil.rmtree(bundle, ignore_errors=True)
            os.makedirs(bundle)
            for r in t.get('resources', []):
                p = os.path.normpath(os.path.join(src, r['path']))
                rule = next(iter(r.get('rule', {'process': {}})))
                if rule == 'copy' or not os.path.isdir(p):
                    self.b.install_resource(p, bundle)
                else:                                # process: a directory's files land at the bundle's top level
                    for dp, dn, fs in os.walk(p):
                        keep = []
                        for d in dn:
                            if d.endswith(('.xcassets', '.lproj', '.bundle', '.xcdatamodeld', '.scnassets')):
                                self.b.install_resource(os.path.join(dp, d), bundle)
                            else:
                                keep.append(d)
                        dn[:] = keep
                        for f in fs:
                            if not f.startswith('.'):
                                self.b.install_resource(os.path.join(dp, f), bundle)
            compile_metal(metal, bundle)
            with open(os.path.join(bundle, 'Info.plist'), 'wb') as f:
                plistlib.dump({'CFBundleIdentifier': f'{m["name"]}.{tname}.resources', 'CFBundleName': bundle_name[:-7],
                               'CFBundlePackageType': 'BNDL', 'CFBundleInfoDictionaryVersion': '6.0'}, f)
            res['bundles'].append(bundle)
            if swift:
                accessor = os.path.join(objdir, 'resource_bundle_accessor.swift')
                with open(accessor, 'w') as f:
                    f.write(RESOURCE_ACCESSOR.replace('@NAME@', bundle_name))
                swift = swift + [accessor]
                gen = generate_asset_symbols(sorted({os.path.join(dp, d) for r in t.get('resources', []) for dp, dn, _ in
                                                     os.walk(os.path.normpath(os.path.join(src, r['path']))) for d in dn if d.endswith('.xcassets')}
                                                    | {os.path.normpath(os.path.join(src, r['path'])) for r in t.get('resources', [])
                                                       if r['path'].rstrip('/').endswith('.xcassets')}), {}, os.path.join(objdir, 'GeneratedAssetSymbols.swift'),
                                             os.path.join(objdir, 'GeneratedAssetSymbols.h'), bundle_expr='Foundation.Bundle.module')
                if gen:
                    swift.append(gen)
            log(f'{tname}: resources -> {bundle_name} (Bundle.module)')
        if csrc:
            include = os.path.join(src, t.get('publicHeadersPath') or 'include')
            defines, flags, headers = self.settings_of(t, 'c')
            cflags = ['-I', include, '-I', src] + [f for h in headers for f in ('-I', os.path.join(src, h))]
            cflags += [f'-D{d}' for d in defines] + deps['cc_flags']
            cflags += ['-DSWIFT_PACKAGE=1'] + (['-DDEBUG=1'] if self.b.configuration == 'Debug' else [])
            for f in csrc:
                o = os.path.join(objdir, os.path.basename(f) + '.o')
                lang = ['-fno-objc-arc'] if f.endswith(('.m', '.mm')) else []     # SwiftPM: no ARC unless asked
                run([ISIM, 'cc', '-Wno-unused-command-line-argument', '-c', f, '-o', o] + lang + cflags + flags)
                res['objs'].append(o)
            # module map for importers (Swift and C): the target's own include/module.modulemap, or a generated one
            mapdir = os.path.join(objdir, 'module')
            os.makedirs(mapdir, exist_ok=True)
            own = os.path.join(include, 'module.modulemap')
            if os.path.exists(own):
                res['swift_flags'] += ['-I', include]
            else:
                umbrella = os.path.join(include, tname, tname + '.h')
                if not os.path.exists(umbrella):
                    umbrella = os.path.join(include, tname + '.h')
                body = f'umbrella header "{umbrella}"' if os.path.exists(umbrella) else f'umbrella "{include}"'
                with open(os.path.join(mapdir, 'module.modulemap'), 'w') as f:
                    f.write(f'module {tname} {{\n  {body}\n  export *\n}}\n')
                res['swift_flags'] += ['-I', mapdir]
            res['swift_flags'] += ['-Xcc', '-I' + include]
            res['cc_flags'] += ['-I', include]
            log(f'{tname}: package C/ObjC target ({len(csrc)} files)')
        if swift:
            version = m.get('toolsVersion', {}).get('_version', '5.9')
            langs = m.get('swiftLanguageVersions') or m.get('swiftLanguageModes') or []
            sv = '6' if int(version.split('.')[0]) >= 6 else '5'
            if langs:
                sv = '6' if '6' in langs else '5'
            defines, flags, _ = self.settings_of(t, 'swift')
            obj = os.path.join(objdir, f'{tname}.o')
            cmd = [ISIM, 'swiftc', '-parse-as-library', '-module-name', tname, '-swift-version', sv, '-D', 'SWIFT_PACKAGE',
                   '-I', modules, '-emit-module', '-emit-module-path', os.path.join(modules, tname + '.swiftmodule'),
                   '-wmo', '-c', '-o', obj] + self.b.swift_opt_flags() + deps['swift_flags'] + flags
            if self.b.configuration == 'Debug':
                cmd += ['-D', 'DEBUG', '-enable-testing']
            for d in defines:
                cmd += ['-D', d]
            log(f'{tname}: package target ({len(swift)} Swift files)')
            run(cmd + swift)
            res['objs'].append(obj)
        if not swift and not csrc:
            log(f'{tname}: package target has no sources')
        return res


RESOURCE_ACCESSOR = '''import Foundation

private final class _IsimBundleFinder {}

extension Foundation.Bundle {
    /// The resource bundle of this package target (generated by isim build, like SwiftPM's accessor).
    static let module: Bundle = {
        let name = "@NAME@"
        var candidates: [String] = [Bundle.main.bundlePath, Bundle(for: _IsimBundleFinder.self).bundlePath]
        for dir in candidates {
            if let b = Bundle(path: (dir as NSString).appendingPathComponent(name)) { return b }
        }
        fatalError("unable to find bundle named \\(name)")
    }()
}
'''


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


def game_center_configuration(project):
    """isim's local Game Center configuration (leaderboards, sets, achievements; see docs/GAMECENTER.md):
    an isim-GameCenter.json next to the .xcodeproj or up to two folders below it."""
    top = os.path.dirname(project.xcodeproj)
    found = []
    for dirpath, dirnames, filenames in os.walk(top):
        rel = os.path.relpath(dirpath, top)
        depth = 0 if rel == '.' else rel.count(os.sep) + 1
        dirnames[:] = [] if depth >= 2 else [d for d in dirnames if not d.startswith('.') and not d.endswith(('.xcodeproj', '.xcassets'))
                                              and d not in ('build', 'DerivedData', 'Pods', 'node_modules')]
        if 'isim-GameCenter.json' in filenames:
            found.append((depth, os.path.join(dirpath, 'isim-GameCenter.json')))
    return min(found)[1] if found else None


# ---------------- Info.plist ----------------
# alternate app icons from the asset catalog (Xcode: "Include All App Icon Assets" or an explicit list)
def apply_alternate_icons(s, bundle, info, name):
    alt_names = str(s.get('ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES', '')).split()
    assets_index = os.path.join(bundle, 'isim-assets.json')
    if not os.path.exists(assets_index):
        return
    with open(assets_index) as f:
        icon_sets = json.load(f).get('appIcons', {})
    primary = s.get('ASSETCATALOG_COMPILER_APPICON_NAME', 'AppIcon')
    if str(s.get('ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS', 'NO')).upper() == 'YES':
        alt_names = [n for n in icon_sets if n != primary]
    alt = {n: {'CFBundleIconName': n} for n in alt_names if n in icon_sets}
    if alt:
        icons = info.setdefault('CFBundleIcons', {})
        icons.setdefault('CFBundlePrimaryIcon', {'CFBundleIconName': primary})
        icons.setdefault('CFBundleAlternateIcons', {}).update(alt)
        with open(os.path.join(bundle, 'Info.plist'), 'wb') as f:
            plistlib.dump(info, f)
        log(f'{name}: alternate app icons {", ".join(sorted(alt))}')


# entitlements (associated domains, app groups, keychain groups) as Xcode's simulator builds have them: archived-expanded-entitlements.xcent
# (isim enforces app groups and keychain access groups from it; nothing is signed)
def apply_entitlements(target, s, bundle):
    if not s.get('CODE_SIGN_ENTITLEMENTS'):
        return
    ent = os.path.join(target.p.root, expand(s['CODE_SIGN_ENTITLEMENTS'], s))
    if os.path.exists(ent):
        with open(ent, 'rb') as f:
            ent_plist = plistlib.load(f)
        # $(AppIdentifierPrefix) / $(TeamIdentifierPrefix) are "TEAM." with DEVELOPMENT_TEAM (Xcode gets them from the
        # provisioning profile); isim signs nothing, so without a team they are empty
        team = s.get('DEVELOPMENT_TEAM', '')
        vs = dict(s, AppIdentifierPrefix=f'{team}.' if team else '', TeamIdentifierPrefix=f'{team}.' if team else '')

        def exp(v):
            if isinstance(v, str):
                return expand(v, vs)
            if isinstance(v, list):
                return [exp(x) for x in v]
            if isinstance(v, dict):
                return {k: exp(x) for k, x in v.items()}
            return v
        with open(os.path.join(bundle, 'archived-expanded-entitlements.xcent'), 'wb') as f:
            plistlib.dump(exp(ent_plist), f)


def make_info_plist(target, settings, bundle, extra_localizations, package_type='APPL'):
    src = settings.get('INFOPLIST_FILE')
    info = {}
    if src:
        with open(os.path.join(target.p.root, src), 'rb') as f:
            info = plistlib.load(f)
    elif settings.get('GENERATE_INFOPLIST_FILE') != 'YES' and package_type in ('APPL', 'XPC!'):
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
    if package_type:
        info.setdefault('CFBundlePackageType', package_type)
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
PRODUCT_KINDS = [   # productType suffix -> (kind, wrapper extension, CFBundlePackageType)
    ('.application.on-demand-install-capable', 'app', '.app', 'APPL'),   # App Clips
    ('.application', 'app', '.app', 'APPL'),
    ('.app-extension', 'appex', '.appex', 'XPC!'),
    ('.extensionkit-extension', 'appex', '.appex', 'XPC!'),
    ('.framework.static', 'staticframework', '.framework', 'FMWK'),
    ('.framework', 'framework', '.framework', 'FMWK'),
    ('.library.static', 'static', '.a', None),
    ('.library.dynamic', 'dylib', '.dylib', None),
    ('.bundle.unit-test', 'xctest', '.xctest', 'BNDL'),
    ('.bundle.ui-testing', 'uitest', '.xctest', 'BNDL'),
    ('.bundle', 'bundle', '.bundle', 'BNDL'),
]


def product_kind(ptype):
    for suffix, kind, ext, pkg in PRODUCT_KINDS:
        if ptype.endswith(suffix):
            return kind, ext, pkg
    return None, None, None


class Builder:
    def __init__(self, projects, configuration, outdir, overrides=None, package_cache=(), run_scripts=True):
        self.projects = [p if isinstance(p, Project) else Project(p) for p in projects]
        self.configuration = configuration
        self.outdir = outdir                                   # $(BUILT_PRODUCTS_DIR)
        self.modules_dir = outdir                              # Swift modules of libraries/packages live here, like Xcode
        self.overrides = overrides or {}
        self.package_cache = [os.path.abspath(d) for d in package_cache]
        self.run_scripts = run_scripts
        self.built = {}                                        # (xcodeproj, target) -> product dict or None
        self.packages = Packages(self)
        self.testing = set()                                   # targets built with -enable-testing (test hosts)

    # -- lookup --
    def project_for(self, path):
        path = os.path.abspath(path)
        for p in self.projects:
            if p.xcodeproj == path:
                return p
        p = Project(path)
        self.projects.append(p)
        return p

    def find_target(self, name, project=None):
        if project is not None and name in project.targets():
            return project.target(name)
        for p in self.projects:
            if name in p.targets():
                return p.target(name)
        fail(f'no target named {name!r} in {", ".join(os.path.basename(p.xcodeproj) for p in self.projects)}')

    def find_product_target(self, filename):
        """The target of any project in the build that produces filename (e.g. libPods-App.a, Alamofire.framework)."""
        for p in self.projects:
            for tname, tid in p.targets().items():
                ref = p.objects[tid].get('productReference')
                if ref and os.path.basename(p.objects[ref].get('path', '')) == filename:
                    return p.target(tname)
        return None

    def settings(self, target):
        kind, ext, _ = product_kind(target.product_type)
        out = self.outdir
        objdir = os.path.join(out, 'obj', target.name)
        defaults = {
            'BUILT_PRODUCTS_DIR': out, 'CONFIGURATION_BUILD_DIR': out, 'TARGET_BUILD_DIR': out, 'SYMROOT': out,
            'BUILD_DIR': os.path.join(out, 'Build', 'Products'), 'BUILD_ROOT': os.path.join(out, 'Build', 'Products'),
            'OBJROOT': os.path.join(out, 'obj'), 'TARGET_TEMP_DIR': objdir, 'TEMP_DIR': objdir,
            'PROJECT_TEMP_DIR': os.path.join(out, 'obj'), 'DERIVED_FILE_DIR': os.path.join(objdir, 'DerivedSources'),
            'DERIVED_FILES_DIR': os.path.join(objdir, 'DerivedSources'),
            'SWIFT_OBJC_INTERFACE_HEADER_NAME': '$(PRODUCT_MODULE_NAME)-Swift.h',
            'LD_RUNPATH_SEARCH_PATHS': '', 'SWIFT_VERSION': '5', 'CLANG_ENABLE_OBJC_ARC': 'YES',
            'ENABLE_TESTABILITY': 'YES' if self.configuration == 'Debug' else 'NO',
        }
        s = target.settings(self.configuration, defaults, self.overrides)
        name = s['PRODUCT_NAME']
        wrapper = ('lib' + name + '.a') if kind == 'static' else ('lib' + name + '.dylib' if kind == 'dylib' else name + (ext or ''))
        s.setdefault('WRAPPER_NAME', wrapper)
        s.setdefault('FULL_PRODUCT_NAME', wrapper)
        s.setdefault('CONTENTS_FOLDER_PATH', wrapper)
        s.setdefault('EXECUTABLE_FOLDER_PATH', wrapper)
        s.setdefault('UNLOCALIZED_RESOURCES_FOLDER_PATH', wrapper)
        s.setdefault('FRAMEWORKS_FOLDER_PATH', wrapper + '/Frameworks')
        s.setdefault('PLUGINS_FOLDER_PATH', wrapper + '/PlugIns')
        s.setdefault('EXECUTABLE_PATH', wrapper + '/' + s.get('EXECUTABLE_NAME', name))
        if kind not in ('static', 'dylib'):
            s.setdefault('INFOPLIST_PATH', wrapper + '/Info.plist')
        s.setdefault('TARGET_DEVICE_OS_VERSION', s.get('IPHONEOS_DEPLOYMENT_TARGET', '17.0'))
        return s

    def swift_opt_flags(self, s=None):
        level = (s or {}).get('SWIFT_OPTIMIZATION_LEVEL') or ('-Onone' if self.configuration == 'Debug' else '-O')
        return [level] if level in ('-Onone', '-O', '-Osize', '-Ounchecked') else []

    # -- resources --
    def install_resource(self, res, bundle):
        if res.endswith('.xcstrings'):
            return compile_xcstrings(res, bundle)
        if res.endswith('.xcassets'):
            compile_xcassets(res, bundle)
        elif res.rstrip('/').endswith(('.xcdatamodeld', '.xcdatamodel')):
            momc.compile_model(res, bundle, os.path.join(bundle, '..', 'obj', 'coredata-unused'))
        elif res.endswith(('.storyboard', '.xib')):
            # Interface Builder documents -> isim's IB archive format (NOT Apple's compiled nibs; see ibtool.py)
            parent = os.path.basename(os.path.dirname(res))
            dst = os.path.join(bundle, parent) if parent.endswith('.lproj') else bundle
            os.makedirs(dst, exist_ok=True)
            try:
                out = ibtool.compile_to(res, dst, warn=lambda m: log(f'ibtool: {m}'))
            except ibtool.CompileError as e:
                sys.exit(f'isim build: {e}')
            log(f'{os.path.basename(res)} -> {os.path.relpath(out, bundle)} (isim IB format)')
            if parent.endswith('.lproj') and parent != 'Base.lproj':
                return [parent[:-6]]
        else:
            copy_resource(res, bundle)
            if res.endswith('.lproj'):
                return [os.path.basename(res)[:-6]]
        return []

    # -- binaries --
    def add_binary(self, path, res):
        """Adds a prebuilt .xcframework / .framework / .a / .dylib to a link result dict."""
        name = os.path.basename(path.rstrip('/'))
        if name.endswith('.xcframework'):
            lib, headers = xcframework_slice(path)
            if headers:
                res['cc_flags'] += ['-I', headers]
                res['swift_flags'] += ['-I', headers, '-Xcc', '-I' + headers]
            return self.add_binary(lib, res)
        if name.endswith('.framework'):
            fw = name[:-len('.framework')]
            parent = os.path.dirname(path)
            res['link'] += ['-F', parent, '-framework', fw]
            res['swift_flags'] += ['-F', parent]
            res['cc_flags'] += ['-F', parent]
            kind = macho_kind(os.path.join(path, fw))
            if kind in ('dylib', 'fat'):
                res['embed'].append(path)
            return res
        if name.endswith('.a') or name.endswith('.dylib'):
            res['link'].append(path)
            if name.endswith('.dylib'):
                res['embed'].append(path)
            return res
        fail(f'{path}: unsupported binary dependency')

    # -- building --
    def build(self, target, for_testing=False):
        key = (target.p.xcodeproj, target.name)
        if key in self.built:
            return self.built[key]
        self.built[key] = None                                 # cycle guard
        for dep in target.dependencies():
            self.build(target.p.target(dep))
        for proj, tname in cross_dependencies(target):
            self.build(self.project_for(proj).target(tname))
        for item in target.link_items():                       # implicit dependencies (workspace products)
            if item['kind'] == 'built':
                t = self.find_product_target(item['name'])
                if t:
                    self.build(t)
        s = self.settings(target)
        if for_testing or target.name in self.testing:
            s['ENABLE_TESTABILITY'] = 'YES'
        kind, ext, pkgtype = product_kind(target.product_type)
        if not kind:
            if not target.product_type:
                log(f'{target.name}: aggregate target' + (' (script phases)' if target.script_phases() else ''))
                self.run_script_phases(target, s)
            else:
                log(f'{target.name}: product type {target.product_type} not supported yet (skipped)')
            return None
        test_host = None
        if kind == 'xctest' and s.get('TEST_HOST'):
            host_target = self.find_product_target(os.path.basename(os.path.dirname(s['TEST_HOST'])))
            if host_target:
                self.testing.add(host_target.name)
                self.built.pop((host_target.p.xcodeproj, host_target.name), None)
                test_host = self.build(host_target, for_testing=True)
        if kind == 'uitest' and s.get('TEST_TARGET_NAME'):
            self.build(self.find_target(s['TEST_TARGET_NAME'], target.p))
        product = self.build_product(target, s, kind, ext, pkgtype, test_host)
        self.built[key] = product
        self.publish_product(s, product)
        return product

    def publish_product(self, s, product):
        """isim builds every product into one directory (BUILT_PRODUCTS_DIR); a target with its own
        CONFIGURATION_BUILD_DIR (CocoaPods gives each pod one) also gets its product linked there, where other
        targets' search paths (LIBRARY_SEARCH_PATHS, FRAMEWORK_SEARCH_PATHS) look for it."""
        cbd = os.path.normpath(str(s.get('CONFIGURATION_BUILD_DIR') or self.outdir))
        if not product or cbd == os.path.normpath(self.outdir) or not os.path.isabs(cbd):
            return
        os.makedirs(cbd, exist_ok=True)
        link = os.path.join(cbd, os.path.basename(product['path']))
        if os.path.islink(link) or os.path.isfile(link):
            os.remove(link)
        elif os.path.isdir(link):
            shutil.rmtree(link)
        os.symlink(os.path.relpath(product['path'], cbd), link)

    def build_product(self, target, s, kind, ext, pkgtype, test_host):
        name = target.name
        out = self.outdir
        product_name = s['PRODUCT_NAME']
        module = s['PRODUCT_MODULE_NAME']
        objdir = os.path.join(out, 'obj', name)
        derived = s['DERIVED_FILE_DIR']
        os.makedirs(derived, exist_ok=True)
        path = os.path.join(out, s['WRAPPER_NAME'])
        wrapper = kind not in ('static', 'dylib')
        if wrapper:
            shutil.rmtree(path, ignore_errors=True)
            os.makedirs(path)
        elif os.path.exists(path):
            os.remove(path)
        log(f'{name}: {target.product_type.split(".")[-1] or kind} -> {os.path.relpath(path)}')
        is_framework = kind in ('framework', 'staticframework')
        is_test = kind in ('xctest', 'uitest')
        sources = target.sources()
        swift = [f for f in sources if f.endswith('.swift')]
        csrc = [f for f in sources if f.endswith(('.m', '.mm', '.c', '.cpp', '.cc'))]
        # asset catalogs -> GeneratedAssetSymbols.swift / .h (ImageResource / ColorResource symbols, as Xcode generates)
        catalogs = [r for r in target.resources() if r.rstrip('/').endswith('.xcassets')]
        gen = generate_asset_symbols(catalogs, s, os.path.join(derived, 'GeneratedAssetSymbols.swift'),
                                     os.path.join(derived, 'GeneratedAssetSymbols.h'))
        if gen and swift:
            swift.append(gen)
        # Core Data models (Sources phase in classic projects, resources in folder-synchronized groups)
        models = [f for f in sources + target.resources() if f.rstrip('/').endswith(('.xcdatamodeld', '.xcdatamodel'))
                  and not os.path.dirname(f.rstrip('/')).endswith('.xcdatamodeld')]
        for m in dict.fromkeys(models):
            gen_dir = os.path.join(objdir, 'coredata-codegen', os.path.basename(m.rstrip('/')))
            shutil.rmtree(gen_dir, ignore_errors=True)
            momd, gen = momc.compile_model(m, path, gen_dir)
            swift += gen
            log(f'{name}: Core Data model {os.path.basename(m.rstrip("/"))} -> {os.path.basename(momd)} (isim model format)'
                + (f', {len(gen)} generated Swift files' if gen else ''))

        # what this target links: package products, other targets' products, prebuilt binaries, SDK frameworks
        deps = Packages.empty()
        for pname, ref in target.package_products():
            Packages.merge(deps, self.packages.product_from_project(target.p, pname, ref))
        link_sdk = []
        for item in target.link_items():
            k = item['kind']
            if k == 'package':
                continue
            if k in ('product', 'built'):
                t = target.p.target(item['target']) if k == 'product' else self.find_product_target(item['name'])
                prod = self.built.get((t.p.xcodeproj, t.name)) if t else None
                if not prod:
                    if k == 'built':
                        log(f'{name}: warning: {item["name"]} is not built by any project in this build (skipped)')
                    continue
                Packages.merge(deps, prod['link_result'])
            elif k == 'file':
                if not os.path.exists(item['path']):
                    fail(f'{name}: {item["path"]} not found')
                self.add_binary(item['path'], deps)
            elif k == 'sdk':
                link_sdk.append(item['name'])

        common_cc = ['-I', os.path.join(out, 'include'), '-I', os.path.join(out, 'usr', 'local', 'include'), '-F', out]
        for d in split_setting(s.get('HEADER_SEARCH_PATHS')):
            common_cc += ['-I', d.rstrip('/').removesuffix('/**')]
        for d in split_setting(s.get('FRAMEWORK_SEARCH_PATHS')):
            common_cc += ['-F', d.rstrip('/').removesuffix('/**')]
        defs = [d for d in split_setting(s.get('GCC_PREPROCESSOR_DEFINITIONS'))]
        objs = []
        public_headers = [h for h, vis in target.headers() if vis == 'public']
        private_headers = [h for h, vis in target.headers() if vis == 'private']

        # script phases placed before Headers / Compile Sources (code generators); their outputs with source
        # extensions are compiled, like Xcode's build rules do for script outputs
        # Metal sources (Compile Sources) -> default.metallib in the product (isim's format: the sources)
        metal = [f for f in sources if f.endswith('.metal')]
        if metal and kind not in ('static', 'dylib'):
            compile_metal(metal, os.path.join(path, 'Resources') if kind in ('framework', 'staticframework') and os.path.isdir(os.path.join(path, 'Resources')) else path)
        for f in self.run_script_phases(target, s, 'compile', kind, path):
            if f.endswith('.swift') and f not in swift:
                swift.append(f)
            elif f.endswith(('.m', '.mm', '.c', '.cpp', '.cc')) and f not in csrc:
                csrc.append(f)

        # headers products expose before compiling (consumers and the target's own Swift code import them)
        if is_framework:
            hdir = os.path.join(path, 'Headers')
            for h in public_headers:
                os.makedirs(hdir, exist_ok=True)
                shutil.copy2(h, hdir)
            for h in private_headers:
                os.makedirs(os.path.join(path, 'PrivateHeaders'), exist_ok=True)
                shutil.copy2(h, os.path.join(path, 'PrivateHeaders'))
        elif kind == 'static' and public_headers:
            hdir = os.path.join(out, s['PUBLIC_HEADERS_FOLDER_PATH'].lstrip('/')) if s.get('PUBLIC_HEADERS_FOLDER_PATH') \
                else os.path.join(out, 'include', product_name)
            os.makedirs(hdir, exist_ok=True)
            for h in public_headers:
                shutil.copy2(h, hdir)
        self.copy_phases(target, s, path, before_link=True)

        swift_header = None
        if swift:
            obj = os.path.join(objdir, f'{module}.o')
            cmd = [ISIM, 'swiftc', '-module-name', module, '-wmo', '-c', '-o', obj, '-I', self.modules_dir, '-F', out]
            if not any(os.path.basename(f) == 'main.swift' for f in swift) or kind not in ('app', 'appex'):
                cmd.append('-parse-as-library')                     # Xcode does the same when there is no main.swift
            sv = str(s.get('SWIFT_VERSION', '5')).split('.')[0]
            cmd += ['-swift-version', sv] + self.swift_opt_flags(s)
            if str(s.get('SWIFT_ENABLE_BARE_SLASH_REGEX', 'NO')).upper() == 'YES' and sv < '6':
                cmd.append('-enable-bare-slash-regex')              # Swift 6 has /regex/ literals on by default
            if s.get('ENABLE_TESTABILITY') == 'YES' and (target.name in self.testing or kind not in ('app', 'appex')):
                cmd.append('-enable-testing')
            cmd += split_setting(s.get('OTHER_SWIFT_FLAGS'))
            for cond in split_setting(s.get('SWIFT_ACTIVE_COMPILATION_CONDITIONS')):
                cmd += ['-D', cond]
            for d in split_setting(s.get('SWIFT_INCLUDE_PATHS')):
                cmd += ['-I', d]
            for i in range(0, len(common_cc), 2):
                flag, val = common_cc[i], common_cc[i + 1]
                cmd += ['-F', val] if flag == '-F' else ['-Xcc', '-I' + val]
            for d in defs:
                cmd += ['-Xcc', '-D' + d]
            cmd += deps['swift_flags']
            if kind in ('static', 'staticframework', 'framework', 'dylib') or is_test or target.name in self.testing:
                mod_out = os.path.join(path, 'Modules', module + '.swiftmodule', TRIPLE_MODULE + '.swiftmodule') if is_framework \
                    else os.path.join(self.modules_dir, module + '.swiftmodule')
                if is_framework:
                    os.makedirs(os.path.dirname(mod_out), exist_ok=True)
                cmd += ['-emit-module', '-emit-module-path', mod_out]
            if (csrc or is_framework) and str(s.get('SWIFT_INSTALL_OBJC_HEADER', 'YES')) == 'YES':
                swift_header = os.path.join(derived, s['SWIFT_OBJC_INTERFACE_HEADER_NAME'])
                cmd += ['-emit-objc-header-path', swift_header]
                if '-emit-module' not in cmd:            # else swiftc leaves a temporary <Module>-1.swiftmodule in the cwd
                    cmd += ['-emit-module', '-emit-module-path', os.path.join(objdir, module + '.swiftmodule')]
            bridging = s.get('SWIFT_OBJC_BRIDGING_HEADER')
            if bridging and not is_framework:
                bpath = bridging if os.path.isabs(bridging) else os.path.join(target.p.root, bridging)
                cmd += ['-import-objc-header', bpath, '-Xcc', '-I' + os.path.dirname(bpath)]
            if is_framework and public_headers:
                # the framework's own ObjC API, seen by its Swift code through the umbrella header (like Xcode's
                # unextended module map); the final module map (with the -Swift.h submodule) is written after
                umap = os.path.join(objdir, 'underlying', 'module.modulemap')
                os.makedirs(os.path.dirname(umap), exist_ok=True)
                with open(umap, 'w') as f:
                    f.write(self.module_map_body(module, path, public_headers, None, framework=False))
                cmd += ['-import-underlying-module', '-Xcc', '-fmodule-map-file=' + umap]
            run(cmd + swift)
            objs.append(obj)
        cc_base = common_cc + ['-I', derived] + deps['cc_flags'] + [f'-D{d}' for d in defs]
        if s.get('CLANG_ENABLE_OBJC_ARC', 'YES') != 'YES':
            cc_base.append('-fno-objc-arc')
        if s.get('CLANG_ENABLE_MODULES', 'NO') == 'YES':
            cc_base += ['-fmodules', '-fmodules-cache-path=' + os.path.join(out, 'obj', 'ModuleCache')]
        if s.get('GCC_PREFIX_HEADER'):
            ph = s['GCC_PREFIX_HEADER']
            cc_base += ['-include', ph if os.path.isabs(ph) else os.path.join(target.p.root, ph)]
        if self.configuration == 'Debug':
            cc_base += ['-g']
        cc_base += split_setting(s.get('OTHER_CFLAGS'))
        for f in csrc:
            obj = os.path.join(objdir, os.path.basename(f) + '.o')
            os.makedirs(objdir, exist_ok=True)
            extra = split_setting(s.get('OTHER_CPLUSPLUSFLAGS')) if f.endswith(('.mm', '.cpp', '.cc')) else []
            run([ISIM, 'cc', '-Wno-unused-command-line-argument', '-c', f, '-o', obj, '-I', os.path.dirname(f)] + cc_base + extra)
            objs.append(obj)
        objs += deps['objs']
        self.run_script_phases(target, s, 'link', kind, path)

        # product layout + link
        link_result = Packages.empty()
        exe = None
        if kind in ('static', 'staticframework'):
            lib = path if kind == 'static' else os.path.join(path, s['EXECUTABLE_NAME'])
            if os.path.exists(lib):
                os.remove(lib)
            run(['llvm-ar', 'rcs', lib] + objs)
            if kind == 'static':
                link_result['link'].append(lib)
            else:
                link_result['link'] += ['-F', out, '-framework', product_name]
            link_result['link'] += deps['link']
            link_result['embed'] += deps['embed']
            link_result['bundles'] += deps['bundles']
        elif kind != 'bundle' or objs:
            exe = os.path.join(path, s['EXECUTABLE_NAME']) if wrapper else path
            link = [ISIM, 'cc'] + objs + ['-o', exe, '-F', out] + deps['link']
            for fw in ['Foundation', 'UIKit']:
                link += ['-framework', fw]
            products = {p for p, _ in target.package_products()}
            for fw in link_sdk:
                n = fw.replace('.framework', '')
                if n in products or not n or n in ('Foundation', 'UIKit'):
                    continue
                if n.endswith(('.tbd', '.dylib')):
                    lib = n.split('.')[0]
                    if os.path.exists(os.path.join(SDK, 'usr/lib', lib + '.tbd')) or os.path.exists(os.path.join(SDK, 'usr/lib', lib + '.dylib')):
                        link.append('-l' + lib[3:])
                    else:
                        log(f'{name}: {n} is not in the isim SDK (not linked)')
                    continue
                # frameworks isim implements only as Swift modules (SpriteKit, GameplayKit, ...) are autolinked
                if not os.path.isdir(os.path.join(SDK, 'System/Library/Frameworks', n + '.framework')):
                    if not os.path.exists(os.path.join(SDK, 'usr/lib/swift', f'libswift{n}.dylib')):
                        log(f'{name}: framework {n} is not in the isim SDK (not linked)')
                    continue
                link += ['-framework', n]
            if is_test:
                link += ['-framework', 'XCTest', '-bundle']
                if test_host:
                    loader = s.get('BUNDLE_LOADER') or s.get('TEST_HOST')
                    link += ['-bundle_loader', test_host['exe'] if test_host else loader]
            elif kind == 'bundle':
                link.append('-bundle')
            elif kind in ('framework', 'dylib'):
                install = s.get('LD_DYLIB_INSTALL_NAME') or (f'@rpath/{s["WRAPPER_NAME"]}/{s["EXECUTABLE_NAME"]}' if kind == 'framework'
                                                             else f'@rpath/{s["WRAPPER_NAME"]}')
                link += ['-dynamiclib', '-install_name', install]
            if kind == 'appex':
                link += ['-Wl,-e,_NSExtensionMain']
            rpaths = split_setting(s.get('LD_RUNPATH_SEARCH_PATHS'))
            defaults_rp = {'app': ['@executable_path/Frameworks'], 'appex': ['@executable_path/Frameworks', '@executable_path/../../Frameworks'],
                           'framework': ['@executable_path/Frameworks', '@loader_path/Frameworks'],
                           'xctest': ['@executable_path/Frameworks', '@loader_path/Frameworks'],
                           'uitest': ['@executable_path/Frameworks', '@loader_path/Frameworks']}.get(kind, [])
            for rp in dict.fromkeys(rpaths + defaults_rp):
                link += ['-Wl,-rpath,' + rp]
            for d in split_setting(s.get('LIBRARY_SEARCH_PATHS')):
                link += ['-L', d.rstrip('/').removesuffix('/**')]
            for d in split_setting(s.get('FRAMEWORK_SEARCH_PATHS')):
                link += ['-F', d.rstrip('/').removesuffix('/**')]
            link += split_setting(s.get('OTHER_LDFLAGS'))
            if '-lc++' not in link and uses_cxx_runtime(link_inputs(objs, link)):
                link.append('-lc++')
            run(link)
            if kind == 'framework':
                link_result['link'] += ['-F', out, '-framework', product_name]
                link_result['embed'].append(path)
            elif kind == 'dylib':
                link_result['link'].append(path)
                link_result['embed'].append(path)
        if is_framework:
            if swift_header and os.path.exists(swift_header):
                os.makedirs(os.path.join(path, 'Headers'), exist_ok=True)
                shutil.copy2(swift_header, os.path.join(path, 'Headers'))
            if s.get('MODULEMAP_FILE'):
                mm = s['MODULEMAP_FILE']
                os.makedirs(os.path.join(path, 'Modules'), exist_ok=True)
                shutil.copy2(mm if os.path.isabs(mm) else os.path.join(target.p.root, mm), os.path.join(path, 'Modules', 'module.modulemap'))
            elif swift or s.get('DEFINES_MODULE') == 'YES':
                os.makedirs(os.path.join(path, 'Modules'), exist_ok=True)
                with open(os.path.join(path, 'Modules', 'module.modulemap'), 'w') as f:
                    f.write(self.module_map_body(module, path, public_headers, swift_header if swift_header and os.path.exists(swift_header) else None))
            link_result['swift_flags'] += ['-F', out]
        elif kind == 'static' and swift_header and os.path.exists(swift_header):
            inc = os.path.join(out, 'include', product_name)
            os.makedirs(inc, exist_ok=True)
            shutil.copy2(swift_header, inc)
        inc = os.path.join(out, 'include', product_name)
        if kind == 'static' and s.get('DEFINES_MODULE') == 'YES' and not swift and os.path.isdir(inc):
            # an ObjC/C static library that defines a module: a module map over its installed public headers
            hdrs = sorted(h for h in os.listdir(inc) if h.endswith('.h'))
            with open(os.path.join(inc, 'module.modulemap'), 'w') as f:
                f.write(f'module {module} {{\n' + ''.join(f'  header "{h}"\n' for h in hdrs) + '  export *\n}\n')
            link_result['swift_flags'] += ['-I', inc]

        self.run_script_phases(target, s, 'resources', kind, path)

        # resources, Info.plist
        if wrapper:
            localizations = set()
            for res in target.resources():
                if res.rstrip('/').endswith(('.xcdatamodeld', '.xcdatamodel')):
                    continue                                   # compiled above
                if res.startswith('$(BUILT_PRODUCTS_DIR)/'):   # another target's product (e.g. a pod's resource bundle)
                    t = self.find_product_target(os.path.basename(res))
                    prod = self.build(t) if t else None
                    if not prod:
                        log(f'{name}: {os.path.basename(res)} is not built by this build (not copied)')
                        continue
                    res = prod['path']
                localizations.update(self.install_resource(res, path))
            info = make_info_plist(target, s, path, localizations, pkgtype)
            if kind == 'app':
                apply_alternate_icons(s, path, info, name)
            apply_entitlements(target, s, path)
        bundles = deps['bundles']
        if kind in ('app', 'appex', 'xctest', 'uitest', 'framework', 'bundle'):
            for b in bundles:                                  # package resource bundles land in the product
                dst = os.path.join(path, os.path.basename(b))
                shutil.rmtree(dst, ignore_errors=True)
                shutil.copytree(b, dst)
        else:
            link_result['bundles'] += bundles
        if kind == 'app':
            sk = storekit_configuration(target.p, name)
            if sk:
                shutil.copy2(sk, os.path.join(path, 'isim-StoreKitConfiguration.storekit'))
                info['ISIMStoreKitConfiguration'] = 'isim-StoreKitConfiguration.storekit'      # isim-private key
                with open(os.path.join(path, 'Info.plist'), 'wb') as f:
                    plistlib.dump(info, f)
                log(f'{name}: StoreKit local testing with {os.path.basename(sk)} (from the scheme; nothing is charged)')
            gc = game_center_configuration(target.p)
            if gc:
                shutil.copy2(gc, os.path.join(path, 'isim-GameCenter.json'))
                log(f'{name}: local Game Center configuration {os.path.relpath(gc, os.path.dirname(target.p.xcodeproj))}')

        self.run_script_phases(target, s, 'embed', kind, path)
        # embedding: copy-files phases, plus dynamic frameworks of packages / xcframeworks (Xcode embeds those itself)
        self.copy_phases(target, s, path, before_link=False)
        if kind in ('app', 'appex', 'xctest', 'uitest'):
            embedded = {os.path.basename(e) for e in os.listdir(os.path.join(path, 'Frameworks'))} if os.path.isdir(os.path.join(path, 'Frameworks')) else set()
            for e in deps['embed']:
                if os.path.basename(e) not in embedded and (kind == 'app' or (kind != 'appex' and not test_host)):
                    self.embed(e, os.path.join(path, 'Frameworks'))
                    log(f'{name}: embedded {os.path.basename(e)} in Frameworks/')
            if any(t.endswith('.framework') or t.endswith('.dylib') for t in embedded) or deps['embed']:
                pass
        elif kind == 'framework':
            link_result['embed'] += deps['embed']
        if test_host and is_test:
            plugins = os.path.join(test_host['path'], 'PlugIns')        # Xcode: hosted tests live in the host's PlugIns/
            os.makedirs(plugins, exist_ok=True)
            dst = os.path.join(plugins, os.path.basename(path))
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(path, dst)
        self.run_script_phases(target, s, 'end', kind, path)
        if kind == 'app':
            privacy_check(path, lambda m: log(f'{name}: {m}'))
        return {'kind': kind, 'path': path, 'exe': exe, 'module': module, 'target': name, 'settings': s,
                'link_result': link_result, 'test_host': test_host}

    @staticmethod
    def module_map_body(module, fwpath, public_headers, swift_header, framework=True):
        names = [os.path.basename(h) for h in public_headers]
        hdir = os.path.join(fwpath, 'Headers')
        lines = []
        if names:
            umbrella = module + '.h'
            prefix = '' if framework else hdir + '/'
            if umbrella in names:
                lines += [f'  umbrella header "{prefix}{umbrella}"', '  export *', '  module * { export * }']
            else:
                lines += [f'  header "{prefix}{n}"' for n in names] + ['  export *']
        out = ('framework ' if framework else '') + f'module {module} {{\n' + '\n'.join(lines) + '\n}\n'
        if swift_header:
            out += f'\nmodule {module}.Swift {{\n  header "{os.path.basename(swift_header)}"\n  requires objc\n}}\n'
        if not names and swift_header:
            out = f'framework module {module} {{\n  header "{os.path.basename(swift_header)}"\n  requires objc\n}}\n'
        return out

    @staticmethod
    def embed(src, dest_dir):
        os.makedirs(dest_dir, exist_ok=True)
        dst = os.path.join(dest_dir, os.path.basename(src.rstrip('/')))
        if os.path.isdir(src):
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(src, dst, symlinks=True)
            if src.endswith('.framework'):
                for sub in ('Headers', 'PrivateHeaders', 'Modules'):   # RemoveHeadersOnCopy
                    shutil.rmtree(os.path.join(dst, sub), ignore_errors=True)
                exe = os.path.join(dst, os.path.basename(src)[:-len('.framework')])
                if macho_kind(exe) == 'fat':
                    thin_x86_64(exe, exe + '.thin')
                    os.replace(exe + '.thin', exe)
        else:
            thin_x86_64(src, dst)
        return dst

    def copy_phases(self, target, s, path, before_link):
        """Copy-files phases: dstSubfolderSpec 1 wrapper, 6 executables, 7 resources, 10 frameworks, 13 plug-ins,
        16 products directory (dstPath, e.g. include/$(PRODUCT_NAME) for a static library's headers)."""
        for spec, dst_path, items in target.copy_phases():
            dst_path = expand(dst_path, s)
            if spec == '16':
                dest = os.path.join(self.outdir, dst_path)
            else:
                sub = {'1': '', '6': '', '7': '', '10': 'Frameworks', '13': 'PlugIns', '11': 'SharedFrameworks',
                       '12': 'SharedSupport'}.get(spec, '')
                dest = os.path.join(path, sub, dst_path)
            only_files = all(kind == 'file' and not p.endswith(('.framework', '.xcframework', '.dylib', '.appex', '.app'))
                             for kind, p in items)
            if before_link != (spec == '16' and only_files):
                continue                                       # header copies run before compiling, embedding after
            for kind, item in items:
                t = prod = None
                if kind == 'target':
                    t = target.p.target(item)
                    prod = self.build(t)
                    if not prod:
                        continue
                    src = prod['path']
                elif kind == 'built':
                    t = self.find_product_target(item)
                    prod = self.build(t) if t else None
                    if not prod:
                        log(f'{target.name}: {item}: not built by this build (not embedded)')
                        continue
                    src = prod['path']
                else:
                    src = item
                    if src.endswith('.xcframework'):
                        lib, _ = xcframework_slice(src)
                        src = lib
                if not os.path.exists(src):
                    log(f'{target.name}: {src} not found (not copied)')
                    continue
                if os.path.isdir(src) or src.endswith(('.dylib',)):
                    self.embed(src, dest)
                else:
                    os.makedirs(dest, exist_ok=True)
                    shutil.copy2(src, dest)
                if not before_link:
                    log(f'{target.name}: embedded {os.path.basename(src)} in {os.path.relpath(dest, os.path.dirname(path)) if spec != "16" else os.path.relpath(dest, self.outdir)}/')
                if t is not None and prod and t.product_type.endswith('.on-demand-install-capable'):
                    self.check_app_clip(target, s, prod, os.path.join(dest, os.path.basename(src)))

    @staticmethod
    def check_app_clip(parent, ps, clip, embedded):
        """An App Clip embedded in its full app (Xcode's "Embed App Clips" phase, <App>.app/AppClips/): the checks
        Xcode and App Store Connect make that matter on isim, as warnings. isim does not enforce the App Store's App Clip
        size limits."""
        cs = clip['settings']
        pid, cid = ps.get('PRODUCT_BUNDLE_IDENTIFIER', ''), cs.get('PRODUCT_BUNDLE_IDENTIFIER', '')
        where = os.path.relpath(embedded, os.path.dirname(os.path.dirname(os.path.dirname(embedded))))
        if os.path.basename(os.path.dirname(embedded)) != 'AppClips':
            log(f'{parent.name}: warning: App Clip {os.path.basename(embedded)} is embedded outside AppClips/ (iOS looks for it in <App>.app/AppClips)')
        if pid and not cid.startswith(pid + '.'):
            log(f'{parent.name}: warning: the App Clip\'s bundle identifier {cid!r} must start with the full app\'s {pid!r} followed by a dot')
        ent = {}
        xcent = os.path.join(clip['path'], 'archived-expanded-entitlements.xcent')
        if os.path.exists(xcent):
            with open(xcent, 'rb') as f:
                ent = plistlib.load(f)
        parents = [p.split('.', 1)[1] if re.match(r'^[A-Z0-9]{10}\.', p) else p for p in ent.get('com.apple.developer.parent-application-identifiers', [])]
        if pid not in parents:
            log(f'{parent.name}: warning: the App Clip\'s com.apple.developer.parent-application-identifiers entitlement does not name {pid!r}')
        if ent.get('com.apple.developer.on-demand-install-capable') is not True:
            log(f'{parent.name}: warning: the App Clip has no com.apple.developer.on-demand-install-capable entitlement')
        size = sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(clip['path']) for f in fs if not os.path.islink(os.path.join(d, f)))
        log(f'{parent.name}: App Clip {cid or clip["target"]} in {where} ({size / 1e6:.1f} MB uncompressed; isim does not check the App Store size limits)')

    def run_script_phases(self, target, s, stage=None, kind=None, path=None):
        """Shell script phases of the given stage (None: all, e.g. an aggregate target), like Xcode: in their place
        among the build phases, with Xcode's environment (build settings, SCRIPT_INPUT_FILE_n / _LIST_n,
        SCRIPT_OUTPUT_FILE_n / _LIST_n), skipped when every output is newer than every input (unless "Based on
        dependency analysis" is off or there are no outputs), deployment-only phases only with
        DEPLOYMENT_POSTPROCESSING=YES. Returns the outputs of the phases that ran or were up to date."""
        produced = []
        for ph in target.script_phases():
            if stage is not None and ph['stage'] != stage:
                continue
            title = f'{target.name}: script phase "{ph["name"]}"'
            if ph['name'].startswith('[CP] '):
                self.cocoapods_phase(target, s, ph, path)
                continue
            if not self.run_scripts:
                log(f'{title} skipped (-skip-script-phases)')
                continue
            if ph['deployment_only'] and str(s.get('DEPLOYMENT_POSTPROCESSING', 'NO')).upper() != 'YES':
                log(f'{title} skipped: runs only when installing (DEPLOYMENT_POSTPROCESSING=YES)')
                continue
            produced += self.run_script_phase(target, s, ph, title, kind)
        return produced

    def cocoapods_phase(self, target, s, ph, path):
        """CocoaPods' generated "[CP]" phases call macOS tools (rsync, lipo, codesign); isim does what they do itself:
        checks Manifest.lock against Podfile.lock, embeds the frameworks and copies the resources their file lists
        name (products of the Pods project, or vendored frameworks / XCFrameworks), and copies vendored XCFramework
        slices where the Pods xcconfigs look for them."""
        name = ph['name'][5:]
        root = target.p.root

        def resolve(p):
            p = expand(p, s).strip()
            return p if os.path.isabs(p) else os.path.normpath(os.path.join(root, p))
        entries = [resolve(p) for p in ph['inputs']]
        for lp in ph['input_lists']:
            lf = resolve(lp)
            if os.path.exists(lf):
                with open(lf, encoding='utf-8') as f:
                    entries += [resolve(l) for l in (x.strip() for x in f) if l and not l.startswith('#')]
            else:
                log(f'{target.name}: "{ph["name"]}": {lf} not found')
        entries = [e for e in entries if not e.endswith('.sh')]
        if name == 'Check Pods Manifest.lock':
            locks = [e for e in entries if e.endswith(('Podfile.lock', 'Manifest.lock'))]
            if len(locks) == 2 and all(os.path.exists(l) for l in locks):
                if open(locks[0], 'rb').read() != open(locks[1], 'rb').read():
                    fail(f'{target.name}: "{ph["name"]}": The sandbox is not in sync with the Podfile.lock. Run \'pod install\' '
                         'or update your CocoaPods installation.')
                log(f'{target.name}: "{ph["name"]}": Podfile.lock matches Pods/Manifest.lock (checked by isim)')
            else:
                log(f'{target.name}: "{ph["name"]}" skipped: no Podfile.lock / Manifest.lock')
            return

        def product_of(e):
            t = self.find_product_target(os.path.basename(e))
            prod = self.build(t) if t else None
            if prod:
                return prod['path']
            if os.path.exists(e):
                return e
            pods_root = expand('$(PODS_ROOT)', s) or os.path.join(root, 'Pods')
            stem = os.path.splitext(os.path.basename(e))[0]
            for dp, dn, _ in os.walk(pods_root):
                if stem + '.xcframework' in dn:
                    return xcframework_slice(os.path.join(dp, stem + '.xcframework'))[0]
            return None
        if name in ('Embed Pods Frameworks', 'Copy Pods Resources'):
            if not path:
                return
            for e in entries:
                src = product_of(e)
                if not src:
                    log(f'{target.name}: "{ph["name"]}": {os.path.basename(e)} not found (skipped)')
                    continue
                if name == 'Embed Pods Frameworks':
                    self.embed(src, os.path.join(path, 'Frameworks'))
                    log(f'{target.name}: embedded {os.path.basename(src)} in Frameworks/ (isim\'s "{ph["name"]}")')
                else:
                    self.install_resource(src, path)
                    log(f'{target.name}: copied {os.path.basename(src)} into the bundle (isim\'s "{ph["name"]}")')
            return
        if name == 'Copy XCFrameworks':
            dest_root = expand('$(PODS_XCFRAMEWORKS_BUILD_DIR)', s)
            for e in entries:
                if e.endswith('.xcframework') and os.path.isdir(e) and dest_root:
                    lib, headers = xcframework_slice(e)
                    dest = os.path.join(dest_root, os.path.basename(e)[:-len('.xcframework')])
                    os.makedirs(dest, exist_ok=True)
                    self.embed(lib, dest) if os.path.isdir(lib) else shutil.copy2(lib, dest)
                    if headers and os.path.isdir(headers):
                        shutil.copytree(headers, os.path.join(dest, 'Headers'), dirs_exist_ok=True)
                    log(f'{target.name}: {os.path.basename(e)}: x86_64 simulator slice -> {dest} (isim\'s "{ph["name"]}")')
            return
        log(f'{target.name}: "{ph["name"]}" skipped: a CocoaPods phase isim does not replace')

    def run_script_phase(self, target, s, ph, title, kind):
        root = target.p.root
        tmp = s.get('TARGET_TEMP_DIR') or os.path.join(self.outdir, 'obj', target.name)
        os.makedirs(tmp, exist_ok=True)

        def resolve(p):
            p = expand(p, s).strip()
            return p if os.path.isabs(p) else os.path.normpath(os.path.join(root, p))

        def file_lists(paths, what):
            lists, files = [], []
            for i, lp in enumerate(paths):
                src = resolve(lp)
                if not os.path.exists(src):
                    fail(f'{title}: {what} file list {src} not found')
                with open(src, encoding='utf-8') as f:
                    entries = [resolve(l) for l in (x.strip() for x in f) if l and not l.startswith('#')]
                # Xcode hands the script a resolved copy of each .xcfilelist (variables expanded)
                copy = os.path.join(tmp, f'{what.capitalize()}FileList-{ph["id"]}-{i}-{os.path.basename(src)}')
                with open(copy, 'w', encoding='utf-8') as f:
                    f.write(''.join(e + '\n' for e in entries))
                lists.append((src, copy))
                files += entries
            return lists, files
        inputs = [resolve(p) for p in ph['inputs'] if expand(p, s).strip()]
        outputs = [resolve(p) for p in ph['outputs'] if expand(p, s).strip()]
        in_lists, in_listed = file_lists(ph['input_lists'], 'input')
        out_lists, out_listed = file_lists(ph['output_lists'], 'output')
        all_in = inputs + in_listed + [src for src, _ in in_lists]
        all_out = outputs + out_listed
        env = dict(os.environ)
        env.update({k: str(v) for k, v in s.items()})
        env.setdefault('ACTION', 'install' if str(s.get('DEPLOYMENT_POSTPROCESSING', 'NO')).upper() == 'YES' else 'build')
        env.setdefault('BUILD_DIR', self.outdir)
        env.setdefault('BUILD_ROOT', self.outdir)
        if kind not in ('static', 'dylib', None):
            env.setdefault('INFOPLIST_PATH', s['CONTENTS_FOLDER_PATH'] + '/Info.plist')
        env['SCRIPT_INPUT_FILE_COUNT'] = str(len(inputs))
        env['SCRIPT_OUTPUT_FILE_COUNT'] = str(len(outputs))
        for i, p in enumerate(inputs):
            env[f'SCRIPT_INPUT_FILE_{i}'] = p
        for i, p in enumerate(outputs):
            env[f'SCRIPT_OUTPUT_FILE_{i}'] = p
        env['SCRIPT_INPUT_FILE_LIST_COUNT'] = str(len(in_lists))
        env['SCRIPT_OUTPUT_FILE_LIST_COUNT'] = str(len(out_lists))
        for i, (_, copy) in enumerate(in_lists):
            env[f'SCRIPT_INPUT_FILE_LIST_{i}'] = copy
        for i, (_, copy) in enumerate(out_lists):
            env[f'SCRIPT_OUTPUT_FILE_LIST_{i}'] = copy
        # dependency analysis: what Xcode compares (inputs vs outputs), plus the phase itself (script, file lists)
        import hashlib
        stamp = os.path.join(tmp, f'Script-{ph["id"]}.stamp')
        digest = hashlib.sha256(json.dumps([ph['shell'], ph['script'], all_in, all_out]).encode()).hexdigest()
        reason = None
        if ph['always']:
            reason = 'always'
        elif not all_out:
            log(f'{title}: warning: will be run during every build because it does not specify any outputs. To address '
                'this warning, either add output dependencies to the script phase, or configure it to run in every build '
                'by unchecking "Based on dependency analysis" in the script phase.')
            reason = 'no outputs'
        else:
            missing_in = [p for p in all_in if not os.path.exists(p)]
            if missing_in:
                fail(f'{title}: Build input file cannot be found: \'{missing_in[0]}\'. Did you forget to declare this file '
                     'as an output of a script phase or custom build rule which produces it?')
            prev = open(stamp).read().strip() if os.path.exists(stamp) else None
            if prev != digest:
                reason = 'changed' if prev else 'first build'
            elif any(not os.path.exists(p) for p in all_out):
                reason = 'outputs missing'
            elif all_in and max(os.path.getmtime(p) for p in all_in) > min(os.path.getmtime(p) for p in all_out):
                reason = 'inputs changed'
        if reason is None:
            log(f'{title} skipped: outputs are up to date (dependency analysis)')
            return all_out
        shell = shlex.split(ph['shell'] or '/bin/sh') or ['/bin/sh']
        if not os.path.exists(shell[0]):
            log(f'{title}: {shell[0]} is not on this system; running it with /bin/sh')
            shell = ['/bin/sh']
        script = os.path.join(tmp, f'Script-{ph["id"]}.sh')
        with open(script, 'w', encoding='utf-8') as f:
            f.write(ph['script'])
        log(f'{title} ({reason})')
        sys.stdout.flush()
        r = subprocess.run(shell + [script], env=env, cwd=root)
        if r.returncode:
            if os.path.exists(stamp):
                os.remove(stamp)
            fail(f'{title}: Command PhaseScriptExecution failed with a nonzero exit code ({r.returncode})')
        with open(stamp, 'w') as f:
            f.write(digest + '\n')
        return all_out


def open_container(project=None, workspace=None):
    """-> (projects, containers for schemes)."""
    if workspace:
        ws = Workspace(workspace)
        if not ws.projects:
            fail(f'{workspace}: no projects')
        return ws.projects, [ws.path] + ws.projects
    if not project:
        found = sorted(f for f in os.listdir('.') if f.endswith(('.xcworkspace', '.xcodeproj')))
        ws = [f for f in found if f.endswith('.xcworkspace')]
        if ws:
            return open_container(workspace=ws[0])
        if not found:
            fail('no -project or -workspace given, and none in the current directory')
        project = found[0]
    return [os.path.abspath(project)], [os.path.abspath(project)]


def parse_overrides(rest):
    out = {}
    for a in rest:
        m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*(?:\[[^\]]*\])*)=(.*)$', a)
        if not m:
            fail(f'unexpected argument {a!r}')
        out[m.group(1)] = m.group(2)
    return out


# ---------------- project view (xcodebuild -list / -showBuildSettings, isim project) ----------------
def list_info(projects, containers, workspace, as_json):
    """xcodebuild -list: targets, build configurations and schemes of the project (or the schemes of a workspace)."""
    schemes = sorted(scheme_files(containers))
    if workspace:
        if not schemes:                              # Xcode autocreates a scheme per target
            schemes = sorted({t for p in projects for t in Project(p).targets()})
        name = os.path.splitext(os.path.basename(workspace))[0]
        if as_json:
            print(json.dumps({'workspace': {'name': name, 'schemes': schemes}}, indent=2))
            return
        print(f'Information about workspace "{name}":')
        print('    Schemes:')
        for n in schemes:
            print(f'        {n}')
        return
    proj = Project(projects[0])
    targets = list(proj.targets())
    configs = proj.configurations()
    schemes = schemes or targets
    name = os.path.splitext(os.path.basename(proj.xcodeproj))[0]
    if as_json:
        print(json.dumps({'project': {'configurations': configs, 'name': name, 'schemes': schemes, 'targets': targets}}, indent=2))
        return
    print(f'Information about project "{name}":')
    print('    Targets:')
    for t in targets:
        print(f'        {t}')
    print('\n    Build Configurations:')
    for c in configs:
        print(f'        {c}')
    print('\n    If no build configuration is specified and -scheme is not passed then "Debug" is used (isim build).')
    print('\n    Schemes:')
    for n in schemes:
        print(f'        {n}')


def show_build_settings(b, targets, as_json):
    """xcodebuild -showBuildSettings: the resolved build settings of each target, as isim build uses them."""
    out = []
    for t in targets:
        st = b.settings(t)
        st.setdefault('ACTION', 'build')
        out.append({'action': 'build', 'target': t.name, 'buildSettings': {k: str(v) for k, v in sorted(st.items())}})
    if as_json:
        print(json.dumps(out, indent=2))
        return
    for e in out:
        print(f'Build settings for action build and target {e["target"]}:')
        for k, v in e['buildSettings'].items():
            print(f'    {k} = {v}')
        print()


def print_tree(projects, workspace=None):
    """isim project: a tree of the projects' targets -> build phases -> files (Xcode's project navigator, as text)."""
    def rel(p, root):
        if not isinstance(p, str) or p.startswith('$('):
            return p
        r = os.path.relpath(p, root)
        return p if r.startswith('../../') else r
    lines = [os.path.basename(workspace)] if workspace else []
    for pi, path in enumerate(projects):
        proj = Project(path)
        root = proj.root
        last_p = pi == len(projects) - 1
        pre = ('└── ' if last_p else '├── ') if workspace else ''
        ind = ('    ' if last_p else '│   ') if workspace else ''
        lines.append(f'{pre}{os.path.basename(proj.xcodeproj)}  (configurations: {", ".join(proj.configurations())})')
        names = list(proj.targets())
        pkgs = [proj.objects[r] for r in proj.project.get('packageReferences', [])]
        for ti, tname in enumerate(names):
            t = proj.target(tname)
            last_t = ti == len(names) - 1 and not pkgs
            lines.append(f'{ind}{"└── " if last_t else "├── "}{tname} ({(t.product_type or "aggregate").split(".")[-1]})')
            tind = ind + ('    ' if last_t else '│   ')
            entries = []
            deps = t.dependencies() + [f'{os.path.basename(pp)}:{n}' for pp, n in cross_dependencies(t)]
            if deps:
                entries.append(('Dependencies', deps))
            prods = [n for n, _ in t.package_products()]
            if prods:
                entries.append(('Swift package products', prods))
            sync = [rel(t.p.path_of(g), root) + '/' for g in t.obj.get('fileSystemSynchronizedGroups', [])]
            if sync:
                entries.append(('Synchronized folders', sync))
            for phid in t.obj.get('buildPhases', []):
                ph = proj.objects[phid]
                isa = ph['isa']
                title = ph.get('name') or PHASE_NAMES.get(isa, isa)
                if isa == 'PBXShellScriptBuildPhase':
                    title = f'Run Script "{ph.get("name", "Run Script")}"'
                    files = [f'in: {x}' for x in ph.get('inputPaths', []) + ph.get('inputFileListPaths', [])]
                    files += [f'out: {x}' for x in ph.get('outputPaths', []) + ph.get('outputFileListPaths', [])]
                    flags = (['always'] if str(ph.get('alwaysOutOfDate', '0')) == '1' else []) + \
                        (['install only'] if str(ph.get('runOnlyForDeploymentPostprocessing', '0')) == '1' else [])
                    if flags:
                        title += f' ({", ".join(flags)})'
                else:
                    if isa == 'PBXCopyFilesBuildPhase':
                        title += f' (dstSubfolderSpec {ph.get("dstSubfolderSpec", "")}' + (f', {ph["dstPath"]}' if ph.get('dstPath') else '') + ')'
                    files = []
                    for bf in ph.get('files', []):
                        b = proj.objects[bf]
                        if b.get('productRef'):
                            files.append(f'{proj.objects[b["productRef"]].get("productName")} (package product)')
                            continue
                        ref = b.get('fileRef')
                        if not ref:
                            continue
                        obj = proj.objects[ref]
                        owner = proj.product_owner(ref)
                        built = owner or obj.get('isa') == 'PBXReferenceProxy' or obj.get('sourceTree') == 'BUILT_PRODUCTS_DIR'
                        shown = os.path.basename(obj.get('path') or obj.get('name', '')) if built else rel(proj.path_of(ref), root)
                        if built and not owner:
                            shown += ' (built product)'
                        attrs = b.get('settings', {}).get('ATTRIBUTES', [])
                        files.append(shown + (f' (product of {owner})' if owner else '') + (f' [{", ".join(attrs)}]' if attrs else ''))
                entries.append((title, files))
            for ei, (title, files) in enumerate(entries):
                last_e = ei == len(entries) - 1
                lines.append(f'{tind}{"└── " if last_e else "├── "}{title}' + (f' ({len(files)})' if files and not title.startswith('Run Script') else ''))
                find = tind + ('    ' if last_e else '│   ')
                for fi, f in enumerate(files):
                    lines.append(f'{find}{"└── " if fi == len(files) - 1 else "├── "}{f}')
        for ki, r in enumerate(pkgs):
            what = r.get('repositoryURL') or r.get('relativePath', '')
            req = r.get('requirement') or {}
            reqs = ' '.join(f'{k}={v}' for k, v in req.items() if k != 'kind')
            lines.append(f'{ind}{"└── " if ki == len(pkgs) - 1 else "├── "}package {what}'
                         + (f' ({req.get("kind")} {reqs})' if req else ' (local)'))
    print('\n'.join(lines))


def main():
    ap = argparse.ArgumentParser(prog='isim build')
    ap.add_argument('-project')
    ap.add_argument('-workspace')
    ap.add_argument('-target', action='append')
    ap.add_argument('-scheme')
    ap.add_argument('-configuration')
    ap.add_argument('-sdk')                        # accepted for xcodebuild compatibility: always the isim simulator SDK
    ap.add_argument('-destination')
    ap.add_argument('-package-cache', action='append', default=[])
    ap.add_argument('-run-script-phases', action='store_true')    # the default now; accepted for older scripts
    ap.add_argument('-skip-script-phases', action='store_true')
    ap.add_argument('-list', action='store_true')
    ap.add_argument('-showBuildSettings', action='store_true')
    ap.add_argument('-json', action='store_true')
    ap.add_argument('-tree', action='store_true')                 # isim project: the project as a tree
    ap.add_argument('-resolvePackageDependencies', action='store_true')
    ap.add_argument('-disableAutomaticPackageResolution', action='store_true')
    ap.add_argument('-onlyUsePackageVersionsFromResolvedFile', action='store_true')
    ap.add_argument('-o', '--output', '-derivedDataPath', dest='output', default=None)
    a, rest = ap.parse_known_args()
    projects, containers = open_container(a.project, a.workspace)
    workspace = os.path.abspath(a.workspace) if a.workspace else (containers[0] if containers[0].endswith('.xcworkspace') else None)
    if a.list:
        return list_info(projects, containers, workspace, a.json)
    if a.tree:
        return print_tree(projects, workspace)
    overrides = parse_overrides(rest)
    outdir = os.path.abspath(a.output or 'build')                 # like xcodebuild: products next to the project, not in isim
    # isim swiftc runs in a container that sees only isim's own tree writable: let it write the products
    os.environ['ISIM_SWIFTC_WRITABLE'] = ':'.join(filter(None, [os.environ.get('ISIM_SWIFTC_WRITABLE'), outdir]))
    scheme = None
    if a.scheme:
        schemes = scheme_files(containers)
        if a.scheme in schemes:
            scheme = Scheme(*schemes[a.scheme])
    configuration = a.configuration or (scheme.configuration('LaunchAction') if scheme else 'Debug')
    b = Builder(projects, configuration, outdir, overrides, a.package_cache, not a.skip_script_phases)
    b.packages.resolved_file = resolved_file_path(workspace, projects)
    b.packages.automatic = not (a.disableAutomaticPackageResolution or a.onlyUsePackageVersionsFromResolvedFile)
    targets = []
    if a.target:
        targets = [b.find_target(t) for t in a.target]
    elif scheme:
        for r in scheme.build_targets():
            if r['for_running']:
                targets.append(b.find_target(r['target'], b.project_for(r['project']) if r['project'] else None))
    elif a.scheme:                                   # no scheme file: Xcode autocreates a scheme per target
        targets = [b.find_target(a.scheme)]
    else:                                            # default: first application target
        for p in b.projects:
            app = next((n for n, t in p.targets().items() if p.objects[t].get('productType', '').endswith('.application')), None)
            if app:
                targets = [p.target(app)]
                break
        if not targets:
            targets = [b.projects[0].target(next(iter(b.projects[0].targets())))]
    if a.showBuildSettings:
        return show_build_settings(b, targets, a.json)
    os.makedirs(outdir, exist_ok=True)
    if a.resolvePackageDependencies:
        b.packages.resolve_all(b.projects)
        log('resolved package dependencies' + (f' ({b.packages.resolved_file})' if b.packages.resolved_file else ''))
        return
    product = None
    for t in targets:
        product = b.build(t) or product
    log(f'done: {product["path"] if product else "(nothing built)"}')


if __name__ == '__main__':
    main()
