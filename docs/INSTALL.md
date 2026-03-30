# Installation Guide

How to install this NixOS configuration on a new or existing machine.

## Prerequisites

- A machine running NixOS (any version)
- Internet connection
- The target machine's hardware configuration generated (`/etc/nixos/hardware-configuration.nix`)

## Quick Start

### One-liner (fresh NixOS install)

```bash
curl -L https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh | sh
```

### Manual clone + run

```bash
git clone https://github.com/henhalvor/nixos.git ~/.dotfiles
cd ~/.dotfiles
bash install.sh
```

### Skip the script entirely

If you already have the repo cloned and your host configured:

```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .#<hostname>
```

---

## What the Install Script Does

The script (`install.sh`) automates the setup process:

1. **Verifies** the machine is running NixOS
2. **Installs git** temporarily via `nix-shell` if not present
3. **Clones** the repository to `~/.dotfiles` (or pulls updates if it exists)
4. **Enables flakes** in the user's nix config if not already enabled
5. **Discovers hosts** by scanning `hosts/*/default.nix`
6. **Validates** the selected host has all required files
7. **Generates `hardware.nix`** from `/etc/nixos/hardware-configuration.nix` if missing (wrapped in flake-parts boilerplate)
8. **Runs `nix flake check`** to validate before building
9. **Stages git changes** to avoid dirty-tree warnings
10. **Rebuilds** with `sudo nixos-rebuild switch --flake .#<hostname>`

All output is logged to `~/.dotfiles-install-logs/`.

---

## Interactive Menu

When you run the script, you'll see a menu like:

```
========================================
Available Host Configurations
========================================

  1) hp-server         [hw cfg]
  2) lenovo-yoga-pro-7 [hw cfg]  (matches current hostname)
  3) workstation       [hw cfg]

  4) Enter custom configuration name
  5) Create new host configuration
  6) View setup documentation
```

- **`hw`** / **`no-hw`** — whether `hardware.nix` exists for that host
- **`cfg`** / **`no-cfg`** — whether `configuration.nix` exists
- **Hostname match** — auto-detected from the running system

---

## Installing on an Existing Host

If the host is already configured (e.g. `lenovo-yoga-pro-7`):

1. Run `install.sh`
2. Select the matching host from the menu
3. Confirm the rebuild
4. Log out and back in for full effect

The script will skip hardware generation if `hardware.nix` already exists. It will warn you if `/etc/nixos/hardware-configuration.nix` is newer (e.g. after adding a disk).

---

## Installing on a New Machine

### Step 1: Boot into NixOS

Install NixOS via the standard installer. This gives you a minimal working system with `/etc/nixos/hardware-configuration.nix`.

### Step 2: Run the install script

```bash
curl -L https://raw.githubusercontent.com/henhalvor/nixos/main/install.sh | sh
```

Select **"Create new host configuration"** from the menu. The script prints a step-by-step guide:

### Step 3: Create the host directory

```bash
mkdir -p ~/.dotfiles/hosts/my-machine
```

### Step 4: Create the three required files

Each host needs exactly three files:

```
hosts/my-machine/
├── default.nix          # Entry point
├── configuration.nix    # System config
└── hardware.nix         # Hardware config
```

#### `default.nix` — Entry point

Defines `nixosConfigurations.my-machine`. Copy from an existing host and update names:

```nix
{self, inputs, ...}: {
  flake.nixosConfigurations.my-machine = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
      pkgs-unstable = import inputs.nixpkgs-unstable {
        system = "x86_64-linux";    # or "aarch64-linux"
        config.allowUnfree = true;
      };
    };
    modules = [ self.nixosModules.myMachineConfig ];
  };
}
```

#### `configuration.nix` — System config

Defines a NixOS module that imports features by name:

```nix
{self, inputs, ...}: {
  flake.nixosModules.myMachineConfig = {pkgs, ...}: {
    imports = [
      # Hardware
      self.nixosModules.myMachineHardware

      # Core (required)
      self.nixosModules.base
      self.nixosModules.bootloader
      self.nixosModules.networking
      inputs.home-manager.nixosModules.home-manager

      # Theme
      inputs.stylix.nixosModules.stylix
      self.nixosModules.stylix

      # Features — pick what you need (see docs/FEATURES.md)
      self.nixosModules.pipewire
      self.nixosModules.bluetooth
      self.nixosModules.secrets
      # ...
    ];

    networking.hostName = "my-machine";
  };
}
```

