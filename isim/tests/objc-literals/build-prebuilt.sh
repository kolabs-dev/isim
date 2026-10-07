#!/usr/bin/env bash
# Rebuild the committed ObjCLiteralsTest.app with clang >= 23, for machines whose clang lacks
# -fobjc-constant-literals. Run after ./build.sh, inside the CI image (clang 23), from the isim directory:
#   docker run --rm -v "$WS:$WS" -w "$PWD" -v /var/run/docker.sock:/var/run/docker.sock isim-ci tests/objc-literals/build-prebuilt.sh
# ($WS = the checkout root, one level above isim/; `isim swiftc` starts the swift:6.2 container through the socket)
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
echo | clang -x objective-c -fobjc-constant-literals -fsyntax-only - 2>/dev/null || { echo "needs clang >= 23" >&2; exit 1; }
sdk=$(realpath ../../out/sdk)
tmp=$(mktemp -d)
ISIM_SDK=$sdk ISIM_CC=clang bash build.sh "$tmp"
rm -rf ObjCLiteralsTest.app
cp -r "$tmp/ObjCLiteralsTest.app" .
rm -rf "$tmp"
owner=$(stat -c %u:%g .)   # the container runs as root: hand the results back to the checkout's owner
chown -R "$owner" ObjCLiteralsTest.app "$sdk/../swift/objc-literals"
echo "built $PWD/ObjCLiteralsTest.app with $(clang --version | head -1)"
