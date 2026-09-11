# Apple-like boards on x86 (Lofree Flow84) keep F-keys on the top row
# (fnmode=2). Apple Silicon wants media keys there, with F1-F12 behind Fn,
# the way macOS does (fnmode=1).
fnmode=2
if omarchy-hw-apple-silicon; then
  fnmode=1
fi

conf="${OMARCHY_HID_APPLE_CONF:-/etc/modprobe.d/hid_apple.conf}"
if [[ ! -f $conf ]]; then
  sudo mkdir -p "$(dirname "$conf")"
  echo "options hid_apple fnmode=$fnmode" | sudo tee "$conf" >/dev/null
fi
