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

      # TODO: Phase 4+ features
      # self.nixosModules.sshServer
      # self.nixosModules.tailscale
      # self.nixosModules.sunshine
      # self.nixosModules.desktopCommon
      # self.nixosModules.hyprland

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "workstation";
    system.stateVersion = "25.05";

    # Syncthing user
    my.syncthing.user = "henhal";

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
      };
    };
  };
}
