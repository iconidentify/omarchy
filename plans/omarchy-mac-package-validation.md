# omarchy-mac candidate validation

Updated 2026-09-19. The coordinated package trial passed on Scott's M2 Max. The candidate is prepared for review and a separate merge decision; no code was merged into `quattro-upstream`, and no candidate was added to the rolling package feed.

## Recorded inputs

| Input | Revision or version |
| --- | --- |
| Desktop baseline | `350c46550b99688cdb5224408edd5870de2ca07b` |
| Shared branch, including the published plan | `efb7ca918dcdb30fd050b8553020aa97e01f1d51` |
| Final code and all three locally built package sources | `20b8ae0fb6e2593172226f9f8cf0bb79e666d2aa` |
| Add-on recipe and companion verification tooling | `290e4c8a2a848897494db67c6047c5fda62037b8` |
| Upstream runtime/settings recipes adapted for local candidates | `6d27290193109c07b0134360d382e64790ae5dda` |
| Installed runtime and settings | `4.0.3.r1.mac.20b8ae0f-1` |
| Installed add-on | `0.1.0-4` |
| Published Steam package included in the transaction | `omarchy-steam-fex 1.0.0-1` |

The desktop review branch is `integrate/omarchy-mac-package` in `omacom/omarchy-mac`; packaging is on `feature/omarchy-mac-package` in `omarchy-mac/omarchy-pkgs-aarch64`. Evidence-only commits after the recorded source do not change these built artifacts. The published integration plan and reference are retained verbatim from `efb7ca91`.

## What passed

- The add-on builds from its own copied directory and passes its standalone behavioral/setup tests. It installs vendor Wi-Fi configuration, Wi-Fi recovery, microphone mapping, headset policy and the notch default. It neither selects a kernel nor provides/replaces settings or installs repository trust.
- Payload checks verify recorded source revisions, actual dependencies, one owner for each transferred path, and the legacy Apple detector alias needed by preserved user service overrides.
- Real pacman transactions in scratch roots pass fresh installation, full baseline upgrade, repeated installation, rollback, interrupted rollback retry and re-upgrade. Installing the add-on alone against the old runtime is correctly rejected. Dependencies remain enabled; hooks and scriptlets are disabled only in scratch roots. No overwrite flags are used.
- A second rehearsal uses the actual installed runtime/settings/add-on baseline and includes the already-published Steam package. Its four-package upgrade, repeat, rollback and retry pass, including after the intervening system update.
- The live four-package transaction passes with normal hooks and scriptlets. The runtime relinquishes the Steam launcher to `omarchy-steam-fex`; the Apple helpers and microphone vendor unit belong to `omarchy-mac`. The dev-link selection is unchanged.
- The two migrations still pending after the user's update, `1789522888` and `1789780917`, complete in order. There are then no pending migrations, and a second migrator run is a no-op. The earlier three pending migrations had already completed during the user's update. No completion marker was fabricated.
- The preserved user microphone unit starts successfully using the legacy detector alias. All four audio services are active, the configured source/sink remain selected, and NetworkManager remains connected with the administrator's wpa_supplicant override. The package's vendor microphone unit was also activated successfully during the earlier diagnostic trials; those whole restart trials did not pass, as explained below.
- Installed integrity checks find zero altered runtime, add-on or Steam files. The unprivileged settings check cannot read four protected sudoers files; it reports no other differences. This is not a complete privileged settings integrity result.

Scott's earlier physical trial confirmed reboot, lid-close suspend/resume, Wi-Fi, YouTube playback and complete microphone recording/playback. That trial used the earlier installed add-on and the dev-linked candidate. The final coordinated package set rebooted successfully at 14:26:42 on September 19 (boot `a56190a2-06a4-4f34-9bf8-37ba2b0da7a7`). Both the session and user systemd environment select the candidate dev link. Wi-Fi is connected, all four audio services are active, the microphone mapping and configured speakers are selected, neither systemd manager reports failed units, and no migrations remain pending. Scott confirmed YouTube playback and complete microphone recording/playback on this final-package boot. `post-reboot-20260919.json` records the machine checks and user confirmation. Neither the successful earlier boot nor scratch provisioning is evidence for a full installer image.

## Audio restart is a separate baseline issue

The earlier report's two successful idle restarts were insufficient to establish the experimental fix. Further trials reproduced the WirePlumber teardown stall, especially during active recording. Both WirePlumber-first and Pulse-first teardown variants passed some idle checks but still required forced recovery during active recording.

The unmodified `350c4655:bin/omarchy-restart-audio` also reproduced the stall during active capture: 27.134 seconds, forced recovery, exit status zero. Captured samples were discarded rather than saved. The extraction retains the same mapper bytes as that baseline. This supports treating the stall as an existing audio-lifecycle issue; it does not establish the exact WirePlumber defect.

