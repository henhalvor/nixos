# freecad — browser
# Source: home/modules/applications/freecad.nix
# Template B2: HM-only
#
# FreeCAD profile sync via Syncthing-backed ~/Shared:
#
# Workstation -> shared profile, with FreeCAD closed:
#   mkdir -p ~/Shared/FreeCAD-profile/config ~/Shared/FreeCAD-profile/data
#   rsync -a --delete ~/.config/FreeCAD/ ~/Shared/FreeCAD-profile/config/
#   rsync -a --delete ~/.local/share/FreeCAD/ ~/Shared/FreeCAD-profile/data/
#
# Shared profile -> Lenovo, with FreeCAD closed:
#   rsync -a --delete ~/Shared/FreeCAD-profile/config/ ~/.config/FreeCAD/
#   rsync -a --delete ~/Shared/FreeCAD-profile/data/ ~/.local/share/FreeCAD/
{ self, ... }:
{
  flake.nixosModules.freecad =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.freecad ];
    };

  flake.homeModules.freecad =
    {
      config,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      freecad = pkgs-unstable.freecad;
      freecadXcb = pkgs.symlinkJoin {
        name = "freecad-xcb";
        paths = [ freecad ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f $out/share/applications/org.freecad.FreeCAD.desktop
          cp ${freecad}/share/applications/org.freecad.FreeCAD.desktop \
            $out/share/applications/org.freecad.FreeCAD.desktop
          substituteInPlace $out/share/applications/org.freecad.FreeCAD.desktop \
            --replace-fail "Exec=FreeCAD - --single-instance %F" \
                           "Exec=FreeCAD --single-instance %F"

          # Keep the existing XCB/XWayland path. FreeCAD has a native Wayland
          # platform plugin, but it has shown blank 3D views on Niri/Sway. Do
          # not switch this to Wayland without manually testing PartDesign's
          # 3D viewport and task dialogs.
          #
          # FreeCAD is a Qt Widgets application with embedded Python/PySide.
          # Its package wrapper supplies a matched Qt and Python runtime, but
          # desktop-wide Qt and Python variables otherwise leak into it. In
          # particular, Kvantum/qt5ct, mixed Qt 5/Qt 6 plugin paths, and the
          # user Python base were associated with task-dialog teardown
          # instability and SIGSEGVs in FreeCAD's Qt hover handling. Strip
          # those variables in
          # this outer wrapper before FreeCAD's own wrapper adds its runtime.
          wrapProgram $out/bin/FreeCAD \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11 \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH \
            --unset PYTHONPATH \
            --unset PYTHONUSERBASE
          wrapProgram $out/bin/freecad \
            --set QT_QPA_PLATFORM xcb \
            --set SDL_VIDEODRIVER x11 \
            --unset QT_STYLE_OVERRIDE \
            --unset QT_QPA_PLATFORMTHEME \
            --unset QT_PLUGIN_PATH \
            --unset QML2_IMPORT_PATH \
            --unset PYTHONPATH \
            --unset PYTHONUSERBASE
        '';
      };

      # FreeCAD weekly AppImage
      #
      # Releases: https://github.com/FreeCAD/FreeCAD/releases
      #
      # Initial installation:
      #   1. Download the latest Linux x86_64 weekly AppImage and its
      #      AppImage-SHA256.txt file from the releases page.
      #   2. Verify it in the download directory:
      #        sha256sum -c FreeCAD_weekly-YYYY.MM.DD-Linux-x86_64.AppImage-SHA256.txt
      #   3. Integrate the verified file with the mutable userland:
      #        userland install appimage "$HOME/Downloads/FreeCAD_weekly-YYYY.MM.DD-Linux-x86_64.AppImage"
      #
      # Gear Lever moves the file to ~/AppImages/freecad.appimage and creates
      # ~/.local/share/applications/freecad.desktop. That generated entry is
      # normally shown as "FreeCAD (<build id>)". Leave it in place because
      # Gear Lever uses it for inventory, metadata, and removal, but launch
      # "FreeCAD Weekly" instead. The Home Manager entry below uses this
      # wrapper to isolate the weekly profile and clean its runtime environment.
      #
      # Gear Lever 3.4.7 cannot follow GitHub's latest prerelease reliably, so
      # `userland update` reports this AppImage as `unknown`. Update it manually:
      #   1. Download and verify the new weekly AppImage as above.
      #   2. Close every FreeCAD window.
      #   3. Keep one rollback copy:
      #        cp --reflink=auto ~/AppImages/freecad.appimage ~/AppImages/freecad.appimage.previous
      #   4. Replace the installed image without changing its stable path:
      #        install -m 0755 ~/Downloads/FreeCAD_weekly-YYYY.MM.DD-Linux-x86_64.AppImage ~/AppImages/freecad.appimage
      #   5. In Gear Lever, select FreeCAD and click "Reload metadata".
      #
      # Roll back a broken weekly build with:
      #   install -m 0755 ~/AppImages/freecad.appimage.previous ~/AppImages/freecad.appimage
      freecadWeekly = pkgs.writeShellApplication {
        name = "freecad-weekly";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          appimage="${config.home.homeDirectory}/AppImages/freecad.appimage"
          config_dir="${config.home.homeDirectory}/.config/FreeCAD-weekly"
          data_dir="${config.home.homeDirectory}/.local/share/FreeCAD-weekly"

          if [[ ! -x "$appimage" ]]; then
            echo "FreeCAD Weekly AppImage not found or not executable: $appimage" >&2
            echo "Install it with: userland install appimage /absolute/path/to/FreeCAD_weekly-*.AppImage" >&2
            exit 1
          fi

          mkdir -p "$config_dir" "$data_dir"

          exec env \
            -u QT_STYLE_OVERRIDE \
            -u QT_QPA_PLATFORMTHEME \
            -u QT_PLUGIN_PATH \
            -u QML2_IMPORT_PATH \
            -u PYTHONPATH \
            -u PYTHONUSERBASE \
            QT_QPA_PLATFORM=xcb \
            SDL_VIDEODRIVER=x11 \
            DESKTOPINTEGRATION=1 \
            FREECAD_USER_HOME="$data_dir" \
            "$appimage" \
              -u "$config_dir/user.cfg" \
              -s "$config_dir/system.cfg" \
              "$@"
        '';
      };
    in
    {
      # FreeCAD's Render workbench writes POV-Ray scene files, while POV-Ray
      # itself performs the render. Configure the profile path to `povray` in
      # FreeCAD's Render preferences after activation.
      home.packages = [ freecadXcb freecadWeekly pkgs.povray ];

      # Gear Lever owns the weekly AppImage and its integration metadata. This
      # entry supplies a stable launcher name, isolates its profile from stable
      # FreeCAD, and applies the same XCB and environment cleanup as the Nix
      # package above.
      xdg.desktopEntries.freecad-weekly = {
        name = "FreeCAD Weekly";
        genericName = "CAD Application";
        comment = "Launch the Gear Lever-managed FreeCAD development build";
        exec = "${freecadWeekly}/bin/freecad-weekly %F";
        icon = "org.freecad.FreeCAD";
        terminal = false;
        categories = [ "Graphics" "Science" "Education" "Engineering" ];
        settings.StartupWMClass = "FreeCAD";
      };
    };
}
