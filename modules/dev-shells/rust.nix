# Rust development shell
# Source: shells/rust/flake.nix
# Uses rust-overlay for latest stable Rust toolchain
{ inputs, ... }: {
  perSystem = { system, ... }: let
    pkgs = import inputs.nixpkgs-unstable {
      inherit system;
      overlays = [ inputs.rust-overlay.overlays.default ];
    };
  in {
    devShells.rust = pkgs.mkShell {
      packages = with pkgs; [
        (rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
          ];
        })
        openssl
        pkg-config
      ];
    };
  };
}
