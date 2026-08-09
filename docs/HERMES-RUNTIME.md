# Hermes Agent runtime on HP

Hermes Agent runs only on `hp-server`, under the unprivileged
`hermes-agent` system account. NixOS owns the account, state-directory
permissions, SOPS environment, dependencies, resource limits, and systemd
supervision. The Hermes package remains a manual Nix profile installation in
`/var/lib/hermes-agent/.nix-profile`.

The currently known-good Nix profile is pinned through the original
pull-request source:

```text
github:NousResearch/hermes-agent/pull/19766/head
```

An update to upstream `main` was tested on 2026-08-02. Hermes 0.19.1 built,
but its Nix output omitted Hermes' Telegram gateway adapter and logged `No
adapter available for telegram`. The live HP profile was rolled back to 0.12.0
and verified active. See `tasks/hermes-upstream-update.md`; do not switch the
service profile to `main` until that smoke test passes.

## First cutover from the henhal user service

Rebuild HP first. The initial `hermes-agent.service` failure is expected until
the manual executable and state have been migrated.

Stop and disable the old user gateway from a login session as `henhal`:

```bash
systemctl --user disable --now hermes-gateway.service
```

Copy the existing state without copying the obsolete plaintext `.env`:

```bash
sudo rsync -a \
  --exclude=.env \
  --chown=hermes-agent:hermes-agent \
  /home/henhal/.hermes/ \
  /var/lib/hermes-agent/.hermes/
```

Install the current upstream package into the service account's profile:

```bash
sudo hermes-agent-maintenance \
  nix profile add 'github:NousResearch/hermes-agent/pull/19766/head'
```

Validate configuration and start the gateway:

```bash
sudo hermes-agent-maintenance hermes --version
sudo hermes-agent-maintenance hermes config check
sudo hermes-agent-maintenance hermes doctor
sudo systemctl restart hermes-agent.service
sudo systemctl status hermes-agent.service
```

The existing Codex OAuth token on HP was already reporting that its refresh
token had been consumed elsewhere. Reauthenticate from the maintenance shell
if that provider is still required:

```bash
sudo hermes-agent-maintenance
hermes auth
```

## Routine maintenance

Open a shell as the service user with only the Hermes SOPS environment loaded:

```bash
sudo hermes-agent-maintenance
```

Test a future upstream update before replacing the profile. After the update
task's Telegram check succeeds, stop the service, replace its profile source,
and verify the version:

```bash
sudo systemctl stop hermes-agent.service
sudo hermes-agent-maintenance nix profile remove hermes-agent
sudo hermes-agent-maintenance nix profile add 'github:NousResearch/hermes-agent'
sudo hermes-agent-maintenance hermes --version
sudo systemctl start hermes-agent.service
```

Inspect service health and bounded logs:

```bash
systemctl status hermes-agent.service
journalctl -u hermes-agent.service --since today
systemctl show hermes-agent.service \
  -p User -p Group -p MemoryMax -p CPUQuotaPerSecUSec -p TasksMax
```

Do not install Hermes into `/home/henhal`, run it through `docker`, add the
service user to privileged groups, or copy personal SSH keys into its state
directory. Backup and Nextcloud secrets must remain unreadable by this user.
