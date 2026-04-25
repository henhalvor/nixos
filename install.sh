#!/bin/bash

# NixOS Installation Script (Dendritic Pattern)
# Usage: curl -L https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh | sh
#
# This flake uses the Dendritic Pattern with flake-parts + import-tree.
# Hosts are defined as directories under hosts/<name>/ with:
#   default.nix        — entry point (nixosConfigurations.<name>)
#   configuration.nix  — system config (imports features by module name)
#   hardware.nix       — hardware config (wrapped in flake-parts boilerplate)

set -e
set -o pipefail

# Setup logging
LOG_DIR="$HOME/.dotfiles-install-logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$LOG_DIR"

# Log rotation: keep only last 10 logs
(ls -t "$LOG_DIR"/install-*.log 2>/dev/null | tail -n +11 | xargs -r rm --) 2>/dev/null || true

exec > >(tee -a "$LOG_FILE")
exec 2>&1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_raw() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error()   { echo -e "${RED}ERROR: $1${NC}" >&2; log_raw "ERROR: $1"; echo -e "${YELLOW}Full log: $LOG_FILE${NC}"; exit 1; }
warn()    { echo -e "${YELLOW}WARNING: $1${NC}" >&2; log_raw "WARNING: $1"; }
info()    { echo -e "${BLUE}INFO: $1${NC}"; log_raw "INFO: $1"; }
success() { echo -e "${GREEN}SUCCESS: $1${NC}"; log_raw "SUCCESS: $1"; }

log_raw "========================================="
log_raw "NixOS Installation Script Started"
log_raw "Timestamp: $(date)"
log_raw "User: $USER | Home: $HOME | CWD: $(pwd)"
log_raw "========================================="

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}NixOS Installation Script${NC}"
echo -e "${BLUE}(Dendritic Pattern — flake-parts)${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Log file: $LOG_FILE${NC}"
echo ""

# ── Verify NixOS ──────────────────────────────────────────────
if [ ! -f /etc/NIXOS ]; then
    error "This script must be run on NixOS. Current OS: $(grep '^NAME=' /etc/os-release | cut -d= -f2)"
fi

NIXOS_VERSION=$(nixos-version 2>/dev/null || echo 'unknown')
info "NixOS version: $NIXOS_VERSION"

# ── Ensure git is available ───────────────────────────────────
if ! command -v git &> /dev/null; then
    warn "Git not found, installing temporarily via nix-shell..."
    if ! nix-shell -p git --run "git --version" &> /dev/null; then
        error "Failed to get git. Try: nix-shell -p git"
    fi
    GIT_CMD="nix-shell -p git --run"
else
    GIT_CMD=""
    info "Git already installed"
fi

run_git() {
    if [ -n "$GIT_CMD" ]; then
        $GIT_CMD "$*"
    else
        eval "$@"
    fi
}

# ── Clone or update repository ────────────────────────────────
REPO_URL="https://github.com/henhalvor/nixos.git"
if [ ! -d "$HOME/.dotfiles" ]; then
    info "Cloning configuration repository..."
    run_git "git clone $REPO_URL $HOME/.dotfiles" || error "Failed to clone repository"
    success "Repository cloned to ~/.dotfiles"
else
    warn "~/.dotfiles already exists, skipping clone"
    cd "$HOME/.dotfiles" || error "Failed to enter ~/.dotfiles"
    info "Pulling latest changes..."
    run_git "git pull" || warn "Failed to update repository (continuing anyway)"
fi

cd "$HOME/.dotfiles" || error "Failed to enter ~/.dotfiles"

# ── Enable flakes if needed ───────────────────────────────────
if ! nix show-config 2>/dev/null | grep -q "experimental-features.*flakes"; then
    warn "Nix flakes not enabled. Enabling for current user..."
    mkdir -p "$HOME/.config/nix"
    if ! grep -q "experimental-features" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
        echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
        success "Enabled flakes in user config"
    fi
    info "System-wide flakes will be enabled after NixOS rebuild"
fi

# ── Discover available hosts ──────────────────────────────────
CURRENT_HOSTNAME=$(hostname)
info "Current hostname: $CURRENT_HOSTNAME"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Available Host Configurations${NC}"
echo -e "${BLUE}========================================${NC}"

