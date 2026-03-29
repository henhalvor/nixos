# Host Configurations

Detailed breakdown of what each host includes and its specific settings.

---

## Workstation

**Type:** Desktop workstation  
**Primary DE:** Hyprland  
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
<summary>System Services (11)</summary>

- `pipewire` — audio
- `bluetooth` — Bluetooth + blueman
- `externalIo` — Logitech wireless (solaar), USB rules
- `printer` — CUPS
- `android` — ADB + udev
- `nvidiaGraphics` — NVIDIA drivers + VAAPI
- `gaming` — Steam, gamemode, gamescope
- `virtualization` — libvirt + QEMU
- `syncthing` — file sync
- `bootWindows` — Windows boot entry
- `sunshine` — game streaming
</details>

<details>
<summary>Server & Connectivity (2)</summary>

- `sshServer` — OpenSSH
- `tailscale` — VPN
</details>

<details>
<summary>Desktop (11)</summary>

- `desktopCommon` — XDG, fonts, GTK/Qt
- `sddm` — display manager
- `hyprland` — primary WM
- `sway` — secondary WM
- `niri` — tertiary WM
- `waybar` — status bar
- `hyprlock` — lock screen
- `mako` — notifications
- `rofi` — app launcher
- `clipman` — clipboard
- `grimblast` — screenshots
- `waylandApplets` — nm-applet, blueman
- `gammastep` — blue light filter
</details>

<details>
<summary>Applications (26)</summary>

- `kitty` — terminal
- `nvf` — Neovim (NixVim)
- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `vivaldi`, `zenBrowser`, `brave`, `firefox`, `googleChrome`, `microsoftEdge` — browsers
- `obsidian` — notes
- `spotify` — music
- `gimp`, `gthumb`, `mpv`, `zathura` — media
- `libreoffice` — office
- `nautilus` — file manager (GUI)
- `missionCenter` — system monitor
- `gnomeCalculator` — calculator
- `vial` — keyboard firmware
- `claudeCode`, `amazonQ`, `opencode` — AI tools
</details>

<details>
<summary>Settings & Utilities (13)</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts`, `udiskie` — fonts, auto-mount
- `devTools`, `sessionVariables`, `direnv`, `bottles`, `utils` — environment
- `powerMonitor`, `yaziFloat`, `brightnessExternal` — scripts
</details>

### Host-Specific Settings

```nix
networking.hostName = "workstation";
my.syncthing.user = "henhal";
my.sunshine.user = "henhal";

# Dual monitor setup
my.hyprland.monitors = [
  "HDMI-A-1,1920x1080@144,0x0,1"
  "DP-1,2560x1440@144,1920x0,1"
];
my.hyprland.lockCommand = "hyprlock";
my.hyprland.launcher = "rofi";
my.hyprland.bar = "waybar";
my.rofi.lockCommand = "hyprlock";
my.desktop.terminal = "kitty";
my.desktop.browser = "vivaldi";

# NVIDIA power management disabled
# Logitech wireless peripherals enabled
# Custom firmware packages (linux_firmware, sof-firmware)
```

---

## Lenovo Yoga Pro 7

**Type:** Laptop  
**Primary DE:** Niri (noctalia shell)  
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
<summary>System Services (10)</summary>

- `pipewire` — audio
- `bluetooth` — Bluetooth + blueman
- `externalIo` — Logitech wireless, USB rules
- `printer` — CUPS
- `android` — ADB
- `systemdLogind` — lid/power button handling
- `virtualization` — libvirt + QEMU
- `syncthing` — file sync
- `amdGraphics` — AMD GPU drivers
- `minimalBattery` — TLP power management
</details>

<details>
<summary>Server & Connectivity (2)</summary>

- `sshServer` — OpenSSH
- `tailscale` — VPN
</details>

<details>
<summary>Desktop (12)</summary>

- `desktopCommon` — XDG, fonts, GTK/Qt
- `sddm` — display manager
- `hyprland` — secondary WM
- `niri` — primary WM
- `sway` — tertiary WM
- `gnome` — GNOME fallback
- `noctalia` — Niri shell/panel
- `swaylock` — lock screen
- `swayidle` — idle daemon
- `rofi` — app launcher
- `clipman` — clipboard
- `grimScreenshot` — screenshots
- `waylandApplets` — nm-applet, blueman
- `gammastep` — blue light filter
</details>

<details>
<summary>Applications (26)</summary>

- `kitty` — terminal
- `nvf` — Neovim
- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `vivaldi`, `zenBrowser`, `brave`, `firefox`, `googleChrome`, `microsoftEdge` — browsers
- `obsidian` — notes
- `spotify` — music
- `gimp`, `gthumb`, `mpv`, `zathura` — media
- `libreoffice` — office
- `nautilus` — file manager (GUI)
- `missionCenter` — system monitor
- `gnomeCalculator` — calculator
- `vial` — keyboard firmware
- `claudeCode`, `amazonQ`, `opencode` — AI tools
</details>

<details>
<summary>Settings & Utilities (12)</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts`, `udiskie` — fonts, auto-mount
- `devTools`, `sessionVariables`, `direnv`, `bottles`, `utils` — environment
- `powerMonitor`, `yaziFloat` — scripts
</details>

