# Mutable userland packages

This document describes the `my.userlandPackages` module, the `userland`
command, the ownership boundary between Nix and mutable software, and the
failure modes that matter when installing fast-moving upstream tools.

The userland is an escape hatch for software that needs to follow upstream
faster than `nixpkgs`, or whose upstream distribution is substantially easier
to maintain than a Nix package. It is not a replacement for NixOS or Home
Manager.

## Philosophy

Nix remains responsible for the machine:

- boot, kernel, firmware, drivers, filesystems, and networking;
- systemd, authentication, security, and root-owned services;
- the compositor, portals, PipeWire, fonts, and desktop plumbing;
- recovery tools, shell configuration, and foundational utilities;
- project development shells and reproducible project environments; and
- ordinary packages when a suitable current `nixpkgs` package exists.

Mutable userland is for the exceptional cases:

- rapidly released AI coding agents and developer CLIs;
- global runtimes where a rolling upstream version is genuinely required;
- experimental tools that are not current or practical in `nixpkgs`;
- user-scoped Flatpak applications that need newer GUI releases; and
- AppImages when the upstream AppImage is the best maintained Linux build.

The deciding question is:

> Does update velocity matter more than reproducibility for this package?

If no, use NixOS or Home Manager. If yes, use the mutable userland while
keeping the package at user scope.

Mutable software can break itself or the user's session. It must not change
the NixOS generation, boot path, root-owned profiles, or root-owned services.

## Architecture

```text
NixOS and Home Manager
  |
  |-- system, drivers, desktop, portals, services, recovery tools
  |-- project Nix shells and direnv
  |-- compatibility plumbing such as nix-ld and AppImage support
  |-- user-scoped Flatpak service
  |-- mise executable and shell integration
  `-- the Nix-owned userland facade
          |
          |-- mise: global user tools and runtimes
          |-- Flatpak: user-scoped GUI applications
          |-- Gear Lever: user AppImages
          `-- reviewed upstream adapters

Mutable state under the user's home directory
  |-- ~/.config/mise/config.toml
  |-- ~/.local/share/mise
  |-- user Flatpak applications and data
  |-- Gear Lever-managed AppImages and metadata
  `-- application-owned state
