# Apple Silicon trackpads: natural scrolling and physical clicks. Asahi's
# disable_while_typing does not stop stray taps, so tap-to-click stays off.
# Appended to the user's override so x86 shipped defaults stay traditional.
omarchy-hw-apple-silicon || return 0

input="${OMARCHY_HYPR_INPUT:-$HOME/.config/hypr/input.lua}"
[[ -f $input ]] || return 0
grep -q 'omarchy-apple-touchpad' "$input" && return 0
# Either key already set is somebody's decision -- a fork template that shipped
# these values, or a user who turned natural scrolling off on purpose. Appending
# would override it, so only a file that says nothing about either gets the
# defaults.
if grep -Eq '^[[:space:]]*(natural_scroll|tap_to_click)[[:space:]]*=' "$input"; then
  return 0
fi

cat >>"$input" <<'LUA'

-- omarchy-apple-touchpad: natural scrolling and physical clicks. On the Asahi
-- touchpad, disable_while_typing alone does not stop stray taps while typing.
hl.config({
  input = {
    touchpad = {
      natural_scroll = true,
      tap_to_click = false,
    },
  },
})
LUA
