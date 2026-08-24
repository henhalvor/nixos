# Userland packages implementation plan

Status: implemented baseline, package migrations pending

## Goal

Add a small mutable userland beside the declarative NixOS and Home Manager
configuration for software that must track upstream faster than the available
`nixpkgs` package.

The finished setup should make it easy to install, inspect, update, and remove
those exceptional packages without allowing them to change the NixOS
generation, system services, boot path, or recovery environment.

The primary user interface will be a Nix-owned `userland` command. It will show
one combined inventory and delegate operations to mise, user-scoped Flatpak,
Gear Lever, and a small allowlist of upstream self-updaters. It will not become
a package database or another source of package definitions.

This document is an implementation plan only. It does not change the running
system.

## Scope

This system is only for packages that are missing from `nixpkgs`, are
materially behind upstream, or are substantially harder to keep current through
Nix than through a supported upstream distribution channel.

The normal ownership rule remains:

1. If a suitable current package exists in `nixpkgs`, install it through NixOS
   or Home Manager.
2. If a project already has a Nix development shell, that shell remains the
   authoritative project environment.
3. Use the mutable userland only when upstream velocity is the reason Nix is a
   poor fit.

This plan does not introduce `nix profile` as another user package layer. It
also does not use the unified interface to update NixOS, Home Manager, flake
inputs, or system packages.

## Non-goals

- Replacing NixOS or Home Manager for ordinary packages.
- Mirroring the Nix package set in a mutable manager.
- Making arbitrary upstream binaries safe or sandboxed.
- Giving mutable tools control over root-owned services.
- Automatically updating every package on a timer.
- Maintaining custom release recipes for every AppImage or GitHub project.
- Providing a universal rollback mechanism across unrelated package managers.

## Assessment and settled direction

The two-layer design in [Userland-packages.md](Userland-packages.md) is sound,
but the boundary must be stricter than the original proposal implies. The
mutable layer is an escape hatch for freshness, not the default application
layer.

| Concern | Decision | Reason |
| --- | --- | --- |
| Current packages | Keep them in NixOS or Home Manager | This preserves the simple declarative path when `nixpkgs` is already adequate. |
| Fast-moving CLI tools | Use mise first | It gives one install, version, update, and rollback model across several upstream ecosystems. |
| Global language runtimes | Use mise only where a rolling version is actually required | Project Nix shells remain reproducible and take precedence inside projects. |
| Fast-moving GUI applications | Prefer user-scoped Flatpak | Flatpak handles updates and desktop integration and provides stronger isolation than AppImage. |
| GUI fallback | Use Gear Lever-managed AppImages | It handles launchers, metadata, updates, and removal without custom Home Manager entries. |
| Self-updating applications | Permit explicit adapters only when mise, Flatpak, and AppImage are unsuitable | This prevents an uncontrolled collection of installers and update commands. |
| Unified overview | Add a thin `userland` facade | Native managers keep ownership of state; the facade only queries and delegates. |
| Cross-manager engine | Start with direct mise and Flatpak adapters; keep MPM as an optional later experiment | The native commands are already structured enough, so bootstrapping another package manager would add friction before it removes code. |
| General update orchestrator | Do not add Topgrade | It can update several managers, but it does not provide the inventory, install, and remove interface required here. Adding it beside the facade would duplicate orchestration. |
| Update scheduling | Manual at first | A bad user application update should be visible and attributable, not silently introduced. |

`mise` is the best fit for this narrow role. A more Nix-native solution would
restore the hash, expression, and rebuild work that this layer is intended to
avoid. Home Manager should own the mise executable and shell integration, while
mise owns the mutable tool selection and installed versions.

## Current repository baseline

As checked on 2026-08-23:

- `modules/base.nix` already enables `programs.nix-ld` with a broad desktop
  library set.
- AppImage support and Flatpak are not enabled.
- The pinned NixOS 25.11 package set provides mise `2025.11.7` and Gear Lever
  `3.4.7`.
- Meta Package Manager is absent from both current pinned package sets. If it is
  retained after the spike, install a pinned release through mise until a
  suitable `nixpkgs` package is available.
- Home Manager 25.11 provides `programs.mise.enable`, shell integration,
  `globalConfig`, and `settings`. It does not provide the newer
  `enableMutableConfig` option.
