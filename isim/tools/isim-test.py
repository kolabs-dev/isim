#!/usr/bin/env python3
"""isim test: build an Xcode project's test targets and run them in the isim simulator, like `xcodebuild test`.

  isim test (-project App.xcodeproj | -workspace App.xcworkspace) [-scheme NAME | -target TESTTARGET ...]
            [-configuration Debug] [-only-testing:Target[/Class[/test]]] [-skip-testing:...] [-o OUTDIR]
            [-resultBundlePath DIR] [-package-cache DIR] [--device NAME] [--windowed] [SETTING=VALUE ...]

* unit-test bundles with a TEST_HOST run inside the host app (the app launches, then the tests run in it);
  bundles without one, and UI-test bundles, run in isim's `xctest` runner process. UI tests drive the
  TEST_TARGET_NAME app, which XCUIApplication launches as its own simulator process.
* XCTest (Objective-C and Swift) and Swift Testing (@Test, when the bundle has any) run in the same bundle.
* Output follows Xcode's console format; ends with ** TEST SUCCEEDED ** / ** TEST FAILED ** (exit 65).
* -resultBundlePath DIR: per bundle a console log, a JUnit XML report (XCTest) and Swift Testing's xUnit XML.
  (isim's results directory; NOT an Xcode .xcresult bundle.)
"""
import importlib.util
import os
import subprocess
import sys

BIN = os.path.dirname(os.path.realpath(__file__))
_spec = importlib.util.spec_from_file_location('isim_build', os.path.join(BIN, 'isim-build.py'))
ib = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ib)

RUNTIME = os.path.join(BIN, 'isim-runtime')


def log(msg):
    print(f'isim test: {msg}', flush=True)


