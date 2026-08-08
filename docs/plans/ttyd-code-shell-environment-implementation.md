# Restricted ttyd Code-Shell Environment Implementation Plan

Status: Implemented in repository; deployment and runtime migration pending

Created: 2026-08-08

Related documentation:

- [Repository architecture](../ARCHITECTURE.md)
- [Secure ttyd web terminal plan](ttyd-web-terminal-implementation.md)
- [Cloud services](../CLOUD.md)
- [Monitoring](../MONITORING.md)

Implementation verification performed on the workstation:

- `hp-server`, `workstation`, and `lenovo-yoga-pro-7` toplevels evaluate
- the `hp-server` toplevel builds successfully
- generated `code-shell` Home Manager files contain no personal secret loader,
  personal SSH aliases, automatic key generation, or `/home/henhal` paths
- generated ttyd configuration waits for the escaped
  `home-manager-code\x2dshell.service` unit and exposes the managed per-user
  profile in `PATH`
- Nix-on-Droid evaluation remains blocked by its pre-existing conflicting
  `.zshenv` managed target; `accountRole` defines only an option and does not
  create that file

## Objective

Make the existing browser terminal useful for development by giving its
dedicated Unix account the existing declarative Zsh, Neovim, tmux, Git,
direnv, Yazi, utility, and development-tool configuration, while preserving a
clear security boundary between that account and the fully fledged `henhal`
account.

Rename the current `webdev` account to `code-shell` as part of this work.
`webdev` is easily read as "web developer" and does not describe the security
role. `code-shell` describes the account's only purpose: it is the constrained
identity behind the browser coding shell. It is not a human login, an
administrator, or a general service account.

This plan deliberately makes no change to the Cloudflare, Keycloak,
oauth2-proxy, nginx, or ttyd request path. Authentication and ingress already
work; this phase changes only the environment and policy of the host-local
account launched by ttyd.

## Fixed Account Boundary

The two identities must remain visibly and technically different:

| Property | `henhal` | `code-shell` |
| --- | --- | --- |
| Purpose | Full personal and administrative account | Restricted browser coding shell |
| NixOS user kind | Normal user | System user with a persistent home |
| Interactive entry | Local login and Tailscale SSH | ttyd service only |
| PAM password | Yes | No |
| SSH authorized keys | Personal keys | None |
| `wheel` / sudo | Yes | Never |
| Docker or root-equivalent groups | Host-dependent | Never |
| Trusted Nix user | HP deployment user | Never |
| Home | `/home/henhal` | `/home/code-shell` |
| Workspace | Personal paths | `/home/code-shell/code` only |
| Personal SOPS/AI secret loader | Allowed by host policy | Never |
| Git credential | Personal | Separate, per-host, least-privilege credential |
| Home Manager | Full host feature set | Restricted policy over the host's CLI feature set |

The account remains `isSystemUser = true`. Do not change it to
`isNormalUser = true`: the current shared Docker module grants normal users
Docker access, which is root-equivalent. ttyd starts the account directly, so
PAM and SSH login eligibility are unnecessary.

The browser terminal remains unsuitable for administration. Environment setup
uses declarative Nix configuration, `nix develop`, `nix shell`, and direnv.
System changes, deployments, service control, SOPS editing, and recovery remain
Tailscale SSH tasks performed as `henhal`.

## Current Architectural Constraint

The repository's Pattern B/B+ NixOS wrappers add application modules through
`home-manager.sharedModules`. Consequently, every Home Manager user on a host
receives every shared Home Manager module imported by that host.

On `hp-server`, adding `code-shell` to `home-manager.users` without policy
changes would currently:

- generate an unencrypted GitHub SSH key through `git.nix`
- install the personal interactive secret loader through `secrets.nix`
- use `/home/henhal/code` and `/home/henhal/dotfiles` in tmux SessionX
- expose personal SSH host aliases through `ssh-config.nix`
- make Yazi's Neovim wrapper expect the interactive personal secret loader

The implementation must therefore not merely add a second Home Manager user.
First introduce a small, shared role option and make only the modules with
identity, credential, secret, or home-path assumptions respect it.

Do not replace the repository's shared-module architecture, duplicate the
existing Neovim configuration, or build a separate standalone Home Manager
evaluation. Those approaches create substantially more code and two competing
ways to assemble user environments.

## Target Architecture

