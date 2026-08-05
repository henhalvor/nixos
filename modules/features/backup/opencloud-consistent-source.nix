# Establish the Mode B (offline) OpenCloud source boundary for Restic.  The HP
# T7 is ext4, so no filesystem snapshot facility is assumed or created here.
{...}: {
  flake.nixosModules.opencloudConsistentSource = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.opencloudConsistentSource;
    cloudCfg = config.my.opencloud;
    prepare = pkgs.writeShellApplication {
      name = "opencloud-backup-prepare";
      runtimeInputs = with pkgs; [attr coreutils findutils jq rsync util-linux];
      text = ''
        set -o pipefail
        stage=/run/opencloud-backup/current
        marker=/run/opencloud-backup/stopped-by-backup
        status=/var/lib/restic-status/opencloud-source.json

        fail() {
          mkdir -p /var/lib/restic-status
          jq -n --arg timestamp "$(date --iso-8601=seconds)" --arg detail "$1" \
            '{timestamp: $timestamp, result: "failed", mode: "offline", detail: $detail}' \
            >"$status.tmp"
          mv -f "$status.tmp" "$status"
          exit 1
        }

        mountpoint -q /srv/opencloud || fail "the OpenCloud data filesystem is not mounted"
        [[ "$(findmnt -no UUID -T /srv/opencloud)" == ${lib.escapeShellArg cloudCfg.storageUuid} ]] \
          || fail "the mounted OpenCloud filesystem UUID is not the reviewed T7"
        available_kib="$(df --output=avail /srv/opencloud | tail -n1 | tr -d ' ')"
        (( available_kib >= ${toString (cfg.minimumFreeMiB * 1024)} )) \
          || fail "the OpenCloud filesystem is below the reviewed free-space threshold"
        [[ -r /srv/opencloud/state ]] || fail "the OpenCloud state tree is unreadable"

        probe=/srv/opencloud/backup-staging/.xattr-probe.$$
        : >"$probe" || fail "could not create the OpenCloud xattr probe"
        setfattr -n user.opencloud-backup-probe -v verified "$probe" || fail "xattr write failed"
        [[ "$(getfattr --only-values -n user.opencloud-backup-probe "$probe")" == verified ]] \
          || fail "xattr read-back failed"
        setfattr -x user.opencloud-backup-probe "$probe"
        rm -f "$probe"

        rm -rf /run/opencloud-backup
        mkdir -p "$stage"
        if systemctl is-active --quiet opencloud.service; then
          systemctl stop opencloud.service || fail "could not stop OpenCloud"
          systemctl is-active --quiet opencloud.service && fail "OpenCloud remained active after stop"
          : >"$marker"
        fi

        # Mode B: keep OpenCloud stopped until Restic completes.  The bind mount
        # merely gives both modes the same recovery-tree layout.
        mkdir -p "$stage/state"
        mount --bind /srv/opencloud/state "$stage/state"
        mkdir -p "$stage/config"
        rsync -aHAX --numeric-ids /etc/opencloud/ "$stage/config/"
        jq -n \
          --arg timestamp "$(date --iso-8601=seconds)" \
          --arg stateDir /srv/opencloud/state \
          --arg mountUuid ${lib.escapeShellArg cloudCfg.storageUuid} \
          --arg packageVersion ${lib.escapeShellArg config.services.opencloud.package.version} \
          '{timestamp: $timestamp, createdAt: $timestamp, result: "healthy", mode: "offline", stateDir: $stateDir, mountUuid: $mountUuid, packageVersion: $packageVersion, xattrProbe: "passed"}' \
          >"$stage/manifest.json"
        cp "$stage/manifest.json" "$status"
      '';
    };
    cleanup = pkgs.writeShellApplication {
      name = "opencloud-backup-cleanup";
      runtimeInputs = with pkgs; [coreutils util-linux];
      text = ''
        set -o pipefail
        stage=/run/opencloud-backup/current
        marker=/run/opencloud-backup/stopped-by-backup
        restart_opencloud=0
        [[ -e "$marker" ]] && restart_opencloud=1
        if mountpoint -q "$stage/state"; then
          umount "$stage/state" || true
        fi
        rm -rf /run/opencloud-backup
        if (( restart_opencloud )); then
          systemctl start opencloud.service || true
        fi
      '';
    };
  in {
    options.my.opencloudConsistentSource = {
      enable = lib.mkEnableOption "the stopped-service OpenCloud Restic source";
      minimumFreeMiB = lib.mkOption {
        type = lib.types.ints.between 1 2147483647;
        default = 20480;
        description = "Minimum free space on the T7 before opening an offline backup window.";
      };
      prepare = lib.mkOption { type = lib.types.package; readOnly = true; };
      cleanup = lib.mkOption { type = lib.types.package; readOnly = true; };
    };

    config = lib.mkIf cfg.enable {
      assertions = [{
        assertion = cloudCfg.enable;
        message = "my.opencloudConsistentSource requires my.opencloud.enable.";
      }];
      my.opencloudConsistentSource.prepare = prepare;
      my.opencloudConsistentSource.cleanup = cleanup;
    };
  };
}
