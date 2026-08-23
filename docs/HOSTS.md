# Host Configurations

Detailed breakdown of what each host includes and its specific settings.

---

## Workstation

**Type:** Desktop workstation<br>
**Default window manager:** Niri<br>
**Desktop shell:** Noctalia v5<br>
**GPU:** NVIDIA  
**Bootloader:** Lanzaboote (secure boot)

### Enabled Features

<details>
<summary>Infrastructure (5)</summary>

- `base` — core NixOS settings
- `secureBoot` — Lanzaboote secure boot
- `networking` — NetworkManager + firewall
- `stylix` — Stylix theming (+ `inputs.stylix` NixOS module)
- `userHenhal` — user account + identity
</details>

<details>
<summary>System Services</summary>

- `pipewire` — audio
- `bluetooth` — Bluetooth + blueman
- `externalIo` — Logitech wireless (solaar), USB rules
- `printer` — CUPS
- `android` — ADB + udev
- `nvidiaGraphics` — NVIDIA drivers + VAAPI
- `gaming` — Steam, gamemode, gamescope
- `virtualization` — libvirt + QEMU
- `docker` — containers
- `syncthing` — file sync
- `bootWindows` — Windows boot entry
- `garbageCollection` — scheduled Nix store cleanup
</details>

<details>
<summary>Server & Connectivity</summary>

- `sshServer` — OpenSSH
- `tailscale` — VPN
- `monitoringExporter` — Tailscale-only Node/Process metrics and journal forwarding
- `sunshine` — game streaming
</details>

<details>
<summary>Desktop</summary>

- `desktopCommon` — XDG, fonts, GTK/Qt
- `sddm` — display manager
- `hyprland` — alternative WM
- `sway` — alternative WM
- `niri` — default WM/session
- `noctalia` — Noctalia v5 shell and panel
- `hyprlock` — alternative lock screen
- `rofi` — app launcher
- `clipman` — clipboard
- `grimblast` — screenshots
- `waylandApplets` — nm-applet, blueman
- `gammastep` — blue light filter
</details>

<details>
<summary>Applications</summary>

- `kitty` — terminal
- `freecad` — CAD
- `nvim` — Neovim
- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `vivaldi`, `zenBrowser`, `brave`, `firefox`, `googleChrome`, `microsoftEdge` — browsers
- `obsidian` — notes
- `opencloudDesktop` — OpenCloud client
- `spotify` — music
- `gimp`, `gthumb`, `mpv`, `zathura` — media
- `onlyoffice` — office
- `nautilus` — file manager (GUI)
- `missionCenter` — system monitor
- `gnomeCalculator` — calculator
- `vial` — keyboard firmware
- `claudeCode`, `amazonQ`, `opencode` — AI tools
- `kdeconnect`, `codecrafters-cli`, `ohMyPi` — additional tools
</details>

<details>
<summary>Settings & Utilities</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts`, `udiskie` — fonts, auto-mount
- `devTools`, `sessionVariables`, `direnv`, `devShellBootstrap`, `bottles`, `utils` — environment
- `powerMonitor`, `yaziFloat`, `brightnessExternal` — scripts
</details>

### Host-Specific Settings

```nix
networking.hostName = "workstation";
my.noctalia.version = "v5";
my.syncthing.user = "henhal";
services.displayManager.defaultSession = "niri";
my.desktop.terminal = "kitty";
my.desktop.browser = "zen-beta";

