# Intel Graphics — Arc/Xe integrated GPU drivers, Vulkan, video acceleration
{...}: {
  flake.nixosModules.intelGraphics = {
    config,
    lib,
    pkgs,
    pkgs-unstable,
    ...
  }: let
    cfg = config.my.intelGraphics;
  in {
    options.my.intelGraphics.useUnstableMesa = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use Mesa from nixpkgs-unstable when the stable release lacks support for a new GPU generation.";
    };

    config = {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";
        MOZ_ENABLE_WAYLAND = "1";
      };

      hardware.graphics =
        {
          enable = true;
          enable32Bit = true;

          extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
            intel-compute-runtime
          ];

          extraPackages32 = with pkgs.pkgsi686Linux; [
            intel-media-driver
          ];
        }
        // lib.optionalAttrs cfg.useUnstableMesa {
          package = pkgs-unstable.mesa;
          package32 = pkgs-unstable.pkgsi686Linux.mesa;
        };

      hardware.firmware = with pkgs; [linux-firmware];
      hardware.enableRedistributableFirmware = true;
      hardware.cpu.intel.updateMicrocode = true;

      xdg.portal = {
        enable = true;
        extraPortals = with pkgs; [xdg-desktop-portal-gtk];
      };

      environment.systemPackages = with pkgs; [
        libva-utils
        intel-gpu-tools
      ];
    };
  };
}
