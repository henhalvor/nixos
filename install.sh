#!/bin/bash

# Usage run this command in your terminal:
# nix-env -iA nixos.git && git clone https://github.com/henhalvor/nixos.git ~/.dotfiles && cd ~/.dotfiles && chmod +x install.sh && ./install.sh
 


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

# Check if ~/.dotfiles already exists
if [ -d "$HOME/.dotfiles" ]; then
    echo -e "${RED}~/.dotfiles directory already exists. Please remove or backup first.${NC}"
    exit 1
fi

# Clone the repository
echo -e "${GREEN}Cloning dotfiles repository...${NC}"
git clone https://github.com/henhalvor/nixos.git "$HOME/.dotfiles"

# Change to the dotfiles directory
cd "$HOME/.dotfiles"

# Check and enable Nix experimental features if needed
# This adds required settings to ~/.config/nix/nix.conf to enable:
# - nix-command: Enables new-style Nix commands
# - flakes: Enables the Nix flakes feature
if ! grep -q "experimental-features = nix-command flakes" "$HOME/.config/nix/nix.conf" 2>/dev/null; then
    echo -e "${YELLOW}Enabling Nix experimental features (nix-command & flakes)...${NC}"
    mkdir -p "$HOME/.config/nix"
    echo "experimental-features = nix-command flakes" >> "$HOME/.config/nix/nix.conf"
fi

# Apply the system configuration
echo -e "${GREEN}Building and activating configuration...${NC}"
sudo nixos-rebuild switch --flake .#nixos

echo -e "${GREEN}Installation complete! Please log out and back in for all changes to take effect.${NC}"
