{
  config,
  pkgs,
  userSettings,
  windowManager,
  lib,
  ...
}: {
  imports =
    # Window manager (conditional import)
    (
      if windowManager == "hyprland"
      then [../../nixos/modules/window-manager/hyrpland.nix]
      else if windowManager == "sway"
      then [../../nixos/modules/window-manager/sway.nix]
      else if windowManager == "gnome"
      then
        # Need to add gnome specific home config
        [../../nixos/modules/window-manager/gnome.nix]
      else if windowManager == "none"
      then []
      else [
        throw
        "Unsupported window manager in flake's windowManager: ${windowManager}"
      ]
    )
    ++ [
      ./hardware-configuration.nix
      ../../nixos/default.nix
      ../../nixos/modules/external-io.nix
      ../../nixos/modules/pipewire.nix
      ../../nixos/modules/bluetooth.nix
      ../../nixos/modules/networking.nix
      ../../nixos/modules/gaming.nix
      ../../nixos/modules/virtualization.nix
      ../../nixos/modules/syncthing.nix
      ../../nixos/modules/printer.nix
      # ./bootloader.nix
      ./secure-boot.nix # Secore boot overrides bootloader settings
      # window-manager
      ../../nixos/modules/window-manager/default.nix

      # Server connectivity
      ../../nixos/modules/server/ssh.nix
      ../../nixos/modules/server/tailscale.nix
      ../../nixos/modules/server/sunshine/default.nix

      # Scripts
      ./scripts/boot-windows.nix

      # Android development
      ../../nixos/modules/android.nix
    ];
  # logitect wireless dongle
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  # NVIDIA GPU
  # Use NVIDIA proprietary drivers and automatically detect correct version
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; # Power-saving mostly applies to laptops
    open = false; # Use proprietary blob (recommended for your GPU)
    nvidiaSettings = true; # Optional: enables `nvidia-settings` GUI tool

    # Enable NVENC/NVDEC for Sunshine hardware encoding
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable OpenGL/Vulkan for hardware encoding
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Early loading of NVIDIA modules
  boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  boot.kernelParams = [
    "modprobe.blacklist=amdgpu" # Prevent conflicts with AMD integrated GPU:  Disable AMD integrated GPU since we are using NVIDIA - Linux firmware does not currently support the newest amd IGPU's
    "mem_sleep_default=s2idle" # Set sleep to "lighter sleep" default is "deep" sleep, solves weird graphics bug on displays after deep sleep
    "nvidia-drm.modeset=1" # Enable modesetting early, helps with early nvidia driver loading
  ];

  hardware.enableAllFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];
  hardware.enableRedistributableFirmware = true;

  # Enable Gnome keyring but disable SSH component to prevent conflicts with ssh-agent
  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;

  # Disable the SSH component of gnome-keyring to use system ssh-agent instead
  environment.sessionVariables = {
    # Prevent gnome-keyring from overriding SSH_AUTH_SOCK
    GSM_SKIP_SSH_AGENT_WORKAROUND = "1";
  };
}
