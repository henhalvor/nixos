{inputs, ...}: {
  flake.nixosModules.hermesAgent = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.hermesAgent;
    ownerHome = lib.attrByPath ["users" "users" cfg.ownerUser "home"] "/home/${cfg.ownerUser}" config;
    ownerGroup = lib.attrByPath ["users" "users" cfg.ownerUser "group"] "users" config;
    hermesUser = config.services.hermes-agent.user;
    hermesGroup = config.services.hermes-agent.group;
    hermesStateDir = config.services.hermes-agent.stateDir;
    effectiveModel = cfg.model;
    backupScript = pkgs.writeShellScript "hermes-agent-backup" ''
      set -eu

      backup_root=${lib.escapeShellArg cfg.backupRoot}
      backup_dir=${lib.escapeShellArg cfg.backupDir}
      tmp_dir="${cfg.backupDir}.tmp"
      state_dir=${lib.escapeShellArg hermesStateDir}

      cleanup() {
        ${pkgs.systemd}/bin/systemctl start hermes-agent.service || true
      }

      ${pkgs.systemd}/bin/systemctl stop hermes-agent.service || true
      trap cleanup EXIT

      ${pkgs.coreutils}/bin/mkdir -p "$backup_root"
      ${pkgs.coreutils}/bin/rm -rf "$tmp_dir"
      ${pkgs.coreutils}/bin/mkdir -p "$tmp_dir"

      ${pkgs.rsync}/bin/rsync -a --delete "$state_dir/.hermes/" "$tmp_dir/.hermes/"
      if [ -d "$state_dir/workspace" ]; then
        ${pkgs.rsync}/bin/rsync -a --delete "$state_dir/workspace/" "$tmp_dir/workspace/"
      fi

      ${pkgs.coreutils}/bin/rm -rf "$backup_dir"
      ${pkgs.coreutils}/bin/mv "$tmp_dir" "$backup_dir"
      ${pkgs.coreutils}/bin/chown -R ${cfg.ownerUser}:${ownerGroup} "$backup_dir"

      trap - EXIT
      ${pkgs.systemd}/bin/systemctl start hermes-agent.service
    '';
  in {
    imports = [inputs.hermes-agent.nixosModules.default];

    options.my.hermesAgent = {
      ownerUser = lib.mkOption {
        type = lib.types.str;
        default = "henhal";
        description = "Interactive workstation user who owns the Hermes integration.";
      };

      repoRoot = lib.mkOption {
        type = lib.types.str;
        default = "${ownerHome}/.dotfiles";
        description = "Absolute path to the dotfiles repository on the host.";
      };

      provider = lib.mkOption {
        type = lib.types.str;
        default = "ollama";
        description = "Hermes inference provider.";
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "minimax-m2.7:cloud";
        description = "Default Hermes model ID.";
      };

      backupRoot = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.repoRoot}/modules/features/hermes/state-backup";
        description = "Directory used for local Hermes state backups.";
      };

      backupDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.backupRoot}/snapshot";
        description = "Overwrite-in-place Hermes backup snapshot directory.";
      };
    };

    config = {
      warnings =
        lib.optional
        (cfg.provider == "copilot-acp" && cfg.model != "copilot-acp")
        "my.hermesAgent.model is ignored when provider is \"copilot-acp\"; Hermes ACP requires model.default = \"copilot-acp\".";

      sops.templates."hermes-agent-env" = {
        owner = hermesUser;
        group = hermesGroup;
        mode = "0640";
        content = ''
          COPILOT_GITHUB_TOKEN=${config.sops.placeholder.COPILOT_GITHUB_TOKEN}
          TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
          TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
          OLLAMA_API_KEY=${config.sops.placeholder.OLLAMA_API_KEY}
        '';
      };

      services.hermes-agent = {
        enable = true;
        user = cfg.ownerUser;
        group = ownerGroup;
        createUser = false;
        addToSystemPackages = true;
        environmentFiles = [config.sops.templates."hermes-agent-env".path];
        documents."USER.md" = ./USER.md;
        extraPackages = with pkgs; [
          curl
          gh
          jq
          nix
          openssh
          rsync
        ];

        settings = {
          model = {
            provider = cfg.provider;
            default = effectiveModel;
          };
          toolsets = ["all"];
          max_turns = 120;
          agent = {
            max_turns = 80;
            verbose = false;
          };
          terminal = {
            backend = "local";
            cwd = cfg.repoRoot;
            timeout = 600;
            persistent_shell = true;
          };
          memory = {
            memory_enabled = true;
            user_profile_enabled = true;
          };
          compression = {
            enabled = true;
            threshold = 0.85;
          };
          telegram.require_mention = true;
          display = {
            compact = false;
            tool_progress = "all";
            background_process_notifications = "result";
          };
        };
      };

      system.activationScripts."hermes-agent-soul" = lib.stringAfter ["hermes-agent-setup"] ''
        install -o ${hermesUser} -g ${hermesGroup} -m 0640 \
          ${./SOUL.md} \
          ${hermesStateDir}/.hermes/SOUL.md
      '';

      systemd.services.hermes-agent-backup = {
        description = "Backup Hermes Agent state into dotfiles";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = backupScript;
          User = "root";
        };
      };

      systemd.timers.hermes-agent-backup = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "15m";
          OnUnitActiveSec = "24h";
          Persistent = true;
          Unit = "hermes-agent-backup.service";
        };
      };
    };
  };
}
