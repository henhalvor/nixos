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

      # Sunshine virtual sink for remote streaming audio
      extraConfig.pipewire."99-sunshine-virtual-sink" = {
        "context.modules" = [
          {
            name = "libpipewire-module-loopback";
            args = {
              "node.description" = "Sunshine Virtual Sink";
              "capture.props" = {
                "audio.position" = ["FL" "FR"];
                "media.class" = "Audio/Sink";
                "node.name" = "sunshine-sink";
              };
              "playback.props" = {
                "node.name" = "sunshine-sink.monitor";
                "node.passive" = true;
              };
            };
          }
        ];
      };
    };
  };
}
