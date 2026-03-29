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

      # SSH authorized keys (consumed by sshServer feature)
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMt1DD3rn6m5uBKGfgOwAerxKEpOJe54Aood9abQWAvx u0_a514@localhost"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDjlpTB8/FqToM9BkFuhL7w627YGto8ZYwAdXVR5AT+T henhal@henhal-Yoga-Pro-7-14APH8-Ubuntu"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAyX9JZNVAi8TchOBM/bsbYHk6b4adcvqPS+yhCo0r/X henhalvor@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN05rLpXKWvbcdus29yl6d1uC18LKPqe9HLpiXUB9mxp henhalvor@gmail.com"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBuJ92xN/PoTQX4RwTCyLddDxJkqkc9q7P5ufl2XZEWy henhal@workstation"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbU4sdXQwBdx/k/usv9DO6WByxwu6zYodYGfsGrHpbX henhal@yoga-pro-7"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEs49ICQp01DqPO/Mwxl13fEsYjM+ghwZWp/orbTZrV3 tablet@android"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINpF0P3LVOGnhKsTo1jchRDvcE4YefAou2MMxTF8TkfN henhalvor@gmail.com"
      ];
    };

    # NixOS-level option values (system-wide settings driven by user preference)
    my.theme = {
      scheme = "gruvbox-dark-hard";
      wallpaper = "atoms.png";
    };

    my.git = {
      userName = "Henrik";
      userEmail = "henhalvor@gmail.com";
    };

    home-manager.users.henhal = {
      nixpkgs.config.allowUnfree = true;
      home.username = "henhal";
      home.homeDirectory = "/home/henhal";
      home.stateVersion = "25.05";
      programs.home-manager.enable = true;
    };
  };
}
