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

      # TODO: Phase 6+ features

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "lenovo-yoga-pro-7";
    system.stateVersion = "25.05";

    # Syncthing user
    my.syncthing.user = "henhal";

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
      };
    };
  };
}