```

The facade does not create a second package database. Native managers remain
the authority for installation, versions, update behavior, and package state.
`userland` normalizes their output and delegates commands to them.

## Enabling the module

The module is enabled per host rather than in the common base configuration.
The current hosts that enable it are the workstation and Lenovo Yoga:

```nix
my.userlandPackages = {
  enable = true;
  enableGui = true;
};
```

The HP server does not enable the mutable GUI userland.

The options are:

| Option | Meaning |
| --- | --- |
| `my.userlandPackages.enable` | Enables the userland facade and mise integration. |
| `my.userlandPackages.enableGui` | Enables user-scoped Flatpak, AppImage binfmt support, the Flatpak service, and Gear Lever. |
| `my.userlandPackages.upstreamAdapters` | Reviewed upstream installer allowlist. Hermes is included by default; hosts may add or override entries. |

After changing these options, activate the host generation. A plain `nix
build` validates a generation but does not activate it:

```bash
sudo nixos-rebuild switch --flake .#workstation
exec zsh -l
```

Use the appropriate host name when switching the Yoga. A new login shell is
important because mise's Zsh integration is loaded from the Home Manager
configuration.

## What the Nix module provides

The implementation is in
[`modules/features/userland-packages/default.nix`](../modules/features/userland-packages/default.nix).

### NixOS module

When enabled, the NixOS side:

- asserts that the `henhal` user exists;
- injects the Home Manager userland module;
- enables `programs.appimage` and binfmt when `enableGui` is true;
- enables the Flatpak service when `enableGui` is true; and
- installs Gear Lever as Nix-owned infrastructure when `enableGui` is true;
- installs Nix-owned prerequisites declared by enabled upstream adapters; and
- enables the Chromium setuid sandbox when an adapter requires it.

The module does not install arbitrary mutable applications into the Nix store.

### Home Manager module

The Home Manager side:

- builds the `userland` wrapper as a Nix-owned command;
- adds Python, mise, and the enabled backend executables to that wrapper's
  runtime path;
- enables `programs.mise` with the pinned Nix package and Zsh integration;
- adds `userland` to the user's Home Manager packages;
- exposes the NixOS Chromium sandbox to Electron through
  `CHROME_DEVEL_SANDBOX` when an adapter requires it; and
- configures the user Flathub remote during activation when GUI support is
  enabled.

Home Manager deliberately does **not** generate
`~/.config/mise/config.toml`. That file is mutable manager state because
`mise use --global` and `userland install mise ...` write it. Making it a Home
Manager symlink would cause declarative activation and mise's own mutations to
fight each other.

### `userland.py`

[`modules/features/userland-packages/userland.py`](../modules/features/userland-packages/userland.py)
is a small stateless Python facade. It:

- runs backend commands as argument arrays rather than shell strings;
- normalizes package rows into manager, package ID, name, installed version,
  available version, and status;
- keeps manager-qualified IDs so an update or removal cannot silently target a
  different backend;
- isolates backend failures and reports them without hiding other managers;
- rejects root execution for mutations;
- rejects system-scoped Flatpak operations;
- exposes reviewed upstream adapters from the generated JSON adapter file; and
- never invokes `sudo`, `nixos-rebuild`, Home Manager, or Nix update commands.

The fixture-based tests are in
[`modules/features/userland-packages/tests/test_userland.py`](../modules/features/userland-packages/tests/test_userland.py).
The Nix flake exposes them as the `userland-packages` check.

## CLI reference

### Inspect managers

```bash
userland managers
userland managers --json
```

This reports whether mise, Flatpak, Gear Lever, and configured upstream
adapters are available, their versions, scopes, capabilities, and current
invocation errors.

### List installed userland packages

```bash
userland list
userland list --manager mise
userland list --manager flatpak
userland list --manager appimage
userland list --json
```

`userland list` queries available backend metadata. It may use the network and
can be slower than a local-only inventory. The output is limited to packages
reported by the mutable managers. It intentionally does not list NixOS or Home
Manager packages.

The normal table is:

```text
MANAGER  PACKAGE_ID  NAME  INSTALLED  AVAILABLE  STATUS
```

When an update method is actionable, the table adds `UPDATE METHOD` after
`STATUS`. Managed backends show the exact manager-qualified `userland` command:

```text
UPDATE METHOD
userland update mise:github:example/tool@1.2.3
```

Upstream applications show their native updater even when the facade cannot
compare an available version:

```text
Native: hermes update
```

JSON rows use `update_method` for the same value.

Statuses are:

| Status | Meaning |
| --- | --- |
| `current` | Installed and available versions match. |
| `outdated` | A newer version was found. |
| `unknown` | The backend could not resolve a comparable available version. |
| `unavailable` | The package or adapter cannot currently provide the requested operation. |
| `error` | The backend or package query failed. |

### Show outdated packages

```bash
userland outdated
userland outdated --manager mise
userland outdated --json
```

The command performs the same availability queries and reports normalized
status. `userland update --all` only mutates packages that a backend reports as
`outdated`; an `unknown` package is not updated implicitly.

### Search native registries

```bash
userland search --manager mise node
userland search --manager flatpak editor
```

Search results are passed through from the native registry. Searching does not
install anything.

### Install

Always name the manager explicitly:

```bash
userland install mise node@22
userland install mise github:anomalyco/opencode
userland install flatpak flathub:org.gimp.GIMP
userland install upstream hermes
```

The mise specification is passed to `mise use --global`. That means mise
specifications, including GitHub backend options, can be quoted and used when
the installed mise release supports them:

```bash
userland install mise 'github:owner/repository[asset_pattern=tool-linux-x64]'
```

For a known release layout, editing the corresponding table in
`~/.config/mise/config.toml` is clearer and safer than relying on an automatic
asset heuristic. Reinstall the affected tool after changing its options.

Flatpak installation is always user-scoped and non-interactive:

```bash
userland install flatpak flathub:org.gimp.GIMP
```

AppImage installation requires an existing absolute file path and delegates
integration to Gear Lever:

```bash
userland install appimage "$HOME/Downloads/example.AppImage"
```

Upstream installation accepts only recipes in the Nix allowlist. The facade
shows the source and expected commands, asks for confirmation, downloads the
installer into a private temporary directory, and runs the file as the current
user. Pass `--yes` only for a reviewed non-interactive invocation:

```bash
userland install upstream hermes --yes
```

### Update one package

Use the exact ID shown by `userland list`:

```bash
userland update mise:node@22.14.0
userland update mise:github:anomalyco/opencode@1.18.21
userland update flatpak:org.gimp.GIMP
```

For mise, the version suffix is stripped before calling `mise upgrade`, so the
tool's configured version range remains authoritative.

### Update everything known to be outdated

Preview and confirm:

```bash
userland update --all
```

Use `--yes` for a non-interactive shell, script, or SSH command:

```bash
userland update --all --yes
```

The facade isolates backend operations. A failure in one backend does not stop
the others, and the final exit status is nonzero when any requested operation
failed.

No update timer is enabled. Manual updates are intentional so a broken
upstream release is visible and attributable.

### Remove

```bash
userland remove mise:node@22.14.0
userland remove mise:github:anomalyco/opencode@1.18.21
userland remove flatpak:org.gimp.GIMP
userland remove appimage:Applications/example.AppImage
```

Removal affects the selected mutable backend only. It does not remove a NixOS
package, Home Manager package, project dependency, or application data that a
backend deliberately retains.

### Diagnose

```bash
userland doctor
```

The doctor command checks manager availability, the user Flatpak remotes, Gear
Lever inventory, and configured upstream health commands. Run it from a real
interactive shell. A non-interactive shell may not have mise's shell
activation environment and can report a false mise activation problem.

## Backends and ownership

### mise

mise owns global tools and runtimes under the user's home directory:

```text
~/.config/mise/config.toml
~/.local/share/mise
```

It is the preferred backend for fast-moving CLI tools and runtimes. Project Nix
shells remain authoritative inside projects and should not be replaced by a
global mutable runtime merely because mise can install one.

Use stable or LTS channels for global runtimes unless a tool genuinely needs a
rolling version. Fast-moving end-user CLIs may use `latest`.

### Flatpak

All facade Flatpak operations use the user's Flatpak installation. The facade
does not accept system Flatpak targets. Flatpak is preferred over AppImage when
the application quality is comparable because it provides a user-scoped update
path, desktop integration, and stronger isolation.

### Gear Lever and AppImage

Gear Lever is Nix-owned infrastructure, but the AppImages it manages are
mutable user applications. AppImages remain ordinary unsandboxed executables.
Use them when the upstream AppImage is the best maintained Linux distribution,
not merely because an AppImage exists.

### Upstream adapters

The `upstreamAdapters` option is an allowlist for reviewed user-scoped tools
that do not fit mise, Flatpak, or Gear Lever. The module includes Hermes by
default so each host does not repeat the recipe and its Nix prerequisites.
Hosts can add recipes or override a built-in recipe through normal Nix module
merging.

Lifecycle commands are argument arrays and never run through a shell. A
bootstrap installer is different: its recipe declares an HTTPS URL, an
interpreter, allowed redirect hosts, and expected installed commands. The
facade downloads the script before invoking the interpreter. It rejects root
execution and removes PATH entries that expose `sudo` while the installer
runs. This makes upstream installers take their documented unprivileged path.
It is not a sandbox against a malicious script that calls an absolute path.

Hermes remains user-owned under `~/.hermes`. GCC, Make, shared libraries, and
the Chromium setuid sandbox are Nix-owned prerequisites. The module exports
the NixOS sandbox through `CHROME_DEVEL_SANDBOX`; it does not allow Hermes to
make a mutable file under `~/.hermes` root-owned or setuid. Hermes Desktop must
be tested after activation. If it ignores the system sandbox and insists on a
sudo fixup, treat the desktop path as unsupported rather than using
`--no-sandbox`.

## GitHub release asset problems

The mise GitHub backend has to choose one release asset from whatever an
upstream repository publishes. Its host OS, architecture, and libc heuristic
is not universally reliable. A repository can publish several plausible Linux
archives, and mise can extract the wrong one successfully. In that case mise
may report `installed` even though the expected command is absent or nested at
an unexpected path.

This happened with:

- `github:openai/codex`; and
- `github:can1357/oh-my-pi`.

The tools installed through the same backend for Claude Code and the Pi coding
agent used assets that exposed their commands correctly.

### Inspect before assuming success

```bash
mise where github:openai/codex
mise where github:can1357/oh-my-pi
find "$(mise where github:openai/codex)" -maxdepth 8 -type f -perm -111 -print
find "$(mise where github:can1357/oh-my-pi)" -maxdepth 8 -type f -perm -111 -print
command -v codex
command -v omp
```

`mise where` proves that mise has an installation directory. It does not prove
that the expected executable is present or on the activated PATH.

### Known working overrides

The current pinned mise release needs explicit asset options for these two
repositories. The options are version-agnostic so future updates keep using the
matching asset:

```toml
[tools]

