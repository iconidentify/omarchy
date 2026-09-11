#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/hardware/fix-fkeys.sh"
migration="$ROOT/migrations/1789132067.sh"
media="$ROOT/default/hypr/bindings/media.lua"
utilities="$ROOT/default/hypr/bindings/utilities.lua"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
conf="$test_tmp/hid_apple.conf"
mkdir -p "$stub_bin"

cat >"$stub_bin/omarchy-hw-apple-silicon" <<'SH'
#!/bin/bash
[[ ${APPLE_SILICON:-0} == "1" ]]
SH

cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
printf 'sudo' >>"$TEST_LOG"
printf '\t%s' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
"$@"
SH

cat >"$stub_bin/mkinitcpio" <<'SH'
#!/bin/bash
printf 'mkinitcpio' >>"$TEST_LOG"
printf '\t%s' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
exit "${MKINITCPIO_STATUS:-0}"
SH

cat >"$stub_bin/omarchy-brightness-keyboard" <<'SH'
#!/bin/bash
printf 'keyboard %s\n' "$*"
SH

cat >"$stub_bin/omarchy-brightness-display" <<'SH'
#!/bin/bash
printf 'display %s\n' "$*"
SH

chmod +x "$stub_bin"/*

run_leaf() {
  APPLE_SILICON="${1:-0}" OMARCHY_HID_APPLE_CONF="$conf" PATH="$stub_bin:$PATH" \
    TEST_LOG="$calls" bash -c 'source "$1"' _ "$leaf"
}

pending="$test_tmp/var/lib/omarchy/migrations/1789132067-initramfs-pending"

run_migration() {
  APPLE_SILICON="${1:-0}" OMARCHY_HID_APPLE_CONF="$conf" \
    OMARCHY_HID_APPLE_FNMODE="$test_tmp/missing-fnmode" \
    OMARCHY_HID_APPLE_PENDING="$pending" \
    PATH="$stub_bin:$PATH" TEST_LOG="$calls" \
    bash -euo pipefail "$migration"
}

rm -f "$conf"
run_leaf 0
[[ $(<"$conf") == "options hid_apple fnmode=2" ]] ||
  fail "x86 install still writes fnmode=2" "$(cat "$conf")"
pass "x86 install still writes fnmode=2"

rm -f "$conf"
run_leaf 1
[[ $(<"$conf") == "options hid_apple fnmode=1" ]] ||
  fail "Apple Silicon install writes fnmode=1" "$(cat "$conf")"
pass "Apple Silicon install writes fnmode=1"

printf 'options hid_apple fnmode=0\n' >"$conf"
run_leaf 1
[[ $(<"$conf") == "options hid_apple fnmode=0" ]] ||
  fail "install leaves an existing hid_apple.conf alone"
pass "install leaves an existing hid_apple.conf alone"

rm -f "$conf"
: >"$calls"
run_migration 0
[[ ! -e $conf ]] || fail "the fnmode migration does not write on x86"
! grep -q mkinitcpio "$calls" || fail "the fnmode migration does not rebuild initramfs on x86"
pass "the fnmode migration is a no-op off Apple Silicon"

printf 'options hid_apple fnmode=2\n' >"$conf"
: >"$calls"
run_migration 1
[[ $(<"$conf") == "options hid_apple fnmode=1" ]] ||
  fail "the migration rewrites the stock fnmode=2 default on Apple Silicon" "$(cat "$conf")"
grep -q $'mkinitcpio\t-P' "$calls" || fail "the migration rebuilds the initramfs after rewriting fnmode"
[[ ! -e $pending ]] || fail "a successful rebuild clears the pending marker"
pass "the migration rewrites fnmode=2 on Apple Silicon"

# A failed rebuild must leave the migration pending, and the rerun must rebuild
# even though the config already reads fnmode=1.
printf 'options hid_apple fnmode=2\n' >"$conf"
: >"$calls"
if MKINITCPIO_STATUS=1 run_migration 1 2>/dev/null; then
  fail "the migration reports a failed initramfs rebuild"
fi
[[ $(<"$conf") == "options hid_apple fnmode=1" ]] ||
  fail "a failed rebuild keeps the rewritten config" "$(cat "$conf")"
[[ -f $pending ]] || fail "a failed rebuild leaves the pending marker"
: >"$calls"
run_migration 1
grep -q $'mkinitcpio\t-P' "$calls" || fail "the rerun rebuilds the initramfs it still owes"
[[ ! -e $pending ]] || fail "the rerun clears the pending marker after rebuilding"
[[ $(<"$conf") == "options hid_apple fnmode=1" ]] || fail "the rerun leaves the config as fnmode=1"
pass "a failed initramfs rebuild stays pending and retries"

printf 'options hid_apple fnmode=0\n' >"$conf"
: >"$calls"
run_migration 1
[[ $(<"$conf") == "options hid_apple fnmode=0" ]] ||
  fail "the migration leaves a user-chosen fnmode alone"
! grep -q mkinitcpio "$calls" || fail "the migration does not rebuild initramfs when leaving fnmode alone"
pass "the migration leaves a user-chosen fnmode alone"

grep -F 'omarchy-brightness-shift up' "$media" >/dev/null ||
  fail "SHIFT+brightness up goes through the shift wrapper"
grep -F 'omarchy-brightness-shift down' "$media" >/dev/null ||
  fail "SHIFT+brightness down goes through the shift wrapper"
! grep -F 'omarchy-brightness-display 100%' "$media" >/dev/null ||
  fail "SHIFT+brightness no longer calls display max directly"
pass "SHIFT+brightness uses the hardware-gated wrapper"

PATH="$stub_bin:$PATH" APPLE_SILICON=0 "$ROOT/bin/omarchy-brightness-shift" up |
  grep -qx 'display 100%' || fail "SHIFT+brightness up is display max on x86"
PATH="$stub_bin:$PATH" APPLE_SILICON=0 "$ROOT/bin/omarchy-brightness-shift" down |
  grep -qx 'display 1%' || fail "SHIFT+brightness down is display min on x86"
pass "SHIFT+brightness is display max/min off Apple Silicon"

PATH="$stub_bin:$PATH" APPLE_SILICON=1 "$ROOT/bin/omarchy-brightness-shift" up |
  grep -qx 'keyboard up' || fail "SHIFT+brightness up is keyboard backlight on Apple Silicon"
PATH="$stub_bin:$PATH" APPLE_SILICON=1 "$ROOT/bin/omarchy-brightness-shift" down |
  grep -qx 'keyboard down' || fail "SHIFT+brightness down is keyboard backlight on Apple Silicon"
pass "SHIFT+brightness is keyboard backlight on Apple Silicon"

grep -F 'SUPER + F12' "$utilities" >/dev/null || fail "SUPER+F12 captures without PRINT"
grep -F 'SUPER + XF86AudioRaiseVolume' "$utilities" >/dev/null ||
  fail "SUPER+volume-up captures on the Apple media row"
grep -F 'PRINT' "$utilities" >/dev/null || fail "PRINT capture binds remain"
pass "capture binds cover PRINT, F-keys, and the Apple media row"
