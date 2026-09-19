echo "Map the Asahi mic array to stereo and retry speakersafetyd"

# Fresh installs run the per-user mic leaf. Reuse it so existing Apple Silicon
# sessions get the same mapping without a reboot.
mic_setup="$OMARCHY_PATH/install/user/hardware/apple/mic.sh"
[[ -f $mic_setup ]] || exit 0
source "$mic_setup"
