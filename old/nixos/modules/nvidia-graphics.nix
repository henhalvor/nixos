{ config, pkgs, ... }: {
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    WLR_RENDERER =
      "egl"; # Use EGL rendering - NVIDIA - Need to check if this works with amd and without graphics card
    # Hardware acceleration
    VDPAU_DRIVER = "nvidia";
  };

  # Load nvidia driver for Xorg and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  # Graphics and Hardware Acceleration
  hardware = {
    # Enable Opengl
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl

        # Nvidia specific
        libglvnd
      ];
    };

    # NVIDIA settings
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

}
