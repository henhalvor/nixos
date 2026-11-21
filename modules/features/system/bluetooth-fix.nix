# Bluetooth Fix — launcher entry that recovers the adapter after booting Windows
# The MediaTek MT7925 is left in a bad state by Windows, so the adapter comes
# up soft-blocked and powered off. This unblocks it, powers it on once the chip
# has re-initialised, and reconnects paired input devices.
# Template B: HM-only (with NixOS wrapper)
{ self, ... }: {
  flake.nixosModules.bluetoothFix = { ... }: {
    home-manager.sharedModules = [ self.homeModules.bluetoothFix ];
  };

  flake.homeModules.bluetoothFix = { pkgs, ... }: let
    fix-bluetooth = pkgs.writeShellApplication {
      name = "fix-bluetooth";
      runtimeInputs = with pkgs; [ util-linux bluez libnotify coreutils gnugrep gawk ];
      text = ''
        notify() {
          notify-send --app-name="Fix Bluetooth" --icon=bluetooth "$@"
        }

        rfkill unblock bluetooth

        # The chip resets after unblocking; power on fails with Busy until it is ready.
        powered=false
        for _ in $(seq 1 15); do
          sleep 1
          bluetoothctl power on >/dev/null 2>&1 || true
          if bluetoothctl show | grep -q "Powered: yes"; then
            powered=true
            break
          fi
        done

        if [[ "$powered" != true ]]; then
          notify --urgency=critical "Bluetooth" "Adapter did not power on. Try again, or reboot."
          exit 1
        fi

        # Only input devices: audio devices may be in use by another host.
        while read -r mac; do
          info=$(bluetoothctl info "$mac")
          if grep -qE "Icon: input-(mouse|keyboard)" <<<"$info" \
            && ! grep -q "Connected: yes" <<<"$info"; then
            timeout 10 bluetoothctl connect "$mac" >/dev/null 2>&1 &
          fi
        done < <(bluetoothctl devices Paired | awk '{ print $2 }')
        wait

        notify "Bluetooth" "Adapter powered on and input devices reconnected."
      '';
    };
  in {
    home.packages = [ fix-bluetooth ];

    xdg.desktopEntries.fix-bluetooth = {
      name = "Fix Bluetooth";
      comment = "Unblock and power on the Bluetooth adapter after booting Windows";
      exec = "${fix-bluetooth}/bin/fix-bluetooth";
      terminal = false;
      categories = [ "System" ];
      icon = "bluetooth";
    };
  };
}
