#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/user/hardware/apple/obsidian.sh"
all="$ROOT/install/user/all.sh"

grep -Fq 'hardware/apple/obsidian.sh' "$all" ||
  fail "Obsidian AppImage setup runs during user setup"
pass "Obsidian AppImage setup runs during user setup"

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
cat >"$stub_bin/omarchy-cmd-missing" <<'SH'
#!/bin/bash
[[ ${OBSIDIAN_PRESENT:-0} != 1 && ! -e ${OBSIDIAN_INSTALLED:-/nonexistent} ]]
SH
cat >"$stub_bin/omarchy-pkg-available" <<'SH'
#!/bin/bash
[[ ${REPO_HAS_OBSIDIAN:-1} == 1 ]]
SH
cat >"$stub_bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf 'pkg-add %s\n' "$*" >>"$TEST_LOG"
touch "$OBSIDIAN_INSTALLED"
SH
cat >"$stub_bin/omarchy-pkg-aur-add" <<'SH'
#!/bin/bash
printf 'aur-add %s\n' "$*" >>"$TEST_LOG"
SH
chmod +x "$stub_bin"/*

run_leaf() {
  : >"$calls"
  rm -f "$test_tmp/installed"
  TEST_ARCH="${1:-x86_64}" OBSIDIAN_PRESENT="${2:-0}" REPO_HAS_OBSIDIAN="${3:-1}" \
    TEST_LOG="$calls" OBSIDIAN_INSTALLED="$test_tmp/installed" \
    PATH="$stub_bin:$PATH" bash -c 'source "$1"' _ "$leaf"
}

run_leaf x86_64 0
[[ ! -s $calls ]] || fail "x86 does not install obsidian-appimage" "$(cat "$calls")"
pass "x86 leaves the packaged Obsidian name alone"

run_leaf aarch64 1
[[ ! -s $calls ]] || fail "aarch64 does not reinstall a present Obsidian" "$(cat "$calls")"
pass "aarch64 skips Obsidian when the command is already present"

run_leaf aarch64 0
grep -Fxq 'pkg-add obsidian-appimage' "$calls" ||
  fail "aarch64 asks the repos for obsidian-appimage" "$(cat "$calls")"
! grep -q aur-add "$calls" || fail "a repo install does not also build from the AUR" "$(cat "$calls")"
pass "aarch64 installs Obsidian from the AppImage package"

run_leaf aarch64 0 0
grep -Fxq 'aur-add obsidian-appimage' "$calls" ||
  fail "aarch64 falls back to the AUR when the repos lack obsidian-appimage" "$(cat "$calls")"
! grep -q pkg-add "$calls" ||
  fail "aarch64 does not call pkg-add when the repos lack the package" "$(cat "$calls")"
pass "aarch64 falls back to the AUR when the repos lack obsidian-appimage"
