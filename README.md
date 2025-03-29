# NixOS Development Environment Setup with Flakes

This repository contains a NixOS configuration using **Nix Flakes** and **Home Manager** to create a flexible, multi-system, and potentially multi-user development environment. It's designed to work seamlessly with Neovim and various development tools while respecting NixOS's principles.

**Current Time:** Saturday, March 29, 2025 at 10:03:08 AM
**Location Context:** Bergen Municipality, Vestland, Norway

## How the Flake Works

This setup is managed by `flake.nix`, which defines the structure and dependencies:

1.  **`inputs`**: Specifies dependencies like specific versions of `nixpkgs`, `nixpkgs-unstable`, `home-manager`, and other external flakes (`hyprpanel`, `zen-browser`, `vscode-server`).
2.  **`outputs`**: Defines what the flake provides to the Nix ecosystem.
3.  **`let` block**: Contains helper variables and functions:
    - `system`: Defines the target architecture (e.g., `x86_64-linux`).
    - `unstablePkgs`: Imports the unstable Nixpkgs channel.
    - `pkgsForNixOS`: Creates the primary Nixpkgs set for system builds, applying overlays (like `hyprpanel`) and enabling access to unstable packages via `pkgs.unstable`.
    - `user<Name>` blocks (e.g., `userHenhal`): Define settings for each potential user (username, home directory, default preferences).
    - `mkNixosSystem`: A helper function to generate NixOS system configurations, taking parameters like `systemName`, `hostname`, `userSettings`, `windowManager`, etc.
4.  **`nixosConfigurations`**: The core output for defining systems.
    - Each entry (e.g., `lenovo-yoga-pro-7`, `hp-server`) defines a complete NixOS system configuration.
    - The **key** (`lenovo-yoga-pro-7`) is used to target builds (`nixos-rebuild ... .#lenovo-yoga-pro-7`).
    - It uses `mkNixosSystem` to build the configuration, importing machine-specific settings from `./systems/<systemName>/configuration.nix`.
    - It integrates Home Manager using the NixOS module, configuring it for the user specified by the `userSettings` argument passed to `mkNixosSystem`.
    - `specialArgs` are passed down to NixOS modules, providing context like `hostname`, `windowManager`, `userSettings`, etc.
5.  **`homeConfigurations`**: Defines standalone Home Manager configurations.
    - Each entry (e.g., `henhal`) is keyed by username.
    - Used for faster, user-only updates via `home-manager switch --flake .#<username>`.
    - Gets its own `pkgs` set and relevant `extraSpecialArgs` (typically including `userSettings` and `unstable` but _not_ system-specific context like `hostname`).

## Rebuilding the Configuration

There are two main ways to apply changes:

### 1. Full System Rebuild (NixOS + Home Manager)

Use this after changing NixOS settings (e.g., services, system packages in `./systems/.../configuration.nix`, common modules) OR Home Manager settings (`./users/.../home.nix`). This updates the entire system based on a specific host definition in `nixosConfigurations`.

**Command:**

