#!/usr/bin/env python3
"""isim test: build an Xcode project's test targets and run them in the isim simulator, like `xcodebuild test`.

  isim test (-project App.xcodeproj | -workspace App.xcworkspace) [-scheme NAME | -target TESTTARGET ...]
            [-testPlan NAME] [-only-test-configuration NAME] [-skip-test-configuration NAME] [-showTestPlans]
            [-configuration Debug] [-only-testing:Target[/Class[/test]]] [-skip-testing:...] [-o OUTDIR (default ./build)]
            [-resultBundlePath DIR] [-package-cache DIR] [--device NAME] [--os 17|18|26|27] [--windowed] [SETTING=VALUE ...]

* unit-test bundles with a TEST_HOST run inside the host app (the app launches, then the tests run in it);
  bundles without one, and UI-test bundles, run in isim's `xctest` runner process. UI tests drive the
  TEST_TARGET_NAME app, which XCUIApplication launches as its own simulator process.
* XCTest (Objective-C and Swift) and Swift Testing (@Test, when the bundle has any) run in the same bundle.
* Output follows Xcode's console format; ends with ** TEST SUCCEEDED ** / ** TEST FAILED ** (exit 65).
* test plans (.xctestplan, a scheme's TestPlans; -testPlan NAME, else the default plan, also when the scheme has no
  Testables): the plan's enabled test targets, skipped / selected tests, its default options and each configuration's
  (environment variables, arguments, language -> ISIM_LANGUAGES, region -> ISIM_LOCALE); the targets run once per
  configuration (-only-test-configuration / -skip-test-configuration). -showTestPlans lists the scheme's plans.
* -resultBundlePath DIR: per bundle a console log, a JUnit XML report (XCTest) and Swift Testing's xUnit XML.
  (isim's results directory; NOT an Xcode .xcresult bundle.)
"""
import importlib.util
import json
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
            'result': None, 'device': None, 'os': None, 'windowed': False, 'targets': [], 'package_cache': [],
            'scripts': True, 'testPlan': None, 'show_plans': False, 'only_configs': [], 'skip_configs': []}
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
        elif a == '-testPlan':
            opts['testPlan'] = nxt; i += 1
        elif a in ('-only-test-configuration', '-skip-test-configuration'):
            opts['only_configs' if a.startswith('-only') else 'skip_configs'].append(nxt); i += 1
        elif a == '-showTestPlans':
            opts['show_plans'] = True
        elif a == '-target':
            opts['targets'].append(nxt); i += 1
        elif a == '-package-cache':
            opts['package_cache'].append(nxt); i += 1
        elif a == '--device':
            opts['device'] = nxt; i += 1
        elif a == '--os':
            opts['os'] = nxt; i += 1
        elif a == '--windowed':
            opts['windowed'] = True
        elif a in ('-skip-script-phases', '-run-script-phases'):
            opts['scripts'] = a == '-run-script-phases'
        elif a == '-destination':                     # always the isim simulator; its OS= picks the iOS version
            for kv in (nxt or '').split(','):
                k, _, v = kv.partition('=')
                if k.strip() == 'OS' and v.strip() not in ('', 'latest'):
                    opts['os'] = v.strip()
            i += 1
        elif a == '-sdk':
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
    if opts['scheme'] and not scheme:
        ib.fail(f'no scheme named {opts["scheme"]}')
    plans = scheme.test_plans() if scheme else []
    if opts['show_plans']:
        print(f'Test plans associated with the scheme "{scheme.name if scheme else ""}":')
        for path, default in plans:
            print(f'\t{os.path.splitext(os.path.basename(path))[0]}{" (default)" if default else ""}')
        return
    plan = None
    if opts['testPlan']:
        named = [p for p, _ in plans if os.path.splitext(os.path.basename(p))[0] == opts['testPlan']]
        if not named:
            ib.fail(f'scheme {scheme.name if scheme else "?"} has no test plan named {opts["testPlan"]} (-showTestPlans lists them)')
        plan = named[0]
    elif plans and scheme and not scheme.testables():
        plan = next((p for p, d in plans if d), plans[0][0])
    configuration = opts['configuration'] or (scheme.configuration('TestAction') if scheme else 'Debug')
    outdir = os.path.abspath(opts['output'] or 'build')          # ./build of the current folder, as isim build
    os.makedirs(outdir, exist_ok=True)
    b = ib.Builder(projects, configuration, outdir, overrides, opts['package_cache'], opts['scripts'])
    b.packages.resolved_file = ib.resolved_file_path(containers[0] if containers[0].endswith('.xcworkspace') else None, projects)

    # which test targets
    testables = []                                   # (Target, skipped identifiers from the scheme)
    env, args = {}, []
    runs = None                                      # a test plan: [(configuration name, testables, env, args)]
    if plan:
        runs = plan_runs(b, plan, scheme, opts)
    elif opts['targets']:
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

    for t, *_ in (testables if runs is None else runs[0][1] if runs else []):
        b.mark_test_host(t)
    results = os.path.abspath(opts['result']) if opts['result'] else None
    if results:
        os.makedirs(results, exist_ok=True)
    failed = False
    for name, ts, renv0, rargs in runs if runs is not None else [(None, [(t, sk, []) for t, sk in testables], env, args)]:
        if name is not None:
            log(f'test plan {os.path.splitext(os.path.basename(plan))[0]}, configuration "{name}"')
        failed |= run_testables(b, ts, renv0, rargs, opts, only, skip, results, configuration,
                                suffix=f'-{name}' if name is not None and len(runs) > 1 else '')
    print('\n** TEST FAILED **' if failed else '\n** TEST SUCCEEDED **', flush=True)
    sys.exit(65 if failed else 0)