```text
hp-server host imports
  |
  +-- existing CLI feature wrappers
  |     nvim, zsh, tmux, yazi, git, ssh-config,
  |     secrets, dev-tools, session-variables, direnv, utils
  |
  +-- ttydWebTerminalTarget
        |
        +-- owns Unix system account: code-shell
        +-- owns Home Manager user: code-shell
        +-- assigns role: restricted-code-shell
        +-- owns /home/code-shell/code
        +-- launches ttyd as code-shell
        +-- exposes no PAM or SSH login

Shared Home Manager modules
  |
  +-- ordinary configuration for henhal (default personal role)
  +-- safe CLI configuration for code-shell
  +-- sensitive behavior disabled when role = restricted-code-shell
```

The target module remains the sole owner of the restricted identity. Do not
create `modules/users/code-shell.nix`: user modules are intended for fully
fledged human identities, while this account exists only when a ttyd target is
enabled. Keeping its Unix account, Home Manager declaration, workspace, and
service in one feature makes deletion and auditing straightforward.

## Planned Repository Changes

### 1. Add a minimal Home Manager account-role module

Add `modules/features/account-role.nix` with only a Home Manager module and an
option such as:

```nix
my.account.role = lib.mkOption {
  type = lib.types.enum ["personal" "restricted-code-shell"];
  default = "personal";
  description = "Security role used to gate user-specific Home Manager behavior.";
};
```

Export it as `self.homeModules.accountRole`. Inject it once through the base
Home Manager setup or another existing universally imported wrapper so the
option exists for every Home Manager user.

Design constraints:

- Keep the default `personal` so existing workstation, Yoga, HP `henhal`, and
  Nix-on-Droid evaluations retain their current behavior.
- Set `my.account.role = "personal"` explicitly for `henhal` for readability,
  even though it matches the default.
- Set `restricted-code-shell` only inside the ttyd target's generated Home
  Manager user.
- Use this role only for genuine account-boundary decisions. Do not spread
  role checks through ordinary editor or shell styling.
- Do not add a broad `enable` option to every application module.

### 2. Extend `ttyd-target.nix` to own the managed code shell

Update `modules/features/remote-access/ttyd-target.nix` while retaining its
current responsibility for the system account, workspace, slice, service,
listener, firewall rules, and assertions.

Change the default account name from `webdev` to `code-shell` and add the
corresponding Home Manager declaration under the existing enable condition:

```nix
home-manager.users.${cfg.user} = {
  nixpkgs.config.allowUnfree = true;
  home.username = cfg.user;
  home.homeDirectory = "/home/${cfg.user}";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
  my.account.role = "restricted-code-shell";
};
```

The exact implementation must follow the evaluated Home Manager option shape,
but the ownership and values above are fixed.

Also:

- keep `isSystemUser = true`, an empty `extraGroups`, no password, and no
  authorized keys
- retain assertions against `root`, trusted Nix users, `wheel`, and Docker
- add assertions that the selected account is the Home Manager account being
  launched and that its home/workspace remain below `/home/${cfg.user}`
- add `/etc/profiles/per-user/${cfg.user}/bin` to the service's explicit
  `PATH`, ahead of its small fallback package path
- order ttyd after the Home Manager activation for this user if evaluation
  shows activation ordering is not already sufficient
- keep `ProtectHome=tmpfs` and the narrow `/home/${cfg.user}` bind; do not bind
  `/home/henhal`
- keep the resource slice and current ttyd transport/authentication behavior
  unchanged

Do not put application imports directly in `ttyd-target.nix`. The host already
chooses its application features in `hosts/<name>/configuration.nix`, and the
shared Home Manager modules apply their safe portions to `code-shell`.

### 3. Make Git behavior safe per Home Manager user

Refactor `modules/features/applications/git.nix` minimally:

- retain Git author name/email and ordinary Git settings for both roles
- retain the current personal SSH and `gh` behavior for `personal`
- for `restricted-code-shell`, do not generate any key during Home Manager
  activation
- never generate a private key with an empty passphrase for the restricted
  account
- do not inherit a private key, agent socket, credential helper, or token from
  `henhal`
- configure the restricted account only to use its own conventional
  `/home/code-shell/.ssh/id_ed25519` after that key is provisioned explicitly
- make `gh` use SSH only after the dedicated key exists; initial clone access
  must fail clearly rather than silently falling back to another credential

Prefer a small derived boolean such as:

```nix
isRestrictedCodeShell = config.my.account.role == "restricted-code-shell";
```

and `lib.mkIf` around credential-specific blocks. Avoid introducing a second
Git module or duplicating the common Git settings.

