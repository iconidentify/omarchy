echo "Install the packaged Steam FEX launcher on existing Apple Silicon Steam installs"

[[ $(uname -m) == aarch64 ]] || exit 0
omarchy-pkg-present steam || [[ -d $HOME/.local/share/Steam ]] || exit 0
omarchy-pkg-add omarchy-steam-fex
omarchy-cmd-present omarchy-launch-steam || exit 0
omarchy-launch-steam --prepare
