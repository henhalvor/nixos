# Feature Reference

Complete list of all feature modules. Each feature is available as
`self.nixosModules.<name>` and (where applicable) `self.homeModules.<name>`.

---

## Core Infrastructure

These are imported by every host.

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `base` | `base.nix` | NixOS-only | Nix settings, locale, timezone, core packages |
| `bootloader` | `bootloader.nix` | NixOS-only | systemd-boot + EFI. Used by lenovo & hp-server |
| `secureBoot` | `secure-boot.nix` | NixOS-only | Lanzaboote secure boot. Used by workstation |
| `networking` | `networking.nix` | NixOS-only | NetworkManager, firewall, mDNS |

## Theme & Styling

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `stylix` | `stylix.nix` | Colocated | Stylix theme with `options.my.theme.*` (wallpaper, colorScheme, polarity) |

## System Services

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `pipewire` | `pipewire.nix` | NixOS-only | Audio via PipeWire + WirePlumber |
| `bluetooth` | `bluetooth.nix` | NixOS-only | Bluetooth + blueman |
| `externalIo` | `external-io.nix` | NixOS-only | Logitech wireless (solaar), USB rules |
| `printer` | `printer.nix` | NixOS-only | CUPS printing |
| `android` | `android.nix` | NixOS-only | ADB + udev rules |
| `nvidiaGraphics` | `nvidia-graphics.nix` | NixOS-only | NVIDIA drivers + VAAPI + power mgmt options |
| `amdGraphics` | `amd-graphics.nix` | NixOS-only | AMD GPU (amdgpu, mesa, VAAPI) |
| `gaming` | `gaming.nix` | NixOS-only | Steam, gamemode, gamescope, mangohud |
| `virtualization` | `virtualization.nix` | NixOS-only | libvirt + virt-manager + QEMU |
| `syncthing` | `syncthing.nix` | NixOS-only | Syncthing with `options.my.syncthing.user` |
| `bootWindows` | `boot-windows.nix` | Colocated | Windows boot desktop entry |
| `systemdLogind` | `systemd-logind.nix` | NixOS-only | Lid/power button handling |
| `minimalBattery` | `minimal-battery.nix` | NixOS-only | TLP + power-profiles-daemon |

## Server Features

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `serverBase` | `server-base.nix` | NixOS-only | fail2ban, auto-upgrades, unattended GC |
| `sshServer` | `ssh-server.nix` | NixOS-only | OpenSSH server (hardened) |
| `tailscale` | `tailscale.nix` | NixOS-only | Tailscale VPN |
| `cockpit` | `cockpit.nix` | NixOS-only | Cockpit web management |
| `serverMonitoring` | `server-monitoring.nix` | NixOS-only | Prometheus + Grafana + node-exporter |
| `laptopServer` | `laptop-server.nix` | NixOS-only | Lid-close ignore, wake-on-LAN |
| `sunshine` | `sunshine.nix` | NixOS-only | Sunshine game streaming with `options.my.sunshine.user` |

## Desktop Foundation

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `desktopCommon` | `desktop-common.nix` | Colocated | XDG portals, dconf, fonts, cursor, GTK/Qt theming, `options.my.desktop.*` |
| `sddm` | `sddm.nix` | NixOS-only | SDDM display manager |
| `gdm` | `gdm.nix` | NixOS-only | GDM display manager |

## Desktop Sessions (Window Managers)

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `hyprland` | `hyprland.nix` | Colocated | Hyprland WM (~520 lines). `options.my.hyprland.*` for monitors, keybinds, lock, launcher, bar |
| `niri` | `niri.nix` | Colocated | Niri scrollable WM. `options.my.niri.*` |
| `sway` | `sway.nix` | Colocated | Sway WM |
| `gnome` | `gnome.nix` | NixOS-only | GNOME desktop environment |

## Desktop Components

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `waybar` | `waybar.nix` | HM-only | Status bar with workspaces, tray, clock |
| `noctalia` | `noctalia.nix` | HM-only | Noctalia shell for Niri |
| `hyprlock` | `hyprlock.nix` | HM-only | Hyprland lock screen |
| `hyprpanel` | `hyprpanel.nix` | HM-only | Hyprland panel (AGS-based) |
| `hypridle` | `hypridle.nix` | HM-only | Hyprland idle daemon |
| `swaylock` | `swaylock.nix` | HM-only | Sway/Niri lock screen |
| `swayidle` | `swayidle.nix` | Colocated | Idle daemon with `options.my.swayidle.*` |
| `mako` | `mako.nix` | HM-only | Notification daemon (Hyprland) |
| `dunst` | `dunst.nix` | HM-only | Notification daemon (alternative) |
| `rofi` | `rofi.nix` | Colocated | App launcher with `options.my.rofi.lockCommand` |
| `clipman` | `clipman.nix` | HM-only | Clipboard manager (wl-clipboard) |
| `cliphist` | `cliphist.nix` | HM-only | Clipboard history |
| `grimblast` | `grimblast.nix` | HM-only | Screenshot tool (Hyprland) |
| `grimScreenshot` | `grim-screenshot.nix` | HM-only | Screenshot tool (Sway/Niri) |
| `waylandApplets` | `wayland-applets.nix` | HM-only | nm-applet, blueman-applet |
| `gammastep` | `gammastep.nix` | HM-only | Blue light filter |
| `wlogout` | `wlogout.nix` | HM-only | Logout menu |

## Applications