"github:can1357/oh-my-pi" = {
  version = "latest",
  asset_pattern = "omp-linux-x64",
}

"github:openai/codex" = {
  version = "latest",
  version_prefix = "rust-v",
  asset_pattern = "codex-npm-linux-x64-*.tgz",
  strip_components = 1,
  bin_path = "vendor/x86_64-unknown-linux-musl/bin",
}
```

Why these options matter:

- `asset_pattern` avoids mise's release-asset scoring heuristic;
- `omp-linux-x64` is the bare Oh My Pi executable and mise exposes it as
  `omp`;
- the Codex npm platform tarball contains the Codex binary and its bundled
  sandbox helpers;
- `strip_components = 1` makes the archive layout deterministic;
- `bin_path` points mise at Codex's nested vendor binary directory; and
- Codex tags use `rust-v0.149.1`, so `version_prefix = "rust-v"` lets versions
  compare as `0.149.1` rather than appearing perpetually outdated.

After changing options, remove and reinstall the affected tools. Preserve the
version printed by `userland list` when constructing the removal command:

```bash
userland remove mise:github:openai/codex@<installed-version>
userland remove mise:github:can1357/oh-my-pi@<installed-version>
mise install github:openai/codex
mise install github:can1357/oh-my-pi
```

The native `mise install` commands are used here because they make it explicit
that the existing config table is the source of the asset options. Once the
installation is verified, the normal `userland update` and `userland list`
commands remain the interface for inventory and future updates.

### What cannot be made universal

There is no safe global option that can infer all of the following for every
GitHub repository:

- which release asset is the Linux x86_64 executable;
- whether the archive contains a wrapper, a nested vendor directory, or only a
  platform package;
- what command name the user expects; and
- whether a tag prefix should be removed for version comparison.

Do not make the heuristic more aggressive just to turn more installs green. A
failed install is safer than a successful install that silently puts the wrong
artifact on the user's PATH.

The long-term improvement belongs in the `userland` facade: a small reviewed
metadata catalog could carry the asset options and expected command names, and
installation could verify the executable before reporting success. That would
be an enhancement to the facade, not a reason to make Home Manager own the
mutable mise config.

## Stability and security boundary

The following invariants are intentional:

- no userland mutation invokes `sudo`;
- no facade operation writes `/etc`, `/run/current-system`, `/nix/store`, or a
  root-owned profile;
- mutable binary directories never enter root's PATH;
- root-owned services never execute mise shims, user-local binaries, Flatpak
  files, or Gear Lever-managed AppImages;
- Flatpak mutations are always user-scoped;
- AppImages are treated as unsandboxed user executables;
- project Nix shells remain authoritative for project runtimes;
- one failed backend does not hide results from other backends; and
- no automatic timer updates every mutable package.

The userland is not a sandbox. Installing a malicious or broken upstream
binary can still compromise the user account or user session. The boundary
protects the NixOS system and root-owned services, not the mutable application
itself.

## Recovery and rollback

The native managers remain the recovery path if the facade is unavailable:

```bash
mise ls --global
mise outdated
mise upgrade
mise unuse --global TOOL@VERSION

