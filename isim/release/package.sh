#!/usr/bin/env bash
# Package an isim release for Linux x86_64:
#   - host runtime built in the release container (glibc 2.35, SDL3 from source) with its shared
#     libraries bundled in lib/ (rpath $ORIGIN/../lib); glibc and the graphics/audio drivers come from the host;
#   - the iOS-simulator SDK, frameworks, Swift libraries and system apps from this tree's build (platform independent);
#   - demo apps;
#   - LICENSE, NOTICE and third-party licenses (release/licenses, plus the Debian copyright file of each bundled library).
# Usage: release/package.sh VERSION   -> dist/isim-VERSION-linux-x86_64.tar.gz
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
VER=${1:?usage: package.sh VERSION}
NAME=isim-$VER-linux-x86_64
STAGE=$PWD/dist/$NAME
[ -f out/sdk/Applications/Settings.app/Settings ] || { echo "build the tree first (./build.sh)"; exit 1; }
rm -rf "$STAGE"; mkdir -p "$STAGE"/{bin,lib,apps,licenses}

docker build -q -t isim-release-build release/ >/dev/null
docker run --rm -u "$(id -u):$(id -g)" -v "$PWD:/isim" -w /isim isim-release-build bash -c '
  set -e
  out=/isim/dist/'"$NAME"'
  gcc-12 -O2 -g -std=gnu11 -o $out/bin/isim-runtime runtime/loader.c runtime/libsystem.c runtime/objc_rt.c runtime/host.c runtime/host_image.c runtime/host_audio.c runtime/host_net.c \
      $(pkg-config --cflags --libs sdl3 cairo pangocairo pangoft2 fontconfig librsvg-2.0 gdk-pixbuf-2.0) -lm -lpthread -ldl
  # bundle shared libraries except the C runtime and GPU/display/audio drivers (must match the host)
  skip="linux-vdso|libstdc\+\+|libgcc_s|ld-linux|libc\.so|libm\.so|libpthread|libdl\.so|librt\.so|libGL|libEGL|libGLX|libGLdispatch|libdrm|libgbm|libvulkan|libasound|libpulse|libwayland|libxkbcommon|libdbus|libudev|libdecor"
  mkdir -p $out/licenses/ubuntu
  for lib in $(ldd $out/bin/isim-runtime | awk "/=>/{print \$3}"); do
    echo "$lib" | grep -Eq "$skip" && continue
    cp -L "$lib" $out/lib/
    # license of the Ubuntu package that ships it (SDL3 is built from source: licenses/SDL3-LICENSE.txt)
    pkg=$(dpkg -S "*/$(basename "$(readlink -f "$lib")")" 2>/dev/null | head -1 | cut -d: -f1) || true
    if [ -n "$pkg" ]; then cp /usr/share/doc/$pkg/copyright $out/licenses/ubuntu/$pkg.copyright; fi
  done
  patchelf --set-rpath "\$ORIGIN/../lib" $out/bin/isim-runtime
  for l in $out/lib/*.so*; do patchelf --set-rpath "\$ORIGIN" "$l"; done
'
cp tools/isim tools/isim-build.py tools/xcodeproj.py "$STAGE/bin/"
cp -a out/sdk "$STAGE/sdk"
mkdir -p "$STAGE/swift"; cp -a out/swift/resource "$STAGE/swift/resource"      # for `isim swiftc` (Docker swift:6.2)
for a in HelloCounter HelloCounterSwift HelloSwiftUI HelloKeyboardApp; do [ -d "out/apps/$a.app" ] && cp -a "out/apps/$a.app" "$STAGE/apps/"; done
cp release/README-release.md "$STAGE/README.md"
cp ../LICENSE ../NOTICE "$STAGE/"; cp release/licenses/* "$STAGE/licenses/"
tar -C dist -czf "dist/$NAME.tar.gz" "$NAME"
(cd dist && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
ls -la "dist/$NAME.tar.gz"
