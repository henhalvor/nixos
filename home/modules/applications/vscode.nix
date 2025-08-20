{ config, pkgs, lib, unstable, ... }: {
  programs.vscode = {
    enable = true;
    package = unstable.vscode;

    profiles.default = {
      extensions = with pkgs.vscode-extensions;
        [
          # TypeScript Development
          # ms-vscode.vscode-typescript-next     # TypeScript Nightly
          dbaeumer.vscode-eslint # ESLint
          esbenp.prettier-vscode # Prettier
          bradlc.vscode-tailwindcss # Tailwind CSS IntelliSense
          formulahendry.auto-rename-tag # Auto Rename Tag
          ms-vscode-remote.remote-ssh
          ms-vscode-remote.vscode-remote-extensionpack

          # NeoVim
          asvetliakov.vscode-neovim # VSCode Neovim
        ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          # Additional TypeScript extensions that might not be in nixpkgs
          # {
          #   name = "typescript-hero";
          #   publisher = "rbbit";
          #   version = "3.0.0";
          #   sha256 = "0bj3q4v3254g14kgkg4yx9q3miw3gyvp23zz0wzjrj7h2qpz315m"; # Replace with actual hash
          # }
          # {
          #   name = "vscodeintellicode";
          #   publisher = "VisualStudioExptTeam";
          #   version = "1.2.30";
          #   sha256 = "1fr48sgd0h0diw7amn99dad9l4m7v8ydvj5yzzj9yq53l1brz35i"; # Replace with actual hash
          # }
          # {
          #   name = "path-intellisense";
          #   publisher = "christian-kohler";
          #   version = "2.8.4";
          #   sha256 = "1wyp3k8nc5kf5dbpbvjpq8lxbe35r9zj2wjc0n9nq4rhg5c0hg3v"; # Replace with actual hash
          # }
        ];

      userSettings = {
        # Theme settings - Fix for light title bar
        "window.titleBarStyle" = "custom";
        "window.autoDetectColorScheme" = false;
        # "workbench.colorTheme" = "Catppuccin Macchiato";
        # "workbench.preferredDarkColorTheme" = "Catppuccin Macchiato";
        "workbench.colorCustomizations" = {
          "titleBar.activeBackground" = "#24273a";
          "titleBar.activeForeground" = "#cad3f5";
          "titleBar.inactiveBackground" = "#1e2030";
          "titleBar.inactiveForeground" = "#a5adcb";
          "activityBar.background" = "#24273a";
          "sideBar.background" = "#1e2030";
        };

        # Force dark UI
        "window.dialogStyle" = "custom";
        "window.menuBarVisibility" = "toggle";
        "workbench.startupEditor" = "newUntitledFile";

        # TypeScript settings
        "typescript.updateImportsOnFileMove.enabled" = "always";
        "typescript.suggest.autoImports" = true;
        "typescript.preferences.importModuleSpecifier" = "relative";
        "[typescript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
          "editor.suggestSelection" = "first";
        };
        "[typescriptreact]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        # NeoVim settings
        "vscode-neovim.neovimExecutablePaths.linux" = "${pkgs.neovim}/bin/nvim";
        "vscode-neovim.neovimInitVimPaths.linux" =
          "$HOME/.config/vscode-neovim/init.lua";
        "keyboard.dispatch" = "keyCode";
        "vscode-neovim.NVIM_APPNAME" = "vscode-neovim";

        # Enable NeoVim keybindings
        "editor.lineNumbers" = "relative";

        # Performance improvements for neovim
        "extensions.experimental.affinity" = {
          "asvetliakov.vscode-neovim" = 1;
        };
      };

      keybindings = [
        {
          key = "ctrl+y";
          command = "-aichat.newfollowupaction";
        }
        {
          key = "ctrl+y";
          command = "-redo";
        }
        {
          key = "ctrl+y";
          command = "acceptSelectedSuggestion";
          when = "suggestWidgetVisible && textInputFocus";
        }
        {
          key = "alt+y";
          command = "editor.action.inlineSuggest.commit";
          when =
            "inlineSuggestionHasIndentationLessThanTabSize && inlineSuggestionVisible && !editorHoverFocused && !editorTabMovesFocus && !suggestWidgetVisible";
        }
        # Close file sidebar
        {
          key = "q";
          command = "runCommands";
          args = { commands = [ "workbench.action.toggleSidebarVisibility" ]; };
          when = "sideBarVisible";
        }
        # Close terminal
        {
          key = "q";
          command = "runCommands";
          args = { commands = [ "workbench.action.terminal.toggleTerminal" ]; };
          when = "terminalFocus";
        }
        # Close Ai sidebar (secondary sidebar)
        {
          key = "q";
          command = "runCommands";
          args = { commands = [ "workbench.action.toggleAuxiliaryBar" ]; };
          when = "auxiliaryBarFocus";
        }
      ];
    };
  };

  # Create a separate directory for VSCode-specific NeoVim config
  home.activation.createVSCodeNeovimDir =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.config/vscode-neovim
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.local/share/vscode-neovim/lazy
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.local/share/vscode-neovim/plugins
    '';

  # Create a VSCode-specific init.vim file
  home.file.".config/vscode-neovim/init.lua".text = ''
    --[[
      VSCode Neovim Configuration
      This configuration is specifically designed for VSCode integration,
      avoiding features that might conflict with VSCode's own functionality.
    ]]

    -- Must be set before loading any Neovim configuration
    -- Prevents tree-sitter from loading plugins
    -- Prevents tree-sitter from causing errors when launching neovim
    vim.cmd([[
      set noloadplugins
      let g:loaded_node_provider = 0
      let g:loaded_python3_provider = 0
      let g:loaded_ruby_provider = 0
      let g:loaded_perl_provider = 0
      let g:did_load_filetypes = 1
      let g:loaded_treesitter = 1
      let g:loaded_treesitter_provider = 1
      let g:do_filetype_lua = 0
      let g:did_indent_on = 1
      let g:did_load_ftplugin = 1
    ]])

    -- Disable filetype detection and treesitter before anything else loads
    vim.g.did_load_filetypes = 1
    vim.g.loaded_treesitter = 1
    vim.g.loaded_treesitter_provider = 1
    vim.g.do_filetype_lua = 0

    if not vim.g.vscode then
      -- If we're not in VSCode, we don't want to load this configuration
      return
    end

    --
    -- Rest of your configuration...
    --

    -- Load the VSCode integration module
    local vscode = require("vscode")

    -- These settings are safe to use with VSCode
    vim.g.mapleader = " "
    vim.opt.clipboard = "unnamedplus"
    vim.opt.hlsearch = true
    vim.opt.incsearch = true
    vim.opt.scrolloff = 10

    -- Window navigation keymaps
    vim.keymap.set("n", "<C-w>h", function()
      vscode.call("workbench.action.focusLeftGroup")
    end)
    vim.keymap.set("n", "<C-w>j", function()
      vscode.call("workbench.action.focusBelowGroup")
    end)
    vim.keymap.set("n", "<C-w>k", function()
      vscode.call("workbench.action.focusAboveGroup")
    end)
    vim.keymap.set("n", "<C-w>l", function()
      vscode.call("workbench.action.focusRightGroup")
    end)

    -- Window splits
    vim.keymap.set("n", "<C-w>v", function()
      vscode.call("workbench.action.splitEditorRight")
    end)
    vim.keymap.set("n", "<C-w>s", function()
      vscode.call("workbench.action.splitEditorDown")
    end)

    -- File searching
    vim.keymap.set("n", "<leader>sc", function()
      vscode.call("workbench.action.quickOpen")
    end)
    -- Live Grep
    vim.keymap.set("n", "<leader>sg", function()
      vscode.call("workbench.action.findInFiles")
    end)

    -- Open buffers
    vim.keymap.set("n", "<leader><leader>", function()
      vscode.call("workbench.action.showAllEditors")
    end)

    -- File explorer
    vim.keymap.set("n", "-", function()
      vscode.call("workbench.action.toggleSidebarVisibility")
      vscode.call("workbench.files.action.focusFilesExplorer")
    end)
    -- Keymap for closing the file explorer (sidebar) is located in keybindings.json (nvim does not work when sideBarFocus is set)
     
    -- Git (version control)
    vim.keymap.set("n", "<leader>gg", function()
      vscode.call("workbench.scm.focus")
    end)

    -- Terminal 
    vim.keymap.set("n", "<leader>tt", function()
      vscode.call("workbench.action.terminal.toggleTerminal")
    end)
    -- Keymap for closing the terminal is located in keybindings.json (nvim does not work when terminalFocus is set)

    -- Ai chat sidebar (secondary sidebar)
    vim.keymap.set("n", "<leader>aa", function()
      vscode.call("workbench.action.toggleAuxiliaryBar")
    end)

    -- Ai Composer
    vim.keymap.set("n", "<leader>ai", function()
      vscode.call("workbench.panel.composerViewPane2.view.focus")
    end)

    -- Extensions panel
    vim.keymap.set("n", "<leader>ex", function()
      vscode.call("workbench.views.extensions.installed.focus")
    end)




    -- Diagnostics
    vim.keymap.set("n", "<leader>di", function()
      vscode.call("editor.action.showHover")
    end)

    -- Line/inline comment with <leader>gc
    vim.keymap.set({ "n", "v" }, "<leader>gc", function()
      vscode.call("editor.action.commentLine")
    end)

    -- Block comment with <leader>gb
    vim.keymap.set({ "n", "v" }, "<leader>gb", function()
      vscode.call("editor.action.blockComment")
    end)

    -- Format document
    vim.keymap.set("n", "<leader>f", function()
      vscode.call("editor.action.formatDocument")
    end, { desc = "Format document" })

    -- LSP suggestion navigation

    -- Not working here, <C-y> is defined in keybindings.json
    vim.keymap.set("i", "<C-y>", function()
      vscode.call("acceptSelectedSuggestion", {
        when = "acceptSuggestionOnEnter && suggestWidgetHasFocusedSuggestion && suggestWidgetVisible && suggestionMakesTextEdit && textInputFocus",
      })
    end)

    vim.keymap.set("i", "<C-n>", function()
      vscode.call("selectNextSuggestion")
    end)

    vim.keymap.set("i", "<C-p>", function()
      vscode.call("selectPrevSuggestion")
    end)

    -- Terminal and Harpoon keymaps
    vim.keymap.set("n", "<leader>t", function()
        vscode.call("workbench.action.terminal.new")
    end, { desc = "New terminal" })

    vim.keymap.set("n", "<leader>a", function()
        vscode.call("vscode-harpoon.addEditor")
    end, { desc = "Harpoon: Add editor" })

    vim.keymap.set("n", "<leader>e", function()
        vscode.call("vscode-harpoon.editorQuickPick")
    end, { desc = "Harpoon: Quick pick" })

    vim.keymap.set("n", "<leader>E", function()
        vscode.call("vscode-harpoon.editEditors")
    end, { desc = "Harpoon: Edit editors" })

    -- Harpoon: Go to editor 1-8
    for i = 1, 8 do
        vim.keymap.set("n", string.format("<leader>%d", i), function()
            vscode.call(string.format("vscode-harpoon.gotoEditor%d", i))
        end, { desc = string.format("Harpoon: Go to editor %d", i) })
    end

    -- Lazy.nvim setup
    local lazypath = vim.fn.expand("~/.local/share/vscode-neovim/lazy/lazy.nvim")
    if not vim.loop.fs_stat(lazypath) then
      vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "--branch=stable",
        "https://github.com/folke/lazy.nvim.git",
        lazypath,
      })
    end

    vim.opt.rtp:prepend(lazypath)

    require("lazy").setup({
      -- Your plugins will go here
    }, {
      root = vim.fn.expand("~/.local/share/vscode-neovim/plugins"),
      lockfile = vim.fn.expand("~/.local/share/vscode-neovim/lazy-lock.json"),
      state = vim.fn.expand("~/.local/share/vscode-neovim/lazy/state.json"),
      readme = { enabled = false },
      defaults = {
        lazy = true,
      },
      concurrency = 1,
    })   '';
}
