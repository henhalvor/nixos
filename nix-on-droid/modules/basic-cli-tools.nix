{ pkgs, ... }:

{
  # Basic CLI tools that are normally available on Linux systems
  # but are missing on Android/Termux by default
  home.packages = with pkgs; [
    # Search tools
    ripgrep       # Modern grep replacement (rg)
    gnugrep       # Traditional grep
    
    # File tools
    findutils     # find, xargs, locate
    which         # locate commands
    file          # determine file type
    
    # Text processing
    gnused        # sed stream editor
    gawk          # awk text processing
    
    # Network tools
    inetutils     # telnet, ftp, etc
    curl          # already in main config, but ensuring it's here
    wget          # already in main config
    
    # Compression
    gzip          # gzip compression
    bzip2         # bzip2 compression
    xz            # xz compression
    zip           # zip compression
    unzip         # already in dev-tools, but ensuring
    
    # System utilities
    procps        # ps, top, kill, etc
    less          # pager
    man           # manual pages
    coreutils     # ls, cp, mv, rm, etc (GNU versions)
    
    # Diff and patch
    diffutils     # diff, cmp, diff3
    patch         # apply patches
  ];
}
