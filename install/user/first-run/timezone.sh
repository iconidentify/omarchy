# The x86 ISO asks for a timezone while provisioning and applies it on first
# boot. Asahi Alarm ships UTC, so the machine keeps that until somebody
# notices. First run is a graphical session with nowhere to ask, so notify
# and open the timezone menu.

current_timezone() {
  timedatectl show --property=Timezone --value 2>/dev/null
}

# UTC is what the image ships, so it stands in for "nobody has chosen yet".
# Someone genuinely in UTC gets one notification and dismisses it.
timezone_needs_setting() {
  local timezone
  timezone=$(current_timezone)
  [[ -z $timezone || $timezone == "UTC" ]]
}

if timezone_needs_setting; then
  omarchy-notification-send -u critical -g 󰥔 "Set your timezone" \
    "This machine is on $(current_timezone). Click to choose yours." \
    --exec omarchy-launch-floating-terminal-with-presentation omarchy-menu-timezone
fi
