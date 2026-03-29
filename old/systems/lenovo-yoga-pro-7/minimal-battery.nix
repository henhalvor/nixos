{
  config,
  pkgs,
  lib,
  ...
}: {
  # Essential monitoring tools only
  environment.systemPackages = with pkgs; [powertop acpi btop htop];

  services.spice-vdagentd.enable = lib.mkDefault false; # not a VM guest
  networking.networkmanager.wifi.powersave = lib.mkDefault true;

  # Simple, effective power management
  powerManagement = {
    enable = true;
    powertop.enable = true; # Automatic tuning on boot
  };

  services.tuned = {
    enable = true;
  };
  services.upower = {
    enable = true;
  };

  # Disable nvidia drivers
  boot = {
    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia-persistenced"
      "nvidia-fabricmanager"
    ];
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/autosuspend_delay_ms}="1000"
    KERNEL=="card[0-9]", SUBSYSTEM=="drm", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="auto"
  '';

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
}