# NVIDIA power management disabled
# Logitech wireless peripherals enabled
# Custom Linux firmware packages
```

Niri's workstation variant uses `HDMI-A-1`, `DP-1`, and the experimental
`sunshine` virtual output. Workspaces are assigned across the physical
displays, with workspace 10 reserved for Sunshine/Moonlight streaming.
Hyprland and Sway remain available as alternative sessions, but they are not
the default.

---

## Lenovo Yoga Pro 7

**Type:** Laptop<br>
**Default window manager:** Niri<br>
**Desktop shell:** Noctalia v5<br>
**GPU:** AMD (integrated)  
**Bootloader:** systemd-boot

### Enabled Features

<details>
<summary>Infrastructure (5)</summary>

- `base` — core NixOS settings
- `bootloader` — systemd-boot
- `networking` — NetworkManager + firewall
- `stylix` — Stylix theming
- `userHenhal` — user account
</details>

<details>
<summary>System Services</summary>

- `pipewire` — audio
- `bluetooth` — Bluetooth + blueman
- `externalIo` — Logitech wireless, USB rules
- `printer` — CUPS
- `android` — ADB
- `systemdLogind` — lid/power button handling
- `virtualization` — libvirt + QEMU
- `syncthing` — file sync
- `amdGraphics` — AMD GPU drivers
- `minimalBattery` — battery-aware CPU/GPU power caps
- `garbageCollection` — scheduled Nix store cleanup
</details>

<details>
<summary>Server & Connectivity</summary>

- `sshServer` — OpenSSH
- `tailscale` — VPN
- `monitoringExporter` — Tailscale-only Node/Process, battery, Syncthing, and journal telemetry
</details>

<details>
<summary>Desktop</summary>

- `desktopCommon` — XDG, fonts, GTK/Qt
- `sddm` — display manager
- `niri` — default WM/session
- `noctalia` — Noctalia v5 shell and panel
- `swaylock` — lock screen
- `swayidle` — idle daemon
- `rofi` — app launcher
- `clipman` — clipboard
- `grimScreenshot` — screenshots
- `waylandApplets` — nm-applet, blueman
- `gammastep` — blue light filter
</details>

<details>
<summary>Applications</summary>

- `kitty` — terminal
- `freecad` — CAD
- `thunderbird` — mail client
- `nvim` — Neovim
- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `vivaldi`, `zenBrowser`, `brave`, `firefox`, `googleChrome`, `microsoftEdge` — browsers
- `obsidian` — notes
- `opencloudDesktop` — OpenCloud client
- `spotify` — music
- `gimp`, `gthumb`, `mpv`, `zathura` — media
- `onlyoffice` — office
- `nautilus` — file manager (GUI)
- `missionCenter` — system monitor
- `gnomeCalculator` — calculator
- `vial` — keyboard firmware
- `claudeCode`, `amazonQ`, `opencode` — AI tools
- `kdeconnect`, `ohMyPi` — additional tools
</details>

<details>
<summary>Settings & Utilities</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts`, `udiskie` — fonts, auto-mount
- `devTools`, `sessionVariables`, `direnv`, `devShellBootstrap`, `bottles`, `utils` — environment
- `powerMonitor`, `yaziFloat` — scripts
</details>

### Host-Specific Settings

```nix
networking.hostName = "lenovo-yoga-pro-7";
my.noctalia.version = "v5";
my.syncthing.user = "henhal";
services.displayManager.defaultSession = "niri";
my.swayidle.lockCommand = "noctalia";
my.swayidle.session = "niri";
my.rofi.lockCommand = "noctalia";

my.desktop.terminal = "kitty";
my.desktop.browser = "zen-beta";

# Logitech wireless peripherals enabled
# USB-C ethernet adapter kernel module (ax88179_178a)
```

The laptop uses Niri's laptop output variant for its internal display. It has
the `moonlight` client installed for connecting to the workstation over
Tailscale. Its lid policy suspends briefly and then hibernates after two hours.

---

## HP Server

**Type:** Headless server<br>
**Window manager / desktop shell:** None<br>
**Graphics:** No desktop graphics module<br>
**Bootloader:** systemd-boot

### Enabled Features

<details>
<summary>Infrastructure</summary>

- `base` — core NixOS settings
- `bootloader` — systemd-boot
- `networking` — NetworkManager + firewall
- `garbageCollection` — scheduled Nix store cleanup
- `stylix` — Stylix theming (for terminal apps)
- `userHenhal` — user account
</details>

<details>
<summary>Host Services</summary>

- `systemdLogind` — login and power handling
- `docker` — containers
- `syncthing` — file sync
- `laptopServer` — ignore lid-close actions and use the performance governor
</details>

<details>
<summary>Access and Monitoring</summary>

