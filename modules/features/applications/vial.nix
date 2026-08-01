# Vial — keyboard configurator
# Source: home/modules/applications/vial.nix
{ self, ... }: {
  flake.nixosModules.vial = { ... }: {
    services.udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    '';
    home-manager.sharedModules = [ self.homeModules.vial ];
  };
  flake.homeModules.vial = { pkgs, ... }: {
    home.packages = with pkgs; [ vial ];
  };
}