The OS-level `my.git.userName` and `my.git.userEmail` may remain shared because
they describe commit authorship, not authentication. A future need for a
different author identity is outside this phase and should become a separate
per-user option rather than overloading credential policy.

### 4. Prevent personal secret injection

Update `modules/features/secrets.nix` so
`home.file.".local/secrets/load-secrets.sh"` exists only for the `personal`
role. The `restricted-code-shell` account must not receive a script pointing
at `interactive-ai-env`, even if file permissions would prevent reading the
underlying SOPS template.

Update the Zsh secret-loading helper and Yazi Neovim wrapper only as needed so
the absence of this loader is an expected, silent state for
`restricted-code-shell`. Preserve existing personal behavior and useful
warnings for a personal account whose expected loader is unexpectedly absent.

Do not add alternative API keys to this account in this phase. Any future
coding-agent credential must have a separate threat review, a dedicated
least-privilege secret, and no access to infrastructure or recovery secrets.

### 5. Remove personal paths and SSH aliases from the restricted role

In `modules/features/applications/tmux.nix`, derive SessionX roots from the
Home Manager home directory or expose a small Home Manager list option. The
restricted account must use only:

```text
/home/code-shell/code
```

Do not expose `/home/henhal/code`, `/home/henhal/dotfiles`, or any other
personal path. Prefer a generic default based on `config.home.homeDirectory`
so the correction benefits every user without a role-specific branch.

Audit `modules/features/network/ssh-config.nix` before implementation. Gate
personal machine aliases and interactive `RemoteCommand` configuration to the
`personal` role unless an alias is demonstrably required by the restricted
coding workflow. The restricted account does not need SSH access to HP,
workstation, Yoga, or other infrastructure hosts.

Audit `zsh.nix`, `yazi.nix`, `dev-tools.nix`, `session-variables.nix`,
`direnv.nix`, `utils.nix`, and the Neovim wrapper for hard-coded `/home/henhal`
paths, personal secret references, desktop-only commands, and privilege
assumptions. Change only findings that affect `code-shell`; do not perform a
general cleanup or redesign during this implementation.

### 6. Preserve the existing feature wiring

Keep the current HP imports of:

- `nvim`
- `zsh`
- `tmux`
- `yazi`
- `git`
- `devTools`
- `sessionVariables`
- `direnv`
- `utils`

Do not create restricted copies of these modules. Their package closures are
already required on HP for `henhal`, so linking them into another Home Manager
profile adds little store duplication.

Keep `secrets` and `sshConfig` imported for `henhal`, but make their
user-sensitive portions obey the account role as described above.

No change is required to `flake.nix`: `import-tree` will discover the new
module automatically. No change is required to `docs/ARCHITECTURE.md` unless
implementation reveals a generally reusable Pattern B rule worth documenting;
this plan does not invent a new module pattern.

### 7. Provision a separate GitHub credential after deployment

Git authentication is a one-time operational step, not Nix activation logic.
After the managed home is active, open the HP target and generate a dedicated,
passphrase-protected key as `code-shell`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 100 -C "code-shell@hp-server" \
  -f ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

Required policy:

- choose and retain a strong passphrase outside the server
- label the GitHub key clearly as `code-shell@hp-server`
- prefer read-only repository deploy keys where push access is unnecessary
- otherwise use a dedicated GitHub account key with only the repository access
  needed by the coding workflow
- never copy a workstation, Yoga, `henhal`, or HP host key
- generate a different key on the future coding server

Start a scoped agent shell inside the persistent tmux session with
`ssh-agent zsh`, then run `ssh-add ~/.ssh/id_ed25519` when Git access is needed.
Exiting that nested shell terminates its agent. Do not use a long-lived global
agent and do not automatically unlock the key from the ttyd service. During an
incident, terminate both the tmux session and any remaining process owned by
`code-shell`.

If GitHub CLI device authentication is later preferred, treat its stored token
as a host-local credential with the same least-privilege and revocation rules.
Do not implement both methods by default.

### 8. Keep projects separate from `henhal`

Use independent clones under:

```text
/home/code-shell/code/<repository>
```

Do not grant read or execute traversal into `/home/henhal` and do not bind that
home into the ttyd service sandbox. Independent clones avoid Git safe-directory,
UID, permissions, editor-state, and credential crossover problems.

If a later workflow genuinely requires shared local data, create a separate
`/srv/development/<project>` boundary with a dedicated non-privileged group,
setgid/ACL policy, and an explicit ttyd bind. That is deliberately deferred
because it expands the files exposed through the public terminal.

