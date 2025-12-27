{
  config,
  pkgs,
  userSettings,
  ...
}: {
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
  };

  # Note: capSysAdmin = true automatically creates the security wrapper
  # Manual security.wrappers.sunshine config removed to prevent conflicts

  # Add CUDA toolkit for NVENC hardware encoding
  environment.systemPackages = with pkgs; [
    libva-utils
    cudatoolkit
  ];

  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;

  # Deploy Sunshine apps.json declaratively using systemd tmpfiles
  systemd.tmpfiles.rules = [
    "L+ ${userSettings.homeDirectory}/.config/sunshine/apps.json - ${userSettings.username} users - ${./apps.json}"
  ];
}
#
# NixOS Moonlight Sunshine
#
# Sunshine is an open-source implementation of NVIDIA's GameStream, enabling self-hosted, low-latency cloud gaming compatible with Moonlight clients across various devices  On NixOS, it can be integrated via the NixOS module system, which configures Sunshine as a systemd user unit that starts automatically upon graphical session login, though a logout/login or system restart may be required after configuration changes due to NixOS's handling of user units
#
# To install and enable Sunshine, add the following to your NixOS configuration:
#
# ```nix
# services.sunshine = {
#   enable = true;
#   autoStart = true;
#   capSysAdmin = true;
#   openFirewall = true;
# };
# ```
#
# This configuration automatically manages firewall rules, opening necessary TCP and UDP ports (47984–48010 for TCP, 47998–48000 for UDP) and setting up the required `cap_sys_admin` capability for the Sunshine binary  The capability is enforced through a security wrapper, which ensures the binary runs with elevated privileges:
#
# ```nix
# security.wrappers.sunshine = {
#   owner = "root";
#   group = "root";
#   capabilities = "cap_sys_admin+p";
#   source = "${pkgs.sunshine}/bin/sunshine";
# };
# ```
#
# For Avahi-based service discovery, which helps Moonlight clients detect the host, enable Avahi publishing:
#
# ```nix
# services.avahi.publish.enable = true;
# services.avahi.publish.userServices = true;
# ```
#
# The Sunshine web interface is accessible at `https://localhost:47990` for configuration, and the host can be manually added in the Moonlight client using the IP address followed by port `47989`
#
# Advanced configurations, such as exposing specific applications (e.g., a 1440p desktop session), can be defined via the `services.sunshine.applications` option, allowing for dynamic display mode switching using tools like `kscreen-doctor`
#
# For users on Intel GPUs, enabling VA-API support requires additional drivers and SDKs, such as `intel-media-driver` and `vpl-gpu-rt`, which should be included in the `hardware.opengl.extraPackages` list  f