### Terminals & Editors

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `kitty` | `kitty.nix` | HM + Package | Kitty terminal. Standalone: `nix run .#kitty` |
| `nvf` | `nvf.nix` | Colocated + Pkg | Neovim via NixVim (~2510 lines). Standalone: `nix run .#nvim` |
| `nvim` | `nvim.nix` | HM-only | Minimal neovim (non-NixVim) |
| `vscode` | `vscode.nix` | HM-only | VS Code with extensions |
| `cursor` | `cursor.nix` | HM-only | Cursor AI editor (~530 lines) |

### Browsers

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `vivaldi` | `vivaldi.nix` | HM-only | Vivaldi browser |
| `zenBrowser` | `zen-browser.nix` | HM-only | Zen browser |
| `brave` | `brave.nix` | HM-only | Brave browser |
| `firefox` | `firefox.nix` | HM-only | Firefox |
| `googleChrome` | `google-chrome.nix` | HM-only | Google Chrome |
| `microsoftEdge` | `microsoft-edge.nix` | HM-only | Microsoft Edge |

### AI Tools

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `claudeCode` | `claude-code.nix` | HM-only | Claude Code CLI |
| `amazonQ` | `amazon-q.nix` | HM-only | Amazon Q developer |
| `aiderChat` | `aider-chat.nix` | HM-only | Aider AI coding |
| `opencode` | `opencode.nix` | HM-only | OpenCode CLI |

### Media & Documents

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `spotify` | `spotify.nix` | HM-only | Spotify (spicetify themed) |
| `mpv` | `mpv.nix` | HM-only | MPV video player |
| `gimp` | `gimp.nix` | HM-only | GIMP image editor |
| `gthumb` | `gthumb.nix` | HM-only | Image viewer |
| `nsxiv` | `nsxiv.nix` | HM-only | Minimal image viewer |
| `zathura` | `zathura.nix` | HM-only | PDF viewer |
| `libreoffice` | `libreoffice.nix` | HM-only | LibreOffice suite |
| `obsidian` | `obsidian.nix` | HM-only | Obsidian notes |

### Utilities

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `nautilus` | `nautilus.nix` | HM-only | GNOME Files |
| `missionCenter` | `mission-center.nix` | HM-only | System monitor |
| `gnomeCalculator` | `gnome-calculator.nix` | HM-only | Calculator |
| `qalculate` | `qalculate.nix` | HM-only | Qalculate (advanced) |
| `bottles` | `bottles.nix` | HM-only | Windows app runner (Wine) |
| `vial` | `vial.nix` | HM-only | Keyboard firmware manager |

## Settings & Environment

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `zsh` | `zsh.nix` | Colocated | Zsh + powerlevel10k + plugins (~176 lines) |
| `tmux` | `tmux.nix` | HM-only | Tmux with catppuccin theme |
| `yazi` | `yazi.nix` | HM-only | Terminal file manager |
| `git` | `git.nix` | Colocated | Git with `options.my.git.*`. osConfig fallback for nix-on-droid |
| `sshConfig` | `ssh-config.nix` | HM-only | SSH client config (server profiles) |
| `secrets` | `secrets.nix` | HM-only | sops-nix secrets + gnome-keyring |
| `nerdFonts` | `nerd-fonts.nix` | HM-only | Hack + JetBrainsMono Nerd Fonts |
| `udiskie` | `udiskie.nix` | HM-only | Auto-mount removable media |
| `devTools` | `dev-tools.nix` | HM-only | CLI dev tools (jq, fd, ripgrep, etc.) |
| `sessionVariables` | `session-variables.nix` | HM-only | XDG dirs, EDITOR, BROWSER, etc. |
| `direnv` | `direnv.nix` | HM-only | direnv + nix-direnv |
| `utils` | `utils.nix` | HM-only | Small utilities (btop, fastfetch, etc.) |

## Scripts & Utilities

| Module | File | Pattern | Description |
|--------|------|---------|-------------|
| `powerMonitor` | `power-monitor.nix` | HM-only | Battery/power monitoring script |
| `yaziFloat` | `yazi-float.nix` | HM-only | Floating yazi terminal script |
| `brightnessExternal` | `brightness-external.nix` | HM-only | DDC/CI external monitor brightness |

## Dev Shells

| Shell | File | Description |
|-------|------|-------------|
| `rust` | `dev-shells/rust.nix` | Rust toolchain via rust-overlay + rust-analyzer |
| `react-native` | `dev-shells/react-native.nix` | React Native + Android SDK + emulator helpers (~590 lines) |
| `sandbox` | `dev-shells/sandbox.nix` | FHS sandbox for prebuilt binaries |

Usage: `nix develop .#<shell-name>`

## Standalone Packages

Available via `nix run .#<name>` or `nix build .#<name>`:

| Package | Description |
|---------|-------------|
| `kitty` | Configured kitty terminal |
| `android-sdk` | Android SDK environment |
| `create-avd` | Create Android Virtual Device |
| `run-emulator` | Launch Android emulator |
| `list-avds` | List available AVDs |
| `emu-buttons` | Emulator button helper |
| `expo-open-all` | Open all Expo dev tools |
| `maestro-studio-desktop` | Maestro Studio .desktop entry |

## Nix-on-Droid Modules

These are specific to the Android tablet configuration:

| Module | File | Description |
|--------|------|-------------|
| `basicCliTools` | `nix-on-droid/basic-cli-tools.nix` | Essential CLI tools for Termux |
| `sshClient` | `nix-on-droid/ssh-client.nix` | SSH/mosh profiles to workstation |

The nix-on-droid config also reuses these shared homeModules: `zsh`, `tmux`,
`yazi`, `nvf`, `git`, `nerdFonts`, `devTools`, `sessionVariables`, `direnv`,
`utils`.
