# HP Server — headless Hermes, Firecrawl, and synchronization host
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.hpServerConfig = {pkgs, ...}: {
    imports = [
      self.nixosModules.hpServerHardware
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      self.nixosModules.systemdLogind
      self.nixosModules.docker
      self.nixosModules.syncthing
      self.nixosModules.laptopServer
      self.nixosModules.sshServer
      self.nixosModules.tailscale

      self.nixosModules.nvim
      self.nixosModules.zsh
      self.nixosModules.tmux
      self.nixosModules.yazi
      self.nixosModules.git
      self.nixosModules.sshConfig
      self.nixosModules.secrets
      self.nixosModules.devTools
      self.nixosModules.sessionVariables
      self.nixosModules.direnv
      self.nixosModules.utils

      self.nixosModules.firecrawl
      self.nixosModules.hermesRuntime
      self.nixosModules.hermesDashboard
      self.nixosModules.hermesWorkspace

      self.nixosModules.userHenhal
    ];

    networking.hostName = "hp-server";
    system.stateVersion = "25.05";
    systemd.defaultUnit = "multi-user.target";

    my.syncthing = {
      user = "henhal";
      deviceName = "hp-server";
      identitySopsFile = ../../secrets/syncthing/hp-server.yaml;
    };

    my.hermesRuntime.enable = true;
    my.hermesDashboard.enable = true;
    my.hermesWorkspace.enable = true;

    # Driver for the USB-C Ethernet adapter.
    boot.kernelModules = ["ax88179_178a"];

    home-manager = {
      useGlobalPkgs = false;
      useUserPackages = true;
      backupFileExtension = "hm-backup";
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
    };
  };
}
