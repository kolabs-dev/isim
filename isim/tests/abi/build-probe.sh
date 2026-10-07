#!/usr/bin/env bash
# Rebuild the committed ABIProbe.app with an OLD isim release, e.g.:
#   tests/abi/build-probe.sh /path/to/isim-0.2.0-linux-x86_64
# The committed binary is the test: do not rebuild it with the current SDK.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
rel=$(realpath "${1:?extracted isim release dir}")
out=$PWD/ABIProbe.app
# the release's swiftc can only write inside its own workspace (two levels above bin/)
obj=$(realpath -m "$rel/../abiprobe-obj/ABIProbe.o"); mkdir -p "$(dirname "$obj")"
rm -rf "$out"; mkdir -p "$out"
"$rel/bin/isim" swiftc -module-name ABIProbe -parse-as-library -wmo -c ABIProbe/main.swift -o "$obj"
"$rel/bin/isim" cc "$obj" -o "$out/ABIProbe"
cp ABIProbe/Info.plist "$out/"
echo "built $out with $("$rel/bin/isim" version)"
