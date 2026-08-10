# Prepare a complete, validated GitHub mirror set before Restic reads it.
{...}: {
  flake.nixosModules.githubMirror = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.githubMirror;
    ownersFile = pkgs.writeText "github-mirror-owners" (builtins.readFile cfg.ownersFile);
    mirrorScript = pkgs.writeShellApplication {
      name = "github-mirror-refresh";
      runtimeInputs = with pkgs; [coreutils findutils gawk git git-lfs gh jq util-linux];
      text = ''
        set -o pipefail

        root=/var/lib/github-mirrors
        current="$root/current"
        status="$root/status.json"
        allowlist=${ownersFile}
        limit=${toString cfg.repositoryLimit}
        lock=/var/lib/hp-backup/source.lock

        write_status() {
          local result="$1" detail="$2"
          mkdir -p "$root"
          jq -n --arg timestamp "$(date --iso-8601=seconds)" \
            --arg result "$result" --arg detail "$detail" \
            '{timestamp: $timestamp, result: $result, detail: $detail}' >"$status.tmp"
          mv -f "$status.tmp" "$status"
        }

        if ! mkdir -p /var/lib/hp-backup; then
          write_status degraded "shared backup lock directory is unavailable"
          exit 0
        fi
        exec 9>"$lock"
        if ! flock -x 9; then
          write_status degraded "could not acquire the shared backup lock"
          exit 0
        fi

        candidate="$(mktemp -d "$root/candidate.XXXXXX")"
        inventory="$(mktemp "$root/inventory.XXXXXX")"
        cleanup() { rm -rf "$candidate" "$inventory"; }
        trap cleanup EXIT

        mapfile -t owners < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$allowlist")
        if (( ''${#owners[@]} == 0 )); then
          write_status degraded "the version-controlled GitHub owner allowlist is empty"
          exit 0
        fi

        # Start from the last complete publication.  This intentionally retains
        # a mirror when a repository is renamed, transferred, or inaccessible.
        if [[ -d "$current" ]]; then
          if ! cp -a --reflink=auto "$current/." "$candidate/"; then
            write_status degraded "could not prepare a private candidate copy of the current mirror set"
            exit 0
          fi
        fi
        mkdir -p "$candidate/repos"

        if ! : >"$inventory"; then
          write_status degraded "could not create the inventory"
          exit 0
        fi
        for owner in "''${owners[@]}"; do
          owner_inventory="$(mktemp "$root/owner.XXXXXX")"
          if ! gh repo list "$owner" --limit "$limit" \
            --json nameWithOwner,url,isArchived,isFork >"$owner_inventory"; then
            rm -f "$owner_inventory"
            write_status degraded "repository discovery failed for $owner; retained the previous publication"
            exit 0
          fi
          count="$(jq 'length' "$owner_inventory")"
          if (( count >= limit )); then
            rm -f "$owner_inventory"
            write_status degraded "repository discovery for $owner reached its reviewed limit ($limit)"
            exit 0
          fi
          jq -c '.[]' "$owner_inventory" >>"$inventory"
          rm -f "$owner_inventory"
        done

        while IFS= read -r repo; do
          name="$(jq -r '.nameWithOwner' <<<"$repo")"
          url="$(jq -r '.url' <<<"$repo")"
          mirror="$candidate/repos/$name.git"
          mkdir -p "$(dirname "$mirror")"

          if [[ -d "$mirror" ]]; then
            if ! git -C "$mirror" remote set-url origin "$url"; then
              write_status degraded "could not update the credential-free remote for $name"
              exit 0
            fi
            if ! git -C "$mirror" -c credential.helper="!${pkgs.gh}/bin/gh auth git-credential" remote update --prune; then
              write_status degraded "fetch failed for $name; retained the previous publication"
              exit 0
            fi
          elif ! git -c credential.helper="!${pkgs.gh}/bin/gh auth git-credential" \
            clone --mirror "$url" "$mirror"; then
            write_status degraded "initial mirror clone failed for $name; retained the previous publication"
            exit 0
          fi

          if ! git -C "$mirror" fsck --full; then
            write_status degraded "git fsck failed for $name; retained the previous publication"
            exit 0
          fi

          # Git fsck does not check LFS payloads.  Fetch and verify every LFS
          # object reachable from every mirrored ref before publishing.
          lfs_oids="$(git -C "$mirror" lfs ls-files --all --long | awk '{print $1}')"
          if [[ -n "$lfs_oids" ]]; then
            if ! git -C "$mirror" lfs fetch --all || ! git -C "$mirror" lfs fsck --objects --pointers; then
              write_status degraded "Git LFS validation failed for $name; retained the previous publication"
              exit 0
            fi
            while IFS= read -r oid; do
              [[ -z "$oid" ]] && continue
              object="$mirror/lfs/objects/''${oid:0:2}/''${oid:2:2}/$oid"
              [[ -f "$object" ]] && [[ "$(sha256sum "$object" | cut -d ' ' -f1)" == "$oid" ]] || {
                write_status degraded "a Git LFS object is missing or corrupt in $name; retained the previous publication"
                exit 0
              }
            done <<<"$lfs_oids"
          fi
        done <"$inventory"

        manifest="$candidate/manifest.json"
        jq -s --arg timestamp "$(date --iso-8601=seconds)" \
          --argjson limit "$limit" \
          '{generatedAt: $timestamp, repositoryLimit: $limit, repositories: .}' \
          "$inventory" >"$manifest"

        # Keep the previous publication until the next exclusive refresh.  The
        # shared lock prevents Restic from traversing a tree being replaced.
        rm -rf "$root/previous"
        [[ ! -d "$current" ]] || mv "$current" "$root/previous"
        mv "$candidate" "$current"
        candidate=""
        write_status healthy "validated mirror publication complete"
      '';
    };
  in {
    options.my.githubMirror = {
      enable = lib.mkEnableOption "the HP read-only GitHub mirror preparer";
      ownersFile = lib.mkOption {
        type = lib.types.path;
        default = ./github-owners.txt;
        description = "Version-controlled allowlist of personal and organisation owners.";
      };
      repositoryLimit = lib.mkOption {
        type = lib.types.ints.between 1 2147483647;
        default = 500;
        description = "Explicit per-owner discovery limit; reaching it is a degraded result.";
      };
    };

    config = lib.mkIf cfg.enable {
      users.groups.backup-source = {};
      users.groups.github-mirror = {};
      users.users.github-mirror = {
        isSystemUser = true;
        group = "github-mirror";
        extraGroups = ["backup-source"];
        home = "/var/lib/github-mirrors";
        createHome = true;
        shell = pkgs.bash;
        description = "Read-only GitHub mirror preparation account";
      };

      sops.secrets.GITHUB_MIRROR_TOKEN = {
        sopsFile = ../../../secrets/hp-backup.yaml;
        owner = "github-mirror";
        group = "github-mirror";
        mode = "0400";
      };
      sops.templates."github-mirror-env" = {
        owner = "github-mirror";
        group = "github-mirror";
        mode = "0400";
        content = "GH_TOKEN=${config.sops.placeholder.GITHUB_MIRROR_TOKEN}\n";
      };

      systemd.tmpfiles.settings."10-github-mirrors" = {
        "/var/lib/github-mirrors".d = {
          mode = "0750";
          user = "github-mirror";
          group = "github-mirror";
        };
        "/var/lib/github-mirrors/current".d = {
          mode = "0750";
          user = "github-mirror";
          group = "github-mirror";
        };
        "/var/lib/hp-backup".d = {
          mode = "0770";
          user = "root";
          group = "backup-source";
        };
        "/var/lib/hp-backup/source.lock".f = {
          mode = "0660";
          user = "root";
          group = "backup-source";
        };
      };

      systemd.services.github-mirror = {
        description = "Refresh validated read-only GitHub mirrors";
        after = ["network-online.target" "sops-install-secrets.service"];
        wants = ["network-online.target"];
        serviceConfig = {
          Type = "oneshot";
          User = "github-mirror";
          Group = "github-mirror";
          WorkingDirectory = "/var/lib/github-mirrors";
          EnvironmentFile = config.sops.templates."github-mirror-env".path;
          UMask = "0077";
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          ReadWritePaths = ["/var/lib/github-mirrors" "/var/lib/hp-backup"];
          NoNewPrivileges = true;
        };
        script = "exec ${mirrorScript}/bin/github-mirror-refresh";
      };
    };
  };
}
