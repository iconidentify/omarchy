echo "Install Obsidian's AppImage build on Apple Silicon"

# obsidian as a pkgbase installs nothing on ARM. Fresh installs run the user
# leaf; existing machines get the same repair here.
leaf="$OMARCHY_PATH/install/user/hardware/apple/obsidian.sh"
[[ -f $leaf ]] || exit 0
source "$leaf"
