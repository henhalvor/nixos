# Userland runtime ownership and hardening plan

Status: proposed. This document records the next improvements; it does not
change the current module or move any package.

## Purpose

The userland module is now useful for fast-moving tools that are a poor fit for
the current `nixpkgs` package. The next step is to make its boundaries easier to
see and its failure modes harder to miss.

This plan covers two related questions:

1. How do the Nix development tools in `modules/features/dev-tools.nix`
   interact with mise and userland packages?
2. What should be improved before calling the userland facade mature enough for
   everyday use?

The guiding rule stays the same:

> Keep a suitable current package in NixOS or Home Manager. Use userland only
> when upstream freshness is worth giving up Nix's package ownership.

## Current ownership model

There are several separate layers. They are easy to confuse because all of
them eventually appear in a shell's `PATH`.

| Layer | Current owner | State and role |
| --- | --- | --- |
| Node.js, pnpm, Python 3.11, pip, Rust, Go, GCC, CMake, and similar tools | Nix/Home Manager via `dev-tools.nix` | Immutable store paths exposed through the per-user Nix profile. These are the default development tools. |
| npm global packages | npm and the user | Mutable files under `~/.local/dev/npm/global`, with the bin directory added by `session-variables.nix`. |
| pip user installs | pip and the user | Mutable files under `~/.local/dev/python`, with its bin directory added to `PATH`. |
| Cargo and Go user installs | Cargo/Go and the user | Mutable directories under `~/.local/dev/cargo/bin` and `~/.local/dev/go/bin`. |
| mise executable and shell integration | Nix/Home Manager | The pinned `pkgs.mise` binary and the `mise activate zsh` hook. |
| mise-managed tools | mise and the user | Configuration in `~/.config/mise/config.toml`; installations under `~/.local/share/mise`. |
| `userland` command | Nix/Home Manager | A Nix-built Python wrapper that queries and delegates to the configured managers. It does not maintain a second package database. |

The userland module does not replace the Node or Python package declared in
`dev-tools.nix`. It also does not make those packages mutable. The wrapper runs
with Nix's Python and calls the Nix-provided mise executable.

## Does mise override the Nix development tools?

Not by itself. Mise changes command resolution only for tools that are both:

1. configured and active in mise, and
2. present in a shell where `mise activate zsh` has run.

The active shell currently contains this Home Manager-generated hook:

```zsh
eval "/nix/store/...-mise-2025.11.7/bin/mise activate zsh"
```

When mise activates a configured tool, it prepends that tool's installation
directory to `PATH`. Therefore:

```text
no mise-managed node       -> Nix nodejs_22 wins
mise-managed node active   -> mise's node wins
no mise-managed python     -> Nix python311 wins
mise-managed python active -> mise's python wins
```

The same rule applies to a CLI with the same name as an old npm, Cargo, pip, or
Go installation. A mise directory is normally placed ahead of the older
mutable directories and the Nix profile. If mise has no active copy, the
existing `session-variables.nix` ordering still allows a mutable npm/Cargo/pip/Go
binary to win over the Nix profile.

This is ordinary `PATH` precedence, not an overlay of the Nix store. The Nix
package remains installed and available. A new shell, an explicit path, or a
project environment can select it again.

Useful inspection commands are:

```bash
type -a node python3 npm pip pnpm
command -v node
mise ls --global
mise which node
mise env --json
```

`type -a` shows every candidate, while `command -v` shows the winner in the
current shell. `mise env --json` shows the environment mise would activate, so
it is better evidence than inspecting only the Nix profile.

## Do the Nix tools affect userland packages?

They can provide a runtime, but they do not own the userland package.

- A GitHub release installed by mise normally brings its own executable and
  helpers. It may not use Node or Python at all.
- A mise backend that installs an npm or Python package may use a runtime chosen
  by that backend, or an active mise runtime. The exact behavior is backend and
  package specific.
- A package that invokes `node`, `python`, `git`, or a compiler at runtime sees
  whichever executable wins in its activated environment.
- `userland` itself is insulated from this choice because its Python interpreter
  and manager binaries come from the Nix-built wrapper.

This means a mutable package can be affected by `PATH` and environment
selection, but it cannot mutate the Nix package that supplied a runtime. The
main practical risk is an accidental runtime collision, not system corruption.

Project environments remain a separate authority. A Nix development shell or
direnv environment should provide the runtime declared by that project. A
global mise runtime must not be treated as a replacement for a reproducible
project shell.

## Why the current setup is safe enough

The module already keeps the important boundary in the right place:

- Nix owns the mise executable, the facade, shell integration, and compatibility
  plumbing.
- Mutable package state stays in the user's home directory.
- `userland` rejects root execution.
- Flatpak operations are forced to user scope.
- The facade never calls `nixos-rebuild`, Home Manager, `sudo`, or a system
  package manager.
