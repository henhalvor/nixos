{
  config,
  unstable,
  pkgs,
  ...
}: {
  programs.obsidian = {
    enable = true;
    package = unstable.obsidian;
  };
}
