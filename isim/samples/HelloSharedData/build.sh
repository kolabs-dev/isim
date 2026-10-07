#!/usr/bin/env bash
# Build HelloSharedData.app (plural localization, LocalizedStringResource, app groups, iCloud key-value store,
# NotificationQueue). The String Catalog is compiled by isim build's compile_xcstrings (.strings + .stringsdict).
# Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloSharedData: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloSharedData.app; obj=$(realpath -m ../../out/swift/obj/HelloSharedData.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSharedData -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSharedData"
cp Info.plist "$out/"
cp -r en.lproj ru.lproj "$out/"
python3 - "$out" <<'PY'
import importlib.util, sys
dest = sys.argv[1]
spec = importlib.util.spec_from_file_location("isim_build", "../../tools/isim-build.py")
m = importlib.util.module_from_spec(spec); sys.argv = ["isim-build"]; spec.loader.exec_module(m)
print("localizations:", m.compile_xcstrings("Localizable.xcstrings", dest))
PY
echo "built $out"
