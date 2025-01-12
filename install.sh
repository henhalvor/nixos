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

# Copy hardware configuration
echo -e "${YELLOW}Copying hardware configuration...${NC}"
cp /etc/nixos/hardware-configuration.nix nixos/hardware-configuration.nix

# Remove Git from Shell (needs to be removed before installing rebuilding config otherwise the git shell install conflicts with the rebuild install)
nix-env -e git

# Apply the system configuration
echo -e "${GREEN}Building and activating NixOS configuration...${NC}"
sudo nixos-rebuild switch --flake .#nixos

# Apply home-manager configuration
echo -e "${GREEN}Building and activating home-manager configuration...${NC}"
home-manager switch --flake .#henhal

echo -e "${GREEN}Installation complete! Please log out and back in for all changes to take effect.${NC}"
