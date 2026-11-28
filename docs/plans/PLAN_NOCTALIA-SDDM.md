# Noctalia-driven login screen

Status: Option A implemented 2026-11-28 (`noctaliaGreeter` module); not yet
tested on hardware. Option B not implemented. Replaces the 2026-11-27
version, which used the third-party mda-dev/noctalia-sddm-theme (Qt5 only,
one maintainer, inactive since April 2026).

## Goal

On the Galaxy Book6 Pro, the login screen follows Noctalia: same wallpaper,
colours and style, updated automatically when they change in Noctalia. No
third-party theme repo. Other hosts keep SDDM + Astronaut with Stylix colours.

## Options

| | A. Noctalia Greeter (recommended) | B. SDDM + Astronaut + user template |
|---|---|---|
| What draws the login screen | [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter), the Noctalia team's greeter for greetd | Astronaut (nixpkgs, Qt6), as today |
| Wallpaper | Synced by Noctalia itself, per output | `wallpaper_changed` hook copies it |
| Colours | Full Noctalia palette and light/dark mode | ~40 Astronaut colour keys from a template |
| Style | Font, corner radius, same look as Noctalia's lock screen | Astronaut's layout, Noctalia colours |
| Monitor layout | Synced | No |
| Code we own | ~40 lines of Nix, no templates | ~30 lines of Nix + template + hook script |
| Display manager | greetd instead of SDDM on this host | SDDM unchanged |

Option A is recommended: it does everything the goal asks for, is
maintained by the Noctalia team (v1.7.1, released 2026-11, in nixpkgs
unstable, with its own flake and NixOS module), and Noctalia 5.6.0 already
has the sync built in (`noctalia msg greeter-sync`, and an Auto-Sync
setting). Option B is the fallback if greetd doesn't work out.

## Option A: Noctalia Greeter

### How sync works

Noctalia stages the wallpaper(s), palette, theme mode, font, corner radius
and monitor layout, then runs the greeter's root-owned helper
`noctalia-greeter-apply-appearance` through Polkit. The helper writes
`/var/lib/noctalia-greeter/sync.toml` and the wallpaper files there. The
declarative `greeter.toml` (from Nix) wins wherever both set a value, so Nix
must not set palette or wallpaper keys.

With **Auto-Sync Greeter** on, Noctalia syncs whenever the wallpaper,
palette, theme mode or font changes (debounced). A Polkit rule lets `henhal`
run only that helper, only for the constrained appearance sync, only from an
active local session, without a password.

### Changes

1. **`flake.nix`**: add `noctalia-greeter.url =
   "github:noctalia-dev/noctalia-greeter"` (no `follows`, like Luciole; it
   builds against unstable). Alternative: `pkgs-unstable.noctalia-greeter`
   with the project module.
2. **New module `modules/features/system/noctalia-greeter.nix`**
   (`self.nixosModules.noctaliaGreeter`):
   - import `inputs.noctalia-greeter.nixosModules.default`;
   - `services.displayManager.noctalia-greeter`:
     - `enable = true;`
     - `passwordless-sync-users = [ "henhal" ];`
     - `settings`: `session.default = "niri"`, cursor from Stylix
       (`cursor.theme`, `cursor.size`, `cursor.path`), keyboard layout. No
       palette or wallpaper keys.
   - `security.pam.services.greetd`:
     - `enableGnomeKeyring = true;` so a password login still unlocks the
       keyring;
     - `fprintAuth = false;` same reason as SDDM in `fingerprint.nix`.
3. **`sddm.nix`**: no change. The host imports `noctaliaGreeter` instead of
   `sddm`, so the other hosts are untouched.
4. **Host** (`hosts/galaxy-book6-pro/configuration.nix`): replace
   `self.nixosModules.sddm` with `self.nixosModules.noctaliaGreeter`.
   `services.displayManager.defaultSession = "niri"` stays (greetd reads
   the same session data).
5. **Noctalia settings** (`v5/galaxy-book6-pro.toml`): turn on Auto-Sync
   Greeter (key checked with `noctalia config validate` against 5.6.0):
   ```toml
   [shell.greeter_sync]
   auto_sync = true
   ```
   Run one manual sync (`noctalia msg greeter-sync`) after switching.
6. **Fingerprint module**: also set `greetd.fprintAuth = false` there, so
   both stay in one place. Either place works; pick one.
