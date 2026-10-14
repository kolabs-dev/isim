"""More `isim build` toolchain coverage, on fixtures in tests/fixtures (built at test time into out/test-builds):

- BuildPhases: shell script phases run in their place among the build phases (a code generator before Compile
  Sources writes the Swift file that is compiled; a check before linking; a post-build script after the resources),
  with .xcfilelists and Xcode's environment, are skipped when their outputs are up to date, deployment-only phases
  run only with DEPLOYMENT_POSTPROCESSING=YES, and a failing script fails the build with its output.
- RemotePackages: remote Swift packages fetched with git from local repositories (file:// URLs, no network):
  versions resolved from tags (up to next major, exact), a transitive remote dependency, Package.resolved written in
  Xcode's format and read back (version 1 and 2), -onlyUsePackageVersionsFromResolvedFile, a remote binary target
  downloaded from a local HTTPS server and verified against its checksum.
- VendorSDK: a prebuilt, Xcode-style dynamic .xcframework (Swift with library evolution: only a .swiftinterface,
  no .swiftmodule binary; an ObjC part with Headers and a module map; a fat x86_64+arm64 simulator slice, a device
  slice and dSYMs) linked, embedded (thinned) and run.
- Pods / Carthage: a checked-in workspace laid out like `pod install` output (Pods project, Pods-App xcconfigs, a
  static library pod, a framework pod with a resource bundle, [CP] script phases) and a Carthage/Build XCFramework.
- Project view: `isim build -list` / `-showBuildSettings` (text and -json) and `isim project`.
- Default output: products in ./build of the current folder, also for a project outside the isim tree.
"""
import hashlib
import http.server
import json
import os
import plistlib
import re
import shutil
import ssl
import subprocess
import threading
import zipfile
from pathlib import Path

import pytest
from isimtest import ISIM, ROOT

FIX = ROOT / "tests/fixtures"


def isim(cwd, *args, env=None, timeout=900):
    e = dict(os.environ, **(env or {}))
    p = subprocess.run([str(ISIM), *map(str, args)], cwd=cwd, env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors="replace", timeout=timeout)
    return p.returncode, p.stdout


@pytest.fixture
def work(tmp_path):
    """The build products directory (tmp_path is under out/pytest, inside the isim workspace that isim swiftc's
    container mounts writable)."""
    d = tmp_path / "build"
    d.mkdir()
    return d


def copy_fixture(name, tmp_path):
    dst = tmp_path / name
    shutil.copytree(FIX / name, dst, symlinks=True)
    return dst


# ---------------- default output: ./build of the current folder ----------------
def build_without_output(launch, src):
    """isim build without -o in src: the products land in src/build, nothing in the isim installation."""
    projects = ROOT / "out/projects"
    before = set(projects.glob("*")) if projects.is_dir() else set()
    rc, log = isim(src, "build", "-project", "BuildPhases.xcodeproj")
    assert rc == 0, log[-3000:]
    app_dir = src / "build" / "BuildPhases.app"
    assert log.rstrip().endswith(f"done: {app_dir}"), log[-500:]
    assert (app_dir / "BuildPhases").is_file() and (src / "build/obj/BuildPhases/DerivedSources/Generated.swift").is_file(), \
        "the app and its intermediates (Swift compiled by the container) in ./build"
    after = set(projects.glob("*")) if projects.is_dir() else set()
    assert after == before, "nothing written into the isim installation"
    app = launch(app_dir)
    app.wait_log(r"BuildPhases: Hello from codegen")
    app.quit()


def test_default_output_in_current_folder(launch, tmp_path):
    """Without -o, isim build writes the products to ./build of the folder it runs in (like xcodebuild)."""
    build_without_output(launch, copy_fixture("BuildPhases", tmp_path))


def docker_sees(path):
    """Whether the docker daemon sees this host path (not when the tests themselves run in a container that shares only
    the workspace with the host's docker, as on CI)."""
    marker = path / ".isim-docker-probe"
    marker.write_text("x")
    r = subprocess.run(["docker", "run", "--rm", "--mount", f"type=bind,src={path},dst=/probe,readonly", "swift:6.2",
                        "cat", "/probe/.isim-docker-probe"], capture_output=True, text=True)
    marker.unlink()
    return r.returncode == 0 and r.stdout == "x"


def test_default_output_outside_workspace(launch):
    """A project outside the isim tree: isim swiftc's container mounts the products directory writable."""
    import tempfile
    with tempfile.TemporaryDirectory(prefix="isim-proj-") as d:
        if not docker_sees(Path(d)):
            pytest.skip("the docker daemon cannot see paths outside the isim workspace here (tests in a container)")
        src = Path(d) / "BuildPhases"
        shutil.copytree(FIX / "BuildPhases", src, symlinks=True)
        build_without_output(launch, src)


