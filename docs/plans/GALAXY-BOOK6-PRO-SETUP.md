# Samsung Galaxy Book6 Pro — new daily-driver host

Status: phase 1 done (host config created, dry build passes; not installed)

Decisions (2026-11-23): hostname `galaxy-book6-pro`; no disk encryption for
now; wipe Windows; no Hyprland/Sway, `gaming`, `thunderbird` or charge limit.
CPU: Core Ultra 7 356H (Panther Lake). Kernel: `pkgs-unstable.linuxPackages_latest`.
Syncthing is commented out in the host config until its identity exists (install step 4).

## Summary

Add a fourth NixOS host for the Samsung Galaxy Book6 Pro. It becomes the
daily driver and carries the workstation's apps and tooling, with Niri and
Noctalia v5. It is built from the Lenovo host (laptop wiring) plus the
workstation's extra apps, with the NVIDIA, AMD, and streaming-server pieces
removed.

The workstation and the Lenovo are not changed by this plan, apart from
shared lists that gain the new machine (Syncthing, monitoring, SSH keys).

## Hostname

**Recommended: `galaxy-book6-pro`**

- It follows the existing brand-and-model pattern (`lenovo-yoga-pro-7`)
  without the redundant `samsung-` prefix.
- It is short enough to type in `ssh`, Tailscale (`galaxy-book6-pro.tail37a5eb.ts.net`)
  and `nixos-rebuild --flake .#galaxy-book6-pro`.
- The name is used as a file key in several places (Noctalia settings, Niri
  variant choice, Syncthing, monitoring), so it should be decided before the
  first build and then left alone.

Derived names:

| Thing | Name |
|---|---|
| `networking.hostName` / flake output | `galaxy-book6-pro` |
| Host directory | `hosts/galaxy-book6-pro/` |
| Config module | `self.nixosModules.galaxyBook6ProConfig` |
| Hardware module | `self.nixosModules.galaxyBook6ProHardware` |
| Syncthing device | `galaxy-book6-pro` |
| sops machine key anchor | `&galaxy-book6-pro` |

Alternatives, if you prefer them: `samsung-galaxy-book6-pro` (strictly
consistent but long), or a role name like `laptop`. A role name would only
make sense if the whole fleet moved to role names, which matters soon
because `workstation` will become a server.

## Hardware notes and risks

I'm assuming the Book6 Pro uses Intel Core Ultra Series 3 (Panther Lake) with
integrated Arc (Xe3) graphics. **Check this on the machine** (`lscpu`,
`lspci -k`) before acting on the items below.

| Area | Expectation | Action |
|---|---|---|
| Kernel | The 25.11 default kernel (6.12 LTS) is too old for a 2026 Intel platform | `boot.kernelPackages = pkgs.linuxPackages_latest`. Boot the installer from the newest ISO available (unstable/graphical) |
| GPU / Mesa | Xe3 needs the `xe` driver and a recent Mesa | New `intelGraphics` module. If 25.11's Mesa can't drive it, take Mesa from `pkgs-unstable` |
| Samsung platform | The mainline `samsung-galaxybook` driver (kernel 6.15+) exposes platform profiles, keyboard backlight and battery charge limit | Use it for power profiles and an 80% charge limit (optional) |
| Speakers | Earlier Galaxy Book Pro models had silent speakers on Linux (amp quirks) | Test after install. It may need a kernel quirk or SOF topology fix |
| Webcam | Intel MIPI/IPU cameras usually don't work out of the box | Test it and don't count on it at first. libcamera/IPU support may come later |
| Fingerprint | Unknown reader, probably unsupported | Skip. Don't enable `fprintd` until the reader is identified |
| Wi-Fi/BT | Intel Wi-Fi 7 (iwlwifi) | Covered by `enableRedistributableFirmware` + latest kernel |
| Display | High-DPI OLED panel (`eDP-1`) | Niri's laptop variant already handles `eDP-1`. Tune the scale after first boot if needed |

## Install-time decisions (made in the installer, then recorded in `hardware.nix`)

1. **Full-disk encryption (LUKS): recommended.** This is now the daily-driver
   laptop that leaves the house. The Lenovo is unencrypted, which this host
   shouldn't repeat. It also makes hibernation safe, because swap is
   encrypted too.
2. **Swap for hibernation:** a swap file or partition at least the size of
   RAM, inside LUKS. This reuses the Lenovo's suspend-then-hibernate policy.
3. **Secure Boot (Lanzaboote): recommended, as a second step.** Install with
   plain systemd-boot (`bootloader`). Once the system boots, create keys with
   `sbctl`, enroll them, and switch to `secureBoot`, as the workstation does.
4. **Windows:** keep or wipe? If it is kept for firmware or BIOS updates, add
   `bootWindows`.

## Feature set

