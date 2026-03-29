# Boot Windows — EFI boot-next script for dual-boot
# Source: systems/workstation/scripts/boot-windows.nix + users/henhal/home.nix (desktop entry)
# Template C: Colocated NixOS + HM
{ self, ... }: {
  flake.homeModules.bootWindows = { pkgs, ... }: {
    xdg.desktopEntries.boot-windows = {
      name = "Boot Windows";
      comment = "Boot into Windows on next reboot";
      exec = "${pkgs.kitty}/bin/kitty -e boot-windows";
      terminal = true;
      categories = [ "System" ];
      icon = "computer";
    };
  };

  flake.nixosModules.bootWindows = { pkgs, ... }: let
    boot-windows = pkgs.writeScriptBin "boot-windows" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      echo "=== Current Boot Entries ==="
      sudo ${pkgs.efibootmgr}/bin/efibootmgr -v
      echo

      DEFAULT_BOOT="0001"
      echo "Default Windows boot entry: $DEFAULT_BOOT"
      read -p "Enter boot entry number (or press Enter for default): " user_boot

      if [[ -z "$user_boot" ]]; then
          BOOT_ENTRY="$DEFAULT_BOOT"
      else
          BOOT_ENTRY="$user_boot"
      fi

      echo "Setting next boot to entry: $BOOT_ENTRY"

      if ! sudo ${pkgs.efibootmgr}/bin/efibootmgr -v | grep -q "Boot$BOOT_ENTRY\*"; then
          echo "Error: Boot entry $BOOT_ENTRY not found!"
          exit 1
      fi

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
                  sleep 1; echo "2..."; sleep 1; echo "1..."; sleep 1
                  sudo ${pkgs.systemd}/bin/systemctl reboot
                  break ;;
              [Nn]* )
                  echo "Boot entry set but not rebooting. Run 'sudo reboot' when ready."
                  exit 0 ;;
              * ) echo "Please answer y or n." ;;
          esac
      done
    '';
  in {
    environment.systemPackages = with pkgs; [efibootmgr boot-windows];

    programs.bash.shellAliases.boot-windows = "sudo boot-windows";
    programs.zsh.shellAliases.boot-windows = "sudo boot-windows";

    home-manager.sharedModules = [ self.homeModules.bootWindows ];
  };
}
