{
  config,
  pkgs,
  ...
}: {
  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;

    # Create virtual sink for Sunshine audio streaming
    extraConfig.pipewire."99-sunshine-virtual-sink" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "Sunshine Virtual Sink";
            "capture.props" = {
              "audio.position" = [ "FL" "FR" ];
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
}
