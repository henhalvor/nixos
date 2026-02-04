#!/bin/bash

# Improved NixOS installation script
# Usage: curl -L https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh | sh

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Setup logging
LOG_DIR="$HOME/.dotfiles-install-logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Log rotation: keep only last 10 logs
(ls -t "$LOG_DIR"/install-*.log 2>/dev/null | tail -n +11 | xargs -r rm --) 2>/dev/null || true

# Redirect all output to both console and log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log metadata
log_raw() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Helper functions
error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log_raw "ERROR: $1"
    echo ""
    echo -e "${YELLOW}Full log saved to: $LOG_FILE${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    log_raw "WARNING: $1"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
    log_raw "INFO: $1"
}

success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
    log_raw "SUCCESS: $1"
}

# Log script start
log_raw "========================================="
log_raw "NixOS Installation Script Started"
log_raw "========================================="
log_raw "Timestamp: $(date)"
log_raw "User: $USER"
log_raw "Home: $HOME"
log_raw "Working Directory: $(pwd)"
log_raw "Log File: $LOG_FILE"
log_raw "========================================="

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}NixOS Installation Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Log file: $LOG_FILE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verify we're running on NixOS
if [ ! -f /etc/NIXOS ]; then
    error "This script must be run on NixOS. Current OS: $(cat /etc/os-release | grep "^NAME=" | cut -d= -f2)"
fi

info "Running NixOS installation script..."
NIXOS_VERSION=$(nixos-version 2>/dev/null || echo 'unknown')
info "Version: $NIXOS_VERSION"
log_raw "NixOS Version: $NIXOS_VERSION"

# Install git if not present
if ! command -v git &> /dev/null; then
    warn "Git not found, installing temporarily..."
    log_raw "Git not found in PATH, using nix-shell"
    # Use nix-shell for temporary installation (cleaner than nix-env)
    if ! nix-shell -p git --run "git --version" &> /dev/null; then
        error "Failed to install git. Try manually: nix-shell -p git"
    fi
    # We'll use nix-shell for git commands below
    GIT_CMD="nix-shell -p git --run"
    log_raw "Git available via nix-shell"
else
    GIT_CMD=""
    GIT_VERSION=$(git --version)
    info "Git already installed"
    log_raw "Git found: $GIT_VERSION"
fi

# Clone repository if not already present
if [ ! -d "$HOME/.dotfiles" ]; then
    info "Cloning configuration repository..."
    log_raw "Cloning repository from: https://github.com/henhalvor/nixos.git"
    if [ -n "$GIT_CMD" ]; then
        $GIT_CMD "git clone https://github.com/henhalvor/nixos.git $HOME/.dotfiles" || error "Failed to clone repository"
    else
        git clone https://github.com/henhalvor/nixos.git "$HOME/.dotfiles" || error "Failed to clone repository"
    fi
    success "Repository cloned to ~/.dotfiles"
    log_raw "Repository cloned successfully"
else
    warn "~/.dotfiles already exists, skipping clone"
    log_raw "Directory ~/.dotfiles already exists"
    # Update existing repo
    cd "$HOME/.dotfiles" || error "Failed to enter ~/.dotfiles directory"
    info "Updating existing repository..."
    log_raw "Attempting to update repository"
    if [ -n "$GIT_CMD" ]; then
        if $GIT_CMD "git pull"; then
            log_raw "Repository updated successfully"
        else
            warn "Failed to update repository (continuing anyway)"
            log_raw "Repository update failed, continuing"
        fi
    else
        if git pull; then
            log_raw "Repository updated successfully"
        else
            warn "Failed to update repository (continuing anyway)"
            log_raw "Repository update failed, continuing"
        fi
    fi
fi

# Change to dotfiles directory
cd "$HOME/.dotfiles" || error "Failed to enter ~/.dotfiles directory"

# Enable Nix experimental features if needed
# Check both user and system configs
NEEDS_FLAKES=false
if ! nix show-config 2>/dev/null | grep -q "experimental-features.*flakes"; then
    NEEDS_FLAKES=true
