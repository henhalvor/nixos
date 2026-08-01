# Secrets — declarative secret profiles via sops-nix.
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {
    config,
    lib,
    ...
  }: let
    isHpServer = config.networking.hostName == "hp-server";
    sharedInteractiveFile = ../../secrets/shared-interactive.yaml;
    authFile = ../../secrets/auth.yaml;
    hpAgentFile = ../../secrets/hp-agent.yaml;
    interactiveKeys = [
      "ANTHROPIC_API_KEY"
      "GEMINI_API_KEY"
      "OPENAI_API_KEY"
      "VERTEXAI_PROJECT"
      "VERTEXAI_LOCATION"
      "COPILOT_GITHUB_TOKEN"
      "OLLAMA_API_KEY"
      "DEEPSEEK_API_KEY"
    ];
  in {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

      secrets =
        lib.genAttrs interactiveKeys (_: {
          sopsFile = sharedInteractiveFile;
          owner = "henhal";
          mode = "0400";
        })
        // {
          HENHAL_PASSWORD_HASH = {
            sopsFile = authFile;
            neededForUsers = true;
            mode = "0400";
          };
        }
        // lib.optionalAttrs isHpServer {
          TELEGRAM_BOT_TOKEN = {
            sopsFile = hpAgentFile;
            owner = "henhal";
            mode = "0400";
          };
          TELEGRAM_ALLOWED_USERS = {
            sopsFile = hpAgentFile;
            owner = "henhal";
            mode = "0400";
          };
          HERMES_OLLAMA_API_KEY = {
            sopsFile = hpAgentFile;
            owner = "henhal";
            mode = "0400";
          };
        };

      templates =
        {
          interactive-ai-env = {
            owner = "henhal";
            mode = "0400";
            content = ''
              ANTHROPIC_API_KEY=${config.sops.placeholder.ANTHROPIC_API_KEY}
              GEMINI_API_KEY=${config.sops.placeholder.GEMINI_API_KEY}
              OPENAI_API_KEY=${config.sops.placeholder.OPENAI_API_KEY}
              VERTEXAI_PROJECT=${config.sops.placeholder.VERTEXAI_PROJECT}
              VERTEXAI_LOCATION=${config.sops.placeholder.VERTEXAI_LOCATION}
              COPILOT_GITHUB_TOKEN=${config.sops.placeholder.COPILOT_GITHUB_TOKEN}
              OLLAMA_API_KEY=${config.sops.placeholder.OLLAMA_API_KEY}
              DEEPSEEK_API_KEY=${config.sops.placeholder.DEEPSEEK_API_KEY}
            '';
          };
        }
        // lib.optionalAttrs isHpServer {
          hermes-agent-env = {
            owner = "henhal";
            mode = "0400";
            content = ''
              OLLAMA_API_KEY=${config.sops.placeholder.HERMES_OLLAMA_API_KEY}
              TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
              TELEGRAM_ALLOWED_USERS=${config.sops.placeholder.TELEGRAM_ALLOWED_USERS}
            '';
          };
        };
    };

    # Inject the allowlisted interactive loader and HP-only Hermes launcher.
    home-manager.sharedModules = [self.homeModules.secrets];
  };

  flake.homeModules.secrets = {
    lib,
    osConfig,
    ...
  }: let
    isHpServer = osConfig.networking.hostName == "hp-server";
    interactiveEnv = osConfig.sops.templates.interactive-ai-env.path;
  in {
    home.file.".local/secrets/load-secrets.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Only explicitly interactive credentials enter the shell environment.
        unset ANTHROPIC_API_KEY GEMINI_API_KEY OPENAI_API_KEY
        unset VERTEXAI_PROJECT VERTEXAI_LOCATION COPILOT_GITHUB_TOKEN
        unset OLLAMA_API_KEY DEEPSEEK_API_KEY
        set -a
        source ${interactiveEnv}
        set +a
      '';
    };

    home.file.".local/bin/hermes-secure" = lib.mkIf isHpServer {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        set -a
        source ${osConfig.sops.templates.hermes-agent-env.path}
        set +a
        exec hermes "$@"
      '';
    };
  };
}
