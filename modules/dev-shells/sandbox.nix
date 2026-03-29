# Catch-all FHS sandbox for bleeding-edge dev tooling
# Source: shells/sandboxes/catchall-sandbox.nix
# Usage: nix develop .#sandbox
{ ... }: {
  perSystem = { pkgs, ... }: {
    devShells.sandbox = pkgs.buildFHSEnv {
      name = "bleeding-edge-sandbox";

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
  };
}
