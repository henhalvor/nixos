# Samsung Galaxy Book6 Pro (`galaxy-book6-pro`)

Daily-driver laptop. It runs the workstation's apps and tooling with the
Lenovo's laptop wiring, on Niri and Noctalia v5. This page records what works,
the workarounds in place, and measured power figures.

Last updated: 2026-11-27 (kernel 7.3.5, NixOS 25.11, Mesa 25.2.6)

| | |
|---|---|
| CPU | Intel Core Ultra 7 356H (Panther Lake), 16 threads |
| GPU | Intel Graphics (PTL, `8086:b0a0`) on the `xe` driver |
| Display | Samsung OLED `eDP-1`, 2880x1800, 60/120 Hz native, scale 1.75 |
| Audio | SoundWire: Cirrus CS35L57 amps + CS42L45 codec (SDCA) |
| RAM / swap | ~31 GB / 33.8 GB swap partition (used for hibernate) |
| Disk | No encryption. Windows wiped |
| Boot | systemd-boot (`bootloader`). Secure Boot not set up yet |
| Kernel | `pkgs-unstable.linuxPackages_latest` |

Config: `hosts/galaxy-book6-pro/configuration.nix` and `hardware.nix`.
Laptop power policy: `modules/features/system/laptop-power.nix`. GPU:
`modules/features/system/intel-graphics.nix`.

## Hardware status

| Area | Status |
|---|---|
| Graphics | OK. `xe` driver, Vulkan (ANV) and GL on the Intel GPU |
| Video decode | OK. VA-API (iHD 25.3.4): H.264, HEVC, VP9, AV1 |
| Speakers / headphones / HDMI audio | OK (needs the alsa-lib override below) |
| Built-in microphone | OK (needs the alsa-lib override below) |
| Wi-Fi / Bluetooth | OK. iwlwifi firmware `c102` (the `c103`–`c107` "failed" lines at boot are normal probing) |
| Keyboard backlight | OK. `samsung-galaxybook::kbd_backlight` |
| Samsung platform driver | OK. Profiles `low-power` / `balanced` / `performance`. Firmware attributes: `power_on_lid_open`, `usb_charging` |
| Charge limit | Available (`charge_control_end_threshold`), left at 100 |
| Sleep | s2idle (no S3 on this platform) |
| Hibernate | OK. `boot.resumeDevice` set to the swap partition in `hardware.nix` |
| Brightness keys | OK (see the double key press workaround) |
| Fn lock | Firmware only: `Fn` + `Esc` toggles media keys vs F1–F12. Not controllable from Linux |
| Webcam | Not working out of the box. Sensor is a SmartSens SC200PC (ACPI `SSLC2000`) with no mainline driver, and `ipu_bridge` doesn't list it ("no subdev found in graph"). The `galaxybook6Camera` module adds a community driver; it's off (`my.galaxybook6Camera.enable = false`) and untested. Enable, rebuild and reboot to try it |
| Fingerprint | Goodix `27c6:6984` (goodixmoc). Needs libfprint from unstable (`fingerprint` module). Used for sudo, polkit and the Noctalia lock screen, not greeter/SDDM/TTY login (keeps GNOME Keyring unlocking). Works: enrol and verify OK (2026-11-28) |

## Workarounds

Each one should be re-tested after kernel or nixpkgs updates and removed once
it's no longer needed.

### Audio: newer alsa-lib for PipeWire and WirePlumber

- **Problem:** alsa-ucm-conf 1.2.14 (NixOS 25.11) has no profile for the
  CS42L45 codec. PipeWire falls back to a stereo-out-only profile with no
  microphone.
- **Fix:** in `configuration.nix`, PipeWire and WirePlumber are rebuilt with
  the stable toolchain against alsa-lib and alsa-ucm-conf 1.2.16.1 from
  unstable. The newer UCM files use syntax 8, which alsa-lib 1.2.14 rejects, so
  pointing `ALSA_CONFIG_UCM2` at them is not enough. The rest of the system
  keeps the stable alsa-lib. The first build compiles PipeWire locally.
- **Remove when:** the stable channel ships alsa-lib and alsa-ucm-conf 1.2.16
  or newer.

### Display: PSR and Panel Replay disabled

- **Problem:** Panel Replay with Selective Update (the default PSR mode on this
  panel) draws thin full-width tearing bands. The kernel logs
  `Selective fetch area calculation failed in pipe A`.
