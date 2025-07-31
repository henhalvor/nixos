{ config, pkgs, userSettings, windowManager, lib, ... }: {
  imports =
    # Window manager (conditional import)
    (if windowManager == "hyprland" then
      [ ../../nixos/modules/window-manager/hyrpland.nix ]
    else if windowManager == "sway" then
      [ ../../nixos/modules/window-manager/sway.nix ]
    else if windowManager == "gnome" then
    # Need to add gnome specific home config
      [ ../../nixos/modules/window-manager/gnome.nix ]
    else if windowManager == "none" then
      [ ]
    else [
      throw
      "Unsupported window manager in flake's windowManager: ${windowManager}"
    ]) ++ [
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/external-io.nix
      # ../../nixos/modules/battery.nix
      ./amd-graphics.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      ../../nixos/modules/systemd-loginhd.nix
      ./bootloader.nix
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix

    ];

  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # Keep the s2idle setting
  boot.kernelParams = [
    "mem_sleep_default=s2idle" # default is "deep" sleep this sets to lighter sleep "s2idle"

    # USB enumeration fixes (usb devices takes 30 seconds to load in display manager)
    "usbcore.old_scheme_first=1" # Try old USB enumeration method first
    "usbcore.use_both_schemes=1" # Use both old and new enumeration schemes
    "usbcore.initial_descriptor_timeout=2000" # Increase timeout for device descriptors
    "usb-storage.delay_use=3" # Delay USB storage device recognition
    "usbhid.mousepoll=0" # Disable mouse polling optimization

    # USB power management fixes
    "usbcore.autosuspend=-1" # Disable USB autosuspend globally
    "usb_core.autosuspend=-1" # Alternative parameter name

    # USB 3.0/2.0 compatibility
    "xhci_hcd.quirks=0x0008"
  ];

  # Add the missing power management
  powerManagement.enable = true;

  # Configure monitor layout for GDM (X11)
  services.xserver.displayManager.setupCommands = ''
    # Workstation monitor setup for GDM
    ${pkgs.xorg.xrandr}/bin/xrandr --output HDMI-A-1 --mode 2560x1440 --rate 144 --pos 1080x0 --primary
    ${pkgs.xorg.xrandr}/bin/xrandr --output DP-1 --mode 1920x1080 --rate 144 --pos 0x-180 --rotate left
  '';

  # Safer approach - disable power profile switching at the software level
  services.udev.extraRules = ''
    # Make power profile files read-only after system boot
    ACTION=="add", KERNEL=="card*", SUBSYSTEM=="drm", RUN+="${pkgs.bash}/bin/bash -c 'sleep 5 && chmod 444 /sys/class/drm/%k/device/pp_power_profile_mode 2>/dev/null || true'"

    # Your existing USB rules (keep these)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0040", ATTR{power/wakeup}="enabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{bInterfaceClass}=="03", ATTR{power/wakeup}="enabled"
  '';

  # Disable power management services
  systemd.services.power-profiles-daemon.enable = lib.mkForce false;
  services.power-profiles-daemon.enable = false;

  # Create a service to disable power profile switching after boot
  systemd.services.disable-amd-power-profiles = {
    description = "Disable AMD Power Profile Switching";
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart =
        "${pkgs.bash}/bin/bash -c 'find /sys/class/drm/card*/device/pp_power_profile_mode -exec chmod 444 {} \\; 2>/dev/null || true'";
    };
  };

}
