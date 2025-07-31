{ config, pkgs, userSettings, ... }: {
  # Video drivers configuration
  services.xserver.videoDrivers = [ "amdgpu" ]; # Only use amdgpu driver

  # # Remove any NVIDIA-related packages and modules
  # hardware.nvidia.package = null;
  # hardware.nvidia.modesetting.enable = false;
  #
  # # Environment variables for AMD graphics
  # environment.sessionVariables = {
  #   # Hardware acceleration API support
  #   LIBVA_DRIVER_NAME = "radeonsi"; # For VA-API
  #   VDPAU_DRIVER = "radeonsi"; # For VDPAU
  #
  #   # Wayland-specific settings (if using Wayland)
  #   # WLR_RENDERER = "vulkan"; # Better performance on AMD
  #   WLR_RENDERER =
  #     "gles2"; # Change "vulkan" to "gles2" to MINIMIZE screen artifact
  #   WLR_NO_HARDWARE_CURSORS = "1"; # FIXES screen artifact in lower right corner
  #
  #   # Force Mesa to ignore NVIDIA
  #   MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";
  #
  #   # Optional: Use Vulkan by default for games
  #   AMD_VULKAN_ICD = "RADV"; # Use RADV Vulkan driver
  # };

  # Graphics and Hardware Acceleration
  hardware = {
    graphics = {
      enable = true;

      # # Add drivers for AMD and definitely exclude NVIDIA
      # extraPackages = with pkgs; [
      #   # Vulkan support
      #   vulkan-loader
      #   vulkan-validation-layers
      #   amdvlk # AMD's Vulkan implementation
      #
      #   # OpenGL and VA-API support
      #   mesa # Main OpenGL implementation
      #   libva # Video Acceleration API
      #   libva-utils
      #
      #   # VDPAU support
      #   vaapiVdpau # VDPAU backend for VA-API
      #   libvdpau-va-gl # OpenGL backend for VDPAU
      #
      #   # ROCm (compute) support if needed
      #   rocmPackages.clr # OpenCL runtime
      # ];
      #
      # # 32-bit support (for Steam and other gaming applications)
      # extraPackages32 = with pkgs.pkgsi686Linux; [
      #   # Vulkan 32-bit support
      #   vulkan-loader
      #
      #   # OpenGL 32-bit support
      #   mesa
      #
      #   # Video acceleration 32-bit support
      #   libva
      #   vaapiVdpau
      # ];
    };

    # Enable firmware for amdgpu if needed
    firmware = [ pkgs.linux-firmware ];
  };

  boot.kernelParams = [
    # AMD integrated graphics configuration
    "radeon.si_support=0"
    "radeon.cik_support=0"
    "amdgpu.si_support=1"
    "amdgpu.cik_support=1"
    # "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"
    #
    # # CRITICAL FIX for Ryzen 7900 integrated graphics (DCN 3.1)
    # "amdgpu.dcfeaturemask=0x0" # Disable ALL Display Core features (fixes DCN 3.1 crashes)
    # "amdgpu.dpm=0" # Disable dynamic power management
    # "amdgpu.runpm=0" # Disable runtime power management
    # "amdgpu.ppfeaturemask=0x0" # Disable power play features
    # "amdgpu.bapm=0" # Disable bidirectional application power management
    #
    # # Integrated GPU specific fixes
    # "amdgpu.gpu_recovery=0" # Disable recovery (broken with DCN 3.1)
    # "amdgpu.lockup_timeout=0" # Disable lockup detection
    # "amdgpu.noretry=1" # Don't retry failed operations
    # "amdgpu.aspm=0" # Disable ASPM for integrated GPU stability
  ];

  #  # RECOMMENDED: Use kernel 6.6 LTS (stable before the DCN 3.1 regression)
  #  boot.kernelPackages = pkgs.linuxPackages_6_6;
  #
  #  # Keep minimal but effective parameters for integrated graphics
  #  boot.kernelParams = [
  #    # Basic AMD integrated graphics setup
  #    "radeon.si_support=0"
  #    "radeon.cik_support=0"
  #    "amdgpu.si_support=1"
  #    "amdgpu.cik_support=1"
  #
  #    # Essential integrated GPU stability fixes
  #    "amdgpu.dcfeaturemask=0x0" # Disable DCN 3.1 features
  #    "amdgpu.dpm=0" # Disable dynamic power management
  #    "amdgpu.runpm=0" # Disable runtime power management
  # ];

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
