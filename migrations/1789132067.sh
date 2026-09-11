echo "Use media keys by default on Apple Silicon keyboards (Fn for F-keys)"

# fnmode=1 (fkeyslast) puts volume/brightness/media on the top row and moves
# F1-F12 behind Fn, the way macOS does. Only Apple Silicon gets this: x86
# Apple-like boards (Lofree Flow84) keep fnmode=2 so the top row stays F-keys.
omarchy-hw-apple-silicon || exit 0

config="${OMARCHY_HID_APPLE_CONF:-/etc/modprobe.d/hid_apple.conf}"
# Records that the config was rewritten but the initramfs rebuild has not
# succeeded yet. It outlives a failed rebuild and a retry by another user, and
# it is what lets a rerun tell "already fnmode=1, rebuild still owed" apart from
# "the user chose fnmode=1 themselves".
pending="${OMARCHY_HID_APPLE_PENDING:-/var/lib/omarchy/migrations/1789132067-initramfs-pending}"

# hid_apple ships inside the initramfs so a LUKS passphrase can be typed before
# root is mounted, and mkinitcpio's modconf hook snapshots /etc/modprobe.d at
# build time. Rebuild so the new option reaches boot. A failed rebuild leaves
# the migration pending so it runs again, rather than marking done a change
# that the next boot will not have.
rebuild_initramfs() {
  echo "Rebuilding the initramfs so fnmode=1 survives a reboot"
  if ! sudo mkinitcpio -P; then
    echo "mkinitcpio failed; the fnmode migration will retry on the next run." >&2
    exit 1
  fi
  sudo rm -f -- "$pending"
}

# Only replace the old install default of fnmode=2 (fkeysfirst). If the file is
# missing, write it; if it names any other mode, the user chose that, so leave it.
if [[ -f $config ]] && ! grep -q 'fnmode=2' "$config"; then
  if [[ -f $pending ]]; then
    rebuild_initramfs
    exit 0
  fi
  echo "Keeping existing hid_apple options in $config"
  exit 0
fi

sudo install -Dm644 /dev/null "$pending"
sudo mkdir -p "$(dirname "$config")"
echo "options hid_apple fnmode=1" | sudo tee "$config" >/dev/null

# Apply now so the top row changes behavior without a reboot.
fnmode_param="${OMARCHY_HID_APPLE_FNMODE:-/sys/module/hid_apple/parameters/fnmode}"
if [[ -f $fnmode_param ]]; then
  echo 1 | sudo tee "$fnmode_param" >/dev/null || true
fi

rebuild_initramfs
