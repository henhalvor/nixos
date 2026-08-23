# Machine orchestration plan

Status: proposal

## Current status

As of 2026-08-23, the setup has three NixOS hosts and one nix-on-droid configuration:

- The workstation is the main desktop. It runs the graphical environment, Android development tools, AI tools, Tailscale, SSH, monitoring, and Sunshine for remote desktop streaming.
- The Lenovo Yoga Pro 7 is a rarely used travel laptop. It has the shared development tools, Android support, Tailscale, SSH, and monitoring, but it is not an always-on development host.
- The HP server is headless. It runs OpenCloud, backups, monitoring, Tailscale, SSH, and other infrastructure services. It has no desktop environment.
- The Android tablet provides a mobile SSH and mosh client for reaching the other machines.

The current configuration is already declarative. Each NixOS machine has its own `nixosConfiguration`, while shared features and Home Manager modules live in the flake. The current configuration does not yet include a dedicated development machine, a Mac, a `deploy-rs` deployment output, or a Disko and `nixos-anywhere` replacement workflow.

Remote administration currently works through Tailscale and SSH. Sunshine exists for the workstation, but there is not yet a tested remote GUI workflow for a separate development desktop or a future Mac. The current SSH aliases also start an interactive tmux session, so deployment commands need a non-interactive SSH override.

The proposed GMKtec K12 has not been purchased or installed. A Mac mini has also not been purchased, so Xcode and the iOS Simulator are not currently available.

## Goal

The goal is a small, role-based machine fleet that can be reached from anywhere, configured from Git, updated remotely, and replaced without rebuilding the setup by hand.

The finished setup should provide:

- a dedicated development desktop for web development, React Native, Android emulators, Nix builds, and coding agents;
- a stable HP infrastructure host that is not overloaded by interactive development work;
- remote GUI access to the development desktop for coding and emulator use while travelling;
- remote GUI access to the Mac mini for Xcode and the iOS Simulator;
- remote GUI access to the K12 for coding, development, ai agents and emulator use
- a repeatable path from new hardware to a complete NixOS or macOS configuration;
- rollback and recovery paths when a deployment or machine fails;
- clear data ownership, with code in Git, important user data backed up, and secrets recoverable without depending on the failed machine;
- a simple way to add future machines by declaring their role, hardware, secrets, and access policy.

The goal is not to pool all machines into one cluster. Each machine should have a clear job, and the access and deployment layers should make the machines feel like one manageable system.

This document describes how to use the current NixOS machines, where a future development machine fits, and how to add a Mac mini for iOS development.

The recommendation is to keep machine roles separate, use Tailscale for private access, use Nix for configuration, and add a deployment tool for installation, updates, and replacement.

## Proposed roles

| Machine           | Role                                                                           |
| ----------------- | ------------------------------------------------------------------------------ |
| Workstation       | Main local desktop, GPU work, deployment controller                            |
| HP server         | OpenCloud, backups, monitoring, and stable infrastructure                      |
| GMKtec K12        | Always-on development desktop, Android emulator, Nix builds, and coding agents |
| Lenovo Yoga Pro 7 | Travel computer and emergency administration client                            |
| Future Mac mini   | Xcode, iOS Simulator, and iOS builds                                           |

This keeps interactive development away from the HP server. The current host split is documented in [HOSTS.md](HOSTS.md), and the existing flake already separates reusable features from host-specific configuration in [ARCHITECTURE.md](ARCHITECTURE.md).

The HP server should remain a stable storage and infrastructure host. It should not become the primary coding or agent machine.

## The GMKtec K12

The Proshop listing calls the processor "Ryzen 7 H225" in its title, but describes the machine as using a Ryzen 7 H255. The official GMKtec page also identifies it as the H255. Verify the delivered model and invoice before ordering.

The listed hardware is a good match for web development and React Native:

- 8 CPU cores and 16 threads
- Radeon 780M integrated graphics
- 32 GB dual-channel DDR5 memory
- Three M.2 slots
- Dual 2.5 GbE ports
- USB4 and OCuLink