def plan_runs(b, plan, scheme, opts):
    """a test plan's runs: per configuration (filtered by -only/-skip-test-configuration) its name, the enabled test
    targets with their skipped and selected tests, and the environment and arguments (default options, then the
    configuration's)"""
    with open(plan) as f:
        p = json.load(f)
    plan_dir = os.path.dirname(os.path.abspath(plan))
    targets = []
    for t in p.get('testTargets', []):
        if t.get('enabled', True) is False:
            continue
        ref = t.get('target', {})
        kind, _, rel = ref.get('containerPath', '').partition(':')
        proj = os.path.normpath(os.path.join(plan_dir, rel)) if kind == 'container' and rel else None
        target = b.find_target(ref.get('name'), b.project_for(proj) if proj else None)
        targets.append((target, [f'{ref.get("name")}/{x}' for x in t.get('skippedTests', [])],
                        [f'{ref.get("name")}/{x}' for x in t.get('selectedTests', [])]))
    if not targets:
        ib.fail(f'test plan {os.path.basename(plan)} has no enabled test targets')

    def options(o):
        env = {e['key']: e.get('value', '') for e in o.get('environmentVariableEntries', []) if e.get('enabled', True) is not False}
        args = [e['argument'] for e in o.get('commandLineArgumentEntries', []) if e.get('enabled', True) is not False]
        if o.get('language'):
            env['ISIM_LANGUAGES'] = o['language']
        if o.get('region'):
            env['ISIM_LOCALE'] = f'{o.get("language", "en").split("-")[0]}_{o["region"]}'
        return env, args
    base_env, base_args = options(p.get('defaultOptions', {}))
    configs = p.get('configurations') or [{'name': 'Default', 'options': {}}]
    runs = []
    for c in configs:
        n = c.get('name', 'Configuration')
        if opts['only_configs'] and n not in opts['only_configs'] or n in opts['skip_configs']:
            continue
        env, args = options(c.get('options', {}))
        runs.append((n, targets, {**base_env, **env}, base_args + args))
    if not runs:
        ib.fail(f'test plan {os.path.basename(plan)}: no configuration left to run')
    return runs


def run_testables(b, testables, env, args, opts, only, skip, results, configuration, suffix=''):
    """build and run test bundles: [(target, skipped identifiers, selected identifiers)]; True when any failed"""
    failed = False
    for target, scheme_skips, selected in testables:
        tname = target.name
        mine = [o for o in only if o.split('/')[0] == tname]          # -only-testing overrides the scheme's skipped tests
        if only and not mine:
            continue
        mine = mine or selected                                      # a test plan's selected tests
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
        if opts['os']:
            renv['ISIM_OS_VERSION'] = opts['os']
        if renv.get('ISIM_OS_VERSION'):              # validate the device + iOS pairing once, like Xcode's destination check
            chk = subprocess.run([RUNTIME, '--os-check'], env=renv, capture_output=True, text=True)
            if chk.returncode:
                sys.stderr.write(chk.stderr); sys.exit(2)
            renv['ISIM_OS_VERSION'] = chk.stdout.strip()
        bundle_base = os.path.splitext(os.path.basename(product['path']))[0]
        # identifiers as Bundle[/Class[/test]] (Xcode's Target/... form, with the bundle's name)
        def ids(lst):
            return ','.join('/'.join([bundle_base] + x.split('/')[1:]) for x in lst if x.split('/')[0] == tname)
        renv['ISIM_XCTEST_ONLY'] = ids(mine)
        renv['ISIM_XCTEST_SKIP'] = ids(skip + ([] if mine else scheme_skips))
        if results:
            renv['ISIM_XCTEST_JUNIT'] = os.path.join(results, bundle_base + suffix + '.junit.xml')
            renv['ISIM_SWIFT_TESTING_XUNIT'] = os.path.join(results, bundle_base + suffix + '.swift-testing.xml')
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
                with open(os.path.join(results, bundle_base + suffix + '.log'), 'w') as lf:
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
    return failed


if __name__ == '__main__':
    main()
