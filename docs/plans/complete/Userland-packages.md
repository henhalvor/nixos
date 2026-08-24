````markdown
# Userland Packages

## Overview

This document describes a package-management strategy for NixOS that separates the stable, declarative operating system from fast-moving user applications and developer tooling.

The goal is to keep the parts of the machine that benefit from NixOS reproducibility under Nix, while allowing rapidly updated tools and applications to update independently without requiring changes to `nixpkgs`, Home Manager, overlays, package hashes, flakes, or system rebuilds.

The intended model is:

```text
NixOS / Home Manager
        │
        ├── operating system
        ├── drivers
        ├── desktop environment / compositor
        ├── system services
        ├── compatibility plumbing
        └── stable foundational tools

────────────────────────────────────

Mutable Userland
        │
        ├── mise-managed tools
        ├── upstream self-updating applications
        ├── AppImages / application manager
        └── other upstream-managed user software
```
````

Nix remains responsible for the machine.

It does not need to be responsible for every application installed on the machine.

---

## The Problem

The conventional NixOS approach is to declare nearly all software through NixOS or Home Manager:

```nix
environment.systemPackages = with pkgs; [
  ...
];

home.packages = with pkgs; [
  ...
];
```

This works extremely well for software where reproducibility and integration with the system are more important than immediately tracking upstream releases.

It becomes significantly less attractive for rapidly changing software.

Examples include:

- AI coding agents
- agent harnesses
- language runtimes
- developer CLIs
- experimental tools
- rapidly updated desktop applications
- applications whose upstream installation process manages its own dependencies
- applications that release multiple times between nixpkgs updates

Hermes Agent is a good example.

Trying to package Hermes using the conventional Nix approach can mean dealing with:

- Python dependency packaging
- dependencies that assume a conventional Linux filesystem
- binaries downloaded by dependencies at runtime
- version mismatches
- fixed-output hashes
- rapidly changing upstream dependency trees
- overlays or package overrides
- package patches
- nixpkgs lag
- rebuilding after every package update
- application assumptions that do not map cleanly onto the Nix store

For an application that changes frequently, this creates a bad maintenance relationship:

```text
Upstream releases new version
        │
        ▼
Update Nix package
        │
        ├── update version
        ├── update hash
        ├── possibly update dependencies
        ├── possibly fix build
        └── possibly patch NixOS-specific problems
        │
        ▼
Rebuild Home Manager / NixOS
        │
        ▼
Use application
```

The user effectively becomes the downstream package maintainer.

For bleeding-edge software, this is unnecessary work.

The application already has an upstream installation and update mechanism. Reimplementing that lifecycle through Nix often provides little practical benefit while substantially increasing maintenance.

---

## Desired User Experience

Installing a fast-moving application should feel approximately like it does on a conventional Linux distribution.

For example:

```bash
hermes install
```

or:

```bash
mise use -g some-tool@latest
```

or:

```text
Download AppImage
    ↓
Integrate
    ↓
Launch
```

Updating should similarly be simple:

```bash
hermes update
```

or:

```bash
mise upgrade
```

or through the application's own updater.

Critically, updating a user application should **not** normally require:

```bash
nixos-rebuild switch
```

or:

```bash
home-manager switch
```

The desired flow is:

```text
Upstream releases new version
        │
        ▼
Application / userland package manager updates it
        │
        ▼
Use new version
```

while:

```text
flake.lock      unchanged
nixpkgs         unchanged
/nix/store      uninvolved
NixOS rebuild   unnecessary
```

---

## Design Principle

The system is divided according to a simple question:

> Does reproducibility matter more than update velocity for this piece of software?

If the answer is **yes**, Nix owns it.

If the answer is **no**, the mutable userland owns it.

This gives us two package-management domains.

### Declarative system layer

Managed by NixOS and Home Manager.

Examples:

- Linux kernel
- kernel modules
- GPU drivers
- systemd
- networking
- filesystems
- Wayland
- compositor
- desktop portals
- PipeWire
- fonts
- system services
- shell configuration
- security configuration
- foundational utilities
- compatibility layers required by mutable applications

These components should remain reproducible and coordinated with the rest of the operating system.

### Mutable userland layer

