# { config, pkgs, unstable, lib, ... }:
#
# {
#
#   # Install the Cursor package
#   home.packages = with pkgs; [
#     unstable.code-cursor
#   ];
#
#   # Cursor user settings (adapted from VSCode config)
#   home.file.".config/Cursor/User/settings.json".text = builtins.toJSON {
#     # Theme settings - Fix for light title bar
#     "window.titleBarStyle" = "custom";
#     "window.autoDetectColorScheme" = false;
#     "workbench.colorTheme" = "Catppuccin Macchiato";
#     "workbench.preferredDarkColorTheme" = "Catppuccin Macchiato";
#     "workbench.colorCustomizations" = {
#       "titleBar.activeBackground" = "#24273a";
#       "titleBar.activeForeground" = "#cad3f5";
#       "titleBar.inactiveBackground" = "#1e2030";
#       "titleBar.inactiveForeground" = "#a5adcb";
#       "activityBar.background" = "#24273a";
#       "sideBar.background" = "#1e2030";
#     };
#
#     # Force dark UI
#     "window.dialogStyle" = "custom";
#     "window.menuBarVisibility" = "toggle";
#     "workbench.startupEditor" = "newUntitledFile";
#
#     # TypeScript settings
#     "typescript.updateImportsOnFileMove.enabled" = "always";
#     "typescript.suggest.autoImports" = true;
#     "typescript.preferences.importModuleSpecifier" = "relative";
#     "[typescript]" = {
#       "editor.defaultFormatter" = "esbenp.prettier-vscode";
#       "editor.suggestSelection" = "first";
#     };
#     "[typescriptreact]" = {
#       "editor.defaultFormatter" = "esbenp.prettier-vscode";
#     };
#
#     "editor.lineNumbers" = "relative";
#
#   };
#
#   # https://www.youtube.com/watch?v=JRnwt7oT1ZE&t=790s
#
#
#   # Cursor keybindings
#   home.file.".config/Cursor/User/keybindings.json".text = builtins.toJSON [
#     #  // Navigation
#   {
#     key = "ctrl-h";
#     command = "workbench.action.navigateLeft";
#   }
#   {
#     key = "ctrl-l";
#     command = "workbench.action.navigateRight";
#   }
#   {
#     key = "ctrl-k";
#     command = "workbench.action.navigateUp";
#   }
#   {
#     key = "ctrl-j";
#     command = "workbench.action.navigateDown";
#   }
#   # Open buffers
#   {
#     key = "space space";
#     command = "workbench.action.showAllEditors";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#   }
#   # Open file explorer
#   {
#     key = "-";
#     command = "runCommands";
#     args = {
#       commands = [
#         "workbench.action.toggleSidebarVisibility"
#         "workbench.files.action.focusFilesExplorer"
#       ];
#     };
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && !sideBarFocus";
#   }
#   # Close file explorer
#   {
#     key = "q";
#     command = "runCommands";
#     args = {
#       commands = [
#         "workbench.action.toggleSidebarVisibility"
#         "workbench.action.focusActiveEditorGroup"
#       ];
#     };
#     when = "sideBarFocus && !inputFocus";
#   }
#   # TODO remove??
#   # Open file explorer
#   {
#     key = "-";
#     when = "vim.mode == 'Normal' && editorTextFocus && foldersViewVisible";
#     command = "workbench.action.toggleSidebarVisibility";
#   }
#   # Window split
#   {
#     key = "ctrl-w s";
#     command = "workbench.action.splitEditor";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#   }
#   {
#     key = "ctrl-w v";
#     command = "workbench.action.splitEditorDown";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#   }
#
#   #
#   #  // Coding
#   #
#   {
#     key = "space c a";
#     command = "editor.action.codeAction";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   # Move visually selected text
#   {
#     key = "shift-k";
#     command = "editor.action.moveLinesUpAction";
#     when = "vim.mode == 'VisualLine' && editorTextFocus";
#   }
#   {
#     key = "shift-j";
#     command = "editor.action.moveLinesDownAction";
#     when = "vim.mode == 'VisualLine' && editorTextFocus";
#   }
#   # Lsp hover
#   {
#     key = "shift-k";
#     command = "editor.action.showHover";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   # Lsp rename
#   {
#     key = "space r n";
#     command = "editor.action.rename";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   # Open symbol menu
#   {
#     key = "space c s";
#     command = "workbench.action.gotoSymbol";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   # {
#   #   key = "space b d";
#   #   command = "workbench.action.closeActiveEditor";
#   #   when = "(vim.mode == 'Normal' && editorTextFocus) || !inputFocus";
#   # }
#   # {
#   #   key = "space b o";
#   #   command = "workbench.action.closeOtherEditors";
#   #   when = "(vim.mode == 'Normal' && editorTextFocus) || !inputFocus";
#   # }
#
#   # Search files
#   {
#     key = "space s c";
#     command = "workbench.action.quickOpen";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#   }
#   {
#     key = "space g d";
#     command = "editor.action.revealDefinition";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   {
#     key = "space g r";
#     command = "editor.action.goToReferences";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   {
#     key = "space g i";
#     command = "editor.action.goToImplementation";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   {
#     key = "space s g";
#     command = "workbench.action.findInFiles";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#   }
#   {
#     key = "space g g";
#     command = "runCommands";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
#     args = {
#       commands = ["workbench.view.scm" "workbench.scm.focus"];
#     };
#   }
#   {
#     key = "ctrl-n";
#     command = "editor.action.addSelectionToNextFindMatch";
#     when = "(vim.mode == 'Normal' || vim.mode == 'Visual') && (editorTextFocus || !inputFocus)";
#   }
#
#   #  // File Explorer
#   {
#     key = "r";
#     command = "renameFile";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "c";
#     command = "filesExplorer.copy";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "p";
#     command = "filesExplorer.paste";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "x";
#     command = "filesExplorer.cut";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "d";
#     command = "deleteFile";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "a";
#     command = "explorer.newFile";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "s";
#     command = "explorer.openToSide";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#   }
#   {
#     key = "shift-s";
#     command = "runCommands";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
#     args = {
#       commands = [
#         "workbench.action.splitEditorDown"
#         "explorer.openAndPassFocus"
#         "workbench.action.closeOtherEditors"
#       ];
#     };
#   }
#   {
#     key = "enter";
#     command = "explorer.openAndPassFocus";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceIsFolder && !inputFocus";
#   }
#   {
#     key = "enter";
#     command = "list.toggleExpand";
#     when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && explorerResourceIsFolder && !inputFocus";
#   }
#
#   #  // Debug
#   {
#     key = "space d a";
#     command = "workbench.action.debug.selectandstart";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && debuggersAvailable";
#   }
#   {
#     key = "space d t";
#     command = "workbench.action.debug.stop";
#     when = "vim.mode == 'Normal' && editorTextFocus && inDebugMode && !focusedSessionIsAttached";
#   }
#   {
#     key = "space d o";
#     command = "workbench.action.debug.stepOver";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
#   }
#   {
#     key = "space d b";
#     command = "editor.debug.action.toggleBreakpoint";
#     when = "vim.mode == 'Normal' && editorTextFocus";
#   }
#   {
#     key = "space d e";
#     command = "editor.debug.action.showDebugHover";
#     when = "vim.mode == 'Normal' && editorTextFocus && inDebugMode && debugState == 'stopped'";
#   }
#   {
#     key = "space d c";
#     command = "workbench.action.debug.continue";
#     when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
#   }
#
#   ];
# }
#

