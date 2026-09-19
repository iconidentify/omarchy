echo "Install the package-owned Apple Wi-Fi default"

if omarchy-hw-apple-silicon && ! pacman -Q omarchy-mac >/dev/null 2>&1; then
  # A local candidate or another user may already have installed the add-on.
  # Acquire missing packages from the signed sync repository, never the AUR.
  # Publication of the matching add-on precedes this runtime update.
  sudo env OMARCHY_UPDATE_PACMAN=1 pacman -S --needed --noconfirm omarchy-mac
fi
