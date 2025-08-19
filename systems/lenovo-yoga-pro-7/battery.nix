{ config, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    powertop
    thermald
    tlp
    acpi
    acpid
    linuxPackages.cpupower
    s-tui
    btop
  ];

  powerManagement = {
    enable = true;
    powertop.enable = true;
  };

  services = {
    # Disable conflicting services
    power-profiles-daemon.enable = false;
    auto-cpufreq.enable = false;

    # TLP with balanced settings for usability
    tlp = {
      enable = true;
      settings = {
        # CPU settings - Balanced for responsiveness
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT =
          "schedutil"; # Better than powersave for responsiveness
        CPU_BOOST_ON_AC = 0; # Allow boost on AC for better performance
        CPU_BOOST_ON_BAT = 0; # No boost on battery

        # More reasonable frequency limits
        CPU_SCALING_MIN_FREQ_ON_AC = 400000;
        CPU_SCALING_MAX_FREQ_ON_AC = 2400000; # 2.4GHz on AC (still below max)
        CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
        CPU_SCALING_MAX_FREQ_ON_BAT =
          1800000; # 1.8GHz on battery for smooth operation

        # Balanced EPP settings
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

        # Performance scaling
        CPU_MAX_PERF_ON_AC = 45; # 45% on AC
        CPU_MAX_PERF_ON_BAT = 45; # 45% on battery

        # Platform Profile
        PLATFORM_PROFILE_ON_AC = "low-power";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # AMD GPU - Allow auto scaling for video
        RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
        RADEON_DPM_PERF_LEVEL_ON_BAT = "auto"; # Auto for video playback
        RADEON_DPM_STATE_ON_AC = "balanced";
        RADEON_DPM_STATE_ON_BAT = "battery";

        # PCIe ASPM
        PCIE_ASPM_ON_AC = "default";
        PCIE_ASPM_ON_BAT = "powersupersave";

        # Runtime PM
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "auto";

        # USB settings
        USB_AUTOSUSPEND = 1;
        USB_BLACKLIST_BTUSB = 1;
        USB_BLACKLIST_PHONE = 1;
        USB_BLACKLIST = "046d:c52b 046d:c077";

        # Sound power saving
        SOUND_POWER_SAVE_ON_AC = 1;
        SOUND_POWER_SAVE_ON_BAT = 1;
        SOUND_POWER_SAVE_CONTROLLER = "Y";

        # Disk settings
        DISK_DEVICES = "nvme0n1";
        DISK_APM_LEVEL_ON_AC = "254";
        DISK_APM_LEVEL_ON_BAT = "128";
        DISK_IOSCHED = "none";

        # SATA link power
        SATA_LINKPWR_ON_AC = "med_power_with_dipm";
        SATA_LINKPWR_ON_BAT = "min_power";

        # Disable Wake-on-LAN
        WOL_DISABLE = "Y";

        # Battery thresholds
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # Don't disable devices
        DEVICES_TO_DISABLE_ON_BAT = "";
        DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = "";
        DEVICES_TO_DISABLE_ON_STARTUP = "";
      };
    };

    # Balanced thermal management
    thermald = {
      enable = true;
      configFile = pkgs.writeText "thermal-conf.xml" ''
        <?xml version="1.0"?>
        <ThermalConfiguration>
          <Platform>
            <Name>AMD Ryzen 7 7840HS Balanced Quiet</Name>
            <ProductName>*</ProductName>
            <Preference>QUIET</Preference>
            <ThermalZones>
              <ThermalZone>
                <Type>cpu</Type>
                <TripPoints>
                  <TripPoint>
                    <SensorType>x86_pkg_temp</SensorType>
                    <Temperature>60000</Temperature>
                    <Type>passive</Type>
                    <CoolingDevice>
                      <Type>Processor</Type>
                      <SamplingPeriod>10</SamplingPeriod>
                    </CoolingDevice>
                  </TripPoint>
                  <TripPoint>
                    <SensorType>x86_pkg_temp</SensorType>
                    <Temperature>70000</Temperature>
                    <Type>passive</Type>
                    <CoolingDevice>
                      <Type>Processor</Type>
                      <SamplingPeriod>5</SamplingPeriod>
                    </CoolingDevice>
                  </TripPoint>
                  <TripPoint>
                    <SensorType>x86_pkg_temp</SensorType>
                    <Temperature>80000</Temperature>
                    <Type>passive</Type>
                    <CoolingDevice>
                      <Type>Processor</Type>
                      <SamplingPeriod>1</SamplingPeriod>
                    </CoolingDevice>
                  </TripPoint>
                </TripPoints>
              </ThermalZone>
            </ThermalZones>
          </Platform>
        </ThermalConfiguration>
      '';
    };

    # udev rules for power management
    udev.extraRules = ''
      # AMD GPU runtime PM
      ACTION=="add", SUBSYSTEM=="pci", DRIVER=="amdgpu", ATTR{power/control}="auto"

      # GPU power management but allow scaling
      SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_state}="battery"
      SUBSYSTEM=="drm", KERNEL=="card[0-9]", DRIVERS=="amdgpu", ATTR{device/power_dpm_force_performance_level}="auto"

      # USB autosuspend
      ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
      ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0cf3", TEST=="power/control", ATTR{power/control}="on"

      # PCIe Runtime PM
      ACTION=="add", SUBSYSTEM=="pci", TEST=="power/control", ATTR{power/control}="auto"

      # NVMe power management
      ACTION=="add", SUBSYSTEM=="nvme", ATTR{power/control}="auto"
    '';
  };

  boot = {
    # Optimized kernel parameters
    kernelParams = [
      "quiet"
      "splash"

      # AMD P-State driver
      "amd_pstate=active" # Active mode for better performance/power balance
      "amd_pstate.shared_mem=1"

      # AMD GPU parameters
      "amdgpu.ppfeaturemask=0xffffffff"
      "amdgpu.runpm=1"
      "amdgpu.aspm=1"
      "amdgpu.bapm=1"
      "amdgpu.dpm=1"
      "amdgpu.dc=1"
      "amdgpu.audio=0"

      # CPU power management
      "processor.max_cstate=9"

      # Timer optimization (less aggressive)
      "nohz=on"
      "highres=off" # Disable high resolution timers to reduce interrupts

      # PCIe ASPM
      "pcie_aspm=force"
      "pcie_aspm.policy=powersupersave"

      # Workqueue
      "workqueue.power_efficient=1"

      # Memory
      "transparent_hugepage=madvise"

      # NVMe
      "nvme_core.default_ps_max_latency_us=0"

      # Disable watchdogs
      "nowatchdog"
      "nmi_watchdog=0"
    ];

    # Module configuration
    extraModprobeConfig = ''
      # AMD GPU
      options amdgpu dpm=1 dc=1 runpm=1 aspm=1 bapm=1

      # Sound power saving
      options snd_hda_intel power_save=1 power_save_controller=Y

           # USB
      options usbcore autosuspend=1
    '';

    blacklistedKernelModules =
      [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];

    # Kernel sysctl
    kernel.sysctl = {
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.dirty_writeback_centisecs" = 1500;
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };
  };

  # Systemd configuration
  systemd = {
    sleep.extraConfig = ''
      AllowSuspend=yes
      AllowHibernation=yes
      HibernateDelaySec=3600
    '';

    # Disable the conflicting service
    services.cpu-throttle.enable = false;

    # Balanced power optimization service
    services."balanced-power-optimization" = {
      description = "Balanced power optimization";
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "balanced-power" ''
          #!${pkgs.bash}/bin/bash

          # Set platform profile
          if [ -f /sys/firmware/acpi/platform_profile ]; then
            if grep -q "Discharging" /sys/class/power_supply/BAT0/status 2>/dev/null; then
              echo "low-power" > /sys/firmware/acpi/platform_profile
            else
              echo "balanced" > /sys/firmware/acpi/platform_profile
            fi
          fi

          # Optimize process scheduler
          echo 1 > /sys/kernel/mm/ksm/run 2>/dev/null || true
          echo 1000 > /sys/kernel/mm/ksm/sleep_millisecs 2>/dev/null || true

          # Set I/O scheduler
          for dev in /sys/block/*/queue/scheduler; do
            echo none > "$dev" 2>/dev/null || true
          done

          # Apply powertop optimizations
          ${pkgs.powertop}/bin/powertop --auto-tune

          # But re-enable important devices
          # Re-enable USB HID devices
          for device in /sys/bus/usb/devices/*/power/control; do
            if [[ -f "$device/../bInterfaceClass" ]] && [[ $(cat "$device/../bInterfaceClass") == "03" ]]; then
              echo "on" > "$device" 2>/dev/null || true
            fi
          done

          # Reduce VM pressure
          echo 1500 > /proc/sys/vm/dirty_writeback_centisecs

          # WiFi power save
          # ${pkgs.networkmanager}/bin/nmcli radio wifi powersave on 2>/dev/null || true
        '';
      };
    };
  };

  # Hardware configuration
  hardware = { cpu.amd.updateMicrocode = true; };

  # Memory optimization
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true;
  };
}

