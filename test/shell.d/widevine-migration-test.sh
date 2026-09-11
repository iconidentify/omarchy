#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

migration="$ROOT/migrations/1789155585.sh"
[[ -f $migration ]] || fail "the Widevine migration exists"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
mkdir -p "$stub_bin"

cat >"$stub_bin/omarchy-hw-apple-silicon" <<'SH'
#!/bin/bash
(( ${APPLE:-1} == 1 ))
SH
cat >"$stub_bin/omarchy-pkg-available" <<'SH'
#!/bin/bash
(( ${AVAILABLE:-1} == 1 ))
SH
cat >"$stub_bin/omarchy-pkg-present" <<'SH'
#!/bin/bash
(( ${PRESENT:-0} == 1 ))
SH
cat >"$stub_bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf 'add %s\n' "$*" >>"$TEST_LOG"
SH
chmod +x "$stub_bin"/*

run_mig() {
  : >"$calls"
  APPLE="${1:-1}" AVAILABLE="${2:-1}" PRESENT="${3:-0}" TEST_LOG="$calls" \
    PATH="$stub_bin:$PATH" bash -euo pipefail "$migration" >/dev/null
}

run_mig 0 1 0
! grep -q add "$calls" || fail "Widevine does not install off Apple Silicon"
pass "Widevine does not install off Apple Silicon"

run_mig 1 0 0
! grep -q add "$calls" || fail "Widevine does not install when the package is missing"
pass "Widevine does not install when the package is missing"

run_mig 1 1 1
! grep -q add "$calls" || fail "Widevine does not reinstall"
pass "Widevine does not reinstall when present"

run_mig 1 1 0
grep -Fx 'add widevine' "$calls" >/dev/null || fail "Widevine installs on Apple Silicon when available"
pass "Widevine installs on Apple Silicon when available"
