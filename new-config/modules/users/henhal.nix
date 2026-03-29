# User: henhal — identity + option values only
# Features are imported at the host level, not here.
{...}: {
  flake.nixosModules.userHenhal = {pkgs, ...}: {
    users.users.henhal = {
      isNormalUser = true;
      description = "Henrik";
      initialPassword = "password";
      extraGroups = ["wheel" "networkmanager" "docker" "video" "input" "i2c" "libvirtd"];
      shell = pkgs.zsh;
      home = "/home/henhal";
    };

    # NixOS-level option values (system-wide settings driven by user preference)
    my.theme = {
      scheme = "gruvbox-dark-hard";
      wallpaper = "atoms.png";
    };

    home-manager.users.henhal = {
      home.username = "henhal";
      home.homeDirectory = "/home/henhal";
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;

      # HM-level option values for future features:
      # my.git = {
      #   userName = "Henrik";
      #   userEmail = "henhalvor@gmail.com";
      # };
    };
  };
}
