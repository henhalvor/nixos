{ lib }:
rec {
  # Per-session defaults - what each session uses by default
  sessionDefaults = {
    hyprland = { bar = "hyprpanel"; lock = "hyprlock"; idle = "hypridle"; notifications = "hyprpanel"; dm = "sddm"; };
    sway     = { bar = "waybar";    lock = "swaylock"; idle = "swayidle"; notifications = "mako"; dm = "sddm"; };
    gnome    = { bar = "none";      lock = "loginctl"; idle = "none";     notifications = "none"; dm = "gdm"; };
    none     = { bar = "none";      lock = "none";     idle = "none";     notifications = "none"; dm = "none"; };
  };

  # Resolve null values to session defaults
  resolveDesktop = desktop:
    let
      session = desktop.session or "none";
      defaults = sessionDefaults.${session};
    in desktop // {
      bar = if desktop.bar or null != null then desktop.bar else defaults.bar;
      lock = if desktop.lock or null != null then desktop.lock else defaults.lock;
      idle = if desktop.idle or null != null then desktop.idle else defaults.idle;
      notifications = if desktop.notifications or null != null then desktop.notifications else defaults.notifications;
      dm = defaults.dm;
    };
}
