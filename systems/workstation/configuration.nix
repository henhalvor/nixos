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
    ../../nixos/modules/external-io.nix
    ../../nixos/modules/pipewire.nix
    ../../nixos/modules/bluetooth.nix
    ../../nixos/modules/networking.nix
    ../../nixos/modules/gaming.nix
    ../../nixos/modules/virtualization.nix
    # ../../nixos/modules/syncthing.nix
    ../../nixos/modules/printer.nix
    # ./bootloader.nix
    ./secure-boot.nix # Secure boot overrides bootloader settings

    # Server connectivity
    ../../nixos/modules/server/ssh.nix
    ../../nixos/modules/server/tailscale.nix
    ../../nixos/modules/server/sunshine/default.nix

    # Scripts
    ./scripts/boot-windows.nix

    # Android development
    ../../nixos/modules/android.nix
  ];

  # Hardware configuration based on hostConfig
  hardware.logitech.wireless.enable = hostConfig.hardware.logitech or false;
  hardware.logitech.wireless.enableGraphical = hostConfig.hardware.logitech or false;

  # NVIDIA GPU (hostConfig.hardware.gpu == "nvidia")
  services.xserver.videoDrivers = lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia") ["nvidia"];

  hardware.nvidia = lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia") {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # OpenGL/Vulkan for hardware encoding
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Increase file watch limit
  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 524288; # or 1048576
  };

  # Early loading of NVIDIA modules
  boot.initrd.kernelModules =
    lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia")
    ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

  boot.kernelParams = lib.mkIf (hostConfig.hardware.gpu or "" == "nvidia") [
    "modprobe.blacklist=amdgpu"
    "mem_sleep_default=s2idle"
    "nvidia-drm.modeset=1"
  ];

  hardware.enableAllFirmware = true;
  hardware.firmware = [pkgs.linux-firmware];
  hardware.enableRedistributableFirmware = true;

  # Enable Gnome keyring but disable SSH component
  security.pam.services.login.enableGnomeKeyring = true;
  services.gnome.gnome-keyring.enable = true;

  environment.sessionVariables = {
    GSM_SKIP_SSH_AGENT_WORKAROUND = "1";
  };
}