#### `hardware.nix` — Hardware config

The install script can **auto-generate** this from `/etc/nixos/hardware-configuration.nix`. Or create it manually:

```nix
{...}: {
  flake.nixosModules.myMachineHardware = {config, lib, modulesPath, ...}: {
    imports = [(modulesPath + "/installer/scan/not-detected.nix")];

    # Paste the body of your hardware-configuration.nix here
    boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" ];
    boot.kernelModules = [ "kvm-amd" ];
    # ...
  };
}
```

### Step 5: Build

```bash
cd ~/.dotfiles
sudo nixos-rebuild switch --flake .#my-machine
```

> **Note:** You do NOT need to edit `flake.nix`. The `import-tree` utility automatically discovers all `.nix` files under `hosts/` and `modules/`.

---

## Hardware Configuration

### Auto-generation

If `hosts/<name>/hardware.nix` doesn't exist, the install script will:

1. Read `/etc/nixos/hardware-configuration.nix`
2. Convert the hostname to a camelCase module name (e.g. `my-machine` → `myMachineHardware`)
3. Wrap it in flake-parts boilerplate
4. Write it to `hosts/<name>/hardware.nix`

### Regenerating after hardware changes

If you add a disk, change partitions, or swap hardware:

```bash
sudo nixos-generate-config          # updates /etc/nixos/hardware-configuration.nix
```

Then manually update `hosts/<name>/hardware.nix` with the new values. The install script will warn you if `/etc/nixos/` is newer.

### Module name convention

Hardware module names follow the pattern `<camelCaseHostname>Hardware`:

| Host | Module name |
|------|-------------|
| `workstation` | `workstationHardware` |
| `lenovo-yoga-pro-7` | `lenovoYogaPro7Hardware` |
| `hp-server` | `hpServerHardware` |

---

## Post-Install Steps

After a successful rebuild:

1. **Log out and back in** — group memberships and environment variables take effect on login
2. **Verify secrets** (if using sops-nix) — `echo $ANTHROPIC_API_KEY` should return a value (see [SECRETS.md](./SECRETS.md))
3. **Set up sops** for a new machine — generate age key and add to `.sops.yaml` (see [SECRETS.md](./SECRETS.md#adding-a-new-machine))

---

## Logs

All install script output is logged to:

```
~/.dotfiles-install-logs/install-YYYYMMDD_HHMMSS.log
```

Only the 10 most recent logs are kept (older ones are auto-rotated).

---

## Troubleshooting

### "No host configurations found in hosts/ directory"

The script scans for `hosts/*/default.nix`. Make sure you're running from the repo root (`~/.dotfiles`).

### "Git tree is dirty" warning

Normal during development. The script auto-stages changes before building. To suppress, commit your changes first.

### Flake check fails

`nix flake check` can report warnings that don't prevent building. The script continues anyway. Run with `--show-trace` for details:

```bash
nix flake check --show-trace 2>&1 | less
```

### Hardware module name mismatch

If the auto-generated `hardware.nix` uses a different module name than what `configuration.nix` imports, you'll get an error like:

```
error: attribute 'myMachineHardware' missing
```

Check that the module name in `hardware.nix` (`flake.nixosModules.<name>`) matches the import in `configuration.nix` (`self.nixosModules.<name>`).

### Build fails on first run

Common causes:
- Missing nix flakes — the script enables them, but you may need to restart your shell
- Network issues — nix needs to download packages on first build
- Disk space — a full desktop config can need 10+ GB during build

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — How the dendritic pattern works
- [FEATURES.md](./FEATURES.md) — Complete feature module reference
- [HOSTS.md](./HOSTS.md) — Per-host breakdown and feature matrix
- [SECRETS.md](./SECRETS.md) — Secrets management with sops-nix
