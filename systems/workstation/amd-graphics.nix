{ config, pkgs, userSettings, ... }: {
  # Video drivers configuration
  services.xserver.videoDrivers = [ "amdgpu" ]; # Only use amdgpu driver

  # Remove any NVIDIA-related packages and modules
  hardware.nvidia.package = null;
  hardware.nvidia.modesetting.enable = false;

  # Environment variables for AMD graphics
  environment.sessionVariables = {
    # Hardware acceleration API support
    LIBVA_DRIVER_NAME = "radeonsi"; # For VA-API
    VDPAU_DRIVER = "radeonsi"; # For VDPAU

    # Wayland-specific settings (if using Wayland)
    # WLR_RENDERER = "vulkan"; # Better performance on AMD
    WLR_RENDERER =
      "gles2"; # Change "vulkan" to "gles2" to MINIMIZE screen artifact
    WLR_NO_HARDWARE_CURSORS = "1"; # FIXES screen artifact in lower right corner

    # Force Mesa to ignore NVIDIA
    MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";

    # Optional: Use Vulkan by default for games
    AMD_VULKAN_ICD = "RADV"; # Use RADV Vulkan driver
  };

  # Graphics and Hardware Acceleration
  hardware = {
    graphics = {
      enable = true;

      # Add drivers for AMD and definitely exclude NVIDIA
      extraPackages = with pkgs; [
        # Vulkan support
        vulkan-loader
        vulkan-validation-layers
        amdvlk # AMD's Vulkan implementation

        # OpenGL and VA-API support
        mesa # Main OpenGL implementation
        libva # Video Acceleration API
        libva-utils

        # VDPAU support
        vaapiVdpau # VDPAU backend for VA-API
        libvdpau-va-gl # OpenGL backend for VDPAU

        # ROCm (compute) support if needed
        rocmPackages.clr # OpenCL runtime
      ];

      # 32-bit support (for Steam and other gaming applications)
      extraPackages32 = with pkgs.pkgsi686Linux; [
        # Vulkan 32-bit support
        vulkan-loader

        # OpenGL 32-bit support
        mesa

        # Video acceleration 32-bit support
        libva
        vaapiVdpau
      ];
    };

    # Enable firmware for amdgpu if needed
    firmware = [ pkgs.linux-firmware ];
  };

  boot.kernelParams = [
    # "amdgpu.ppfeaturemask=0xffffffff" # Enables all power management features
    "radeon.si_support=0" # Disable Southern Islands support
    "radeon.cik_support=0" # Disable Sea Islands support
    "amdgpu.si_support=1" # Enable Southern Islands support in amdgpu
    "amdgpu.cik_support=1" # Enable Sea Islands support in amdgpu
    "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm" # Blacklist NVIDIA modules
    "amdgpu.dpm=0" # Disables dynamic power management, (fixes amd-gpu crashing / freeze issues)
    "amdgpu.runpm=0" # Disable runtime power management
    "amdgpu.bapm=0" # Disable bidirectional application power management
    "amdgpu.ppfeaturemask=0x0" # Disable ALL power features completely
    "amdgpu.noretry=1" # Don't retry failed operations
    "amdgpu.lockup_timeout=0" # Disable lockup detection
  ];

  # XDG Desktop Portal for proper application integrations
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
    config.common.default = "*";
  };
}
