# High-Risk Storage, Hibernation, and System Changes

Status: Deferred; separate explicit approval required

Created: 2026-07-29

Scope: Changes that can prevent boot, prevent login, destroy data or backup
history, invalidate rollback paths, or require recovery media.

Related safe plan:
[Security, Monitoring, and Remote Backup](security-monitoring-backup.md)

## Approval Boundary

This document is a gated runbook, not authorization to implement anything.
None of its changes should be included while implementing the related main
plan.

Require a fresh explicit approval for each category:

1. Remote-backup deletion and retention
2. Lenovo storage encryption, swap, and hibernation
3. Workstation storage encryption, swap, NVIDIA, and hibernation
4. Kernel or initrd parameter changes
5. Firmware updates
6. Nix garbage collection or automatic deployment

Do not approve all categories as one batch.

## Why These Changes Are Isolated

The current workstation and Lenovo configurations declare ext4 roots with no
swap. Hibernation therefore requires persistent storage and resume
configuration that do not currently exist. A mistake in partitioning,
encryption, initrd unlock, resume device, or boot configuration can make a
machine unbootable or destroy data.

Hibernation also writes a representation of live memory to disk. That memory
can contain decrypted secrets, SSH agent material, browser sessions, and open
documents. A plaintext hibernation image would undermine the security work in
the main plan.

Backup retention, Restic pruning, S3 lifecycle expiration, garbage collection,
firmware updates, and automatic deployments are separated because they can
permanently remove recovery material or leave a machine unavailable.

## Mandatory Safety Gates

All applicable gates must pass before modifying a machine:

- [ ] The remote backup from the main plan has completed successfully.
- [ ] A representative file restore has succeeded.
- [ ] A full-folder restore has succeeded.
- [ ] Irreplaceable data has a second independent copy.
- [ ] The Restic password and SOPS personal age key have verified offline
  copies.
- [ ] A current NixOS installer/recovery USB is available and has booted on the
  target machine.
- [ ] Local physical console access is available throughout the change.
- [ ] The exact disk, partition, filesystem, encryption, RAM, and firmware
  layout has been recorded.
- [ ] The target machine has a known-good boot generation that remains
  available.
- [ ] Recovery steps are written before executing the change.
- [ ] The rollback path does not depend on the configuration being modified.
- [ ] Only one machine is changed at a time.
- [ ] The Lenovo is used as the first hibernation/storage pilot; the primary
  workstation remains unchanged until the pilot is reliable.

No partitioning, encryption, filesystem, swap, initrd, or resume change may be
performed through a remote-only session.

## Part 1: Remote-Backup Retention and Deletion

### Initial safe state

The main plan creates encrypted snapshots and S3 object versions without
automatic deletion. Keep this append-only operational period for at least 30
days and complete restore testing before enabling retention.

### Proposed Restic retention

Candidate policy:

- 14 daily snapshots
- 8 weekly snapshots
- 12 monthly snapshots
- 3 yearly snapshots

Before activation:

- [ ] Measure repository growth and projected storage cost.
- [ ] Verify which snapshots a dry-run retention evaluation would keep and
  remove.
- [ ] Export the snapshot list before the first deletion.
- [ ] Confirm S3 versioning is enabled and noncurrent versions are recoverable.
- [ ] Ensure the backup identity cannot permanently delete noncurrent object
  versions.
- [ ] Ensure no backup is running during repository maintenance.

Activation:

- [ ] Run retention without pruning first.
- [ ] Verify retained snapshots and perform another restore.
- [ ] Run pruning only in a separate maintenance window.
- [ ] Run a repository check after pruning.
- [ ] Monitor repository lock state, errors, and storage usage.
- [ ] Add automation only after two successful manual maintenance cycles.

### S3 lifecycle expiration

Lifecycle expiration permanently removes recovery history and must not be
enabled merely to reduce a cost estimate.

Before activation:

- [ ] Observe at least 90 days of real storage growth.
- [ ] Confirm how the provider handles current versions, noncurrent versions,
  delete markers, incomplete multipart uploads, and minimum storage duration.
- [ ] Begin only with cleanup of abandoned multipart uploads if it cannot
  affect completed Restic objects.
- [ ] Keep noncurrent Restic object versions for a separately approved recovery
  window.
- [ ] Test recovery of an object hidden by a delete marker.
- [ ] Keep lifecycle-policy administration credentials off all three machines.

Object Lock is optional and deferred beyond initial retention. Enabling it can
be irreversible for a bucket and can conflict with Restic lock cleanup and
pruning. Use a disposable test repository before considering it for the real
bucket.

Rollback:

- Suspend retention automation.
- Restore deleted current objects from S3 noncurrent versions.
- Run Restic repository checks before resuming backups.
- Do not run additional prune or repair operations until the failure is
understood.

## Part 2: Hibernation Storage Design

### Security requirement

Do not enable hibernation to plaintext swap.

The preferred design is a dedicated swap partition or logical volume inside
persistent LUKS-encrypted storage. Random-key encrypted swap cannot resume
after reboot because its key is intentionally discarded.

