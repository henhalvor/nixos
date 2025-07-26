{
  # ▶️ Usage
  #
  # From the ~/dev/sandbox directory:
  #
  # nix develop
  #
  # Or, add an alias:
  #
  # alias sandbox='nix develop ~/dev/sandbox'
  #
  # Now you can just run:
  #
  # sandbox
  #
  # From anywhere.

  description = "Catch-all FHS sandbox for bleeding-edge dev tooling";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.buildFHSUserEnv {
          name = "bleeding-edge-sandbox";

          # Tools available inside the sandbox:
          # - Basic Unix tools: bash, coreutils, curl, unzip, git
          # - Compilers: gcc, g++, clang
          # - Languages: Go, Rust, Node.js (with npm), Python 3
          # - Helpers: jq for JSON, wget for downloads
          #
          # Customize `targetPkgs` to add more tools as needed.
          targetPkgs = pkgs:
            with pkgs; [
              bash
              coreutils
              git
              curl
              wget
              unzip
              jq

              # Compilers and build tools
              gcc
              gnumake
              clang
              cmake
              pkg-config

              # Languages
              go
              rustc
              nodejs_20
              python3
            ];

          # Environment setup:
          # - GOPATH: for Go tooling
          # - Add ~/.local/bin to PATH: for user-installed binaries
          #
          # You can install bleeding-edge tools using go install, cargo install, npm, etc.
          # These will persist in your $HOME even after exiting the sandbox.
          runScript = ''
            export GOPATH=$HOME/go
            export PATH=$GOPATH/bin:$HOME/.local/bin:$PATH
            echo "🛠  Entered bleeding-edge dev sandbox"
            echo "📦  Go tools: $GOPATH/bin"
            echo "📂  Custom tools: ~/.local/bin"
            echo
            bash
          '';
        };
      });
}
