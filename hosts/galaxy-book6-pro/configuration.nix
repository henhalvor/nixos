# Samsung Galaxy Book6 Pro — system configuration
# Daily driver: workstation apps and tooling with the Lenovo's laptop wiring.
# See docs/plans/GALAXY-BOOK6-PRO-SETUP.md for the install procedure.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.galaxyBook6ProConfig =
    {
      pkgs,
      pkgs-unstable,
      config,
      lib,
      ...
    }:
    {
      imports = [
        # Hardware
        self.nixosModules.galaxyBook6ProHardware

        # Core
        self.nixosModules.base
        self.nixosModules.bootloader
        self.nixosModules.networking
        self.nixosModules.firewall
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
        self.nixosModules.docker
        # TODO(install): enable once the Syncthing identity exists, see the
        # my.syncthing block below.
        # self.nixosModules.syncthing
        self.nixosModules.intelGraphics
        self.nixosModules.laptopPower
        self.nixosModules.garbageCollection

        # Server/connectivity (Phase 4)
        self.nixosModules.sshServer
        self.nixosModules.tailscale
        self.nixosModules.monitoringExporter
        self.nixosModules.moonlight

        # Desktop foundation (Phase 5)
        self.nixosModules.desktopCommon
        self.nixosModules.sddm

        # Desktop sessions (Phase 6)
        self.nixosModules.niri

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
        self.nixosModules.freecad
        self.nixosModules.nvim
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
        self.nixosModules.t3code
        self.nixosModules.opencloudDesktop
        self.nixosModules.spotify
        self.nixosModules.gimp
        self.nixosModules.gthumb
        self.nixosModules.mpv
        self.nixosModules.zathura
        self.nixosModules.onlyoffice
        self.nixosModules.nautilus
        self.nixosModules.missionCenter
        self.nixosModules.gnomeCalculator
        self.nixosModules.vial
        self.nixosModules.kdeconnect
        self.nixosModules.codecrafters-cli

        # Settings & Environment (Phase 9)
        self.nixosModules.git
        self.nixosModules.sshConfig
        self.nixosModules.secrets
        self.nixosModules.nerdFonts
        self.nixosModules.udiskie
        self.nixosModules.devTools
        self.nixosModules.sessionVariables
        self.nixosModules.direnv
        self.nixosModules.devShellBootstrap
        self.nixosModules.userlandPackages
        self.nixosModules.bottles
        self.nixosModules.utils

        # Scripts & Utilities (Phase 10)
        self.nixosModules.powerMonitor
        self.nixosModules.yaziFloat

        # User
        self.nixosModules.userHenhal
      ];

      # Host identity
      networking.hostName = "galaxy-book6-pro";
      system.stateVersion = "25.11";

      # Panther Lake (Core Ultra 7 356H) support keeps improving upstream, so
      # track the newest mainline kernel from unstable rather than 25.11's.
      boot.kernelPackages = pkgs-unstable.linuxPackages_latest;

      # Panel Replay Selective Update (the default PSR mode on this OLED panel)
      # draws thin full-width tearing bands; the kernel logs "Selective fetch
      # area calculation failed in pipe A". Disabling PSR at runtime via
      # i915_edp_psr_debug=0x1 removed it (2026-11-23). Costs some idle power.
      # Retest on newer kernels by removing this and checking the band is gone.
      boot.kernelParams = [ "xe.enable_psr=0" ];

      my.noctalia.version = "v5";

      # Idle and lid timings (seconds). See modules/features/desktop/swayidle.nix.
      #   AC:      lock 5 min, screen off 10 min, never suspend; lid = lock.
      #   Battery: same, plus suspend 20 min after screen off (30 min idle),
      #            and 20 min after lid close. Suspend hibernates after 2h.
      my.swayidle = {
        lockCommand = "noctalia";
        session = "niri";
        lockTimeout = 300;
        screenOffTimeout = 600;
        suspendTimeout = 600 + 1200;
        lidSuspendDelay = 1200;
      };

      my.rofi.lockCommand = "noctalia";

      # TODO(install): generate the Syncthing identity, add the device to
      # syncthing.nix and .sops.yaml, then re-enable the import above.
      # my.syncthing = {
      #   user = "henhal";
      #   deviceName = "galaxy-book6-pro";
      #   identitySopsFile = ../../secrets/syncthing/galaxy-book6-pro.yaml;
      # };

      my.userlandPackages = {
        enable = true;
        enableGui = true;
      };

      my.monitoring.exporter = {
        enable = true;
        hubHost = "hp-server-1.tail37a5eb.ts.net";
        enableBattery = true;
        # TODO(install): enable together with Syncthing.
        # enableSyncthingMetrics = true;
        # extraUnits = [
        #   "syncthing.service"
        # ];
      };

      # Default session
      services.displayManager.defaultSession = "niri";

      # The CS42L45 codec (built-in mic, speaker routing) has no UCM profile in
      # 25.11's alsa-ucm-conf 1.2.14; 1.2.16+ adds cs42l45 and cs42l45-dmic.
      # Without it PipeWire falls back to a stereo-out-only profile with no mic.
      # The new UCM files use syntax 8, which alsa-lib 1.2.14 rejects, so
      # PipeWire and WirePlumber are rebuilt (stable toolchain) against alsa-lib
      # and alsa-ucm-conf 1.2.16 from unstable. The rest of the system keeps the
      # stable alsa-lib. Drop this once the stable channel ships >= 1.2.16.
      services.pipewire =
        let
          alsaLibNew =
            (pkgs.alsa-lib.override { alsa-ucm-conf = pkgs-unstable.alsa-ucm-conf; }).overrideAttrs
              (_: {
                inherit (pkgs-unstable.alsa-lib) version src;
                # The 1.2.14 CVE backport is already upstream in 1.2.16.
                patches = pkgs-unstable.alsa-lib.patches;
              });
          pipewireNew = pkgs.pipewire.override { alsa-lib = alsaLibNew; };
        in
        {
          package = pipewireNew;
          wireplumber.package = pkgs.wireplumber.override { pipewire = pipewireNew; };
        };

      # Lid close only locks (Niri turns the panel off). On battery the
      # swayidle lid hook suspends after my.swayidle.lidSuspendDelay.
      # Every suspend is suspend-then-hibernate: s2idle, then hibernate after
      # two hours. Resume device is set in hardware.nix.
      services.logind.settings.Login.HandleLidSwitch = lib.mkForce "lock";
      systemd.sleep.extraConfig = ''
        HibernateDelaySec=2h
      '';

      # Logitech wireless peripherals
      hardware.logitech.wireless.enable = true;
      hardware.logitech.wireless.enableGraphical = true;

      # Drivers for usb-c to ethernet adapter
      boot.kernelModules = [ "ax88179_178a" ];

      # Increase file watch limit
      boot.kernel.sysctl."fs.inotify.max_user_watches" = 524288;

      # Gnome keyring (for secrets management)
      services.gnome.gnome-keyring.enable = true;
      environment.sessionVariables.GSM_SKIP_SSH_AGENT_WORKAROUND = "1";

      # Home-manager settings
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

        # Per-host desktop preference overrides
        users.henhal.my.desktop = {
          terminal = "kitty";
          browser = "zen-beta";
        };
      };
    };
}
