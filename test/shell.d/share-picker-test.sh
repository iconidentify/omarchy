#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/user/hardware/apple/share-picker.sh"
all="$ROOT/install/user/all.sh"
migration="$ROOT/migrations/1789140928.sh"
git_drop="$ROOT/migrations/1789228235.sh"
flags="$ROOT/config/chromium-flags.conf"

grep -Fq 'hardware/apple/share-picker.sh' "$all" ||
  fail "the share-picker leaf runs during user setup"
[[ -f $migration ]] || fail "existing installs get the share-picker migration"
[[ -f $git_drop ]] || fail "existing -git installs get a replacement migration"
grep -Fq 'hyprland-preview-share-picker-git' "$git_drop" ||
  fail "the replacement migration drops hyprland-preview-share-picker-git"
! grep -Fq 'WebRTCPipeWireCapturer' "$flags" ||
  fail "shipped Chromium flags must not force the PipeWire capturer on x86"
pass "fresh and existing installs are wired to the screen-share picker"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
mkdir -p "$stub_bin"

cat >"$stub_bin/uname" <<'SH'
#!/bin/bash
[[ ${1:-} == -m ]] && { printf '%s\n' "${TEST_ARCH:-x86_64}"; exit 0; }
exec /usr/bin/uname "$@"
SH
chmod +x "$stub_bin"/*

run_leaf() {
  : >"$calls"
  TEST_ARCH="${1:-x86_64}" TEST_LOG="$calls" \
    HOME="$test_tmp/home" PATH="$stub_bin:$PATH" bash -c 'source "$1"' _ "$leaf"
}

run_leaf x86_64
[[ ! -s $calls ]] || fail "x86 does not touch the share picker" "$(cat "$calls")"
pass "x86 leaves the packaged picker alone"

! grep -Fq 'hyprland-preview-share-picker-git' "$leaf" "$migration" ||
  fail "the share-picker leaf and migration no longer AUR-build -git"
pass "aarch64 uses the packaged hyprland-preview-share-picker"

conf="$test_tmp/home/.config/chromium-flags.conf"
mkdir -p "$(dirname "$conf")"
printf '%s\n' '--enable-features=TouchpadOverscrollHistoryNavigation' >"$conf"
run_leaf x86_64 0
! grep -Fq 'WebRTCPipeWireCapturer' "$conf" ||
  fail "the share-picker leaf must not rewrite x86 Chromium flags"
pass "the share-picker leaf leaves x86 Chromium flags alone"

printf '%s\n' '--enable-features=TouchpadOverscrollHistoryNavigation' >"$conf"
run_leaf aarch64
grep -Fq 'WebRTCPipeWireCapturer' "$conf" ||
  fail "a fresh aarch64 install enables PipeWire capture on existing Chromium flags"
pass "a fresh aarch64 install enables PipeWire capture on existing Chromium flags"

printf '%s\n' '--enable-features=TouchpadOverscrollHistoryNavigation' >"$conf"
HOME="$test_tmp/home" TEST_ARCH=x86_64 TEST_LOG="$calls" PATH="$stub_bin:$PATH" bash "$migration"
! grep -Fq 'WebRTCPipeWireCapturer' "$conf" ||
  fail "the migration must not rewrite x86 Chromium flags"
pass "the migration leaves x86 Chromium flags alone"

printf '%s\n' '--enable-features=TouchpadOverscrollHistoryNavigation' >"$conf"
HOME="$test_tmp/home" TEST_ARCH=aarch64 TEST_LOG="$calls" PATH="$stub_bin:$PATH" bash "$migration"
grep -Fq 'WebRTCPipeWireCapturer' "$conf" ||
  fail "the migration enables PipeWire capture on existing aarch64 Chromium flags"
pass "the migration enables PipeWire capture on existing aarch64 Chromium flags"