- `modules/features/dev-tools.nix` installs global Node.js, pnpm, Rust, Python,
  Go, and native build tools through Home Manager.
- `modules/features/session-variables.nix` prepends the existing mutable npm,
  Cargo, Python, and Go directories to `PATH`.
- `modules/features/applications/opencode/opencode.nix` maintains OpenCode with
  a bespoke npm update service and starts user services from a mutable npm
  location.
- `modules/features/applications/oh-my-pi.nix` packages a pinned upstream
  binary in Nix.
- `modules/features/dev-shell-bootstrap.nix` and
  `modules/features/direnv.nix` provide project-specific Nix environments.
  These remain in place.
- `modules/features/ai/hermes-runtime.nix` describes a dedicated system service
  account and a root-owned systemd service. That service is outside the
  workstation userland boundary even though its payload is mutable.
- The workstation and Yoga import the global development and AI-tool modules.
  The HP server also imports the development baseline, so mutable userland must
  be explicitly enabled per host rather than added to `base.nix`.

Phase 0 must refresh this inventory immediately before implementation. Package
versions and manager command formats are expected to change.

## Target architecture

```text
NixOS and Home Manager
  |
  |-- system, drivers, desktop, portals, services, recovery tools
  |-- project Nix shells and direnv
  |-- nix-ld, AppImage execution, Flatpak service
  |-- mise executable and shell activation
  `-- userland facade and adapter definitions
          |
          |-- native mise and Flatpak adapters
          |     |-- mise
          |     `-- Flatpak --user
          |-- Gear Lever CLI
          `-- allowlisted upstream adapters

Mutable state under the user's home directory
  |-- ~/.config/mise/config.toml
  |-- ~/.local/share/mise
  |-- user-scoped Flatpak applications and data
  |-- Gear Lever-managed AppImages and metadata
  `-- application-owned state
```

Nix declares which managers exist and how the facade calls them. Each native
manager remains the authority for its packages, versions, metadata, and update
operations.

## Ownership decision

Before moving or installing a package, record the answer to these questions:

1. Does it affect boot, hardware, networking, authentication, filesystems,
   desktop plumbing, or a root-owned service? If yes, Nix owns it.
2. Is the `nixpkgs` package suitable and current enough for actual use? If yes,
   NixOS or Home Manager owns it.
3. Is it a global CLI or runtime that needs a newer upstream release? If yes,
   mise owns it.
4. Is it a desktop application with a maintained Flatpak? If yes, user-scoped
   Flatpak owns it.
5. Is the official AppImage the best maintained Linux build? If yes, Gear Lever
   owns it.
6. Does upstream provide the only practical supported installer and updater?
   If yes, add a reviewed exception adapter.
7. If none apply, keep or package it in Nix rather than inventing a fragile
   mutable recipe.

The decision is based on maintenance cost and freshness, not merely on the
existence of another installation method.

## Stability boundary

The implementation must preserve these invariants:

- No `userland` operation invokes `sudo`.
- No userland manager writes to `/etc`, `/run/current-system`, `/nix/store`, or
  a root-owned profile.
- Mutable binary directories never enter root's `PATH`.
- Root-owned system services never execute mise shims, `~/.local/bin`, Flatpak,
  or Gear Lever-managed files.
- Foundational shell, Git, SSH, Nix, editors needed for recovery, and build
  prerequisites remain Nix-owned.
- Project Nix shells override global mise runtimes inside those projects.
- Flatpak operations always use user scope. System-scoped Flatpak installation
  and updates are rejected by the facade.
- AppImages are treated as ordinary unsandboxed user executables. Flatpak is
  preferred when its package quality is comparable.
- `nix-ld` is compatibility plumbing, not a sandbox. Libraries are added only
  for a reproduced application requirement.
- An unavailable or failed backend does not prevent the other backends from
  being inspected or updated.
- No automatic cleanup removes previous mise versions or old application
  artifacts until rollback behavior has been tested.
- No scheduled `userland update --all` is enabled during the initial rollout.

The guarantee is deliberately limited: a mutable package can break itself or
the user's session. It must not change the NixOS generation, boot path, or
root-owned services.

## Mise ownership and configuration

Home Manager should enable mise and its Zsh integration. It may own stable mise
settings, but it must not generate `~/.config/mise/config.toml` because that
would make `mise use --global` conflict with a Home Manager symlink.

