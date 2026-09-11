echo "Replace hyprland-preview-share-picker-git with the packaged picker"

# Existing Macs installed -git from the old migration. The packaged build does
# not conflict or replace it, and both ship the same binary, so pkg-add hits
# a file conflict unless -git is removed first.
omarchy-hw-apple-silicon || exit 0

if omarchy-pkg-present hyprland-preview-share-picker-git; then
  omarchy-pkg-drop hyprland-preview-share-picker-git
fi

omarchy-pkg-add hyprland-preview-share-picker
