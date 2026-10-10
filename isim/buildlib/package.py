"""Packaging a release for Linux x86_64 (dist/isim-VERSION-linux-x86_64.tar.gz):
  - the host runtime built in the release container (release/Dockerfile: glibc 2.35, SDL3 from source) with its shared
    libraries bundled in lib/ (rpath $ORIGIN/../lib); glibc and the graphics/audio drivers come from the host;
  - the iOS-simulator SDK, frameworks, Swift libraries and system apps from this tree's build (platform independent);
  - demo apps; LICENSE, NOTICE and third-party licenses (release/licenses, plus the Debian copyright file of each
    bundled library)."""
import glob
import hashlib
import os
import shutil
import subprocess

DEMOS = ("HelloCounter HelloCounterSwift HelloSwiftUI HelloKeyboardApp HelloTable HelloCollection HelloNavigation HelloControls "
         "HelloDrawing HelloCharts HelloStoryboards HelloCoreAnimation HelloQuartz HelloImaging HelloTextEditing HelloMultiTouch "
         "HelloOSVersions").split()

BUNDLE = r'''
set -e
out=/isim/dist/{name}
gcc-12 -O2 -g -std=gnu11 -o $out/bin/isim-runtime {srcs} \
    $(pkg-config --cflags --libs sdl3 cairo pangocairo pangoft2 fontconfig librsvg-2.0 gdk-pixbuf-2.0) -lm -lpthread -ldl
# bundle shared libraries except the C runtime and GPU/display/audio drivers (must match the host)
skip="linux-vdso|libstdc\+\+|libgcc_s|ld-linux|libc\.so|libm\.so|libpthread|libdl\.so|librt\.so|libGL|libEGL|libGLX|libGLdispatch|libdrm|libgbm|libvulkan|libasound|libpulse|libwayland|libxkbcommon|libdbus|libudev|libdecor"
mkdir -p $out/licenses/ubuntu
for lib in $(ldd $out/bin/isim-runtime | awk "/=>/{{print \$3}}"); do
  echo "$lib" | grep -Eq "$skip" && continue
  cp -L "$lib" $out/lib/
  # license of the Ubuntu package that ships it (SDL3 is built from source: licenses/SDL3-LICENSE.txt)
  pkg=$(dpkg -S "*/$(basename "$(readlink -f "$lib")")" 2>/dev/null | head -1 | cut -d: -f1) || true
  if [ -n "$pkg" ]; then cp /usr/share/doc/$pkg/copyright $out/licenses/ubuntu/$pkg.copyright; fi
done
patchelf --set-rpath "\$ORIGIN/../lib" $out/bin/isim-runtime
for l in $out/lib/*.so*; do patchelf --set-rpath "\$ORIGIN" "$l"; done
'''


def package(root, version, ctx):
    from .graph import host_sources
    name = f"isim-{version}-linux-x86_64"
    dist = os.path.join(root, "dist")
    stage = os.path.join(dist, name)
    if not os.path.exists(os.path.join(root, "out/sdk/Applications/Settings.app/Settings")):
        raise SystemExit("build the tree first (build.py)")
    shutil.rmtree(stage, ignore_errors=True)
    for d in ("bin", "lib", "apps", "licenses"):
        os.makedirs(os.path.join(stage, d))
    image = os.environ.get("ISIM_RELEASE_IMAGE")             # an image built beforehand (CI builds it with its layer cache)
    if not image:
        image = "isim-release-build"
        subprocess.run(["docker", "build", "-q", "-t", image, "release/"], check=True, cwd=root, stdout=subprocess.DEVNULL)
    subprocess.run(["docker", "run", "--rm", "-u", f"{os.getuid()}:{os.getgid()}", "-v", f"{root}:/isim", "-w", "/isim",
                    image, "bash", "-c", BUNDLE.format(name=name, srcs=" ".join(host_sources(ctx)))], check=True)
    for t in ("tools/isim", "tools/isim-build.py", "tools/xcodeproj.py", "VERSION", "tools/isim-services.py", "tools/momc.py",
              "tools/ibtool.py", "tools/isim-test.py"):
        shutil.copy(os.path.join(root, t), os.path.join(stage, "bin"))
    shutil.copy(os.path.join(root, "..", "install.sh"), os.path.join(stage, "bin", "isim-install.sh"))   # `isim update`
    shutil.copytree(os.path.join(root, "out/sdk"), os.path.join(stage, "sdk"), symlinks=True)
    os.makedirs(os.path.join(stage, "share/fonts"))                       # isim's UI fonts (OFL)
    for f in glob.glob(os.path.join(root, "fonts/*.ttf")) + [os.path.join(root, "fonts/LICENSE-OFL.txt")]:
        shutil.copy(f, os.path.join(stage, "share/fonts"))
    shutil.copytree(os.path.join(root, "out/share/icons"), os.path.join(stage, "share/icons"))   # app icon (icons/)
    shutil.copytree(os.path.join(root, "out/swift/resource"), os.path.join(stage, "swift/resource"), symlinks=True)   # isim swiftc
    shutil.copytree(os.path.join(root, "out/swift/host"), os.path.join(stage, "swift/host"), symlinks=True)   # macro plugins
    for a in DEMOS:
        if os.path.isdir(os.path.join(root, f"out/apps/{a}.app")):
            shutil.copytree(os.path.join(root, f"out/apps/{a}.app"), os.path.join(stage, f"apps/{a}.app"), symlinks=True)
    shutil.copy(os.path.join(root, "release/README-release.md"), os.path.join(stage, "README.md"))
    for f in ("LICENSE", "NOTICE"):
        shutil.copy(os.path.join(root, "..", f), stage)
    for f in glob.glob(os.path.join(root, "release/licenses/*")):
        shutil.copy(f, os.path.join(stage, "licenses"))
    tar = os.path.join(dist, f"{name}.tar.gz")
    subprocess.run(["tar", "-C", dist, "-czf", tar, name], check=True)
    h = hashlib.sha256(open(tar, "rb").read()).hexdigest()
    with open(f"{tar}.sha256", "w") as f:
        f.write(f"{h}  {name}.tar.gz\n")
    print(f"{tar} ({os.path.getsize(tar) // 2**20} MB)")
    return 0


def bump(root, kind):
    """the next version after the latest release tag (vX.Y.Z; isim/VERSION when there is none): patch, minor or major.
    Writes isim/VERSION and the version examples in the README; returns the new version."""
    import re
    if kind not in ("patch", "minor", "major"):
        raise SystemExit("usage: build.py version patch|minor|major")
    tags = subprocess.run(["git", "tag", "-l", "v*"], capture_output=True, text=True, cwd=root).stdout.split()
    versions = sorted(tuple(map(int, t[1:].split("."))) for t in tags if re.fullmatch(r"v\d+\.\d+\.\d+", t))
    with open(os.path.join(root, "VERSION")) as f:
        current = f.read().strip()
    major, minor, patch = versions[-1] if versions else tuple(map(int, current.split(".")))
    new = {"major": f"{major + 1}.0.0", "minor": f"{major}.{minor + 1}.0", "patch": f"{major}.{minor}.{patch + 1}"}[kind]
    with open(os.path.join(root, "VERSION"), "w") as f:
        f.write(new + "\n")
    readme = os.path.join(root, "..", "README.md")
    with open(readme) as f:
        text = f.read()
    text = re.sub(r"(isim update )\d+\.\d+\.\d+", rf"\g<1>{new}", text)
    text = re.sub(r"(build\.py package )\d+\.\d+\.\d+", rf"\g<1>{new}", text)
    with open(readme, "w") as f:
        f.write(text)
    return new
