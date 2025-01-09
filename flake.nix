{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

outputs = { self, nixpkgs, home-manager, ... }: 
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    lib = nixpkgs.lib;

 # ---- SYSTEM SETTINGS ---- #
      systemSettings = {
        system = "x86_64-linux"; # system arch
        hostname = "nixos"; # hostname
        profile = "personal"; # select a profile defined from my profiles directory
        timezone = "Europe/Oslo"; # select timezone
        locale = "en_US.UTF-8"; # select locale
      };

      # ----- USER SETTINGS ----- #
      userSettings = rec {
        username = "henhal"; # username
        name = "Henrik"; # name/identifier
        email = "henhalvor@gmail.com"; # email (used for certain configurations)
        dotfilesDir = "~/.dotfiles"; # absolute path of the local repo
        wm = "hyprland"; # Selected window manager or desktop environment; must select one in both ./user/wm/ and ./system/wm/
        # window manager type (hyprland or x11) translator
        wmType = if ((wm == "hyprland") || (wm == "sway")) then "wayland" else "x11";
        browser = "firefox"; # Default browser; must select one from ./user/app/browser/
        term = "kitty"; # Default terminal command;
        editor = "vim"; # Default editor;
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
        extraSpecialArgs = {
            # pass config variables from above
            inherit systemSettings;
            inherit userSettings;
          };
      };
    };
    homeConfigurations = {
      henhal = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/home.nix ];

        extraSpecialArgs = {
            # pass config variables from above
            inherit systemSettings;
            inherit userSettings;
          };
      };
    };
  };
}

  
