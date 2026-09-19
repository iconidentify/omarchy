#!/bin/bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
cat >"$work/bin/omarchy-hw-apple-silicon" <<'STUB'
#!/bin/bash
[[ ${APPLE:-0} == 1 ]]
STUB
cat >"$work/bin/sudo" <<'STUB'
#!/bin/bash
"$@"
STUB
cat >"$work/bin/pacman" <<'STUB'
#!/bin/bash
echo "$*" >>"$CALLS"
if [[ $1 == "-Q" ]]; then
  [[ -e $INSTALLED ]] || exit 1
else
  (( ${PKG_STATUS:-0} == 0 )) || exit "$PKG_STATUS"
  touch "$INSTALLED"
fi
STUB
cat >"$work/bin/systemctl" <<'STUB'
#!/bin/bash
[[ $1 != is-active && $1 != is-enabled ]]
STUB
for helper in omarchy-mac-setup-system omarchy-mac-setup-user; do
  printf '#!/bin/bash\necho "${0##*/}" >>"$CALLS"\nexit "${SETUP_STATUS:-0}"\n' >"$work/bin/$helper"
done
chmod +x "$work/bin/"*
cat >"$work/bin/lspci" <<'STUB'
#!/bin/bash
echo 'Broadcom [14e4:4433]'
STUB
chmod +x "$work/bin/lspci"
export OMARCHY_PATH="$ROOT"
export INSTALLED="$work/installed"
ln -s "$ROOT/bin/omarchy-setup-mac" "$work/bin/omarchy-setup-mac"
export CALLS="$work/calls" PATH="$work/bin:$PATH"
# Historical leaves must acquire the add-on in their original execution scope.
for spec in 'enable-notch.sh --system' 'fix-wifi-resume.sh --system' 'mic.sh --user'; do
  read -r leaf scope <<<"$spec"
  rm -f "$INSTALLED"
  : >"$CALLS"
  APPLE=1 omarchy-setup-mac "$scope"
  if [[ $scope == "--system" ]]; then
    ! grep -Fxq omarchy-mac-setup-user "$CALLS" || fail 'root compatibility setup must not configure the root user'
  else
    ! grep -Fxq omarchy-mac-setup-system "$CALLS" || fail 'user leaf delegates only user setup'
  fi
done
: >"$CALLS"
# Redirect legacy networkd cleanup to a temporary root as well.
sed "s|/etc/systemd/network/|$work/network/|g" "$ROOT/install/hardware/network.sh" >"$work/network.sh"
# Existing installs run the transition before invoking the package helpers.
for migration in 1789132600 1789136143 1789140994 1789275235 1789780917; do
  rm -f "$INSTALLED"
  APPLE=0 bash -euo pipefail "$ROOT/migrations/$migration.sh"
  [[ ! -e $INSTALLED ]] || fail 'non-Apple migration must not install add-on'
  APPLE=1 bash -euo pipefail "$ROOT/migrations/$migration.sh"
  [[ -e $INSTALLED ]] || fail 'historical and current migrations acquire add-on'
  APPLE=1 bash -euo pipefail "$ROOT/migrations/$migration.sh"
done
[[ $(grep -c -- '^-S --needed --noconfirm omarchy-mac$' "$CALLS") == 5 ]] || fail 'each migration acquires the add-on only when missing'
# Local package candidates must work before signed repository publication.
: >"$CALLS"
APPLE=1 PKG_STATUS=42 bash -euo pipefail "$ROOT/migrations/1789275235.sh"
! grep -q -- '^-S ' "$CALLS" || fail 'installed add-on must not require a sync repository entry'
rm "$INSTALLED"
status=0
APPLE=1 PKG_STATUS=42 bash -euo pipefail "$ROOT/migrations/1789275235.sh" || status=$?
[[ $status == 42 && ! -e $INSTALLED ]] || fail 'historical acquisition failure must remain retryable'
APPLE=1 bash -euo pipefail "$ROOT/migrations/1789275235.sh"
[[ -e $INSTALLED ]] || fail 'historical acquisition must succeed on retry'
pass 'local add-on candidates need no sync entry and missing-package failures retry'
for apple in 0 1; do
  APPLE=$apple bash -eE -c 'source "$1"' bash "$work/network.sh"
done
rm "$INSTALLED"
status=0
APPLE=1 PKG_STATUS=42 bash -euo pipefail "$ROOT/migrations/1789780917.sh" || status=$?
[[ $status == 42 && ! -e $INSTALLED ]] || fail 'failed installation stays pending'
status=0
APPLE=1 bash -eE -c 'source "$1"' bash "$work/network.sh" || status=$?
[[ $status == 1 ]] || fail 'fresh setup requires preinstalled add-on'
status=0
APPLE=1 SETUP_STATUS=43 bash -euo pipefail "$ROOT/migrations/1789780917.sh" || status=$?
[[ $status == 43 ]] || fail 'setup failure stays pending after package acquisition'
APPLE=1 bash -euo pipefail "$ROOT/migrations/1789780917.sh"
grep -Fxq omarchy-mac "$ROOT/install/omarchy-apple.packages" || fail 'Apple fresh-install inputs require the package'
pass 'Apple-only acquisition, historical ordering and interrupted transition are retryable'
