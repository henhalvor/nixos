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
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nvf = {
      url = "github:notashelf/nvf/v0.8";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nvim-nix.url = "github:henhalvor/nvim-nix";
    stylix = {
      url = "github:nix-community/stylix/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nixpkgs-24-11,
    zen-browser,
    vscode-server,
    nvf,
    nvim-nix,
    stylix,
    lanzaboote,
    nix-on-droid,
    ...
  } @ inputs: let
    # Host configs (pure data)
    hosts = {
      workstation = import ./hosts/workstation.nix;
      lenovo-yoga-pro-7 = import ./hosts/lenovo-yoga-pro-7.nix;
      hp-server = import ./hosts/hp-server.nix;
    };

    # User configs
    users = {
      henhal = rec {
        username = "henhal";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = "/home/${username}";
        term = "kitty";
        browser = "vivaldi";
        stateVersion = "25.05";
        stylixTheme = {
          scheme = "gruvbox-dark-hard";
          wallpaper = "starry-sky.png";
        };
      };
      henhal-dev = rec {
        username = "henhal-dev";
        name = "Henrik";
        email = "henhalvor@gmail.com";
        homeDirectory = "/home/${username}";
        stateVersion = "25.05";
      };
    };

    # System builder
    mkSystem = import ./lib/mk-nixos-system.nix inputs;
  in {
    nixosConfigurations = {
      workstation = mkSystem {
        hostConfig = hosts.workstation;
        userSettings = users.henhal;
      };

      lenovo-yoga-pro-7 = mkSystem {
        hostConfig = hosts.lenovo-yoga-pro-7;
        userSettings = users.henhal;
      };

      # Should be deleted eventually
      desktop = mkSystem {
        hostConfig = hosts.workstation;  # Using workstation config for now
        userSettings = users.henhal;
      };

      hp-server = mkSystem {
        hostConfig = hosts.hp-server;
        userSettings = users.henhal-dev;
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

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      modules = [ ./nix-on-droid/default.nix ];

      extraSpecialArgs = {
        inherit inputs;
      };

      pkgs = import nixpkgs {
        system = "aarch64-linux";
        config.allowUnfree = true;
        overlays = [ nix-on-droid.overlays.default ];
      };

      home-manager-path = home-manager.outPath;
    };
  };
}
