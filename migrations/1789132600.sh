echo "Enable the Asahi notch strip so the bar can use the full panel height"

# install/hardware/apple/enable-notch.sh runs on new installs only.
omarchy-hw-apple-silicon || exit 0
source "$OMARCHY_PATH/install/hardware/apple/enable-notch.sh"