Managed independently of Nix.

Examples:

- Codex CLI
- Claude Code
- Hermes Agent
- Node.js versions
- Python versions
- Bun
- rapidly changing developer utilities
- experimental tooling
- self-updating desktop applications
- AppImage applications
- other software where following upstream closely is desirable

These tools should be able to update without changing the operating system.

---

# Architecture

The resulting system looks like this:

```text
                         NixOS
                           │
          ┌────────────────┴────────────────┐
          │                                 │
   Declarative system                Compatibility layer
          │                                 │
     kernel/drivers                      nix-ld
      Wayland/etc.                    AppImage support
     system services                   Flatpak support
          │                                 │
          └────────────────┬────────────────┘
                           │
                    Mutable Userland
                           │
          ┌────────────────┼─────────────────┐
          │                │                 │
         mise        upstream-managed    GUI applications
          │                │                 │
      CLI tools          Hermes          AppImage /
      runtimes           etc.            self-updater
```

The compatibility layer is the important bridge.

It allows software designed for conventional Linux distributions to run on NixOS without requiring that software itself to become a Nix package.

---

# One-Time NixOS Plumbing

NixOS should declaratively provide the infrastructure required for mutable user applications.

A minimal starting point is:

```nix
{
  programs.nix-ld.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  services.flatpak.enable = true;
}
```

`mise` itself may also be installed through NixOS or Home Manager because it is infrastructure rather than a rapidly changing application payload.

For example:

```nix
environment.systemPackages = with pkgs; [
  mise
  git
  curl
];
```

This configuration changes rarely.

Its purpose is not to describe every user application.

Its purpose is to establish the capabilities required to run them.

---

# nix-ld

NixOS does not expose the conventional dynamic linker and shared-library layout expected by many precompiled Linux applications.

As a result, an ordinary upstream binary may fail with errors similar to:

```text
Could not start dynamically linked executable
```

`nix-ld` provides a compatibility layer for these binaries.

Conceptually:

```text
Upstream Linux binary
        │
        │ expects normal ELF loader
        ▼
      nix-ld
        │
        ▼
available Nix libraries
```

This makes many binaries downloaded by applications, package managers, language tooling, and installers work without packaging the application itself through Nix.

Some applications may require additional libraries.

These can be added centrally if necessary:

```nix
programs.nix-ld = {
  enable = true;

  libraries = with pkgs; [
    zlib
    openssl
  ];
};
```

Libraries should only be added when there is a concrete requirement.

The objective is not to reconstruct an entire conventional Linux filesystem.

The objective is to provide enough compatibility for ordinary user software to function.

---

# AppImage Support

Desktop applications frequently distribute official Linux builds as AppImages.

NixOS can provide transparent AppImage execution:

```nix
programs.appimage = {
  enable = true;
  binfmt = true;
};
```

With this enabled, AppImages can behave much more like ordinary executables.

This gives us a useful upstream-controlled distribution mechanism for desktop applications without creating Nix derivations for each release.

```text
GitHub / upstream release
        │
        ▼
     AppImage
        │
        ▼
user application directory
        │
        ▼
desktop launcher
```

An AppImage manager can handle the remaining integration details such as:

- storage
- desktop entries
- icons
- update checking
- replacing old versions
- application removal

This avoids maintaining those details in Home Manager.

---

# mise

`mise` is the primary mechanism for fast-moving command-line tools and language runtimes.

It is not restricted to npm.

Depending on the tool, `mise` can manage software obtained through mechanisms such as:

- language/runtime plugins
- GitHub releases
- npm
- pipx
- Cargo
- Go
- Aqua
- direct binary downloads

The important property is that the installed tool lives in user space rather than being owned by the Nix system closure.

Conceptually:

```text
mise
 │
 ├── Node
 ├── Python
 ├── Bun
 ├── Codex
 ├── Claude
 └── other CLI tools
```

with installations stored beneath the user's home directory.

A typical installation might look like:

```bash
mise use -g node@latest
```

or:

```bash
mise use -g some-tool@latest
```

Updating becomes:

```bash
mise upgrade
```

No Nix expression needs to change.

No fixed-output hash needs to be updated.

