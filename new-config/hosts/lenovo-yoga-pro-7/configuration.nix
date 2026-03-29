# Lenovo Yoga Pro 7 — system configuration
# Source: systems/lenovo-yoga-pro-7/configuration.nix + hosts/lenovo-yoga-pro-7.nix
{self, inputs, ...}: {
  flake.nixosModules.lenovoYogaPro7Config = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      # Hardware
      self.nixosModules.lenovoYogaPro7Hardware

      # Core
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme (Phase 2)
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # System services (Phase 3)
      self.nixosModules.pipewire
      self.nixosModules.bluetooth
      self.nixosModules.externalIo
      self.nixosModules.printer
      self.nixosModules.android
      self.nixosModules.systemdLogind
      self.nixosModules.virtualization
      self.nixosModules.syncthing
      self.nixosModules.amdGraphics
      self.nixosModules.minimalBattery

      # Server/connectivity (Phase 4)
      self.nixosModules.sshServer
      self.nixosModules.tailscale

      # Desktop foundation (Phase 5)
      self.nixosModules.desktopCommon
      self.nixosModules.sddm

      # Desktop sessions (Phase 6)
      self.nixosModules.hyprland
      self.nixosModules.niri
      self.nixosModules.sway
      self.nixosModules.gnome

      # Desktop components (Phase 7)
      self.nixosModules.noctalia
      self.nixosModules.swaylock
      self.nixosModules.swayidle
      self.nixosModules.rofi
      self.nixosModules.clipman
      self.nixosModules.grimScreenshot
      self.nixosModules.waylandApplets
      self.nixosModules.gammastep

      # Applications (Phase 8)
      self.nixosModules.kitty
      self.nixosModules.nvf
      self.nixosModules.zsh
      self.nixosModules.tmux
      self.nixosModules.yazi
      self.nixosModules.vivaldi
      self.nixosModules.zenBrowser
      self.nixosModules.brave
      self.nixosModules.firefox
      self.nixosModules.googleChrome
      self.nixosModules.microsoftEdge
      self.nixosModules.obsidian
      self.nixosModules.spotify
      self.nixosModules.gimp
      self.nixosModules.gthumb
      self.nixosModules.mpv
      self.nixosModules.zathura
      self.nixosModules.libreoffice
      self.nixosModules.nautilus
      self.nixosModules.missionCenter
      self.nixosModules.gnomeCalculator
      self.nixosModules.vial
      self.nixosModules.claudeCode
      self.nixosModules.amazonQ
      self.nixosModules.opencode

      # Settings & Environment (Phase 9)
      self.nixosModules.git
      self.nixosModules.sshConfig
      self.nixosModules.secrets
      self.nixosModules.nerdFonts
      self.nixosModules.udiskie
      self.nixosModules.devTools
      self.nixosModules.sessionVariables
      self.nixosModules.direnv
      self.nixosModules.bottles
      self.nixosModules.utils

      # Scripts & Utilities (Phase 10)
      self.nixosModules.powerMonitor
      self.nixosModules.yaziFloat

      # TODO: Phase 11+ features

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "lenovo-yoga-pro-7";
    system.stateVersion = "25.05";

    # Syncthing user
    my.syncthing.user = "henhal";

    # Hyprland host-specific config
    my.hyprland = {
      monitors = [
        "eDP-1,2560x1600@60,0x0,1.6"
      ];
      workspaceRules = [
        "2, monitor:DP-9"
        "3, monitor:DP-9"
        "1, monitor:DP-8"
        "1, monitor:eDP-1"
        "2, monitor:eDP-1"
        "3, monitor:eDP-1"
      ];
      lockCommand = "hyprlock";
      launcher = "rofi";
    };

    # Swayidle config (niri session, swaylock)
    my.swayidle = {
      lockCommand = "swaylock";
      session = "niri";
    };

    # Rofi lock command
    my.rofi.lockCommand = "swaylock";

    # Laptop-specific hardware
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Fixes battery percentage in hyprpanel
    services.upower.enable = true;

    # Drivers for usb-c to ethernet adapter
    boot.kernelModules = ["ax88179_178a"];

    # Home-manager settings
    home-manager = {
      useGlobalPkgs = false;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {
        inherit inputs self;
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        pkgs24-11 = import inputs.nixpkgs-24-11 {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };

      # Per-host desktop preference overrides
      users.henhal.my.desktop = {
        terminal = "kitty";
        browser = "vivaldi";
      };
    };
  };
}