- **Fix:** `xe.enable_psr=0 xe.enable_panel_replay=0 xe.enable_psr2_sel_fetch=0`
  in `boot.kernelParams`. `xe.enable_psr=0` alone is not enough: Panel Replay
  has its own switch, which defaults to auto, so it stayed on and the bands
  came back now and then. Disabling PSR at runtime (`i915_edp_psr_debug=0x1`)
  turns off both, which is why the first test looked fixed.
- **Check it's off:** `PSR mode` in `i915_edp_psr_status` should say disabled,
  not `Panel Replay Selective Update enabled`.
- **If bands remain with all three set:** try `xe.enable_fbc=0` (framebuffer
  compression). Untested here; suggested for similar artifacts in an
  unverified Intel community thread (Raptor/Lunar/Arrow Lake, no logs).
- **Cost:** some idle power on a static screen. Idle is still 1.9 W (see below),
  so this is small.
- **Retest:** at runtime, without a rebuild:
  ```
  sudo cat /sys/kernel/debug/dri/0000:00:02.0/i915_edp_psr_status
  echo 0x0 | sudo tee /sys/kernel/debug/dri/0000:00:02.0/i915_edp_psr_debug  # driver default
  echo 0x2 | sudo tee /sys/kernel/debug/dri/0000:00:02.0/i915_edp_psr_debug  # PSR1 only, untested
  echo 0x1 | sudo tee /sys/kernel/debug/dri/0000:00:02.0/i915_edp_psr_debug  # PSR off
  ```
  If PSR1 (`0x2`) is clean, drop `xe.enable_psr=0` and keep the other two
  parameters instead of disabling PSR completely.

### Brightness keys: double key press

- **Problem:** the firmware sends every brightness key press twice from the
  ACPI "Video Bus" input device at the same instant. The keyboard itself sends
  no brightness keys.
- **Fix:** the Niri brightness binds (`modules/features/desktop/niri/niri.nix`)
  have `cooldown-ms = 50`, which drops the duplicate. The step is 5%.

### Hibernate breaks the Samsung firmware interface (no fix yet)

- **Problem:** after resuming from hibernate (S4), every `samsung-galaxybook`
  call to the firmware fails with
  `acpi SAMB430:00: failed to execute CSFI; device responded with failure code 0xff`.
  The keyboard backlight can't be turned on, and platform profile changes
  probably don't reach the firmware either. Plain suspend (s2idle) is not
  affected. One such error at boot is normal.
- **Do not** reload the module (`modprobe -r samsung_galaxybook`): the driver
  sits in the i8042 keyboard path and the built-in keyboard stops working until
  a reboot.
- **Fix:** reboot. To make it rare, `HibernateDelaySec=24h`: standby measured
  under ~1%/h, so hibernating early saved little.
