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

  # AMD microcode updates
  hardware.cpu.amd.updateMicrocode = true;

  # Minimal monitoring tools
  environment.systemPackages = with pkgs;
    [
      libva-utils # vainfo - verify video acceleration works
      # radeontop and nvtop are useful but consume power themselves
    ];
}

