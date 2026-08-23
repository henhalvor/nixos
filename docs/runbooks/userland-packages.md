# Mutable userland packages

The mutable userland is enabled on workstation and Lenovo Yoga only. It is for
software that needs a newer upstream release than the current `nixpkgs` package
or is substantially easier to maintain through its upstream channel.

The current migration record is in
[userland-packages-migration.md](userland-packages-migration.md). Existing
packages stay with their current owner until that record has a tested rollback
entry.

Keep suitable current packages in NixOS or Home Manager. Project runtimes and
tools declared by a project's Nix shell still win inside that shell. The
`userland` command never updates Nix, Home Manager, system Flatpaks, or
root-owned services.

## Inspect packages

```bash
userland managers
userland list
userland outdated
userland doctor
```

Use JSON when another script needs the same inventory:

```bash
userland list --json
userland outdated --json
userland managers --json
```

Every mutable package has a manager-qualified identifier. Examples include
`mise:node@22.14.0` and `flatpak:org.gimp.GIMP`.

## Install and remove

Always name the manager explicitly:

```bash
userland install mise node@22
userland install flatpak flathub:org.gimp.GIMP
userland remove mise:node@22.14.0
userland remove flatpak:org.gimp.GIMP
```

The mise command writes the mutable global mise configuration under the home
directory. Flatpak commands always use the user installation. The facade does
not accept a system Flatpak target.

Search the native registries with:

```bash
userland search --manager mise node
userland search --manager flatpak editor
```

## Update

Preview and confirm all known updates:

```bash
userland update --all
```

For scripts or an SSH session without a TTY, pass `--yes` explicitly:

```bash
userland update --all --yes
```

A failure in one backend does not stop the other backends. The command returns
nonzero when any requested operation fails. Update one package by its exact
identifier:

```bash
userland update mise:node@22.14.0
userland update flatpak:org.gimp.GIMP
```

## AppImages

Gear Lever is installed as Nix-owned infrastructure. Its pinned 3.4.7 release
provides the CLI used by `userland` for installed-app inventory, integration,
updates, and removal. The GUI remains available for operations that need visual
selection or custom update-source configuration.

Flatpak is preferred when it provides a comparable application because it has a
user-scoped update path and stronger isolation. AppImages remain ordinary
unsandboxed user executables.

## Recovery

The native commands remain the recovery path if the facade is unavailable:

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

Disabling `my.userlandPackages.enable` in a host removes the facade and shell
activation from the next Home Manager generation. It does not delete mise,
Flatpak, Gear Lever, or application data under the home directory.

Do not point a root-owned systemd service at a mutable userland executable.
The Hermes gateway remains a separate system service with its own reviewed
maintenance path.
