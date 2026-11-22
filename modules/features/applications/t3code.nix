# T3 Code — GUI for coding agents (from unstable)
# Provides `t3code-desktop` (desktop app) and `t3` (CLI/server)
# Template B2: HM-only
{ self, ... }:
{
  flake.nixosModules.t3code =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.t3code ];
    };

  flake.homeModules.t3code =
    { pkgs-unstable, ... }:
    {
      home.packages = [ pkgs-unstable.t3code ];
    };
}
