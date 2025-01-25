{
  description = "Rust development environment";

  # Define our inputs (dependencies) for the flake
  inputs = {
    # nixpkgs is our base package set
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    # flake-utils provides helper functions for working with flakes
    flake-utils.url = "github:numtide/flake-utils";
    
    # rust-overlay provides different Rust toolchain versions
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      # These 'follows' statements prevent duplicate dependencies
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Apply the Rust overlay to our package set
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # You have two options for specifying the Rust toolchain:
        
        # Option 1: Use a specific version directly
        rustToolchain = pkgs.rust-bin.stable.latest.default;
        
        # Option 2: Use a rust-toolchain.toml file (uncomment to use)
        # rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Our Rust toolchain
            rustToolchain
            
            # Additional tools that are useful for Rust development
            rust-analyzer    # IDE support
            clippy          # Linting
            rustfmt         # Code formatting
            
            # Build essentials
            pkg-config
            openssl
            
            # Optional: Additional development tools
            cargo-edit      # Adds `cargo add` subcommand
            cargo-watch     # Watches your project for changes

            # Direnv
            direnv
          ];

          # Shell hook for additional environment setup
          shellHook = ''
            echo "Rust Development Environment"
            echo "-------------------------"
            rustc --version
            cargo --version
            # Export the PATH so Neovim can find the tools
            export PATH="${pkgs.rust-analyzer}/bin:$PATH"
            export PATH="${pkgs.rustfmt}/bin:$PATH"
            export PATH="${pkgs.clippy}/bin:$PATH"
            echo
            echo "Ready for development! 🦀"
          '';
        };
      }
    );
}
