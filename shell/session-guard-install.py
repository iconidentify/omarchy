#!/usr/bin/python3
"""Install the authenticated SDDM recovery hook after its session assets."""

import configparser
import os
from pathlib import Path
import stat
import sys
import tempfile


PAM_LINE = "session required pam_exec.so seteuid /usr/bin/omarchy-session-guard --pam"
RELOGIN = "[Autologin]\nRelogin=false\n"
SERVICE_OVERRIDE = "[Service]\nExecStart=\nExecStart=/usr/bin/uwsm aux exec -- %I /usr/bin/omarchy-session-guard --run /usr/bin/Hyprland\n"


def check_relogin(target):
  # SDDM reads system drop-ins, local drop-ins, then /etc/sddm.conf.
  sources = sorted((target / "usr/lib/sddm/sddm.conf.d").glob("*.conf"))
  sources += sorted((target / "etc/sddm.conf.d").glob("*.conf"))
  sources += [target / "etc/sddm.conf"]
  effective = None
  for source in sources:
    if not source.exists():
      continue
    config = configparser.ConfigParser(interpolation=None, strict=False)
    config.read_string(source.read_text())
    if config.has_option("Autologin", "Relogin"):
      effective = config.get("Autologin", "Relogin").strip().lower()
  if effective != "false":
    raise RuntimeError("the effective SDDM Relogin policy must be false")


def replace_file(path, text):
  info = path.lstat()
  if not stat.S_ISREG(info.st_mode):
    raise RuntimeError(f"not a regular configuration file: {path}")
  fd, temporary = tempfile.mkstemp(prefix=".omarchy-session-guard-", dir=path.parent)
  try:
    with os.fdopen(fd, "w") as output:
      output.write(text)
      output.flush()
      os.fsync(output.fileno())
      os.fchmod(output.fileno(), stat.S_IMODE(info.st_mode))
      os.fchown(output.fileno(), info.st_uid, info.st_gid)
    os.replace(temporary, path)
  finally:
    if os.path.exists(temporary):
      os.unlink(temporary)


def configure_target(target, rollback=False):
  pam = target / "etc/pam.d/sddm"
  existing = pam.read_text()
  lines = existing.splitlines()
  if rollback:
    desktop = target / "usr/local/share/wayland-sessions/omarchy.desktop"
    guarded = target / "usr/local/share/wayland-sessions/omarchy-guarded-hyprland.desktop"
    service = target / "usr/lib/systemd/user/wayland-wm@hyprland.desktop.service.d/99-session-lock-recovery.conf"
    if guarded.exists() or service.exists() or (desktop.exists() and "omarchy-guarded-hyprland.desktop" in desktop.read_text()):
      raise RuntimeError("restore both previous packages before removing authenticated recovery")
    if PAM_LINE in lines:
      replace_file(pam, "\n".join(line for line in lines if line != PAM_LINE) + "\n")
    return

  helper = target / "usr/bin/omarchy-session-guard"
  implementation = target / "usr/share/omarchy/shell/session-guard.py"
  desktop = target / "usr/local/share/wayland-sessions/omarchy.desktop"
  guarded = target / "usr/local/share/wayland-sessions/omarchy-guarded-hyprland.desktop"
  relogin = target / "etc/sddm.conf.d/90-session-lock-recovery.conf"
  service = target / "usr/lib/systemd/user/wayland-wm@hyprland.desktop.service.d/99-session-lock-recovery.conf"
  if not os.access(helper, os.X_OK) or not implementation.is_file():
    raise RuntimeError("the session guard runtime must be installed first")
  if "Exec=uwsm start -g -1 -e -D Hyprland omarchy-guarded-hyprland.desktop\n" not in desktop.read_text():
    raise RuntimeError("the guarded Omarchy session must be installed first")
  if "Exec=omarchy-session-guard --run Hyprland\n" not in guarded.read_text():
    raise RuntimeError("the guarded Hyprland entry point must be installed first")
  if relogin.read_text() != RELOGIN:
    raise RuntimeError("SDDM automatic relogin must be disabled first")
  if service.read_text() != SERVICE_OVERRIDE:
    raise RuntimeError("the existing Hyprland service must select the guard")
  check_relogin(target)
  if PAM_LINE not in lines:
    replace_file(pam, existing.rstrip("\n") + "\n" + PAM_LINE + "\n")


if __name__ == "__main__":
  try:
    if os.geteuid() != 0:
      raise RuntimeError("system setup requires root")
    if sys.argv[1:] not in ([], ["--rollback"]):
      raise RuntimeError("expected no arguments or --rollback")
    configure_target(Path("/"), rollback=sys.argv[1:] == ["--rollback"])
  except (OSError, RuntimeError, configparser.Error) as error:
    print(f"omarchy-session-guard-install: {error}", file=sys.stderr)
    sys.exit(1)