# ---------------- shell script build phases ----------------
def test_script_phases(launch, tmp_path, work):
    src = copy_fixture("BuildPhases", tmp_path)
    phases_log = work / "obj" / "phases.log"
    build = lambda *a: isim(src, "build", "-project", "BuildPhases.xcodeproj", "-o", work, *a)

    rc, log = build()
    assert rc == 0, log[-3000:]
    # order: codegen before compiling (its Swift output is compiled), the check before linking, post-build after
    # the resources; the deployment-only phase is skipped
    assert phases_log.read_text().splitlines() == [
        "codegen in=1 lists=1 out=1", "check linked=no", "postbuild infoplist=yes exe=yes"], phases_log.read_text()
    assert 'script phase "Install Only" skipped: runs only when installing' in log
    app_dir = work / "BuildPhases.app"
    info = dict(l.split("=", 1) for l in (app_dir / "build-info.txt").read_text().splitlines())
    assert info["SRCROOT"] == str(src) and info["PROJECT_DIR"] == str(src), info
    assert info["BUILT_PRODUCTS_DIR"] == str(work) and info["TARGET_BUILD_DIR"] == str(work), info
    assert info["CONFIGURATION"] == "Debug" and info["PRODUCT_NAME"] == "BuildPhases" and info["TARGET_NAME"] == "BuildPhases"
    assert info["INFOPLIST_PATH"] == "BuildPhases.app/Info.plist" and info["EXECUTABLE_NAME"] == "BuildPhases"
    assert info["CONTENTS_FOLDER_PATH"] == "BuildPhases.app" and info["UNLOCALIZED_RESOURCES_FOLDER_PATH"] == "BuildPhases.app"
    assert info["DERIVED_FILE_DIR"] == str(work / "obj/BuildPhases/DerivedSources") and info["ACTION"] == "build"
    assert info["SCRIPT_INPUT_FILE_COUNT"] == "1" and info["SCRIPT_INPUT_FILE_0"] == str(app_dir / "Info.plist")
    assert info["SCRIPT_OUTPUT_FILE_LIST_COUNT"] == "1"
    generated = work / "obj/BuildPhases/DerivedSources/Generated.swift"
    app = launch(app_dir)
    app.wait_log(r"BuildPhases: Hello from codegen \| vanilla,chocolate,mango \| Debug \| build-info yes")
    app.quit()

    # second build: the code generator's outputs are newer than its inputs -> skipped
    mtime = generated.stat().st_mtime_ns
    rc, log = build()
    assert rc == 0, log[-3000:]
    assert 'script phase "Generate Constants" skipped: outputs are up to date (dependency analysis)' in log, log[-3000:]
    assert 'script phase "Check Before Link" (always)' in log        # "Based on dependency analysis" off
    assert generated.stat().st_mtime_ns == mtime
    assert phases_log.read_text().splitlines()[3:] == ["check linked=no", "postbuild infoplist=yes exe=yes"]

    # an input listed in the .xcfilelist changes -> the generator runs again; installing runs the deployment phase
    (src / "Config/greeting.txt").write_text("Hola\n")
    rc, log = build("DEPLOYMENT_POSTPROCESSING=YES")
    assert rc == 0, log[-3000:]
    assert 'script phase "Generate Constants" (inputs changed)' in log
    assert phases_log.read_text().splitlines()[5:] == ["codegen in=1 lists=1 out=1", "check linked=no",
                                                       "postbuild infoplist=yes exe=yes", "deploy"]
    assert 'static let greeting = "Hola"' in generated.read_text()

    # a failing script fails the build, with its output, before compiling
    (src / "Config/flavors.txt").write_text("lemon\n")
    rc, log = build("FIXTURE_FAIL=YES")
    assert rc != 0 and "error: codegen refused (FIXTURE_FAIL=YES)" in log, log[-3000:]
    assert 'script phase "Generate Constants": Command PhaseScriptExecution failed with a nonzero exit code (3)' in log
    assert len(phases_log.read_text().splitlines()) == 9, "nothing ran after the failing phase"

    # -skip-script-phases: none of them run (the app then lacks its generated code)
    rc, log = build("-skip-script-phases")
    assert 'script phase "Generate Constants" skipped (-skip-script-phases)' in log and rc != 0


