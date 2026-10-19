#!/usr/bin/env bash
# Swift 6.2.4 from swift.org (the toolchain isim's SDK is built with, the same one swiftly installs), checked
# against swift.org's signing keys and unpacked into DIR (DIR/usr/bin/swiftc), for CI and cloud sessions:
# ISIM_SWIFT_TOOLCHAIN=DIR then compiles with it. On a desktop, `isim toolchain install` (swiftly) installs the same
# toolchain. Usage: isim/ci/swift-toolchain.sh DIR [ubuntu24.04]
set -euo pipefail
dir=${1:?usage: swift-toolchain.sh DIR [platform]}
platform=${2:-ubuntu24.04}
version=6.2.4
name=swift-$version-RELEASE-$platform
url=https://download.swift.org/swift-$version-release/${platform//./}/swift-$version-RELEASE/$name.tar.gz
if [ -x "$dir/usr/bin/swift-frontend" ] && "$dir/usr/bin/swift-frontend" --version | grep -q "(swift-$version-RELEASE)"; then
  echo "Swift $version is in $dir"; exit 0
fi
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
curl -fsSL --retry 3 -o "$tmp/swift.tar.gz" "$url"
curl -fsSL --retry 3 -o "$tmp/swift.tar.gz.sig" "$url.sig"
export GNUPGHOME=$tmp/gnupg
mkdir -m 700 "$GNUPGHOME"
curl -fsSL --retry 3 https://www.swift.org/keys/all-keys.asc | gpg --batch --quiet --import
gpg --batch --verify "$tmp/swift.tar.gz.sig" "$tmp/swift.tar.gz"
mkdir -p "$dir"
tar -xzf "$tmp/swift.tar.gz" -C "$dir" --strip-components=1
"$dir/usr/bin/swift-frontend" --version | head -1
