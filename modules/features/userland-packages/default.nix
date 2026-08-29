# Mutable userland infrastructure and its read-only-by-default facade.
{ self, ... }:
{
  flake.nixosModules.userlandPackages =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.userlandPackages;
      installerType = lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "HTTPS URL of the reviewed upstream installer.";
          };
          interpreter = lib.mkOption {
            type = lib.types.enum [ "bash" "sh" ];
            default = "bash";
            description = "Interpreter used for the downloaded installer file.";
          };
          arguments = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Arguments passed to the installer after the downloaded file.";
          };
          allowedHosts = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Allowed installer download and redirect hosts.";
          };
        };
      };
      adapterType = lib.types.submodule (
        { ... }:
        {
          options = {
            displayName = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Human-readable name shown by userland.";
            };

            commands = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
              default = { };
              description = ''
                argv arrays for version, available, install, update, remove,
                and health checks. Commands never run through a shell.
              '';
            };

            installer = lib.mkOption {
              type = lib.types.nullOr installerType;
              default = null;
              description = "Optional reviewed bootstrap installer.";
            };

            expectedExecutables = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Executables that must resolve after installation.";
            };

            requirements = {
              packages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Nix-owned runtime and build prerequisites for this adapter.";
              };
              chromiumSandbox = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Provide the NixOS Chromium setuid sandbox to Electron applications.";
              };
              binBash = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Provide /bin/bash for upstream software that hardcodes the FHS path.";
              };
              atSpi = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable the AT-SPI accessibility bus for semantic desktop inspection.";
              };
            };
          };
        }
      );
      defaultAdapters = {
        hermes = {
          displayName = "Hermes Agent";
          installer = {
            url = "https://hermes-agent.nousresearch.com/install.sh";
            interpreter = "bash";
            allowedHosts = [
              "hermes-agent.nousresearch.com"
              "raw.githubusercontent.com"
            ];
          };
          commands = {
            version = [ "hermes" "--version" ];
            update = [ "hermes" "update" ];
            health = [ "hermes" "doctor" ];
          };
          expectedExecutables = [ "hermes" ];
          requirements = {
            packages = with pkgs; [
              gcc
              gnumake
            ];
            chromiumSandbox = true;
            binBash = true;
            atSpi = true;
          };
        };
      };
    in
    {
      options.my.userlandPackages = {
        enable = lib.mkEnableOption "mutable userland package facade";

        enableGui = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable user-scoped Flatpak and AppImage support.";
        };

        upstreamAdapters = lib.mkOption {
          type = lib.types.attrsOf adapterType;
          default = { };
          description = "Reviewed user-scoped upstream self-updater adapters.";
        };
      };

      config = lib.mkMerge [
        {
          my.userlandPackages.upstreamAdapters = lib.mkDefault defaultAdapters;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = config.users.users ? henhal;
              message = "my.userlandPackages requires the henhal user to exist.";
            }
          ];

          home-manager.sharedModules = [ self.homeModules.userlandPackages ];

          programs.appimage = lib.mkIf cfg.enableGui {
            enable = true;
            binfmt = true;
          };

          services.flatpak.enable = lib.mkIf cfg.enableGui true;
          environment.systemPackages =
            lib.optional cfg.enableGui pkgs.gearlever
            ++ lib.concatMap (adapter: adapter.requirements.packages) (lib.attrValues cfg.upstreamAdapters);
          security.chromiumSuidSandbox.enable = lib.any (
            adapter: adapter.requirements.chromiumSandbox
          ) (lib.attrValues cfg.upstreamAdapters);
          services.gnome.at-spi2-core.enable = lib.any (
            adapter: adapter.requirements.atSpi
          ) (lib.attrValues cfg.upstreamAdapters);

          # Hermes and cua-driver both execute their Computer Use installers
          # through the literal /bin/bash path. Bash on PATH is insufficient,
          # so NixOS owns this compatibility link instead of leaving a manual
          # root-created symlink outside the system configuration.
          systemd.tmpfiles.rules = lib.optional (lib.any (
            adapter: adapter.requirements.binBash
          ) (lib.attrValues cfg.upstreamAdapters)) "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash";
        })
      ];
    };

  flake.homeModules.userlandPackages =
    {
      config,
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      cfg = lib.attrByPath [ "my" "userlandPackages" ] {
        enable = false;
        enableGui = false;
        upstreamAdapters = { };
      } osConfig;

      runtimeAdapters = lib.mapAttrs (_: adapter: {
        inherit (adapter) displayName commands installer expectedExecutables;
      }) cfg.upstreamAdapters;
      adaptersFile = pkgs.writeText "userland-upstream-adapters.json" (builtins.toJSON runtimeAdapters);
      chromiumSandboxPath = "/run/wrappers/bin/${pkgs.chromium.sandbox.passthru.sandboxExecutableName}";

      userland = pkgs.writeShellApplication {
        name = "userland";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.bash
          pkgs.curl
          pkgs.git
          pkgs.gnutar
          pkgs.gzip
          pkgs.mise
          pkgs.unzip
          pkgs.xz
        ]
          ++ lib.optional cfg.enableGui pkgs.flatpak
          ++ lib.optional cfg.enableGui pkgs.gearlever
          ++ lib.concatMap (adapter: adapter.requirements.packages) (lib.attrValues cfg.upstreamAdapters);
        text = ''
          ${lib.optionalString cfg.enableGui "export USERLAND_GEARLEVER_VERSION=${lib.escapeShellArg pkgs.gearlever.version}"}
          exec ${pkgs.python3}/bin/python3 ${./userland.py} \
            --adapters-file ${lib.escapeShellArg (toString adaptersFile)} "$@"
        '';
      };
    in
    lib.mkIf cfg.enable {
      home.packages = [ userland ];

      programs.mise = {
        enable = true;
        package = pkgs.mise;
        enableZshIntegration = true;
      };

      home.sessionVariables = lib.mkIf (lib.any (
        adapter: adapter.requirements.chromiumSandbox
      ) (lib.attrValues cfg.upstreamAdapters)) {
        CHROME_DEVEL_SANDBOX = chromiumSandboxPath;
      };

      home.activation = lib.mkIf cfg.enableGui {
        userlandFlathub = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -x ${pkgs.flatpak}/bin/flatpak ]; then
            ${pkgs.flatpak}/bin/flatpak --user remote-add --if-not-exists \
              flathub https://flathub.org/repo/flathub.flatpakrepo \
              || echo "userland: unable to configure the Flathub user remote" >&2
          fi
        '';
      };
    };

  perSystem =
    { pkgs, ... }:
    {
      checks.userland-packages = pkgs.runCommand "userland-package-tests" {
        nativeBuildInputs = [ pkgs.python3 ];
      } ''
        mkdir -p tests/fixtures
        cp ${./userland.py} userland.py
        cp ${./tests/test_userland.py} tests/test_userland.py
        cp ${./tests/fixtures}/* tests/fixtures/
        PYTHONDONTWRITEBYTECODE=1 python3 tests/test_userland.py
        touch "$out"
      '';
    };
}