The base is the workstation's import list. The table below shows how the
new host differs from it.

### Kept from the workstation (no change)

Core: `base`, `networking`, `firewall`, home-manager, `stylix`, `userHenhal`.

Services: `pipewire`, `bluetooth`, `externalIo`, `printer`, `android`,
`virtualization`, `docker`, `syncthing`, `garbageCollection`.

Connectivity: `sshServer`, `tailscale`, `monitoringExporter`, `moonlight`.

Desktop: `desktopCommon`, `sddm`, `niri`, `noctalia` (v5), `rofi`, `clipman`,
`grimScreenshot`, `waylandApplets`, `gammastep`.

Apps: `kitty`, `freecad`, `nvim`, `zsh`, `tmux`, `yazi`, `vivaldi`,
`zenBrowser`, `brave`, `firefox`, `googleChrome`, `microsoftEdge`,
`obsidian`, `t3code`, `opencloudDesktop`, `spotify`, `gimp`, `gthumb`,
`mpv`, `zathura`, `onlyoffice`, `nautilus`, `missionCenter`,
`gnomeCalculator`, `vial`, `kdeconnect`, `codecrafters-cli`.

Settings: `git`, `sshConfig`, `secrets`, `nerdFonts`, `udiskie`, `devTools`,
`sessionVariables`, `direnv`, `devShellBootstrap`, `userlandPackages`
(GUI on), `bottles`, `utils`, `powerMonitor`, `yaziFloat`.

### Workstation features left out

| Feature | Why |
|---|---|
| `secureBoot` | Added after install (see above). `bootloader` is used first |
| `nvidiaGraphics` | No NVIDIA GPU. `intelGraphics` (new) replaces it |
| `sunshine` | The laptop is a streaming client, not a host. `moonlight` stays |
| `bootWindows` | Only if Windows is kept |
| `bluetoothFix` | Specific to the workstation's MediaTek MT7925 |
| `brightnessExternal` | DDC brightness for the workstation's monitors. It could be added later for a desk monitor |
| `hyprland`, `sway` | Alternative sessions that were never the default. Their configs branch on hostname (`lenovo-yoga-pro-7` / `workstation`), so they'd need laptop branches for the new name. **Your call:** leave them out (recommended), or add them and generalise those branches to "laptop" |
| `hyprlock` | Belongs to Hyprland. Noctalia v5 locks the screen |
| Workstation-only settings | `hardware.nvidia.*`, `modprobe.blacklist=amdgpu`, `hermes` persistent service |

### Added from the Lenovo (laptop wiring)

- `systemdLogind`: lid and power-button handling, plus
  `suspend-then-hibernate` with `HibernateDelaySec=2h`.
- `swayidle` with `lockCommand = "noctalia"` and `session = "niri"`.
- `services.upower.enable = true`.
- `boot.kernelModules = [ "ax88179_178a" ]` (if you use the same USB-C
  Ethernet adapter).
- `thunderbird` (Lenovo only today; keep it if you use it).
- `my.monitoring.exporter.enableBattery = true`.

### Gaming (your call)

`gaming` (Steam, gamemode, gamescope) is a workstation feature. It runs on
Arc integrated graphics, but costs closure size. **Recommended:** leave it
out at first and stream from the workstation (Moonlight) while it still has
its GPU. Add it later if you want local games.

## New modules required

1. **`intelGraphics`** (`modules/features/system/intel-graphics.nix`).
   Equivalent to `amdGraphics`: `hardware.graphics` with
   `intel-media-driver` (VA-API, `LIBVA_DRIVER_NAME=iHD`), `vpl-gpu-rt`,
   `intel-compute-runtime`, 32-bit Mesa,
   `hardware.cpu.intel.updateMicrocode`, and `libva-utils`. Includes an
   optional switch to take Mesa from `pkgs-unstable`.
2. **`laptopPower`** (an Intel-safe battery policy). `minimalBattery` can't
   be reused as-is: it runs `ryzenadj`, writes `amdgpu` sysfs and udev rules,
   and blacklists NVIDIA. Proposed contents:
   - `services.power-profiles-daemon` (or the current `tuned`, so it matches
     the Lenovo), driving the `samsung-galaxybook` platform profile.
   - `services.thermald.enable = true` (Intel).
   - `powertop` auto-tune and Wi-Fi powersave, as in `minimalBattery`.
   - Optional `my.laptopPower.chargeLimit = 80` that writes
     `charge_control_end_threshold`.
   - **Alternative:** split `minimalBattery` into a vendor-neutral core and an
     AMD part, then use the core on both laptops. That is cleaner, but it
     touches the Lenovo, which you said should stay unchanged for now, so I
     suggest doing it later.

## Files to create or change

### New

