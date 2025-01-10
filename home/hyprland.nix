{ config, pkgs, userSettings, ... }:

{

  home.packages = with pkgs; [
    # Wayland essentials
    wofi # Application launcher
    waybar # Status bar
    # swaync          # Notification daemon
    # swaylock        # Screen locker
    # swayidle        # Idle management daemon
    wl-clipboard # Clipboard manager
    # grim            # Screenshot utility
    # slurp           # Screen region selector
    # wf-recorder     # Screen recording
    # brightnessctl   # Brightness control
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;

    extraConfig = ''
      exec-once = dbus-update-activation-environment --systemd DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_SESSION_DESKTOP=Hyprland XDG_CURRENT_DESKTOP=Hyprland XDG_SESSION_TYPE=wayland
      # exec-once = hyprctl setcursor '' + config.gtk.cursorTheme.name + " " + builtins.toString config.gtk.cursorTheme.size + ''

      env = XDG_CURRENT_DESKTOP,Hyprland
      env = XDG_SESSION_DESKTOP,Hyprland
      env = XDG_SESSION_TYPE,wayland
      env = WLR_DRM_DEVICES,/dev/dri/card2:/dev/dri/card1
      env = GDK_BACKEND,wayland,x11,*
      env = QT_QPA_PLATFORM,wayland;xcb
      env = QT_QPA_PLATFORMTHEME,qt5ct
      env = QT_AUTO_SCREEN_SCALE_FACTOR,1
      env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
      env = CLUTTER_BACKEND,wayland
      env = GDK_PIXBUF_MODULE_FILE,${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache

     # exec-once = nm-applet
      # exec-once = blueman-applet
       exec-once = waybar

      # exec-once = hypridle
      # exec-once = sleep 5 && libinput-gestures
      # exec-once = hyprpaper
      # bezier = wind, 0.05, 0.9, 0.1, 1.05
      # bezier = winIn, 0.1, 1.1, 0.1, 1.0
      # bezier = winOut, 0.3, -0.3, 0, 1
      # bezier = liner, 1, 1, 1, 1
      # bezier = linear, 0.0, 0.0, 1.0, 1.0
      #
      animations {
           enabled = yes
           animation = windowsIn, 1, 6, winIn, popin
           animation = windowsOut, 1, 5, winOut, popin
           animation = windowsMove, 1, 5, wind, slide
           animation = border, 1, 10, default
           animation = borderangle, 1, 100, linear, loop
           animation = fade, 1, 10, default
           animation = workspaces, 1, 5, wind
           animation = windows, 1, 6, wind, slide
           animation = specialWorkspace, 1, 6, default, slidefadevert -50%
      }

      general {
        layout = master
        border_size = 5
        col.active_border = 0xff'' + config.lib.stylix.colors.base08 + " " + ''0xff'' + config.lib.stylix.colors.base09 + " " + ''0xff'' + config.lib.stylix.colors.base0A + " " + ''0xff'' + config.lib.stylix.colors.base0B + " " + ''0xff'' + config.lib.stylix.colors.base0C + " " + ''0xff'' + config.lib.stylix.colors.base0D + " " + ''0xff'' + config.lib.stylix.colors.base0E + " " + ''0xff'' + config.lib.stylix.colors.base0F + " " + ''270deg

        col.inactive_border = 0xaa'' + config.lib.stylix.colors.base02 + ''

            resize_on_border = true
            gaps_in = 7
            gaps_out = 7
       }

       cursor {
         no_warps = false
         inactive_timeout = 30
       }

       bind=SUPER,code:9,exec,nwggrid-wrapper
       bind=SUPER,code:66,exec,nwggrid-wrapper
       bind=SUPER,SPACE,fullscreen,1
       bind=SUPERSHIFT,F,fullscreen,0
       bind=SUPER,Y,workspaceopt,allfloat
       bind=ALT,TAB,cyclenext
       bind=ALT,TAB,bringactivetotop
       bind=ALTSHIFT,TAB,cyclenext,prev
       bind=ALTSHIFT,TAB,bringactivetotop
       bind=SUPER,V,exec,wl-copy $(wl-paste | tr '\n' ' ')
       bind=SUPERSHIFT,T,exec,screenshot-ocr
       bind=CTRLALT,Delete,exec,hyprctl kill
       bind=SUPERSHIFT,K,exec,hyprctl kill
       bind=SUPER,W,exec,nwg-dock-wrapper

       bind=,code:172,exec,lollypop -t
       bind=,code:208,exec,lollypop -t
       bind=,code:209,exec,lollypop -t
       bind=,code:174,exec,lollypop -s
       bind=,code:171,exec,lollypop -n
       bind=,code:173,exec,lollypop -p

       bind = SUPER,R,pass,^(com\.obsproject\.Studio)$
       bind = SUPERSHIFT,R,pass,^(com\.obsproject\.Studio)$

       bind=SUPER,RETURN,exec,'' + userSettings.term + ''

       bind=SUPERSHIFT,RETURN,exec,'' + userSettings.term + " " + '' --class float_term

       bind=SUPER,A,exec,'' + userSettings.spawnEditor + ''

       bind=SUPER,S,exec,'' + userSettings.spawnBrowser + ''

       bind=SUPERCTRL,S,exec,container-open # qutebrowser only

       bind=SUPERCTRL,P,pin

       bind=SUPER,code:47,exec,fuzzel
       bind=SUPER,X,exec,fnottctl dismiss
       bind=SUPERSHIFT,X,exec,fnottctl dismiss all
       bind=SUPER,Q,killactive
       bind=SUPERSHIFT,Q,exit
       bindm=SUPER,mouse:272,movewindow
       bindm=SUPER,mouse:273,resizewindow
       bind=SUPER,T,togglefloating
       bind=SUPER,G,exec,hyprctl dispatch focusworkspaceoncurrentmonitor 9 && pegasus-fe;
       bind=,code:148,exec,'' + userSettings.term + " " + ''-e numbat

       bind=,code:107,exec,grim -g "$(slurp)"
       bind=SHIFT,code:107,exec,grim -g "$(slurp -o)"
       bind=SUPER,code:107,exec,grim
       bind=CTRL,code:107,exec,grim -g "$(slurp)" - | wl-copy
       bind=SHIFTCTRL,code:107,exec,grim -g "$(slurp -o)" - | wl-copy
       bind=SUPERCTRL,code:107,exec,grim - | wl-copy

       bind=,code:122,exec,swayosd-client --output-volume lower
       bind=,code:123,exec,swayosd-client --output-volume raise
       bind=,code:121,exec,swayosd-client --output-volume mute-toggle
       bind=,code:256,exec,swayosd-client --output-volume mute-toggle
       bind=SHIFT,code:122,exec,swayosd-client --output-volume lower
       bind=SHIFT,code:123,exec,swayosd-client --output-volume raise
       bind=,code:232,exec,swayosd-client --brightness lower
       bind=,code:233,exec,swayosd-client --brightness raise
       bind=,code:237,exec,brightnessctl --device='asus::kbd_backlight' set 1-
       bind=,code:238,exec,brightnessctl --device='asus::kbd_backlight' set +1
       bind=,code:255,exec,airplane-mode
       bind=SUPER,C,exec,wl-copy $(hyprpicker)

       bind=SUPERSHIFT,S,exec,systemctl suspend
       bindl=,switch:on:Lid Switch,exec,loginctl lock-session
       bind=SUPERCTRL,L,exec,loginctl lock-session

       bind=SUPER,H,movefocus,l
       bind=SUPER,J,movefocus,d
       bind=SUPER,K,movefocus,u
       bind=SUPER,L,movefocus,r

       bind=SUPERSHIFT,H,movewindow,l
       bind=SUPERSHIFT,J,movewindow,d
       bind=SUPERSHIFT,K,movewindow,u
       bind=SUPERSHIFT,L,movewindow,r

       bind=SUPER,1,focusworkspaceoncurrentmonitor,1
       bind=SUPER,2,focusworkspaceoncurrentmonitor,2
       bind=SUPER,3,focusworkspaceoncurrentmonitor,3
       bind=SUPER,4,focusworkspaceoncurrentmonitor,4
       bind=SUPER,5,focusworkspaceoncurrentmonitor,5
       bind=SUPER,6,focusworkspaceoncurrentmonitor,6
       bind=SUPER,7,focusworkspaceoncurrentmonitor,7
       bind=SUPER,8,focusworkspaceoncurrentmonitor,8
       bind=SUPER,9,focusworkspaceoncurrentmonitor,9

       bind=SUPERCTRL,right,exec,hyprnome
       bind=SUPERCTRL,left,exec,hyprnome --previous
       bind=SUPERSHIFT,right,exec,hyprnome --move
       bind=SUPERSHIFT,left,exec,hyprnome --previous --move

       bind=SUPERSHIFT,1,movetoworkspace,1
       bind=SUPERSHIFT,2,movetoworkspace,2
       bind=SUPERSHIFT,3,movetoworkspace,3
       bind=SUPERSHIFT,4,movetoworkspace,4
       bind=SUPERSHIFT,5,movetoworkspace,5
       bind=SUPERSHIFT,6,movetoworkspace,6
       bind=SUPERSHIFT,7,movetoworkspace,7
       bind=SUPERSHIFT,8,movetoworkspace,8
       bind=SUPERSHIFT,9,movetoworkspace,9

       bind=SUPER,Z,exec,if hyprctl clients | grep scratch_term; then echo "scratch_term respawn not needed"; else alacritty --class scratch_term; fi
       bind=SUPER,Z,togglespecialworkspace,scratch_term
       bind=SUPER,F,exec,if hyprctl clients | grep scratch_ranger; then echo "scratch_ranger respawn not needed"; else kitty --class scratch_ranger -e ranger; fi
       bind=SUPER,F,togglespecialworkspace,scratch_ranger
       bind=SUPER,N,exec,if hyprctl clients | grep scratch_numbat; then echo "scratch_ranger respawn not needed"; else alacritty --class scratch_numbat -e numbat; fi
       bind=SUPER,N,togglespecialworkspace,scratch_numbat
       bind=SUPER,M,exec,if hyprctl clients | grep lollypop; then echo "scratch_ranger respawn not needed"; else lollypop; fi
       bind=SUPER,M,togglespecialworkspace,scratch_music
       bind=SUPER,B,exec,if hyprctl clients | grep scratch_btm; then echo "scratch_ranger respawn not needed"; else alacritty --class scratch_btm -e btm; fi
       bind=SUPER,B,togglespecialworkspace,scratch_btm
       bind=SUPER,D,exec,if hyprctl clients | grep Element; then echo "scratch_ranger respawn not needed"; else element-desktop; fi
       bind=SUPER,D,togglespecialworkspace,scratch_element
       bind=SUPER,code:172,exec,togglespecialworkspace,scratch_pavucontrol
       bind=SUPER,code:172,exec,if hyprctl clients | grep pavucontrol; then echo "scratch_ranger respawn not needed"; else pavucontrol; fi

       $scratchpadsize = size 80% 85%

       $scratch_term = class:^(scratch_term)$
       windowrulev2 = float,$scratch_term
       windowrulev2 = $scratchpadsize,$scratch_term
       windowrulev2 = workspace special:scratch_term ,$scratch_term
       windowrulev2 = center,$scratch_term

       $float_term = class:^(float_term)$
       windowrulev2 = float,$float_term
       windowrulev2 = center,$float_term

       $scratch_ranger = class:^(scratch_ranger)$
       windowrulev2 = float,$scratch_ranger
       windowrulev2 = $scratchpadsize,$scratch_ranger
       windowrulev2 = workspace special:scratch_ranger silent,$scratch_ranger
       windowrulev2 = center,$scratch_ranger

       $scratch_numbat = class:^(scratch_numbat)$
       windowrulev2 = float,$scratch_numbat
       windowrulev2 = $scratchpadsize,$scratch_numbat
       windowrulev2 = workspace special:scratch_numbat silent,$scratch_numbat
       windowrulev2 = center,$scratch_numbat

       $scratch_btm = class:^(scratch_btm)$
       windowrulev2 = float,$scratch_btm
       windowrulev2 = $scratchpadsize,$scratch_btm
       windowrulev2 = workspace special:scratch_btm silent,$scratch_btm
       windowrulev2 = center,$scratch_btm

       windowrulev2 = float,class:^(Element)$
       windowrulev2 = size 85% 90%,class:^(Element)$
       windowrulev2 = workspace special:scratch_element silent,class:^(Element)$
       windowrulev2 = center,class:^(Element)$

       windowrulev2 = float,class:^(lollypop)$
       windowrulev2 = size 85% 90%,class:^(lollypop)$
       windowrulev2 = workspace special:scratch_music silent,class:^(lollypop)$
       windowrulev2 = center,class:^(lollypop)$

       $savetodisk = title:^(Save to Disk)$
       windowrulev2 = float,$savetodisk
       windowrulev2 = size 70% 75%,$savetodisk
       windowrulev2 = center,$savetodisk

       $pavucontrol = class:^(org.pulseaudio.pavucontrol)$
       windowrulev2 = float,$pavucontrol
       windowrulev2 = size 86% 40%,$pavucontrol
       windowrulev2 = move 50% 6%,$pavucontrol
       windowrulev2 = workspace special silent,$pavucontrol
       windowrulev2 = opacity 0.80,$pavucontrol

       $miniframe = title:\*Minibuf.*
       windowrulev2 = float,$miniframe
       windowrulev2 = size 64% 50%,$miniframe
       windowrulev2 = move 18% 25%,$miniframe
       windowrulev2 = animation popin 1 20,$miniframe

       windowrulev2 = float,class:^(pokefinder)$
       windowrulev2 = float,class:^(Waydroid)$

       windowrulev2 = float,title:^(Blender Render)$
       windowrulev2 = size 86% 85%,title:^(Blender Render)$
       windowrulev2 = center,title:^(Blender Render)$
       windowrulev2 = float,class:^(org.inkscape.Inkscape)$
       windowrulev2 = float,class:^(pinta)$
       windowrulev2 = float,class:^(krita)$
       windowrulev2 = float,class:^(Gimp)
       windowrulev2 = float,class:^(Gimp)
       windowrulev2 = float,class:^(libresprite)$

       windowrulev2 = opacity 0.80,title:ORUI

       windowrulev2 = opacity 1.0,class:^(org.qutebrowser.qutebrowser),fullscreen:1
       windowrulev2 = opacity 0.85,class:^(Element)$
       windowrulev2 = opacity 0.85,class:^(Logseq)$
       windowrulev2 = opacity 0.85,class:^(lollypop)$
       windowrulev2 = opacity 1.0,class:^(Brave-browser),fullscreen:1
       windowrulev2 = opacity 1.0,class:^(librewolf),fullscreen:1
       windowrulev2 = opacity 0.85,title:^(My Local Dashboard Awesome Homepage - qutebrowser)$
       windowrulev2 = opacity 0.85,title:\[.*\] - My Local Dashboard Awesome Homepage
       windowrulev2 = opacity 0.85,class:^(org.keepassxc.KeePassXC)$
       windowrulev2 = opacity 0.85,class:^(org.gnome.Nautilus)$
       windowrulev2 = opacity 0.85,class:^(org.gnome.Nautilus)$

       windowrulev2 = opacity 0.85,initialTitle:^(Notes)$,initialClass:^(Brave-browser)$

       layerrule = blur,waybar
       layerrule = xray,waybar
       blurls = waybar
       layerrule = blur,launcher # fuzzel
       blurls = launcher # fuzzel
       layerrule = blur,gtk-layer-shell
       layerrule = xray,gtk-layer-shell
       blurls = gtk-layer-shell
       layerrule = blur,~nwggrid
       layerrule = xray 1,~nwggrid
       layerrule = animation fade,~nwggrid
       blurls = ~nwggrid

       bind=SUPER,equal, exec, hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 + 0.5}')"
       bind=SUPER,minus, exec, hyprctl keyword cursor:zoom_factor "$(hyprctl getoption cursor:zoom_factor | grep float | awk '{print $2 - 0.5}')"

       bind=SUPER,I,exec,networkmanager_dmenu
       bind=SUPER,P,exec,keepmenu
       bind=SUPERSHIFT,P,exec,hyprprofile-dmenu
       bind=SUPERCTRL,R,exec,phoenix refresh

       # 3 monitor setup
       monitor=eDP-1,1920x1080@300,900x1080,1
       monitor=HDMI-A-1,1920x1080,1920x0,1
       monitor=DP-1,1920x1080,0x0,1

       # hdmi tv
       #monitor=eDP-1,1920x1080,1920x0,1
       #monitor=HDMI-A-1,1920x1080,0x0,1

       # hdmi work projector
       #monitor=eDP-1,1920x1080,1920x0,1
       #monitor=HDMI-A-1,1920x1200,0x0,1

       xwayland {
         force_zero_scaling = true
       }

       binds {
         movefocus_cycles_fullscreen = false
       }

       input {
         kb_layout = us
         kb_options = caps:escape
         repeat_delay = 350
         repeat_rate = 50
         accel_profile = adaptive
         follow_mouse = 2
         float_switch_override_focus = 0
       }

       misc {
         disable_hyprland_logo = true
         mouse_move_enables_dpms = true
         enable_swallow = true
         swallow_regex = (scratch_term)|(Alacritty)|(kitty)
         font_family = '' + userSettings.font + ''

       }
       decoration {
         rounding = 8
         dim_special = 0.0
         blur {
           enabled = true
           size = 5
           passes = 2
           ignore_opacity = true
           contrast = 1.17
           brightness = '' + (if (config.stylix.polarity == "dark") then "0.8" else "1.25") + ''

           xray = true
           special = true
           popups = true
         }
       }

    '';
  };
}



