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
      # This ensures it uses the same nixpkgs as your system
      inputs.nixpkgs.follows = "nixpkgs";
    };
zen-browser.url = "github:0xc000022070/zen-browser-flake";
vscode-server.url = "github:nix-community/nixos-vscode-server";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, hyprpanel, zen-browser, vscode-server, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Add reference to unstable packages with unfree allowed
      unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      lib = nixpkgs.lib;

      # ---- SYSTEM SETTINGS ---- #
      systemSettings = {
        system = system; # Use the 'system' from the let binding
        hostname = "nixos-server"; # hostname
        timezone = "Europe/Oslo"; # select timezone
        locale = "en_US.UTF-8"; # select locale
        stateVersion = "24.11";
        #
        # Has to be one of the systems defined in ./systems/
        #
        # lenovo-yoga-pro-7
        # desktop
        # hp-server
        #
        systemName = "hp-server";
      };

      # ----- USER SETTINGS ----- #
      userSettings = rec {
        #
        # Has to be one of the users defined in ./users/
        #
        # henhal
        #
        username = "henhal";
        name = "Henrik"; # name/identifier
        email = "henhalvor@gmail.com";
        dotfilesDir = "${pkgs.lib.getHomeDir username}/.dotfiles"; # absolute path of the local repo
        term = "kitty";
        browser = "zen-browser";
        system = "x86_64-linux";
        stateVersion = "24.11";
      };
    in
    {
      nixosConfigurations = {
        nixos = lib.nixosSystem {
          inherit system;
          modules = [
            ./systems/${systemSettings.systemName}/configuration.nix
            home-manager.nixosModules.home-manager
            
          ] ++ (if systemSettings.systemName == "hp-server" then [
            # VS Code server fix (only for server systems)
            vscode-server.nixosModules.default
            ({ config, pkgs, ... }: {
              services.vscode-server.enable = true;
            })
          ] else []);
          specialArgs = {
            # pass config variables from above
            inherit systemSettings;
            inherit userSettings;
            inherit zen-browser;
            # Pass unstable packages
            inherit unstable;
          };
        };
      };

      homeConfigurations = {
        henhal = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            inherit zen-browser;
            overlays = [
              hyprpanel.overlay
               # Add overlay to expose unstable packages
              (final: prev: {
                unstable = unstable;
              })
            ];
          };
         modules = [ ./users/${userSettings.username}/home.nix ];
          extraSpecialArgs = {
            inherit system;
            inherit systemSettings userSettings;
            inherit zen-browser;
            inherit unstable;
            inputs = {
              inherit hyprpanel;
            };
          };
        };
      };
    };
}
