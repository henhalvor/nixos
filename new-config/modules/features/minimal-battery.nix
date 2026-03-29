# Minimal Battery — power management for laptops
# Source: systems/lenovo-yoga-pro-7/minimal-battery.nix
{...}: {
  flake.nixosModules.minimalBattery = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = with pkgs; [powertop acpi btop htop];

    services.spice-vdagentd.enable = lib.mkDefault false;
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    powerManagement = {
      enable = true;
      powertop.enable = true;
    };

    services.tuned.enable = true;
    services.upower.enable = true;

    # Block NVIDIA drivers on AMD-only laptop
    boot.blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia-persistenced"
      "nvidia-fabricmanager"
    ];

    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"
      ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/autosuspend_delay_ms}="1000"
      KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="auto"
    '';

    # Battery-focused Firefox
    programs.firefox = {
      enable = true;
      preferences = {
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.enabled" = true;
        "media.ffvpx.enabled" = false;
        "dom.ipc.processCount" = 2;
        "browser.sessionstore.interval" = 120000;
        "browser.tabs.unloadOnLowMemory" = true;
        "media.autoplay.default" = 5;
        "javascript.options.mem.gc_incremental_slice_ms" = 10;
        "browser.sessionhistory.max_entries" = 10;
        "toolkit.telemetry.unified" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "layers.acceleration.disabled" = false;
        "gfx.webrender.software.opengl" = true;
      };
    };
  };
}