```bash
# Navigate to your flake directory (~/.dotfiles)
cd ~/.dotfiles

# Choose the target system key and action
sudo nixos-rebuild <action> --flake .#<system_key>

    Replace <action> with:
        switch: (Recommended) Build, set as default boot option, and activate immediately.
        boot: Build, set as default boot option, activate on next reboot.
        test: Build and activate temporarily (doesn't change boot options).
        build: Build only, no activation.
    Replace <system_key> with the key matching your target machine from nixosConfigurations in flake.nix (e.g., lenovo-yoga-pro-7, desktop, hp-server).

Example (Applying changes to your laptop):
Bash

sudo nixos-rebuild switch --flake .#lenovo-yoga-pro-7

This command builds the lenovo-yoga-pro-7 configuration, which includes system settings and the Home Manager setup for userHenhal (as defined in the flake), and activates both.
2. Home Manager Only Rebuild (Standalone)

Use this only when you've made changes exclusively to files managed by Home Manager (e.g., ./users/henhal/home.nix, linked dotfiles) and want a faster update without rebuilding the OS.

Command:
Bash

# Navigate to your flake directory (~/.dotfiles)
cd ~/.dotfiles

# Run AS THE USER whose config you are changing
home-manager switch --flake .#<username_key>

    Replace <username_key> with the key from homeConfigurations in flake.nix (e.g., henhal).
    Important: Run this command as the actual user (e.g., logged in as henhal). If running as root, use sudo -u henhal home-manager switch ....

Example (Quick update for user henhal):
Bash

# Assuming you are logged in as henhal
home-manager switch --flake .#henhal

This uses the standalone homeConfigurations.henhal definition, applying only user-level changes. It uses the default windowManager specified in its extraSpecialArgs for evaluating conditional imports in home.nix.
Directory Structure

(This section seems mostly related to user-space directories managed outside Nix/HM, likely still accurate)

The configuration encourages an organized directory structure in your home directory:

~/.local/
├── dev/                 # Development tools and global packages
│   ├── npm/             # Node.js related
│   │   ├── global/      # Global npm packages
│   │   ├── cache/       # npm cache
│   │   └── config/      # npm configuration
│   ├── cargo/           # Rust/Cargo installations
│   ├── rustup/          # Rust toolchain
│   ├── python/          # Python user packages
│   └── go/              # Go packages
└── share/
    └── nvim/            # Neovim-specific installations
        ├── lazy/        # Lazy.nvim plugins
        └── mason/       # Mason-installed tools

Initial Setup
Quick Install

    Run this command on a fresh NixOS installation:
    Bash

    curl -L [https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh](https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh) | sh

    (Note: Ensure install.sh is updated to use the new flake commands)

Manual Install

    Clone this repository (replace yourusername if necessary):
    Bash

git clone [https://github.com/henhalvor/nixos.git](https://www.google.com/search?q=https://github.com/henhalvor/nixos.git) ~/.dotfiles

Copy Hardware Configuration: NixOS generates a hardware-specific configuration during installation. Copy it into your flake's structure. A common place is ./nixos/:
Bash

mkdir -p ~/.dotfiles/nixos
sudo cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/nixos/hardware-configuration.nix
# Ensure ownership is correct if needed: sudo chown $USER:$USER ~/.dotfiles/nixos/hardware-configuration.nix

Important: You then need to import this file from your machine-specific configuration (e.g., inside ~/.dotfiles/systems/lenovo-yoga-pro-7/configuration.nix add imports = [ ../../nixos/hardware-configuration.nix ];).

Create User-Space Directories (Optional but Recommended):
Bash

mkdir -p ~/.local/dev/{npm/{global,cache,config},cargo,rustup,python,go}
mkdir -p ~/.local/share/nvim/{lazy,mason}

Apply the Configuration: Choose the correct <system_key> for the machine you are installing on from flake.nix.
Bash

    cd ~/.dotfiles
    # Example for the laptop:
    sudo nixos-rebuild switch --flake .#lenovo-yoga-pro-7

Adding a New System (Machine)

    Create System Directory: Make a new directory under ./systems/ named after your new machine (e.g., systems/new-server/).
    Add Configuration: Create a configuration.nix file inside this new directory. You can copy from an existing system and adapt it. Define machine-specific settings (kernel modules, drivers, file systems, system services) here. Remember to import the hardware configuration if applicable: imports = [ ../../nixos/hardware-configuration.nix ];.
    Add Flake Entry: Open flake.nix and add a new entry to the nixosConfigurations block:
    Nix

nixosConfigurations = {
  # ... existing systems ...

  # Entry for the new system
  new-server = mkNixosSystem {
    systemName = "new-server";        # Matches directory name
    hostname = "new-server-hostname"; # Desired network hostname
    userSettings = userHenhal;        # Choose the primary user (or define a new one)
    windowManager = "none";           # Choose WM ('none' for servers)
    # Add extraModules if needed (e.g., for specific server software)
    # extraModules = [ ... ];
  };
};

Rebuild: On the new machine, after cloning the flake, run nixos-rebuild targeting the new key:
Bash

    sudo nixos-rebuild switch --flake .#new-server

Adding a New User

    Define User Settings: Open flake.nix and add a new user settings block in the let section:
    Nix

userAdmin = rec {
  username = "admin";
  name = "Administrator";
  email = "admin@example.com";
  homeDirectory = "/home/admin";
  term = "foot";
  browser = "firefox";
  stateVersion = "24.11";
};

Create Home Manager Config: Create the user's directory and home.nix file: users/admin/home.nix. Populate it with their desired Home Manager configuration.
Add Standalone HM Config: Add an entry to homeConfigurations in flake.nix:
Nix

    homeConfigurations = {
      henhal = { ... }; # Existing user

      admin = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { ... }; # Define pkgs like for henhal
        modules = [ ./users/admin/home.nix ];
        extraSpecialArgs = {
           inherit system;
           userSettings = userAdmin; # Use the new user's settings
           unstable = unstablePkgs;
           windowManager = "none"; # Default for standalone
           # Add other needed inputs/args
        };
      };
    };

    Associate with System(s): Decide which system(s) this user will primarily use.
        New System: If adding a new system for this user, pass their settings: userSettings = userAdmin; when calling mkNixosSystem for that system (as shown in "Adding a New System").
        Existing System: If adding this user as the primary managed user for an existing system config (e.g., you want hp-server managed for admin instead of henhal), change the userSettings = userHenhal; line to userSettings = userAdmin; for the hp-server entry in nixosConfigurations. (Note: The current mkNixosSystem easily supports one primary HM-managed user per system config. Managing multiple users via HM on a single system config requires adjustments.)
        Secondary User: To just create the user account on a system without full HM integration via the flake's primary mechanism, add them normally via users.users.<new_username> = { ... }; within that system's NixOS modules.
    Rebuild:
        Run sudo nixos-rebuild switch --flake .#<system_key> for the system(s) associated with the new user.
        Run home-manager switch --flake .#<new_username> (e.g., .#admin) to activate their standalone config (run as the new user).

Maintenance
Updating Flake Inputs (Dependencies)

To update nixpkgs, home-manager, etc., to the latest versions compatible with your specified branches/tags:
Bash

cd ~/.dotfiles
nix flake update
# Then rebuild the desired system(s)
sudo nixos-rebuild switch --flake .#<system_key>

Updating Neovim Packages

(This section looks okay - it uses Neovim's internal managers)

    Update plugins:
    Vim Script

:Lazy update

Update language servers and tools:
Vim Script

    :Mason update

How It Works (Tool Configuration)

(This section describing npm/pip/cargo/go paths seems okay, assuming your Home Manager config still sets up those environment variables/configs)
Core Development Tools

Home Manager (./users/.../home.nix) installs core tools. Environment variables (e.g., NPM_CONFIG_PREFIX, CARGO_HOME, GOPATH) are typically set (often in session-variables.nix or similar) to direct where these tools install user-level packages, respecting the ~/.local/dev structure.
Package Management Examples

(Examples seem okay, assuming the underlying HM config enables this)

    NPM Global Packages: npm install -g typescript (Installs to ~/.local/dev/npm/global)
    Python Packages: pip install --user black (Installs to ~/.local/dev/python)
    Rust Packages: cargo install ripgrep (Installs to ~/.local/dev/cargo)
    Go Packages: go install golang.org/x/tools/gopls@latest (Installs to ~/.local/dev/go)

Adding New Tools
Adding System Packages/Services

    System-wide tools/services: Add to NixOS modules (e.g., environment.systemPackages in ./systems/<name>/configuration.nix or a common imported module). Then run sudo nixos-rebuild switch --flake .#<system_key>.
    User-specific tools (via Nix): Add to home.packages in ./users/<name>/home.nix. Then run sudo nixos-rebuild switch --flake .#<system_key> OR home-manager switch --flake .#<username>.

Adding Neovim Plugins / Language Servers

(This section looks okay)

Follow the existing instructions for modifying Neovim configuration and using :Lazy or :Mason.
Troubleshooting / Customization / Design

(These sections seem broadly applicable and likely don't need major changes unless specific issues arise from the flake structure).

Remember to git add ., git commit -m "...", and git push your changes in ~/.dotfiles regularly!his design allows you to maintain a stable system while having the flexibility to experiment with development tools and configurations in your user space.
```
