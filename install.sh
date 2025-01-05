#!/bin/bash

# Usage:
# 1. Install git:    nix-env -iA nixos.git
# 2. Clone repo:     git clone https://github.com/henhalvor/nixos.git ~/.dotfiles
# 3. Go to dir:      cd ~/.dotfiles
# 4. Make executable: chmod +x install.sh
# 5. Run script:     ./install.sh
 


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
for cmd in nix git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}${cmd} not found. Please install ${cmd} first.${NC}"
        case $cmd in
            nix)
                echo "Visit https://nixos.org/download.html for installation instructions"
                ;;
            git)
                echo "Install git using: nix-env -iA nixos.git"
                ;;
        esac
        exit 1
    fi
done


# Check and enable Nix experimental features if needed
# This adds required settings to ~/.config/nix/nix.conf to enable:
# - nix-command: Enables new-style Nix commands
# - flakes: Enables the Nix flakes feature
if ! grep -q "experimental-features = nix-command flakes" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
    echo -e "${YELLOW}Enabling Nix experimental features (nix-command & flakes)...${NC}"
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

# Copy hardware configuration
echo -e "${YELLOW}Copying hardware configuration...${NC}"
cp /etc/nixos/hardware-configuration.nix nixos/hardware-configuration.nix

# Apply the system configuration
echo -e "${GREEN}Building and activating configuration...${NC}"
sudo nixos-rebuild switch --flake .#nixos

echo -e "${GREEN}Installation complete! Please log out and back in for all changes to take effect.${NC}"