```
hosts/galaxy-book6-pro/default.nix         # copy of lenovo default.nix, renamed output
hosts/galaxy-book6-pro/configuration.nix   # feature list above
hosts/galaxy-book6-pro/hardware.nix        # PLACEHOLDER until install (see below)
modules/features/system/intel-graphics.nix
modules/features/system/laptop-power.nix
modules/features/desktop/noctalia/v5/galaxy-book6-pro.toml   # copy of lenovo-yoga-pro-7.toml
secrets/syncthing/galaxy-book6-pro.yaml    # created after install (needs device key)
```

The Noctalia v5 module loads `v5/<hostname>.toml`, so this file is required.
The Lenovo file is the right starting point because it already targets
`eDP-1`. Niri needs no change: every host other than `workstation` gets the
laptop variant.

### Changed (shared lists only)

| File | Change |
|---|---|
| `.sops.yaml` | Add a `&galaxy-book6-pro` machine key (and later a personal `&henhal-galaxy` key). Add it to `shared-interactive`, `auth`, and its own syncthing rule. Re-key with `sops updatekeys` |
| `modules/features/network/syncthing.nix` | Add the device ID and add it to the `shared` folder participants |
| `modules/users/henhal.nix` | Add the laptop's `henhal@galaxy-book6-pro` SSH public key |
| `modules/features/network/ssh-config.nix` | Add `galaxy-book6-pro` / `-tailscale` aliases (optional) |
| `hosts/hp-server/configuration.nix` | Add the monitoring scrape target `galaxy-book6-pro.tail37a5eb.ts.net` |
| `modules/features/monitoring/rules/availability.yaml` | Add an "offline for N days" alert (for a daily driver, something like 3–7 days) |
| `docs/HOSTS.md`, `docs/INSTALL.md`, `docs/FEATURES.md` | Add a host section, matrix column, and hardware module name |

## The missing `hardware.nix`

The flake must evaluate before install, so `hardware.nix` starts as a
**placeholder** that defines `galaxyBook6ProHardware` with:

- `nixpkgs.hostPlatform = "x86_64-linux"`
- `hardware.cpu.intel.updateMicrocode`
- likely initrd modules (`nvme`, `xhci_pci`, `thunderbolt`, `usb_storage`, `sd_mod`)
- dummy `fileSystems."/"` and `"/boot"` entries, with a loud comment

This lets `nix build .#nixosConfigurations.galaxy-book6-pro.config.system.build.toplevel`
run on the workstation now, so evaluation and build errors are caught before
the laptop exists. After install, the placeholder is replaced with the
generated file (UUIDs, LUKS device, swap, resume offset).

## Install order (the secrets chicken-and-egg)

`userHenhal` reads the password hash from sops with `neededForUsers = true`,
and sops decrypts with the machine's SSH host key. **That key doesn't exist
until NixOS is installed**, so the first switch into this config would fail
to set the user password unless the order below is followed:

1. Install plain NixOS from the installer (LUKS, swap, user `henhal`).
2. On the laptop: `nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'`.
3. On the workstation: add that age key to `.sops.yaml`, then run
   `sops updatekeys` on `auth.yaml`, `shared-interactive.yaml`, and the new
   syncthing file. Commit and push.
4. Generate the Syncthing identity for the new device, store it in
   `secrets/syncthing/galaxy-book6-pro.yaml`, and add the device ID to
   `syncthing.nix`.
5. On the laptop: clone the dotfiles, copy
   `/etc/nixos/hardware-configuration.nix` into `hosts/galaxy-book6-pro/hardware.nix`
   (wrapped in the flake-parts module), `git add`, then
   `sudo nixos-rebuild switch --flake .#galaxy-book6-pro`.
6. Generate a user SSH key, then add it to `henhal.nix` and as a personal sops key.
7. Join Tailscale, then add the HP scrape target and rebuild `hp-server`.
8. Secure Boot: `sbctl create-keys`, switch `bootloader` → `secureBoot`,
   rebuild, enroll the keys in firmware setup mode.
9. Run the post-install checklist below.

## Post-install checklist

Run these on the laptop after the first successful switch. Record results
here and turn fixes into config changes.

### Hardware basics

- [ ] Confirm the platform: `lscpu` shows Core Ultra 7 356H, and
      `lspci -k | grep -A3 VGA` shows `Kernel driver in use: xe`.
- [ ] Speakers and microphone work (`pavucontrol`, `wpctl status`). If the
      speakers are silent, check `dmesg | grep -iE "sof|snd|max98"` for amp or
      topology errors.
- [ ] Webcam: `cam -l` (libcamera) or `v4l2-ctl --list-devices`. Expect
      possible IPU problems. Not a blocker.
- [ ] Fingerprint reader: `lsusb` to identify it. Leave `fprintd` disabled
      unless it is supported.
