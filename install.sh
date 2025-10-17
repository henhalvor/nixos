#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install git if not present
if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Installing git...${NC}"
    nix-env -iA nixos.git
fi

# Clone repository if not already present
if [ ! -d "$HOME/.dotfiles" ]; then
    echo -e "${YELLOW}Cloning configuration...${NC}"
    git clone https://github.com/henhalvor/nixos.git ~/.dotfiles
fi

# Change to dotfiles directory
cd ~/.dotfiles || exit 1

# Enable Nix experimental features if needed
if ! grep -q "experimental-features = nix-command flakes" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
    echo -e "${YELLOW}Enabling Nix experimental features...${NC}"
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

# Prompt user for system configuration
echo -e "${YELLOW}Available system configurations:${NC}"
echo "1) workstation"
echo "2) lenovo-yoga-pro-7"
echo "3) desktop"
echo "4) hp-server"
echo "5) Enter custom configuration name"
echo ""
read -p "Select system configuration (1-5): " choice

case $choice in
    1)
        SYSTEM_CONFIG="workstation"
        ;;
    2)
        SYSTEM_CONFIG="lenovo-yoga-pro-7"
        ;;
    3)
        SYSTEM_CONFIG="desktop"
        ;;
    4)
        SYSTEM_CONFIG="hp-server"
        ;;
    5)
        read -p "Enter custom system configuration name: " SYSTEM_CONFIG
        if [ -z "$SYSTEM_CONFIG" ]; then
            echo -e "${RED}Configuration name cannot be empty. Exiting.${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Invalid selection. Exiting.${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Selected configuration: $SYSTEM_CONFIG${NC}"

# Check if system configuration directory exists
if [ ! -d "$HOME/.dotfiles/systems/$SYSTEM_CONFIG" ]; then
    echo -e "${RED}Error: System configuration '$SYSTEM_CONFIG' does not exist in systems/ directory.${NC}"
    echo -e "${RED}Available configurations:${NC}"
    ls ~/.dotfiles/systems/
    exit 1
fi

# Copy hardware configuration to the correct system directory
echo -e "${YELLOW}Copying hardware configuration to systems/$SYSTEM_CONFIG/...${NC}"
cp /etc/nixos/hardware-configuration.nix ~/.dotfiles/systems/$SYSTEM_CONFIG/hardware-configuration.nix

# Stage repo changes before system rebuild to avoid error
echo -e "${YELLOW}Staging repo changes...${NC}"
git add .

# Apply the system configuration
echo -e "${GREEN}Building and activating NixOS and home-manager configuration...${NC}"
sudo nixos-rebuild switch --flake .#$SYSTEM_CONFIG

# Remove Git from Shell (needs to be removed before installing rebuilding config otherwise the git shell install conflicts with the rebuild install)
nix-env -e git


echo -e "${GREEN}Installation complete! Please log out and back in for all changes to take effect.${NC}"
