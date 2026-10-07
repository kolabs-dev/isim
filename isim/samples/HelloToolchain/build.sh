#!/usr/bin/env bash
# Build HelloToolchain.app from its workspace with `isim build`: an app (Swift + ObjC, bridging header,
# -Swift.h), a static library, a dynamic framework (Swift + ObjC, resource), a local package that depends on
# another local package (with a C target and resources), a prebuilt XCFramework and .xcconfig files.
# Its test targets (unit, UI, Swift Testing) run with `isim test` (tests/ui/toolchain.sh). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[ -f ../../out/sdk/usr/lib/swift/libswiftXCTest.dylib ] || { echo "HelloToolchain: skipped (Swift overlays not built)"; exit 0; }
outdir=${1:?output dir}
isim=$(realpath ../../out/bin/isim)
work=$(realpath -m ../../out/projects/HelloToolchain)
# the vendor XCFramework: an x86_64 iOS-simulator static library + headers, packaged like a binary SDK
xcf=Vendor/Sum.xcframework; slice=$xcf/ios-x86_64-simulator
mkdir -p "$work/vendor" "$slice/Headers"
"$isim" cc -c Vendor/Sum/sum.c -o "$work/vendor/sum.o"
llvm-ar rcs "$slice/libSum.a" "$work/vendor/sum.o"
cp Vendor/Sum/sum.h Vendor/Sum/module.modulemap "$slice/Headers/"
cat > "$xcf/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>HeadersPath</key><string>Headers</string>
			<key>LibraryIdentifier</key><string>ios-x86_64-simulator</string>
			<key>LibraryPath</key><string>libSum.a</string>
			<key>SupportedArchitectures</key><array><string>x86_64</string></array>
			<key>SupportedPlatform</key><string>ios</string>
			<key>SupportedPlatformVariant</key><string>simulator</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key><string>XFWK</string>
	<key>XCFrameworkFormatVersion</key><string>1.0</string>
</dict>
</plist>
PLIST
"$isim" build -workspace HelloToolchain.xcworkspace -scheme HelloToolchain -o "$work"
rm -rf "$outdir/HelloToolchain.app"; cp -a "$work/HelloToolchain.app" "$outdir/"
echo "built $outdir/HelloToolchain.app"
