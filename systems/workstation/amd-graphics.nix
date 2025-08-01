{ config, pkgs, unstable, ... }: {
  # Video drivers configuration
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Environment variables for AMD graphics - UNCOMMENT AND USE THESE:
  environment.sessionVariables = {
    # Hardware acceleration API support
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";

    # Wayland-specific settings - USE GLES2 for stability
    WLR_RENDERER = "gles2"; # More stable than Vulkan for problematic GPUs
    WLR_NO_HARDWARE_CURSORS = "1"; # Fixes artifacts

    # Force Mesa to use AMD
    MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";

    # AMD Vulkan driver
    AMD_VULKAN_ICD = "RADV";

    # Additional stability variables
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
  };

  # Graphics and Hardware Acceleration - UNCOMMENT AND USE UNSTABLE MESA:
  hardware = {
    graphics = {
      enable = true;
      # Use LATEST Mesa and graphics packages from unstable
      extraPackages = with unstable; [ # <-- KEY: Use unstable packages
        # Latest Mesa (most important for AMD fixes)
        mesa
        mesa.drivers

        # Vulkan support
        vulkan-loader
        vulkan-validation-layers
        amdvlk

        # Video acceleration
        libva
        libva-utils
        vaapiVdpau
        libvdpau-va-gl

        # ROCm support
        rocmPackages.clr
      ];

      # 32-bit support with latest packages
      extraPackages32 = with unstable.pkgsi686Linux; [ # <-- KEY: Use unstable
        mesa
        vulkan-loader
        libva
        vaapiVdpau
      ];
    };
    firmware = [ pkgs.linux-firmware ];
  };

  # ACTIVATE your proven stable kernel parameters:
  boot.kernelParams = [
    "radeon.si_support=0"
    "radeon.cik_support=0"
    "amdgpu.si_support=1"
    "amdgpu.cik_support=1"

    # Your proven stable parameters
    "amdgpu.dcfeaturemask=0x0"
    "amdgpu.dpm=0"
    "amdgpu.runpm=0"
    "amdgpu.ppfeaturemask=0x0"
    "amdgpu.bapm=0"
    "amdgpu.gpu_recovery=0"
    "amdgpu.lockup_timeout=0"
    "amdgpu.noretry=1"
  ];

  # XDG Portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    config.common.default = "*";
  };
}
