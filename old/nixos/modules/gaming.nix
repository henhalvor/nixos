{
  pkgs,
  config,
  ...
}: {
  # Keeping this as a nixos module for now. The systemPackages could be moved to home-manager if needed. Co-locating gaming stuff here for now.

  programs.gamemode.enable = true; # for performance mode

  programs.nix-ld.enable = true;

  programs.steam = {
    enable = true; # install steam
    remotePlay.openFirewall =
      true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall =
      true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [
    wineWowPackages.staging
    winetricks

    heroic # install heroic launcher
    lutris # install lutris launcher
    mumble # install voice-chat
    protonup-qt # GUI for installing custom Proton versions like GE_Proton
    # (retroarch.override {
    #   cores = with libretro; [ # decide what emulators you want to include
    #     puae # Amiga 500
    #     scummvm
    #     dosbox
    #   ];
    # })
    teamspeak3 # install voice-chat

    prismlauncher # Minecraft launcher
    # You can override prismlauncher to change the environment available to the launcher and the game. This might be useful for installing additional versions of Java or providing extra binaries needed by some mods.
    (prismlauncher.override {
      # Add binary required by some mod
      additionalPrograms = [ffmpeg];

      # Change Java runtimes available to Prism Launcher
      jdks = [
        graalvmPackages.graalvm-ce
        zulu8
        zulu17
        zulu
      ];
    })
  ];
}
