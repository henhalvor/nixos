{ config, pkgs, ... }: {

  # Essential monitoring tools only
  environment.systemPackages = with pkgs; [ powertop acpi btop ];

  # Simple, effective power management
  powerManagement = {
    enable = true;
    powertop.enable = true; # Automatic tuning on boot
  };

  # Disable conflicting services (CRITICAL!)
  services = {
    power-profiles-daemon.enable = false;
    thermald.enable = false; # AMD doesn't need Intel's thermald!

    # Only use auto-cpufreq (much simpler and more effective than TLP)
    auto-cpufreq.enable = true;
    #
    # # Use ONLY TLP 
    # tlp = {
    #   enable = true;
    #   settings = {
    #     # Let AMD's hardware do the work - don't micromanage
    #     TLP_DEFAULT_MODE = "BAT"; # Always optimize for battery
    #     TLP_PERSISTENT_DEFAULT = 1;
    #
    #     # CPU - Conservative but not crippling
    #     CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
    #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    #
    #     # CRITICAL: Enable boost for efficiency (counter-intuitive but correct)
    #     CPU_BOOST_ON_AC = 1;
    #     CPU_BOOST_ON_BAT =
    #       1; # Short bursts are more efficient than sustained load
    #
    #     # Platform profile - let AMD manage power
    #     PLATFORM_PROFILE_ON_AC = "low-power";
    #     PLATFORM_PROFILE_ON_BAT = "low-power";
    #
    #     # AMD GPU power management
    #     RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
    #     RADEON_DPM_PERF_LEVEL_ON_BAT = "low";
    #     RADEON_DPM_STATE_ON_AC = "battery";
    #     RADEON_DPM_STATE_ON_BAT = "battery";
    #
    #     # Essential power saving
    #     PCIE_ASPM_ON_AC = "performance";
    #     PCIE_ASPM_ON_BAT = "powersupersave";
    #
    #     RUNTIME_PM_ON_AC = "auto";
    #     RUNTIME_PM_ON_BAT = "auto";
    #
    #     # USB power management
    #     USB_AUTOSUSPEND = 1;
    #     USB_BLACKLIST_BTUSB = 1;
    #     USB_BLACKLIST_PHONE = 1;
    #
    #     # Audio power saving
    #     SOUND_POWER_SAVE_ON_AC = 10;
    #     SOUND_POWER_SAVE_ON_BAT = 1;
    #     SOUND_POWER_SAVE_CONTROLLER = "Y";
    #
    #     # Disk power management
    #     DISK_DEVICES = "nvme0n1";
    #     DISK_APM_LEVEL_ON_AC = "254";
    #     DISK_APM_LEVEL_ON_BAT = "128";
    #     DISK_IOSCHED = "none"; # Modern NVMe doesn't need scheduling
    #
    #     # Network power saving
    #     WOL_DISABLE = "Y";
    #
    #     # Battery care
    #     START_CHARGE_THRESH_BAT0 = 80;
    #     STOP_CHARGE_THRESH_BAT0 = 85;
    #   };
    # };
  };

  # Optimized kernel parameters (much simpler)
  boot = {
    # kernelParams = [
    #   # AMD P-State (most important for 7840HS!)
    #   "amd_pstate=active"
    #
    #   # PCIe power management (fixes many ASPM issues)
    #   "pcie_aspm=force"
    #
    #   # Essential power saving
    #   "nowatchdog"
    #   "nmi_watchdog=0"
    #
    #   # Let hardware manage itself
    #   "processor.max_cstate=9"
    # ];

    # # Minimal module config
    # extraModprobeConfig = ''
    #   # AMD GPU
    #   options amdgpu dpm=1 runpm=1 dc=1
    #
    #   # Audio power saving
    #   options snd_hda_intel power_save=1 power_save_controller=Y
    # '';

    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia-persistenced"
      "nvidia-fabricmanager"
    ];

    # # Essential sysctl only
    # kernel.sysctl = {
    #   "kernel.nmi_watchdog" = 0;
    #   "vm.laptop_mode" = 5;
    #   "vm.swappiness" = 10;
    #   "vm.dirty_writeback_centisecs" = 1500;
    # };
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
  #
  # # Reasonable zram (don't overdo it)
  # zramSwap = {
  #   enable = true;
  #   algorithm = "zstd";
  #   memoryPercent = 25; # 50% was too much
  # };
  #
  # # OOM protection
  # services.earlyoom = {
  #   enable = true;
  #   freeMemThreshold = 5;
  #   freeSwapThreshold = 10;
  #   enableNotifications = false; # Notifications waste power
  # };
}
