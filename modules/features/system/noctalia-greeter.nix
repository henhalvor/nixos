# Noctalia Greeter — greetd login screen that follows Noctalia
# Template A: NixOS-only (flake input)
#
# greetd is the display manager; noctalia-greeter is its login UI (user list,
# session picker, power buttons). Use instead of the `sddm` module, never
# both.
#
# Appearance comes from Noctalia, not Nix: Noctalia's greeter sync copies the
# wallpaper(s), palette, theme mode, font, corner radius and monitor layout to
# /var/lib/noctalia-greeter/sync.toml. With `[shell.greeter_sync] auto_sync`
# in the Noctalia config it re-syncs on every change; `noctalia msg
# greeter-sync` syncs by hand. greeter.toml (below) wins over sync.toml, so it
# must not set palette or wallpaper keys.
#
# Logs: /var/log/noctalia-greeter.log, /var/lib/noctalia-greeter/greeter.log,
# journalctl -u greetd.
{inputs, ...}: {
  flake.nixosModules.noctaliaGreeter = {config, ...}: {
    imports = [inputs.noctalia-greeter.nixosModules.default];

    services.displayManager.noctalia-greeter = {
      enable = true;

      # Lets these users run only the greeter's appearance-sync helper through
      # Polkit, from an active local session, without a password.
      passwordless-sync-users = ["henhal"];

      settings = {
        session.default = config.services.displayManager.defaultSession;
        cursor = {
          theme = config.stylix.cursor.name;
          size = config.stylix.cursor.size;
          path = config.stylix.cursor.package;
        };
      };
    };

    security.pam.services.greetd = {
      # A password login unlocks the GNOME Keyring login keyring.
      enableGnomeKeyring = true;
      # Same as SDDM in fingerprint.nix: a fingerprint login can't unlock the
      # keyring, and pam_fprintd would make the password wait.
      fprintAuth = false;
    };
  };
}