7. **Docs**: `docs/FEATURES.md` (new module), Galaxy Book `README.md` ("Login
   screen" section), `stylix.nix` header (the login screen is now
   Noctalia's on this host).

### Verification

Before rebooting:

1. Build the system; check that `/etc/greetd/config.toml` runs
   `noctalia-greeter-session`, and that the Polkit rule names the packaged
   helper path.
2. `nixos-rebuild switch` while still logged in, then
   `noctalia msg greeter-sync`: no password prompt, and
   `/var/lib/noctalia-greeter/` gets `sync.toml` and `wallpaper.*`.

After rebooting:

3. The greeter shows the Noctalia wallpaper and colours, lists niri,
   accepts the password, and the keyring is unlocked after login
   (Chrome/Brave open without a keyring prompt).
4. Change the palette and the wallpaper in Noctalia; log out: the greeter
   shows both.
5. Fingerprint isn't offered at the greeter (password only).

### Rollback

Switch the host import back to `self.nixosModules.sddm` and rebuild. If the
greeter doesn't start: `Ctrl+Alt+F2`, log in on the TTY, roll back, or boot
the previous generation from the systemd-boot menu. Logs:
`/var/log/noctalia-greeter.log`, `/var/lib/noctalia-greeter/greeter.log`,
`journalctl -u greetd`.

### Risks and open questions

- **Display manager switch.** greetd replaces SDDM on this host. The
  greeter docs say not to keep two display managers enabled. Not importing
  `sddm` here is enough.
- **Build against stable.** The flake builds with nixpkgs unstable, like
  Luciole. If its NixOS module needs options 25.11 lacks, use the module
  from the flake but check the evaluation first.
- **Fonts.** The synced font must be installed system-wide for the greeter
  user. Stylix installs its fonts through `fonts.packages`, so this should
  hold; check after the first sync.
- **Avatar.** Comes from AccountsService (the module enables it), not
  from sync.
- **Keyring.** Must check that greetd's PAM stack unlocks the keyring
  (step 3). The greeter docs mention keyrings with a separate password; the
  `login` keyring uses the account password here.

## Option B: SDDM + Astronaut with a Noctalia user template

Only if Option A fails.

- `sddm.nix` gets `my.sddm.colorSource = "stylix" | "noctalia"`. With
  `noctalia`, the Astronaut package's `Themes/astronaut.conf` is a symlink
  to `/var/lib/noctalia-sddm/astronaut.conf`, and `Background` points at
  `/var/lib/noctalia-sddm/background`.
- tmpfiles: the directory, owned by `henhal`, mode 0755; seed both files
  once from the current Stylix config and wallpaper (`C`).
- Template `~/.config/noctalia/templates/sddm-astronaut.conf`: the current
  ~40 keys with `{{ colors.<role>.default.hex }}` and
  `{{ colors.<role>.default.hex | set_alpha 0.7 }}` instead of Stylix base16
  colours, plus the non-colour keys unchanged.
- TOML:
  ```toml
  [theme.templates.user.sddm]
  input_path = "$XDG_CONFIG_HOME/noctalia/templates/sddm-astronaut.conf"
  output_path = "/var/lib/noctalia-sddm/astronaut.conf"

  [hooks]
  wallpaper_changed = "noctalia-sddm-wallpaper"
  ```
  The hook copies `$NOCTALIA_WALLPAPER_PATH` when
  `$NOCTALIA_WALLPAPER_CONNECTOR` is `eDP-1` (cp to `.tmp`, then mv).
- Test without logging out:
  `sddm-greeter-qt6 --test-mode --theme <astronaut theme dir>`.

`noctalia config validate` accepts `[theme.templates.user.<id>]` with
`input_path`/`output_path`/`post_hook`/`hook_async` and
`[hooks] wallpaper_changed` (checked 2026-11-28 against 5.6.0).

## Sources

- Noctalia user templates:
  https://docs.noctalia.dev/noctalia/theming/app-theming/?section=user-templates#user-templates
  and https://docs.noctalia.dev/noctalia/theming/templates/
- Noctalia Greeter: https://github.com/noctalia-dev/noctalia-greeter,
  https://docs.noctalia.dev/greeter/installation/,
  https://docs.noctalia.dev/greeter/sync/
