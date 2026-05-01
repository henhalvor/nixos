{inputs, ...}: {
  flake.nixosModules.firecrawl = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.my.firecrawl;
    ownerHome = lib.attrByPath ["users" "users" cfg.ownerUser "home"] "/home/${cfg.ownerUser}" config;
    ownerGroup = lib.attrByPath ["users" "users" cfg.ownerUser "group"] "users" config;
  in {
    options.my.firecrawl = {
      ownerUser = lib.mkOption {
        type = lib.types.str;
        default = "henhal";
        description = "Interactive workstation user who owns the firecrawl integration.";
      };
      repoRoot = lib.mkOption {
        type = lib.types.str;
        default = "${ownerHome}/.dotfiles";
        description = "Absolute path to the dotfiles repository on the host.";
      };

      firecrawlComposeFile = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.repoRoot}/modules/features/ai/firecrawl/firecrawl-compose.yml";
        description = "Path to the firecrawl docker-compose.yml file.";
      };
    };

    config = {
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

      # ─── Self-hosted Firecrawl (docker-compose) ───────────────────────────
      # Clone firecrawl repo during activation so docker build can access sibling
      # files (compose build contexts are resolved relative to the compose file).
      # Runs once; subsequent activations skip if already cloned.
      systemd.services.firecrawl-bootstrap = {
        description = "Bootstrap Firecrawl repository";

        wantedBy = ["multi-user.target"];
        after = ["network-online.target"];
        wants = ["network-online.target"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };

        script = ''
          firecrawl_src='${cfg.repoRoot}/.firecrawl-src'

          if [ ! -d "$firecrawl_src/.git" ]; then
            ${pkgs.git}/bin/git clone --depth 1 https://github.com/mendableai/firecrawl.git "$firecrawl_src"
          fi

          cp ${cfg.firecrawlComposeFile} "$firecrawl_src/firecrawl-override.yml"
        '';
      };
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
    };
  };
}
