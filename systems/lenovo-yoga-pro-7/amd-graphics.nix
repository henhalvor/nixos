{ config, pkgs, userSettings, ... }: {
  # Video drivers
  services.xserver.videoDrivers = [ "amdgpu" ];

  # Environment variables for video acceleration
  environment.sessionVariables = {
    # Hardware video acceleration - Essential for low-power video
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";

    # Firefox hardware acceleration
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_USE_XINPUT2 = "1";
    MOZ_X11_EGL = "1";
    MOZ_WEBRENDER = "1";
    MOZ_ACCELERATED = "1";

    # AMD Vulkan settings
    AMD_VULKAN_ICD = "RADV";
    RADV_PERFTEST = "video_decode";

    # Mesa settings
    MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";
    mesa_glthread = "true";

    # Wayland settings from your config
    WLR_RENDERER = "gles2";
    WLR_NO_HARDWARE_CURSORS = "1";

    # Enable DRI3
    LIBGL_DRI3_DISABLE = "0";
  };

  # Graphics hardware configuration
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        # Mesa drivers
        mesa

        # Vulkan
        amdvlk
        vulkan-loader
        vulkan-validation-layers

        # Video acceleration - Critical for battery life during video
        libva
        libva-utils
        libvdpau
        vaapiVdpau
        libvdpau-va-gl

        # AMD ROCm
        rocmPackages.clr
      ];

      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        vulkan-loader
        libva
        libvdpau
        vaapiVdpau
      ];
    };

    firmware = with pkgs; [ linux-firmware ];
  };

  # Balanced kernel parameters for Radeon 780M
  boot.kernelParams = [
    # AMD GPU parameters
    "amdgpu.ppfeaturemask=0xffffffff"
    "amdgpu.runpm=1"
    "amdgpu.aspm=1"
    "amdgpu.bapm=1"
    "amdgpu.dpm=1"
    "amdgpu.dc=1"
    "amdgpu.msi=1"
    "amdgpu.gpu_recovery=1"

    # Disable unused features
    "amdgpu.audio=0" # Disable HDMI audio if not needed

    # Disable old radeon driver
    "radeon.si_support=0"
    "radeon.cik_support=0"
    "amdgpu.si_support=1"
    "amdgpu.cik_support=1"

    # Blacklist NVIDIA
    "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm,nouveau"
  ];

  # XDG Portal configuration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
    config = { common = { default = [ "wlr" "gtk" ]; }; };
  };

  # Firefox with video acceleration
  programs.firefox = {
    enable = true;
    preferences = {
      # Hardware video acceleration
      "media.ffmpeg.vaapi.enabled" = true;
      "media.hardware-video-decoding.enabled" = true;
      "media.hardware-video-decoding.force-enabled" = true;
      "media.ffvpx.enabled" = false;
      "media.av1.enabled" = true;
      "media.navigator.mediadatadecoder_vpx_enabled" = true;
      "media.rdd-process.enabled" = false; # Reduce process overhead

      # WebRender
      "gfx.webrender.all" = true;
      "gfx.webrender.enabled" = true;
      "gfx.webrender.compositor" = true;
      "gfx.webrender.compositor.force-enabled" = true;

      # Wayland
      "widget.wayland.use-cached-mode-info" = true;
      "widget.dmabuf.force-enabled" = true;

      # Performance settings for battery
      "dom.ipc.processCount" = 4;
      "browser.sessionstore.interval" = 60000; # Save session less often
      "browser.tabs.unloadOnLowMemory" = true;
      "javascript.options.mem.gc_incremental_slice_ms" = 20;

      # Disable telemetry
      "toolkit.telemetry.unified" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;

      # GPU acceleration
      "layers.acceleration.force-enabled" = true;
      "layers.omtp.enabled" = true;
      "layers.gpu-process.enabled" = true;
    };
  };

  # Additional GPU management
  services = {
    udev.extraRules = ''
      # AMD GPU power management
      KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_state}="battery"
      KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="auto"
      ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"
    '';
  };

  # Video playback tools
  environment.systemPackages = with pkgs; [
    libva-utils # vainfo command
    vdpauinfo # vdpauinfo command
    radeontop # GPU monitoring
    nvtopPackages.amd # Better GPU monitoring
  ];
}

# {
#   config,
#   pkgs,
#   userSettings,
#   ...
# }: {
#   # Video drivers configuration
#   services.xserver.videoDrivers = ["amdgpu"]; # Only use amdgpu driver
#
#   # Remove any NVIDIA-related packages and modules
#   hardware.nvidia.package = null;
#   hardware.nvidia.modesetting.enable = false;
#
#   # Environment variables for AMD graphics
#   environment.sessionVariables = {
#     # Hardware acceleration API support
#     LIBVA_DRIVER_NAME = "radeonsi"; # For VA-API
#     VDPAU_DRIVER = "radeonsi"; # For VDPAU
#
#     # Wayland-specific settings (if using Wayland)
#     # WLR_RENDERER = "vulkan"; # Better performance on AMD
#   WLR_RENDERER = "gles2"; # Change "vulkan" to "gles2" to MINIMIZE screen artifact
#  WLR_NO_HARDWARE_CURSORS = "1"; # FIXES screen artifact in lower right corner
#
#     # Force Mesa to ignore NVIDIA
#     MESA_LOADER_DRIVER_OVERRIDE = "radeonsi";
#
#     # Optional: Use Vulkan by default for games
#     AMD_VULKAN_ICD = "RADV"; # Use RADV Vulkan driver
#   };
#
#   # Graphics and Hardware Acceleration
#   hardware = {
#     graphics = {
#       enable = true;
#
#       # Add drivers for AMD and definitely exclude NVIDIA
#       extraPackages = with pkgs; [
#         # Vulkan support
#         vulkan-loader
#         vulkan-validation-layers
#         amdvlk # AMD's Vulkan implementation
#
#         # OpenGL and VA-API support
#         mesa # Main OpenGL implementation
#         libva # Video Acceleration API
#         libva-utils
#
#         # VDPAU support
#         vaapiVdpau # VDPAU backend for VA-API
#         libvdpau-va-gl # OpenGL backend for VDPAU
#
#         # ROCm (compute) support if needed
#         rocmPackages.clr # OpenCL runtime
#       ];
#
#       # 32-bit support (for Steam and other gaming applications)
#       extraPackages32 = with pkgs.pkgsi686Linux; [
#         # Vulkan 32-bit support
#         vulkan-loader
#
#         # OpenGL 32-bit support
#         mesa
#
#         # Video acceleration 32-bit support
#         libva
#         vaapiVdpau
#       ];
#     };
#
#     # Enable firmware for amdgpu if needed
#     firmware = [pkgs.linux-firmware];
#   };
#
#   # Optional: For better performance with AMDGPU
#   boot.kernelParams = [
#     "amdgpu.ppfeaturemask=0xffffffff" # Enables all power management features
#     "radeon.si_support=0" # Disable Southern Islands support
#     "radeon.cik_support=0" # Disable Sea Islands support
#     "amdgpu.si_support=1" # Enable Southern Islands support in amdgpu
#     "amdgpu.cik_support=1" # Enable Sea Islands support in amdgpu
#     "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm" # Blacklist NVIDIA modules
#   ];
#
#   # XDG Desktop Portal for proper application integrations
#   xdg.portal = {
#     enable = true;
#     extraPortals = with pkgs; [
#       xdg-desktop-portal-gtk
#       xdg-desktop-portal-gnome
#     ];
#     config.common.default = "*";
#   };
# }
