{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-24-11.url = "github:nixos/nixpkgs/nixos-24.11";
    hyprpanel = {
      url = "github:jas-singhfsu/hyprpanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nvim-nix.url = "github:henhalvor/nvim-nix";
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nixpkgs-24-11,
    hyprpanel,
    zen-browser,
    vscode-server,
    nvf,
    nvim-nix,
    ...
  }: let
    system = "x86_64-linux";

    unstablePkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };

    # Add nixpkgs 24.11 package set
    pkgs24-11 = import nixpkgs-24-11 {
      inherit system;
      config.allowUnfree = true;
    };

    pkgsForNixOS = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        hyprpanel.overlay
        (final: prev: {
          unstable = unstablePkgs;
          pkgs24-11 = pkgs24-11;
        })
      ];
    };

    userHenhal = rec {
      username = "henhal";
      name = "Henrik";
      email = "henhalvor@gmail.com";
      homeDirectory = "/home/${username}";
      term = "kitty";
      browser = "zen-browser";
      stateVersion = "25.05";
    };

    userHenhalDev = rec {
      username = "henhal-dev";
      name = "Henrik";
      email = "henhalvor@gmail.com";
      homeDirectory = "/home/${username}";
      stateVersion = "25.05";
    };

    mkNixosSystem = {
      systemName,
      hostname,
      userSettings,
      windowManager ? "none",
      extraModules ? [],
      extraSpecialArgs ? {},
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs =
          {
            inherit userSettings;
            unstable = unstablePkgs;
            pkgs24-11 = pkgs24-11;
            inherit zen-browser hyprpanel;
            inherit hostname windowManager systemName;
          }
          // extraSpecialArgs;

        modules =
          [
            ./systems/${systemName}/configuration.nix
            {
              nixpkgs.config.allowUnfree = true;
            }
            ({
              config,
              pkgs,
              ...
            }: {
              networking.hostName = hostname;
              time.timeZone = "Europe/Oslo";
              i18n.defaultLocale = "en_US.UTF-8";
              system.stateVersion = userSettings.stateVersion;

              users.users.${userSettings.username} = {
                isNormalUser = true;
                description = userSettings.name;
                initialPassword = "password";
                extraGroups = ["networkmanager" "wheel" "i2c" "docker" "video"];
                shell = pkgsForNixOS.zsh;
                home = userSettings.homeDirectory;
                packages = with pkgsForNixOS; [
                  ethtool
                ];
              };

              # nixpkgs.pkgs = pkgsForNixOS; -- DEPRECATED IN RECENT VERSION OF HOME MANAGER
            })
            home-manager.nixosModules.home-manager
            {
              home-manager.extraSpecialArgs = {
                inherit system userSettings zen-browser hyprpanel nvf nvim-nix;
                unstable = unstablePkgs;
                pkgs24-11 = pkgs24-11;
                inherit hostname windowManager systemName;
                inputs = {
                  inherit hyprpanel zen-browser nvf nvim-nix;
                };
              };
              home-manager.useGlobalPkgs = false; # NEEDS TO BE FALSE IN RECENT VERSION OF HOME MANAGER
              home-manager.useUserPackages = true;
              home-manager.users.${userSettings.username} =
                import ./users/${userSettings.username}/home.nix;
            }
          ]
          ++ extraModules;
      };
  in {
    nixosConfigurations = {
      lenovo-yoga-pro-7 = mkNixosSystem {
        systemName = "lenovo-yoga-pro-7";
        hostname = "yoga-pro-7";
        userSettings = userHenhal;
        windowManager = "sway";
      };

      desktop = mkNixosSystem {
        systemName = "desktop";
        hostname = "desktop-pc";
        userSettings = userHenhal;
        windowManager = "hyprland";
      };

      hp-server = mkNixosSystem {
        systemName = "hp-server";
        hostname = "hp-server";
        userSettings = userHenhalDev;
        windowManager = "none";
        extraModules = [
          vscode-server.nixosModules.default
          ({
            config,
            pkgs,
            ...
          }: {services.vscode-server.enable = true;})
        ];
      };
    };

    homeConfigurations = {
      henhal = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            hyprpanel.overlay
            (final: prev: {unstable = unstablePkgs;})
          ];
        };
        modules = [./users/henhal/home.nix];
        extraSpecialArgs = {
          inherit system nvf nvim-nix;
          userSettings = userHenhal;
          unstable = unstablePkgs;
          pkgs24-11 = pkgs24-11;
          inherit zen-browser hyprpanel;
          inputs = {
            inherit hyprpanel zen-browser nvf nvim-nix;
          };
          windowManager = "sway";
        };
      };

      henhal-dev = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            hyprpanel.overlay
            (final: prev: {unstable = unstablePkgs;})
          ];
        };
        modules = [./users/henhal-dev/home.nix];
        extraSpecialArgs = {
          inherit system;
          userSettings = userHenhalDev;
          unstable = unstablePkgs;
          pkgs24-11 = pkgs24-11;
          inherit zen-browser hyprpanel;
          inputs = {
            inherit hyprpanel zen-browser;
          };
          windowManager = "none";
        };
      };
    };
  };
}
