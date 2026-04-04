# Session Variables — editor, dev tool paths
# Source: home/modules/environment/session-variables.nix
{ self, ... }: {
  flake.nixosModules.sessionVariables = { ... }: {
    home-manager.sharedModules = [ self.homeModules.sessionVariables ];
  };

  flake.homeModules.sessionVariables = { lib, ... }: {
    home.sessionVariables = {
      # Default editor
      EDITOR = lib.mkForce "nvim";
      SUDO_EDITOR = lib.mkForce "nvim";
      VISUAL = lib.mkForce "nvim";

      # Base directory for all development tools
      DEV_HOME = "$HOME/.local/dev";

      # Tool-specific home directories
      NPM_HOME = "$HOME/.local/dev/npm";
      NPM_CONFIG_PREFIX = "$HOME/.local/dev/npm/global";
      CARGO_HOME = "$HOME/.local/dev/cargo";
      RUSTUP_HOME = "$HOME/.local/dev/rustup";
      PYTHONUSERBASE = "$HOME/.local/dev/python";
      GOPATH = "$HOME/.local/dev/go";

      # Combined PATH for all dev tools
      PATH = builtins.concatStringsSep ":" [
        "$HOME/.local/dev/npm/global/bin"
        "$HOME/.local/dev/cargo/bin"
        "$HOME/.local/dev/python/bin"
        "$HOME/.local/dev/go/bin"
        "$PATH"
      ];
    };
  };
}