{ config, pkgs, unstable, lib, ... }:

{
  # Make sure vscode-neovim (asvetliakov.vscode-neovim) is installed 

  # Install the Cursor package
  home.packages = with pkgs; [
    unstable.code-cursor
  ];

  # Cursor user settings (adapted from VSCode config)
  home.file.".config/Cursor/User/settings.json".text = builtins.toJSON {
    # Theme settings - Fix for light title bar
    "window.titleBarStyle" = "custom";
    "window.autoDetectColorScheme" = false;
    "workbench.colorTheme" = "Catppuccin Macchiato";
    "workbench.preferredDarkColorTheme" = "Catppuccin Macchiato";
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
    "vscode-neovim.neovimInitVimPaths.linux" = "$HOME/.config/cursor-neovim/init.vim";
    "keyboard.dispatch" = "keyCode";
    "vscode-neovim.NVIM_APPNAME" = "cursor-neovim";


    # Enable NeoVim keybindings
    "editor.lineNumbers" = "relative";

    # Performance improvements for neovim
    "extensions.experimental.affinity" = {
      "asvetliakov.vscode-neovim" = 1;
    };
  };

  # Cursor keybindings
  home.file.".config/Cursor/User/keybindings.json".text = builtins.toJSON [
   # {
   #    key = "space";
   #    command = "vscode-neovim.leader";
   #    when = "editorTextFocus && neovim.mode != 'insert'";
   #  }
   #
    #  // Navigation
  {
    key = "ctrl-h";
    command = "workbench.action.navigateLeft";
  }
  {
    key = "ctrl-l";
    command = "workbench.action.navigateRight";
  }
  {
    key = "ctrl-k";
    command = "workbench.action.navigateUp";
  }
  {
    key = "ctrl-j";
    command = "workbench.action.navigateDown";
  }
  # Open buffers
  {
    key = "space space";
    command = "workbench.action.showAllEditors";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
  }
  # Open file explorer
  {
    key = "-";
    command = "runCommands";
    args = {
      commands = [
        "workbench.action.toggleSidebarVisibility"
        "workbench.files.action.focusFilesExplorer"
      ];
    };
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && !sideBarFocus";
  }
  # Close file explorer
  {
    key = "q";
    command = "runCommands";
    args = {
      commands = [
        "workbench.action.toggleSidebarVisibility"
        "workbench.action.focusActiveEditorGroup"
      ];
    };
    when = "sideBarFocus && !inputFocus";
  }
  # TODO remove??
  # Open file explorer
  {
    key = "-";
    when = "vim.mode == 'Normal' && editorTextFocus && foldersViewVisible";
    command = "workbench.action.toggleSidebarVisibility";
  }
  # Window split
  {
    key = "ctrl-w s";
    command = "workbench.action.splitEditor";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
  }
  {
    key = "ctrl-w v";
    command = "workbench.action.splitEditorDown";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
  }

  #
  #  // Coding
  #
  {
    key = "space c a";
    command = "editor.action.codeAction";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  # Move visually selected text
  {
    key = "shift-k";
    command = "editor.action.moveLinesUpAction";
    when = "vim.mode == 'VisualLine' && editorTextFocus";
  }
  {
    key = "shift-j";
    command = "editor.action.moveLinesDownAction";
    when = "vim.mode == 'VisualLine' && editorTextFocus";
  }
  # Lsp hover
  {
    key = "shift-k";
    command = "editor.action.showHover";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  # Lsp rename
  {
    key = "space r n";
    command = "editor.action.rename";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  # Open symbol menu
  {
    key = "space c s";
    command = "workbench.action.gotoSymbol";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  # {
  #   key = "space b d";
  #   command = "workbench.action.closeActiveEditor";
  #   when = "(vim.mode == 'Normal' && editorTextFocus) || !inputFocus";
  # }
  # {
  #   key = "space b o";
  #   command = "workbench.action.closeOtherEditors";
  #   when = "(vim.mode == 'Normal' && editorTextFocus) || !inputFocus";
  # }

  # Search files
  {
    key = "space s c";
    command = "workbench.action.quickOpen";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
  }
  {
    key = "space g d";
    command = "editor.action.revealDefinition";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  {
    key = "space g r";
    command = "editor.action.goToReferences";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  {
    key = "space g i";
    command = "editor.action.goToImplementation";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  {
    key = "space s g";
    command = "workbench.action.findInFiles";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
  }
  {
    key = "space g g";
    command = "runCommands";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus)";
    args = {
      commands = ["workbench.view.scm" "workbench.scm.focus"];
    };
  }
  {
    key = "ctrl-n";
    command = "editor.action.addSelectionToNextFindMatch";
    when = "(vim.mode == 'Normal' || vim.mode == 'Visual') && (editorTextFocus || !inputFocus)";
  }

  #  // File Explorer
  {
    key = "r";
    command = "renameFile";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "c";
    command = "filesExplorer.copy";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "p";
    command = "filesExplorer.paste";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "x";
    command = "filesExplorer.cut";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "d";
    command = "deleteFile";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "a";
    command = "explorer.newFile";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "s";
    command = "explorer.openToSide";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
  }
  {
    key = "shift-s";
    command = "runCommands";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
    args = {
      commands = [
        "workbench.action.splitEditorDown"
        "explorer.openAndPassFocus"
        "workbench.action.closeOtherEditors"
      ];
    };
  }
  {
    key = "enter";
    command = "explorer.openAndPassFocus";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && !explorerResourceIsFolder && !inputFocus";
  }
  {
    key = "enter";
    command = "list.toggleExpand";
    when = "filesExplorerFocus && foldersViewVisible && !explorerResourceIsRoot && explorerResourceIsFolder && !inputFocus";
  }

  #  // Debug
  {
    key = "space d a";
    command = "workbench.action.debug.selectandstart";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && debuggersAvailable";
  }
  {
    key = "space d t";
    command = "workbench.action.debug.stop";
    when = "vim.mode == 'Normal' && editorTextFocus && inDebugMode && !focusedSessionIsAttached";
  }
  {
    key = "space d o";
    command = "workbench.action.debug.stepOver";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
  }
  {
    key = "space d b";
    command = "editor.debug.action.toggleBreakpoint";
    when = "vim.mode == 'Normal' && editorTextFocus";
  }
  {
    key = "space d e";
    command = "editor.debug.action.showDebugHover";
    when = "vim.mode == 'Normal' && editorTextFocus && inDebugMode && debugState == 'stopped'";
  }
  {
    key = "space d c";
    command = "workbench.action.debug.continue";
    when = "vim.mode == 'Normal' && (editorTextFocus || !inputFocus) && inDebugMode && debugState == 'stopped'";
  }

  
  ];

# Create directories for Cursor-specific Neovim config and plugins
home.activation.createCursorNeovimDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
  $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.config/cursor-neovim
  $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.local/share/cursor-neovim/lazy
  $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.local/share/cursor-neovim/plugins
'';

  # Create a Cursor-specific init.lua file
  home.file.".config/cursor-neovim/init.lua".text = ''
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
    vim.keymap.set("n", "<leader>sg", function()
      vscode.call("workbench.action.findInFiles")
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
    local lazypath = vim.fn.expand("~/.local/share/cursor-neovim/lazy/lazy.nvim")
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
      root = vim.fn.expand("~/.local/share/cursor-neovim/plugins"),
      lockfile = vim.fn.expand("~/.local/share/cursor-neovim/lazy-lock.json"),
      state = vim.fn.expand("~/.local/share/cursor-neovim/lazy/state.json"),
      readme = { enabled = false },
      defaults = {
        lazy = true,
      },
      concurrency = 1,
    }) 
  '';
}
