{ config, pkgs, ... }: {
  # Whether to enable udisks2, a DBus service that allows applications to query and manipulate storage devices.
  services.udisks2.enable = true;
}
