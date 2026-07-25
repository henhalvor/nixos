# Printer and scanner support for local, USB, and network devices.
{...}: {
  flake.nixosModules.printer = {
    config,
    lib,
    pkgs,
    ...
  }: let
    normalUsers = builtins.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);
  in {
    users.groups.lp.members = normalUsers;
    users.groups.scanner.members = normalUsers;

    hardware.sane = {
      enable = true;
      extraBackends = [pkgs.sane-airscan];
    };

    services = {
      printing = {
        enable = true;
        browsed.enable = true;

        # Prefer driverless IPP Everywhere, with broad legacy/vendor fallbacks.
        drivers = with pkgs; [
          gutenprint
          gutenprintBin
          hplip
          brlaser
          brgenml1lpr
          brgenml1cupswrapper
          cnijfilter2
          epson-escpr
          epson-escpr2
          splix
        ];
      };

      # Exposes IPP-over-USB printers through the same driverless path as
      # AirPrint network printers and also supports compatible scanners.
      ipp-usb.enable = true;

      avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
      system-config-printer.enable = true;
    };
  };
}
