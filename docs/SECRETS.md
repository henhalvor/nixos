# Secrets management

## Troubleshooting

### Editing an HP-only profile on HP

Personal age identities normally live on workstation or Lenovo in
`~/.config/sops/age/keys.txt`. HP-only profiles also include an age recipient
derived from HP's SSH host key, so `sops-nix` can decrypt them at activation.
The recipient is native age format (`age1...`), not an SSH recipient
(`ssh-ed25519 ...`), so pointing `SOPS_AGE_SSH_PRIVATE_KEY_FILE` directly at
`/etc/ssh/ssh_host_ed25519_key` does not work for these files.

To edit such a profile directly on HP, derive the native age identity in
memory and pass it to SOPS. The SSH host private key is root-only, so use:

```bash
nix-shell -p sops ssh-to-age

SOPS_BIN="$(command -v sops)"
SSH_TO_AGE_BIN="$(command -v ssh-to-age)"

sudo env \
  SOPS_AGE_KEY_CMD="$SSH_TO_AGE_BIN -private-key -i /etc/ssh/ssh_host_ed25519_key" \
  "$SOPS_BIN" secrets/opencloud.yaml
```

`ssh-to-age` writes the derived private age identity only to SOPS through a
pipe: it is neither displayed nor saved to disk. Do not generate a new age key
to recover an existing file; it cannot decrypt the file's current recipients.
After editing as root, verify that Git-tracked files remain user-owned:

```bash
stat -c '%U:%G %a %n' secrets/opencloud.yaml
```

This repository uses `sops-nix` and age. Encrypted secret files are safe to
commit, but access is deliberately split by purpose and host. A machine can
only decrypt profiles whose age recipient list includes that machine's SSH
host key.

## Profiles

| File | Runtime access | Contents |
| --- | --- | --- |
| `secrets/shared-interactive.yaml` | henhal on all hosts | AI and coding credentials approved for interactive shells |
| `secrets/auth.yaml` | system activation on all hosts | Initial account password hash |
| `secrets/hp-agent.yaml` | HP server only | Hermes Telegram, agent-only provider, Firecrawl, and Workspace credentials |
| `secrets/workstation-services.yaml` | workstation only | OpenCode server credentials |
| `secrets/syncthing/<host>.yaml` | matching host only | Host-specific Syncthing identity |
| `secrets/opencloud.yaml` | HP server only, when added | OpenCloud, Keycloak, and Cloudflare Tunnel credentials |
| `secrets/hp-backup.yaml` | HP server root services only, when added | Restic/S3 backup credentials |

The last two paths already have recipient rules in `.sops.yaml`; create them
when those services are implemented. Do not add an empty encrypted file.

Every profile includes the two personal editor keys. Machine recipients are
the minimum required by that profile. In particular, Lenovo and workstation
machine keys cannot decrypt `hp-agent.yaml`, so Telegram credentials are
available only to the HP server at runtime.

## Runtime access

At activation, `sops-nix` decrypts declared secrets into `/run/secrets` and
generated templates into `/run/secrets-rendered`. These are runtime files, not
Nix store values. File ownership and mode determine which process may read
them.

Interactive shells source only the explicit allowlist rendered as
`interactive-ai-env`. Zsh and the Neovim/Yazi wrapper call:

```text
~/.local/secrets/load-secrets.sh
```

This loader never scans `/run/secrets/*`. Service credentials therefore do
not leak into every terminal or child process.

On the HP server, open a maintenance shell as the dedicated Hermes service
account with:

```bash
sudo hermes-agent-maintenance
```

That command loads only `hermes-agent-env`. The supervised gateway receives
the same file directly from systemd. Firecrawl and Hermes Workspace receive
separate environment files with restrictive ownership and mode. Backup and
OpenCloud credentials should follow the same service-only pattern; do not add
them to the shell loader.

Environment variables are inherited by child processes and may be visible to
same-user debugging tools. For work that does not need interactive AI keys,
remove them from the current shell with:

```bash
unset ANTHROPIC_API_KEY GEMINI_API_KEY OPENAI_API_KEY VERTEXAI_PROJECT
unset VERTEXAI_LOCATION COPILOT_GITHUB_TOKEN OLLAMA_API_KEY DEEPSEEK_API_KEY
```

## Editing a profile

Use a personal age key stored at `~/.config/sops/age/keys.txt`:

```bash
sops secrets/shared-interactive.yaml
sops secrets/hp-agent.yaml
```

To add a new profile, first add an exact `path_regex` and its minimal recipient
set to `.sops.yaml`, then create it:

```bash
sops secrets/opencloud.yaml
```

Never place plaintext values in Nix expressions, shell scripts, command-line
arguments, or Git. The YAML value shown in the repository must start with
`ENC[`.

## Adding a secret consumer

1. Put the secret in the narrowest appropriate encrypted profile.
2. Declare `sops.secrets.<name>.sopsFile` explicitly in the owning module.
3. Set the narrowest owner and `mode = "0400"`.
4. For a service, create a service-specific `sops.templates` environment file.
5. Reference the generated runtime path from the service configuration.
6. Evaluate/build every affected host and verify the secret is absent from
   unrelated host configurations.

Do not restore `defaultSopsFile` or wildcard shell loading. Explicit source
files make profile boundaries reviewable and prevent a newly declared service
secret from being silently exported into interactive sessions.

## Adding or replacing a machine

Get its age recipient from the SSH Ed25519 host public key:

```bash
ssh-keyscan -t ed25519 HOST 2>/dev/null | ssh-to-age
```

Add the recipient only to profiles the machine needs, then rewrap those files:

```bash
sops updatekeys secrets/shared-interactive.yaml
sops updatekeys secrets/auth.yaml
```

Before removing an old recipient, confirm a personal key and the replacement
machine can decrypt the required profiles. Then remove it from `.sops.yaml`
and run `sops updatekeys` on every affected file.

## Rotation and incident response

Changing SOPS recipients only changes who can decrypt future ciphertext. It
does not invalidate a credential previously decrypted by a machine or present
in Git history. Rotate the credential at its provider, update the relevant
profile, deploy the consumer, verify it, and only then revoke the old value.

If plaintext is accidentally committed, treat the credential as compromised:

1. Revoke or rotate it at the provider immediately.
2. Store the replacement in the correct SOPS profile.
3. Deploy and verify the replacement.
4. Remove the plaintext from current Git content. History rewriting is a
   separate coordinated operation and does not replace rotation.

Keep personal age keys and SSH host private keys backed up securely. Losing all
authorized private keys makes the encrypted profiles unrecoverable.
