{
  description = "NixOS configuration";

  nixConfig = {
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-24-11.url = "github:nixos/nixpkgs/nixos-24.11";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    vscode-server.url = "github:nix-community/nixos-vscode-server";

    hermes-agent.url = "github:NousResearch/hermes-agent/c9e8d82ef42970b31d683b9c3e8319b2d54d8b08";

    garbage-day-nvim = {
      url = "github:Zeioth/garbage-day.nvim";
      flake = false;
    };

    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Final stable Quickshell-based v4 release. Keep this pinned so that the
    # fallback remains reproducible while v5 is under active development.
    noctalia-v4 = {
      url = "github:noctalia-dev/noctalia-shell/v4.7.7";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
      inputs.noctalia-qs.follows = "noctalia-v4-qs";
    };

    noctalia-v4-qs = {
      url = "github:noctalia-dev/noctalia-qs/1c0710cd7c9f1483bb6dbf5e69023da97136646d";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # The cachix branch follows the newest v5 commit successfully built by CI.
    # Do not override its nixpkgs input: doing so would disable cache hits.
    noctalia-v5.url = "github:noctalia-dev/noctalia/cachix";

    # Dev shell inputs
    rust-overlay.url = "https://flakehub.com/f/oxalica/rust-overlay/*.tar.gz";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs?rev=91170262072e4a5c09db45b44d72e71752b6204d";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.wrapper-modules.flakeModules.default
        (inputs.import-tree ./hosts)
        (inputs.import-tree ./modules)
      ];
    };
}
