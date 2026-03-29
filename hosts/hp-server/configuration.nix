# HP Server — system configuration
# Source: systems/hp-server/configuration.nix + hosts/hp-server.nix
{self, inputs, ...}: {
  flake.nixosModules.hpServerConfig = {pkgs, ...}: {
    imports = [
      # Hardware
      self.nixosModules.hpServerHardware

      # Core
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme (Phase 2) — terminal theming
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # System services (Phase 3)
      self.nixosModules.pipewire
      self.nixosModules.bluetooth
      self.nixosModules.nvidiaGraphics
      self.nixosModules.laptopServer

      # Server features (Phase 4)
      self.nixosModules.serverBase
      self.nixosModules.sshServer
      self.nixosModules.tailscale
      self.nixosModules.serverMonitoring
      # self.nixosModules.cockpit  # Currently unused

      # VS Code Remote Server
      inputs.vscode-server.nixosModules.default

      # Shell & tools (Phase 8)
      self.nixosModules.zsh
      self.nixosModules.tmux
      self.nixosModules.yazi
      self.nixosModules.nvf

      # Settings & Environment (Phase 9)
      self.nixosModules.git
      self.nixosModules.sshConfig
      self.nixosModules.secrets
      self.nixosModules.nerdFonts
      self.nixosModules.devTools
      self.nixosModules.sessionVariables
      self.nixosModules.direnv
      self.nixosModules.utils

      # User
      self.nixosModules.userHenhal
    ];

    # Host identity
    networking.hostName = "hp-server";
    system.stateVersion = "25.05";

    programs.dconf.enable = true;

    # VS Code Remote Server (for remote development)
    services.vscode-server.enable = true;

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
    };
  };
}
