#!/bin/bash

# Loopback rehearsal for omarchy-system-snapshot-restore. Needs root and is not
# part of ./test/shell: it creates a btrfs image, mounts it, and runs the real
# swap against it.
#
#   sudo bash test/manual/snapshot-restore-rehearsal.sh
#
# It builds @ with a nested snapper-style store holding one read-only snapshot,
# changes the live root, restores snapshot 1 through --rehearse, and then
# checks that the store came along and that @old-* deletes in one command.
# Every check is fatal: a rehearsal that reaches the end has passed.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
restore="$root/bin/omarchy-system-snapshot-restore"
(( EUID == 0 )) || { echo "run as root: sudo bash $0" >&2; exit 1; }

work=$(mktemp -d /tmp/omarchy-restore-rehearsal.XXXXXX)
img="$work/fs.img"
mnt="$work/mnt"
loop=""

cleanup() {
  umount "$mnt" 2>/dev/null || true
  [[ -z $loop ]] || losetup -d "$loop" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

check() {
  local description=$1
  shift
  if "$@"; then
    printf 'ok - %s\n' "$description"
  else
    printf 'not ok - %s\n' "$description" >&2
    exit 1
  fi
}

truncate -s 1G "$img"
loop=$(losetup --find --show "$img")
mkfs.btrfs -q "$loop"
mkdir -p "$mnt"
mount -o subvolid=5 "$loop" "$mnt"

btrfs subvolume create "$mnt/@" >/dev/null
mkdir -p "$mnt/@/usr/share/omarchy" "$mnt/@/usr/lib/modules/6.0.0-rehearsal"
echo "4.0.0-rehearsal" >"$mnt/@/usr/share/omarchy/version"
btrfs subvolume create "$mnt/@/.snapshots" >/dev/null
mkdir -p "$mnt/@/.snapshots/1"
echo original >"$mnt/@/marker"
btrfs subvolume snapshot -r "$mnt/@" "$mnt/@/.snapshots/1/snapshot" >/dev/null
printf '<snapshot><date>2026-09-13 09:00:00</date><description>pre-update</description></snapshot>\n' >"$mnt/@/.snapshots/1/info.xml"
echo changed >"$mnt/@/marker"

check "the snapshot holds an empty placeholder where the nested store was" test -d "$mnt/@/.snapshots/1/snapshot/.snapshots"
check "the snapshot's placeholder is not a subvolume" bash -c '! btrfs subvolume show "$1" >/dev/null 2>&1' _ "$mnt/@/.snapshots/1/snapshot/.snapshots"

OMARCHY_SNAPSHOT_RESTORE_CHOICE=1 "$restore" --rehearse "$mnt"

check "@ holds the restored content" test "$(cat "$mnt/@/marker")" = original
check "@/.snapshots is a subvolume again" btrfs subvolume show "$mnt/@/.snapshots"
check "snapshot 1 is still in the store" test -d "$mnt/@/.snapshots/1/snapshot"
check "snapper's info.xml came along" test -f "$mnt/@/.snapshots/1/info.xml"
old=$(ls -d "$mnt"/@old-* | head -1)
check "the displaced root is kept as @old-<stamp>" test -n "$old"
check "the displaced root holds the changed content" test "$(cat "$old/marker")" = changed
check "nothing nested is left in the displaced root" test ! -e "$old/.snapshots"
check "the displaced root deletes in one command" btrfs subvolume delete "$old"
check "no @new is left behind" test ! -e "$mnt/@new"

echo "rehearsal complete: every check passed"