flatpak --user list --app
flatpak --user update
flatpak --user uninstall APP_ID

gearlever --list-installed
gearlever --list-updates
gearlever --update --all --yes
```

For mise, previous installed versions can normally be selected without a new
download if the old version has not been removed:

```bash
mise ls --global
mise use --global TOOL@PREVIOUS_VERSION
```

This is not a universal rollback guarantee. Upstream releases can disappear,
Flatpak history can be pruned, and some self-updaters do not retain old
artifacts.

Disabling `my.userlandPackages.enable` removes the facade and shell activation
from the next Home Manager generation. It does not delete mise installations,
Flatpak data, Gear Lever applications, or application-owned state under the
home directory.

## Migration rules

Move one ownership group at a time:

1. Install the mutable copy without removing the current owner.
2. Verify the command path, version, and primary workflow.
3. Resolve PATH precedence deliberately.
4. Remove the old Nix, Home Manager, npm, or bespoke updater owner.
5. Rebuild and start a fresh shell.
6. Verify that only the intended copy resolves.
7. Record a tested rollback command in
   [`docs/runbooks/userland-packages-migration.md`](runbooks/userland-packages-migration.md).

Do not migrate a package merely because it can be installed through mise. The
reason for moving it must be freshness, upstream support, or a materially lower
maintenance burden.

Root-owned services are a separate boundary. They must not be pointed at a
mutable workstation installation simply because the CLI is convenient there.

## Validation

Run the userland parser tests directly:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 modules/features/userland-packages/tests/test_userland.py
```

Run the Nix check:

```bash
XDG_CACHE_HOME=/tmp/codex-nix-cache nix build --no-link \
  --print-out-paths '.#checks.x86_64-linux.userland-packages'
```

Validate the flake and host closures before activation:

```bash
XDG_CACHE_HOME=/tmp/codex-nix-cache nix flake check --no-build

XDG_CACHE_HOME=/tmp/codex-nix-cache nix build --no-link \
  --print-out-paths '.#nixosConfigurations.workstation.config.system.build.toplevel'
```

The checks validate the Nix-owned infrastructure and facade. They cannot prove
that an arbitrary upstream GitHub release contains the expected executable.
That requires the package-specific command and workflow verification described
above.

## Related documents

- [Userland package proposal](plans/Userland-packages.md)
- [Userland implementation plan](plans/Userland-packages-implementation.md)
- [Operational runbook](runbooks/userland-packages.md)
- [Migration record](runbooks/userland-packages-migration.md)
