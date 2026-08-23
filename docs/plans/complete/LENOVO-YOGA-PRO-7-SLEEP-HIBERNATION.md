# Lenovo Yoga Pro 7: sleep and hibernation

Status: configured; test hibernation after reboot

## Observed system state

The Lenovo Yoga Pro 7 14APH8 runs NixOS 25.11 on Linux 6.12.77.

- Firmware advertises ACPI S0, S4, and S5.
- Linux exposes `freeze`, `mem`, and `disk`; `mem` uses `s2idle` (modern
  standby). S3/deep sleep is not available on this model.
- Several completed `s2idle` suspend/resume cycles are recorded in the system
  journal, including a long suspend from 2026-08-10 to 2026-08-12.
- Closing the lid on battery currently suspends. On external power it locks,
  which keeps an externally connected desktop session available.
- `swayidle` locks the active session before system sleep.

## Why hibernation is unavailable

There is no active swap, and
`hosts/lenovo-yoga-pro-7/hardware.nix` declares `swapDevices = []`.
Consequently, logind reports hibernation, hybrid sleep, and
suspend-then-hibernate as unavailable.

The root filesystem is a plaintext ext4 filesystem on
`/dev/disk/by-uuid/6d349d18-9193-4deb-a5ab-937d306da763`; it is not backed by
LUKS. A swapfile on that filesystem would store the hibernation image in
plaintext. That image can contain session cookies, decrypted documents,
credentials, and other memory-resident secrets.

On 2026-08-12, the machine owner explicitly accepted this plaintext-swap risk
for this Lenovo. The configuration therefore creates a 32 GiB `/swapfile` on
the root filesystem. This exception applies only to this host and does not
change the encrypted-storage requirement for other machines.

## Implementation sequence

`/swapfile` is active at 32 GiB. Its first physical extent is `5347328`; with
the filesystem and kernel both using 4 KiB pages, this is also the
`resume_offset` value. The configuration supplies that offset and the root
partition's stable UUID as the resume device.

The battery lid policy is `suspend-then-hibernate`, with
`HibernateDelaySec=2h`: short closures use fast `s2idle`, and longer closures
hibernate. External-power lid close remains lock-only.

The resume setting is effective only after rebooting into the generation that
contains it. Start with a manual `systemctl hibernate` test after that reboot;
do not rely on the automatic lid action before that test completes.

If `/swapfile` is ever deleted or recreated, its physical extents can change.
Before enabling hibernation again, run `sudo filefrag -v /swapfile`, take the
first `physical_offset`, confirm the filesystem block size equals the kernel
page size, update `resume_offset`, switch, and reboot.

## Required design

The preferred long-term design is a persistent swap partition
or logical volume inside LUKS-encrypted storage, at least as large as installed
RAM plus a safety margin. Random-key encrypted swap cannot be used because its
key is discarded at shutdown and the hibernation image would be unrecoverable.

After the encrypted backing store exists, configure it in
`hosts/lenovo-yoga-pro-7/hardware.nix` using a stable device path, then add the
matching resume-device configuration in a separate change. Verify a normal
cold boot before attempting a manual hibernation.

Only after repeated manual hibernate/resume tests succeed should the lid action
change from `suspend` to `suspend-then-hibernate`. Set
`HibernateDelaySec=2h` as the initial policy: short closures use fast `s2idle`,
while longer closures preserve battery by hibernating.

## Validation and rollback

Before changing storage or boot/resume configuration, complete the mandatory
gates in [the high-risk storage and hibernation runbook](plans/high-risk-storage-hibernation-system-changes.md): verified backups and restores, local
recovery media tested on this laptop, physical console access, a documented
disk layout, and a known-good boot generation.

Validate in stages: activate encrypted swap, reboot normally, perform manual
hibernate/resume from a console, then from Niri, and repeat under realistic
memory pressure. Confirm networking, audio, Bluetooth, Syncthing, Tailscale,
and the display session after each resume.

If resume fails, boot the previous NixOS generation and remove the resume
configuration before removing or recreating the swap backing device. Never
reuse a resume UUID for a repurposed device.
