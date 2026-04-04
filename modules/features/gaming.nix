# Gaming — Steam, Gamemode, Wine, launchers
# Source: nixos/modules/gaming.nix
{...}: {
  flake.nixosModules.gaming = {pkgs, ...}: {
    programs.gamemode.enable = true;

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
    };

    environment.systemPackages = with pkgs; [
      wineWowPackages.staging
      winetricks
      heroic
      lutris
      mumble
      protonup-qt
      teamspeak3
      (prismlauncher.override {
        additionalPrograms = [ffmpeg];
        jdks = [
          graalvmPackages.graalvm-ce
          zulu8
          zulu17
          zulu
        ];
      })
    ];
  };
}
