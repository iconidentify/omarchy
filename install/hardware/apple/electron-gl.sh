# Global launchers belong to system setup, never graphical user finalization.
omarchy-hw-apple-silicon || return 0

for app in chromium 1password cursor; do
  if [[ $app == "chromium" ]]; then
    real=${OMARCHY_CHROMIUM_BIN:-/usr/bin/chromium}
  elif [[ $app == "1password" ]]; then
    real=${OMARCHY_1PASSWORD_BIN:-/opt/1Password/1password}
  else
    real=${OMARCHY_CURSOR_BIN:-/usr/bin/cursor}
  fi
  if [[ -x $real ]]; then
    if omarchy-cmd-electron-gl-wrap "$app" "$real"; then
      :
    else
      status=$?
      if ((status == 3)); then
        echo "Preserving administrator-owned $app launcher" >&2
      else
        return "$status"
      fi
    fi
  fi
done