- [ ] Wi-Fi and Bluetooth: connect, then check `dmesg | grep iwlwifi` for
      firmware errors.
- [ ] Keyboard backlight: `brightnessctl --list` shows a `samsung-galaxybook`
      (or similar) `kbd_backlight` device.
- [ ] Samsung platform driver loaded: `lsmod | grep samsung_galaxybook`,
      and `cat /sys/firmware/acpi/platform_profile_choices` lists profiles.
- [ ] External display over USB-C/Thunderbolt, including Niri output
      placement and Noctalia bar.

### Graphics and video decoding

- [ ] `vainfo` (with `LIBVA_DRIVER_NAME=iHD`) lists H.264, HEVC, VP9 and AV1
      decode profiles.
- [ ] `vulkaninfo --summary` shows the Intel ANV driver, and
      `glxinfo -B` / `eglinfo` show `iris` (not `llvmpipe`).
- [ ] mpv uses hardware decoding: play a video with `mpv -v` and check for
      `Using hardware decoding (vaapi)`.
- [ ] Zen: `about:support` → Media shows hardware decoding for H.264/VP9/AV1.
      While a video plays, `intel_gpu_top` shows the Video engine busy.
- [ ] Chromium-based browsers (Vivaldi, Brave, Chrome, Edge): check
      `chrome://gpu` for "Video Decode: Hardware accelerated". If they use
      software decoding, add VA-API flags to their modules.
- [ ] If there are rendering glitches or poor GPU performance, consider
      `my.intelGraphics.useUnstableMesa` or (better) moving the flake to a
      newer NixOS release. Stable Mesa is 25.2.6.

### Power and battery

- [ ] Idle discharge rate: on battery, screen on and idle, run
      `upower -i $(upower -e | grep BAT)` or `powertop` for ~10 minutes. Note
      the watt figure here as a baseline before tuning.
- [ ] `powerprofilesctl` switches between `power-saver`, `balanced` and
      `performance`, and `platform_profile` follows.
- [ ] Energy preference changes with the profile:
      `cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference`.
- [ ] thermald: `journalctl -u thermald -b`. If it logs
      "Unsupported cpu model", remove `services.thermald.enable` from
      `laptopPower`.
- [ ] `powertop` "Tunables" tab: enable only the useful "Bad" items
      (PCI runtime PM, audio codec power save, SATA/NVMe link PM) as declarative
      settings. Do **not** enable USB autosuspend globally: it makes Logitech
      receivers and keyboards lag.
- [ ] Package C-states: `powertop` "Idle stats" should reach deep package
      states (PC6/PC10) at idle. If it stays shallow, look for a device
      blocking it (often a USB or PCIe device without runtime PM).
- [ ] Panel Self Refresh is active:
      `cat /sys/kernel/debug/dri/*/i915_edp_psr_status` or the xe equivalent
      under `/sys/kernel/debug/dri/*/` (needs root).
- [ ] Display refresh: `niri msg outputs` shows the `eDP-1` mode. Measure
      120 Hz vs 60 Hz on battery. If the difference is significant, add an
      `eDP-1` mode or VRR setting to Niri's laptop variant.

### Sleep and lid

- [ ] `cat /sys/power/mem_sleep` shows `[s2idle]` (Panther Lake has no S3).
- [ ] Suspend for 1 hour with the lid closed. Battery drop should be around
      1–2% per hour. Check for s0ix residency with
      `cat /sys/kernel/debug/pmc_core/slp_s0_residency_usec` (non-zero after
      resume).
- [ ] Hibernate works (`systemctl hibernate`) once swap and resume settings
      are in `hardware.nix`, and suspend-then-hibernate fires after 2 hours.
- [ ] Lid close on external power locks the screen (`HandleLidSwitchExternalPower = "lock"`).

## Implementation phases (after your approval)

1. **Pre-install (can be done now):** host directory with placeholder
   hardware, `intelGraphics`, `laptopPower`, Noctalia toml, docs. Check that
   it builds with `nix build`. Nothing is deployed and the other hosts are
   unaffected. Verify with `nix flake check` / build of all three existing hosts.
2. **Install day:** steps 1–7 above.
3. **Post-install:** Secure Boot, hardware tuning (audio quirks, display
   scale, power profile), decide on `gaming`.
4. **Later, out of scope here:** turning the workstation into a server and
   retiring or repurposing the Lenovo.

## Decisions needed from you

1. Hostname: `galaxy-book6-pro` (recommended) or another?
2. LUKS full-disk encryption: yes (recommended)?
3. Keep Windows (dual boot) or wipe it?
4. Hyprland/Sway alternative sessions: leave out (recommended) or include?
5. `gaming`: leave out for now (recommended) or include?
6. `thunderbird`: include (it's on the Lenovo, not the workstation)?
7. Battery charge limit at 80%: yes or no?
