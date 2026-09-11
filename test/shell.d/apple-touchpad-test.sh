#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/user/hardware/apple/touchpad.sh"
all="$ROOT/install/user/all.sh"
migration="$ROOT/migrations/1789135950.sh"

grep -Fq 'hardware/apple/touchpad.sh' "$all" ||
  fail "Apple Silicon touchpad defaults run during user setup"
[[ -f $migration ]] || fail "existing Apple Silicon installs get touchpad defaults"
pass "fresh and existing installs are wired to Apple Silicon touchpad defaults"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
stub_bin="$test_tmp/bin"
input="$test_tmp/input.lua"
mkdir -p "$stub_bin"
printf '%s\n' '-- personal overrides' >"$input"

cat >"$stub_bin/omarchy-hw-apple-silicon" <<'SH'
#!/bin/bash
[[ ${APPLE_SILICON:-0} == "1" ]]
SH
chmod +x "$stub_bin/omarchy-hw-apple-silicon"

run_leaf() {
  APPLE_SILICON="${1:-0}" OMARCHY_HYPR_INPUT="$input" PATH="$stub_bin:$PATH" \
    bash -c 'source "$1"' _ "$leaf"
}

run_leaf 0
! grep -q 'omarchy-apple-touchpad' "$input" ||
  fail "the touchpad leaf does not rewrite x86 input.lua"
pass "the touchpad leaf is a no-op off Apple Silicon"

run_leaf 1
grep -Fq 'natural_scroll = true' "$input" || fail "Apple Silicon gets natural scrolling"
grep -Fq 'tap_to_click = false' "$input" || fail "Apple Silicon turns tap-to-click off"
pass "Apple Silicon user override uses natural scrolling and physical clicks"

before=$(wc -c <"$input")
run_leaf 1
after=$(wc -c <"$input")
(( before == after )) || fail "the touchpad leaf is idempotent"
pass "the touchpad leaf is idempotent"

printf '%s\n' 'hl.config({' '  input = {' '    touchpad = {' '      natural_scroll = true,' '      tap_to_click = false,' '    },' '  },' '})' >"$input"
run_leaf 1
! grep -q 'omarchy-apple-touchpad' "$input" ||
  fail "an existing macOS-like override is not duplicated"
pass "an existing macOS-like override is not duplicated"

# A user who turned natural scrolling off keeps it off: fork installs predate
# the marker, so first adoption is exactly this unmarked case.
printf '%s\n' 'hl.config({' '  input = {' '    touchpad = {' '      natural_scroll = false,' '    },' '  },' '})' >"$input"
before=$(cat "$input")
run_leaf 1
[[ $(cat "$input") == "$before" ]] ||
  fail "an explicit natural_scroll = false is preserved" "$(cat "$input")"
pass "an explicit touchpad choice is preserved"
