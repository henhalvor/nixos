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
          };
        }
      );
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

      config = lib.mkIf cfg.enable {
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
        environment.systemPackages = lib.mkIf cfg.enableGui [ pkgs.gearlever ];
      };
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

      adaptersFile = pkgs.writeText "userland-upstream-adapters.json" (
        builtins.toJSON cfg.upstreamAdapters
      );

      userland = pkgs.writeShellApplication {
        name = "userland";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.mise
        ]
          ++ lib.optional cfg.enableGui pkgs.flatpak
          ++ lib.optional cfg.enableGui pkgs.gearlever;
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
