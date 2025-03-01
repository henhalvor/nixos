{ config, pkgs, lib, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    
    extensions = with pkgs.vscode-extensions; [
      # TypeScript Development
      # ms-vscode.vscode-typescript-next     # TypeScript Nightly
      dbaeumer.vscode-eslint               # ESLint
      esbenp.prettier-vscode               # Prettier
      bradlc.vscode-tailwindcss            # Tailwind CSS IntelliSense
      formulahendry.auto-rename-tag        # Auto Rename Tag
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.vscode-remote-extensionpack
      
      # NeoVim
      asvetliakov.vscode-neovim            # VSCode Neovim
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
      "workbench.colorTheme" = "Catppuccin Macchiato";
      "workbench.preferredDarkColorTheme" = "Catppuccin Macchiato";
      "workbench.colorCustomizations" = {
        "titleBar.activeBackground" = "#24273a";        # Catppuccin Macchiato base
        "titleBar.activeForeground" = "#cad3f5";        # Catppuccin Macchiato text
        "titleBar.inactiveBackground" = "#1e2030";      # Catppuccin Macchiato mantle
        "titleBar.inactiveForeground" = "#a5adcb";      # Catppuccin Macchiato subtext0
        "activityBar.background" = "#24273a";           # Consistent with titleBar
        "sideBar.background" = "#1e2030";               # Slightly darker for contrast
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
      
      # NeoVim settings - Use a separate init file specifically for VSCode
      "vscode-neovim.neovimExecutablePaths.linux" = "${pkgs.neovim}/bin/nvim";
      "vscode-neovim.neovimInitVimPaths.linux" = "$HOME/.config/vscode-neovim/init.vim";
      "keyboard.dispatch" = "keyCode";  # Better keyboard handling for NeoVim
      
      # Enable NeoVim keybindings
      "editor.lineNumbers" = "relative";

      # Performance improvements for neovim
      "extensions.experimental.affinity" = {
        "asvetliakov.vscode-neovim" = 1;
    };
    };

    keybindings = [
      {
        key = "ctrl+h";
        command = "workbench.action.navigateLeft";
        when = "neovim.mode != 'insert'";
      }
      {
        key = "ctrl+j";
        command = "workbench.action.navigateDown";
        when = "neovim.mode != 'insert'";
      }
      {
        key = "ctrl+k";
        command = "workbench.action.navigateUp";
        when = "neovim.mode != 'insert'";
      }
      {
        key = "ctrl+l";
        command = "workbench.action.navigateRight";
        when = "neovim.mode != 'insert'";
      }
      {
        key = "space";
        command = "vscode-neovim.leader";
        when = "editorTextFocus && neovim.mode != 'insert'";
      }
    ];
  };

  # Create a separate directory for VSCode-specific NeoVim config
  home.activation.createVSCodeNeovimDir = ''
    mkdir -p ${config.home.homeDirectory}/.config/vscode-neovim
  '';

  # Create a VSCode-specific init.vim file
  home.file.".config/vscode-neovim/init.vim".text = ''
    " VSCode-NeoVim specific configuration
    " This is completely separate from your regular NeoVim setup

    set clipboard=unnamedplus
    set ignorecase
    set smartcase
    set number
    set relativenumber
    set mouse=a
    
    " VSCode-specific settings
    " VSCode-neovim specific settings
    nnoremap <silent> za <Cmd>call VSCodeNotify('editor.toggleFold')<CR>
    nnoremap <silent> zR <Cmd>call VSCodeNotify('editor.unfoldAll')<CR>
    nnoremap <silent> zM <Cmd>call VSCodeNotify('editor.foldAll')<CR>
    nnoremap <silent> zo <Cmd>call VSCodeNotify('editor.unfold')<CR>
    nnoremap <silent> zc <Cmd>call VSCodeNotify('editor.fold')<CR>
    
    " Leader mappings for VSCode actions
    nnoremap <silent> <leader>f <Cmd>call VSCodeNotify('workbench.action.quickOpen')<CR>
    nnoremap <silent> <leader>e <Cmd>call VSCodeNotify('workbench.action.toggleSidebarVisibility')<CR>
    nnoremap <silent> <leader>g <Cmd>call VSCodeNotify('workbench.view.scm')<CR>
    
    " TypeScript-specific keybindings
    nnoremap <silent> gd <Cmd>call VSCodeNotify('editor.action.revealDefinition')<CR>
    nnoremap <silent> gr <Cmd>call VSCodeNotify('editor.action.goToReferences')<CR>
    nnoremap <silent> gi <Cmd>call VSCodeNotify('editor.action.goToImplementation')<CR>
    nnoremap <silent> <leader>rn <Cmd>call VSCodeNotify('editor.action.rename')<CR>
    nnoremap <silent> <leader>ca <Cmd>call VSCodeNotify('editor.action.quickFix')<CR>
  '';
}