## Implementation Sequence

### Phase 0: Read-only preflight and migration inventory

1. Inspect `/home/webdev` on HP as root without modifying it. Record ownership,
   project files, uncommitted Git work, tmux state, and credentials.
2. Confirm no process outside `ttyd-web-terminal.service` depends on UID,
   group, or path `webdev`.
3. Evaluate the current HP Home Manager shared-module list and audit the files
   named in this plan for account assumptions.
4. Record the current active generation, ttyd service state, listener/socket,
   and successful browser connection as rollback evidence.

Exit gate: all data that may need migration is identified, and `webdev` is
confirmed to be a ttyd-only identity.

### Phase 1: Introduce role policy without changing runtime identity

1. Add the account-role Home Manager option with default `personal`.
2. Set `henhal` explicitly to `personal`.
3. Add the Git, secrets, Zsh/Yazi, tmux, and SSH-config policy branches.
4. Evaluate and build workstation, Yoga, HP, and any standalone Home Manager or
   Nix-on-Droid configurations that consume the changed modules.
5. Inspect generated `henhal` Home Manager files to confirm there is no
   behavioral change.

Exit gate: all existing personal configurations build with unchanged effective
behavior, and the restricted role can be evaluated without a user yet using it.

### Phase 2: Add the managed `code-shell` identity

1. Change the ttyd target default account to `code-shell`.
2. Add its Home Manager declaration and restricted role inside the target
   module.
3. Add its Home Manager profile path to ttyd's explicit `PATH`.
4. Update HP target configuration only if it explicitly names `webdev`; prefer
   the target module's new default otherwise.
5. Update the original ttyd plan and operational documentation from `webdev`
   to `code-shell` after the implementation is validated so documentation
   matches reality.
6. Evaluate the HP config and inspect the generated passwd entry, Home Manager
   activation, ttyd unit, PATH, sandbox, and assertions.
7. Build the HP toplevel on the workstation.

Exit gate: the closure contains a managed `code-shell` home with the expected
CLI tools and no credential, secret-loader, personal-path, PAM, SSH, wheel,
Docker, or trusted-Nix access.

### Phase 3: Deploy and verify before migrating data

1. Activate the workstation-built HP configuration through the established
   `NIX_SSHOPTS='-o RemoteCommand=none'` remote workflow.
2. Verify the active generation and inspect `ttyd-web-terminal.service`, Home
   Manager activation results, the Unix socket, and relevant journals.
3. Log in through Keycloak and confirm `whoami` returns `code-shell`.
4. Verify Zsh, Neovim, tmux, Git, direnv, Yazi, Nix development shells, and
   expected language tools are available.
5. Verify the prompt, terminal title, and tmux status unmistakably identify HP
   and the restricted account.
6. Run all negative privilege and secret tests before provisioning Git access.

Exit gate: the browser coding environment works without any inherited personal
credential or access.

### Phase 4: Migrate only approved workspace data

1. Stop or detach the old `webdev` tmux session so files are quiescent.
2. Copy only reviewed project data from `/home/webdev/code` to
   `/home/code-shell/code`, preserving Git metadata and assigning ownership to
   `code-shell:code-shell`.
3. Do not copy `.ssh`, `.config/gh`, shell history, tokens, secret loaders,
   caches, or the whole home directory.
4. Verify Git status for every migrated repository before and after the copy.
5. Keep `/home/webdev` inaccessible and untouched for one rollback window.
6. Remove the old home only after explicit user approval and a final read-only
   inventory; removal is not part of automatic Nix activation.

Exit gate: all intended projects are present with correct ownership and no
credential or unrelated home-state migration.

### Phase 5: Provision and test the host-specific Git key

1. Generate the passphrase-protected HP key as described above.
2. Register only its public key with the required GitHub account or repository.
3. Test host verification, read access, and push access only where intended.
4. Verify the account cannot use `henhal` credentials or reach repositories
   not granted to its dedicated key.
5. Revoke and recreate the key once as a recovery rehearsal if practical.

Exit gate: normal clone/fetch/push work is possible within the intended scope,
and revocation does not affect another machine.

### Phase 6: Repeat the identity pattern on the future coding server

When that host exists:

1. Reuse `ttydWebTerminalTarget`; do not create another user module.
2. Use the same `code-shell` account name and restricted Home Manager role, but
   a separate home, workspace, UID allocation, tmux session, and SSH key.
