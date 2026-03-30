# Secrets — declarative secret management via sops-nix
# Secrets are encrypted in secrets/secrets.yaml and decrypted at activation time.
# Edit secrets with: sops secrets/secrets.yaml
# Machine decrypts via SSH host key; user edits via personal age key.
{ self, inputs, ... }: {
  flake.nixosModules.secrets = { config, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      defaultSopsFile = ../../secrets/secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets = {
        ANTHROPIC_API_KEY = {};
        GEMINI_API_KEY = {};
        OPENAI_API_KEY = {};
        VERTEXAI_PROJECT = {};
        VERTEXAI_LOCATION = {};
      };
    };

    # Inject HM module that sources decrypted secrets into shell env
    home-manager.sharedModules = [ self.homeModules.secrets ];
  };

  flake.homeModules.secrets = { ... }: {
    # Source all sops secrets as env vars in the shell
    home.file.".local/secrets/load-secrets.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Auto-generated: sources sops-nix decrypted secrets from /run/secrets/
        for f in /run/secrets/*; do
          [ -f "$f" ] || continue
          name="$(basename "$f")"
          # Skip files with dots (sops metadata)
          [[ "$name" == *.* ]] && continue
          value="$(cat "$f" 2>/dev/null)" || continue
          export "$name=$value"
        done
      '';
    };
  };
}
