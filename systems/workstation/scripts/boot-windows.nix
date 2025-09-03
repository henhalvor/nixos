{ config, lib, pkgs, ... }:
let
  # Create the boot-windows package using writeScriptBin
  boot-windows = pkgs.writeScriptBin "boot-windows" ''
    #!${pkgs.bash}/bin/bash
    # Script for booting into Windows from Linux
    # Changes boot order to boot into Windows on next reboot, then reboots the system

    set -euo pipefail  # Exit on error, undefined vars, pipe failures

    echo "=== Current Boot Entries ==="
    sudo ${pkgs.efibootmgr}/bin/efibootmgr -v
    echo

    # Default boot entry
    DEFAULT_BOOT="0001"

    echo "Default Windows boot entry: $DEFAULT_BOOT"
    read -p "Enter boot entry number (or press Enter for default): " user_boot

    # Use default if user just pressed Enter
    if [[ -z "$user_boot" ]]; then
        BOOT_ENTRY="$DEFAULT_BOOT"
    else
        BOOT_ENTRY="$user_boot"
    fi

    echo "Setting next boot to entry: $BOOT_ENTRY"

    # Validate boot entry exists
    if ! sudo ${pkgs.efibootmgr}/bin/efibootmgr -v | grep -q "Boot$BOOT_ENTRY\*"; then
        echo "Error: Boot entry $BOOT_ENTRY not found!"
        exit 1
    fi

    # Set the boot entry
    if sudo ${pkgs.efibootmgr}/bin/efibootmgr --bootnext "$BOOT_ENTRY"; then
        echo "Successfully set next boot to entry $BOOT_ENTRY"
    else
        echo "Error: Failed to set boot entry!"
        exit 1
    fi

    echo
    echo "=== Reboot Confirmation ==="
    while true; do
        read -p "Reboot now? (y/n): " yn
        case $yn in
            [Yy]* ) 
                echo "Rebooting in 3 seconds..."
                sleep 1
                echo "2..."
                sleep 1
                echo "1..."
                sleep 1
                sudo ${pkgs.systemd}/bin/systemctl reboot
                break
                ;;
            [Nn]* ) 
                echo "Boot entry set but not rebooting. Run 'sudo reboot' when ready."
                exit 0
                ;;
            * ) 
                echo "Please answer y or n."
                ;;
        esac
    done
  '';
in {
  environment.systemPackages = with pkgs; [ efibootmgr boot-windows ];

  # Create aliases for convenience
  programs.bash.shellAliases = { boot-windows = "sudo boot-windows"; };

  programs.zsh.shellAliases = { boot-windows = "sudo boot-windows"; };

}
