#!/usr/bin/env bash
# Build HelloAppearance.app (Swift UIKit: traits, dynamic colors/images, appearance proxies) for isim, with its asset
# catalog compiled by isim's build tool (the Badge image variants are generated here). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloAppearance: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloAppearance.app; obj=$(realpath -m ../../out/swift/obj/HelloAppearance.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloAppearance -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloAppearance"
cp Info.plist "$out/"
# asset catalog: Brand (Any/Dark x High Contrast), AccentColor, Badge (light 10 pt red, dark 12 pt blue, @3x)
assets=$(realpath -m ../../out/obj/HelloAppearance.xcassets); rm -rf "$assets"; cp -r Assets.xcassets "$assets"
python3 - "$assets/Badge.imageset" <<'PY'
import struct, sys, zlib
def png(path, size, rgb):
    raw = b''.join(b'\0' + bytes(rgb) * size for _ in range(size))
    chunk = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))
png(sys.argv[1] + '/badge-light.png', 30, (255, 0, 0))
png(sys.argv[1] + '/badge-dark.png', 36, (0, 0, 255))
PY
python3 - "$assets" "$out" <<'PY'
import importlib.util, sys, os
spec = importlib.util.spec_from_file_location('isim_build', os.path.join(os.path.dirname(os.path.abspath('build.sh')), '../../tools/isim-build.py'))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
m.compile_xcassets(sys.argv[1], sys.argv[2])
PY
echo "built $out"
