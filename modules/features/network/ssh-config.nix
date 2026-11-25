# SSH Config — remote machine connections with port forwarding
# Source: home/modules/settings/ssh.nix
# Template B2: HM-only (hardcoded per-user SSH hosts)
{self, ...}: {
  flake.nixosModules.sshConfig = {...}: {
    home-manager.sharedModules = [self.homeModules.sshConfig];
  };

  flake.homeModules.sshConfig = {pkgs, ...}: let
    # Remote filesystems for yazi's native SFTP VFS (yazi >= 25.12.29).
    # Yazi does not read ~/.ssh/config, so hosts are listed here and rendered
    # into ~/.config/yazi/vfs.toml. Auth goes through the SSH agent
    # ($SSH_AUTH_SOCK); interactive prompts are not supported.
    # Browse with `cd sftp://<name>` or the `g r <key>` keymaps below.
    yaziRemotes = [
      {
        name = "server";
        host = "hp-server-1.tail37a5eb.ts.net";
        key = "s";
      }
      {
        name = "workstation";
        host = "workstation.tail37a5eb.ts.net";
        key = "w";
      }
      {
        name = "lenovo";
        host = "lenovo-yoga-pro-7.tail37a5eb.ts.net";
        key = "l";
      }
      {
        name = "galaxy";
        host = "galaxy-book6-pro.tail37a5eb.ts.net";
        key = "g";
      }
    ];

    portsToForward = [
      {
        bind.port = 3000;
        host.address = "localhost";
        host.port = 3000;
      } # Next.js
      {
        bind.port = 5173;
        host.address = "localhost";
        host.port = 5173;
      } # Sveltekit
      {
        bind.port = 54321;
        host.address = "localhost";
        host.port = 54321;
      } # Supabase API
      {
        bind.port = 54320;
        host.address = "localhost";
        host.port = 54320;
      } # Supabase DB shadow
      {
        bind.port = 54329;
        host.address = "localhost";
        host.port = 54329;
      } # Supabase DB pooler
      {
        bind.port = 8083;
        host.address = "localhost";
        host.port = 8083;
      } # Supabase edge fn inspector
      {
        bind.port = 54322;
        host.address = "localhost";
        host.port = 54322;
      } # Supabase PostgreSQL
      {
        bind.port = 54323;
        host.address = "localhost";
        host.port = 54323;
      } # Supabase Studio
      {
        bind.port = 54324;
        host.address = "localhost";
        host.port = 54324;
      } # Supabase Inbucket
      {
        bind.port = 54327;
        host.address = "localhost";
        host.port = 54327;
      } # Supabase analytics
      {
        bind.port = 38215;
        host.address = "localhost";
        host.port = 38215;
      } # AWS SSO login
      {
        bind.port = 5037;
        host.address = "localhost";
        host.port = 5037;
      } # ADB Server
      {
        bind.port = 19000;
        host.address = "localhost";
        host.port = 19000;
      } # Expo Dev Server
      {
        bind.port = 19001;
        host.address = "localhost";
        host.port = 19001;
      } # Expo Dev Client
      {
        bind.port = 19002;
        host.address = "localhost";
        host.port = 19002;
      } # Expo Dev Tools
      {
        bind.port = 8081;
        host.address = "localhost";
        host.port = 8081;
      } # Metro Bundler
      {
        bind.port = 19003;
        host.address = "localhost";
        host.port = 19003;
      } # Expo Debugger
    ];
  in {
    xdg.configFile."yazi/vfs.toml".source = (pkgs.formats.toml {}).generate "yazi-vfs.toml" {
      sftp = builtins.listToAttrs (map (r: {
          inherit (r) name;
          value = {
            inherit (r) host;
            user = "henhal";
            port = 22;
          };
        })
        yaziRemotes);
    };

    programs.yazi.keymap.mgr.prepend_keymap =
      map (r: {
        on = ["g" "r" r.key];
        run = "cd sftp://${r.name}";
        desc = "Remote: ${r.name}";
      })
      yaziRemotes;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "server" = {
          hostname = "10.0.0.120";
          user = "henhal";
          identityFile = "~/.ssh/id_workstation";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            ExitOnForwardFailure = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
            IPQoS = "lowdelay throughput";
          };
          compression = true;
          serverAliveInterval = 15;
          serverAliveCountMax = 6;
          dynamicForwards = [
            {
              port = 8888;
              address = "localhost";
            }
          ];
          localForwards = portsToForward;
        };

        "workstation" = {
          hostname = "10.0.0.5";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          localForwards = portsToForward;
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "workstation-tailscale" = {
          hostname = "workstation.tail37a5eb.ts.net";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          localForwards = portsToForward;
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        # Plain non-interactive alias for tools that run their own remote
        # commands (T3 Code desktop SSH environments). The tmux RemoteCommand,
        # forced TTY and port forwards on workstation-tailscale break them.
        "workstation-t3" = {
          hostname = "workstation.tail37a5eb.ts.net";
          user = "henhal";
          extraOptions = {
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control-t3:%h:%p:%r";
            ControlPersist = "8h";
          };
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "server-tailscale" = {
          hostname = "hp-server-1.tail37a5eb.ts.net";
          user = "henhal";
          identityFile = "~/.ssh/id_workstation";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "laptop" = {
          hostname = "10.0.0.25";
          user = "henhal";
          identityFile = "~/.ssh/id_workstation";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "lenovo-tailscale" = {
          hostname = "lenovo-yoga-pro-7.tail37a5eb.ts.net";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };

        "galaxy-book6-pro-tailscale" = {
          hostname = "galaxy-book6-pro.tail37a5eb.ts.net";
          user = "henhal";
          extraOptions = {
            RequestTTY = "yes";
            RemoteCommand = "tmux new-session -A -s main";
            Compression = "yes";
            ControlMaster = "auto";
            ControlPath = "~/.ssh/control:%h:%p:%r";
            ControlPersist = "10m";
          };
          compression = true;
          serverAliveInterval = 30;
          serverAliveCountMax = 3;
        };
      };
    };
  };
}
