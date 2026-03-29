# AMD Graphics — Radeon drivers, Vulkan, video acceleration
# Source: systems/lenovo-yoga-pro-7/amd-graphics.nix
{...}: {
  flake.nixosModules.amdGraphics = {pkgs, ...}: {
    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "radeonsi";
      VDPAU_DRIVER = "radeonsi";
      MOZ_ENABLE_WAYLAND = "1";
      WLR_RENDERER = "gles2";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    # Force RADV over AMDVLK for better performance and power efficiency
    environment.variables.AMD_VULKAN_ICD = "RADV";

    hardware.graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        mesa
        libva
        libvdpau
        libva-vdpau-driver
        libvdpau-va-gl
        vulkan-loader
      ];

      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa
        vulkan-loader
        libva
        libvdpau
        libva-vdpau-driver
      ];
    };

    hardware.firmware = with pkgs; [linux-firmware];

    boot.kernelParams = [
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.runpm=1"
      "amdgpu.bapm=1"
      "amdgpu.dpm=1"
      "amdgpu.dc=1"
      "amdgpu.audio=0"
      "module_blacklist=nvidia,nvidia_drm,nvidia_modeset,nvidia_uvm"
    ];

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [xdg-desktop-portal-gtk xdg-desktop-portal-wlr];
      config.common.default = ["wlr" "gtk"];
    };

    hardware.cpu.amd.updateMicrocode = true;

    environment.systemPackages = with pkgs; [libva-utils];
  };
}
