# Documentation audit issues

Audit date: 2026-08-23

Scope: the Markdown files directly under `docs/`. Markdown files in nested
directories were not audited as primary documents. Existing nested paths were
checked only when a root document linked to them.

The comparisons used the flake, host configurations, feature modules,
`install.sh`, the checked-in secret files, and the current worktree. This file
is the only file created by this audit. Existing documentation and system
configuration were not changed.

## Confirmed discrepancies

### 1. Repository hardware file name is wrong in `ARCHITECTURE.md`

`docs/ARCHITECTURE.md:150-156` and `docs/ARCHITECTURE.md:282-285` describe the
repository host file as `hardware-configuration.nix`.

The actual repository uses `hosts/*/hardware.nix`, and `install.sh:7-10`,
`install.sh:138-139`, and `install.sh:323-350` use that name. The generated
NixOS source file remains `/etc/nixos/hardware-configuration.nix`, so the
distinction in `docs/INSTALL.md` is correct. The architecture document is
inconsistent with both the checkout and the installer.

### 2. `FEATURES.md` is not a complete or fully accurate feature reference

`docs/FEATURES.md:1-4` calls the document a complete list, but active host
configurations use feature modules that are absent from the tables. Examples
include `freecad`, `opencloudDesktop`, `thunderbird`, `onlyoffice`,
`kdeconnect`, `codecrafters-cli`, `ohMyPi`, and the HP cloud/backup modules
`opencloudConsistentSource`, `githubMirror`, and `hpResticS3`. Their module
declarations and host imports are present in the checkout.

The standalone package table at `docs/FEATURES.md:187-201` also omits at least
the `nvim` package, despite the module documenting `nix run .#nvim` at line
102, and the `omp` package exposed by `modules/features/applications/oh-my-pi.nix:48-68`.

Several listed descriptions also disagree with their implementations:

- `docs/FEATURES.md:10` says the core infrastructure is imported by every host,
  but the same table says `bootloader` is used only by Lenovo and HP while
  `secureBoot` is used by the workstation.
- `docs/FEATURES.md:31` says `externalIo` provides Logitech/solaar and USB
  rules. `modules/features/system/external-io.nix:1-6` only enables `udisks2`.
  Logitech configuration is set directly in the workstation and Lenovo host
  files.
- `docs/FEATURES.md:41` describes `minimalBattery` as TLP plus
  power-profiles-daemon. `modules/features/system/minimal-battery.nix:9-30` and
  `:71-80` instead implement custom CPU/GPU caps, `ryzenadj`, cpufreq,
  powertop, tuned, and upower settings.
- `docs/FEATURES.md:53` says `laptopServer` includes wake-on-LAN.
  `modules/features/system/laptop-server.nix:5-21` configures lid handling and
  the performance CPU governor, with no wake-on-LAN setting.

### 3. `HOSTS.md` repeats the `externalIo` ownership error and has a misleading Nix-on-Droid snippet

The workstation and Lenovo service lists at `docs/HOSTS.md:30-34` and
`docs/HOSTS.md:147-152` attribute Logitech wireless and USB rules to
`externalIo`. The actual module only enables `udisks2`, as described above.

The Nix-on-Droid block at `docs/HOSTS.md:347-352` is not an effective copyable
configuration. Values such as `user.shell = zsh;` and
`terminal.colors = gruvbox-dark-hard;` are unquoted identifiers rather than the
actual values. The live module uses the zsh executable path, a concrete Hack
Nerd Font file path, and the `terminalColors` attrset in
`modules/nix-on-droid/default.nix:7-18` and `:53-56`.

### 4. Monitoring documentation includes inactive services and a broken link

`docs/MONITORING.md:15-16` links to
`plans/security-monitoring-implementation.md`. That path is absent in the
current worktree. The current replacement is
`docs/plans/complete/security-monitoring-implementation.md`, which is an
untracked file in the existing worktree state.

`docs/MONITORING.md:24-26` says Firecrawl and Hermes are monitored as active
HP services. The effective HP configuration does not enable them:

- `hosts/hp-server/configuration.nix:43-46` comments out their feature imports.
- `hosts/hp-server/configuration.nix:175-187` comments out their monitored
  systemd units.
- `hosts/hp-server/configuration.nix:190-202` overrides the local probes to
  Grafana, Keycloak, and OpenCloud only.

The monitoring module has Firecrawl and Hermes probe defaults at
`modules/features/monitoring/hub.nix:211-220`, but the HP host override removes
those defaults. `docs/HOSTS.md:313-314` correctly says those services are not
enabled, so the two root documents conflict.

The routine status command at `docs/MONITORING.md:197-203` also omits
`prometheus-blackbox-exporter`, even though the hub enables it at
`modules/features/monitoring/hub.nix:511-514` and `docs/COMMANDS.md` includes
it.

### 5. `SECRETS.md` describes active profiles as future profiles and describes an inactive Hermes runtime

