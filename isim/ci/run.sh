#!/usr/bin/env bash
# CI entry point: build isim and run every test suite plus the ABI check.
# Runs inside the ci/Dockerfile image with the repository mounted at the SAME path as on the host and the host's
# Docker socket, so the `docker run -v $ws:$ws` calls that compile Swift (swift:6.2 image) resolve on the host.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
git config --global --add safe.directory '*'
[ -d ../third_party/swift/stdlib ] || bash swift/fetch-sources.sh
docker image inspect swift:6.2 >/dev/null 2>&1 || docker pull -q swift:6.2
echo "::group::build"
./build.sh
echo "::endgroup::"
# optional parts are skipped quietly by build.sh; in CI they must exist, or their suites would be skipped too
for f in out/sdk/usr/lib/swift/libswiftCore.dylib out/sdk/usr/lib/swift/libswiftSwiftUI.dylib out/bin/isim-webkit \
         out/apps/HelloSwiftUI.app/HelloSwiftUI out/apps/CoreDataTest.app/CoreDataTest out/apps/ObjCLiteralsTest.app/ObjCLiteralsTest; do
  [ -e "$f" ] || { echo "CI: $f was not built"; exit 1; }
done
python3 tools/abi-check.py
./test.sh --junitxml=../out/test-results.xml 2>&1 | tee out/test.log
exit "${PIPESTATUS[0]}"