Prefer a partition or logical volume over a swapfile. Swapfile resume also
requires a stable physical offset and is easier to break accidentally.

### Per-host discovery

For the target machine:

- [ ] Record total RAM and current maximum realistic memory use.
- [ ] Record root filesystem UUID and parent block device.
- [ ] Record every partition boundary and mounted filesystem.
- [ ] Record free disk space and unallocated device space.
- [ ] Record current encryption and initrd unlock configuration.
- [ ] Confirm firmware and kernel hibernation support.
- [ ] Confirm whether the firmware supports the intended sleep state.
- [ ] Record Secure Boot state and bootloader behavior.

Allocate encrypted disk swap at least equal to RAM, with a safety margin based
on measured use and available storage. Exact sizing is a per-host decision and
must not be guessed in Nix configuration.

### Migration strategy

Preferred order:

1. Verify remote and secondary local backups.
2. Reinstall or perform an offline migration into a planned encrypted layout.
3. Restore data.
4. Verify normal boot and unlock.
5. Verify several normal reboots.
6. Add the resume device without enabling automatic hibernation.
7. Test manual hibernation.
8. Add desktop/lid integration only after repeated success.

Prefer backup/reinstall/restore over risky in-place shrinking of a live ext4
root. If an in-place migration is proposed, it requires its own written
procedure, offline filesystem checks, exact partition math, and another
explicit approval.

If full-disk migration is deferred, a separately encrypted persistent swap
partition can be considered. Its persistent unlock method must protect a
stolen powered-off machine. A plaintext swapfile is allowed only as an
explicitly documented temporary risk acceptance.

## Part 3: Shared Hibernation Configuration

Planned files:

- add `modules/features/system/hibernate.nix`
- update `hosts/lenovo-yoga-pro-7/hardware.nix`
- update `hosts/workstation/hardware.nix`
- import the shared module only after each host's storage exists

The shared module may:

- declare common sleep settings
- accept a host-specific resume device
- optionally enable zram for runtime memory pressure while keeping encrypted
  disk swap available for hibernation
- keep disk swap at a lower runtime priority than zram
- expose a consistent manual hibernation action
- inhibit hibernation while backup or repository maintenance is running

Host-specific device identifiers must remain in the relevant hardware module.
Never share or copy UUIDs between hosts.

### Configuration safety sequence

- [ ] Add the physical/encrypted swap device first.
- [ ] Verify it is active after a normal reboot.
- [ ] Add resume configuration in a separate commit.
- [ ] Build without switching.
- [ ] Inspect the generated boot/initrd configuration.
- [ ] Switch while local recovery media is present.
- [ ] Reboot normally before attempting hibernation.
- [ ] Attempt manual hibernation from a low-complexity console session.

Rollback:

- Boot the previous generation.
- Remove resume configuration before removing or recreating swap.
- Never reuse a resume UUID after repurposing the underlying storage.

## Part 4: Lenovo Pilot

Planned files:

- `hosts/lenovo-yoga-pro-7/configuration.nix`
- `hosts/lenovo-yoga-pro-7/hardware.nix`
- `modules/features/system/systemd-logind.nix`
- potentially a host-specific sleep policy module

Pilot sequence:

- [ ] Complete the encrypted storage and swap migration.
- [ ] Complete five manual hibernation cycles from a console session.
- [ ] Complete ten manual cycles from Niri.
- [ ] Repeat with memory use above 70%.
- [ ] Verify Wi-Fi, Tailscale, Syncthing, audio, Bluetooth, and clock after
  resume.
- [ ] Verify persistent systemd timers catch up correctly.
- [ ] Verify hibernation after at least one kernel update.
- [ ] Keep automatic lid actions disabled throughout initial testing.

Only after direct hibernation is reliable:

- [ ] Make manual hibernation available in the desktop UI.
- [ ] Test `suspend-then-hibernate`.
- [ ] Configure lid close to suspend first.
- [ ] Configure transition to hibernation after 60 minutes.
- [ ] Test battery and AC behavior separately.

Acceptance:

- Ten consecutive Niri hibernate/resume cycles succeed.
- No plaintext hibernation image exists.
- A failed resume can be recovered through a normal cold boot without data
  loss.
- Suspend-then-hibernate works from lid close only after manual tests pass.

## Part 5: Workstation NVIDIA and Hibernation

Do not begin until the Lenovo pilot is complete.

Planned files:

- `hosts/workstation/configuration.nix`
- `hosts/workstation/hardware.nix`
- `modules/features/system/nvidia-graphics.nix`

The workstation currently forces NVIDIA power management off. Hibernation may
require NVIDIA's systemd suspend/hibernate/resume integration and preserved
video-memory allocations.

Before changing NVIDIA or kernel settings:

- [ ] Record the current driver, kernel, display, and boot behavior.
- [ ] Calculate persistent temporary-storage capacity for preserved GPU
  memory.
- [ ] Identify every existing NVIDIA and sleep-related kernel parameter.
- [ ] Verify that the current normal suspend path still works.
- [ ] Make NVIDIA integration changes separately from disk/resume changes.

Validation:

