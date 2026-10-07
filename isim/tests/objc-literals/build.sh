#!/usr/bin/env bash
# Build tests/objc-literals as ObjCLiteralsTest.app: Literals.m compiled with -fobjc-constant-literals, so its
# literals are static NSConstantArray/NSConstantDictionary/NSConstantIntegerNumber/... objects, and main.swift
# bridging them into Swift. The flag needs clang >= 23; with an older clang the committed ObjCLiteralsTest.app
# (built with clang 23 by build-prebuilt.sh) is used instead.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
out=${1:?output dir}
cc=${ISIM_CC:-clang}
isim=$ISIM_SDK/../bin/isim
app=$out/ObjCLiteralsTest.app
if ! echo | "$cc" -x objective-c -fobjc-constant-literals -fsyntax-only - 2>/dev/null; then
  echo "objc-literals: $cc has no -fobjc-constant-literals (clang >= 23); using the prebuilt ObjCLiteralsTest.app"
  rm -rf "$app"; cp -r ObjCLiteralsTest.app "$app"
  exit 0
fi
if [ ! -x "$isim" ] || [ ! -d "$ISIM_SDK/usr/lib/swift" ]; then echo "objc-literals: skipped (needs the Swift toolchain)"; exit 0; fi
obj=$ISIM_SDK/../swift/objc-literals
mkdir -p "$obj" "$app"
CLANG=$cc "$isim" cc -fobjc-constant-literals -fobjc-arc-exceptions -O1 -Wall -c Literals.m -o "$obj/Literals.o"
"$isim" swiftc -parse-as-library -import-objc-header Literals.h -c main.swift -o "$obj/main.o"
CLANG=$cc "$isim" cc "$obj/Literals.o" "$obj/main.o" -framework Foundation -o "$app/ObjCLiteralsTest"
cp Info.plist "$app/"
