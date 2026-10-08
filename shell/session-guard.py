#!/usr/bin/python3
"""Keep a compositor restart behind authentication after a session lock."""

import fcntl
import os
from pathlib import Path
import pwd
import signal
import stat
import subprocess
import sys


def state_path():
  return Path(os.environ.get("HOME") or pwd.getpwuid(os.getuid()).pw_dir) / ".local/state/omarchy/session-guard"


def open_state():
  path = state_path()
  path.mkdir(mode=0o700, parents=True, exist_ok=True)
  fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
  info = os.fstat(fd)
  if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
    os.close(fd)
    raise RuntimeError("lock state must be an owned directory with mode 0700")
  return fd


def open_file(directory, name):
  fd = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600, dir_fd=directory)
  info = os.fstat(fd)
  if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1:
    os.close(fd)
    raise RuntimeError("invalid lock state file")
  return fd


def is_locked(directory):
  try:
    os.stat("locked", dir_fd=directory, follow_symlinks=False)
    return True
  except FileNotFoundError:
    return False


def change_intent(directory, locked):
  # Serialize marker updates with compositor admission.
  fd = open_file(directory, "intent.lock")
  try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    if locked:
      marker = open_file(directory, "locked")
      try:
        os.fsync(marker)
      finally:
        os.close(marker)
    else:
      try:
        os.unlink("locked", dir_fd=directory)
      except FileNotFoundError:
        pass
    os.fsync(directory)
  finally:
    os.close(fd)


def run_compositor(directory, command):
  if not command:
    raise RuntimeError("no compositor command was supplied")
  lease = open_file(directory, "compositor.lock")
  admission = open_file(directory, "intent.lock")
  try:
    # A replacement waits until the previous compositor has stopped, then
    # checks the marker. It cannot pass admission beside a still-locked child.
    fcntl.flock(lease, fcntl.LOCK_EX)
    fcntl.flock(admission, fcntl.LOCK_EX)
    if is_locked(directory):
      raise RuntimeError("session remains locked; authenticate at the greeter")
    child = subprocess.Popen(command, pass_fds=(lease,))
    fcntl.flock(admission, fcntl.LOCK_UN)
    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
      signal.signal(signum, lambda received, frame: child.send_signal(received))
    status = child.wait()
    return status if status >= 0 else 128 - status
  finally:
    os.close(admission)
    os.close(lease)


def authenticated_login():
  # sddm-autologin never clears lock intent. Only the password/fingerprint
  # authenticated SDDM stack installs this open_session hook.
  if os.geteuid() != 0 or os.environ.get("PAM_SERVICE") != "sddm":
    raise RuntimeError("authenticated SDDM session required")
  if os.environ.get("PAM_TYPE") != "open_session":
    return False
  account = pwd.getpwnam(os.environ.get("PAM_USER", ""))
  if account.pw_uid == 0:
    raise RuntimeError("root graphical sessions are not supported")
  os.setgroups([])
  os.setgid(account.pw_gid)
  os.setuid(account.pw_uid)
  os.environ["HOME"] = account.pw_dir
  return True


def main(arguments):
  operation = arguments[0] if arguments else ""
  if operation == "--pam":
    if not authenticated_login():
      return 0
    operation = "--clear"
  elif os.geteuid() == 0:
    raise RuntimeError("root may only use the authenticated PAM hook")
  if operation not in ("--arm", "--clear", "--run"):
    raise RuntimeError("expected --arm, --clear, --run or --pam")
  directory = open_state()
  try:
    if operation == "--run":
      return run_compositor(directory, arguments[1:])
    change_intent(directory, operation == "--arm")
    return 0
  finally:
    os.close(directory)


if __name__ == "__main__":
  try:
    sys.exit(main(sys.argv[1:]))
  except (OSError, RuntimeError, KeyError) as error:
    print(f"omarchy-session-guard: {error}", file=sys.stderr)
    sys.exit(1)
