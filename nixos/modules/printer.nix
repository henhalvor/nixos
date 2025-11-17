{ userSettings, ... }:

{
  users.groups = {
    lp.members = [ "${userSettings.username}" ];
    scanner.members = [ "${userSettings.username}" ];
  };
  hardware.sane.enable = true;
  services = {
    printing.enable = true; # drivers are set on each machine
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
    system-config-printer = {
      enable = true;
    };
  };
}
