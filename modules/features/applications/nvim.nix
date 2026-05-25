# Neovim configured with native Lua and nix-wrapper-modules.
{
  self,
  inputs,
  ...
}: let
  mkNvimPackage = {
    pkgs,
  }:
    inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs;
      imports = [self.wrapperModules.neovimConfig];
    };
in {
  flake.wrappers.neovimConfig = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    pkgs-unstable = import inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    pkgs24-11 = import inputs.nixpkgs-24-11 {
      inherit system;
      config.allowUnfree = true;
    };

    neocodeium = config.nvim-lib.mkPlugin "neocodeium" (
      pkgs24-11.fetchFromGitHub {
        owner = "monkoose";
        repo = "neocodeium";
        rev = "v1.16.3";
        sha256 = "sha256-UemmcgQbdTDYYh8BCCjHgr/wQ8M7OH0ef6MBMHfOJv8=";
      }
    );

    codecompanion = config.nvim-lib.mkPlugin "codecompanion.nvim" (
      pkgs24-11.fetchFromGitHub {
        owner = "olimorris";
        repo = "codecompanion.nvim";
        rev = "v18.4.1";
        sha256 = "sha256-f3Fin46KtArc5XxA2whagloFxPev/bThCTK+52fzQoM=";
      }
    );
  in {
    imports = [wlib.wrapperModules.neovim];

    config.package = pkgs-unstable.neovim-unwrapped;
    config.settings.config_directory = ./nvim/config;
    config.settings.aliases = ["vim"];

    config.info.dap = {
      vscodeJsDebug = "${pkgs.vscode-js-debug}";
      codelldb = "${lib.getExe' pkgs.lldb "lldb-dap"}";
    };

    config.specs.core = with pkgs.vimPlugins; [
      nvim-lspconfig
      blink-cmp
      pkgs-unstable.vimPlugins.blink-compat
      luasnip
      friendly-snippets
      snacks-nvim
      mini-nvim
      conform-nvim
      nvim-lint
      fidget-nvim
      flash-nvim
      nvim-web-devicons
      vim-tmux-navigator
      barbecue-nvim
      nvim-osc52
      tabout-nvim
      nvim-ts-context-commentstring
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      nvim-ts-autotag
      render-markdown-nvim
      rustaceanvim
      pkgs-unstable.vimPlugins.codediff-nvim
      plenary-nvim
      neocodeium
      codecompanion
    ];

    config.specs.harpoon = {
      pname = "harpoon";
      lazy = true;
      data = pkgs.vimPlugins.harpoon2;
    };
    config.specs.grug-far = {
      pname = "grug-far.nvim";
      lazy = true;
      data = pkgs.vimPlugins.grug-far-nvim;
    };
    config.specs.persistence = {
      pname = "persistence.nvim";
      lazy = true;
      data = pkgs.vimPlugins.persistence-nvim;
    };
    config.specs.yazi = {
      pname = "yazi.nvim";
      lazy = true;
      data = pkgs.vimPlugins.yazi-nvim;
    };
    config.specs.garbage-day = {
      pname = "garbage-day.nvim";
      lazy = true;
      data = config.nvim-lib.mkPlugin "garbage-day.nvim" inputs.garbage-day-nvim;
    };
    config.specs.nvim-dap = {
      pname = "nvim-dap";
      lazy = true;
      data = pkgs.vimPlugins.nvim-dap;
    };
    config.specs.nvim-dap-ui = {
      pname = "nvim-dap-ui";
      lazy = true;
      data = pkgs.vimPlugins.nvim-dap-ui;
    };
    config.specs.nvim-nio = {
      pname = "nvim-nio";
      lazy = true;
      data = pkgs.vimPlugins.nvim-nio;
    };
    config.specs.nvim-dap-virtual-text = {
      pname = "nvim-dap-virtual-text";
      lazy = true;
      data = pkgs.vimPlugins.nvim-dap-virtual-text;
    };
    config.specs.nvim-dap-vscode-js = {
      pname = "nvim-dap-vscode-js";
      lazy = true;
      data = pkgs.vimPlugins.nvim-dap-vscode-js;
    };

    config.specs.themes = with pkgs.vimPlugins; [
      catppuccin-nvim
      rose-pine
      gruvbox-nvim
      gruvbox-baby
      gruvbox-material
      tokyonight-nvim
      kanagawa-nvim
      nord-nvim
      nightfox-nvim
      onedark-nvim
      dracula-nvim
      everforest
      sonokai
      oxocarbon-nvim
      melange-nvim
      cyberdream-nvim
      vscode-nvim
      github-nvim-theme
    ];

    config.extraPackages = with pkgs; [
      ripgrep
      fd
      git
      lazygit
      nodejs
      prettierd
      nodePackages.eslint_d
      stylua
      black
      nixfmt-rfc-style
      rustfmt
      rust-analyzer
      lua-language-server
      nil
      nodePackages.typescript-language-server
      tailwindcss-language-server
      nodePackages.vscode-langservers-extracted
      nodePackages.yaml-language-server
      nodePackages.svelte-language-server
      gopls
      pyright
      clang-tools
      vscode-js-debug
      lldb
    ];
  };

  perSystem = {
    pkgs,
    ...
  }: {
    packages.nvim = mkNvimPackage {
      inherit pkgs;
    };
  };

  flake.nixosModules.nvim = {...}: {
    home-manager.sharedModules = [self.homeModules.nvim];
  };

  flake.homeModules.nvim = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
  in {
    home.packages = [self.packages.${system}.nvim];

    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    home.file.".local/state/nvim/.keep".text = "";
  };
}
