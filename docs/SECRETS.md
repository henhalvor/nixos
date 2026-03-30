# Secrets Management

This project uses [sops-nix](https://github.com/Mic92/sops-nix) with
[age](https://github.com/FiloSottile/age) encryption for declarative,
version-control-safe secret management.

---

## Concepts

### What Is SOPS?

[SOPS](https://github.com/mozilla/sops) (Secrets OPerationS) is a Mozilla tool
that encrypts the **values** of structured files (YAML, JSON, ENV, INI) while
leaving the **keys** in plaintext. This means you can see *which* secrets exist
in a git diff, but never their contents.

### What Is age?

[age](https://github.com/FiloSottile/age) is a modern, simple encryption tool.
We use it instead of GPG because:

- No keyservers or web of trust to manage
- SSH Ed25519 host keys can be converted to age keys directly
- Simpler key management — just a file with a single key

### What Is sops-nix?

[sops-nix](https://github.com/Mic92/sops-nix) is a NixOS module that
integrates SOPS into the NixOS activation process. During `nixos-rebuild
switch`, it automatically decrypts your secrets and places them as individual
files under `/run/secrets/`.

### Key Types

There are two categories of age keys in this project:

| Key Type | Purpose | Where It Lives |
|----------|---------|----------------|
| **Personal key** | For *editing* secrets on your workstation | `~/.config/sops/age/keys.txt` |
| **Machine key** | For *decrypting* secrets at system activation | Derived from `/etc/ssh/ssh_host_ed25519_key` |

Your personal key lets you run `sops secrets/secrets.yaml` to view and edit
secrets in plaintext. Machine keys let each NixOS host decrypt secrets during
boot — without your personal key being present on the machine.

---

## Data Flow

Here is the complete lifecycle of a secret, from creation to use:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        EDIT TIME (your laptop)                      │
│                                                                     │
│  You run: sops secrets/secrets.yaml                                 │
│                                                                     │
│  SOPS decrypts using your personal age key                          │
│  (~/.config/sops/age/keys.txt)                                      │
│                                                                     │
│  Your $EDITOR opens with plaintext YAML:                            │
│    ANTHROPIC_API_KEY: sk-ant-api03-...                               │
│    GEMINI_API_KEY: AIzaSy...                                        │
│                                                                     │
│  On save, SOPS re-encrypts for ALL recipients listed in             │
│  .sops.yaml (your personal key + all machine keys)                  │
│                                                                     │
│  Encrypted file is safe to commit to git                            │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ git push / nixos-rebuild
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     BUILD TIME (nixos-rebuild)                       │
│                                                                     │
│  secrets/secrets.yaml is copied into the Nix store (still encrypted)│
│  No secrets are exposed during evaluation or build                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ system activation
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   ACTIVATION TIME (target machine)                   │
│                                                                     │
│  sops-nix reads the machine's SSH host key:                         │
│    /etc/ssh/ssh_host_ed25519_key                                    │
│                                                                     │
│  Converts it to an age private key (in memory)                      │
│                                                                     │
│  Decrypts each declared secret and writes it to:                    │
│    /run/secrets/ANTHROPIC_API_KEY    (mode 0400, owner root)        │
│    /run/secrets/GEMINI_API_KEY                                      │
│    /run/secrets/OPENAI_API_KEY                                      │
│    /run/secrets/VERTEXAI_PROJECT                                    │
│    /run/secrets/VERTEXAI_LOCATION                                   │
│                                                                     │
│  /run/secrets/ is a ramfs — secrets exist only in memory,           │
│  never written to disk unencrypted                                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ shell login
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      RUNTIME (your shell)                           │
│                                                                     │
│  Zsh init calls load_secrets() which iterates /run/secrets/*        │
│  and exports each file as an environment variable:                  │
│                                                                     │
│    export ANTHROPIC_API_KEY="sk-ant-api03-..."                      │
│    export GEMINI_API_KEY="AIzaSy..."                                │
│                                                                     │
│  Your tools (aider, claude, etc.) read these env vars normally      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Project File Layout

```
~/.dotfiles/
├── .sops.yaml                         # Key registry + path rules
├── secrets/
│   └── secrets.yaml                   # Encrypted secrets (committed to git)
├── modules/features/
│   └── secrets.nix                    # NixOS + HM module (declares which secrets to decrypt)
└── flake.nix                          # sops-nix input
```

### `.sops.yaml`

The central configuration file. It defines:

1. **Keys** — all age public keys (personal + machine) with YAML anchors
2. **Creation rules** — which keys can encrypt/decrypt which files

```yaml
keys:
  - &henhal age13azyggpzlzzsp3levku6ecjaqd3cq3eapeu9e6nnrzp6eguk6cwscsted0
  - &lenovo age1sxv8q8hlyc8lhy3ydzexds93rl8pdql944hm4y2df56pq4qssujskg3k9q

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env)$
    key_groups:
      - age:
        - *henhal
        - *lenovo
```

**Important:** Every machine that needs to decrypt secrets must have its age
public key listed here. If you add a new host, you must add its key and
re-encrypt (see [Adding a New Machine](#adding-a-new-machine)).

### `secrets/secrets.yaml`

The encrypted secrets file. Values are encrypted, keys are plaintext:

```yaml
ANTHROPIC_API_KEY: ENC[AES256_GCM,data:iCdbA05u7GN4xho=,...]
GEMINI_API_KEY: ENC[AES256_GCM,data:nAeWjs/ZmlpO2vw=,...]
sops:
    age:
        - recipient: age13azyggpzlzzsp3levku6ecjaqd3cq3eapeu9e6nnrzp6eguk6cwscsted0
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
```

This file is **safe to commit to git**. The values can only be read by holders
of the corresponding private keys.

### `modules/features/secrets.nix`

The NixOS module that wires sops-nix into the system:

```nix
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
```

Each entry in `sops.secrets` maps to a key in `secrets.yaml`. At activation,
each becomes a file at `/run/secrets/<NAME>`.

---

## How-To Guides

### Initial Setup (One-Time Per User)

Generate a personal age key for editing secrets:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

This prints your public key (starts with `age1...`). Add it to `.sops.yaml`
under the `keys:` section.

**Keep `keys.txt` safe.** Back it up somewhere secure. If you lose it, you
cannot edit secrets (though machines can still decrypt via their own keys).

### Editing Existing Secrets

```bash
cd ~/.dotfiles
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

This opens your `$EDITOR` with the decrypted YAML. Edit values, save, and quit.
SOPS automatically re-encrypts on save. Then commit:

```bash
git add secrets/secrets.yaml
git commit -m "chore: update secrets"
sudo nixos-rebuild switch --flake .#<hostname>
```

### Adding a New Secret

**Step 1:** Add the value to the encrypted file:

```bash
nix-shell -p sops --run "sops secrets/secrets.yaml"
```

Add your new key-value pair:

```yaml
ANTHROPIC_API_KEY: sk-ant-...
GEMINI_API_KEY: AIza...
MY_NEW_SECRET: my-secret-value    # ← add this
```

Save and quit.

**Step 2:** Declare it in `modules/features/secrets.nix`:

```nix
sops.secrets = {
  ANTHROPIC_API_KEY = {};
  GEMINI_API_KEY = {};
  MY_NEW_SECRET = {};    # ← add this
};
```

**Step 3:** Rebuild:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

The secret is now available at `/run/secrets/MY_NEW_SECRET` and will be
auto-exported as `$MY_NEW_SECRET` in your shell.

### Removing a Secret

1. Remove the key from `secrets/secrets.yaml` via `sops`
2. Remove the entry from `sops.secrets` in `secrets.nix`
3. Rebuild

### Adding a New Machine

**Step 1:** Get the machine's age public key (run on the target machine):

```bash
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

This converts the machine's SSH Ed25519 host key to an age public key.

**Step 2:** Add it to `.sops.yaml`:

```yaml
keys:
  - &henhal age13azyggpzlzzsp3levku6ecjaqd3cq3eapeu9e6nnrzp6eguk6cwscsted0
  - &lenovo age1sxv8q8hlyc8lhy3ydzexds93rl8pdql944hm4y2df56pq4qssujskg3k9q
  - &workstation age1abc...def    # ← new machine

creation_rules:
  - path_regex: secrets/[^/]+\.(yaml|json|env)$
    key_groups:
      - age:
        - *henhal
        - *lenovo
        - *workstation            # ← add reference
```

**Step 3:** Re-encrypt secrets for the new key set:

```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

This re-encrypts the file so the new machine can also decrypt it.

**Step 4:** Commit and deploy:

```bash
git add .sops.yaml secrets/secrets.yaml
git commit -m "chore: add workstation to sops keys"
```

### Rotating Keys

If a machine is decommissioned or compromised:

1. Remove its key from `.sops.yaml`
2. Run `sops updatekeys secrets/secrets.yaml` to re-encrypt without that key
3. Rotate any secrets that may have been exposed
4. Commit and rebuild all remaining machines

### Using Secrets in NixOS Services

For NixOS services that need a secret file (not an env var), use the
`sops.secrets.<name>.path` attribute:

```nix
# In a feature module:
sops.secrets.MY_SERVICE_TOKEN = {
  owner = "myservice";
  group = "myservice";
  mode = "0400";
};

services.myservice = {
  enable = true;
  tokenFile = config.sops.secrets.MY_SERVICE_TOKEN.path;
};
```

The `path` attribute returns the actual path (e.g. `/run/secrets/MY_SERVICE_TOKEN`).
You can also set `owner`, `group`, and `mode` to control file permissions.

### Using Secrets in Home Manager

For Home Manager programs that need secrets as environment variables, the
current setup handles this automatically via the zsh `load_secrets` function.

For HM programs that need a secret *file*, you can use `sops-nix`'s Home
Manager module directly. Add to `secrets.nix`:

```nix
flake.homeModules.secrets = { config, ... }: {
  imports = [ inputs.sops-nix.homeManagerModules.sops ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.keyFile = "/home/henhal/.config/sops/age/keys.txt";

    secrets.MY_HM_SECRET = {
      path = "${config.home.homeDirectory}/.config/myapp/token";
    };
  };
};
```

---

## Secret Permissions

By default, sops-nix creates secrets with:

| Property | Default |
|----------|---------|
| Owner | `root` |
| Group | `keys` |
| Mode | `0400` (read-only by owner) |

This means only root (and the `keys` group) can read secrets directly. The zsh
`load_secrets` function works because it runs as your user and can read
`/run/secrets/*` (the directory is `0751` owned by `root:keys`, and your user
is in the `keys` group via sops-nix).

To customize permissions for a specific secret:

```nix
sops.secrets.DATABASE_PASSWORD = {
  owner = "postgres";
  group = "postgres";
  mode = "0440";
};
```

---

## Troubleshooting

### `Failed to get the data key required to decrypt the SOPS file`

**Cause:** SOPS can't find your age private key.

**Fix:** Ensure your key file exists at the expected path:

```bash
ls -la ~/.config/sops/age/keys.txt
```

The file should contain a line starting with `AGE-SECRET-KEY-...`. If missing,
regenerate with `age-keygen`.

### `no matching creation rules found`

**Cause:** The file path doesn't match any `path_regex` in `.sops.yaml`.

**Fix:** Ensure your secrets file is under `secrets/` and has a `.yaml`,
`.json`, or `.env` extension, matching the regex in `.sops.yaml`.

### Secrets not available after rebuild

**Check 1:** Is the secret declared in `sops.secrets`?

```bash
grep MY_SECRET modules/features/secrets.nix
```

**Check 2:** Does the decrypted file exist?

```bash
sudo ls -la /run/secrets/
```

**Check 3:** Can your user read it?

```bash
sudo cat /run/secrets/MY_SECRET
```

**Check 4:** Is the machine's key in `.sops.yaml`? If not, add it and run
`sops updatekeys`.

### `error: Cannot decrypt the data key with any of the provided master keys`

**Cause:** The machine's age key (derived from SSH host key) is not listed as a
recipient in the encrypted file.

**Fix:** Add the machine's key to `.sops.yaml` and re-encrypt:

```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

### Secrets not exported in shell

**Check:** Open a new terminal and run:

```bash
echo $ANTHROPIC_API_KEY
```

If empty, manually trigger the loader:

```bash
load_secrets
echo $ANTHROPIC_API_KEY
```

If `load_secrets` fails, check that `/run/secrets/` has files and your user can
read them.

---

## Security Notes

- **Encrypted file in git:** `secrets/secrets.yaml` is encrypted at rest. Only
  key holders can read values. Key names are visible (by design — SOPS encrypts
  values, not keys).

- **Decrypted secrets in memory only:** `/run/secrets/` is a ramfs mount.
  Secrets are never written to disk in plaintext.

- **Shell environment:** The `load_secrets` function exports secrets as
  environment variables. These are visible to all processes in your shell
  session (same as any env var). This is the standard pattern for CLI tools
  that read API keys from env.

- **Key backup:** Your personal key (`~/.config/sops/age/keys.txt`) is the
  master editing key. Back it up securely. Machine keys are derived from SSH
  host keys, which are regenerated on NixOS reinstall — if you reinstall,
  you'll need to update `.sops.yaml` with the new machine key.

- **Never commit `keys.txt`:** Your age private key should never be in the
  repository. It stays on your local machine only.
