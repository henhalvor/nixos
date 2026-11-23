# PipeWire — audio subsystem
# Source: nixos/modules/pipewire.nix
{...}: {
  flake.nixosModules.pipewire = {...}: {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
