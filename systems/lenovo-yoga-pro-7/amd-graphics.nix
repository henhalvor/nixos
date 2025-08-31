{ config, pkgs, userSettings, ... }: {
  # Video drivers
  # services.xserver.videoDrivers = [ "amdgpu" ];

  environment.sessionVariables = {
    # Essential video acceleration
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";

    # Wayland Basics
    MOZ_ENABLE_WAYLAND = "1";
    WLR_RENDERER = "gles2";
    WLR_NO_HARDWARE_CURSORS = "1";

  };

  # Performance Issues with AMDVLK
  # Some games choose AMDVLK over RADV, which can cause noticeable performance issues (e.g. <50% less FPS in games)
  # This is also more power efficient than AMDVL
  # To force RADV
  environment.variables.AMD_VULKAN_ICD = "RADV";

  # Graphics hardware configuration
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        # Core Mesa drivers
        mesa

        # Essential video acceleration for battery life
        libva
        libvdpau
        vaapiVdpau
        libvdpau-va-gl

        # Minimal Vulkan support
        vulkan-loader
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

  # Optional: For better performance with AMDGPU
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff" # Enables all power management features
    "amdgpu.runpm=1" # Runtime PM
    "amdgpu.bapm=1" # Battery power management
    "amdgpu.dpm=1" # Dynamic power management
    "amdgpu.dc=1" # Display core efficiency

    # Additional battery optimizations
    "amdgpu.audio=0" # Disable HDMI audio if not needed
    "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm" # Blacklist NVIDIA modules
  ];

  # XDG Portal configuration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
    config = { common = { default = [ "wlr" "gtk" ]; }; };
  };

  # Battery-focused Firefox
  programs.firefox = {
    enable = true;
    preferences = {
      # Video acceleration (essential for battery)
      "media.ffmpeg.vaapi.enabled" = true;
      "media.hardware-video-decoding.enabled" = true;
      "media.ffvpx.enabled" = false;

      # Battery optimizations
      "dom.ipc.processCount" = 2;
      "browser.sessionstore.interval" = 120000;
      "browser.tabs.unloadOnLowMemory" = true;
      "browser.tabs.remote.autostart" = false;
      "media.autoplay.default" = 5; # Block autoplay

      # Memory management
      "javascript.options.mem.gc_incremental_slice_ms" = 10;
      "browser.sessionhistory.max_entries" = 10;

      # Disable telemetry (saves CPU cycles)
      "toolkit.telemetry.unified" = false;
      "browser.newtabpage.activity-stream.telemetry" = false;

      # Conservative GPU usage
      "layers.acceleration.disabled" = false;
      "gfx.webrender.software.opengl" = true;
    };
  };

  # Aggressive power management
  services.udev.extraRules = ''
    # Maximum battery optimization for AMD GPU
    KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_state}="battery"
    KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="low"
    KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/pp_power_profile_mode}="1"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/autosuspend_delay_ms}="1000"
  '';

  # Minimal monitoring tools
  environment.systemPackages = with pkgs;
    [
      libva-utils # vainfo - verify video acceleration works
      # radeontop and nvtop are useful but consume power themselves
    ];
}