3. Import only the CLI feature wrappers required on that host.
4. Size resource limits for its actual hardware.
5. Keep its ttyd listener reachable only from HP over Tailscale as specified in
   the original terminal plan.

No home, private key, GitHub token, agent socket, or mutable editor state is
shared between the two servers. Repository state is synchronized through Git,
not by copying the account home.

## Verification Checklist

### Environment

- `getent passwd code-shell` shows a system account with `/home/code-shell`
  and Zsh.
- `code-shell` appears in no normal-user, wheel, Docker, service-secret, or
  trusted-Nix membership.
- `whoami`, `$HOME`, `$USER`, working directory, prompt, title, and tmux status
  all identify the expected target and account.
- `command -v nvim zsh tmux git direnv yazi nix` resolves through the managed
  profile or the target's explicit fallback path.
- Neovim loads the existing declarative configuration and can edit a file in
  `/home/code-shell/code`.
- `nix develop` and direnv work without sudo.

### Isolation

- `/home/henhal`, `/root`, `/run/secrets`, `/run/secrets-rendered`, SOPS age
  keys, tunnel credentials, backup credentials, service credentials, and
  personal agent sockets are unreadable.
- no `.local/secrets/load-secrets.sh` is installed for `code-shell`.
- the environment contains no personal API tokens after login.
- tmux and Yazi contain no `/home/henhal` paths.
- personal SSH host aliases are absent.
- the account has no PAM password, authorized SSH keys, sudo capability,
  setuid escalation path, capabilities, or root-equivalent group.
- the service still sees only its bound home/workspace under `ProtectHome`.

### Git credential

- no private key is created during NixOS or Home Manager activation.
- the provisioned key has a passphrase, mode `0600`, and an unambiguous
  host-specific label.
- the key is not usable until explicitly added to an ephemeral agent.
- the HP and future coding-server keys differ.
- revoking the HP key stops HP Git access without affecting workstation, Yoga,
  `henhal`, or the future server.

### Regression

- workstation, Yoga, HP `henhal`, and Nix-on-Droid evaluations succeed.
- `henhal` retains the existing Neovim, Zsh, tmux, Git, SSH aliases, and
  intended interactive secret behavior.
- Cloudflare, Keycloak, oauth2-proxy, nginx, ttyd WebSocket routing, monitoring,
  OpenCloud, backup, and Tailscale behavior are unchanged.
- service activation is followed by runtime checks; a successful evaluation or
  build alone is not treated as deployment proof.

## Rollback

1. Disable public terminal ingress or the ttyd target first if the new account
   exposes an unexpected secret, path, or privilege.
2. Revert ttyd to the previous `webdev` account while retaining the role-policy
   changes, which default to the existing personal behavior.
3. Rebuild on the workstation, activate HP, and verify the old service/socket
   path and browser connection.
4. Do not delete `/home/code-shell` or `/home/webdev` during rollback. Inspect
   and reconcile project changes first.
5. Revoke the `code-shell@hp-server` GitHub key if it was provisioned.

The role option is intentionally backward-compatible, so rollback of the
runtime identity does not require undoing safe module parameterization.

## Acceptance Criteria

Implementation is complete only when:

- ttyd runs as the system account `code-shell`, which cannot log in through
  PAM/SSH and has no administrative or root-equivalent privilege
- its declarative Home Manager environment provides the existing CLI coding
  experience without duplicating application modules
- `henhal` retains the current full personal environment
- the restricted account receives no personal secret loader, credential,
  agent socket, SSH aliases, or `/home/henhal` path
- projects live in an isolated host-local workspace and Git uses a separate,
  passphrase-protected, revocable, host-specific credential
- environment setup and project dependencies work through Nix without sudo
- the existing terminal authentication, routing, WebSocket, sandbox, resource,
  monitoring, and incident-response boundaries remain intact
- the same target/profile pattern can be applied to the future coding server
  without sharing mutable home state or credentials

## Deliberately Deferred

- browser-based sudo or a browser shell as `henhal`
- access to Docker, libvirt, systemd administration, SOPS, backups, tunnel
  credentials, or production service accounts
- sharing `/home/henhal` or synchronizing the complete code-shell home
- automatic private-key generation, automatic key unlocking, or copying an
  existing private key
- AI/API credentials in the restricted account
- a shared `/srv/development` workspace
- per-user Git author identities
- restructuring all Pattern B modules to use per-feature enable flags

Each deferred item expands privilege, data exposure, or architectural scope
and requires a separate review.
