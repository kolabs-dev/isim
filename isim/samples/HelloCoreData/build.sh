#!/usr/bin/env bash
# Build HelloCoreData.app from its Xcode project with `isim build` (Core Data model compiled by isim momc,
# Xcode-style generated NSManagedObject classes, SwiftUI @FetchRequest). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[ -f ../../out/sdk/usr/lib/swift/libswiftCoreData.dylib ] || { echo "HelloCoreData: skipped (Swift overlays not built)"; exit 0; }
outdir=${1:?output dir}
work=$(realpath -m ../../out/projects/HelloCoreData)
../../out/bin/isim build -project HelloCoreData.xcodeproj -o "$work"
rm -rf "$outdir/HelloCoreData.app"; cp -a "$work/HelloCoreData.app" "$outdir/"
echo "built $outdir/HelloCoreData.app"
