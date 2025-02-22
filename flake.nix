{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
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
  };

  outputs = { self, nixpkgs, home-manager, hyprpanel, zen-browser, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      # ---- SYSTEM SETTINGS ---- #
      systemSettings = {
        system = system; # Use the 'system' from the let binding
        hostname = "nixos"; # hostname
        timezone = "Europe/Oslo"; # select timezone
        locale = "en_US.UTF-8"; # select locale
        isEfiSystem = true;
      };

      # ----- USER SETTINGS ----- #
      userSettings = rec {
        username = "henhal"; # username
        name = "Henrik"; # name/identifier
        email = "henhalvor@gmail.com"; # email (used for certain configurations)
        dotfilesDir = "${pkgs.lib.getHomeDir username}/.dotfiles"; # absolute path of the local repo
        # wm = "hyprland"; # Selected window manager or desktop environment
        # wmType = if (wm == "hyprland" || wm == "sway") then "wayland" else "x11";
        # browser = "firefox"; # Default browser
        term = "kitty"; # Default terminal
        browser = "zen-browser";
      system = "x86_64-linux";
        # editor = "vim"; # Default editor
      };
    in
    {
      nixosConfigurations = {
        nixos = lib.nixosSystem {
          inherit system;
          modules = [
            ./nixos/configuration.nix
            home-manager.nixosModules.home-manager
          ];
          specialArgs = {
            # pass config variables from above
            inherit systemSettings;
            inherit userSettings;
            inherit zen-browser;
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
            ];
          };
          modules = [ ./home/home.nix ];
          extraSpecialArgs = {
            inherit system;
            inherit systemSettings userSettings;
            inherit zen-browser;
            inputs = {
              inherit hyprpanel;
            };
          };
        };
      };
    };
}
