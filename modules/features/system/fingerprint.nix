# Fingerprint — fprintd with libfprint from unstable
# Template A: NixOS-only
#
# Stable libfprint (1.94.9) does not know newer sensors such as the Galaxy
# Book6 Pro's Goodix 27c6:6984 (goodixmoc driver); unstable's 1.94.100 does.
# fprintd itself is the same version on both channels, so taking unstable's
# fprintd only changes the library it is linked against.
#
# Enabling fprintd adds pam_fprintd to every PAM service. It stays on for
# sudo, polkit etc., but is turned off for the display manager and TTY login:
# a fingerprint login gives GNOME Keyring no password, so the login keyring
# would stay locked. Noctalia's lock screen talks to fprintd over D-Bus (its
# password path uses the `login` PAM service), so it is unaffected.
#
# Enrol with `fprintd-enroll`, check with `fprintd-verify`. Prints are stored
# per machine in /var/lib/fprint.
{...}: {
  flake.nixosModules.fingerprint = {pkgs-unstable, ...}: {
    services.fprintd = {
      enable = true;
      package = pkgs-unstable.fprintd;
    };

    security.pam.services = {
      login.fprintAuth = false;
      sddm.fprintAuth = false;
    };
  };
}