No system rebuild is required.

---

# Flow: Installing Hermes Agent

Hermes is a good example of software that should be allowed to own its own lifecycle.

Instead of packaging Hermes and its rapidly changing dependency tree through Nix, the upstream installer is used.

The intended flow is:

```text
NixOS
 │
 ├── nix-ld
 ├── graphics/runtime environment
 └── normal system infrastructure
        │
        ▼
Hermes upstream installer
        │
        ▼
user-owned Hermes installation
        │
        ▼
hermes
```

Installation should therefore follow upstream instructions.

Conceptually:

```bash
curl ... | bash
```

After installation:

```bash
hermes
```

runs from the user environment.

Hermes may maintain its own files under locations such as:

```text
~/.hermes
~/.local/bin
```

The Nix store is not responsible for those files.

## Hermes Updates

When Hermes releases a new version:

```text
Hermes upstream release
        │
        ▼
hermes update
        │
        ▼
user-owned Hermes installation updated
```

There is no reason to:

```text
change nixpkgs
update package hash
change an overlay
run home-manager switch
run nixos-rebuild
```

unless Hermes itself exposes some new operating-system requirement.

That distinction is important.

Application updates happen frequently.

Platform requirements should change rarely.

---

# Flow: Installing a CLI Without a Self-Updater

Consider a CLI named `foo` that releases frequently through GitHub but does not implement its own updater.

If it can be managed through `mise`, the lifecycle becomes:

```text
GitHub Releases
      │
      ▼
     mise
      │
      ▼
~/.local/share/mise/...
      │
      ▼
     foo
```

Installation:

```bash
mise use -g foo@latest
```

or through an explicit backend if required:

```bash
mise use -g github:vendor/foo@latest
```

Usage:

```bash
foo
```

Updating:

```bash
mise upgrade
```

Again:

```text
Nix configuration     unchanged
Home Manager          unchanged
NixOS generation      unchanged
```

`mise` owns the volatile application lifecycle.

---

# Flow: Installing a GUI Application Without a Self-Updater

GUI applications are not necessarily good candidates for `mise`.

A desktop application often also requires:

- a `.desktop` launcher
- icons
- desktop menu integration
- MIME metadata
- application storage
- update metadata

We do not want to manually create or maintain this plumbing.

Instead, an AppImage manager should own it.

The user-facing flow should be approximately:

```text
Download Foo.AppImage
        │
        ▼
Open with AppImage manager
        │
        ▼
Click "Integrate"
        │
        ▼
Foo appears in application launcher
```

The application manager handles:

```text
AppImage storage
desktop file
icon
launcher integration
update source
future updates
removal
```

The user should not need to manually create:

```text
~/.local/share/applications/foo.desktop
```

or:

```text
~/.local/bin/foo
```

unless there is an unusual application that cannot be handled automatically.

---

# Updating a GUI Application

If the application provides update metadata or publishes predictable upstream releases, the AppImage manager handles future updates.

Conceptually:

```text
Foo 1.4 installed
      │
      │ upstream releases 1.5
      ▼
AppImage manager
      │
      ▼
Foo 1.5 installed
```

Again, NixOS is uninvolved.

If an application does not publish usable update metadata, specifying its GitHub repository or update URL once is acceptable.

That is application registration, not continuous package maintenance.

The important property is that subsequent releases do not require configuration changes.

---

# Avoid Building a Second Nixpkgs

It would be possible to describe mutable applications declaratively ourselves.

For example:

```nix
mutableApps = {
  foo = {
    github = "vendor/foo";
    asset = "*x86_64.AppImage";
  };

  bar = {
    github = "vendor/bar";
    asset = "*linux.AppImage";
  };
};
```

A custom system could then generate:

- download URLs
- launchers
- desktop entries
- icons
- update commands

This initially sounds attractive.

However, it would quickly become another package-maintenance system.

Applications change:

```text
asset names change
repositories move
release structures change
AppImage becomes tar.gz
binaries get renamed
runtime arguments change
icons move
update APIs change
```

At that point we would once again be maintaining package definitions.

That is exactly the problem this design is intended to avoid.

Therefore:

> Prefer existing upstream installation mechanisms and mature user-space package managers over custom declarative package definitions.

