# Apple Silicon upstream integration plan

Shared working plan for bringing Apple Silicon support into upstream Omarchy. Updated September 19, 2026. Use this document to agree how the pieces fit together; use the existing workstream cards to track implementation and validation.

DHH sets the release timeline. His [September 19 update](https://app.basecamp.com/5994298/buckets/48663438/messages/10294496118#__recording_10320638828) targets the first or second week of October, without a committed public release date. Contributors are invited to propose changes to the open sections below through PRs. Named contributors are invitations to develop those sections unless coordination is explicitly agreed; proposed repository homes and interfaces still need maintainer agreement.

## What we are building

One Apple Silicon Omarchy system that testers can install, developed together and brought upstream through focused contributions.

| Piece | Where we work | Intended destination |
| --- | --- | --- |
| Desktop and shared helpers | `omacom/omarchy-mac:quattro-upstream`, distilling the accumulated fork into upstream-reviewable changes | Focused PRs to `omacom/omarchy` |
| Persistent Apple configuration and services | `packages/omarchy-mac/` in that repository; PKGBUILD in `omarchy-mac/omarchy-pkgs-aarch64` | Independently versioned `omarchy-mac` add-on, with official recipe publication and any later source-repository split agreed with maintainers |
| macOS app, Apple boot preparation and encrypted Linux installation | Reuse [Marcelo's macOS installer](https://github.com/maralcbr/omarchy-mx-mac/tree/main/apps/omarchy-apple-installer) and suitable [omarchy-mac-iso](https://github.com/omarchy-mac/omarchy-mac-iso) components in a shared installer project | Companion installer repository, with reusable Linux installation changes proposed to `omacom/omarchy-iso`; exact homes to agree |
| Packages testers install | Use [omarchy-pkgs-aarch64](https://github.com/omarchy-mac/omarchy-pkgs-aarch64) for the release, completing signing and validation of the compatible package set | Official Omarchy packaging or the appropriate upstream providers as components are accepted |

The collaboration **branch** is what we develop together. The collaboration **channel** is what testers install together. Official ARM packages help, but we still need to distribute desktop and add-on changes that have not landed upstream.

The main release initiatives already cover [M1/M2 launch](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294470280), a [unified installer](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10296876777), [ARM package infrastructure](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294467178) and a [unified kernel](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294477079). This plan connects those outcomes to the Apple work. Marcelo's [release outline](https://app.basecamp.com/5994298/buckets/48646031/documents/10294385193) includes the installer, M1/M2 Pro/Max, GPU support, USB-C displays, Touch ID, MLX and encryption. Agree their acceptance criteria together; the add-on is one part of that system.

## Shared development and upstream contributions

`quattro-upstream` is the attempt to distill `omarchy-mac` into an upstream-mergeable branch. It brings the accumulated work onto upstream Quattro with Marcelo's [#9835](https://github.com/omacom/omarchy/pull/9835) adapted in. It is the shared review starting point, not a completed upstream merge.

Marcelo, Scott, Wes and Naeem will coordinate the add-on extraction and preparation of the remaining upstream merge. After #9835 lands, compare its actual merged implementation with the distilled branch, reconcile differences and prepare the remaining desktop delta. Ready independent fixes can continue through review throughout this work.

Keep contributions focused and preserve attribution. Mark new commits with `Upstream-Status: candidate`, `Upstream-Status: experimental` or `Upstream-Status: temporary`; explain the purpose and exit condition for experiments and temporary glue. Preserve shared history by default. Coordinate any exceptional rewrite; submission branches can be cleaned independently.

Installer source, kernel recipes, MLX implementation and repository trust bootstrap belong in their appropriate projects. The upstream desktop submission must also exclude `packages/omarchy-mac/`; its shared interfaces, package dependency and migrations remain separately reviewable. ALS and Steam can be tested in the complete system while receiving separate upstream review. Steam's launcher is supplied by `omarchy-steam-fex`.

The [dated merge tracker](upstream-integration-reference.md#upstream-merge-record) records the existing provisioning, battery, clock/weather, test-runner and Apple foundation contributions. Recheck their status and reconcile accepted changes before preparing submissions.

## The `omarchy-mac` add-on

Persistent Apple defaults and support services belong in the add-on; shared discovery and desktop interfaces stay in Omarchy. The package complements `omarchy` and `omarchy-settings`. It neither provides nor replaces them, selects no kernel, contains no installer and installs no repository trust configuration.

The source directory is independently buildable, with its own version, MIT license, attribution, tests and staging/install script. Preserve original commit references when extracting code. The separate PKGBUILD pins a collaboration-repository commit and packages only that directory. Propose official recipe publication with the packaging maintainers; keep the candidate available through the agreed collaboration channel while that work proceeds.

| First-release component | Package responsibility |
| --- | --- |
| Wi-Fi backend | NetworkManager vendor configuration selecting iwd |
| Wi-Fi resume recovery | Existing restricted helper and package-owned system service |
| Microphone mapping | Existing helper and user service, preserving gain, mute and device choices |
| Headset microphone priority | WirePlumber vendor policy |
| Notch setting | Existing module default, preserving administrator overrides |

Use small explicit system/user setup entrypoints. Fresh Apple installations must acquire the package before hardware setup; existing machines need a retryable transition from the old `omarchy-settings-asahi` requirement. Preserve historical migration compatibility and support offline provisioning and first-session activation without requiring a running user bus during installation. Retain microphone state saving before audio restart.

Validate the runtime/settings/add-on transaction together: each transferred file has exactly one owner, with no broad overwrite workaround. Retire only recognized generated configuration, preserve administrator changes, service masks and intentional disables, and check effective configuration for older overrides. Package publication must be available before setup or migration relies on it.

Bindings, trackpad defaults, Electron workarounds, ambient-light support, HID early-loading, function-key/initramfs handling, boot management, snapshots and installer work stay outside this first package. The wider direction remains package-owned system defaults, a desktop platform layer below user choices, shared hardware discovery and explicit package/boot lifecycle ownership. Those broader changes are separate work, not additions to this initial package scope.

## Packages testers install

Use [omarchy-mac/omarchy-pkgs-aarch64](https://github.com/omarchy-mac/omarchy-pkgs-aarch64) as the initial collaboration package source for testers and the release. Complete its publication and signing work to provide one reproducible package set for both fresh installations and existing testers. It must include new names such as `omarchy-mac` and the needed branch-built replacements for `omarchy` and `omarchy-settings`. Record exact source and recipe revisions, versions, providers and signers.

Repository precedence must select those intended replacements. Test installation, upgrades, equal versions, locally newer packages and leaving the channel. Coordinate ownership across runtime, settings and add-on packages. Availability of an official ARM package does not establish that it contains the collaboration changes or that the complete installation path is qualified.

The [package pool](https://omarchy-pool.firemanxbr.org/) remains an open question for sub-team experimentation: could it let groups build and test new ideas in independently managed collections, then promote agreed changes into the release package set? Explore build, signing, promotion, retention and rollback with its maintainer. Adopting the pool is not a release dependency; proceed with `omarchy-pkgs-aarch64` while that exploration continues. The [dated package inventory and pool observations](upstream-integration-reference.md#package-delivery-observations) remain inputs to recheck.

Signing and a tested transition away from the existing unsigned repository configuration are release deliverables; [#394](https://github.com/omacom/omarchy-mac/issues/394) records that gap. Trust bootstrap belongs in installer/package configuration. Changing future templates alone does not update existing machines.

**Release and packaging maintainers:** please define the complete tester set delivered through `omarchy-pkgs-aarch64`, name a signing/publication owner, and explain how fresh installs and existing testers reach the same versions and recover from failed updates. With Ryan and upstream maintainers, agree official recipe homes and ARM qualification. Teams interested in the pool can explore its experimental collections separately, including branch-built overrides and the recorded ARM configuration gaps.

## Installer

Prefer reusing [Marcelo's macOS installer](https://github.com/maralcbr/omarchy-mx-mac/tree/main/apps/omarchy-apple-installer) for its interface and Apple boot preparation alongside suitable encrypted-installation work from [omarchy-mac-iso](https://github.com/omarchy-mac/omarchy-mac-iso). Keep the installer separate from the desktop integration repository and preserve history and attribution when extracting existing code. Agree its shared repository home and the reusable Linux interfaces with Marcelo and the maintainers.

Marcelo and Eryk have been working on the macOS installer. Wes has documented the strategies used by the `omarchy-mac-iso` encrypted installer. That documentation is an input to the shared design.

**Marcelo and Eryk, with the Linux installer contributors:** first describe the installer working today—source/runtime branch, image, package set, tested machines and try/install flows, including whether it has been tried with #9835 or the distilled branch. Then propose the shared home, macOS-to-Linux handoff, artifact delivery and ownership of boot updates and recovery. **Wes:** please help review that proposal against the encrypted-install strategies you documented; any implementation role remains to be agreed. The lifecycle below is the intended design to validate against those implementations, not a claim that the current app already performs it.

Linux root and user data must be encrypted. Identify the boot components that remain unencrypted; keep encryption credentials out of logs, the temporary installer and unencrypted boot files.

1. From macOS, prepare Apple boot and allocate the Linux extent. Place the temporary installer at its tail, with the target system ahead of it. APFS resizing remains a macOS operation.
2. Record the disk, partition identities, geometry and artifacts in a handoff manifest. Validate them before target writes; store no secrets in the manifest.
3. Boot Linux, collect the passphrase and create LUKS2 with the agreed Btrfs layout.
4. Install the recorded signed package set, including `omarchy-mac` before hardware setup, and run shared system/user provisioning.
5. Boot the encrypted installed system independently of the temporary installer and verify that independence.
6. Delete only the recorded installer partition, then grow the root partition in place, the encrypted mapping and the filesystem in that order.

Keep the temporary installer until independent boot succeeds. Installation and reclamation must be retryable, checking actual disk state before each mutation. Test interruption and recovery, including snapshot restore with matching boot files and kernel modules. The [recovery constraints](upstream-integration-reference.md#installer-recovery-constraints) retain the detailed checks.

The existing bootstrap can remain a developer/recovery route. The recommended public installer must meet the encrypted lifecycle; the plan does not require two equally supported public installers.

## Kernel, graphics and hardware scope

Asahi is the first validation baseline. Develop an opt-in Aurora preview with its own recorded package set, supported models, updates and recovery. Keep kernel choice independent of the desktop channel and preserve the default for people who have not opted in. Fresh preview installation and switching an existing system require separate evidence.

Marcelo's [public installer documentation](https://github.com/maralcbr/omarchy-mx-mac#omarchy-for-apple-silicon-macs), read September 19, reports an Aurora RC option for particular M1 Pro and M2 Max models. We have not validated that path against the distilled branch or package candidate. Confirm its exact builds and behavior before adopting it into the shared delivery path.

**DJ, Eryk, Ryan Murray and other kernel/graphics contributors, with Marcelo:** please propose the baseline and preview stacks here. Identify the compatible kernel, modules, headers, firmware/boot components and Mesa builds; named models; update and fallback behavior; and physical-hardware acceptance checks. Explain how the Apple proposal fits the wider unified-kernel initiative. Audit `linux-asahi` assumptions and distinguish running, installed and next-boot kernels.

**M3 is a candidate for labelled early support in the first release**, potentially without GPU acceleration, subject to package availability and testing. Asahi's [September announcement](https://asahilinux.org/2026/09/m2-episode-1/) describes M3 laptop/iMac support and limitations; it does not establish what our ALARM package set delivers. Naeem is preparing the Hyprland software-renderer fix PR and following its review toward a merge. Record the delivering package, eligible models, usable-desktop results and install/update/recovery evidence before offering this path. M3 MLX/ANE support is a separate capability, not a prerequisite for a software-rendered desktop.

**Chris and the video-acceleration contributors:** please confirm your scope and propose first-release decoder/encoder capabilities, dependencies, packages, hardware coverage and application tests, building on the existing Andreas/Miguel work.

**DJ:** please describe how the working Touch ID implementation joins the shared system: source and packages, kernel/userspace dependencies, tested models, enrollment and authentication. Keep any Secure Enclave disk-encryption work distinct from biometric authentication.

## MLX and its graphics dependencies

Josh's [M1/M2 MLX/ANE release card](https://app.basecamp.com/5994298/buckets/48646031/card_tables/cards/10264591646), read September 19, bounds the initial capability around installation, GPU inference, stated ANE coverage, non-fatal upgrades and documented limits. Later-chip support, full performance parity and broader coverage have separate scope.

**Josh:** please develop the MLX/CoreML/ANE integration proposal here, using that bounded release scope. Identify what ships by default or optionally, the source/package/wheel set, Mesa/Honeykrisp and kernel/ANE/compiler dependencies, supported models and acceptance demonstrations. State functional readiness separately from performance targets, and identify what assistance is needed.

The [Honeykrisp package proposal](https://app.basecamp.com/5994298/buckets/48646031/card_tables/cards/10320749071) is a shared graphics dependency: Josh brings the ML requirements and patches, graphics contributors review integration and desktop behavior, and packaging maintainers deliver the agreed tested Mesa build. Define that build together so the installer delivers a compatible graphics and ML stack.

## First milestone and existing work

`recorded signed packages → encrypted fresh install → independent boot → reclaim installer space → package/kernel update → reboot → recovery`

Use physical Macs for firmware, graphics, audio, suspend, encrypted boot and recovery; ARM VMs for package transactions; disposable storage for interruption tests; and x86 regression checks for shared runtime. Record exact artifacts, repository configuration, hardware and limitations. Each experimental hardware/kernel path needs its own evidence.

Resolve the cross-component questions here, then map implementation to the existing [M+ workstreams](https://app.basecamp.com/5994298/buckets/48646031/card_tables/10263379585). The [card reconciliation](upstream-integration-reference.md#relationship-to-existing-basecamp-cards) preserves the mapping and scope questions, including the duplicate Honeykrisp cards, performance criteria and which additional capabilities are release requirements. Reuse existing discussions and work; agree owners, dependencies and acceptance criteria rather than treating every roadmap card as a release blocker.

The immediate work is to complete the add-on validation and agree the package, installer, kernel and MLX interfaces needed for one reproducible encrypted Asahi candidate, with an explicitly scoped Aurora preview proposal. Ready upstream fixes can continue in parallel.

## Current state and evidence

We have taken two steps:

1. **Distilled the existing fork onto upstream Quattro**, incorporating Marcelo's #9835 with adaptations. Published as `quattro-upstream`, this is a common review starting point for the remaining Apple Silicon changes.
2. **Extracted and tried the separate `omarchy-mac` add-on.** Automated checks and a limited M2 Max trial covered installation, dev-linking, reboot, suspend/resume, Wi-Fi, playback and microphone recording. The implementation remains on the [candidate branch](https://github.com/omacom/omarchy-mac/tree/integrate/omarchy-mac-package), not merged into `quattro-upstream` or published as a signed tester release.

The limited trial gives us confidence to pursue the package split as the integration plan; broader installation, upgrade and hardware validation remain ahead. Existing configuration overrides were retained. Additional audio-restart checks, the full ordered migration and reproducible companion runtime/settings artifacts remain to be completed. The [validation record](https://github.com/omacom/omarchy-mac/blob/d3b22f6ed2ab326f529c42f3b36ff22b63431e05/plans/omarchy-mac-package-validation.md) records revisions and limitations; Scott subsequently confirmed the post-dev-link playback and recording checks it still lists as pending.

Installer integration remains unverified against this branch. Marcelo's tested runtime/package baseline needs clarification; the desktop/add-on trial provides no evidence of that integration.

The [supporting reference](upstream-integration-reference.md) retains dated package observations, the upstream merge record, detailed recovery constraints and the Basecamp mapping. This document is the shared plan to develop together.
