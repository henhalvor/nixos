# Neovim (basic) — standalone neovim with lazy.nvim (currently unused, nvf preferred)
# Source: home/modules/applications/nvim.nix
# Template B2: HM-only
{ self, inputs, ... }: {
  flake.nixosModules.nvim = { ... }: {
    home-manager.sharedModules = [ self.homeModules.nvim ];
  };

  flake.homeModules.nvim = { config, pkgs, lib, pkgs-unstable, ... }: {
    imports = [ inputs.nvim-nix.homeManagerModules.default ];

    home.packages = [ pkgs-unstable.neovim ];

    # Writable directories for Neovim
    home.activation.createNeovimDirs = ''
      mkdir -p ${config.home.homeDirectory}/.local/state/nvim
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
    '';

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    home.file.".local/state/nvim/.keep".text = "";

    # Symlink nvim-nix config after home-manager writes
    home.activation.nvimSymlink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Running Neovim symlink script..."
      export NVIM_NIX_CLONE_DIR="${config.home.homeDirectory}/.nvim-nix"
      export SYMLINK_SCRIPT="$NVIM_NIX_CLONE_DIR/symlink.sh"

      if [ -f "$SYMLINK_SCRIPT" ]; then
        echo "Executing Neovim symlink script: $SYMLINK_SCRIPT"
        $DRY_RUN_CMD chmod +x "$SYMLINK_SCRIPT"
        $DRY_RUN_CMD "$SYMLINK_SCRIPT"
      else
        echo "Warning: Neovim symlink script not found at $SYMLINK_SCRIPT." >&2
      fi
    '';
  };
}
