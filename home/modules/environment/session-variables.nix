{ config, pkgs, ... }:

{
  # Configure all package managers to use our organized directory structure
  home.sessionVariables = {
    # Base directory for all development tools
    DEV_HOME = "$HOME/.local/dev";

    # Tool-specific home directories
    NPM_HOME = "$HOME/.local/dev/npm";
    NPM_CONFIG_PREFIX = "$HOME/.local/dev/npm/global";
    CARGO_HOME = "$HOME/.local/dev/cargo";
    RUSTUP_HOME = "$HOME/.local/dev/rustup";
    PYTHONUSERBASE = "$HOME/.local/dev/python";
    GOPATH = "$HOME/.local/dev/go";

    # Combine all PATH additions in a single definition
    PATH = builtins.concatStringsSep ":" [
      "$HOME/.local/dev/npm/global/bin"
      "$HOME/.local/dev/cargo/bin"
      "$HOME/.local/dev/python/bin"
      "$HOME/.local/dev/go/bin"
      "$PATH"
    ];
  };
}