- Root-owned services are not supposed to consume the user's mise paths.
- A failed backend does not hide inventory from other backends.

That is enough for personal workstation use. It is not a security boundary for
untrusted software. A mutable upstream binary still runs with the user's
permissions and can damage the user account or user data.

## Improvements to plan

### 1. Add runtime collision visibility

Extend `userland doctor` with an optional `PATH` audit for managed commands. For
each command, show:

- the selected executable;
- all candidates returned by `type -a` or an equivalent lookup;
- whether each candidate belongs to Nix, mise, npm, pip, Cargo, Go, or an
  unknown user directory;
- which owner is expected for that package.

The first version should report collisions, not change them. This gives us
evidence before removing the old mutable directories from
`session-variables.nix`.

### 2. Verify the executable after installation

Mise can successfully extract the wrong GitHub release asset. Codex and Oh My
Pi demonstrated that an `installed` result does not prove that the expected
command exists.

Add reviewed metadata for exceptional tools, including:

- expected command names;
- an optional executable path inside the install directory;
- release asset options such as `asset_pattern`, `strip_components`,
  `bin_path`, and `version_prefix`;
- a lightweight version or health check.

After install and update, the facade should check the expected executable and
report a failed package operation if it is absent. The metadata should remain
user-owned or be an explicit reviewed catalog. It should not turn the Nix
module into a generated `~/.config/mise/config.toml`, because that file must
remain writable by mise.

### 3. Make inventory and update semantics explicit

The current `list` path performs availability queries. That is useful, but it
means `userland list` can require network access and can return `unknown` when a
release service is unavailable.

Future work should:

- make `userland outdated` print only outdated rows, rather than duplicating the
  full inventory;
- keep `unknown` distinct from `current`;
- show whether availability came from a live query or a cached result;
- avoid prompting for `update --all` when there are no updates and no backend
  error;
- preserve the exact `UPGRADE COMMAND` for every actionable row.

### 4. Test the ownership boundary, not only parsers

Add integration-style tests that use fake managers and controlled `PATH` values
to prove that:

- the Nix runtime wins when no mise runtime is active;
- an active mise runtime wins only for its own tool name;
- a project shell can override the global selection;
- userland never invokes root or system-scoped Flatpak operations;
- a wrong release asset fails post-install validation;
- one backend failing does not suppress another backend's update.

Keep these tests offline. Live package updates remain a manual acceptance test.

### 5. Finish migration cleanup deliberately

Do not remove the existing Node/Python/Rust/Go packages just because mise can
install them. First decide which are still needed as stable build and recovery
tools.

For each migrated package:

1. install and smoke-test the mise copy;
2. inspect `type -a` and `command -v` in a fresh login shell;
3. remove the old global package or bespoke updater;
4. only then remove its mutable `PATH` entry or directory setup;
5. keep a native rollback command and a known-good prior version.

The likely end state is not "everything through mise." It is a smaller Nix
development baseline plus mise-managed exceptions, with no duplicate global
owner for a migrated command.

### 6. Keep service boundaries explicit

User services may use a mutable userland package if their unit is intentionally
user-scoped and has a health check. System services must continue to use Nix
paths or a separately managed service payload. No system unit should inherit
the interactive user's mise activation or `~/.local` directories.

Before moving a tool used by a service, inspect the evaluated unit and test a
fresh login, restart, and rollback.

## Implementation sequence

1. Add the `userland doctor` PATH audit and fixture tests.
2. Add package metadata and post-install executable checks for Codex, Oh My Pi,
   and any future GitHub tools with nonstandard layouts.
3. Correct `outdated` filtering and no-op update behavior.
4. Run a collision audit on workstation and Yoga.
5. Migrate or remove old global npm/pip/Cargo/Go owners one group at a time.
6. Rebuild only when the declarative side changes, then verify a new login,
   project shell, and user services.

## Acceptance criteria

This plan is complete when:

- `userland doctor` makes command ownership and collisions visible;
- a successful install means the expected command is present and executable;
- Codex-style release layouts have version-correct availability reporting;
- `list` and `outdated` have distinct, predictable output;
- Nix runtimes remain available when no mise runtime is selected;
- an active mise runtime wins only through documented `PATH` precedence;
- project Nix shells still resolve their declared runtimes;
- no migrated command has two active global owners;
- userland operations still cannot alter NixOS generations, system Flatpaks, or
  root-owned services;
- native manager commands remain a usable recovery path.

## What this plan does not propose

It does not propose replacing `nodejs_22` or `python311` in
`modules/features/dev-tools.nix` immediately. It does not generate mise's
mutable config through Nix. It does not add a second package manager or an
automatic update timer. Those choices would add friction before the ownership
and collision evidence justifies them.