Target ownership:

| Path or concern | Owner |
| --- | --- |
| mise executable | Home Manager package |
| Zsh activation | Home Manager `programs.mise` integration |
| `~/.config/mise/settings.toml` | Home Manager, after settings are tested |
| `~/.config/mise/config.toml` | mise and the user |
| `~/.config/mise/mise.lock` or the current global lock path | mise and the user |
| `~/.local/share/mise` | mise and the user |

Start with shell integration and no declarative `globalConfig`. After the pilot
works, consider stable safety settings such as a release-age delay and lockfile
generation. Confirm the exact setting names and global lock command against the
installed mise release before declaring them.

Use stable major or LTS channels for global runtimes unless a package genuinely
requires `latest`. Fast-moving end-user CLIs may use `latest`, but manager
infrastructure should use explicit versions.

## Unified `userland` interface

### Command contract

The first implementation should provide:

```text
userland managers
userland list [--manager MANAGER] [--json]
userland outdated [--manager MANAGER] [--json]
userland search [--manager mise|flatpak] QUERY
userland install MANAGER SPEC
userland update PACKAGE_ID
userland update --all [--yes]
userland remove PACKAGE_ID
userland doctor
```

An optional `userland ui` command can be added after the CLI and backend
contracts are stable.

`userland list` means all packages in the mutable userland, not all software on
the machine. NixOS and Home Manager packages are intentionally outside its
inventory.

### Package identifiers

Every row uses a manager-qualified identifier so commands cannot update or
remove the wrong package:

```text
mise:node
mise:npm:@openai/codex
flatpak:org.gimp.GIMP
appimage:LM-Studio
upstream:hermes
```

Installation always requires an explicit manager. The facade must not guess
whether an unqualified name belongs to npm, pipx, Flatpak, or another backend.

### Normalized inventory

Human output should use one table with these fields:

| Field | Meaning |
| --- | --- |
| Manager | `mise`, `flatpak`, `appimage`, or `upstream` |
| Package ID | Native stable identifier used for later commands |
| Name | Display name when the backend supplies one |
| Installed | Installed version, or `unknown` |
| Available | Newest known version, or `unknown` |
| Status | `current`, `outdated`, `unknown`, `unavailable`, or `error` |

`--json` should expose the same fields plus a backend error field. Backend
failures belong in the result instead of being hidden. Human output should end
with a short unavailable/failed backend summary.

### Manager status

`userland managers` should report:

- whether each manager executable is available;
- its version;
- whether its configured scope is safe;
- whether credentials or network access are needed;
- whether list, search, install, update, and remove are supported;
- the last error encountered during the current invocation.

This makes partial coverage visible. An arbitrary self-installed binary cannot
be discovered reliably unless its manager or an explicit adapter reports it.

### Update behavior

`userland update --all` must:

1. Query and display the proposed updates.
2. Ask for confirmation unless `--yes` is supplied.
3. Update mise, Flatpak, AppImage, and upstream groups independently.
4. Continue with later groups when one group fails.
5. Run cheap post-update version or health checks where available.
6. Print a final per-package or per-backend result summary.
7. Exit nonzero if any requested backend or package failed.

The command must never discover and update every manager on the machine. In
particular, it must not pass an unqualified `upgrade --all` to Meta Package
Manager because that tool can auto-detect Nix and other package managers.

## Backend contracts

### Mise and Flatpak

The initial implementation calls mise and Flatpak directly. Their JSON and
column-oriented output is small enough to normalize in the facade, and this
keeps the first install path to Nix-owned mise plus the native Flatpak package.

Every invocation explicitly selects only mise and Flatpak. Flatpak calls also
force user scope. The parser fixtures pin the expected mise JSON and Flatpak
column formats before mutation is enabled.

Meta Package Manager remains an optional later experiment. If it is evaluated,
it must stay behind the same public `userland` command and cannot auto-detect
Nix or system-scoped Flatpak.

Do not bootstrap Meta Package Manager during the first rollout. If a later
comparison proves that it reduces adapter code, install a pinned release only
after verifying its backend names and explicit user-scope flags.

### Gear Lever