fi

if [ "$NEEDS_FLAKES" = true ]; then
    warn "Nix flakes not enabled. Enabling for current user..."
    mkdir -p "$HOME/.config/nix"
    if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
        success "Enabled flakes in user config"
    fi
    
    # Note: System-wide flakes will be enabled after rebuild
    info "System-wide flakes will be enabled after NixOS rebuild"
fi

# Auto-detect current hostname
CURRENT_HOSTNAME=$(hostname)
info "Current hostname: $CURRENT_HOSTNAME"

# Dynamically discover available system configurations
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Available System Configurations${NC}"
echo -e "${BLUE}========================================${NC}"

CONFIGS=($(ls -1 systems/))
CONFIG_COUNT=${#CONFIGS[@]}

if [ $CONFIG_COUNT -eq 0 ]; then
    error "No system configurations found in systems/ directory"
fi

# Display configurations with details
for i in "${!CONFIGS[@]}"; do
    config="${CONFIGS[$i]}"
    config_num=$((i + 1))
    
    # Check if hostname matches
    match_indicator=""
    if [ "$config" = "$CURRENT_HOSTNAME" ]; then
        match_indicator=" ${GREEN}(matches current hostname)${NC}"
    fi
    
    # Check if host config exists
    host_file="hosts/${config}.nix"
    if [ -f "$host_file" ]; then
        # Try to extract session type from host config
        session=$(grep "session =" "$host_file" | head -1 | sed 's/.*"\(.*\)".*/\1/' || echo "unknown")
        echo -e "${config_num}) ${GREEN}${config}${NC} - Session: ${session}${match_indicator}"
    else
        echo -e "${config_num}) ${YELLOW}${config}${NC} - ${YELLOW}(no host config found)${NC}${match_indicator}"
    fi
done

echo "$((CONFIG_COUNT + 1))) Enter custom configuration name"
echo "$((CONFIG_COUNT + 2))) ${BLUE}Create new system/host configuration${NC}"
echo "$((CONFIG_COUNT + 3))) ${BLUE}View setup documentation${NC}"
echo ""

# Prompt user for system configuration
read -p "Select system configuration (1-$((CONFIG_COUNT + 3))): " choice

# Validate input is a number
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    error "Invalid input. Must be a number."
fi

# Handle create new config option
if [ "$choice" -eq $((CONFIG_COUNT + 2)) ]; then
    source "$(dirname "$0")/scripts/create-new-config.sh" || {
        # If script doesn't exist, show inline guide
        cat << 'EOF'

========================================
Creating New System/Host Configuration
========================================

To create a new system configuration, you need to create files in 3 locations:

1. HOST CONFIGURATION (hosts/my-system.nix)
   Defines: hostname, desktop session, monitors, hardware flags
   
2. SYSTEM DIRECTORY (systems/my-system/)
   Contains: configuration.nix, hardware-configuration.nix
   
3. FLAKE.NIX ENTRY
   Registers the configuration in flake.nix

========================================
Step-by-Step Guide
========================================

STEP 1: Create Host Configuration File
---------------------------------------
Create: hosts/my-system.nix

{
  hostname = "my-system";
  
  desktop = {
    session = "hyprland";  # hyprland | sway | gnome | none
    bar = null;            # null = use defaults
    lock = null;
    idle = null;
    
    monitors = [
      ",preferred,auto,1"  # Auto-detect monitor
    ];
  };
  
  hardware = {
    gpu = "nvidia";        # nvidia | amd | intel
    logitech = false;
    bluetooth = true;
  };
}

STEP 2: Create System Directory
--------------------------------
mkdir -p systems/my-system
cp systems/workstation/configuration.nix systems/my-system/

# Hardware config will be auto-generated during install

STEP 3: Register in flake.nix
------------------------------
Edit flake.nix and add to hosts section:

hosts = {
  workstation = import ./hosts/workstation.nix;
  my-system = import ./hosts/my-system.nix;  # ADD THIS
};

And to nixosConfigurations:

nixosConfigurations = {
  workstation = mkSystem { ... };
  my-system = mkSystem {                     # ADD THIS
    hostConfig = hosts.my-system;
    userSettings = users.henhal;
  };
};

STEP 4: Build and Test
-----------------------
sudo nixos-rebuild switch --flake .#my-system

========================================
Desktop Session Options
========================================

hyprland:  Modern tiling Wayland compositor (recommended)
sway:      Stable i3-like Wayland compositor  
gnome:     Full GNOME desktop environment
none:      Headless/server (no GUI)

========================================
For more details, see:
========================================
docs/DESKTOP_CONFIGURATION.md

EOF
        exit 0
    }
fi

# Handle documentation option
if [ "$choice" -eq $((CONFIG_COUNT + 3)) ]; then
    cat << 'EOF'

========================================
NixOS Dotfiles Setup Documentation
========================================

DIRECTORY STRUCTURE:
--------------------
.dotfiles/
├── hosts/                    # Host configs (pure data)
│   ├── workstation.nix       # Desktop PC
│   ├── lenovo-yoga-pro-7.nix # Laptop
│   └── hp-server.nix         # Server
│
├── systems/                  # Per-host NixOS configs
│   ├── workstation/
│   │   ├── configuration.nix
│   │   └── hardware-configuration.nix
│   └── ...
│
├── users/                    # User-specific configs
│   └── henhal/
│       └── home.nix          # Home Manager config
│
├── nixos/modules/            # Shared NixOS modules
├── home/modules/             # Shared Home Manager modules
└── flake.nix                 # Entry point

========================================
Configuration Layers
========================================

A complete system has 3 configuration files:

1. HOST CONFIG (hosts/my-pc.nix)
   - Hostname, desktop session, monitors
   - Hardware flags (GPU type, peripherals)
   - Pure data, no imports

2. SYSTEM CONFIG (systems/my-pc/)
   - NixOS system configuration
   - Imports shared modules
   - Hardware-specific settings

3. USER CONFIG (users/my-user/home.nix)
   - Home Manager configuration
   - User packages, dotfiles
   - Desktop applications

========================================
Creating New Configurations
========================================

NEW HOST/SYSTEM:
----------------
1. Create hosts/my-system.nix (see template below)
2. Create systems/my-system/configuration.nix
3. Register in flake.nix hosts and nixosConfigurations
4. Run: sudo nixos-rebuild switch --flake .#my-system

NEW USER:
---------
1. Create users/my-username/home.nix
2. Define user settings in flake.nix users section
3. Reference in nixosConfigurations
4. Run: sudo nixos-rebuild switch --flake .#my-system

========================================
Host Configuration Template
========================================

{
  hostname = "my-system";
  
  desktop = {
    session = "hyprland";  # hyprland|sway|gnome|none
    bar = null;            # null = smart defaults
    lock = null;
    idle = null;
    
    # Hyprland monitor format
    monitors = [
      "DP-1,2560x1440@144,0x0,1"
    ];
    
    # Optional: workspace rules
    workspaceRules = [
      "1, monitor:DP-1, default:true"
    ];
  };
  
  hardware = {
    gpu = "nvidia";        # nvidia|amd|intel
    logitech = true;       # Logitech wireless
    bluetooth = true;      # Bluetooth support
  };
}

========================================
User Settings Template
========================================

In flake.nix users section:

my-user = rec {
  username = "myname";
  name = "My Full Name";
  email = "me@example.com";
  homeDirectory = "/home/\${username}";
  term = "kitty";         # kitty|alacritty|wezterm
  browser = "vivaldi";    # vivaldi|firefox|zen
  stateVersion = "25.05";
  
  stylixTheme = {
    scheme = "gruvbox-dark-hard";
    wallpaper = "starry-sky.png";
  };
};

========================================
Available Desktop Sessions
========================================

hyprland:
  - Modern Wayland tiling compositor
  - Best for gaming, multi-monitor setups
  - Highly customizable, great performance
  - Default bar: hyprpanel
  
sway:
  - Mature i3-compatible Wayland compositor
  - Excellent for laptops (battery efficient)
  - Stable, well-documented
  - Default bar: waybar

gnome:
  - Full-featured desktop environment
  - Best for users wanting traditional desktop
  - All tools built-in
  
none:
  - Headless/server mode
  - No graphical desktop
  - SSH/terminal only

========================================
Desktop Component Options
========================================

All options support null (smart defaults):

session:       hyprland | sway | gnome | none
bar:           hyprpanel | waybar | none | null
lock:          hyprlock | swaylock | loginctl | none | null
idle:          hypridle | swayidle | none | null
clipboard:     clipman | cliphist | none | null
screenshotTool: grimblast | grim | none | null
notifications: mako | dunst | none | null
nightLight:    gammastep | redshift | none | null

NOTE: idle != "none" requires lock != "none"

========================================
Quick Reference Commands
========================================

# Rebuild system
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .#my-system

# Test without switching
sudo nixos-rebuild test --flake .#my-system

# Update flake inputs
nix flake update

# Check flake for errors
nix flake check

# View build logs
journalctl -xe

# View installation logs
./scripts/view-install-logs.sh

========================================
Detailed Documentation
========================================

Desktop Configuration:  docs/DESKTOP_CONFIGURATION.md
Installation Guide:     Run this script again
Troubleshooting:        docs/DESKTOP_CONFIGURATION.md#troubleshooting

EOF
    exit 0
fi

# Handle custom config option
if [ "$choice" -eq $((CONFIG_COUNT + 1)) ]; then
    read -p "Enter custom system configuration name: " SYSTEM_CONFIG
    if [ -z "$SYSTEM_CONFIG" ]; then
        error "Configuration name cannot be empty"
    fi
elif [ "$choice" -ge 1 ] && [ "$choice" -le $CONFIG_COUNT ]; then
    SYSTEM_CONFIG="${CONFIGS[$((choice - 1))]}"
else
    error "Invalid selection. Must be between 1 and $((CONFIG_COUNT + 3))"
fi

success "Selected configuration: $SYSTEM_CONFIG"
log_raw "User selected configuration: $SYSTEM_CONFIG"

# Check if system configuration directory exists
if [ ! -d "systems/$SYSTEM_CONFIG" ]; then
    log_raw "ERROR: Configuration directory not found: systems/$SYSTEM_CONFIG"
    error "System configuration 'systems/$SYSTEM_CONFIG' does not exist.\nAvailable: $(ls -m systems/)"
fi
log_raw "Configuration directory exists: systems/$SYSTEM_CONFIG"

# Check if hardware-configuration.nix exists in /etc/nixos
if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    error "Hardware configuration not found at /etc/nixos/hardware-configuration.nix. Generate it with: sudo nixos-generate-config"
fi

# Backup existing hardware-configuration.nix if it exists
if [ -f "systems/$SYSTEM_CONFIG/hardware-configuration.nix" ]; then
    backup_file="systems/$SYSTEM_CONFIG/hardware-configuration.nix.backup.$(date +%Y%m%d_%H%M%S)"
    warn "Backing up existing hardware-configuration.nix to $backup_file"
    log_raw "Backing up existing hardware config to: $backup_file"
    cp "systems/$SYSTEM_CONFIG/hardware-configuration.nix" "$backup_file"
    log_raw "Backup created successfully"
fi

# Copy hardware configuration to the correct system directory
info "Copying hardware configuration to systems/$SYSTEM_CONFIG/..."
log_raw "Copying /etc/nixos/hardware-configuration.nix to systems/$SYSTEM_CONFIG/"
cp /etc/nixos/hardware-configuration.nix "systems/$SYSTEM_CONFIG/hardware-configuration.nix" || error "Failed to copy hardware configuration"
success "Hardware configuration copied"
log_raw "Hardware configuration copied successfully"

# Validate flake before rebuild
info "Validating flake configuration..."
log_raw "Running: nix flake check --no-build"
if nix flake check --no-build 2>&1 | tee -a "$LOG_FILE"; then
    log_raw "Flake validation passed"
else
    warn "Flake check failed (this might be normal on first run)"
    log_raw "Flake validation failed (continuing anyway)"
fi

# Show what will be built
info "Configuration to be built: .#$SYSTEM_CONFIG"
log_raw "Configuration to build: .#$SYSTEM_CONFIG"
echo ""
read -p "Proceed with system rebuild? This will modify your system. [y/N]: " -n 1 -r
echo
log_raw "User confirmation: $REPLY"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Installation cancelled by user"
    log_raw "Installation cancelled by user"
    exit 0
fi
log_raw "User confirmed, proceeding with rebuild"

# Stage repo changes before system rebuild to avoid dirty git tree errors
info "Staging repository changes..."
log_raw "Running: git add ."
if [ -n "$GIT_CMD" ]; then
    if $GIT_CMD "git add ."; then
        log_raw "Changes staged successfully"
    else
        warn "Failed to stage changes (continuing anyway)"
        log_raw "Failed to stage changes"
    fi
else
    if git add .; then
        log_raw "Changes staged successfully"
    else
        warn "Failed to stage changes (continuing anyway)"
        log_raw "Failed to stage changes"
    fi
fi

# Apply the system configuration
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building NixOS Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
info "This may take several minutes..."
log_raw "========================================="
log_raw "Starting NixOS rebuild"
log_raw "========================================="
log_raw "Command: sudo nixos-rebuild switch --flake .#$SYSTEM_CONFIG --show-trace"

# Use sudo nixos-rebuild with explicit flake reference
REBUILD_START=$(date +%s)
if sudo nixos-rebuild switch --flake ".#$SYSTEM_CONFIG" --show-trace 2>&1 | tee -a "$LOG_FILE"; then
    REBUILD_END=$(date +%s)
    REBUILD_DURATION=$((REBUILD_END - REBUILD_START))
    success "NixOS configuration applied successfully!"
    log_raw "NixOS rebuild completed successfully in ${REBUILD_DURATION}s"
else
    REBUILD_END=$(date +%s)
    REBUILD_DURATION=$((REBUILD_END - REBUILD_START))
    log_raw "NixOS rebuild failed after ${REBUILD_DURATION}s"
    error "NixOS rebuild failed. Check the error output above."
fi

# Cleanup: We don't need to manually remove git anymore
# The system configuration will manage packages declaratively

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. ${YELLOW}Log out and log back in${NC} for all changes to take effect"
echo -e "  2. Your dotfiles are in: ${GREEN}~/.dotfiles${NC}"
echo -e "  3. To rebuild in the future: ${BLUE}cd ~/.dotfiles && sudo nixos-rebuild switch --flake .#$SYSTEM_CONFIG${NC}"
echo ""
echo -e "Configuration applied: ${GREEN}$SYSTEM_CONFIG${NC}"
echo -e "System hostname: ${GREEN}$CURRENT_HOSTNAME${NC}"
echo -e "Installation log: ${YELLOW}$LOG_FILE${NC}"
echo ""

if [ "$SYSTEM_CONFIG" != "$CURRENT_HOSTNAME" ]; then
    warn "Selected config ($SYSTEM_CONFIG) doesn't match hostname ($CURRENT_HOSTNAME)"
    echo -e "Consider running: ${BLUE}sudo hostnamectl set-hostname $SYSTEM_CONFIG${NC}"
    echo ""
    log_raw "WARNING: Config name ($SYSTEM_CONFIG) doesn't match hostname ($CURRENT_HOSTNAME)"
fi

success "Enjoy your NixOS system!"

# Log completion
log_raw "========================================="
log_raw "Installation completed successfully"
log_raw "Configuration: $SYSTEM_CONFIG"
log_raw "Hostname: $CURRENT_HOSTNAME"
log_raw "Timestamp: $(date)"
log_raw "========================================="
