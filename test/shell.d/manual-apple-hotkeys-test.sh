#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

coming_from="$ROOT/manual/03-coming-from-mac-or-windows.md"
hotkeys="$ROOT/manual/07-hotkeys.md"
input="$ROOT/manual/34-keyboard-mouse-trackpad.md"

grep -F '`Super + F11` on an Apple keyboard, or `Print Screen`' "$coming_from" >/dev/null ||
  fail "coming-from chapter maps Mac screenshots to Super+F11"
grep -F 'use Command wherever this manual says `Super`' "$coming_from" >/dev/null ||
  fail "coming-from chapter names Command as Super on Apple keyboards"
grep -F 'media controls work directly, while `Fn` gives you F1-F12' "$coming_from" >/dev/null ||
  fail "coming-from chapter documents Fn for F-keys on Apple keyboards"
pass "coming-from chapter documents Apple keyboard screenshot and Super"

grep -F 'Maximum screen brightness (keyboard backlight on Apple keyboards)' "$hotkeys" >/dev/null ||
  fail "hotkeys still document x86 Shift+brightness as maximum screen brightness"
grep -F 'Minimum screen brightness (keyboard backlight on Apple keyboards)' "$hotkeys" >/dev/null ||
  fail "hotkeys still document x86 Shift+brightness as minimum screen brightness"
grep -F '`Super + F11` | Screenshot region on Apple keyboards' "$hotkeys" >/dev/null ||
  fail "hotkeys list Super+F11 region capture on Apple keyboards"
grep -F '`Super + F10` | Screenshot window on Apple keyboards' "$hotkeys" >/dev/null ||
  fail "hotkeys list Super+F10 window capture on Apple keyboards"
grep -F '`Super + F12` | Screenshot full display on Apple keyboards' "$hotkeys" >/dev/null ||
  fail "hotkeys list Super+F12 full-display capture on Apple keyboards"
! grep -F 'Super + Alt + F12' "$hotkeys" >/dev/null ||
  fail "hotkeys should not bind Super+Alt+F12 for recording"
grep -F 'whether or not you hold `Fn`' "$hotkeys" >/dev/null ||
  fail "hotkeys say Apple capture shortcuts work without Fn"
grep -F '`Super + Ctrl + Alt + F` | Toggle full screen desktop (top bar + window gaps)' "$hotkeys" >/dev/null ||
  fail "hotkeys still document the x86 full-screen desktop toggle"
pass "hotkeys document Apple capture chords without dropping x86 brightness max/min"

grep -F '### Apple keyboard and trackpad defaults' "$input" >/dev/null ||
  fail "input chapter has Apple keyboard and trackpad defaults"
grep -F 'natural scrolling and physical clicks instead of tap-to-click' "$input" >/dev/null ||
  fail "input chapter documents Apple trackpad defaults"
pass "input chapter documents Apple keyboard and trackpad defaults"
