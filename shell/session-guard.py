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
import uuid


def state_path():
  return Path(os.environ.get("HOME") or pwd.getpwuid(os.getuid()).pw_dir) / ".local/state/omarchy/session-guard"


def open_state():
  home = state_path().parents[3]
  fd = os.open(home, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
  try:
    info = os.fstat(fd)
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o022:
      raise RuntimeError("HOME must be owned and not writable by other users")
    for name in (".local", "state", "omarchy", "session-guard"):
      try:
        os.mkdir(name, 0o700, dir_fd=fd)
      except FileExistsError:
        pass
      child = os.open(name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
      info = os.fstat(child)
      if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o022 or (name == "session-guard" and stat.S_IMODE(info.st_mode) != 0o700):
        os.close(child)
        raise RuntimeError("invalid owner or permissions in the lock state namespace")
      try:
        # Both the directory and its name in the parent must survive reboot.
        os.fsync(child)
        os.fsync(fd)
      except BaseException:
        os.close(child)
        raise
      os.close(fd)
      fd = child
  except BaseException:
    os.close(fd)
    raise
  return fd


def open_file(directory, name, create=True):
  flags = os.O_RDWR | os.O_NOFOLLOW | (os.O_CREAT if create else 0)
  fd = os.open(name, flags, 0o600, dir_fd=directory)
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


def change_intent(directory, locked, generation=None):
  # Serialize marker updates with compositor admission.
  fd = open_file(directory, "intent.lock")
  try:
    fcntl.flock(fd, fcntl.LOCK_EX)
    if locked:
      generation = uuid.uuid4().hex
      marker = open_file(directory, "locked")
      try:
        os.ftruncate(marker, 0)
        os.write(marker, (generation + "\n").encode("ascii"))
        os.fsync(marker)
      finally:
        os.close(marker)
    else:
      try:
        if generation is not None:
          if not is_locked(directory):
            return
          marker = open_file(directory, "locked", create=False)
          try:
            if os.read(marker, 128).decode("ascii").strip() != generation:
              return
          finally:
            os.close(marker)
        os.unlink("locked", dir_fd=directory)
      except FileNotFoundError:
        pass
    os.fsync(directory)
    if locked:
      return generation
  finally:
    os.close(fd)


def prepare_unlock(directory, generation):
  # The caller has authenticated, but still holds the protocol lock. Leave
  # durable intent in place until that lock has actually been released.
  admission = open_file(directory, "intent.lock")
  try:
    fcntl.flock(admission, fcntl.LOCK_EX)
    marker = open_file(directory, "locked", create=False)
    try:
      if os.read(marker, 128).decode("ascii").strip() != generation:
        raise RuntimeError("lock generation changed before authenticated unlock")
      os.fsync(marker)
      os.fsync(directory)
    finally:
      os.close(marker)
  finally:
    os.close(admission)


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
  if operation not in ("--arm", "--prepare-unlock", "--clear", "--run"):
    raise RuntimeError("expected --arm, --prepare-unlock, --clear, --run or --pam")
  directory = open_state()
  try:
    if operation == "--run":
      return run_compositor(directory, arguments[1:])
    if operation == "--prepare-unlock":
      if len(arguments) != 2:
        raise RuntimeError("unlock preparation requires its lock generation")
      prepare_unlock(directory, arguments[1])
      return 0
    generation = arguments[1] if len(arguments) == 2 else None
    result = change_intent(directory, operation == "--arm", generation)
    if result:
      print(result)
    return 0
  finally:
    os.close(directory)


if __name__ == "__main__":
  try:
    sys.exit(main(sys.argv[1:]))
  except (OSError, RuntimeError, KeyError, ValueError) as error:
    print(f"omarchy-session-guard: {error}", file=sys.stderr)
    sys.exit(1)
