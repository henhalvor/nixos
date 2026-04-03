# Minimal Battery — power management for laptops
# Source: systems/lenovo-yoga-pro-7/minimal-battery.nix
{...}: {
  flake.nixosModules.minimalBattery = {
    pkgs,
    lib,
    ...
  }: let
    applyPowerCaps = pkgs.writeShellScript "apply-power-caps" ''
      set -euo pipefail

      ac_online=0
      for ac in /sys/class/power_supply/AC*; do
        if [ -f "$ac/online" ] && [ "$(cat "$ac/online")" = "1" ]; then
          ac_online=1
          break
        fi
      done

      if [ "$ac_online" = "1" ]; then
        cpu_cap="0"
        platform_profile="balanced"
        gpu_level="auto"
        ryzenadj_args="--stapm-limit=35000 --fast-limit=45000 --slow-limit=35000 --tctl-temp=90"
      else
        cpu_cap="1800000"
        platform_profile="low-power"
        gpu_level="low"
        ryzenadj_args="--stapm-limit=12000 --fast-limit=15000 --slow-limit=12000 --tctl-temp=72"
      fi

      for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [ -d "$policy" ] || continue

        if [ -w "$policy/scaling_max_freq" ]; then
          if [ "$ac_online" = "1" ] && [ -f "$policy/cpuinfo_max_freq" ]; then
            cat "$policy/cpuinfo_max_freq" > "$policy/scaling_max_freq"
          else
            printf '%s' "$cpu_cap" > "$policy/scaling_max_freq"
          fi
        fi

        if [ -w "$policy/energy_performance_preference" ]; then
          if [ "$ac_online" = "1" ]; then
            printf 'balance_performance' > "$policy/energy_performance_preference"
          else
            printf 'power' > "$policy/energy_performance_preference"
          fi
        fi
      done

      if [ -w /sys/firmware/acpi/platform_profile ]; then
        printf '%s' "$platform_profile" > /sys/firmware/acpi/platform_profile
      fi

      for gpu in /sys/class/drm/card*/device; do
        [ -d "$gpu" ] || continue
        if [ -w "$gpu/power_dpm_force_performance_level" ]; then
          printf '%s' "$gpu_level" > "$gpu/power_dpm_force_performance_level"
        fi
      done

      ${pkgs.ryzenadj}/bin/ryzenadj $ryzenadj_args >/dev/null 2>&1 || true
    '';
  in {
    environment.systemPackages = with pkgs; [powertop acpi btop htop];

    services.spice-vdagentd.enable = lib.mkDefault false;
    networking.networkmanager.wifi.powersave = lib.mkDefault true;

    powerManagement = {
      enable = true;
      powertop.enable = true;
    };

    services.tuned.enable = true;
    services.upower.enable = true;

    systemd.services.apply-power-caps = {
      description = "Apply aggressive CPU/GPU power caps";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${applyPowerCaps}";
      };
      wantedBy = ["multi-user.target"];
    };

    systemd.timers.apply-power-caps = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "1m";
        Unit = "apply-power-caps.service";
      };
    };

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
