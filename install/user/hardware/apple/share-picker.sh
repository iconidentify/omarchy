# hyprland-preview-share-picker is in omarchy-base.packages and omarchy-aarch64.
# Older Chromium flag files still omit WebRTCPipeWireCapturer; write it on
# aarch64 only. Do not write this into shipped x86 defaults.
[[ $(uname -m) == "aarch64" ]] || return 0

# Same PipeWire capturer flag the migration writes for existing aarch64 configs.
# Modern Chromium enables it by default; this covers older user flag files on
# a fresh aarch64 install. Do not write this into shipped x86 defaults.
for conf in ~/.config/{chromium,brave,chrome,microsoft-edge-stable}-flags.conf; do
  [[ -f $conf ]] || continue
  grep -q 'WebRTCPipeWireCapturer' "$conf" && continue
  if grep -q -- '--enable-features=' "$conf"; then
    sed -i 's/\(^--enable-features=[^[:space:]]*\)/\1,WebRTCPipeWireCapturer/' "$conf"
  else
    [[ -n $(tail -c1 "$conf") ]] && echo >>"$conf"
    echo '--enable-features=WebRTCPipeWireCapturer' >>"$conf"
  fi
done
