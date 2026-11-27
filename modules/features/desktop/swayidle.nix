# Swayidle — idle daemon for Sway/Niri
# Source: home/modules/desktop/idle/swayidle.nix
# Template B2: HM-only with NixOS options for lock command + session
#
# Timings are set per host through `my.swayidle.*` (seconds). Idle timeouts
# count from the last keyboard/mouse/touchpad input.
#
# Optional battery-only suspend:
#   suspendTimeout   — idle seconds before suspend (on battery only)
#   lidSuspendDelay  — seconds after lid close before suspend (on battery only).
#                      Needs logind HandleLidSwitch = "lock" on the host, and
#                      Niri's lid-close/lid-open switch events, which call the
#                      `lid-close-hook` / `lid-open-hook` commands installed here.
# Both re-check the power source when they fire, so plugging in cancels them.
{self, ...}: {
  flake.nixosModules.swayidle = {lib, ...}: {
    options.my.swayidle = {
      lockCommand = lib.mkOption {
        type = lib.types.str;
        default = "swaylock";
        description = "Lock screen command name (swaylock, hyprlock, noctalia, loginctl)";
      };
      session = lib.mkOption {
        type = lib.types.str;
        default = "sway";
        description = "Session type for monitor power command (sway or niri)";
      };
      lockTimeout = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Idle seconds before the screen locks";
      };
      screenOffTimeout = lib.mkOption {
        type = lib.types.int;
        default = 600;
        description = "Idle seconds before the monitors turn off";
      };
      suspendTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Idle seconds before suspend-then-hibernate, on battery only. null disables";
      };
      lidSuspendDelay = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Seconds after lid close before suspend-then-hibernate, on battery only. null disables";
      };
    };

    config.home-manager.sharedModules = [self.homeModules.swayidle];
  };

  flake.homeModules.swayidle = {
    config,
    lib,
    pkgs,
    osConfig,
    ...
  }: let
    cfg = osConfig.my.swayidle;
    lockBin =
      {
        swaylock = "${pkgs.swaylock}/bin/swaylock -f";
        hyprlock = "${pkgs.hyprlock}/bin/hyprlock";
        noctalia = "${lib.getExe config.programs.noctalia.package} msg session lock";
        loginctl = "loginctl lock-session";
      }
      .${cfg.lockCommand}
      or "loginctl lock-session";

    monitorPowerTimeout =
      if cfg.session == "niri"
      then {
        timeout = cfg.screenOffTimeout;
        command = "${lib.getExe osConfig.programs.niri.package} msg action power-off-monitors";
      }
      else {
        timeout = cfg.screenOffTimeout;
        command = "swaymsg 'output * dpms off'";
        resumeCommand = "swaymsg 'output * dpms on'";
      };

    # Suspend only when no mains adapter is online. With `lid` as the first
    # argument it also requires the lid to still be closed.
    # swayidle's service PATH has no systemctl (idle suspend failed with
    # "systemctl: not found"), nor cat/grep for the AC and lid checks.
    suspendOnBattery = pkgs.writeShellScriptBin "suspend-on-battery" ''
      export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.systemd]}:$PATH
      for ps in /sys/class/power_supply/*; do
        if [ "$(cat "$ps/type" 2>/dev/null)" = Mains ] && [ "$(cat "$ps/online" 2>/dev/null)" = 1 ]; then
          exit 0
        fi
      done
      if [ "''${1:-}" = lid ] && ! grep -qs closed /proc/acpi/button/lid/*/state; then
        exit 0
      fi
      exec systemctl suspend-then-hibernate
    '';

    lidCloseHook = pkgs.writeShellScriptBin "lid-close-hook" ''
      systemctl --user stop lid-suspend.timer 2>/dev/null
      exec systemd-run --user --collect --unit=lid-suspend \
        --on-active=${toString cfg.lidSuspendDelay} \
        --timer-property=AccuracySec=5s \
        ${lib.getExe suspendOnBattery} lid
    '';

    lidOpenHook = pkgs.writeShellScriptBin "lid-open-hook" ''
      exec systemctl --user stop lid-suspend.timer
    '';
  in {
    home.packages = lib.optionals (cfg.lidSuspendDelay != null) [lidCloseHook lidOpenHook];

    services.swayidle = {
      enable = true;
      timeouts =
        [
          {
            timeout = cfg.lockTimeout;
            command = lockBin;
          }
          monitorPowerTimeout
        ]
        ++ lib.optional (cfg.suspendTimeout != null) {
          timeout = cfg.suspendTimeout;
          command = lib.getExe suspendOnBattery;
        };
      events = [
        {
          event = "before-sleep";
          command = lockBin;
        }
        # logind's HandleLidSwitch = "lock" (and `loginctl lock-session`)
        {
          event = "lock";
          command = lockBin;
        }
      ];
    };
  };
}
