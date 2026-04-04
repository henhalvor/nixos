# Secrets — declarative secret management via sops-nix
# Secrets are encrypted in secrets/secrets.yaml and decrypted at activation time.
# Edit secrets with: sops secrets/secrets.yaml
# Machine decrypts via SSH host key; user edits via personal age key.
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.secrets = {config, ...}: {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

      secrets = {
        ANTHROPIC_API_KEY = {
          group = "keys";
          mode = "0440";
        };
        GEMINI_API_KEY = {
          group = "keys";
          mode = "0440";
        };
        OPENAI_API_KEY = {
          group = "keys";
          mode = "0440";
        };
        VERTEXAI_PROJECT = {
          group = "keys";
          mode = "0440";
        };
        VERTEXAI_LOCATION = {
          group = "keys";
          mode = "0440";
        };
      };
    };

    # Inject HM module that sources decrypted secrets into shell env
    home-manager.sharedModules = [self.homeModules.secrets];
  };

  flake.homeModules.secrets = {...}: {
    # Source all sops secrets as env vars in the shell
    home.file.".local/secrets/load-secrets.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Auto-generated: sources sops-nix decrypted secrets from /run/secrets/
        secret_dir="/run/secrets"
        [ -d "$secret_dir" ] || exit 0
        for f in "$secret_dir"/*; do
          [ -f "$f" ] || continue
          name="$(basename "$f")"
          # Skip files with dots (sops metadata)
          case "$name" in *.*) continue;; esac
          value="$(cat "$f" 2>/dev/null)" || continue
          export "$name=$value"
        done
      '';
    };
  };
}