Commit `3968bdd5` removes the speculative teardown fix from this candidate. The restart command retains baseline behavior and the optional mapper presence guard, saving microphone state before restarting audio. Its focused tests cover ordering, missing optional add-on, non-Apple hosts, state-save failure and the existing forced-recovery path. The experiment is preserved locally on `experiment/mac-audio-teardown-20260919`, with unsuccessful variants and diagnostics retained in the recovery folder. This candidate does not claim to fix audio restart during recording.

The extracted mapper is byte-identical to `350c4655:bin/omarchy-audio-asahi-mic-map` (SHA256 `5a4cd6bbc36e2c7beb62023a27997d1f5f84b3ffeae58a5f107185615dfda1bc`). The prior installed helper's SHA256 was `838d44a5578ad12c134ad77ff54284afe7b987c4223480330ec4f54ba881d291`; it polled every two seconds. The reported 2h25m CPU observation belonged to that older helper and does not demonstrate an extraction regression.

## Automated tests and limits

Standalone package tests, CLI checks, focused integration/migration/restart/detector tests and effective NetworkManager/systemd/module-configuration checks pass as a non-root user. Setup coverage includes offline provisioning, first-session activation, multiple users, repeated/interrupted setup, preserved overrides and masks, Wi-Fi failure/excluded-chipset cases, and microphone gain/mute/device choices.

The final normal-environment aggregate (`env -u NO_COLOR -u LC_ALL TERM=xterm-256color ./test/all`) passes CLI and 284 of 286 shell test files. `optional-transactions-drift-test.sh` also fails on unchanged `350c4655`. The other failure, `snapshot-restore-test.sh`, passes an immediate focused rerun; both that test and its implementation are unchanged from the baseline. Its warning text was present in the failed run, consistent with the test's early-exiting `grep -q` pipeline racing under `pipefail`. Earlier candidate aggregate runs passed 285/286 files. The final aggregate is not reported as completely green.

The user performed a broader system update during validation. Its mkinitcpio hook failed against an unowned `/etc/mkinitcpio.d/linux-asahi.preset` pointing to missing `/boot/vmlinuz-linux-asahi`; the same error appears on September 2 and 6. GRUB references `/EFI/omarchy/vmlinuz` and `/EFI/omarchy/initramfs.img`, both present and dated August 30. No boot files or presets were changed for this package trial.

## Desktop reduction and review boundary

Counts use `git diff --numstat 350c4655 20b8ae0f -- bin default install migrations test` and include the integration calls, compatibility leaves, detector alias and migration/restart coverage.

| Scope | Added | Removed | Net removed |
| --- | ---: | ---: | ---: |
| Runtime/setup/migrations | 65 | 662 | 597 |
| Desktop tests | 132 | 748 | 616 |
| Total | 197 | 1,410 | **1,213** |

The earlier 1,334, 1,279 and 1,123 figures describe earlier review states. Package source is counted separately. The upstream desktop PR must exclude `packages/`, plans and collaboration documentation. Keep shared interfaces, package implementation, compatibility changes and packaging separately reviewable. Historical migration bodies and compatibility paths are retained; login starts the enabled service without rerunning setup.

The candidate merge preview against `efb7ca91` is conflict-free. This is a read-only merge preview, not a shared-branch merge or approval to publish packages.

## Durable evidence and recovery

The current worktrees are under `~/code/omarchy-worktrees/`. Evidence is under `/home/scott/omarchy-mac-recovery/merge-readiness-20260919/`:

- `reviewed/artifacts/` contains all four archives and `SHA256SUMS`; the source revision is embedded in the three local builds.
- `ownership-reviewed.json`, `installed-upgrade-reviewed.json` and `logs/` record builds, dependencies, ownership, effective configuration, aggregate/focused checks, scratch rollback and the live transaction/migrations.
- `packages.after`, `ownership.after`, `migrations.before`, `migrations.after`, `live-trial.exit` and `live-trial-passed` record the installed outcome.
- `audio/`, `audio-orderly/`, `audio-pulse-first/`, `audio-baseline/` and `experiments/` preserve successful activation/state observations and failed restart evidence.
- `rollback/` contains the three previous packages, checksums and saved migration/user configuration. The old settings archive is a documented reconstruction of installed files, not an original downloaded artifact. `ROLLBACK.md` describes the rehearsed offline package return, including removing the new Steam package before restoring the old runtime's launcher ownership.
- Root snapshot 9 predates the intervening system update; snapshot **11** was taken immediately before the final four-package trial. `/home` and `/boot` are excluded. Root snapshot restoration has not been exercised.

Earlier physical-trial evidence and dev-link return instructions remain under `/home/scott/omarchy-mac-recovery/trial/`. Those earlier artifacts and observations are historical evidence, not the final package set.

## Before release promotion

The extraction is reviewable with the baseline audio issue disclosed. Broader M1/M2 hardware coverage, live iwd and BCM4378/BCM4387 recovery, full image provisioning and signed repository selection remain separate qualification work. BCM4388 recovery stays excluded. Aurora requires independently recorded evidence. The package feed, trust configuration and shared code branch have not been changed by this work.
