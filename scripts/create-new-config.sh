#!/bin/bash

# Interactive wizard for creating new NixOS configurations
# Called from install.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}New Configuration Wizard${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Step 1: What to create
echo -e "${BLUE}What would you like to create?${NC}"
echo "1) New host/system configuration"
echo "2) New user configuration"
echo "3) Both (new system + new user)"
echo ""
read -p "Selection (1-3): " creation_type

case $creation_type in
    1) CREATE_HOST=true; CREATE_USER=false ;;
    2) CREATE_HOST=false; CREATE_USER=true ;;
    3) CREATE_HOST=true; CREATE_USER=true ;;
    *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
esac

# ============================================
# CREATE HOST CONFIGURATION
# ============================================

if [ "$CREATE_HOST" = true ]; then
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Host Configuration Setup${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # Hostname
    echo ""
    read -p "Hostname (e.g., my-laptop): " HOSTNAME
    if [ -z "$HOSTNAME" ]; then
        echo -e "${RED}Hostname cannot be empty${NC}"
        exit 1
    fi
    
    # Check if exists
    if [ -f "hosts/${HOSTNAME}.nix" ]; then
        echo -e "${YELLOW}Warning: hosts/${HOSTNAME}.nix already exists${NC}"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Desktop session
    echo ""
    echo -e "${BLUE}Desktop Session:${NC}"
    echo "1) hyprland  - Modern Wayland compositor (recommended for desktops)"
    echo "2) sway      - Stable i3-like compositor (good for laptops)"
    echo "3) gnome     - Full GNOME desktop environment"
    echo "4) none      - Headless/server (no GUI)"
    echo ""
    read -p "Selection (1-4): " session_choice
    
    case $session_choice in
        1) SESSION="hyprland" ;;
        2) SESSION="sway" ;;
        3) SESSION="gnome" ;;
        4) SESSION="none" ;;
        *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
    esac
    
    # GPU type
    echo ""
    echo -e "${BLUE}GPU Type:${NC}"
    echo "1) nvidia"
    echo "2) amd"
    echo "3) intel"
    echo "4) none/integrated"
    echo ""
    read -p "Selection (1-4): " gpu_choice
    
    case $gpu_choice in
        1) GPU="nvidia" ;;
        2) GPU="amd" ;;
        3) GPU="intel" ;;
        4) GPU="" ;;
        *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
    esac
    
    # Peripherals
    echo ""
    read -p "Enable Logitech wireless support? [y/N]: " -n 1 -r
    echo
    LOGITECH="false"
    [[ $REPLY =~ ^[Yy]$ ]] && LOGITECH="true"
    
    read -p "Enable Bluetooth? [y/N]: " -n 1 -r
    echo
    BLUETOOTH="false"
    [[ $REPLY =~ ^[Yy]$ ]] && BLUETOOTH="true"
    
    # Create host config file
    echo ""
    echo -e "${YELLOW}Creating hosts/${HOSTNAME}.nix...${NC}"
    
    cat > "hosts/${HOSTNAME}.nix" << EOF
{
  hostname = "${HOSTNAME}";

  desktop = {
    session = "${SESSION}";
    bar = null;            # null = use session defaults
    lock = null;
    idle = null;
    notifications = null;

    monitors = [
      ",preferred,auto,1"  # Auto-detect monitors
    ];
EOF

    if [ "$SESSION" = "hyprland" ]; then
        cat >> "hosts/${HOSTNAME}.nix" << 'EOF'

    # Optional: Add workspace rules
    workspaceRules = [
      "1, monitor:DP-1, default:true"
    ];
EOF
    elif [ "$SESSION" = "sway" ]; then
        cat >> "hosts/${HOSTNAME}.nix" << 'EOF'

    # Optional: Sway output configuration
    outputs = {
      # "eDP-1" = {
      #   resolution = "1920x1080@60Hz";
      #   position = "0,0";
      #   scale = 1.0;
      # };
    };
EOF
    fi

    cat >> "hosts/${HOSTNAME}.nix" << EOF
  };

  hardware = {
EOF

    if [ -n "$GPU" ]; then
        cat >> "hosts/${HOSTNAME}.nix" << EOF
    gpu = "${GPU}";
EOF
    fi

    cat >> "hosts/${HOSTNAME}.nix" << EOF
    logitech = ${LOGITECH};
    bluetooth = ${BLUETOOTH};
  };
}
EOF

    echo -e "${GREEN}✓ Created hosts/${HOSTNAME}.nix${NC}"
    
    # Create systems directory
    echo ""
    echo -e "${YELLOW}Creating systems/${HOSTNAME}/...${NC}"
    mkdir -p "systems/${HOSTNAME}"
    
    # Copy template configuration.nix
    if [ -f "systems/workstation/configuration.nix" ]; then
        cp "systems/workstation/configuration.nix" "systems/${HOSTNAME}/configuration.nix"
        echo -e "${GREEN}✓ Created systems/${HOSTNAME}/configuration.nix (from template)${NC}"
    else
        # Create minimal configuration.nix
        cat > "systems/${HOSTNAME}/configuration.nix" << 'EOF'
{
  config,
  pkgs,
  userSettings,
  desktop,
  hostConfig,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../nixos/default.nix
    ../../nixos/modules/networking.nix
  ];

  # Add system-specific imports and configuration here
}
EOF
        echo -e "${GREEN}✓ Created systems/${HOSTNAME}/configuration.nix (minimal)${NC}"
    fi
    
    echo -e "${YELLOW}Note: hardware-configuration.nix will be auto-generated during install${NC}"
    
    # Show flake.nix instructions
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Manual Step Required: Update flake.nix${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Add to the ${BLUE}hosts${NC} section:"
    echo ""
    echo -e "${GREEN}  hosts = {${NC}"
    echo -e "    workstation = import ./hosts/workstation.nix;"
    echo -e "${YELLOW}    ${HOSTNAME} = import ./hosts/${HOSTNAME}.nix;  # ADD THIS${NC}"
    echo -e "${GREEN}  };${NC}"
    echo ""
    echo -e "Add to the ${BLUE}nixosConfigurations${NC} section:"
    echo ""
    echo -e "${GREEN}  nixosConfigurations = {${NC}"
    echo -e "    workstation = mkSystem { ... };"
    echo -e "${YELLOW}    ${HOSTNAME} = mkSystem {              # ADD THIS${NC}"
    echo -e "${YELLOW}      hostConfig = hosts.${HOSTNAME};${NC}"
    echo -e "${YELLOW}      userSettings = users.henhal;  # or your user${NC}"
    echo -e "${YELLOW}    };${NC}"
    echo -e "${GREEN}  };${NC}"
    echo ""
fi

# ============================================
# CREATE USER CONFIGURATION
# ============================================

if [ "$CREATE_USER" = true ]; then
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}User Configuration Setup${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    # Username
    echo ""
    read -p "Username (e.g., john): " USERNAME
    if [ -z "$USERNAME" ]; then
        echo -e "${RED}Username cannot be empty${NC}"
        exit 1
    fi
    
    # Check if exists
    if [ -d "users/${USERNAME}" ]; then
        echo -e "${YELLOW}Warning: users/${USERNAME}/ already exists${NC}"
        read -p "Overwrite? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # Full name
    read -p "Full name (e.g., John Doe): " FULLNAME
    
    # Email
    read -p "Email: " EMAIL
    
    # Terminal
    echo ""
    echo -e "${BLUE}Terminal Emulator:${NC}"
    echo "1) kitty"
    echo "2) alacritty"
    echo "3) wezterm"
    echo ""
    read -p "Selection (1-3): " term_choice
    
    case $term_choice in
        1) TERM="kitty" ;;
        2) TERM="alacritty" ;;
        3) TERM="wezterm" ;;
        *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
    esac
    
    # Browser
    echo ""
    echo -e "${BLUE}Browser:${NC}"
    echo "1) vivaldi"
    echo "2) firefox"
    echo "3) zen"
    echo "4) brave"
    echo ""
    read -p "Selection (1-4): " browser_choice
    
    case $browser_choice in
        1) BROWSER="vivaldi" ;;
        2) BROWSER="firefox" ;;
        3) BROWSER="zen" ;;
        4) BROWSER="brave" ;;
        *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
    esac
    
    # Theme
    echo ""
    echo -e "${BLUE}Theme:${NC}"
    echo "1) gruvbox-dark-hard"
    echo "2) catppuccin-mocha"
    echo "3) nord"
    echo "4) dracula"
    echo ""
    read -p "Selection (1-4): " theme_choice
    
    case $theme_choice in
        1) THEME="gruvbox-dark-hard" ;;
        2) THEME="catppuccin-mocha" ;;
        3) THEME="nord" ;;
        4) THEME="dracula" ;;
        *) echo -e "${RED}Invalid selection${NC}"; exit 1 ;;
    esac
    
    # Create user directory and home.nix
    echo ""
    echo -e "${YELLOW}Creating users/${USERNAME}/...${NC}"
    mkdir -p "users/${USERNAME}"
    
    # Copy template or create minimal
    if [ -f "users/henhal/home.nix" ]; then
        cp "users/henhal/home.nix" "users/${USERNAME}/home.nix"
        echo -e "${GREEN}✓ Created users/${USERNAME}/home.nix (from template)${NC}"
        echo -e "${YELLOW}Note: Review and customize the imports for your needs${NC}"
    else
        cat > "users/${USERNAME}/home.nix" << 'EOF'
{
  config,
  pkgs,
  userSettings,
  ...
}: {
  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";
  home.stateVersion = userSettings.stateVersion;
  
  programs.home-manager.enable = true;
  nixpkgs.config.allowUnfree = true;

  imports = [
    ../../home/modules/desktop/default.nix
    ../../home/modules/applications/zsh.nix
    ../../home/modules/applications/${userSettings.term}.nix
    ../../home/modules/applications/${userSettings.browser}.nix
    # Add more imports as needed
  ];
}
EOF
        echo -e "${GREEN}✓ Created users/${USERNAME}/home.nix (minimal)${NC}"
    fi
    
    # Show flake.nix instructions
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}Manual Step Required: Update flake.nix${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "Add to the ${BLUE}users${NC} section:"
    echo ""
    echo -e "${GREEN}  users = {${NC}"
    echo -e "    henhal = { ... };"
    echo -e "${YELLOW}    ${USERNAME} = rec {                          # ADD THIS${NC}"
    echo -e "${YELLOW}      username = \"${USERNAME}\";${NC}"
    echo -e "${YELLOW}      name = \"${FULLNAME}\";${NC}"
    echo -e "${YELLOW}      email = \"${EMAIL}\";${NC}"
    echo -e "${YELLOW}      homeDirectory = \"/home/\\\${username}\";${NC}"
    echo -e "${YELLOW}      term = \"${TERM}\";${NC}"
    echo -e "${YELLOW}      browser = \"${BROWSER}\";${NC}"
    echo -e "${YELLOW}      stateVersion = \"25.05\";${NC}"
    echo -e "${YELLOW}      stylixTheme = {${NC}"
    echo -e "${YELLOW}        scheme = \"${THEME}\";${NC}"
    echo -e "${YELLOW}        wallpaper = \"starry-sky.png\";${NC}"
    echo -e "${YELLOW}      };${NC}"
    echo -e "${YELLOW}    };${NC}"
    echo -e "${GREEN}  };${NC}"
    echo ""
fi

# Final summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${GREEN}Configuration Files Created!${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [ "$CREATE_HOST" = true ]; then
    echo -e "${GREEN}✓${NC} hosts/${HOSTNAME}.nix"
    echo -e "${GREEN}✓${NC} systems/${HOSTNAME}/"
fi

if [ "$CREATE_USER" = true ]; then
    echo -e "${GREEN}✓${NC} users/${USERNAME}/"
fi

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Edit flake.nix and add the entries shown above"
echo "2. Review and customize the generated files"
echo "3. Run: sudo nixos-rebuild switch --flake .#${HOSTNAME:-your-host}"
echo ""
echo -e "${BLUE}Tip: Use 'nix flake check' to validate your configuration${NC}"
echo ""
