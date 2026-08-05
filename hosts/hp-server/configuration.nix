# HP Server — headless Hermes, Firecrawl, and synchronization host
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.hpServerConfig =
    { pkgs, ... }:
    {
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

        # Phase 5 services are imported now but intentionally not enabled until
        # the real domain, tunnel UUID, S3 identity, and encrypted SOPS profiles
        # have been created.  See docs/runbooks/phase-5-deployment.md.
        self.nixosModules.opencloud
        self.nixosModules.opencloudKeycloak
        self.nixosModules.opencloudTunnel
        self.nixosModules.opencloudConsistentSource
        self.nixosModules.githubMirror
        self.nixosModules.hpResticS3

        self.nixosModules.userHenhal
      ];

      networking.hostName = "hp-server";
      system.stateVersion = "25.05";
      systemd.defaultUnit = "multi-user.target";

      # Permit the administrative SSH user to import locally-built closures when
      # deploying this host remotely.  henhal is already a wheel user.
      nix.settings.trusted-users = [ "henhal" ];

      # Accept Kitty's TERM value in interactive SSH sessions without installing
      # the graphical terminal emulator on this headless host.
      environment.systemPackages = [ pkgs.kitty.terminfo ];

      my.syncthing = {
        user = "henhal";
        deviceName = "hp-server";
        identitySopsFile = ../../secrets/syncthing/hp-server.yaml;
      };

      my.opencloud = {
        enable = true;
        cloudHost = "cloud.henhal.net";
        authHost = "auth.henhal.net";
      };

      my.opencloudConsistentSource.enable = true;
      my.githubMirror.enable = true;
      my.hpBackup = {
        enable = true;
        # Built-in staged/exported sources must not be repeated here:
        # /run/opencloud-backup/current, /var/lib/opencloud-identity-backup,
        # /var/lib/{vault,shared}-backup, /var/lib/github-mirrors, and
        # /var/lib/hermes-backup. This list is only ordinary HP-local files
        # that may be read live by Restic.
        extraPaths = [
          "/home/henhal/Documents"
          "/home/henhal/Pictures"
          "/home/henhal/Music"
          "/home/henhal/Downloads"
          "/home/henhal/Video"
          "/home/henhal/Desktop"
        ];
      };

      my.opencloudTunnel.tunnelId = "d5383138-72c4-4879-924a-319edc4c20c6";

      my.hermesRuntime.enable = true;
      my.hermesDashboard.enable = true;
      my.hermesWorkspace.enable = true;

      # Driver for the USB-C Ethernet adapter.
      boot.kernelModules = [ "ax88179_178a" ];

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
