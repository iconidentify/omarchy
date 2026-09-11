echo "Use macOS-like trackpad defaults on Apple Silicon"

# Fresh installs run install/user/hardware/apple/touchpad.sh. Existing Apple
# Silicon users still have the shipped traditional-scroll default.
leaf="$OMARCHY_PATH/install/user/hardware/apple/touchpad.sh"
[[ -f $leaf ]] || exit 0
source "$leaf"
