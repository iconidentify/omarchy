echo "Give the machine a UTF-8 locale"

# Asahi Alarm ships LANG=C and no install step ever replaced it, so every Mac
# installed by hand runs non-UTF-8 until this repairs it.
locale_setup="$OMARCHY_PATH/install/config/locale.sh"
locale_conf="${OMARCHY_LOCALE_CONF:-/etc/locale.conf}"

[[ -f $locale_setup ]] || exit 0

before=$(cat "$locale_conf" 2>/dev/null || true)
source "$locale_setup"
[[ $(cat "$locale_conf" 2>/dev/null || true) != "$before" ]] || exit 0

echo "Log out and back in for $LANG to reach your session"
