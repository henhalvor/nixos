# { config, pkgs, ... }:
# {
#   programs.yazi = {
#     enable = true;
#     settings = {
#       yazi = {
#         manager = {
#           show_hidden = true;
#           sort_by = "natural";
#           sort_dir_first = true;
#           sort_sensitive = false;
#         };
#         preview = {
#           max_width = 1024;
#           max_height = 1024;
#         };
#         opener = {
#           folder = [{ exec = "cd \"$@\""; block = true; }];
#           text = [{ exec = "nvim \"$@\""; block = true; }];
#           image = [{ exec = "imv \"$@\""; fork = true; }];
#           video = [{ exec = "mpv \"$@\""; fork = true; }];
#           pdf = [{ exec = "zathura \"$@\""; fork = true; }];
#         };
#       };
#     };
#    };
#
#   # Add helpful packages for better preview support
#   home.packages = with pkgs; [
#     ffmpegthumbnailer  # Video thumbnails
#     unar               # Archive previews
#     poppler_utils      # PDF previews
#     file              # File type detection
#     jq                # JSON preview
#   ];
# }
#

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
