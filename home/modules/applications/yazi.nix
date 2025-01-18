
{ config, pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
        sort_sensitive = false;
      };
      preview = {
        max_width = 1024;
        max_height = 1024;
      };
      opener = {
        folder = [{ run = "cd \"$@\""; block = true; }];
        text = [{ run = "nvim \"$@\""; block = true; }];
        image = [{ run = "imv \"$@\""; fork = true; }];
        video = [{ run = "mpv \"$@\""; fork = true; }];
        pdf = [{ run = "zathura \"$@\""; fork = true; }];
      };
    };
  };
  
  home.packages = with pkgs; [
    ffmpegthumbnailer
    unar
    poppler_utils
    file
    jq
  ];
}
