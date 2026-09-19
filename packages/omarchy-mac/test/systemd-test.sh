#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
"$ROOT"/install "$work/root"
mkdir -p "$work/root/etc/systemd/system" "$work/bin"
cp "$ROOT"/legacy/omarchy-wifi-resume-fix.service "$work/root/etc/systemd/system/"
systemctl --root="$work/root" enable omarchy-wifi-resume-fix.service
printf '#!/bin/bash\nexit 0\n' >"$work/bin/omarchy-hw-apple-silicon"
printf '#!/bin/bash\necho "14e4:4433"\n' >"$work/bin/lspci"
chmod +x "$work/bin/"*
PATH="$work/bin:$PATH" "$work/root/usr/bin/omarchy-mac-setup-system" "$work/root"
for target in suspend hibernate hybrid-sleep suspend-then-hibernate; do
  link="$work/root/etc/systemd/system/$target.target.wants/omarchy-wifi-resume-fix.service"
  [[ $(readlink "$link") == /usr/lib/systemd/system/omarchy-wifi-resume-fix.service ]] || fail 'legacy enablement points to vendor unit'
done
pass 'real systemctl upgrade repairs generated enablement links' 
