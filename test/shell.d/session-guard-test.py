import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch


ROOT = Path(sys.argv.pop(1))
ENTRY = ROOT / "bin/omarchy-session-guard"
spec = importlib.util.spec_from_file_location("session_guard", ROOT / "shell/session-guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
install_spec = importlib.util.spec_from_file_location("session_guard_install", ROOT / "shell/session-guard-install.py")
installer = importlib.util.module_from_spec(install_spec)
install_spec.loader.exec_module(installer)


class SessionGuardTest(unittest.TestCase):
  def setUp(self):
    self.fixture = tempfile.TemporaryDirectory()
    self.addCleanup(self.fixture.cleanup)
    self.home = Path(self.fixture.name)
    self.env = {**os.environ, "HOME": str(self.home), "OMARCHY_PATH": str(ROOT)}
    self.state = self.home / ".local/state/omarchy/session-guard"
    self.started = self.home / "frames"

  def invoke(self, *arguments, **kwargs):
    return subprocess.run([str(ENTRY), *arguments], env=self.env, capture_output=True, text=True, **kwargs)

  def frame_command(self):
    return [sys.executable, "-c", "import pathlib,sys; pathlib.Path(sys.argv[1]).write_text('frame')", str(self.started)]

  def test_unlocked_start_and_status(self):
    self.assertEqual(self.invoke("--run", *self.frame_command()).returncode, 0)
    self.assertEqual(self.started.read_text(), "frame")
    self.assertEqual(self.invoke("--run", "sh", "-c", "exit 17").returncode, 17)

  def test_locked_restart_has_no_compositor_exec_or_frame(self):
    self.assertEqual(self.invoke("--arm").returncode, 0)
    restarted = self.invoke("--run", *self.frame_command())
    self.assertEqual(restarted.returncode, 1)
    self.assertIn("authenticate at the greeter", restarted.stderr)
    self.assertFalse(self.started.exists())

  def test_unlock_and_reboot_preserve_intent(self):
    self.assertEqual(self.invoke("--arm").returncode, 0)
    # A new process with a different runtime directory still sees disk intent.
    self.env["XDG_RUNTIME_DIR"] = str(self.home / "new-runtime")
    self.assertEqual(self.invoke("--run", *self.frame_command()).returncode, 1)
    self.assertFalse(self.started.exists())
    self.assertEqual(self.invoke("--clear").returncode, 0)
    self.assertEqual(self.invoke("--run", *self.frame_command()).returncode, 0)

  def test_arm_and_clear_are_idempotent(self):
    for _ in range(2):
      self.assertEqual(self.invoke("--arm").returncode, 0)
    for _ in range(2):
      self.assertEqual(self.invoke("--clear").returncode, 0)

  def test_crash_while_locked_blocks_queued_replacement(self):
    ready = self.home / "ready"
    command = [sys.executable, "-c", "import pathlib,sys,time; pathlib.Path(sys.argv[1]).touch(); time.sleep(30)", str(ready)]
    running = subprocess.Popen([str(ENTRY), "--run", *command], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    replacement = None
    try:
      deadline = time.monotonic() + 5
      while not ready.exists() and time.monotonic() < deadline:
        time.sleep(0.01)
      self.assertTrue(ready.exists())
      replacement = subprocess.Popen([str(ENTRY), "--run", *self.frame_command()], env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
      time.sleep(0.1)
      self.assertIsNone(replacement.poll())
      self.assertEqual(self.invoke("--arm").returncode, 0)
      running.send_signal(signal.SIGTERM)
      self.assertEqual(running.wait(timeout=5), 128 + signal.SIGTERM)
      self.assertEqual(replacement.wait(timeout=5), 1)
      self.assertFalse(self.started.exists())
    finally:
      for process in (running, replacement):
        if process:
          if process.poll() is None:
            process.kill()
          process.communicate(timeout=5)

  def test_marker_and_directory_failures_deny_exec(self):
    self.assertEqual(self.invoke("--arm").returncode, 0)
    self.state.chmod(0o755)
    self.assertEqual(self.invoke("--run", *self.frame_command()).returncode, 1)
    self.state.chmod(0o700)
    (self.state / "locked").unlink()
    (self.state / "locked").symlink_to(self.home / "missing")
    self.assertEqual(self.invoke("--arm").returncode, 1)
    self.assertEqual(self.invoke("--run", *self.frame_command()).returncode, 1)
    self.assertFalse(self.started.exists())

  def test_pam_unprivileged_or_autologin_cannot_clear(self):
    self.assertEqual(self.invoke("--arm").returncode, 0)
    self.env.update(PAM_SERVICE="sddm", PAM_TYPE="open_session", PAM_USER="owner")
    self.assertEqual(self.invoke("--pam").returncode, 1)
    self.assertTrue((self.state / "locked").exists())
    with patch.object(guard.os, "geteuid", return_value=0), patch.dict(guard.os.environ, {"PAM_SERVICE": "sddm-autologin", "PAM_TYPE": "open_session"}):
      with self.assertRaises(RuntimeError):
        guard.authenticated_login()

  def test_pam_password_login_drops_privileges_before_state_access(self):
    account = type("Account", (), {"pw_uid": 1234, "pw_gid": 1234, "pw_dir": str(self.home)})()
    order = []
    with patch.dict(guard.os.environ, {"PAM_SERVICE": "sddm", "PAM_TYPE": "open_session", "PAM_USER": "owner"}), patch.object(guard.os, "geteuid", return_value=0), patch.object(guard.pwd, "getpwnam", return_value=account), patch.object(guard.os, "setgroups", side_effect=lambda groups: order.append(("groups", groups))), patch.object(guard.os, "setgid", side_effect=lambda gid: order.append(("gid", gid))), patch.object(guard.os, "setuid", side_effect=lambda uid: order.append(("uid", uid))):
      self.assertTrue(guard.authenticated_login())
      self.assertEqual(order, [("groups", []), ("gid", 1234), ("uid", 1234)])
      self.assertEqual(guard.os.environ["HOME"], str(self.home))

  def test_close_session_does_not_clear(self):
    with patch.object(guard.os, "geteuid", return_value=0), patch.dict(guard.os.environ, {"PAM_SERVICE": "sddm", "PAM_TYPE": "close_session"}):
      self.assertFalse(guard.authenticated_login())

  def test_bash_startup_injection_and_decoy_privileged_argument(self):
    injected = self.home / "injected"
    startup = self.home / "startup"
    startup.write_text(f"touch '{injected}'\n")
    self.env["BASH_ENV"] = str(startup)
    self.assertEqual(self.invoke("--arm").returncode, 0)
    self.assertFalse(injected.exists())
    rejected = subprocess.run(["bash", str(ENTRY), "-p", "--arm"], env=self.env, capture_output=True, text=True)
    self.assertEqual(rejected.returncode, 1)
    self.assertIn("privileged Bash startup is required", rejected.stderr)

  def stage_target(self):
    def place(relative, text, mode=0o644):
      output = self.home / relative
      output.parent.mkdir(parents=True, exist_ok=True)
      output.write_text(text)
      output.chmod(mode)
    place("usr/bin/omarchy-session-guard", ENTRY.read_text(), 0o755)
    place("usr/share/omarchy/shell/session-guard.py", (ROOT / "shell/session-guard.py").read_text())
    for entry in ("omarchy.desktop", "omarchy-guarded-hyprland.desktop"):
      place("usr/local/share/wayland-sessions/" + entry, (ROOT / "default/wayland-sessions" / entry).read_text())
    place("etc/sddm.conf.d/90-session-lock-recovery.conf", (ROOT / "etc/sddm.conf.d/90-session-lock-recovery.conf").read_text())
    place("etc/pam.d/sddm", "auth include system-login\naccount include system-login\nsession include system-login\n")
    place("etc/pam.d/sddm-autologin", "auth required pam_permit.so\nsession include system-login\n")

  def test_deployment_idempotence_and_rollback(self):
    self.stage_target()
    pam = self.home / "etc/pam.d/sddm"
    autologin = self.home / "etc/pam.d/sddm-autologin"
    original, auto_before = pam.read_bytes(), autologin.read_bytes()
    for _ in range(2):
      installer.configure_target(self.home)
    self.assertEqual(pam.read_text().count(installer.PAM_LINE), 1)
    self.assertEqual(autologin.read_bytes(), auto_before)
    for _ in range(2):
      installer.configure_target(self.home, rollback=True)
    self.assertEqual(pam.read_bytes(), original)
    self.assertEqual(autologin.read_bytes(), auto_before)

  def test_partial_deployment_or_relogin_override_leaves_pam_unchanged(self):
    self.stage_target()
    pam = self.home / "etc/pam.d/sddm"
    original = pam.read_bytes()
    guarded = self.home / "usr/local/share/wayland-sessions/omarchy-guarded-hyprland.desktop"
    guarded.unlink()
    with self.assertRaises(OSError):
      installer.configure_target(self.home)
    self.assertEqual(pam.read_bytes(), original)
    guarded.write_text((ROOT / "default/wayland-sessions/omarchy-guarded-hyprland.desktop").read_text())
    override = self.home / "etc/sddm.conf"
    override.write_text("[Autologin]\nRelogin=true\n")
    with self.assertRaises(RuntimeError):
      installer.configure_target(self.home)
    self.assertEqual(pam.read_bytes(), original)

  def test_pre_existing_symlink_pam_is_not_replaced(self):
    self.stage_target()
    pam = self.home / "etc/pam.d/sddm"
    original = pam.read_bytes()
    other = self.home / "other-pam"
    other.write_bytes(original)
    pam.unlink()
    pam.symlink_to(other)
    with self.assertRaises(RuntimeError):
      installer.configure_target(self.home)
    self.assertTrue(pam.is_symlink())
    self.assertEqual(other.read_bytes(), original)


unittest.main()
