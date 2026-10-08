# Session assets arrive together in omarchy and omarchy-settings. Install the
# authenticated recovery hook only after both packages are in place.
/usr/bin/python3 -I "$OMARCHY_PATH/shell/session-guard-install.py"
