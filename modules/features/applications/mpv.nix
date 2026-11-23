# mpv — media player with MIME associations
# Source: home/modules/applications/mpv.nix
{ self, ... }: {
  flake.nixosModules.mpv = { ... }: {
    home-manager.sharedModules = [ self.homeModules.mpv ];
  };

  flake.homeModules.mpv = { pkgs, ... }: {
    home.packages = with pkgs; [ mpv ];
    programs.mpv.enable = true;
    # mpv decodes in software by default; use the GPU (VA-API/NVDEC) when safe.
    programs.mpv.config.hwdec = "auto-safe";

    xdg.mimeApps.enable = true;
    xdg.mimeApps.defaultApplications = {
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/wav" = "mpv.desktop";
    };
  };
}
