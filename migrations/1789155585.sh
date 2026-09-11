echo "Install Widevine CDM for DRM streaming on Apple Silicon"

omarchy-hw-apple-silicon || exit 0
omarchy-pkg-available widevine || exit 0
omarchy-pkg-present widevine && exit 0
omarchy-pkg-add widevine
