# NVIDIA Graphics — driver, session variables, hardware acceleration
# Source: nixos/modules/nvidia-graphics.nix + systems/workstation/configuration.nix (NVIDIA parts)
# Hosts can override specific settings (e.g. powerManagement) in their configuration.nix.
{...}: {
  flake.nixosModules.nvidiaGraphics = {
    config,
    pkgs,
    ...
  }: {
    # environment.sessionVariables = {
    #   LIBVA_DRIVER_NAME = "nvidia";
    #   GBM_BACKEND = "nvidia-drm";
    #   __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    #   WLR_RENDERER = "egl";
    #   VDPAU_DRIVER = "nvidia";
    # };

    services.xserver.videoDrivers = ["nvidia"];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva-vdpau-driver
        libvdpau-va-gl
        libglvnd
      ];
    };

    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };

    # Early loading for Wayland compositors
    boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];
    boot.kernelParams = ["nvidia-drm.modeset=1"];
  };
}