# ---------------- remote Swift packages ----------------
def git(*args, cwd):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True,
                   env=dict(os.environ, GIT_AUTHOR_NAME="isim", GIT_AUTHOR_EMAIL="isim@example.invalid",
                            GIT_COMMITTER_NAME="isim", GIT_COMMITTER_EMAIL="isim@example.invalid"))


def make_repo(src, dest, versions, subst):
    """A bare repository at dest with one tagged commit per version; subst(version) -> {placeholder: value}."""
    wt = dest.with_suffix(".work")
    shutil.copytree(src, wt)
    git("init", "-q", "-b", "main", cwd=wt)
    templates = {p: p.read_text() for p in wt.rglob("*") if p.is_file() and ".git" not in p.parts}
    for v in versions:
        for p, text in templates.items():
            for k, x in subst(v).items():
                text = text.replace(k, x)
            p.write_text(text)
        git("add", "-A", cwd=wt)
        git("commit", "-q", "-m", f"version {v}", cwd=wt)
        git("tag", "-a", v, "-m", v, cwd=wt)          # annotated, like most packages' release tags
    git("clone", "-q", "--bare", str(wt), str(dest), cwd=wt.parent)
    shutil.rmtree(wt)


class HTTPS:
    """A local HTTPS server (self-signed certificate for 127.0.0.1) serving a directory: SwiftPM accepts only
    https URLs for binary targets."""

    def __init__(self, root, tmp):
        self.cert = tmp / "cert.pem"
        key = tmp / "key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=127.0.0.1",
                        "-addext", "subjectAltName=IP:127.0.0.1", "-keyout", str(key), "-out", str(self.cert)],
                       check=True, capture_output=True)
        handler = lambda *a, **kw: http.server.SimpleHTTPRequestHandler(*a, directory=str(root), **kw)
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(self.cert, key)
        self.server.socket = ctx.wrap_socket(self.server.socket, server_side=True)
        self.url = f"https://127.0.0.1:{self.server.server_address[1]}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()


def static_xcframework(srcdir, name, dest, work):
    """<name>.xcframework with an x86_64 simulator static library (built with isim cc), headers and module map."""
    sl = dest / "ios-x86_64-simulator"
    (sl / "Headers").mkdir(parents=True)
    obj = work / f"{name.lower()}.o"
    subprocess.run([str(ISIM), "cc", "-c", str(srcdir / f"{name.lower()}.c"), "-o", str(obj)], check=True)
    subprocess.run(["llvm-ar", "rcs", str(sl / f"lib{name}.a"), str(obj)], check=True)
    for f in (f"{name.lower()}.h", "module.modulemap"):
        shutil.copy(srcdir / f, sl / "Headers")
    (dest / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [
        {"HeadersPath": "Headers", "LibraryIdentifier": "ios-x86_64-simulator", "LibraryPath": f"lib{name}.a",
         "SupportedArchitectures": ["x86_64"], "SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator"}],
        "CFBundlePackageType": "XFWK", "XCFrameworkFormatVersion": "1.0"}))