# { config, pkgs, ... }: {
#
#   environment.systemPackages = with pkgs; [
#     powertop
#     thermald
#     auto-cpufreq
#     tlp
#     acpi
#     acpid
#     # Replace cpupower with the correct package
#     linuxPackages.cpupower
#     cpulimit
#   ];
#
#   powerManagement = {
#     enable = true;
#     powertop.enable = true;
#     cpuFreqGovernor = "ondemand";
#     # Remove the conflicting scsiLinkPolicy
#   };
#
#   services = {
#     power-profiles-daemon.enable = false;
#     auto-cpufreq = {
#       enable = true;
#       settings = {
#         battery = {
#           governor = "powersave";
#           turbo = "never";
#           scaling_min_freq = 400000;  # Set lower minimum frequency
#           scaling_max_freq = 1800000; # Limit maximum frequency on battery
#           energy_performance_preference = "power"; # Prioritize power saving over performance
#         };
#         charger = {
#           governor = "performance";
#           turbo = "auto";
#           scaling_min_freq = 800000;  # Higher min frequency on AC
#           scaling_max_freq = 3600000; # Max frequency on AC
#           energy_performance_preference = "performance"; # Full performance on AC
#         };
#       };
#     };
#
#     # TLP for more comprehensive power management
#     tlp = {
#       enable = true;
#       settings = {
#         # CPU settings
#         CPU_SCALING_GOVERNOR_ON_AC = "performance";
#         CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
#         CPU_BOOST_ON_AC = 0;
#         CPU_BOOST_ON_BAT = 0;
#
#         # CPU frequency limits
#         CPU_SCALING_MIN_FREQ_ON_AC = 800000;
#         CPU_SCALING_MAX_FREQ_ON_AC = 3600000;  # Full performance on AC
#         CPU_SCALING_MIN_FREQ_ON_BAT = 400000;
#         CPU_SCALING_MAX_FREQ_ON_BAT = 1800000;
#
#         # CPU energy/performance policies
#         CPU_ENERGY_PERF_POLICY_ON_AC = "balance-power";
#         CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
#
#         # CPU scaling factors
#         CPU_MAX_PERF_ON_AC = 100;        # 100% performance on AC
#         CPU_MAX_PERF_ON_BAT = 60;       # Limit to 60% performance on battery
#
#         # CPU throttle temperatures
#         CPU_TEMP_UNDERVOLT = 75;        # Start light throttling at 75°C
#         CPU_TEMP_THROTTLE = 85;         # Aggressive throttling at 85°C
#
#         # Display and graphics settings
#         RADEON_DPM_STATE_ON_AC = "performance";
#         RADEON_DPM_STATE_ON_BAT = "battery";
#         INTEL_GPU_MIN_FREQ_ON_AC = 350;
#         INTEL_GPU_MIN_FREQ_ON_BAT = 350;
#         INTEL_GPU_MAX_FREQ_ON_AC = 1150;
#         INTEL_GPU_MAX_FREQ_ON_BAT = 800;
#         INTEL_GPU_BOOST_FREQ_ON_AC = 1150;
#         INTEL_GPU_BOOST_FREQ_ON_BAT = 800;
#
#         # Power saving settings
#         PCIE_ASPM_ON_BAT = "powersupersave";
#         RUNTIME_PM_ON_BAT = "auto";
#         USB_AUTOSUSPEND = 1;
#         # WIFI_PWR_ON_BAT = 2;         # Medium power saving instead of maximum (1)
#         DEVICES_TO_DISABLE_ON_BAT = ""; # Don't disable any devices on battery
#         DEVICES_TO_DISABLE_ON_BAT_NOT_IN_USE = ""; # Don't disable unused devices
#
#         # Bluetooth settings
#         DEVICES_TO_DISABLE_ON_STARTUP = ""; # Don't disable Bluetooth on startup
#         BLUETOOTH_POWER_ON_AC = 1;    # Keep Bluetooth powered on AC
#         BLUETOOTH_POWER_ON_BAT = 1;   # Keep Bluetooth powered on battery
#
#         WOL_DISABLE = "Y";
#
#         # SATA link power management (replacing powerManagement.scsiLinkPolicy)
#         SATA_LINKPWR_ON_AC = "med_power_with_dipm";
#         SATA_LINKPWR_ON_BAT = "min_power";
#
#         # Additional disk power saving settings
#         DISK_DEVICES = "sda sdb nvme0n1"; # Update with your actual disk devices
#         DISK_APM_LEVEL_ON_AC = "254 254";
#         DISK_APM_LEVEL_ON_BAT = "128 128";
#         DISK_SPINDOWN_TIMEOUT_ON_AC = "0 0";
#         DISK_SPINDOWN_TIMEOUT_ON_BAT = "60 60";
#         DISK_IOSCHED = "none none";
#
#         # Battery charge thresholds (if supported)
#         # START_CHARGE_THRESH_BAT0 = 40;
#         # STOP_CHARGE_THRESH_BAT0 = 80;
#
#         # WiFi power management (use moderate settings that won't break connectivity)
#         WIFI_PWR_ON_AC = 0;          # No power saving on AC
#         WIFI_PWR_ON_BAT = 3;         # Moderate power saving (not aggressive)
#
#       };
#     };
#
#     # Enhanced thermald configuration
#     thermald = {
#       enable = true;
#       configFile = pkgs.writeText "thermal-conf.xml" ''
#         <?xml version="1.0"?>
#         <ThermalConfiguration>
#           <Platform>
#             <Name>CPU Throttling Configuration</Name>
#             <ProductName>*</ProductName>
#             <Preference>QUIET</Preference>
#             <ThermalZones>
#               <ThermalZone>
#                 <Type>cpu</Type>
#                 <TripPoints>
#                   <TripPoint>
#                     <SensorType>x86_pkg_temp</SensorType>
#                     <Temperature>70000</Temperature>
#                     <Type>passive</Type>
#                     <CoolingDevice>
#                       <Type>CPU</Type>
#                       <SamplingPeriod>5</SamplingPeriod>
#                     </CoolingDevice>
#                   </TripPoint>
#                 </TripPoints>
#               </ThermalZone>
#             </ThermalZones>
#           </Platform>
#         </ThermalConfiguration>
#       '';
#     };
#
#
#
#     udev.extraRules = ''
#       # Remove NVIDIA USB xHCI Host Controller devices, if present
#       ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
#       # Remove NVIDIA USB Type-C UCSI devices, if present
#       ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
#       # Remove NVIDIA Audio devices, if present
#       ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
#       # Remove NVIDIA VGA/3D controller devices
#       ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
#
#       # USB autosuspend
#       ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="auto"
#
#       # PCI runtime power management
#       SUBSYSTEM=="pci", ATTR{power/control}="auto"
#     '';
#   };
#
#   boot = {
#     extraModprobeConfig = ''
#       blacklist nouveau
#       options nouveau modeset=0
#
#       # Additional power saving options for Intel and AMD
#       options snd_hda_intel power_save=1
#
#       # WiFi power management - use safer settings
#       options iwlwifi power_save=0 d0i3_disable=1
#
#       options btusb enable_autosuspend=0 # Prevent Bluetooth from auto-suspending
#       options i915 enable_dc=2 enable_fbc=1 enable_guc=2
#     '';
#     blacklistedKernelModules =
#       [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];
#     kernelParams = [
#       "quiet"
#       "acpi_osi=Linux"
#       # "mem_sleep_default=deep"
#       "pcie_aspm=force"
#       "i915.enable_psr=1"
#       "i915.enable_fbc=1"
#       "nmi_watchdog=0"
#       "usbcore.autosuspend=1"
#       "processor.max_cstate=5"          # Limit CPU to C-state 5
#       "intel_pstate=active"            
#     ];
#
#     # I/O scheduler optimization
#     kernel.sysctl = {
#       "vm.laptop_mode" = 5;
#       "vm.dirty_writeback_centisecs" = 1500;
#       "vm.swappiness" = 10;
#       "kernel.nmi_watchdog" = 0;
#     };
#   };
#
#   # Configure system sleep settings
#   systemd = {
#     sleep.extraConfig = ''
#       HibernateDelaySec=3600
#       SuspendState=mem
#     '';
#     services.power-profiles-daemon.enable = false; # Ensure it's disabled in favor of TLP
#   };
#
#   # Add hardware configuration to ensure Bluetooth works properly
#   hardware = {
#     bluetooth = {
#       enable = true;
#       powerOnBoot = true;  # Keep Bluetooth on at boot
#       settings = {
#         General = {
#           Enable = "Source,Sink,Media,Socket";
#         };
#       };
#     };
#   };
#
#   # Configure networking with power-efficient settings that won't break connectivity
#   networking = {
#     networkmanager = {
#       enable = true;
#       # Let the service settings above handle the backend configuration
#     };
#
#     # Pick only ONE of these options:
#
#     # OPTION 1: Disable iwd (use with wpa_supplicant backend)
#     wireless.iwd.enable = false;
#
#     # OPTION 2: Enable iwd (use with iwd backend)
#     # wireless.iwd.enable = true;
#     # wireless.iwd.settings = {
#     #   General = {
#     #     EnableNetworkConfiguration = false;  # Let NetworkManager handle it
#     #   };
#     #   Settings = {
#     #     AutoConnect = true;
#     #   };
#     # };
#   };
#
#   # CPU throttling service - fixed version
#   systemd.services.cpu-throttle = {
#     description = "CPU Throttling Service";
#     wantedBy = [ "multi-user.target" ];
#     serviceConfig = {
#       Type = "oneshot";
#       # Only use commands known to work and avoid the failing set -b command
#       ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set -g performance && ${pkgs.linuxPackages.cpupower}/bin/cpupower frequency-set --min 800MHz --max 4.0GHz'";
#       RemainAfterExit = true;
#       # Add permissions to access CPU controls
#       CapabilityBoundingSet = ["CAP_SYS_NICE" "CAP_SYS_ADMIN"];
#       ProtectSystem = "strict";
#       ProtectHome = true;
#       # Add retry on failure
#       Restart = "on-failure";
#       RestartSec = "5s";
#     };
#   };
# }
