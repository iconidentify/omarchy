#!/bin/bash

# Apple keyboards have no Print Screen, so the utilities bindings add
# SUPER+F10-F12 and the top-row media chords for capture. Those keys are
# unbound on every other machine and must stay that way: the binds exist only
# when the Apple Silicon detector says so.

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

require_command lua

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/omarchy-hw-apple-silicon" <<'SH'
#!/bin/bash
[[ ${APPLE_SILICON:-0} == "1" ]]
SH
chmod +x "$stub_bin"/*

# Load only the helpers and the utilities bindings, printing every key that
# reaches hl.bind. The "-" makes lua report a chunk error in its exit status.
list_utility_keys() {
  APPLE_SILICON="$1" PATH="$stub_bin:$PATH" OMARCHY_PATH="$ROOT" lua - <<'LUA'
package.path = os.getenv("OMARCHY_PATH") .. "/?.lua;" .. package.path

local function proxy()
  return setmetatable({}, {
    __index = function(self, key)
      local value = proxy()
      rawset(self, key, value)
      return value
    end,
    __call = function()
      return {}
    end,
  })
end

hl = setmetatable({
  dsp = proxy(),
  bind = function(keys)
    print(keys)
  end,
  on = function() end,
  config = function() end,
  get_config = function() return nil end,
}, {
  __index = function()
    return function()
      return {}
    end
  end,
})

require("default.hypr.helpers")
require("default.hypr.bindings.utilities")
LUA
}

apple_chords=("SUPER + F12" "SUPER + F11" "SUPER + F10" "SUPER + XF86AudioMute" "SUPER + XF86AudioLowerVolume" "SUPER + XF86AudioRaiseVolume")

keys=$(list_utility_keys 0) || fail "utilities bindings load off Apple Silicon" "$keys"
grep -Fxq 'PRINT' <<<"$keys" || fail "the shared Print Screen bind is present" "$keys"
for chord in "${apple_chords[@]}"; do
  ! grep -Fxq "$chord" <<<"$keys" || fail "$chord is bound off Apple Silicon" "$keys"
done
! grep -Fq 'SUPER + ALT + F12' <<<"$keys" || fail "Super+Alt+F12 stays unbound"
pass "capture chords leave SUPER+F10-F12 and the media chords unbound off Apple Silicon"

keys=$(list_utility_keys 1) || fail "utilities bindings load on Apple Silicon" "$keys"
for chord in "${apple_chords[@]}"; do
  grep -Fxq "$chord" <<<"$keys" || fail "$chord is bound on Apple Silicon" "$keys"
done
grep -Fxq 'PRINT' <<<"$keys" || fail "the shared Print Screen bind is still present on Apple Silicon"
pass "capture chords are bound on Apple Silicon"
