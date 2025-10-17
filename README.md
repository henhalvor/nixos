# NixOS Configuration with Flakes and Home Manager

This repository contains a NixOS configuration using **Nix Flakes** and **Home Manager** to create a flexible, multi-system development environment. Home Manager is integrated as a NixOS module for unified system and user configuration management.

## Architecture Overview

This setup uses a single flake that manages both NixOS system configurations and Home Manager user configurations through NixOS modules. This approach ensures consistency and eliminates conflicts between system and user settings.

### Key Components

- **NixOS Systems**: Multiple machine configurations (workstation, laptop, server)
- **Home Manager Integration**: User configurations managed through NixOS modules
- **Unified Rebuilds**: Single command rebuilds both system and user configurations
- **Multi-User Support**: Different user profiles for different use cases

## Directory Structure

```
~/.dotfiles/
├── flake.nix                    # Main flake configuration
├── install.sh                  # Automated installation script
├── assets/
│   └── wallpapers/             # System wallpapers
├── home/
│   ├── config/                 # Home configuration files
│   ├── modules/
│   │   ├── applications/       # Application configurations
│   │   ├── environment/        # Environment setup
│   │   ├── scripts/           # Custom scripts
│   │   ├── settings/          # System settings
│   │   ├── themes/            # Theme configurations
│   │   └── window-manager/    # Window manager configs
│   └── shells/                # Development shells
├── nixos/
│   └── modules/               # NixOS system modules
├── systems/
│   ├── workstation/           # Desktop system config
│   ├── lenovo-yoga-pro-7/     # Laptop system config
│   ├── desktop/               # Legacy desktop config
│   └── hp-server/             # Server system config
└── users/
    ├── henhal/                # Primary user configuration
    └── henhal-dev/            # Development user configuration
```

## Available System Configurations

- **workstation**: Main desktop system with Hyprland
- **lenovo-yoga-pro-7**: Laptop configuration with power management
- **desktop**: Legacy desktop configuration (marked for removal)
- **hp-server**: Headless server configuration with VS Code server

## Rebuilding the Configuration

### System Rebuild (Recommended)

This is the primary way to apply changes. It rebuilds both NixOS and Home Manager configurations together:

```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .#<system-name>
```

**Examples:**

```bash
# For workstation
sudo nixos-rebuild switch --flake .#workstation

# For laptop
sudo nixos-rebuild switch --flake .#lenovo-yoga-pro-7

# For server
sudo nixos-rebuild switch --flake .#hp-server
```

**Available Actions:**

- `switch`: Build, activate, and set as boot default (recommended)
- `boot`: Build and set as boot default, activate on next reboot
- `test`: Build and activate temporarily (no boot changes)
- `build`: Build only, no activation

## Installation

### Automated Installation

Run the installation script on a fresh NixOS system:

```bash
curl -L https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh | sh
```

The script will:

1. Install git if needed
2. Clone the repository to `~/.dotfiles`
3. Enable Nix experimental features
4. Copy hardware configuration
5. Prompt for system configuration selection
6. Rebuild the system

### Manual Installation

1. **Clone Repository:**

   ```bash
   git clone https://github.com/henhalvor/nixos.git ~/.dotfiles
   cd ~/.dotfiles
   ```

2. **Copy Hardware Configuration:**

   ```bash
   sudo cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/systems/<system-name>/hardware-configuration.nix
   ```

3. **Enable Nix Flakes:**

   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

4. **Apply Configuration:**
   ```bash
   sudo nixos-rebuild switch --flake .#<system-name>
   ```

## Adding a New System

1. **Create System Directory:**

   ```bash
   mkdir -p ~/.dotfiles/systems/new-system
   ```

2. **Create Configuration:**
   Create `~/.dotfiles/systems/new-system/configuration.nix`:

   ```nix
   { config, pkgs, userSettings, ... }: {
     imports = [
       ./hardware-configuration.nix
       ../../nixos/modules/default.nix
     ];

     # System-specific configuration here
   }
   ```

3. **Add to Flake:**
   Edit `flake.nix` and add to `nixosConfigurations`:

   ```nix
   new-system = mkNixosSystem {
     systemName = "new-system";
     hostname = "new-hostname";
     userSettings = userHenhal;  # or create new user
     windowManager = "hyprland"; # or "none" for servers
   };
   ```

4. **Copy Hardware Config:**

   ```bash
   sudo cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/systems/new-system/
   ```

5. **Rebuild:**
   ```bash
   sudo nixos-rebuild switch --flake .#new-system
   ```

## Adding a New User

1. **Define User Settings in flake.nix:**

   ```nix
   userNewUser = rec {
     username = "newuser";
     name = "New User";
     email = "newuser@example.com";
     homeDirectory = "/home/${username}";
     term = "kitty";
     browser = "zen-browser";
     stateVersion = "25.05";
   };
   ```

2. **Create User Directory:**

   ```bash
   mkdir -p ~/.dotfiles/users/newuser
   ```

3. **Create Home Configuration:**
   Create `~/.dotfiles/users/newuser/home.nix` with the user's Home Manager configuration.

4. **Update System Configuration:**
   Modify the desired system in `nixosConfigurations` to use the new user:
   ```nix
   userSettings = userNewUser;
   ```

## User Profiles

### henhal (Primary User)

- Full desktop environment with Hyprland
- Development tools and applications
- Theming with Stylix (Gruvbox/Catppuccin)

### henhal-dev (Development User)

- Minimal server-oriented configuration
- Development tools without GUI applications
- Used on server systems

## Key Features

- **Unified Configuration**: Single command rebuilds both system and user configs
- **Multi-System Support**: Easy management of multiple machines
- **Theme Management**: Stylix integration for consistent theming
- **Window Manager Support**: Hyprland and Sway configurations
- **Development Environment**: Comprehensive tooling for various languages
- **Server Support**: Headless configurations with remote development tools

## Maintenance

### Update Dependencies

```bash
cd ~/.dotfiles
nix flake update
sudo nixos-rebuild switch --flake .#<system-name>
```

### Update Neovim Packages

```vim
:Lazy update
:Mason update
```

### Backup and Version Control

```bash
cd ~/.dotfiles
git add .
git commit -m "Update configuration"
git push
```

## Troubleshooting

### Common Issues

1. **Build Failures**: Check that hardware-configuration.nix exists in the system directory
2. **Permission Issues**: Ensure you're running nixos-rebuild with sudo
3. **Flake Errors**: Verify flake.nix syntax with `nix flake check`

### Getting Help

- Check NixOS manual: https://nixos.org/manual/nixos/stable/
- Home Manager manual: https://nix-community.github.io/home-manager/
- Nix flakes documentation: https://nixos.wiki/wiki/Flakes

## Development Shells

The repository includes development shells for specific languages:

```bash
# Rust development
cd ~/.dotfiles/shells/rust
nix develop

# React Native development
cd ~/.dotfiles/shells/js/react-native
nix develop
```

This configuration provides a robust, reproducible development environment that can be easily deployed across multiple systems while maintaining consistency and flexibility.

