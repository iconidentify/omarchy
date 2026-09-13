echo "Add the [omarchy-aarch64] repository on Apple Silicon"

# Existing Apple Silicon installs that never had the stanza cannot pkg-add any
# of Omarchy's own aarch64 packages, and several later Apple migrations do:
# video decode, Widevine, the packaged share picker. This sorts before every
# one of them. The leaf adds the repository, fetches its database, and stays
# pending (non-zero) until that fetch has succeeded once.
omarchy-hw-apple-silicon || exit 0

source "$OMARCHY_PATH/install/hardware/apple/pacman.sh"
