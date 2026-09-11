echo "Brand the GRUB boot on Apple Silicon: plymouth hook, quiet splash, Omarchy menu title"

# Fresh installs run install/login/grub-splash.sh from omarchy-apply-system.
# Macs installed from the overlay never did, so their boot menu still offers
# "Arch Linux" and the LUKS passphrase prompt is plymouth's stock one.
omarchy-hw-apple-silicon || exit 0

leaf="$OMARCHY_PATH/install/login/grub-splash.sh"
[[ -f $leaf ]] || exit 0

if (( EUID == 0 )); then
  bash -euo pipefail -c 'source "$1"' bash "$leaf"
else
  sudo env OMARCHY_PATH="$OMARCHY_PATH" bash -euo pipefail -c 'source "$1"' bash "$leaf"
fi