- [ ] Start with one monitor and an idle Niri session.
- [ ] Repeat with both monitors.
- [ ] Repeat after video playback and GPU use.
- [ ] Repeat after a game or other high-VRAM workload.
- [ ] Verify Niri, displays, Sunshine, PipeWire, network, Tailscale, and
  Syncthing after resume.
- [ ] Complete ten consecutive hibernation cycles.
- [ ] Verify another cycle after a kernel or NVIDIA driver update.

Acceptance:

- Workstation resumes Niri and both displays without manual recovery.
- Preserved video-memory storage cannot fill the root filesystem.
- Normal boot remains possible when no valid hibernation image exists.

## Part 6: Kernel and Initrd Changes

Any change to these areas requires its own small commit and approval:

- `boot.kernelParams`
- `boot.initrd.*`
- `boot.resumeDevice`
- encrypted-device unlock declarations
- NVIDIA module parameters
- sleep-state defaults

Rules:

- [ ] Change one behavior at a time.
- [ ] Document the exact observed problem the parameter addresses.
- [ ] Link primary kernel or vendor documentation.
- [ ] Confirm the parameter exists for the deployed kernel/driver.
- [ ] Build before switching.
- [ ] Preserve a boot entry without the new parameter.
- [ ] Test cold boot before hibernation.
- [ ] Remove experimental parameters that do not improve measured behavior.

Do not copy kernel parameters from another machine merely because both run
NixOS.

## Part 7: Destructive or Availability-Affecting Maintenance

### SSD TRIM/discard

- [ ] Confirm the physical storage and encryption stack support discard.
- [ ] Prefer periodic TRIM over continuous discard unless measurements justify
  otherwise.
- [ ] Verify the correct devices are targeted.
- [ ] Enable on one machine first and review logs.

### Firmware updates

- [ ] Review each offered firmware update manually.
- [ ] Ensure AC power is connected and recovery instructions are available.
- [ ] Do not combine firmware updates with kernel, bootloader, or disk changes.
- [ ] Reboot and validate hardware before applying unrelated changes.

### Nix garbage collection and store changes

- [ ] Record the generations required for rollback.
- [ ] Keep a known-good system generation and recovery USB.
- [ ] Start with reporting and alerts only.
- [ ] Perform the first collection manually with an explicit age policy.
- [ ] Confirm required development shells and profiles are protected by roots.
- [ ] Do not use daily `nix-collect-garbage -d`.
- [ ] Automate only after observing two safe manual cycles.

### Automatic deployments and reboot

- [ ] Require successful builds for all hosts.
- [ ] Deploy to HP manually first.
- [ ] Confirm Hermes, Firecrawl, monitoring, Syncthing, and Tailscale health.
- [ ] Define an automatic rollback or out-of-band recovery path.
- [ ] Automate switching only after several uneventful manual deployments.
- [ ] Keep automatic reboot disabled unless separately approved.

## High-Risk Implementation Order

After separate approvals:

1. `backup: validate retention without deletion`
2. `backup: apply first manual retention cycle`
3. `backup: prune after verified restore`
4. `storage(lenovo): migrate to encrypted hibernation layout`
5. `power(lenovo): configure resume and manual hibernation`
6. `power(lenovo): enable suspend then hibernate`
7. `storage(workstation): migrate to encrypted hibernation layout`
8. `power(workstation): configure resume`
9. `power(workstation): add nvidia hibernation integration`
10. `maintenance: pilot trim and guarded nix gc`
11. `maintenance: evaluate hp automatic deployment`

Never combine two numbered storage/power steps in one commit or maintenance
window.

## Definition of Done

- [ ] Every destructive action had a verified recovery path before execution.
- [ ] Restore tests passed before any backup retention or lifecycle deletion.
- [ ] Noncurrent S3 versions protect against client-side deletion.
- [ ] Lenovo completed the pilot before workstation storage was changed.
- [ ] Both machines use encrypted persistent hibernation storage.
- [ ] Both machines completed ten consecutive resume cycles.
- [ ] Workstation NVIDIA state resumes reliably under realistic load.
- [ ] Previous boot generations remain available until the validation window
  ends.
- [ ] No automatic cleanup, update, deployment, or reboot was enabled before
  successful manual trials.
- [ ] Recovery and rollback results are documented.

## References

- [Restic: retention, pruning, and repository checks](https://restic.readthedocs.io/en/latest/060_forget.html)
- [AWS: S3 Lifecycle rules](https://docs.aws.amazon.com/AmazonS3/latest/userguide/intro-lifecycle-rules.html)
- [AWS: Object Lock considerations](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock-managing.html)
- [NixOS Wiki: swap](https://wiki.nixos.org/wiki/Swap)
- [NixOS Wiki: hibernation and resume devices](https://wiki.nixos.org/wiki/Power_Management)
- [Linux kernel: system sleep states](https://dri.freedesktop.org/docs/drm/admin-guide/pm/sleep-states.html)
- [NVIDIA: Linux power-management integration](https://download.nvidia.com/XFree86/Linux-x86_64/460.32.03/README/powermanagement.html)