- **Check for it:** `journalctl -k -b | grep -c "failed to execute CSFI"` (more
  than 1 means it's broken).

## Power

### Profiles

power-profiles-daemon drives the Samsung platform profile. Noctalia's
control-center switch and `powerprofilesctl` both use it. Measured on battery:

| | power-saver | balanced | performance |
|---|---|---|---|
| Platform profile | `low-power` | `balanced` | `performance` |
| CPU energy preference (battery) | `power` | `balance_power` | `performance` |
| Sustained limit (PL1) | 16 W | 32 W | 35 W |
| Short boost limit (PL2) | 80 W | 80 W | 80 W |
| 16-thread benchmark, 20 s | 43% of balanced, ~15 W | 100%, ~63 W | 102%, ~70 W |
| Idle | similar to balanced | — | ~2.5x balanced (clocks stay high) |

On AC power, balanced uses `balance_performance` instead of `balance_power`.

**Recommended:** balanced as the everyday default, power-saver to stretch the
battery, performance only on AC. Balanced and performance differ little except
at idle, where performance wastes power.

### Baseline measurements

Whole-system draw from the battery sensor (current × voltage), on battery,
balanced profile, PSR off. Use these to spot regressions after updates.

| State | Draw |
|---|---|
| Idle, screen on, browser and tmux open but inactive | **~1.9 W** |
| YouTube in Zen, fullscreen, 60 Hz | **~4–4.5 W** |
| Netflix in Zen (windowed, 120 Hz) | ~2.5–3 W above idle |

For comparison, other Linux Panther Lake laptops report 1.4–2.2 W idle (Dell
XPS 14/16). Trusted Reviews measured about 5 W for Netflix on this model under
Windows.

Measure:
```
echo "$(( $(cat /sys/class/power_supply/BAT1/current_now) * $(cat /sys/class/power_supply/BAT1/voltage_now) / 1000000000 )) mW"
```
Average several readings over a few minutes; a single reading is noisy.

### Video decoding

- **YouTube and other unprotected video in Zen** is decoded on the GPU (VA-API).
  The decoder process (RDD) uses about 5% CPU and the video engine about 5%.
  Most of the remaining power goes on the YouTube page itself, so fullscreen
  and 60 Hz help most.
- **Netflix (Widevine DRM)** is decoded in software in every Linux browser.
  Zen's Widevine process used about 45% of a core; Brave's used about 92%, plus
  more in its renderer. Use Zen for Netflix. Netflix is capped at 720p in all
  Linux browsers.
- `intel_gpu_top` does not support the `xe` driver. Per-process engine usage is
  in `/proc/<pid>/fdinfo/*` (`drm-cycles-vcs` vs `drm-total-cycles-vcs` for the
  video engine), readable without root for your own processes.

## Idle, lock, suspend and lid

Three parts handle this: swayidle (idle timers), systemd-logind (lid and power
button) and Noctalia (lock screen and session menu).

| | On AC power | On battery |
|---|---|---|
| 5 min idle | Lock | Lock |
| 10 min idle | Screen off | Screen off |
| 30 min idle (20 min after screen off) | Nothing | Suspend |
| Lid closed | Lock, panel off | Lock, panel off, suspend after 20 min |
| Lid opened within 20 min | — | Pending suspend cancelled |

- **Every suspend is suspend-then-hibernate:** s2idle, then hibernate after
  `HibernateDelaySec=24h`. systemd also hibernates earlier if the battery runs
  low.
- **Battery checks happen when a timer fires.** Plugging in before then
  cancels that suspend.
- **Known limitation:** the idle suspend fires once per idle period. If you're
  on AC at the 30-minute mark and unplug later, it waits for a new idle period.
- **How the lid works:** logind `HandleLidSwitch = "lock"`. Niri's `lid-close` /
  `lid-open` switch events run `niri-lid-switch` (in `niri.nix`). On close it
  runs `niri msg action power-off-monitors` when no external monitor is on,
  because niri only turns the laptop panel off by itself when an external
  monitor is connected. Without this the panel stayed lit behind the lid until
  the 10-minute screen-off. It then calls `lid-close-hook` / `lid-open-hook`
  (from the swayidle module), which start and stop a transient
  `lid-suspend.timer` user unit. Check it with
  `systemctl --user list-timers lid-suspend.timer`.
- **Lid suspend is delayed on purpose:** closing the lid on battery suspends
  after 20 minutes, not immediately; on AC it never suspends. Change
  `lidSuspendDelay` below for a shorter delay.
- **Fixed 2026-11-27:** idle suspend never ran. swayidle's service has no
  `systemctl` on its `PATH`, so `suspend-on-battery` failed with
  `systemctl: not found`. The script now sets its own `PATH`.
- **Noctalia:** provides the lock screen (`noctalia msg session lock`), the
  session menu (lock, suspend, hibernate, reboot, shutdown via systemd) and the
  power-profile switch. It has no idle or timeout settings here.

Adjust the timings (seconds) in `configuration.nix`:

```nix
my.swayidle = {
  lockTimeout = 300;            # idle → lock
  screenOffTimeout = 600;       # idle → screen off
  suspendTimeout = 600 + 1200;  # idle → suspend, battery only; counted from last input; null = never
  lidSuspendDelay = 1200;       # lid closed → suspend, battery only; null = never
};
```

The hibernate delay is `HibernateDelaySec` in the same file.

## Display

- **Default refresh rate: 60 Hz**, to save power. Set with
  `my.niri.laptopPanelMode = "2880x1800@60.000"` in `configuration.nix`;
  without it niri starts at the panel's preferred 120 Hz.
- **Refresh rate toggle:** `Mod+Shift+R` cycles the panel 120 → 90 → 60 Hz with
  a notification. 60 and 120 are native modes; 90 is a custom CVT mode Niri
  generates (89.98 Hz). The choice resets to 60 Hz on reboot or Niri config
  reload.
- **VRR:** supported by the panel, currently disabled.
- **Scale:** 1.75 (logical 1645x1028).

## Login screen

greetd with Noctalia Greeter (`noctaliaGreeter` module), not SDDM. Noctalia
syncs wallpaper, palette, theme mode, font, corner radius and monitor layout
to it (`[shell.greeter_sync] auto_sync = true` in the Noctalia TOML; by hand
with `noctalia msg greeter-sync`). `henhal` may run the sync helper without a
password. Changes show at the next login screen. Auto-sync only fires on
a change, not at login, so after a reinstall (or wiping
`/var/lib/noctalia-greeter`) run `noctalia msg greeter-sync` once; until then
the greeter shows its built-in default look.

- Password only: fingerprint is off for greetd so the login unlocks GNOME
  Keyring.
- Synced state: `/var/lib/noctalia-greeter/sync.toml` and `wallpaper*`.
  `greeter.toml` (from Nix) wins over it and only sets session and cursor.
- Logs: `/var/log/noctalia-greeter.log`,
  `/var/lib/noctalia-greeter/greeter.log`, `journalctl -u greetd`.
- Fallback: swap `noctaliaGreeter` for the commented `sddm` import in
  `configuration.nix`. If the greeter won't start, use a TTY
  (`Ctrl+Alt+F2`) or the previous generation in the boot menu.

## Remote development on the workstation

Heavy dev work runs on the workstation, with this laptop as the client.

- **SSH aliases:** `workstation-tailscale` opens the tmux session and forwards
  the dev ports. It cannot run one-off commands
  (`ssh workstation-tailscale '<cmd>'` fails with "Cannot execute command-line
  and remote command"). For scripts and tools, use `workstation-t3` (no tmux,
  no forwards), or add `-o RemoteCommand=none -o RequestTTY=no`.
- **T3 Code:** the desktop app here adds the workstation as an SSH environment
  (Settings → Environments → Add environment → SSH → `workstation-t3`). The app
  downloads its own server into `~/.t3/runtime` on the workstation. Agents,
  their logins and the project checkouts all live on the workstation.
- **Agents and dev shells:** agents don't trigger direnv. Global agent
  instructions (`modules/features/ai/agent-instructions.nix`) tell them to use
  `direnv exec .`. A new clone on the workstation needs `direnv allow` once.
- **Not tested yet:** an end-to-end T3 session over `workstation-t3`.

## Open items

- [ ] Syncthing: generate the identity, store it in
      `secrets/syncthing/galaxy-book6-pro.yaml` (sops rule already exists),
      add the device ID to `syncthing.nix`, re-enable the module and the
      `my.syncthing` block (TODOs in `configuration.nix`), and enable the
      Syncthing monitoring metrics.
- [ ] Monitoring: add the scrape target `galaxy-book6-pro.tail37a5eb.ts.net` to
      `hosts/hp-server/configuration.nix` and an "offline for N days" alert in
      `modules/features/monitoring/rules/availability.yaml`.
- [ ] Secure Boot: `sbctl create-keys`, switch `bootloader` → `secureBoot`,
      rebuild, enroll the keys in firmware setup mode.
- [ ] Docs: fill out the `docs/HOSTS.md` entry (only a pointer so far) and add
      this host to `docs/INSTALL.md` and
      `docs/FEATURES.md`.
- [ ] Not yet tested: hibernate end to end, the 20-minute lid suspend on
      battery, suspend drain overnight (expect ~1–2%/h) and s0ix residency,
      external display over USB-C/Thunderbolt, Chromium hardware decoding of
      unprotected video, 90 Hz for flicker.
- [ ] Decide later: `gaming`, battery charge limit, VRR.

## Reinstall notes

The secrets setup has an ordering problem: `userHenhal` reads its password hash
from sops, which decrypts with the machine's SSH host key, and that key only
exists after install. On a reinstall:

1. Install plain NixOS and create the `henhal` user.
2. On the laptop: `nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub'`.
3. On another host: replace the `&galaxy-book6-pro` age key in `.sops.yaml`,
   run `sops updatekeys` on every file that lists it, commit and push.
4. On the laptop: clone the dotfiles, copy the new
   `/etc/nixos/hardware-configuration.nix` into `hosts/galaxy-book6-pro/hardware.nix`
   (keep the flake-parts wrapper and the `boot.resumeDevice` line, with the new
   swap UUID), then `sudo nixos-rebuild switch --flake .#galaxy-book6-pro`.
5. Generate a user SSH key and update it in `modules/users/henhal.nix`.
