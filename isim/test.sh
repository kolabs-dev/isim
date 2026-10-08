#!/usr/bin/env bash
# Run isim's tests: pytest over isim/tests (build first with ./build.sh). Arguments go to pytest, e.g.
#   ./test.sh -k navigation          ./test.sh tests/ui/test_navigation.py          ./test.sh -x --lf
# Environment: ISIM_TEST_JOBS (parallel workers; default half the CPUs, 2-16; 1 = one at a time),
# ISIM_TEST_RETRY=0 (no rerun of failed tests; by default a failure is rerun once and reported as flaky if it then
# passes), OS_MATRIX=1 (also run the os_matrix tests under iOS 17, 18, 26 and 27).
# The Python packages (tests/requirements.txt) are installed into out/pyenv on first use.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
venv=$PWD/out/pyenv req=tests/requirements.txt
if [ ! -x "$venv/bin/python" ] || ! cmp -s "$req" "$venv/requirements.txt"; then
  echo "test.sh: installing the test packages into $venv"
  python3 -m venv "$venv" && "$venv/bin/pip" install -q -r "$req" && cp "$req" "$venv/requirements.txt"
fi
if [ -n "${ISIM_TEST_JOBS:-}" ]; then jobs=$ISIM_TEST_JOBS
else jobs=$(( $(nproc) / 2 )); [ "$jobs" -ge 2 ] || jobs=2; [ "$jobs" -le 16 ] || jobs=16; fi
args=(--basetemp="$PWD/out/pytest" -q)
[ "$jobs" -gt 1 ] && args+=(-n "$jobs" --dist load --maxschedchunk 1)
[ "${ISIM_TEST_RETRY:-1}" = 0 ] || args+=(--reruns 1)
[ "${OS_MATRIX:-0}" = 1 ] && args+=(--os-matrix)
cd tests && exec "$venv/bin/python" -m pytest "${args[@]}" "$@"
