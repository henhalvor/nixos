# NixOS Development Environment Setup

This repository contains a NixOS configuration that creates a flexible and maintainable development environment. The setup uses Home Manager to manage system tools while maintaining the ability to install and manage packages locally. It's designed to work seamlessly with Neovim and various development tools while respecting NixOS's immutable filesystem principles.

## Directory Structure

The configuration creates an organized directory structure in your home directory:

```
~/.local/
├── dev/                    # Development tools and global packages
│   ├── npm/               # Node.js related
│   │   ├── global/        # Global npm packages
│   │   ├── cache/         # npm cache
│   │   └── config/        # npm configuration
│   ├── cargo/             # Rust/Cargo installations
│   ├── rustup/            # Rust toolchain
│   ├── python/            # Python user packages
│   └── go/                # Go packages
└── share/
    └── nvim/              # Neovim-specific installations
        ├── lazy/          # Lazy.nvim plugins
        └── mason/         # Mason-installed tools
```

## Initial Setup

### Quick Install

1. Run this command on a fresh nixOs installation:

   ```bash
   nix-env -iA nixos.git && git clone https://github.com/henhalvor/nixos.git ~/.dotfiles && cd ~/.dotfiles && chmod +x install.sh &&
   ./install.sh
   ```

1. Clone this repository to your home directory:

   ```bash
   git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
   ```

1. Create necessary directories:

   ```bash
   mkdir -p ~/.local/dev/{npm/{global,cache,config},cargo,rustup,python,go}
   mkdir -p ~/.local/share/nvim/{lazy,mason}
   ```

1. Apply the configuration:
   ```bash
   home-manager switch
   ```

## How It Works

### Core Development Tools

The setup uses Home Manager to install and manage core development tools. These are defined in `home.nix`:

- Node.js and npm
- Rust and Cargo
- Python and pip
- Go
- Various build tools (gcc, make, cmake)

These tools are installed system-wide through Home Manager but are configured to install their packages in your home directory.

### Package Management

Each development tool is configured to install its packages in a user-accessible location:

1. NPM Global Packages:

   ```bash
   npm install -g typescript
   # Installs to ~/.local/dev/npm/global
   ```

2. Python Packages:

   ```bash
   pip install --user black
   # Installs to ~/.local/dev/python
   ```

3. Rust Packages:

   ```bash
   cargo install ripgrep
   # Installs to ~/.local/dev/cargo
   ```

4. Go Packages:
   ```bash
   go install golang.org/x/tools/gopls@latest
   # Installs to ~/.local/dev/go
   ```

### Neovim Integration

The Neovim configuration uses two package managers:

1. Lazy.nvim for plugin management

   - Installs plugins to ~/.local/share/nvim/lazy
   - Configured in init.lua
   - Uses the system Git installation from Home Manager

2. Mason for LSP servers and tools
   - Installs to ~/.local/share/nvim/mason
   - Uses system tools (npm, pip, etc.) for installations
   - Configured to respect our directory structure

## Adding New Tools

### Adding System Tools

To add new system-wide tools, modify `home.nix`:

```nix
home.packages = with pkgs; [
  # Add your new package here
  newpackage
];
```

Then run:

```bash
home-manager switch
```

### Adding Neovim Plugins

To add new plugins, modify your Neovim configuration in `lua/plugins/`:

```lua
-- In a new or existing plugin file
return {
  'author/plugin-name',
  config = function()
    -- Plugin configuration
  end
}
```

### Adding Language Servers

Add new language servers to your LSP configuration:

```lua
local servers = {
  your_new_server = {
    settings = {
      -- Server-specific settings
    }
  }
}
```

Mason will automatically install the server on next Neovim startup.

## Maintenance

### Updating the System

Update your NixOS system and Home Manager packages:

```bash
sudo nixos-rebuild switch
home-manager switch
```

### Updating Neovim Packages

1. Update plugins:

   ```vim
   :Lazy update
   ```

2. Update language servers and tools:
   ```vim
   :Mason update
   ```

### Cleaning Up

To clean unused packages:

```bash
# Clean npm packages
npm clean-install

# Clean Mason installations
:Mason uninstall <package>

# Clean Lazy plugins
:Lazy clean
```

## Troubleshooting

If you encounter permission issues:

1. Check that the directories exist in ~/.local
2. Verify ownership: `ls -la ~/.local/dev`
3. Ensure environment variables are set: `echo $NPM_CONFIG_PREFIX`

For Mason installation issues:

1. Check Mason log: `:Mason log`
2. Verify system tools are available: `which npm`, `which pip`
3. Check installation directory permissions

## Adding Custom Configuration

The setup is designed to be extensible. Common customization points:

1. Shell Configuration (home.nix):

   ```nix
   programs.bash = {
     shellAliases = {
       # Add your aliases here
     };
   };
   ```

2. Git Configuration:

   ```nix
   programs.git.extraConfig = {
     # Add your git config here
   };
   ```

3. Development Tool Settings:
   ```nix
   home.file.".config/tool/config".text = ''
     # Tool-specific configuration
   '';
   ```

Remember to run `home-manager switch` after making changes to `home.nix`.

## Understanding the Design

This setup follows several key principles:

1. **Separation of Concerns**: System tools are managed by Home Manager, while development-specific tools are managed in user space.

2. **Reproducibility**: The configuration is version-controlled and declarative, making it easy to reproduce the same environment on different machines.

3. **Flexibility**: While core tools are managed through Nix, you maintain the ability to use traditional package managers for development-specific tools.

4. **Organization**: All user-installed packages are kept in a clean, organized directory structure under ~/.local.

This design allows you to maintain a stable system while having the flexibility to experiment with development tools and configurations in your user space.