- `sshServer` — OpenSSH
- `tailscale` — VPN
- `monitoringExporter` — Node/Process metrics, custom collectors, and selected journal forwarding over Tailscale
- `monitoringHub` — Prometheus, Telegram Alertmanager, Grafana, Loki, probes, dashboards, and external heartbeats
</details>

<details>
<summary>Hosted Services and Backups</summary>

- `opencloud` — OpenCloud at `cloud.henhal.net`
- `opencloudRadicale` — CalDAV/CardDAV through OpenCloud
- `opencloudKeycloak` — authentication at `auth.henhal.net`
- `opencloudTunnel` — Cloudflare tunnel and private monitoring ingress
- `opencloudConsistentSource` — consistent OpenCloud backup source
- `githubMirror` — GitHub repository mirror
- `hpResticS3` — HP off-site Restic backups
</details>

<details>
<summary>Shell and Tools</summary>

- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `nvim` — Neovim
</details>

<details>
<summary>Settings</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts` — terminal fonts
- `devTools`, `sessionVariables`, `direnv`, `devShellBootstrap`, `utils` — environment
</details>

### Host-Specific Settings

```nix
networking.hostName = "hp-server";
systemd.defaultUnit = "multi-user.target";

# No display manager, desktop session, Noctalia, or desktop applications
# Firecrawl and Hermes are not enabled
```

HP is operated remotely over SSH and Tailscale. It is the monitoring and
service host, not a graphical workstation.

---

## Nix-on-Droid (Galaxy Tab S10 Ultra)

**Type:** Android tablet  
**System:** aarch64-linux via nix-on-droid  
**Shell:** Zsh + powerlevel10k

### Architecture

Unlike the NixOS hosts, nix-on-droid doesn't have a NixOS layer. Home Manager
modules are imported directly via `self.homeModules.*` instead of going through
the `self.nixosModules.*` wrapper.

### Shared Modules (from features/)

`zsh`, `tmux`, `yazi`, `nvim`, `git`, `nerdFonts`, `devTools`,
`sessionVariables`, `direnv`, `utils`

### Android-Specific Modules

- `basicCliTools` — essential CLI tools missing from Termux
- `sshClient` — SSH/mosh profiles to workstation (4 profiles: LAN SSH, LAN
  mosh, Tailscale SSH, Tailscale mosh) with port forwarding for dev servers

### Settings

```nix
system.stateVersion = "24.05";
time.timeZone = "Europe/Oslo";
user.shell = zsh;
terminal.colors = gruvbox-dark-hard;
terminal.font = Hack Nerd Font Mono;

# Git (HM-level options, no osConfig)
my.git.userName = "Henrik";
my.git.userEmail = "henhalvor@gmail.com";

# Custom p10k config with hardcoded hostname
# Termux properties copied via activation script
# Nerd fonts copied to ~/.termux/fonts/
```

### Rebuild

```bash
nix-on-droid switch --flake .#default
```

---

## Feature Comparison Matrix

| Feature | Workstation | Lenovo | HP Server | Android |
|---------|:-----------:|:------:|:---------:|:-------:|
| Hyprland | available | — | — | — |
| Niri | ✅ (default) | ✅ (default) | — | — |
| Sway | available | — | — | — |
| Noctalia v5 | ✅ | ✅ | — | — |
| NVIDIA | ✅ | — | — | — |
| AMD GPU | — | ✅ | — | — |
| Gaming | ✅ | — | — | — |
| Secure Boot | ✅ | — | — | — |
| Sunshine | ✅ | — | — | — |
| Moonlight Qt | ✅ | ✅ | — | — |
| Server stack | — | — | ✅ | — |
| Battery mgmt | — | ✅ | — | — |
| Desktop apps | ✅ | ✅ | — | — |
| AI tools | ✅ | ✅ | — | — |
| Dev tools | ✅ | ✅ | ✅ | ✅ |
| SSH client | — | — | — | ✅ |
| Neovim (nvim) | ✅ | ✅ | ✅ | ✅ |
| Zsh + p10k | ✅ | ✅ | ✅ | ✅ |
