{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
  };

outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }: 
  let
    system = "x86_64-linux";
    # Create an overlay to make unstable packages available
    overlay-unstable = final: prev: {
      unstable = nixpkgs-unstable.legacyPackages.${system};
    };
    # Configure pkgs with the overlay
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ overlay-unstable ];
    };
  in
  {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.henhal = import ./home/home.nix;
            # Make the overlay available to all modules
            nixpkgs.overlays = [ overlay-unstable ];
          }
        ];
      };
    };
  };

  # outputs = { self, nixpkgs, home-manager, ... }: 
  # let
  #   system = "x86_64-linux";
  #   pkgs = nixpkgs.legacyPackages.${system};
  # in
  # {
  #   nixosConfigurations = {
  #     nixos = nixpkgs.lib.nixosSystem {
  #       inherit system;
  #       modules = [
  #         ./nixos/configuration.nix
  #         home-manager.nixosModules.home-manager
  #         {
  #           home-manager.useGlobalPkgs = true;
  #           home-manager.useUserPackages = true;
  #           home-manager.users.henhal = import ./home/home.nix;
  #         }
  #       ];
  #     };
  #   };
  # };
}
