# Apple Silicon has no Omarchy repository in pacman.conf by default: the
# post-install restore deliberately skips the x86 pacman.conf and mirrorlist,
# and Arch Linux ARM carries none of Omarchy's own packages. The aarch64 builds
# of those live in [omarchy-aarch64], published from omarchy-pkgs-aarch64. The
# video decode, 1Password, Cursor, voxtype, Widevine and share-picker installs
# all pkg-add from it, so this runs before every other Apple leaf.
#
# Unsigned, so SigLevel matches what that repository documents. Sourced by
# install/hardware/all.sh as root during setup, and by the migration as a
# user, hence the sudo fallback.
#
# Adding the stanza is not enough: pacman refuses to install from a repository
# whose database it has never fetched. The pending marker records a sync still
# owed, so a fetch that failed (no network yet) is retried on the next run
# instead of leaving a configured repository nothing can install from.
omarchy-hw-apple-silicon || return 0

pacman_conf="${OMARCHY_PACMAN_CONF:-/etc/pacman.conf}"
sync_pending="${OMARCHY_AARCH64_REPO_PENDING:-/var/lib/omarchy/migrations/omarchy-aarch64-sync-pending}"
OMARCHY_AARCH64_REPO_ADDED=0

if (( ${EUID:-$(id -u)} == 0 )); then
  as_root=()
else
  as_root=(sudo)
fi

if ! grep -q '^\[omarchy-aarch64\]' "$pacman_conf"; then
  echo "Adding the [omarchy-aarch64] repository to $pacman_conf"
  "${as_root[@]}" install -Dm644 /dev/null "$sync_pending"
  "${as_root[@]}" tee -a "$pacman_conf" >/dev/null <<'REPO'

[omarchy-aarch64]
SigLevel = Optional TrustAll
Server = https://github.com/omarchy-mac/omarchy-pkgs-aarch64/releases/download/edge
REPO
  OMARCHY_AARCH64_REPO_ADDED=1
fi

if [[ -f $sync_pending ]]; then
  echo "Fetching the [omarchy-aarch64] package database"
  if ! "${as_root[@]}" pacman -Sy; then
    echo "Could not fetch the [omarchy-aarch64] database; it will be retried on the next run." >&2
    return 1
  fi
  "${as_root[@]}" rm -f -- "$sync_pending"
fi