Declarative configuration should describe the **infrastructure**, not every volatile package.

---

# What Remains Declarative

The Nix configuration should declare that the machine supports mutable userland applications.

For example:

```nix
{
  programs.nix-ld.enable = true;

  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  services.flatpak.enable = true;

  environment.systemPackages = with pkgs; [
    mise
    git
    curl
  ];
}
```

This is stable configuration.

It expresses:

```text
This system can run conventional Linux binaries.
This system can run AppImages.
This system supports Flatpak applications.
This system has a user-space tool manager.
```

It does **not** express:

```text
Hermes must be version X.
Codex must be version Y.
Foo Desktop must be version Z.
```

Those belong to the mutable layer.

---

# Optional Unified Update Command

Once the individual mechanisms are working reliably, Home Manager can provide a small convenience command.

For example:

```bash
update-userland
```

Its purpose would only be to invoke the existing update mechanisms.

Conceptually:

```text
update-userland
       │
       ├── mise upgrade
       │
       ├── hermes update
       │
       └── check/update managed GUI applications
```

The command itself can be declarative because its behavior is stable.

The actual application versions remain mutable.

This gives us a useful separation:

```text
Nix declares HOW software is updated.

Upstream determines WHAT version is current.
```

---

# Failure Model

This approach does not guarantee that every arbitrary Linux application will immediately run on NixOS.

There may still be applications that assume:

- specific libraries
- `/usr/lib` paths
- `/etc` files from Ubuntu or Fedora
- particular system services
- setuid helpers
- kernel modules
- unusual Electron sandbox behavior

When such a problem occurs, the first question should be:

> Is this a platform compatibility problem or an application packaging problem?

If it is a platform capability that multiple applications need, it belongs in NixOS.

For example:

```text
missing common runtime library
        │
        ▼
add once to nix-ld libraries
```

If it is highly application-specific and fragile, packaging the application through Nix may still be appropriate.

The mutable layer is therefore not an ideological requirement.

It is a practical default for software where upstream lifecycle management is substantially easier than downstream Nix packaging.

---

# Package Ownership Rules

A useful decision tree is:

```text
Does this software need deep system integration?
        │
       yes
        │
        ▼
      NixOS
```

Examples:

- drivers
- daemons
- kernel modules
- core desktop components
- filesystem integration
- security infrastructure

Otherwise:

```text
Does upstream provide a reliable self-updater?
        │
       yes
        │
        ▼
Let upstream manage it
```

Examples:

- Hermes Agent
- self-updating desktop applications

Otherwise:

```text
Is it primarily a CLI/runtime/versioned tool?
        │
       yes
        │
        ▼
       mise
```

Otherwise:

```text
Is it distributed as an AppImage or similar portable GUI app?
        │
       yes
        │
        ▼
AppImage manager
```

Only when none of these approaches work well should we consider packaging the application through Nix ourselves.

---

# Guiding Principle

The system should optimize for two different properties at two different layers.

```text
               SYSTEM
                  │
          reproducibility
          predictability
          coordinated upgrades
                  │
                  ▼
                NixOS

────────────────────────────────

              USERLAND
                  │
              freshness
          upstream compatibility
             rapid updates
                  │
                  ▼
      mise / upstream / AppImage
```

NixOS remains the stable foundation.

The mutable userland deliberately behaves more like a conventional Linux environment.

This gives us the strengths of NixOS where they matter while avoiding unnecessary friction for software ecosystems that move too quickly for downstream declarative packaging to be pleasant.

---

# Core Objective

The success criterion is simple:

> Installing a bleeding-edge user application may require solving compatibility once. Updating that application should not require touching Nix again.

For software such as Hermes, Codex, rapidly changing agents, runtimes, and experimental desktop applications, the normal lifecycle should be:

```text
install once
    ↓
use normally
    ↓
upstream releases update
    ↓
update directly
    ↓
continue working
```

not:

```text
upstream releases update
    ↓
edit Nix expression
    ↓
update hashes
    ↓
fix dependency issues
    ↓
rebuild
    ↓
hope package still works
```

The purpose of the Userland Packages architecture is to keep those two concerns separate.

```

```
