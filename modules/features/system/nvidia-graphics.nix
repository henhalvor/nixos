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

    # Prevent the NVIDIA driver from retaining an oversized pool of freed
    # compositor buffers. Without this profile, long-running Niri sessions can
    # exhaust VRAM and leave games displaying a black or frozen frame.
    environment.etc."nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json".text =
      builtins.toJSON {
        rules = [
          {
            pattern = {
              feature = "procname";
              matches = "niri";
            };
            profile = "Limit Free Buffer Pool On Wayland Compositors";
          }
        ];
        profiles = [
          {
            name = "Limit Free Buffer Pool On Wayland Compositors";
            settings = [
              {
                key = "GLVidHeapReuseRatio";
                value = 0;
              }
            ];
          }
        ];
      };

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
