#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/base-test.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin"
cat >"$work/bin/omarchy-hw-apple-silicon" <<'STUB'
#!/bin/bash
[[ ${APPLE:-1} == 1 ]]
STUB
cat >"$work/bin/lspci" <<'STUB'
#!/bin/bash
echo "Broadcom [14e4:${WIFI_ID:-4433}]"
STUB
cat >"$work/bin/systemctl" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$CALLS"
exit "${SYSTEMCTL_STATUS:-0}"
STUB
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" CALLS="$work/calls"
stage="$work/root"
"$ROOT/install" "$stage"
setup="$stage/usr/bin/omarchy-mac-setup-system"
unit="$stage/etc/systemd/system/omarchy-wifi-resume-fix.service"
mkdir -p "${unit%/*}"
"$setup" "$stage"
[[ ! -e $unit ]] || fail 'fresh setup uses vendor unit'
grep -q 'enable omarchy-wifi-resume-fix.service' "$CALLS" || fail 'fresh setup enables recovery'
cp "$ROOT/legacy/${unit##*/}" "$unit"
"$setup" "$stage"
[[ ! -e $unit && -f $unit.omarchy-mac-retired ]] || fail 'recognized generated unit retires'
"$setup" "$stage"
# Simulate interruption after backup but before deleting a duplicate generated file.
cp "$ROOT/legacy/${unit##*/}" "$unit"
"$setup" "$stage"
[[ ! -e $unit ]] || fail 'interrupted retirement retries'
printf 'custom service\n' >"$unit"
: >"$CALLS"
"$setup" "$stage"
[[ $(cat "$unit") == 'custom service' && ! -s $CALLS ]] || fail 'custom unit survives setup'
rm "$unit"
ln -s /dev/null "$unit"
"$setup" "$stage"
[[ $(readlink "$unit") == /dev/null && ! -s $CALLS ]] || fail 'mask survives setup'
rm "$unit"
for spec in '0 4433' '1 4434' '1 0000'; do
  read -r apple wifi <<<"$spec"
  APPLE=$apple WIFI_ID=$wifi "$setup" "$stage"
  [[ ! -s $CALLS ]] || fail 'non-Apple and excluded hardware are untouched'
done
rm "$stage/var/lib/omarchy-mac/wifi-configured"
if SYSTEMCTL_STATUS=42 "$setup" "$stage"; then fail 'enable failure must be retryable'; fi
"$setup" "$stage"
pass 'fresh, upgrade, repeated, interrupted, overrides, masks and hardware gates'
for relative in etc/modprobe.d/asahi-notch.conf etc/NetworkManager/conf.d/wifi_backend.conf; do
  file="$stage/$relative"
  mkdir -p "${file%/*}"
  cp "$ROOT/legacy/${file##*/}" "$file"
  "$setup" "$stage"
  [[ ! -e $file && -f $file.omarchy-mac-retired ]] || fail 'generated config retires'
  printf 'administrator override\n' >"$file"
  "$setup" "$stage"
  [[ $(cat "$file") == 'administrator override' ]] || fail 'modified config survives'
done
user_setup="$stage/usr/bin/omarchy-mac-setup-user"
export XDG_RUNTIME_DIR="$work/no-session"
unset XDG_CONFIG_HOME XDG_STATE_HOME
for name in alice bob; do
  export HOME="$work/$name"
  policy="$HOME/.config/wireplumber/wireplumber.conf.d/asahi-headset-mic.conf"
  wants="$HOME/.config/systemd/user/graphical-session.target.wants/omarchy-asahi-mic.service"
  : >"$CALLS"
  "$user_setup" "$stage"
  "$user_setup" "$stage"
  [[ -L $wants && ! -s $CALLS && ! -e $policy ]] || fail 'offline setup needs no bus or private policy'
  mkdir -p "${policy%/*}"
  cp "$ROOT/legacy/asahi-headset-mic.conf" "$policy"
  "$user_setup" "$stage"
  [[ ! -e $policy && -f $policy.omarchy-mac-retired ]] || fail 'generated user policy retires'
  printf 'custom policy\n' >"$policy"
  "$user_setup" "$stage"
  [[ $(cat "$policy") == 'custom policy' ]] || fail 'custom user policy survives'
  rm "$policy"
  ln -s /missing-custom-target "$policy"
  "$user_setup" "$stage"
  [[ -L $policy ]] || fail 'dangling policy override survives'
done
for scope in "$HOME/.config/systemd/user" "$stage/etc/systemd/user"; do
  mkdir -p "$scope"
  rm -f "$wants"
  ln -s /dev/null "$scope/omarchy-asahi-mic.service"
  "$user_setup" "$stage"
  [[ ! -e $wants && ! -L $wants ]] || fail 'user and global masks remain disabled'
  rm "$scope/omarchy-asahi-mic.service"
  echo custom >"$scope/omarchy-asahi-mic.service"
  "$user_setup" "$stage"
  [[ ! -L $wants ]] || fail 'custom user fragment is left alone'
  rm "$scope/omarchy-asahi-mic.service"
done
ln -s /dev/null "$wants"
"$user_setup" "$stage"
[[ $(readlink "$wants") == /dev/null ]] || fail 'activation mask survives'
pass 'multiple users, offline setup, generated policy, custom fragments and masks'
# First-session activation and activation failures use a real fake bus socket.
python3 - "$user_setup" "$stage" "$work" <<'PY'
import os, socket, subprocess, sys
from pathlib import Path
setup, stage, work = sys.argv[1:]
# Redirect filesystem paths while exercising the default live-session branch.
script = Path(work)/'session-setup'
script.write_text(Path(setup).read_text().replace('$root/usr/', stage+'/usr/').replace('$root/etc/', stage+'/etc/').replace('$root/run/', stage+'/run/'))
script.chmod(0o755)
setup = str(script)
env = dict(os.environ, HOME=work+'/session', XDG_RUNTIME_DIR=work+'/runtime')
Path(env['XDG_RUNTIME_DIR']).mkdir()
with socket.socket(socket.AF_UNIX) as bus:
    bus.bind(env['XDG_RUNTIME_DIR']+'/bus')
    subprocess.run([setup], env=env, check=True)
    calls = Path(env['CALLS']).read_text()
    assert '--user daemon-reload' in calls and '--user start omarchy-asahi-mic.service' in calls
    result = subprocess.run([setup], env=dict(env, SYSTEMCTL_STATUS='42'))
    assert result.returncode == 42
PY
pass 'first-session activation errors remain retryable'

# An explicit disable after successful setup remains a choice on later runs.
rm "$wants"
"$user_setup" "$stage"
[[ ! -L $wants ]] || fail 'repeat setup preserves disabled microphone service'
: >"$CALLS"
"$setup" "$stage"
[[ ! -s $CALLS ]] || fail 'repeat setup does not reenable disabled Wi-Fi recovery'
pass 'explicit disables survive repeated setup'