`docs/SECRETS.md:51-52` says `secrets/opencloud.yaml` and
`secrets/hp-backup.yaml` are used "when added". Both files exist, and the HP
configuration enables OpenCloud and the HP backup profile at
`hosts/hp-server/configuration.nix:121-151`. The consuming modules are
`modules/features/cloud/opencloud.nix`, `modules/features/auth/keycloak.nix`,
and `modules/features/backup/restic-s3.nix`.

`docs/SECRETS.md:95-105` presents `hermes-agent-maintenance`, the supervised
Hermes gateway, and Firecrawl/Hermes Workspace environment files as current HP
runtime behavior. The corresponding feature imports and enable flags are
commented out in `hosts/hp-server/configuration.nix:43-46` and `:210-212`.
The maintenance command is defined by `modules/features/ai/hermes-runtime.nix`
only when that module is enabled. This section therefore describes a planned
or previously intended runtime, not the current effective HP configuration.

### 6. `Security.md` still describes Nextcloud, while the configured service is OpenCloud

The Nextcloud-specific material in `docs/Security.md:97-99`,
`:144-160`, `:214-217`, `:240-243`, and `:250-259` is stale for the current
checkout. It names Nextcloud as the service receiving credentials, the
authoritative file service, the session/application to revoke, and the service
to review during periodic checks.

The current service is OpenCloud, enabled at
`hosts/hp-server/configuration.nix:121-126` and implemented in
`modules/features/cloud/opencloud.nix`. `docs/CLOUD.md` uses the current
OpenCloud naming. The security guidance should be retargeted to the configured
service rather than treating Nextcloud as an alternate spelling.

### 7. `Security.md` contradicts active monitoring and current group ownership

`docs/Security.md:250-253` says automated monitoring has not been implemented.
The HP host enables the monitoring hub, notifications, and heartbeats at
`hosts/hp-server/configuration.nix:190-195`.

The policy at `docs/Security.md:44-53` says host-specific privileges should not
be placed in general user identity. The shared user module nevertheless assigns
`libvirtd`, `keys`, and `bluetooth` in
`modules/users/henhal.nix:4-10`, alongside the genuinely general groups. This
is a policy/configuration mismatch even though other feature-owned groups are
handled elsewhere.

### 8. `BACKUP.md` overstates which writers are stopped for the identity export

`docs/BACKUP.md:26-34` says the Keycloak PostgreSQL and OpenLDAP exports are
created while the relevant writers are stopped.

The implementation at `modules/features/backup/restic-s3.nix:108-145` runs
`pg_dump` against the live Keycloak PostgreSQL service. It stops OpenCloud and
OpenLDAP for the LDAP export, then restarts them. The documentation should
distinguish the live transaction-consistent PostgreSQL logical dump from the
stopped-writer OpenLDAP export. This is a documentation accuracy issue, not a
claim that the backup implementation itself must be changed.

### 9. The documented installer one-liner is not compatible with the script's interactive Bash behavior

`docs/INSTALL.md:13-17` and `:100-104` tell users to pipe the installer to
`sh`. The script declares Bash at `install.sh:1`, uses Bash-specific syntax,
and reads its interactive menu directly from standard input at
`install.sh:150-153`. In a normal `curl | sh` pipeline, standard input is the
script stream, and the script itself reports that it requires a TTY when no
choice is received. The documented invocation therefore does not reliably
support the interactive menu.

The same installer treats every nonzero `nix flake check` result as a warning
and continues at `install.sh:368-374`, while `docs/INSTALL.md:270-275` frames
the failure mainly as warnings that do not prevent building. A read-only check
on 2026-08-23 exited nonzero because the `react-native` dev shell still
references Node.js 20, whose upstream support was removed on 2026-04-30. The
documentation should distinguish a warning from a failed validation result.

## Claims that cannot be confirmed from the Nix checkout

These are not proven false by the repository, but the root documents present
them as current external state without a declarative source of truth:

- `docs/CLOUD.md` describes Cloudflare Access/cache behavior, Keycloak realm
  and client details, MFA, and external routing. The Keycloak module explicitly
  says provider data is intentionally not guessed in Nix at
  `modules/features/auth/keycloak.nix:1-3`.
- `docs/MONITORING.md:40-43` and its validation sections describe the current
  public Grafana/Keycloak setup and alert delivery. The Nix checkout configures
  the services and secrets, but cannot confirm live Keycloak provider data,
  Cloudflare state, Telegram delivery, or Healthchecks.io delivery.
- `docs/TAILSCALE-ACCESS.md` describes tailnet policy and device authorization.
  The checkout configures local Tailscale services and firewall behavior, but
  tailnet ACL and device state are external.

These claims need either live verification or an explicit label that they are
operator-managed external state.

## Areas that matched the current configuration

No confirmed discrepancy was found in `docs/COMMANDS.md`. The documented host
names, `server-tailscale` deployment target, `RemoteCommand=none` behavior, and
monitoring service names match the current SSH and host configuration.

The main service addresses and ports in `docs/CLOUD.md`, the Restic source
paths and 03:00 timer in `docs/BACKUP.md`, the five monitoring dashboard names,
the Noctalia v5 desktop references, and the broad Tailscale port model also
match the checked-in configuration. These matches do not verify provider-side
state or successful live service operation.