[Gear Lever](https://github.com/mijorus/gearlever) is Nix-owned manager
infrastructure, not a mutable application payload. Prefer the current
`nixpkgs` package if its CLI supports the required operations.

The adapter uses Gear Lever's `--list-installed`, `--list-updates`, `--update`,
`--integrate`, and `--remove` options. The pinned `3.4.7` release returns a
bracketed text table rather than JSON, so the adapter parses that format and
keeps the parser fixture-tested against the installed release.

Do not create custom GitHub release recipes in Nix. Gear Lever owns update
sources and desktop integration for each AppImage.

### Upstream self-updaters

Exceptions use a small allowlisted adapter, not an application package
definition. Each entry may define argv arrays for:

- current version;
- available version or update check;
- update;
- optional health check.

Adapter commands must not be interpolated shell strings, request `sudo`, or
read secrets into logs. If upstream has no reliable non-mutating check, report
the available version as `unknown` rather than scraping release pages in the
facade.

Hermes may use this path for an interactive workstation installation if mise
cannot manage it cleanly. The dedicated Hermes gateway in
`modules/features/ai/hermes-runtime.nix` remains a separately reviewed system
service and is not controlled by `userland`.

## Proposed repository layout

Start with one feature directory rather than scattering manager logic across
the application modules:

```text
modules/features/userland-packages/
  default.nix
  userland.sh
  adapters/
    upstream.json
  tests/
    fixtures/
    userland.bats
```

`default.nix` should expose `flake.nixosModules.userlandPackages` and a matching
Home Manager module. Suggested options:

```text
my.userlandPackages.enable
my.userlandPackages.enableGui
my.userlandPackages.upstreamAdapters
```

The NixOS side owns platform capabilities such as Flatpak and AppImage
execution. The Home Manager side owns mise integration, the `userland`
executable, user-scoped Flathub setup, and stable adapter configuration.

Keep the shell implementation small and dependency-explicit with
`pkgs.writeShellApplication`. If structured merging becomes hard to test in
shell, use a small Python program from Nix instead of accumulating complex
`jq` and quoting logic. The tool still remains a facade with no database.

Enable the full GUI layer only on graphical user machines. Do not import it
through `modules/base.nix`, and do not enable it on HP by default.

## Phase 0: Inventory and migration record

Before changing configuration:

1. Record `command -v`, resolved path, and version for each global runtime,
   coding agent, and candidate mutable application.
2. Record packages installed through Home Manager, global npm/pip/Cargo/Go
   directories, Flatpak, AppImage locations, and any existing mise state.
3. Record user and system services whose `ExecStart` resolves through a user
   directory.
4. Identify duplicate command names and which path currently wins.
5. Classify each candidate with the ownership decision above.
6. Back up mutable configuration and application state needed for rollback.

Create a migration table during implementation:

| Package | Current owner/path | Target owner | Why mutable | Service dependency | Rollback |
| --- | --- | --- | --- | --- | --- |

Do not migrate a package without a filled row.

### Phase 0 gate

- Every candidate has an explicit current and target owner.
- Packages that are current enough in `nixpkgs` are excluded.
- No root-owned service depends on a migration candidate.
- Existing user services and PATH collisions are documented.

## Phase 1: Add platform plumbing without migrating packages

1. Add the `userlandPackages` feature module.
2. Enable mise through Home Manager with Zsh integration and no generated
   global tool config.
3. Enable `services.flatpak` and add Flathub as a user remote idempotently.
4. Enable `programs.appimage.enable` and `programs.appimage.binfmt` on the
   selected graphical hosts.
5. Install Gear Lever from `nixpkgs` as infrastructure on graphical hosts.
6. Keep the existing `nix-ld` library set unchanged initially. Audit it later
   against concrete failures instead of expanding it preemptively.
7. Add `userland managers` with read-only availability checks only.

### Phase 1 gate

- Targeted workstation and Yoga configurations evaluate and build.
- Existing commands still resolve to their old owners.
- A new login activates mise once and does not duplicate PATH entries.
- `mise doctor` succeeds or reports only understood warnings.
- `flatpak --user remotes` contains Flathub and no package was installed at
  system scope.
- A disposable AppImage launches through the declared AppImage support.
- `userland managers` performs no writes and reports unavailable optional
  backends clearly.

### Phase 1 rollback

Remove the host imports and switch to the previous NixOS generation. No package
has moved yet, so existing application paths remain valid.

## Phase 2: Pilot mise with low-risk CLI tools

1. Select one or two interactive CLI tools with no service dependency and an
   easy native rollback.
2. Install explicit versions through mise.
3. Verify interactive shell resolution, `mise exec`, and non-interactive use.
4. Upgrade one pilot tool, verify it, and select the previous installed version
   again.
5. Confirm project Nix shells resolve their declared runtimes instead of the
   global mise versions.
6. Keep prior versions until the pilot has passed login and reboot tests.

Do not begin with system services or move all language runtimes at once.

### Phase 2 gate

- Pilot tools work before and after a new login and reboot.
- An update does not change the NixOS or Home Manager generation.
- Previous versions can be selected without downloading them again.
- A project Nix shell retains its expected runtime and package manager.
- Removing mise activation restores the prior command path.

## Phase 3: Implement read-only unified inventory

1. Implement direct mise and user-scoped Flatpak adapters.
2. Compare their parser size and failure behavior with a disposable MPM spike
   only if native commands prove insufficient.
3. Keep the native adapters unless MPM materially reduces code and produces a
   stable structured result without broad manager auto-detection.
4. Implement `managers`, `list`, `outdated`, `search`, `doctor`, and `--json`.
5. Add the Gear Lever read-only adapter.
6. Add fixture-based parser tests for normal, empty, outdated, malformed, and
   unavailable backend output.
7. Deduplicate only exact manager-qualified identifiers. Do not merge packages
   merely because display names match.

### Phase 3 gate

- The combined inventory contains all packages reported by enabled backends.
- Nix is never auto-detected or queried as an update backend.
- Flatpak queries use user scope.
- One unavailable backend does not suppress results from others.
- Human and JSON output represent unknown versions and backend errors honestly.
- Read-only commands leave manager state and file mtimes unchanged, apart from
  documented manager caches.

## Phase 4: Add mutation commands

1. Implement explicit-manager install.
2. Implement manager-qualified single-package update and remove.
3. Implement confirmed `update --all` with backend isolation and a final
   summary.
4. Reject root execution and commands containing unsupported manager names.
5. Add the Gear Lever mutation adapter after its CLI has passed disposable-app
   tests.
6. Add at most one upstream exception as a proof of the adapter contract.
7. Keep native manager commands documented as the recovery path.

### Phase 4 gate

- Install, update, and remove work for one disposable package per manager.
- Cancelling confirmation changes nothing.
- Non-interactive all-update requires `--yes`.
- A forced failure in one backend does not stop later backends.
- The final exit code and summary identify partial failure.
- No test invokes `sudo`, system-scoped Flatpak, Nix update commands, or a
  root-owned profile.

## Phase 5: Migrate selected existing packages

Migrate one ownership group at a time. For each package:

1. Install and verify the target mutable copy without removing the old owner.
2. Test version output and the application's main workflow.
3. Resolve PATH precedence deliberately.
4. Remove the old Nix/Home Manager package or bespoke updater.
5. Rebuild, log in again, and verify that only the target copy resolves.
6. Record the native rollback command and retain the previous usable version.

Specific repository work likely includes:

- Remove migrated global runtimes and package managers from
  `modules/features/dev-tools.nix`, while retaining build tools and recovery
  utilities required outside project shells.
- Remove obsolete npm, Cargo, Python, and Go PATH entries and directory setup
  from `modules/features/session-variables.nix` only after their consumers have
  moved.
- Replace hard-coded OpenCode paths in Lazygit with a command resolved through
  the chosen owner.
- Remove `opencode-update.service` if OpenCode moves to mise. Update OpenCode
  user services to use an explicit `mise exec -- opencode ...` path and keep a
  health check before restart.
- Decide whether Oh My Pi's release cadence justifies moving it from its Nix
  package. Retain the existing package until mutable install, update, and
  rollback are proven.
- Inventory Claude Code, Codex, Amazon Q, and CodeCrafters before changing their
  current modules. Migrate only tools that meet the freshness rule.
- Treat interactive Hermes separately from the disabled HP gateway service.
  Do not point a system unit at the workstation user's mutable installation.

### Phase 5 gate

- `command -v` and version output match the migration record.
- No migrated command has two active global owners.
- Existing project shells and direnv workflows pass their normal checks.
- OpenCode user services start after login and survive a tested update.
- System service `ExecStart` and environment paths contain no mutable userland
  paths.
- The workstation remains recoverable when the mutable directories are moved
  temporarily out of the way.

## Phase 6: Add the optional interactive view

Only after the CLI is stable, add `userland ui` using the existing `fzf`
package or another small Nix-owned terminal dependency.

The UI should display the normalized inventory, allow filtering and
multi-selection, and expose only the same install, update, remove, and refresh
operations as the CLI. It must show manager-qualified identifiers and reuse the
CLI confirmation and error paths. It must not implement separate backend
logic.

### Phase 6 gate

- Every UI action can be reproduced with a documented CLI command.
- Closing or cancelling the UI changes nothing.
- Partial backend failures remain visible.
- The CLI remains fully usable when the UI dependency is unavailable.

## Phase 7: Documentation and recovery rehearsal

Update the source proposal or replace it with a shorter architecture document
after implementation. Its current outer Markdown fence should also be fixed at
that time.

Document:

- the package ownership rule;
- normal `userland` commands;
- native mise, Flatpak, and Gear Lever recovery commands;
- where each manager stores state;
- how to repin a previous mise version;
- how to inspect Flatpak history and attempt an application-specific rollback;
- how to restore an AppImage retained by Gear Lever;
- how to disable the Home Manager feature without deleting mutable state;
- which upstream adapters exist and why each exception is necessary.

Rehearse recovery for one package from each enabled manager. Do not claim
universal rollback: upstream services can remove old artifacts, Flatpak history
can be pruned, and some self-updaters do not retain prior releases.

## Validation commands

Use the repository's normal targeted checks during implementation:

```bash
XDG_CACHE_HOME=/tmp/codex-nix-cache nix eval \
  .#nixosConfigurations.workstation.config.system.build.toplevel.drvPath

XDG_CACHE_HOME=/tmp/codex-nix-cache nix build \
  .#nixosConfigurations.workstation.config.system.build.toplevel

XDG_CACHE_HOME=/tmp/codex-nix-cache nix eval \
  .#nixosConfigurations.lenovo-yoga-pro-7.config.system.build.toplevel.drvPath

git diff --check
```

After activation, include at least:

```bash
mise doctor
mise ls --global
mise outdated
flatpak --user remotes
flatpak --user list
userland managers
userland list
userland outdated
userland doctor
```

Use the Gear Lever CLI form verified in phase 1 for its list and update checks.
Also inspect the evaluated system and user units, test a fresh login and reboot,
and repeat inventory while one backend is offline or deliberately unavailable.

## Final acceptance criteria

The implementation is complete when:

- Current packages continue to be installed through NixOS or Home Manager.
- Every mutable package has one recorded owner and a reason it cannot reasonably
  follow the normal Nix path.
- mise, Flatpak, and AppImage support are enabled only on selected user hosts.
- Project Nix shells remain authoritative inside projects.
- `userland list` and `userland outdated` provide one honest combined view of
  every configured mutable backend.
- Install and remove require an explicit manager-qualified target.
- `userland update --all` previews, confirms, isolates backend failures, and
  returns an accurate result code.
- Native manager commands remain usable when the facade is broken.
- No unified operation can update Nix, Home Manager, system Flatpaks, or a
  root-owned service.
- No root-owned service depends on mutable user binaries.
- At least one update and recovery rehearsal has passed for each enabled
  backend.
- The old mutable npm/runtime PATH and bespoke updater configuration have been
  removed only where their packages were successfully migrated.
- The NixOS generation can be rolled back independently of mutable application
  state, and losing the mutable state does not prevent system recovery.

## Implementation-time questions

These are validation gates, not unresolved architecture decisions:

- Does the pinned Meta Package Manager release reduce the implementation enough
  to justify its extra dependency, or are direct mise and Flatpak adapters
  smaller and more reliable?
- Which exact Meta Package Manager option forces user-scoped Flatpak operations
  in the pinned release?
- Does a future Gear Lever release change the current bracketed CLI table or
  add structured output? Keep the adapter parser fixture-pinned when it does.
- Which existing global tools are actually behind `nixpkgs` at migration time?
- Which, if any, upstream self-updaters genuinely need an exception after mise
  coverage is checked?