Sources: [Proshop listing](https://www.proshop.no/Stasjonaer-Mini-PCBarebone/GMKtec-K12-AMD-Ryzen-7-H225-32GB-1TB-Windows-11-Pro/3462534) and [GMKtec specifications](https://www.gmktec.com/products/gmktec-k12-amd-ryzen%E2%84%A2-7-h-255-mini-pc?variant=0f751f07-2ec8-4b82-9341-38520431c40d).

Treat the K12 as a consumer desktop, not as a server. It does not replace the HP server's role. It has no server-grade remote management or ECC memory, and its integrated GPU is not a good long-term solution for serious local LLM inference. OCuLink leaves an eGPU option for later, but the eGPU should be treated as a separate project.

Start with 32 GB. Upgrade to 64 GB when Android emulators, browsers, builds, and several agents regularly compete for memory.

## Private access network

Use Tailscale as the access network for every machine. Do not expose SSH, RDP, VNC, or Sunshine directly to the public internet.

Tailscale provides stable device names through MagicDNS, private connectivity across changing networks, and access policies for individual machines and services. Use grants or ACLs to define access such as:

- personal devices may SSH into all machines;
- personal devices may reach the development desktop GUI;
- the development machine may reach only the HP services it needs;
- the HP server does not receive broad access to desktop machines.

See [Tailscale device access](https://tailscale.com/kb/1452/connect-to-devices) and [Tailscale access policies](https://tailscale.com/docs/features/access-control/acls).

Use hosted Tailscale initially. Headscale is a valid self-hosted alternative, but running the control plane only on HP would make HP a dependency for reaching the rest of the network. Consider Headscale later on an independent VPS if self-hosting the access control plane becomes important. See the [Headscale documentation](https://headscale.net/stable/).

## NixOS deployment and replacement

Add a deployment layer around the existing `nixosConfigurations`:

1. Use `nixos-anywhere` and Disko for initial installation and replacement.
2. Use `deploy-rs` for normal remote updates and rollback.
3. Keep secrets in the existing SOPS and age workflow.
4. Keep code in Git and user data in explicit backup sets. Do not treat a machine's home directory as the only copy of important data.

`deploy-rs` consumes NixOS configurations, provides deployment checks, and can roll back after it loses contact with a target. See the [deploy-rs documentation](https://github.com/serokell/deploy-rs/blob/master/README.md).

`nixos-anywhere` can partition the disk with Disko, install NixOS, generate hardware configuration, and leave future changes to the flake. See the [nixos-anywhere quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md).

The development host should have a structure like this:

```text
hosts/dev-machine/
  default.nix
  configuration.nix
  hardware.nix
  disk-config.nix
```

The role configuration should be reusable. Hardware and disk layout are machine-specific. A replacement machine then needs a new hardware report, a new machine secret if required, and the same role configuration.

The current SSH aliases start an interactive tmux command. Use a separate non-interactive deployment alias, or retain the existing `RemoteCommand=none` override when running deployment commands.

Keep a checkout of this repository on both the workstation and the Yoga. That way either machine can deploy a replacement if the other one is unavailable.

## Linux GUI access

Use Sunshine on the K12 and Moonlight on the workstation, Yoga, tablet, or another client.

Sunshine supports Linux Wayland capture, AMD encoding, and recent releases include headless-monitor support. See the [Sunshine configuration documentation](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html).

The current Sunshine module is a useful starting point, but its monitor scripts are tied to the workstation's Hyprland monitor names. Split those scripts from the generic Sunshine feature before reusing it on the K12.

The K12 needs a graphical session for Sunshine. The simplest arrangement is an always-on, locked development session with automatic login and sleep disabled. If automatic login is not acceptable, use a tested headless or virtual-display arrangement and keep SSH as the recovery path.

KVM over IP is not needed for normal GUI access. It is only useful for BIOS, bootloader, disk replacement, power control, or a completely broken operating system.

## Mac GUI access

Use two separate access paths:

- SSH for administration, scripts, and recovery.
- Screen Sharing for Xcode and the iOS Simulator.

macOS Screen Sharing is VNC-compatible and supports remote control of the desktop. Run it over Tailscale and restrict it to the personal account. See [Apple's Screen Sharing documentation](https://support.apple.com/en-ie/guide/mac-help/mh11848/mac).

If VNC is too slow for Xcode or the Simulator, test NoMachine. It supports macOS hosts and Linux clients. See [NoMachine's supported systems](https://www.nomachine.com/support/supported-operating-systems-and-supported-applications).

Use `nix-darwin` with Home Manager for the Mac's shell, packages, developer tools, and preferences. Xcode, Apple ID setup, App Store applications, and some privacy permissions remain macOS-specific. See [Home Manager with nix-darwin](https://nix-community.github.io/home-manager/nix-flakes/nix-darwin.html).

Configure the Mac mini to:

- disable automatic sleep;
- enable Remote Login and Screen Sharing;
- use a dummy display adapter if the headless resolution is poor;
- keep the FileVault recovery key outside the Mac and outside HP;
- test recovery after an unexpected reboot.

The normal Tailscale macOS application runs after user login. Tailscale also documents a CLI-only `tailscaled` variant that can run before login, but marks it for experienced administrators. See [Tailscale's macOS variants](https://tailscale.com/docs/concepts/macos-variants).

On Apple silicon with macOS 26 or newer, Apple documents unlocking FileVault over SSH after restart when Remote Login and networking are available. Test this before relying on it. See [Apple's FileVault security documentation](https://support.apple.com/guide/security/sec8447f5049/web).

## KVM over IP

Do not buy KVM over IP as part of the first K12 setup.

First test:

- BIOS power-on-after-AC-loss;
- Wake-on-LAN;
- remote NixOS installation with `nixos-anywhere`;
- Sunshine after reboot;
- recovery from the Yoga while away from home.

Add PiKVM, JetKVM, or a similar device if remote BIOS and boot recovery become necessary. PiKVM supports BIOS access, virtual media, and ATX power control when the target hardware exposes the required connections. See the [PiKVM documentation](https://docs.pikvm.org/v3/).

KVM should be a recovery upgrade, not a prerequisite for the development workflow.

## Suggested rollout

1. Install NixOS on the K12 and add it as `dev-machine`.
2. Add Disko and a replacement-ready hardware layout.
3. Add Tailscale policy for SSH and GUI access.
4. Add `deploy-rs` around the existing host configurations.
5. Configure Sunshine and test Moonlight from the Yoga and a mobile device while away from the home network.
6. Add the Mac mini later with a `darwinConfigurations` entry, nix-darwin, Home Manager, Tailscale, Screen Sharing, and Xcode.
7. Add KVM only after the recovery tests show that it solves a real remaining problem.

This gives each machine one clear job and makes replacement mostly a matter of reinstalling the declared system, restoring secrets, and cloning the required repositories.
