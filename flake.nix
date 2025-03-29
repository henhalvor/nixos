{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel = {
      url = "github:jas-singhfsu/hyprpanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, hyprpanel
    , zen-browser, vscode-server, ... }:
    let
      # Common system architecture
      system = "x86_64-linux";

      # Import unstable packages (used in overlays and potentially directly)
      unstablePkgs = import nixpkgs-unstable {
        inherit system;
        config = { allowUnfree = true; };
      };

      # Create pkgs set with overlays for NixOS configurations
      # This pkgs set will be inherited by Home Manager within NixOS modules
      pkgsForNixOS = import nixpkgs {
        inherit system;
        config.allowUnfree = true; # Allow unfree packages system-wide if needed
        overlays = [
          hyprpanel.overlay
          # Add overlay to expose unstable packages under 'unstable' attribute
          (final: prev: { unstable = unstablePkgs; })
          # Add other overlays here if needed globally for NixOS builds
        ];
      };

      lib = nixpkgs.lib; # Convenience access to lib functions

      #
      #
      # ----- Define settings for EACH user -----
      #
      #

      # User 'henhal' - assumed to be the primary user for most systems based on original flake
      userHenhal = rec {
        username = "henhal";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = "/home/${username}"; # Standard home directory path
        term = "kitty";
        browser = "zen-browser"; # Defined via zen-browser input
        stateVersion = "24.11";
        # Add any other settings specific to henhal that home.nix might need
      };

      # Add other user settings here if needed, e.g.:
      # userAdmin = rec { username = "admin"; ... };

      #
      #
      #
      #
      #

      # ----- Helper function to generate a NixOS configuration -----
      mkNixosSystem = { systemName
        , # Name matching directory in ./systems/ (e.g., "lenovo-yoga-pro-7")
        hostname, # The desired hostname for the system (e.g., "yoga-pro-7")
        userSettings, # The user settings block (e.g., userHenhal)
        windowManager ? "none", # Default WM if not specified
        extraModules ? [ ], # List of extra modules to include
        extraSpecialArgs ? { } # Extra specialArgs for NixOS modules
        }:
        lib.nixosSystem {
          inherit system; # Use the global system architecture

          # Pass common inputs and potentially system-specific args to all modules
          specialArgs = {
            inherit userSettings;
            unstable = unstablePkgs;
            inherit zen-browser hyprpanel;
            inherit hostname windowManager systemName;
          } // extraSpecialArgs;

          modules = [
            # Import the machine-specific hardware/system configuration
            ./systems/${systemName}/configuration.nix

            # Global defaults and settings
            ({ config, pkgs, ... }: {
              networking.hostName = hostname;
              time.timeZone =
                "Europe/Oslo"; # Current location detected: Bergen, Norway
              i18n.defaultLocale = "en_US.UTF-8";
              system.stateVersion = userSettings.stateVersion;

              # Define the primary user for this system configuration
              users.users.${userSettings.username} = {
                isNormalUser = true;
                description = userSettings.name;
                extraGroups =
                  [ "networkmanager" "wheel" "i2c" "docker" "video" ];
                shell = pkgsForNixOS.zsh; # Use pkgs set defined for NixOS
                home = userSettings.homeDirectory;
                packages = with pkgsForNixOS;
                  [
                    #  thunderbird
                  ];
              };

              # Ensure the pkgs passed to modules includes overlays
              nixpkgs.pkgs = pkgsForNixOS;
            })

            # Integrate Home Manager as a NixOS module
            home-manager.nixosModules.home-manager
            {
              # Pass arguments accessible inside home.nix via 'specialArgs'
              home-manager.extraSpecialArgs = {
                inherit system userSettings zen-browser hyprpanel;
                unstable =
                  unstablePkgs; # Explicitly pass unstablePkgs AS unstable
                inherit hostname windowManager systemName; # Pass system context
                inputs = {
                  inherit hyprpanel zen-browser;
                }; # Pass specific inputs
              };
              home-manager.useGlobalPkgs =
                true; # Use pkgs from NixOS (includes overlays)
              home-manager.useUserPackages = true;
              # Configure HM for the specific user for this system
              home-manager.users.${userSettings.username} =
                import ./users/${userSettings.username}/home.nix;
            }

          ] ++ extraModules;
        };

    in { # The final outputs attribute set

      #
      #
      # ----- Define the NixOS Configurations for Each Host -----
      #
      #

      nixosConfigurations = {
        lenovo-yoga-pro-7 = mkNixosSystem {
          systemName = "lenovo-yoga-pro-7";
          hostname = "yoga-pro-7";
          userSettings = userHenhal;
          windowManager = "sway";
        };

        desktop = mkNixosSystem {
          systemName = "desktop"; # Assuming ./systems/desktop/ exists
          hostname = "desktop-pc";
          userSettings = userHenhal;
          windowManager = "hyprland";
        };

        hp-server = mkNixosSystem {
          systemName = "hp-server";
          hostname = "hp-server";
          userSettings =
            userHenhal; # Or userAdmin if defined and preferred for server
          windowManager = "hyprland";
          extraModules = [
            vscode-server.nixosModules.default
            ({ config, pkgs, ... }: { services.vscode-server.enable = true; })
          ];
        };
        # Add other hosts here...
      };

      #
      #
      #
      #
      #

      #
      #
      # ----- Standalone Home Manager Configurations -----
      #
      #

      # Allows updating user environment independently via:
      #   home-manager switch --flake .#<username>
      homeConfigurations = {

        # Standalone config for user 'henhal'
        henhal = home-manager.lib.homeManagerConfiguration {
          # Define pkgs specifically for this standalone build
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree =
              true; # Allow unfree packages if needed by home.nix
            overlays = [
              hyprpanel.overlay
              # Add unstable overlay for standalone build if needed directly in home.nix pkgs
              (final: prev: { unstable = unstablePkgs; })
            ];
          };
          modules =
            [ ./users/henhal/home.nix ]; # Path to the home configuration
          # Pass arguments needed by home.nix when built standalone
          extraSpecialArgs = {
            inherit system;
            userSettings = userHenhal; # Pass the correct user settings block
            unstable = unstablePkgs; # Pass unstable package set
            inherit zen-browser hyprpanel; # Pass inputs needed by home.nix
            inputs = {
              inherit hyprpanel zen-browser;
            }; # Pass inputs structured if needed
            # Note: System context like hostname, windowManager is typically NOT passed here,
            # unless home.nix has logic specifically for standalone mode based on them.
            windowManager = "sway";
          };
        };

        # Add standalone config for 'admin' if you defined userAdmin above
        # admin = home-manager.lib.homeManagerConfiguration { ... };

      }; # End of homeConfigurations

    }; # End of outputs
}