### Host-Specific Settings

```nix
networking.hostName = "lenovo-yoga-pro-7";
my.syncthing.user = "henhal";

# Single high-DPI display
my.hyprland.monitors = [ "eDP-1,2560x1600@60,0x0,1.6" ];
my.hyprland.lockCommand = "hyprlock";
my.hyprland.launcher = "rofi";

my.swayidle.lockCommand = "swaylock";
my.swayidle.session = "niri";
my.rofi.lockCommand = "swaylock";

my.desktop.terminal = "kitty";
my.desktop.browser = "vivaldi";

# Logitech wireless peripherals enabled
# USB-C ethernet adapter kernel module (ax88179_178a)
```

---

## HP Server

**Type:** Headless server  
**Primary DE:** None  
**GPU:** NVIDIA (compute)  
**Bootloader:** systemd-boot

### Enabled Features

<details>
<summary>Infrastructure (5)</summary>

- `base` — core NixOS settings
- `bootloader` — systemd-boot
- `networking` — NetworkManager + firewall
- `stylix` — Stylix theming (for terminal apps)
- `userHenhal` — user account
</details>

<details>
<summary>System Services (3)</summary>

- `pipewire` — audio (for remote streaming)
- `bluetooth` — Bluetooth
- `nvidiaGraphics` — NVIDIA drivers
</details>

<details>
<summary>Server Features (5)</summary>

- `serverBase` — fail2ban, auto-upgrades, GC
- `sshServer` — OpenSSH
- `tailscale` — VPN
- `serverMonitoring` — Prometheus + Grafana
- `laptopServer` — lid-close ignore, wake-on-LAN
</details>

<details>
<summary>Remote Development (1)</summary>

- `vscode-server` — VS Code remote server (via `inputs.vscode-server`)
</details>

<details>
<summary>Shell & Tools (4)</summary>

- `zsh` — shell
- `tmux` — multiplexer
- `yazi` — file manager
- `nvf` — Neovim
</details>

<details>
<summary>Settings (8)</summary>

- `git`, `sshConfig`, `secrets` — dev config
- `nerdFonts` — terminal fonts
- `devTools`, `sessionVariables`, `direnv`, `utils` — environment
</details>

### Host-Specific Settings

```nix
networking.hostName = "hp-server";
programs.dconf.enable = true;
services.vscode-server.enable = true;

# No desktop environment
# No my.desktop.* settings
```

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

`zsh`, `tmux`, `yazi`, `nvf`, `git`, `nerdFonts`, `devTools`,
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
| Hyprland | ✅ (primary) | ✅ | — | — |
| Niri | ✅ | ✅ (primary) | — | — |
| Sway | ✅ | ✅ | — | — |
| GNOME | — | ✅ | — | — |
| NVIDIA | ✅ | — | ✅ | — |
| AMD GPU | — | ✅ | — | — |
| Gaming | ✅ | — | — | — |
| Secure Boot | ✅ | — | — | — |
| Sunshine | ✅ | — | — | — |
| Server stack | — | — | ✅ | — |
| VS Code Server | — | — | ✅ | — |
| Battery mgmt | — | ✅ | — | — |
| Desktop apps | ✅ | ✅ | — | — |
| AI tools | ✅ | ✅ | — | — |
| Dev tools | ✅ | ✅ | ✅ | ✅ |
| SSH client | — | — | — | ✅ |
| Neovim (nvf) | ✅ | ✅ | ✅ | ✅ |
| Zsh + p10k | ✅ | ✅ | ✅ | ✅ |