# Hosts are directories under hosts/ containing default.nix
CONFIGS=()
for dir in hosts/*/; do
    [ -f "${dir}default.nix" ] && CONFIGS+=("$(basename "$dir")")
done

CONFIG_COUNT=${#CONFIGS[@]}
if [ $CONFIG_COUNT -eq 0 ]; then
    error "No host configurations found in hosts/ directory"
fi

for i in "${!CONFIGS[@]}"; do
    config="${CONFIGS[$i]}"
    config_num=$((i + 1))

    match_indicator=""
    if [ "$config" = "$CURRENT_HOSTNAME" ]; then
        match_indicator=" ${GREEN}(matches current hostname)${NC}"
    fi

    # Show which files exist for this host
    files=""
    [ -f "hosts/$config/hardware.nix" ] && files="hw " || files="${YELLOW}no-hw${NC} "
    [ -f "hosts/$config/configuration.nix" ] && files="${files}cfg" || files="${files}${YELLOW}no-cfg${NC}"

    echo -e "  ${config_num}) ${GREEN}${config}${NC}  [${files}]${match_indicator}"
done

echo ""
echo -e "  $((CONFIG_COUNT + 1))) Enter custom configuration name"
echo -e "  $((CONFIG_COUNT + 2))) ${BLUE}Create new host configuration${NC}"
echo -e "  $((CONFIG_COUNT + 3))) ${BLUE}View setup documentation${NC}"
echo ""

if ! read -p "Select host configuration (1-$((CONFIG_COUNT + 3))): " choice; then
    error "Failed to read input. Are you running interactively? (curl | sh requires a TTY)"
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    error "Invalid input. Must be a number."
fi

# ── Handle: Create new host ──────────────────────────────────
if [ "$choice" -eq $((CONFIG_COUNT + 2)) ]; then
    cat << 'EOF'

========================================
Creating a New Host (Dendritic Pattern)
========================================

Each host lives in its own directory under hosts/<name>/ with 3 files:

  hosts/my-machine/
  ├── default.nix          # Entry point — defines nixosConfigurations.my-machine
  ├── configuration.nix    # System config — imports features by module name
  └── hardware.nix         # Hardware config — wrapped in flake-parts boilerplate

STEP 1: Create the host directory
----------------------------------
  mkdir -p hosts/my-machine

STEP 2: Create default.nix (entry point)
------------------------------------------
  Copy from an existing host and change the names:

  {self, inputs, ...}: {
    flake.nixosConfigurations.my-machine = inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        inherit inputs self;
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      };
      modules = [ self.nixosModules.myMachineConfig ];
    };
  }

STEP 3: Create configuration.nix
----------------------------------
  Define a flake-parts nixosModule that imports the features you want:

  {self, inputs, ...}: {
    flake.nixosModules.myMachineConfig = {pkgs, ...}: {
      imports = [
        self.nixosModules.myMachineHardware
        self.nixosModules.base
        self.nixosModules.bootloader
        self.nixosModules.networking
        inputs.home-manager.nixosModules.home-manager
        # ... add features by module name (see docs/FEATURES.md)
      ];
      networking.hostName = "my-machine";
    };
  }

STEP 4: Create hardware.nix
-----------------------------
  This script can generate it for you (option during install).
  Or manually wrap your /etc/nixos/hardware-configuration.nix:

  {...}: {
    flake.nixosModules.myMachineHardware = {config, lib, modulesPath, ...}: {
      imports = [(modulesPath + "/installer/scan/not-detected.nix")];
      # ... paste hardware config body here ...
    };
  }

STEP 5: Build
--------------
  sudo nixos-rebuild switch --flake .#my-machine

NOTE: import-tree automatically discovers all .nix files — no flake.nix edits needed!

For feature reference, see: docs/FEATURES.md
For architecture details, see: docs/ARCHITECTURE.md

EOF
    exit 0
fi

# ── Handle: View documentation ───────────────────────────────
if [ "$choice" -eq $((CONFIG_COUNT + 3)) ]; then
    cat << 'EOF'

========================================
NixOS Dotfiles — Dendritic Pattern
========================================

ARCHITECTURE:
  This flake uses flake-parts + import-tree. Every .nix file under
  modules/ and hosts/ is auto-discovered and loaded as a flake-parts
  module. Components reference each other by name, not file path.

DIRECTORY STRUCTURE:
  .dotfiles/
  ├── flake.nix              # Flake entry — inputs + import-tree
  ├── hosts/                 # One subdirectory per machine
  │   ├── workstation/       #   default.nix, configuration.nix, hardware.nix
  │   ├── lenovo-yoga-pro-7/
  │   └── hp-server/
  ├── modules/               # Shared feature modules
  │   ├── base.nix           #   Core NixOS settings
  │   ├── users/             #   User definitions
  │   └── features/          #   Desktop, apps, services, dev tools
  ├── secrets/               # Encrypted secrets (sops-nix)
  ├── assets/                # Wallpapers, icons, static files
  └── docs/                  # Documentation

HOST FILES (hosts/<name>/):
  default.nix        Entry point — defines nixosConfigurations.<name>
  configuration.nix  System config — imports features by module name
  hardware.nix       Hardware config (from nixos-generate-config, wrapped)

KEY CONCEPTS:
  • Modules are referenced by NAME (self.nixosModules.foo), not path
  • import-tree auto-discovers all .nix files recursively
  • No flake.nix edits needed when adding features or hosts
  • Features can define both NixOS + Home Manager config in one file
  • Secrets managed via sops-nix (see docs/SECRETS.md)

QUICK REFERENCE:
  Rebuild:          sudo nixos-rebuild switch --flake .#<hostname>
  Test (no switch): sudo nixos-rebuild test --flake .#<hostname>
  Update inputs:    nix flake update
  Edit secrets:     nix-shell -p sops --run "sops secrets/secrets.yaml"

DOCUMENTATION:
  docs/ARCHITECTURE.md   — Dendritic pattern deep-dive
  docs/FEATURES.md       — Complete feature reference
  docs/HOSTS.md          — Per-host breakdown
  docs/SECRETS.md        — Secrets management guide

EOF
    exit 0
fi

# ── Handle: Custom name or selection ─────────────────────────
if [ "$choice" -eq $((CONFIG_COUNT + 1)) ]; then
    read -p "Enter host configuration name: " SYSTEM_CONFIG
    if [ -z "$SYSTEM_CONFIG" ]; then
        error "Configuration name cannot be empty"
    fi
elif [ "$choice" -ge 1 ] && [ "$choice" -le $CONFIG_COUNT ]; then
    SYSTEM_CONFIG="${CONFIGS[$((choice - 1))]}"
else
    error "Invalid selection. Must be between 1 and $((CONFIG_COUNT + 3))"
fi

success "Selected configuration: $SYSTEM_CONFIG"
log_raw "Selected: $SYSTEM_CONFIG"

# ── Validate host directory ──────────────────────────────────
if [ ! -d "hosts/$SYSTEM_CONFIG" ]; then
    error "Host directory 'hosts/$SYSTEM_CONFIG' does not exist.\nAvailable: $(printf '%s ' "${CONFIGS[@]}")"
fi

if [ ! -f "hosts/$SYSTEM_CONFIG/default.nix" ]; then
    error "Missing entry point: hosts/$SYSTEM_CONFIG/default.nix"
fi

if [ ! -f "hosts/$SYSTEM_CONFIG/configuration.nix" ]; then
    error "Missing system config: hosts/$SYSTEM_CONFIG/configuration.nix"
fi

# ── Hardware configuration ───────────────────────────────────
if [ ! -f "hosts/$SYSTEM_CONFIG/hardware.nix" ]; then
    warn "No hardware.nix found for $SYSTEM_CONFIG"

    if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
        error "No hardware config found. Generate one with: sudo nixos-generate-config"
    fi

    info "Generating hardware.nix from /etc/nixos/hardware-configuration.nix..."

    # Convert hostname to camelCase module name (e.g. lenovo-yoga-pro-7 → lenovoYogaPro7)
    MODULE_NAME=$(echo "$SYSTEM_CONFIG" | sed -E 's/(^|-)(.)/\U\2/g; s/^(.)/\L\1/')
    MODULE_NAME="${MODULE_NAME}Hardware"

    # Extract the body of the hardware config (everything inside the { ... } block)
    HW_BODY=$(sed '1,/{/d; $d' /etc/nixos/hardware-configuration.nix)

    cat > "hosts/$SYSTEM_CONFIG/hardware.nix" << HWEOF
# ${SYSTEM_CONFIG} — hardware configuration
# Generated by install.sh from /etc/nixos/hardware-configuration.nix
{...}: {
  flake.nixosModules.${MODULE_NAME} = {config, lib, modulesPath, ...}: {
${HW_BODY}
  };
}
HWEOF

    success "Generated hosts/$SYSTEM_CONFIG/hardware.nix (module: ${MODULE_NAME})"
    warn "Review the generated file — you may need to adjust the module name"
    warn "to match what configuration.nix imports"
else
    info "Hardware config exists: hosts/$SYSTEM_CONFIG/hardware.nix"

    # Notify if /etc/nixos version is newer
    if [ -f /etc/nixos/hardware-configuration.nix ]; then
        HW_MTIME=$(stat -c %Y "hosts/$SYSTEM_CONFIG/hardware.nix")
        ETC_MTIME=$(stat -c %Y /etc/nixos/hardware-configuration.nix)
        if [ "$ETC_MTIME" -gt "$HW_MTIME" ]; then
            warn "/etc/nixos/hardware-configuration.nix is newer than hosts/$SYSTEM_CONFIG/hardware.nix"
            echo -e "  ${YELLOW}If you've changed hardware, update hosts/$SYSTEM_CONFIG/hardware.nix manually.${NC}"
            echo ""
        fi
    fi
fi

# ── Validate flake ───────────────────────────────────────────
info "Validating flake configuration..."
if nix flake check --no-build 2>&1 | tee -a "$LOG_FILE"; then
    log_raw "Flake validation passed"
else
    warn "Flake check reported issues (this might be normal)"
fi

# ── Confirm and build ────────────────────────────────────────
echo ""
info "Configuration to build: .#$SYSTEM_CONFIG"
echo ""
read -p "Proceed with system rebuild? This will modify your system. [y/N]: " -n 1 -r
echo
log_raw "User confirmation: $REPLY"
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Installation cancelled by user"
    exit 0
fi

# Stage changes to avoid dirty-tree warnings
info "Staging repository changes..."
run_git "git add ." || warn "Failed to stage changes (continuing anyway)"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Building NixOS Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
info "This may take several minutes on first build..."
log_raw "Command: sudo nixos-rebuild switch --flake .#$SYSTEM_CONFIG --show-trace"

REBUILD_START=$(date +%s)
if sudo nixos-rebuild switch --flake ".#$SYSTEM_CONFIG" --show-trace 2>&1 | tee -a "$LOG_FILE"; then
    REBUILD_DURATION=$(( $(date +%s) - REBUILD_START ))
    success "NixOS configuration applied successfully! (${REBUILD_DURATION}s)"
else
    REBUILD_DURATION=$(( $(date +%s) - REBUILD_START ))
    log_raw "NixOS rebuild failed after ${REBUILD_DURATION}s"
    error "NixOS rebuild failed. Check the error output above."
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Next steps:"
echo -e "  1. ${YELLOW}Log out and log back in${NC} for all changes to take effect"
echo -e "  2. Your dotfiles are in: ${GREEN}~/.dotfiles${NC}"
echo -e "  3. To rebuild: ${BLUE}cd ~/.dotfiles && sudo nixos-rebuild switch --flake .#$SYSTEM_CONFIG${NC}"
echo ""
echo -e "Configuration: ${GREEN}$SYSTEM_CONFIG${NC}"
echo -e "Hostname: ${GREEN}$CURRENT_HOSTNAME${NC}"
echo -e "Log: ${YELLOW}$LOG_FILE${NC}"
echo ""

if [ "$SYSTEM_CONFIG" != "$CURRENT_HOSTNAME" ]; then
    warn "Selected config ($SYSTEM_CONFIG) doesn't match hostname ($CURRENT_HOSTNAME)"
    echo -e "  The NixOS config sets the hostname declaratively."
    echo -e "  If this is a fresh install, it will update on next boot."
    echo ""
fi

success "Enjoy your NixOS system!"
log_raw "========================================="
log_raw "Installation completed: $SYSTEM_CONFIG"
log_raw "========================================="
