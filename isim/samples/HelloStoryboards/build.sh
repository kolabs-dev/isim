#!/usr/bin/env bash
# Build HelloStoryboards.app (Swift, scene-based: Main/LaunchScreen storyboards, xibs, Settings.bundle) and
# HelloStoryboardsClassic.app (Objective-C, UIMainStoryboardFile, UILaunchScreen dictionary) from their Xcode
# project with `isim build`, which compiles the storyboards and xibs with isim's ibtool. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloStoryboards: skipped (Swift SDK not built)"; exit 0; }
outdir=$(realpath -m "${1:?output dir}")
work=$(realpath -m ../../out/projects/HelloStoryboards)
for target in HelloStoryboards HelloStoryboardsClassic; do
  ../../out/bin/isim build -project HelloStoryboards.xcodeproj -target "$target" -o "$work"
  rm -rf "$outdir/$target.app"; cp -a "$work/$target.app" "$outdir/"
  echo "built $outdir/$target.app"
done
