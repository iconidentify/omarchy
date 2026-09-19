# Basecamp upstream-merge update

Saved as an unpublished [Basecamp Message Board draft](https://app.basecamp.com/5994298/buckets/48646031/messages/10314807445) on 2026-09-17. Title: **Apple Silicon: shared integration branch and next steps**. No subscribers added; not published.

## Posting plan

- Use a new Message Board post in Omarchy M+; the existing [Prepare upstream merge approach/plan](https://app.basecamp.com/5994298/buckets/48646031/todos/10240031705) ticket is complete. The draft is saved for review before publication.
- Link the [Omarchy Mac Upstream Merge list](https://app.basecamp.com/5994298/buckets/48646031/todolists/10266878547), the [M1 + M2 launch card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294470280), and Ryan's [Unified Installer card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10296876777) so the discussion connects to the existing work.
- Link the published [integration plan and merge tracker](https://github.com/omacom/omarchy-mac/blob/quattro-upstream/docs/upstream-integration-plan.md) for implementation details. The plan was committed and pushed as `350c4655`.
- Coordinate package delivery with the existing [Omarchy ARM card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294467178), which covers package mirroring for Qualcomm, Pi, and Apple M.
- Post the proposed milestones as outcomes for discussion. Decide the card breakdown and ownership with the group, starting with the next concrete steps and reusing existing upstream-merge and installer items where they fit.

## Draft maintenance

Updated 2026-09-18 with the agreed source layout and actual candidate progress. The message remains unpublished, with no subscribers added.

## Message body

I've distilled the Apple Silicon work from the Omarchy Mac fork into a much smaller set of focused commits on top of upstream Quattro, incorporating [@Marcelo Alcantara](mention:BAh7BkkiC19yYWlscwY6BkVUewdJIglkYXRhBjsAVEkiKWdpZDovL2JjMy9QZXJzb24vNTMwMjU4NDk_ZXhwaXJlc19pbgY7AFRJIghwdXIGOwBUSSIPYXR0YWNoYWJsZQY7AFQ=--441183af9963e4fb15aa1f027a3c282efc33db39)'s [#9835](https://github.com/omacom/omarchy/pull/9835) foundation. The aim is to make each remaining change understandable and reviewable on its own, while keeping the complete system working together.

That integration is now on [omacom/omarchy-mac:quattro-upstream](https://github.com/omacom/omarchy-mac/tree/quattro-upstream), originally published at `350c4655`, which remains my running dev-linked checkout. The add-on candidate remains on the separate `integrate/omarchy-mac-package` branch while validation continues; it is not merged into the shared branch. I'd like us to use it as our shared starting point: refine and test the distilled changes together, then submit the remaining work upstream in focused PRs. This covers the runtime integration; package delivery and the encrypted installer still need the work outlined below.

I've also published an [integration plan and merge tracker](https://github.com/omacom/omarchy-mac/blob/quattro-upstream/docs/upstream-integration-plan.md) covering the branch workflow, package delivery, encrypted installer, kernel updates, and validation. It's a proposal for us to work through together; the main decisions are below.

This supports the existing [Omarchy M launch with M1 + M2](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294470280) card, assigned to [@Marcelo Alcantara](mention:BAh7BkkiC19yYWlscwY6BkVUewdJIglkYXRhBjsAVEkiKWdpZDovL2JjMy9QZXJzb24vNTMwMjU4NDk_ZXhwaXJlc19pbgY7AFRJIghwdXIGOwBUSSIPYXR0YWNoYWJsZQY7AFQ=--441183af9963e4fb15aa1f027a3c282efc33db39) and Naeem: a unified macOS app with both try and install flows, targeting complete M1 and M2 compatibility out of the box. The encrypted-install work below should fit into that effort, with the try flow kept in view as part of the launch scope. Ryan's [unified-installer card](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10296876777) connects it to shared Linux provisioning and package definitions across architectures.

**The upstream merge set we're tracking**

All five changes are represented in the collaboration branch; their upstream PRs remain separate:

- [#9835 — Apple Silicon foundation](https://github.com/omacom/omarchy/pull/9835), including [@Marcelo Alcantara](mention:BAh7BkkiC19yYWlscwY6BkVUewdJIglkYXRhBjsAVEkiKWdpZDovL2JjMy9QZXJzb24vNTMwMjU4NDk_ZXhwaXJlc19pbgY7AFRJIghwdXIGOwBUSSIPYXR0YWNoYWJsZQY7AFQ=--441183af9963e4fb15aa1f027a3c282efc33db39)'s package guards, pacman staging, keyring, and settings work.
- [#12056 — Provisioning robustness](https://github.com/omacom/omarchy/pull/12056).
- [#12058 — Battery rounding](https://github.com/omacom/omarchy/pull/12058).
- [#8942 — Clock/weather popup anchoring](https://github.com/omacom/omarchy/pull/8942), tested and confirmed in my live session.
- [#9834 — Refuse shell tests as root](https://github.com/omacom/omarchy/pull/9834), now included with its root protection and normal-user regression path checked.

The remaining Apple platform work and keyboard ambient-light support are also available in the shared branch. Steam/FEX uses the separate `omarchy-steam-fex` package. We'll reconcile the final [#9835](https://github.com/omacom/omarchy/pull/9835) merge and submit the remaining changes without duplicating those existing PRs.

**Three things I'd like us to settle next**

1. **A shared package staging area.** Could we use [Marcelo Barbosa's](https://github.com/firemanxbr) [Omarchy pool](https://omarchy-pool.firemanxbr.org/) to distribute signed builds of our collaboration branch, so everyone can install and test the same system before the changes land upstream? We'd want an opt-in Mac collection that supplies missing packages and deliberately overrides the upstream runtime/settings pair where needed. Let's confirm with Marcelo how exact-commit builds, promotion of tested package sets, and the eventual transition back to upstream packages would work. This should connect to the existing [Omarchy ARM](https://app.basecamp.com/5994298/buckets/48663438/card_tables/cards/10294467178) card for package mirroring across Qualcomm, Pi, and Apple M, with our staging builds providing a path to test and contribute the Apple-specific requirements.
2. **Encrypted installation.** I'd like to combine [@Marcelo Alcantara](mention:BAh7BkkiC19yYWlscwY6BkVUewdJIglkYXRhBjsAVEkiKWdpZDovL2JjMy9QZXJzb24vNTMwMjU4NDk_ZXhwaXJlc19pbgY7AFRJIghwdXIGOwBUSSIPYXR0YWNoYWJsZQY7AFQ=--441183af9963e4fb15aa1f027a3c282efc33db39)'s macOS app with the technique developed in `omarchy-mac-iso`: place the temporary installer at the tail of the Linux space, install an encrypted root ahead of it, then reclaim that slice and expand the installed system after a successful independent boot. I'm happy to use whichever implementation fits best. Encryption, interruption recovery, and package-managed kernel updates are the requirements. Start with Asahi and keep Aurora as an explicit experimental choice. I propose a separate shared installer repository, with its home agreed together, consuming the same Linux provisioning and package definitions. Upstream contributions can land across the desktop, installer, and package repositories.
3. **Coordination and next steps.** I'd like us to work out together how to break this into manageable pieces and where each person's existing work fits. I don't have a proposed division of the cards yet. Ryan's guidance on how official ARM edge is built and how we should submit the remaining package recipes and qualification evidence would help shape that breakdown.

**Keeping Apple customizations maintainable**

The agreed source home for the kernel-neutral `omarchy-mac` add-on is `packages/omarchy-mac/` in the collaboration repository, alongside the desktop integration. It has its own version, license, attributed source, tests and staging script and builds independently. The PKGBUILD lives in [omarchy-mac/omarchy-pkgs-aarch64:feature/omarchy-mac-package](https://github.com/omarchy-mac/omarchy-pkgs-aarch64/tree/feature/omarchy-mac-package), pinned to source `b76c6d79`; the recorded recipe/tooling revision is `94a2dd49`. It complements upstream `omarchy` and `omarchy-settings`, selects no kernel and contains no installer or trust configuration.

Implementation began with Wi-Fi recovery as a separate reviewable slice. The `0.1.0` candidate now also supplies the iwd vendor default, unchanged microphone mapper and user service, headset microphone priority and notch module default. Small explicit system/user setup entrypoints preserve masks, custom files, gain/mute and device choices and support offline setup and first-session activation. Historical migrations remain retryable, with a new transition for already-completed installations. Fresh Apple inputs require `omarchy-mac` before hardware setup.

The add-on remains on `integrate/omarchy-mac-package`; it is not merged into `quattro-upstream`, which remains at `350c4655`. The original runtime/settings/add-on candidate trio was built from `b76c6d79`, with scratch transaction checks. That `/tmp` bundle did not survive reboot. The durable live trial instead pairs add-on `0.1.0-1` from `b76c6d79` with a minimal reconstruction of the installed runtime (`4.0.2-202609092055.mac1`); settings remains `4.0.2-202609092055` and the candidate was subsequently dev-linked and booted successfully on 2026-09-19 at `3f9f7177`. Ownership transfer and offline rollback were rehearsed with dependencies enforced, and the live transaction and package integrity checks passed.

Scott confirmed reboot, Wi-Fi, playback, microphone recording, and lid-close resume on an M2 Max. Wi-Fi retains the administrator’s wpa_supplicant override; BCM4388 remains excluded from resume recovery, and the existing user microphone unit remains authoritative. Audio restart exposed a WirePlumber teardown stall. It reproduced with WirePlumber alone, but stopped cleanly after stopping the mapper and unloading its null sink. A separate desktop fix waits for graph removal and DSP readiness, preserves service state and device choices, and completed two live restarts in 3.75 seconds each without forced recovery. The exact underlying WirePlumber listener-loop defect remains unidentified.

Historical migration bodies are retained, with the unresolved package name corrected and an installed-package guard added to the old package-acquisition migration; compatibility leaves acquire the add-on in their original system/user scope. The new transition handles already-completed migrations. Login only starts an enabled microphone unit; provisioning, first-run and migration handle setup.

The revised extraction saves 1,279 desktop lines against `350c4655`. Including the restart fix, optional mapper guard, installed-package migration guard and their tests at `ea58eb2c`, the combined reduction is 1,123 lines. `packages/`, plans and documentation are excluded from those desktop counts. Upstream desktop PRs must exclude `packages/`; it remains independently maintained in the collaboration repository. CLI, standalone package and focused regression suites pass. The non-root desktop aggregate passes 285/286 shell test files; the existing optional-menu drift failure remains.

The candidate dev link is active after reboot. No candidate was published to the rolling feed, repository trust was not changed, and no shared-branch merge occurred. Signed repository selection, full image provisioning, additional M1/M2 coverage, the packaged-unit activation path, and separately recorded Aurora qualification remain open. Current persistent worktrees are under `~/code/omarchy-worktrees/`; live artifacts, recovery commands and diagnostic evidence are under `~/omarchy-mac-recovery/trial/`.

**Proposed milestones**

These describe the outcomes we're aiming for. We can decide together how many cards each needs, what can proceed in parallel, and who wants to take part.

1. **Shared collaboration baseline:** published branch and plan, agreed contribution workflow, and a maintained merge tracker. The branch and plan are up; let's agree how we work together.
2. **Signed, reproducible package set:** build the runtime/settings pair from an exact branch commit, resolve all required packages from agreed signed sources, and verify that repository ordering selects the intended builds.
3. **Encrypted installation through the macOS app:** start from macOS, boot the temporary installer, install encrypted into the space ahead of it, and boot the installed system independently using shared Linux provisioning.
4. **Installer-space reclamation and recovery:** reclaim the temporary slice and grow the installed system after successful boot, with interruption tests showing that each stage can resume safely.
5. **Reliable updates and tester migration:** demonstrate package/kernel update, reboot, and recovery; provide existing fork users a tested transition into the collaboration channel, retire TrustAll, and document how they leave that channel.
6. **Upstream integration and handoff:** land the agreed platform changes and required package recipes, retire the corresponding downstream overrides, and demonstrate transition to the supported upstream configuration. Independent PRs can land throughout this work.

Aurora qualification can proceed in parallel, with its own installation, update, and recovery evidence, without blocking the Asahi baseline. For each milestone, let's name the hardware tested and link the source revision, package set, and results. Launch qualification should cover both M1 and M2 and both macOS-app flows: try and install. Optional applications shouldn't block the first encrypted installation unless we agree they're part of the required baseline.

The first substantial target would be a signed, reproducible package set that installs encrypted through the macOS app. The full lifecycle we want to prove is **encrypted fresh install → successful installed boot → installer-space reclamation → package/kernel update → reboot → recovery**.

Does this look like the right shared starting point, and are these useful milestones? I'd appreciate corrections to the assumptions, connections to work already underway, and suggestions for the first concrete steps. From there, we can work out the cards and ownership together, using the [upstream-merge list](https://app.basecamp.com/5994298/buckets/48646031/todolists/10266878547) and existing installer work where they fit.
