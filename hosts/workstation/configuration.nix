# Workstation — system configuration
# Source: systems/workstation/configuration.nix + hosts/workstation.nix
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.workstationConfig = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      # Hardware
      self.nixosModules.workstationHardware

      # Core
      self.nixosModules.base
      self.nixosModules.secureBoot
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
      self.nixosModules.nvidiaGraphics
      self.nixosModules.gaming
      self.nixosModules.virtualization
      self.nixosModules.syncthing
      self.nixosModules.bootWindows

      # Server/connectivity (Phase 4)
      self.nixosModules.sshServer
      self.nixosModules.tailscale
      self.nixosModules.sunshine

      # Desktop foundation (Phase 5)
      self.nixosModules.desktopCommon
      self.nixosModules.sddm

      # Desktop sessions (Phase 6)
      self.nixosModules.hyprland
      self.nixosModules.sway
      self.nixosModules.niri

      # Desktop components (Phase 7)
      self.nixosModules.waybar
      self.nixosModules.hyprlock
      self.nixosModules.mako
      self.nixosModules.rofi
      self.nixosModules.clipman
      self.nixosModules.grimblast
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
      self.nixosModules.brightnessExternal

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "workstation";
    system.stateVersion = "25.05";

    # Syncthing user
    my.syncthing.user = "henhal";

    # Sunshine user
    my.sunshine.user = "henhal";

    # Hyprland host-specific config
    my.hyprland = {
      monitors = [
        "HDMI-A-1,1920x1080@144,0x0,1,transform,1"
        "DP-1,2560x1440@144,1080x0,1"
      ];
      workspaceRules = [
        "1, monitor:HDMI-A-1"
        "3, monitor:HDMI-A-1"
        "2, monitor:DP-1"
        "4, monitor:DP-1"
        "5, monitor:DP-1"
        "6, monitor:DP-1"
        "10, monitor:HEADLESS-1"
      ];
      lockCommand = "hyprlock";
      launcher = "rofi";
      bar = "waybar";
    };

    # Rofi lock command
    my.rofi.lockCommand = "hyprlock";

    # Workstation-specific NVIDIA overrides (desktop GPU doesn't need power saving)
    hardware.nvidia.powerManagement.enable = lib.mkForce false;
    boot.kernelParams = [
      "modprobe.blacklist=amdgpu"
      "mem_sleep_default=s2idle"
    ];

    # Workstation-specific hardware
    hardware.logitech.wireless.enable = true;
    hardware.logitech.wireless.enableGraphical = true;
    hardware.enableAllFirmware = true;
    hardware.firmware = [pkgs.linux-firmware];
    hardware.enableRedistributableFirmware = true;

    # Increase file watch limit
    boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

    # Gnome keyring (for secrets management)
    security.pam.services.login.enableGnomeKeyring = true;
    services.gnome.gnome-keyring.enable = true;
    environment.sessionVariables.GSM_SKIP_SSH_AGENT_WORKAROUND = "1";

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
        browser = "zen-beta";
      };
    };
  };
}