def test_remote_packages(launch, tmp_path, work):
    src = copy_fixture("RemotePackages", tmp_path)
    repos, served = tmp_path / "repos", tmp_path / "served"
    repos.mkdir()
    served.mkdir()
    # the binary target: Vendor.xcframework.zip and its SwiftPM checksum (SHA-256)
    xcf = tmp_path / "zip" / "Vendor.xcframework"
    static_xcframework(src / "packages/Vendor", "Vendor", xcf, work)
    with zipfile.ZipFile(served / "Vendor.xcframework.zip", "w") as z:
        for f in sorted(xcf.rglob("*")):
            z.write(f, f.relative_to(xcf.parent))
    checksum = hashlib.sha256((served / "Vendor.xcframework.zip").read_bytes()).hexdigest()
    server = HTTPS(served, tmp_path)
    try:
        repo_url = f"file://{repos}"
        make_repo(src / "packages/Base", repos / "Base.git", ["1.0.0", "1.1.0"],
                  lambda v: {"@VALUE@": {"1.0.0": "10", "1.1.0": "11"}[v]})
        make_repo(src / "packages/Greet", repos / "Greet.git", ["1.0.0", "1.2.0", "2.0.0"],
                  lambda v: {"@VERSION@": v, "@REPOS@": repo_url, "@ARTIFACTS@": server.url,
                             "@CHECKSUM@": "0" * 64 if v == "2.0.0" else checksum})   # 2.0.0 declares a wrong checksum
        pbx = src / "RemotePackages.xcodeproj/project.pbxproj"
        pbx.write_text(pbx.read_text().replace("@REPOS@", repo_url))
        resolved = src / "RemotePackages.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        cache = tmp_path / "cache"
        env = {"XDG_CACHE_HOME": str(cache), "SSL_CERT_FILE": str(server.cert), "NO_PROXY": "127.0.0.1,localhost",
               "no_proxy": "127.0.0.1,localhost"}
        build = lambda *a: isim(src, "build", "-project", "RemotePackages.xcodeproj", "-o", work, *a, env=env)

        # no Package.resolved: up to next major from 1.0.0 -> Greet 1.2.0; its dependency Base from: 1.0.0 -> 1.1.0
        rc, log = build()
        assert rc == 0, log[-4000:]
        assert "greet: fetching" in log and "Vendor: checksum verified" in log, log[-4000:]
        pins = json.loads(resolved.read_text())
        assert pins["version"] == 2 and {p["identity"]: p["state"]["version"] for p in pins["pins"]} == \
            {"base": "1.1.0", "greet": "1.2.0"}, pins
        assert all(p["kind"] == "remoteSourceControl" and len(p["state"]["revision"]) == 40 for p in pins["pins"])
        assert (cache / "isim/packages/checkouts").is_dir() and (cache / "isim/packages/artifacts/greet/Vendor").is_dir()
        app = launch(work / "RemotePackages.app")
        app.wait_log(r"RemotePackages: greet 1\.2\.0 base 11 vendor 7")
        app.quit()
        rc, log = build("-resolvePackageDependencies")                  # fetch only: everything is cached and pinned
        assert rc == 0 and "isim build: resolved package dependencies" in log and "fetching" not in log, log[-3000:]

        # a version 1 Package.resolved (older Xcode) pins Greet 1.0.0 and Base 1.0.0
        def rev(repo, tag):
            return subprocess.run(["git", "rev-parse", f"{tag}^{{commit}}"], cwd=repos / repo, capture_output=True,
                                  text=True, check=True).stdout.strip()
        resolved.write_text(json.dumps({"object": {"pins": [
            {"package": "Greet", "repositoryURL": f"{repo_url}/Greet.git",
             "state": {"branch": None, "revision": rev("Greet.git", "1.0.0"), "version": "1.0.0"}},
            {"package": "Base", "repositoryURL": f"{repo_url}/Base.git",
             "state": {"branch": None, "revision": rev("Base.git", "1.0.0"), "version": "1.0.0"}}]}, "version": 1}))
        rc, log = build("-onlyUsePackageVersionsFromResolvedFile")
        assert rc == 0, log[-4000:]
        assert "greet: " in log and "pinned 1.0.0 (Package.resolved)" in log, log[-4000:]
        app = launch(work / "RemotePackages.app")
        app.wait_log(r"RemotePackages: greet 1\.0\.0 base 10 vendor 7")
        app.quit()

        # without pins, -onlyUsePackageVersionsFromResolvedFile refuses to resolve
        resolved.unlink()
        rc, log = build("-onlyUsePackageVersionsFromResolvedFile")
        assert rc != 0 and "is not pinned" in log and "automatic package resolution is disabled" in log, log[-3000:]
        assert not resolved.exists()

        # exactVersion 2.0.0, whose binary target declares a wrong checksum: the download is refused
        pbx.write_text(pbx.read_text().replace("kind = upToNextMajorVersion; minimumVersion = 1.0.0;",
                                               "kind = exactVersion; version = 2.0.0;"))
        shutil.rmtree(cache / "isim/packages/artifacts")
        rc, log = build()
        assert rc != 0 and f"Vendor: checksum of {server.url}/Vendor.xcframework.zip is {checksum}, the package declares " \
            + "0" * 64 in log, log[-3000:]
        assert json.loads(resolved.read_text())["pins"][-1]["state"]["version"] == "2.0.0"
    finally:
        server.close()


