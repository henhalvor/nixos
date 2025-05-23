{ pkgs, ... }:

{
  # 1. Install Google Chrome
  home.packages = [ pkgs.google-chrome ];

  # 2. Override the default .desktop file to add the --incognito flag
  xdg.desktopEntries."google-chrome-incognito" = {
    # Using a slightly different name avoids potential conflicts and makes it clear
    name = "Google Chrome (Incognito)";
    comment = "Access the internet (Incognito Mode)";
    # Use the executable provided by the Nix package and add the flag
    # Assuming 'google-chrome-stable' is the executable name in the package's bin dir
    exec = "${pkgs.google-chrome}/bin/google-chrome-stable --incognito %U";
    # Use the standard Chrome icon
    icon = "google-chrome";
    terminal = false;
    type = "Application";
    # Common categories for a web browser
    categories = [ "Network" "WebBrowser" ];
    # You might need to copy MimeType= line from the original .desktop file if needed
    # MimeType = "text/html;...";
  };

  # Optional: Remove the original non-incognito entry if you ONLY want the incognito one
  # Be cautious with this, as it might affect other system integrations.
  # xdg.desktopEntries."google-chrome".visible = false; # Hides original entry
  # Or fully remove it (might require finding the exact name generated by the package)
  # xdg.desktopEntries."google-chrome".name = lib.mkForce null;

}
