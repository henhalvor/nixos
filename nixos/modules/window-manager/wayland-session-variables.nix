

{ config, pkgs, userSettings, ... }: {
  environment.sessionVariables = {
    #  If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    #Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
    # NVIDIA specific
    XDG_SESSION_TYPE = "wayland";
  };

}
