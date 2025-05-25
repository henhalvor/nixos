{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # Core development tools
    lazygit
    lazydocker
    ripgrep
    tree-sitter
    unzip
    neofetch

    # Node.js ecosystem
    nodejs_20

    # Rust ecosystem
    rustc
    cargo

    # Python ecosystem
    python311
    python311Packages.pip

    # Go ecosystem
    go

    # Build tools and utilities
    gcc
    gnumake
    cmake
  ];

  # Ensure npm config directory exists
  home.activation = {
    createDevDirectories = ''
      mkdir -p ${config.home.homeDirectory}/.local/dev/{npm/{global,cache,config},cargo,rustup,python,go}
      mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
    '';
  };

  # Configure npm to use our directory structure
  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.local/dev/npm/global
    cache=${config.home.homeDirectory}/.local/dev/npm/cache
    init-module=${config.home.homeDirectory}/.local/dev/npm/config/npm-init.js
  '';

  # Configure pip to use our directory structure
  home.file.".config/pip/pip.conf".text = ''
    [global]
    user = true
    prefix = ${config.home.homeDirectory}/.local/dev/python
  '';
}
