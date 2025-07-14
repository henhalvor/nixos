{ config, lib, unstable, nvim-nix, ... }: {
  #
  # Neovim configuration
  #

  home.packages = [ unstable.neovim ];

  # Create writable directories for Neovim
  home.activation.createNeovimDirs = ''
    mkdir -p ${config.home.homeDirectory}/.local/state/nvim
    mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
  '';

  # Set Neovim as the default editor
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Ensure state directory exists for Lazy
  home.file.".local/state/nvim/.keep".text = "";

  # Import the Neovim Nix Config module
  imports = [ nvim-nix.homeManagerModules.default ];

  # Run the symlink script after the home directory is written
  home.activation.nvimSymlink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      echo "Running Neovim symlink script..."
    # Define the path to your cloned nvim-nix repository directory
    # Ensure this path is correct for your setup.
    # This assumes you clone nvim-nix to ~/.nvim-nix
    export NVIM_NIX_CLONE_DIR="${config.home.homeDirectory}/.nvim-nix"
    export SYMLINK_SCRIPT="$NVIM_NIX_CLONE_DIR/symlink.sh"

    if [ -f "$SYMLINK_SCRIPT" ]; then
      echo "Executing Neovim symlink script: $SYMLINK_SCRIPT"
      $DRY_RUN_CMD chmod +x "$SYMLINK_SCRIPT"
      $DRY_RUN_CMD "$SYMLINK_SCRIPT"
    else
      echo "Warning: Neovim symlink script not found at $SYMLINK_SCRIPT. Please ensure $NVIM_NIX_CLONE_DIR is cloned and contains symlink.sh." >&2
    fi
  '';
}