def test_package_requirements(tmp_path):
    """How requirements resolve against a repository's tags (Xcode's kinds and SwiftPM manifest ones)."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("isim_build", ROOT / "out/bin/isim-build.py")
    ib = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(ib)
    repo = tmp_path / "Lib.git"
    lib = tmp_path / "lib"
    lib.mkdir()
    (lib / "Package.swift").write_text("// @V@\n")
    make_repo(lib, repo, ["1.0.0", "1.0.5", "1.1.0", "v1.4.2", "2.0.0-beta.1", "2.0.0", "3.1.0"], lambda v: {"@V@": v})

    class B:
        package_cache = [str(tmp_path / "cache")]
    pk = ib.Packages(B())
    url = f"file://{repo}"
    mirror = pk.mirror(url, "lib")
    def version(ref_req):
        return pk.resolve(mirror, url, ib.requirement_of_ref({"requirement": ref_req}))[1].get("version")
    assert version({"kind": "upToNextMajorVersion", "minimumVersion": "1.0.0"}) == "1.4.2"     # "v" prefix accepted
    assert version({"kind": "upToNextMinorVersion", "minimumVersion": "1.0.0"}) == "1.0.5"
    assert version({"kind": "exactVersion", "version": "1.1.0"}) == "1.1.0"
    assert version({"kind": "versionRange", "minimumVersion": "1.1.0", "maximumVersion": "3.0.0"}) == "2.0.0"  # no betas
    m = lambda req: pk.resolve(mirror, url, ib.requirement_of_manifest(req))[1]
    assert m({"range": [{"lowerBound": "3.0.0", "upperBound": "4.0.0"}]})["version"] == "3.1.0"
    assert m({"exact": ["1.0.0"]})["version"] == "1.0.0"
    head = subprocess.run(["git", "rev-parse", "main"], cwd=repo, capture_output=True, text=True).stdout.strip()
    assert m({"branch": ["main"]}) == {"branch": "main", "revision": head}
    assert pk.resolve(mirror, url, ib.requirement_of_ref({"requirement": {"kind": "revision", "revision": head}}))[0] == head
    with pytest.raises(SystemExit, match=r"no version tag matches 4\.0\.0\.\.<5\.0\.0"):
        version({"kind": "upToNextMajorVersion", "minimumVersion": "4.0.0"})


# ---------------- project view ----------------
def test_project_view(tmp_path):
    proj = ROOT / "samples/HelloToolchain"
    rc, out = isim(proj, "build", "-project", "HelloToolchain.xcodeproj", "-list")
    assert rc == 0 and out.startswith('Information about project "HelloToolchain":'), out
    sections = re.split(r"\n\s*\n", out)
    assert re.search(r"Targets:\n(\s+\w+\n?)+", sections[0]) and \
        [l.strip() for l in sections[0].splitlines()[2:]] == ["HelloToolchain", "MathKit", "Greeter", "AppTests", "AppUITests",
                                                             "AppSwiftTests"], out
    assert "Build Configurations:\n        Debug\n        Release" in out and "Schemes:\n        HelloToolchain\n        HelloToolchainPlans" in out
    rc, out = isim(proj, "build", "-workspace", "HelloToolchain.xcworkspace", "-list", "-json")
    assert rc == 0 and json.loads(out) == {"workspace": {"name": "HelloToolchain", "schemes": ["HelloToolchain", "HelloToolchainPlans"]}}, out

    rc, out = isim(proj, "build", "-project", "HelloToolchain.xcodeproj", "-target", "Greeter", "-configuration", "Release",
                   "-showBuildSettings")
    assert rc == 0 and out.startswith("Build settings for action build and target Greeter:\n"), out[:500]
    settings = dict(re.findall(r"^    (\w+) = (.*)$", out, re.M))
    assert settings["CONFIGURATION"] == "Release" and settings["PRODUCT_BUNDLE_IDENTIFIER"] == "dev.isim.samples.Greeter"
    assert settings["WRAPPER_NAME"] == "Greeter.framework" and settings["SRCROOT"] == str(proj)
    rc, out = isim(proj, "build", "-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchain",
                   "-showBuildSettings", "-json")
    entries = json.loads(out)
    app = entries[0]["buildSettings"]
    assert rc == 0 and entries[0]["target"] == "HelloToolchain" and app["PRODUCT_BUNDLE_IDENTIFIER"] == \
        "dev.isim.samples.HelloToolchain" and app["INFOPLIST_KEY_ToolchainGreeting"] == "Howdy", "xcconfig settings resolved"

    rc, out = isim(FIX / "BuildPhases", "project", "BuildPhases.xcodeproj")
    assert rc == 0, out
    assert out.splitlines()[:4] == ["BuildPhases.xcodeproj  (configurations: Debug, Release)",
                                    "└── BuildPhases (application)",
                                    '    ├── Run Script "Generate Constants"',
                                    "    │   ├── in: $(SRCROOT)/Config/flavors.txt"], out
    for line in ("    ├── Compile Sources (1)", "    │   └── App/AppDelegate.swift", '    ├── Run Script "Check Before Link" (always)',
                 '    └── Run Script "Install Only" (install only)',
                 "    │   └── out: $(SRCROOT)/Config/postbuild-outputs.xcfilelist"):
        assert line in out.splitlines(), (line, out)
    rc, out = isim(proj, "project", "HelloToolchain.xcworkspace")
    assert rc == 0 and out.splitlines()[0] == "HelloToolchain.xcworkspace" and \
        "    │   │   └── Units (package product)" in out and "    └── package Packages/Units (local)" in out, out


# ---------------- prebuilt dynamic XCFramework (Xcode-style vendor SDK) ----------------
def run(*cmd, cwd=None):
    p = subprocess.run([str(c) for c in cmd], cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert p.returncode == 0, f"{' '.join(map(str, cmd[:4]))} ...\n{p.stdout[-3000:]}"
    return p.stdout


def vendor_xcframework(srcdir, dest, tmp):
    """Vendor.xcframework the way `xcodebuild archive BUILD_LIBRARY_FOR_DISTRIBUTION=YES` + `-create-xcframework`
    lay it out: per slice a dynamic Vendor.framework (Info.plist, Headers + module map for the ObjC API,
    Modules/Vendor.swiftmodule/<triple>.swiftinterface without a binary .swiftmodule) and dSYMs. The simulator
    slice is fat (x86_64 + arm64); the arm64 code is a placeholder (isim builds x86_64 simulator code only)."""
    obj = tmp / "vendor-obj"
    obj.mkdir()
    sim = dest / "ios-arm64_x86_64-simulator"
    dev = dest / "ios-arm64"
    fw = sim / "Vendor.framework"
    for d in (fw / "Headers", fw / "Modules/Vendor.swiftmodule"):
        d.mkdir(parents=True)
    for h in ("Vendor.h", "VNDLegacy.h"):
        shutil.copy(srcdir / h, fw / "Headers")
    (obj / "underlying").mkdir()
    (obj / "underlying/module.modulemap").write_text(f'module Vendor {{\n  umbrella header "{fw}/Headers/Vendor.h"\n  export *\n}}\n')
    framework_map = 'framework module Vendor {\n  umbrella header "Vendor.h"\n  export *\n  module * { export * }\n}\n'
    (fw / "Modules/module.modulemap").write_text(framework_map)     # what verifying the emitted interface imports
    swiftmod = fw / "Modules/Vendor.swiftmodule"
    run(ISIM, "swiftc", "-parse-as-library", "-module-name", "Vendor", "-enable-library-evolution", "-swift-version", "5",
        "-emit-module-interface-path", swiftmod / "x86_64-apple-ios-simulator.swiftinterface",
        "-emit-private-module-interface-path", swiftmod / "x86_64-apple-ios-simulator.private.swiftinterface",
        "-emit-module", "-emit-module-path", obj / "Vendor.swiftmodule", "-emit-objc-header-path", fw / "Headers/Vendor-Swift.h",
        "-import-underlying-module", "-Xcc", f"-fmodule-map-file={obj}/underlying/module.modulemap", "-F", sim,
        "-wmo", "-c", "-o", obj / "Vendor-swift.o", srcdir / "Vendor.swift", cwd=tmp)
    (fw / "Modules/module.modulemap").write_text(framework_map + '\nmodule Vendor.Swift {\n  header "Vendor-Swift.h"\n  requires objc\n}\n')
    run(ISIM, "cc", "-c", srcdir / "VNDLegacy.m", "-I", fw / "Headers", "-o", obj / "VNDLegacy.o")
    run(ISIM, "cc", "-dynamiclib", "-install_name", "@rpath/Vendor.framework/Vendor", obj / "Vendor-swift.o", obj / "VNDLegacy.o",
        "-framework", "Foundation", "-o", obj / "Vendor-x86_64")
    for triple, out in (("arm64-apple-ios17.0-simulator", "Vendor-arm64-sim"), ("arm64-apple-ios17.0", "Vendor-arm64")):
        run("clang", "-target", triple, "-dynamiclib", "-nostdlib", "-install_name", "@rpath/Vendor.framework/Vendor",
            "-fuse-ld=lld", srcdir / "placeholder.c", "-o", obj / out)
    run("llvm-lipo", "-create", obj / "Vendor-x86_64", obj / "Vendor-arm64-sim", "-output", fw / "Vendor")
    for name in ("x86_64-apple-ios-simulator.swiftinterface", "x86_64-apple-ios-simulator.private.swiftinterface"):
        text = (swiftmod / name).read_text()
        (swiftmod / name.replace("x86_64", "arm64")).write_text(text.replace("-target x86_64-apple-ios", "-target arm64-apple-ios"))
    info = {"CFBundleDevelopmentRegion": "en", "CFBundleExecutable": "Vendor", "CFBundleIdentifier": "com.example.Vendor",
            "CFBundleInfoDictionaryVersion": "6.0", "CFBundleName": "Vendor", "CFBundlePackageType": "FMWK",
            "CFBundleShortVersionString": "3.2.1", "CFBundleVersion": "1", "MinimumOSVersion": "17.0",
            "CFBundleSupportedPlatforms": ["iPhoneSimulator"]}
    (fw / "Info.plist").write_bytes(plistlib.dumps(info))
    # the device slice: arm64 iPhoneOS (the placeholder), same headers and interfaces
    shutil.copytree(fw, dev / "Vendor.framework")
    shutil.copy(obj / "Vendor-arm64", dev / "Vendor.framework/Vendor")
    dswift = dev / "Vendor.framework/Modules/Vendor.swiftmodule"
    for f in list(dswift.iterdir()):
        if "x86_64" in f.name:
            f.unlink()
        else:
            f.rename(dswift / f.name.replace("-simulator", ""))
    (dev / "Vendor.framework/Info.plist").write_bytes(plistlib.dumps(dict(info, CFBundleSupportedPlatforms=["iPhoneOS"])))
    for sl, binary in ((sim, fw / "Vendor"), (dev, dev / "Vendor.framework/Vendor")):
        dsym = sl / "dSYMs/Vendor.framework.dSYM/Contents"
        (dsym / "Resources/DWARF").mkdir(parents=True)
        shutil.copy(binary, dsym / "Resources/DWARF/Vendor")
        (dsym / "Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": "com.apple.xcode.dsym.com.example.Vendor",
                                                          "CFBundlePackageType": "dSYM", "CFBundleInfoDictionaryVersion": "6.0"}))
    (dest / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [
        {"BinaryPath": "Vendor.framework/Vendor", "DebugSymbolsPath": "dSYMs", "LibraryIdentifier": "ios-arm64",
         "LibraryPath": "Vendor.framework", "SupportedArchitectures": ["arm64"], "SupportedPlatform": "ios"},
        {"BinaryPath": "Vendor.framework/Vendor", "DebugSymbolsPath": "dSYMs", "LibraryIdentifier": "ios-arm64_x86_64-simulator",
         "LibraryPath": "Vendor.framework", "SupportedArchitectures": ["arm64", "x86_64"], "SupportedPlatform": "ios",
         "SupportedPlatformVariant": "simulator"}], "CFBundlePackageType": "XFWK", "XCFrameworkFormatVersion": "1.0"}))


def test_binary_dynamic_xcframework(launch, tmp_path, work):
    src = copy_fixture("VendorSDK", tmp_path)
    xcf = src / "Frameworks/Vendor.xcframework"
    vendor_xcframework(src / "VendorSource", xcf, tmp_path)
    assert not list(xcf.rglob("*.swiftmodule/*.swiftmodule")), "interfaces only, like a distributed XCFramework"
    assert "x86_64" in run("llvm-lipo", "-archs", xcf / "ios-arm64_x86_64-simulator/Vendor.framework/Vendor")
    rc, log = isim(src, "build", "-project", "VendorSDK.xcodeproj", "-o", work)
    assert rc == 0, log[-4000:]
    emb = work / "VendorApp.app/Frameworks/Vendor.framework"
    assert run("llvm-lipo", "-archs", emb / "Vendor").split() == ["x86_64"], "embedded thinned to the x86_64 slice"
    assert (emb / "Info.plist").is_file() and not (emb / "Headers").exists() and not (emb / "Modules").exists()
    assert not list((work / "VendorApp.app").rglob("*.dSYM")), "dSYMs are not embedded"
    app = launch(work / "VendorApp.app")
    app.wait_log(r"VendorSDK: Vendor 3\.2\.1 greets isim \(legacy score 42\) \| VNDLegacy \| app widget")
    app.quit()


# ---------------- CocoaPods and Carthage ----------------
def test_cocoapods_workspace(launch, tmp_path, work):
    src = copy_fixture("PodsApp", tmp_path)
    build = lambda: isim(src, "build", "-workspace", "App.xcworkspace", "-scheme", "App", "-o", work)
    rc, log = build()
    assert rc == 0, log[-4000:]
    for line in ('App: "[CP] Check Pods Manifest.lock": Podfile.lock matches Pods/Manifest.lock (checked by isim)',
                 'App: embedded FramePod.framework in Frameworks/ (isim\'s "[CP] Embed Pods Frameworks")',
                 'App: copied StaticPodResources.bundle into the bundle (isim\'s "[CP] Copy Pods Resources")'):
        assert line in log, (line, log[-3000:])
    app_dir = work / "App.app"
    fw = app_dir / "Frameworks/FramePod.framework"
    assert (fw / "FramePod").is_file() and (fw / "FramePodResources.bundle/greeting.txt").is_file() and \
        not (fw / "Headers").exists(), "framework pod embedded with its resource bundle, without headers"
    assert (app_dir / "StaticPodResources.bundle/counter.txt").is_file()
    # products also where the pods' CONFIGURATION_BUILD_DIRs (xcconfig search paths) expect them
    assert (work / "Build/Products/Debug-iphonesimulator/StaticPod/libStaticPod.a").exists()
    app = launch(app_dir)
    app.wait_log(r"PodsApp: StaticPod 2 counter resource \| FramePod hello from FramePodResources \(FramePod\.framework\) \| "
                 r"COCOAPODS=1")
    app.quit()
    # Pods/ out of sync with Podfile.lock: the build stops like CocoaPods' check phase does
    (src / "Pods/Manifest.lock").write_text((src / "Pods/Manifest.lock").read_text().replace("1.4.0", "1.3.0"))
    rc, log = build()
    assert rc != 0 and "The sandbox is not in sync with the Podfile.lock. Run 'pod install'" in log, log[-2000:]


def objc_xcframework(srcdir, name, dest, tmp):
    """A dynamic ObjC <name>.xcframework laid out like `carthage build --use-xcframeworks` / `xcodebuild
    -create-xcframework` output: ios-arm64_x86_64-simulator (x86_64 code; isim cannot build arm64 simulator code, so
    the simulator slice is x86_64 only here) and an ios-arm64 device slice (placeholder)."""
    sim = dest / "ios-arm64_x86_64-simulator" / f"{name}.framework"
    dev = dest / "ios-arm64" / f"{name}.framework"
    for fw in (sim, dev):
        (fw / "Headers").mkdir(parents=True)
        (fw / "Modules").mkdir()
        for h in srcdir.glob("*.h"):
            shutil.copy(h, fw / "Headers")
        shutil.copy(srcdir / "module.modulemap", fw / "Modules")
        (fw / "Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": name, "CFBundleIdentifier": f"org.example.{name}",
                                                        "CFBundlePackageType": "FMWK", "CFBundleShortVersionString": "1.3.0",
                                                        "MinimumOSVersion": "17.0"}))
    objs = []
    for m in srcdir.glob("*.m"):
        o = tmp / f"{m.stem}.o"
        run(ISIM, "cc", "-c", m, "-I", sim / "Headers", "-o", o)
        objs.append(o)
    run(ISIM, "cc", "-dynamiclib", "-install_name", f"@rpath/{name}.framework/{name}", *objs, "-framework", "Foundation",
        "-o", sim / name)
    (tmp / "placeholder.c").write_text("int placeholder(void) { return 0; }\n")
    run("clang", "-target", "arm64-apple-ios17.0", "-dynamiclib", "-nostdlib", "-fuse-ld=lld", "-install_name",
        f"@rpath/{name}.framework/{name}", tmp / "placeholder.c", "-o", dev / name)
    (dest / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [
        {"BinaryPath": f"{name}.framework/{name}", "LibraryIdentifier": "ios-arm64", "LibraryPath": f"{name}.framework",
         "SupportedArchitectures": ["arm64"], "SupportedPlatform": "ios"},
        {"BinaryPath": f"{name}.framework/{name}", "LibraryIdentifier": "ios-arm64_x86_64-simulator",
         "LibraryPath": f"{name}.framework", "SupportedArchitectures": ["arm64", "x86_64"], "SupportedPlatform": "ios",
         "SupportedPlatformVariant": "simulator"}], "CFBundlePackageType": "XFWK", "XCFrameworkFormatVersion": "1.0"}))


def test_carthage_xcframework(launch, tmp_path, work):
    src = copy_fixture("CarthageApp", tmp_path)
    objc_xcframework(src / "FooSource", "Foo", src / "Carthage/Build/Foo.xcframework", tmp_path)
    rc, log = isim(src, "build", "-project", "CarthageApp.xcodeproj", "-o", work)
    assert rc == 0, log[-4000:]
    fw = work / "CarthageApp.app/Frameworks/Foo.framework"
    assert (fw / "Foo").is_file() and not (fw / "Headers").exists()
    app = launch(work / "CarthageApp.app")
    app.wait_log(r"CarthageApp: Foo 1\.3 answer 42 from Foo\.framework")
    app.quit()
