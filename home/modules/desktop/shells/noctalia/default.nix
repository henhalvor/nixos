{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  # Command to get current settings
  # noctalia-shell ipc call state all | jq .settings > home/modules/desktop/shells/noctalia/settings.json

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = lib.mkDefault (builtins.fromJSON (builtins.readFile ./settings.json));

    # settings = {
    #   bar = {
    #     density = "compact";
    #     # position = "right";
    #     showCapsule = false;
    #     widgets = {
    #       left = [
    #         {
    #           id = "ControlCenter";
    #           useDistroLogo = true;
    #         }
    #         {id = "Network";}
    #         {id = "Bluetooth";}
    #       ];
    #       center = [
    #         {
    #           hideUnoccupied = false;
    #           id = "Workspace";
    #           labelMode = "none";
    #         }
    #       ];
    #       right = [
    #         {
    #           alwaysShowPercentage = false;
    #           id = "Battery";
    #           warningThreshold = 30;
    #         }
    #         {
    #           formatHorizontal = "HH:mm";
    #           formatVertical = "HH mm";
    #           id = "Clock";
    #           useMonospacedFont = true;
    #           usePrimaryColor = true;
    #         }
    #       ];
    #     };
    #   };
    #   colorSchemes.predefinedScheme = "Monochrome";
    #   general = {
    #     radiusRatio = 0.2;
    #   };
    #   location = {
    #     monthBeforeDay = true;
    #     name = "Oslo, Norway";
    #   };
    # };
  };
}
