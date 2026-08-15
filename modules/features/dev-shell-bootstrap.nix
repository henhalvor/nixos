# General-purpose development shell bootstrapper.
# Creates a standalone flake and direnv entry point in a project directory.
{
  self,
  ...
}:
{
  flake.nixosModules.devShellBootstrap =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.devShellBootstrap ];
    };

  flake.homeModules.devShellBootstrap =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.dev-init ];
    };

  perSystem =
    { pkgs, ... }:
    let
      allroundPackages = with pkgs; [
        bashInteractive
        coreutils
        curl
        fd
        file
        git
        jq
        ripgrep
        tree
        unzip
        wget
        zip

        # JavaScript / TypeScript
        nodejs_22
        nodePackages.typescript
        pnpm
        yarn

        # Python
        python3
        python3Packages.pip
        python3Packages.virtualenv

        # Rust
        rustc
        cargo
        rustfmt
        clippy
        rust-analyzer

        # Go
        go
        gopls

        # Native builds
        clang
        cmake
        gcc
        gnumake
        openssl
        pkg-config
      ];

      flakeTemplate = pkgs.writeText "allround-dev-flake.nix" ''
        {
          description = "General-purpose development shell";

          inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

          outputs =
            { nixpkgs, ... }:
            let
              systems = [
                "x86_64-linux"
                "aarch64-linux"
                "x86_64-darwin"
                "aarch64-darwin"
              ];
            in
            {
              devShells = nixpkgs.lib.genAttrs systems (system: {
                default =
                  let
                    pkgs = import nixpkgs { inherit system; };
                  in
                  pkgs.mkShell {
                    packages = with pkgs; [
                      bashInteractive
                      coreutils
                      curl
                      fd
                      file
                      git
                      jq
                      ripgrep
                      tree
                      unzip
                      wget
                      zip

                      # JavaScript / TypeScript
                      nodejs_22
                      nodePackages.typescript
                      pnpm
                      yarn

                      # Python
                      python3
                      python3Packages.pip
                      python3Packages.virtualenv

                      # Rust
                      rustc
                      cargo
                      rustfmt
                      clippy
                      rust-analyzer

                      # Go
                      go
                      gopls

                      # Native builds
                      clang
                      cmake
                      gcc
                      gnumake
                      openssl
                      pkg-config
                    ];

                  };
              });
            };
        }
      '';

      devInit = pkgs.writeShellApplication {
        name = "dev-init";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.direnv
          pkgs.git
          pkgs.gnugrep
        ];
        text = ''
          usage() {
            printf '%s\n' "Usage: dev-init [--force] [DIRECTORY]"
            printf '%s\n' "Create an all-round Nix development shell in DIRECTORY."
          }

          force=false
          target=""

          for argument in "$@"; do
            case "$argument" in
              -f|--force)
                force=true
                ;;
              -h|--help)
                usage
                exit 0
                ;;
              --)
                printf '%s\n' "Error: -- must be the final option." >&2
                usage >&2
                exit 2
                ;;
              -*)
                printf 'Error: unknown option: %s\n' "$argument" >&2
                usage >&2
                exit 2
                ;;
              *)
                if [ -n "$target" ]; then
                  printf '%s\n' "Error: only one DIRECTORY may be specified." >&2
                  usage >&2
                  exit 2
                fi
                target="$argument"
                ;;
            esac
          done

          target=''${target:-.}
          if [ ! -d "$target" ]; then
            printf 'Error: directory does not exist: %s\n' "$target" >&2
            exit 1
          fi
          target="$(realpath "$target")"

          if [ "$force" = false ] && { [ -e "$target/flake.nix" ] || [ -e "$target/.envrc" ]; }; then
            printf '%s\n' "Error: flake.nix or .envrc already exists. Use --force to replace them." >&2
            exit 1
          fi

          install -m 0644 ${flakeTemplate} "$target/flake.nix"
          printf '%s\n' 'use flake' > "$target/.envrc"
          chmod 0644 "$target/.envrc"

          gitignore="$target/.gitignore"
          if [ -f "$gitignore" ]; then
            if ! grep -Eq '(^|/)\.direnv/?$' "$gitignore"; then
              if [ -s "$gitignore" ] && [ "$(tail -c 1 "$gitignore")" != $'\n' ]; then
                printf '\n' >> "$gitignore"
              fi
              printf '%s\n' '.direnv' >> "$gitignore"
            fi
          else
            printf '%s\n' '.direnv' > "$gitignore"
          fi

          if git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            # Nix only exposes flakes from tracked Git paths. Intent-to-add keeps
            # the generated file unstaged while making it visible to Nix.
            git -C "$target" add --intent-to-add --force -- flake.nix
          fi

          direnv allow "$target"
          printf 'Initialized %s\n' "$target"
          printf '%s\n' "Starting the development shell. Exit it with Ctrl-D."

          cd "$target"
          shell="''${SHELL##*/}"
          shell="''${shell:-bash}"
          exec direnv exec . "$shell" -i
        '';
      };
    in
    {
      packages.dev-init = devInit;

      devShells.allround = pkgs.mkShell {
        packages = allroundPackages;

        shellHook = ''
          export GOPATH="''${GOPATH:-$PWD/.direnv/go}"
          export CARGO_HOME="''${CARGO_HOME:-$PWD/.direnv/cargo}"
          export PIP_CACHE_DIR="''${PIP_CACHE_DIR:-$PWD/.direnv/pip-cache}"
          export PATH="$GOPATH/bin:$CARGO_HOME/bin:$PATH"
        '';
      };
    };
}