def main():
    argv = sys.argv[1:]
    only, skip, rest = [], [], []
    opts = {'project': None, 'workspace': None, 'scheme': None, 'configuration': None, 'output': None,
            'result': None, 'device': None, 'windowed': False, 'targets': [], 'package_cache': []}
    i = 0
    while i < len(argv):
        a = argv[i]
        nxt = argv[i + 1] if i + 1 < len(argv) else None
        if a.startswith('-only-testing:'):
            only.append(a.split(':', 1)[1])
        elif a.startswith('-skip-testing:'):
            skip.append(a.split(':', 1)[1])
        elif a in ('-only-testing', '-skip-testing'):
            (only if a == '-only-testing' else skip).append(nxt); i += 1
        elif a in ('-project', '-workspace', '-scheme', '-configuration'):
            opts[a[1:]] = nxt; i += 1
        elif a in ('-o', '-derivedDataPath'):
            opts['output'] = nxt; i += 1
        elif a == '-resultBundlePath':
            opts['result'] = nxt; i += 1
        elif a == '-target':
            opts['targets'].append(nxt); i += 1
        elif a == '-package-cache':
            opts['package_cache'].append(nxt); i += 1
        elif a == '--device':
            opts['device'] = nxt; i += 1
        elif a == '--windowed':
            opts['windowed'] = True
        elif a in ('-sdk', '-destination'):
            i += 1                                   # always the isim simulator
        else:
            rest.append(a)
        i += 1
    projects, containers = ib.open_container(opts['project'], opts['workspace'])
    overrides = ib.parse_overrides(rest)
    scheme = None
    if opts['scheme']:
        schemes = ib.scheme_files(containers)
        if opts['scheme'] in schemes:
            scheme = ib.Scheme(*schemes[opts['scheme']])
    configuration = opts['configuration'] or (scheme.configuration('TestAction') if scheme else 'Debug')
    name0 = os.path.splitext(os.path.basename(opts['workspace'] or projects[0]))[0]
    outdir = os.path.abspath(opts['output'] or os.path.join(BIN, '..', 'projects', name0))
    os.makedirs(outdir, exist_ok=True)
    b = ib.Builder(projects, configuration, outdir, overrides, opts['package_cache'])

    # which test targets
    testables = []                                   # (Target, skipped identifiers from the scheme)
    env, args = {}, []
    if opts['targets']:
        testables = [(b.find_target(t), []) for t in opts['targets']]
    elif scheme:
        env, args = scheme.test_environment()
        for r in scheme.testables():
            t = b.find_target(r['target'], b.project_for(r['project']) if r['project'] else None)
            testables.append((t, [f'{r["target"]}/{s}' for s in r['skipped_tests']]))
        if not testables:
            ib.fail(f'scheme {scheme.name} has no test targets (TestAction > Testables)')
    else:
        for p in b.projects:
            for n, tid in p.targets().items():
                if p.objects[tid].get('productType', '').endswith(('.unit-test', '.ui-testing')):
                    testables.append((p.target(n), []))
        if not testables:
            ib.fail('no test targets found; pass -scheme or -target')

    failed = False
    results = os.path.abspath(opts['result']) if opts['result'] else None
    if results:
        os.makedirs(results, exist_ok=True)
    for target, scheme_skips in testables:
        tname = target.name
        mine = [o for o in only if o.split('/')[0] == tname]          # -only-testing overrides the scheme's skipped tests
        if only and not mine:
            continue
        product = b.build(target)
        if not product or product['kind'] not in ('xctest', 'uitest'):
            log(f'{tname}: not a test bundle (skipped)')
            continue
        renv = dict(os.environ)
        renv.update(env)
        renv['ISIM_HEADLESS'] = '0' if opts['windowed'] else renv.get('ISIM_HEADLESS', '1') or '1'
        if renv['ISIM_HEADLESS'] == '0':
            renv.pop('ISIM_HEADLESS')
        if opts['device']:
            renv['ISIM_DEVICE'] = opts['device']
        bundle_base = os.path.splitext(os.path.basename(product['path']))[0]
        # identifiers as Bundle[/Class[/test]] (Xcode's Target/... form, with the bundle's name)
        def ids(lst):
            return ','.join('/'.join([bundle_base] + x.split('/')[1:]) for x in lst if x.split('/')[0] == tname)
        renv['ISIM_XCTEST_ONLY'] = ids(mine)
        renv['ISIM_XCTEST_SKIP'] = ids(skip + ([] if mine else scheme_skips))
        if results:
            renv['ISIM_XCTEST_JUNIT'] = os.path.join(results, bundle_base + '.junit.xml')
            renv['ISIM_SWIFT_TESTING_XUNIT'] = os.path.join(results, bundle_base + '.swift-testing.xml')
        sdk = ib.SDK
        if product['kind'] == 'xctest' and product.get('test_host'):
            host = product['test_host']
            bundle = os.path.join(host['path'], 'PlugIns', os.path.basename(product['path']))
            renv['ISIM_XCTEST_BUNDLE'] = bundle
            cmd = [RUNTIME, '--root', sdk, host['exe']] + args
            log(f'{tname}: running {os.path.basename(bundle)} in {os.path.basename(host["path"])} ({configuration})')
        else:
            if product['kind'] == 'uitest':
                ttn = product['settings'].get('TEST_TARGET_NAME')
                app = b.built.get((target.p.xcodeproj, ttn)) if ttn else None
                if not app:
                    t = b.find_target(ttn, target.p) if ttn else None
                    app = b.built.get((t.p.xcodeproj, t.name)) if t else None
                if app:
                    renv['ISIM_XCUI_TARGET_APP'] = app['path']
                apps = [p['path'] for p in b.built.values() if p and p['kind'] == 'app']
                renv['ISIM_XCUI_APPS'] = ':'.join(apps)
            cmd = [RUNTIME, '--root', sdk, os.path.join(sdk, 'usr', 'bin', 'xctest'), product['path']]
            log(f'{tname}: running {os.path.basename(product["path"])} in the xctest runner ({configuration})')
        timeout = float(os.environ.get('ISIM_TEST_TIMEOUT', '900'))
        try:
            if results:
                with open(os.path.join(results, bundle_base + '.log'), 'w') as lf:
                    p = subprocess.Popen(cmd, env=renv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace')
                    for line in p.stdout:
                        sys.stdout.write(line); sys.stdout.flush(); lf.write(line)
                    rc = p.wait(timeout=timeout)
            else:
                rc = subprocess.run(cmd, env=renv, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            log(f'{tname}: timed out after {timeout:g} s')
            rc = 1
        if rc != 0:
            failed = True
            if rc not in (1,):
                log(f'{tname}: test process exited with status {rc}')
    print('\n** TEST FAILED **' if failed else '\n** TEST SUCCEEDED **', flush=True)
    sys.exit(65 if failed else 0)


if __name__ == '__main__':
    main()
