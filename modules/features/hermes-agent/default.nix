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

      vaultPath = lib.mkOption {
        type = lib.types.str;
        default = "${ownerHome}/Vault";
        description = "Absolute path to the Obsidian vault directory.";
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

      firecrawlComposeFile = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.repoRoot}/modules/features/hermes-agent/firecrawl-compose.yml";
        description = "Path to the firecrawl docker-compose.yml file.";
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
          FIRECRAWL_API_URL=http://localhost:3002
        '';
      };

      # Expose OPENAI_API_KEY as a readable env file so the firecrawl
      # docker-compose service (running as root) can source it.
      sops.templates."firecrawl-env" = {
        owner = "root";
        group = "root";
        mode = "0644";
        path = "/etc/firecrawl.env";
        content = ''
          OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
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
        documents."AGENTS.md" = ./AGENTS.md;
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

      system.activationScripts."hermes-vault-init" = lib.stringAfter ["hermes-agent-setup"] ''
        vault_root=${lib.escapeShellArg cfg.vaultPath}
        owner=${lib.escapeShellArg cfg.ownerUser}
        group=${lib.escapeShellArg ownerGroup}

        # Create main directories
        ${pkgs.coreutils}/bin/mkdir -p "$vault_root"/Agent-Shared/projects
        ${pkgs.coreutils}/bin/mkdir -p "$vault_root"/Agent-Hermes/daily

        # Helper to create a file only if it doesn't exist
        create_if_missing() {
          local file=$1
          local content=$2
          if [ ! -f "$file" ]; then
            printf '%s\n' "$content" > "$file"
            ${pkgs.coreutils}/bin/chown "$owner:$group" "$file"
            ${pkgs.coreutils}/bin/chmod 0640 "$file"
          fi
        }

        # Initialize vault files with templates if missing
        create_if_missing "$vault_root/Agent-Shared/today.md" \
          "## Tasks Today
- [ ] Review vault structure

## Scheduled
"

        create_if_missing "$vault_root/Agent-Shared/project-state.md" \
          "## Active projects
(none)

## On hold
(none)

## Completed
(none)
"

        create_if_missing "$vault_root/Agent-Shared/decisions-log.md" \
          "# Decisions Log
Append-only record of decisions made.
"

        create_if_missing "$vault_root/Agent-Shared/user-profile.md" \
          "## Identity
Name: Henrik

## Working style
(to be filled)

## Tools
Editor: nvim
Shell: zsh
Default code directory: ~/code

## Stable facts
(to be filled)
"

        create_if_missing "$vault_root/Agent-Hermes/working-context.md" \
          "# Working Context
Current task: (empty)
"

        create_if_missing "$vault_root/Agent-Hermes/mistakes.md" \
          "# Mistakes Log
Append-only record of errors and corrections.
"

        # Set permissions recursively
        ${pkgs.coreutils}/bin/chown -R "$owner:$group" "$vault_root"
        ${pkgs.findutils}/bin/find "$vault_root" -type f -exec ${pkgs.coreutils}/bin/chmod 0640 {} \;
        ${pkgs.findutils}/bin/find "$vault_root" -type d -exec ${pkgs.coreutils}/bin/chmod 0750 {} \;
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

      # ─── Self-hosted Firecrawl (docker-compose) ───────────────────────────
      # Clone firecrawl repo during activation so docker build can access sibling
      # files (compose build contexts are resolved relative to the compose file).
      # Runs once; subsequent activations skip if already cloned.
      system.activationScripts.firecrawl-clone = lib.stringAfter ["hermes-agent-setup"] ''
        firecrawl_src='${cfg.repoRoot}/.firecrawl-src'
        if [ ! -d "$firecrawl_src/.git" ]; then
          ${pkgs.git}/bin/git clone --depth 1 https://github.com/mendableai/firecrawl.git "$firecrawl_src"
        fi
        # Copy our compose override into the clone so relative build contexts resolve
        cp '${cfg.firecrawlComposeFile}' "$firecrawl_src/firecrawl-override.yml"
      '';

      systemd.services.firecrawl = {
        description = "Self-hosted Firecrawl web scraping API";
        wantedBy = ["multi-user.target"];
        after = ["docker.service"];
        requires = ["docker.service"];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        serviceConfig.TimeoutStopSec = 300;
        serviceConfig.User = "root";
        serviceConfig.ExecStart =
          "${pkgs.docker}/bin/docker compose "
          + "--env-file /etc/firecrawl.env "
          + "-f '${cfg.repoRoot}/.firecrawl-src/docker-compose.yaml' "
          + "-f '${cfg.repoRoot}/.firecrawl-src/firecrawl-override.yml' "
          + "up -d";
        serviceConfig.ExecStop =
          "${pkgs.docker}/bin/docker compose "
          + "-f '${cfg.repoRoot}/.firecrawl-src/docker-compose.yaml' "
          + "down";
      };

      # ─── Firecrawl MCP Server ────────────────────────────────────────────
      # Connects to the local self-hosted Firecrawl instance. Tools appear
      # in Hermes as mcp_firecrawl_*.
      services.hermes-agent.mcpServers = {
        firecrawl = {
          command = "npx";
          args = ["-y" "firecrawl-mcp"];
          env = {
            FIRECRAWL_API_URL = "http://localhost:3002";
          };
        };
      };
    };
  };
}
