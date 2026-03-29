{ lib, pkgs, ... }:
{
  # Helper to create wl-paste watcher services
  mkWlPasteWatchService = {
    name,
    description,
    command,
    types ? [ "text" "image" ],
    wantedBy ? [ "graphical-session.target" ],
  }: {
    Unit = {
      Description = description;
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = let
      watchCommands = map (type: 
        "${pkgs.wl-clipboard}/bin/wl-paste --type ${type} --watch ${command}"
      ) types;
    in {
      ExecStart = if (builtins.length watchCommands) == 1
        then builtins.head watchCommands
        else pkgs.writeShellScript "${name}-watch" ''
          ${lib.concatMapStringsSep " & \n" (cmd: cmd) watchCommands}
          wait
        '';
      Restart = "on-failure";
    };

    Install = { WantedBy = wantedBy; };
  };
}
