{ config, pkgs, ... }: {

  # Essential monitoring tools only
  environment.systemPackages = with pkgs; [ powertop acpi ];

  # Simple, effective power management
  powerManagement = {
    enable = true;
    powertop.enable = true; # Automatic tuning on boot
  };

  # Disable conflicting services (CRITICAL!)
  services = {
    power-profiles-daemon.enable = false;
    auto-cpufreq.enable = false;
    thermald.enable = false; # AMD doesn't need Intel's thermald!

    # Use ONLY TLP 
    tlp = {
      enable = true;
      settings = {
        # Let AMD's hardware do the work - don't micromanage
        TLP_DEFAULT_MODE = "BAT"; # Always optimize for battery
        TLP_PERSISTENT_DEFAULT = 1;

        # CPU - Conservative but not crippling
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

        # CRITICAL: Enable boost for efficiency (counter-intuitive but correct)
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT =
          1; # Short bursts are more efficient than sustained load

        # Platform profile - let AMD manage power
        PLATFORM_PROFILE_ON_AC = "low-power";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # AMD GPU power management
        RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
        RADEON_DPM_PERF_LEVEL_ON_BAT = "low";
        RADEON_DPM_STATE_ON_AC = "battery";
        RADEON_DPM_STATE_ON_BAT = "battery";

        # Essential power saving
        PCIE_ASPM_ON_AC = "performance";
        PCIE_ASPM_ON_BAT = "powersupersave";

        RUNTIME_PM_ON_AC = "auto";
        RUNTIME_PM_ON_BAT = "auto";

        # USB power management
        USB_AUTOSUSPEND = 1;
        USB_BLACKLIST_BTUSB = 1;
        USB_BLACKLIST_PHONE = 1;

        # Audio power saving
        SOUND_POWER_SAVE_ON_AC = 10;
        SOUND_POWER_SAVE_ON_BAT = 1;
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        # Disk power management
        DISK_DEVICES = "nvme0n1";
        DISK_APM_LEVEL_ON_AC = "254";
        DISK_APM_LEVEL_ON_BAT = "128";
        DISK_IOSCHED = "none"; # Modern NVMe doesn't need scheduling

        # Network power saving
        WOL_DISABLE = "Y";

        # Battery care
        START_CHARGE_THRESH_BAT0 = 80;
        STOP_CHARGE_THRESH_BAT0 = 85;
      };
    };
  };

  # Optimized kernel parameters (much simpler)
  boot = {
    kernelParams = [
      # AMD P-State (most important for 7840HS!)
      "amd_pstate=active"

      # PCIe power management (fixes many ASPM issues)
      "pcie_aspm=force"

      # Essential power saving
      "nowatchdog"
      "nmi_watchdog=0"

      # Let hardware manage itself
      "processor.max_cstate=9"
    ];

    # Minimal module config
    extraModprobeConfig = ''
      # AMD GPU
      options amdgpu dpm=1 runpm=1 dc=1

      # Audio power saving
      options snd_hda_intel power_save=1 power_save_controller=Y
    '';

    blacklistedKernelModules = [
      "nouveau"
      "nvidia"
      "nvidia_drm"
      "nvidia_modeset"
      "nvidia_uvm"
      "nvidia-persistenced"
      "nvidia-fabricmanager"
    ];

    # Essential sysctl only
    kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
      "vm.swappiness" = 10;
      "vm.dirty_writeback_centisecs" = 1500;
    };
  };

  # Minimal udev rules
  services.udev.extraRules = ''
    # AMD GPU runtime power management
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"

    # PCIe ASPM
    ACTION=="add", SUBSYSTEM=="pci", TEST=="power/control", ATTR{power/control}="auto"

    # USB autosuspend (but keep HID devices active)
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
  '';

  # AMD microcode updates
  hardware.cpu.amd.updateMicrocode = true;

  # Reasonable zram (don't overdo it)
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25; # 50% was too much
  };

  # OOM protection
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = false; # Notifications waste power
  };
}
