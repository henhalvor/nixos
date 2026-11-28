# Galaxy Book6 webcam — SmartSens SC200PC sensor on Intel IPU7 (Panther Lake)
# Template A: NixOS-only
#
# Off by default: set `my.galaxybook6Camera.enable = true` and reboot (the
# stock ipu_bridge can't be swapped at runtime). Untested on hardware so far.
#
# The sensor is ACPI `SSLC2000`. Mainline has no driver for it, and the
# kernel's ipu_bridge doesn't list it, so the IPU7 finds "no subdev in graph".
# This module adds:
#   - sc200pc.ko, an out-of-tree sensor driver
#     (https://github.com/z4ziggy/galaxybook6-camera), and ipu-bridge.ko built
#     from the running kernel's own source plus the SSLC2000 entry. Both go in
#     `updates/`, which depmod prefers over the stock ipu_bridge.
#   - libcamera 0.7 (stable has 0.6.0; the driver needs >= 0.7, which also
#     brings the GPU software ISP), built with the stable toolchain and
#     shipping the sensor's tuning file. Exposed as
#     `my.galaxybook6Camera.libcamera` for the host's PipeWire override.
#   - a WirePlumber rule hiding the ~32 raw IPU7 capture nodes, so apps only
#     see the libcamera camera.
#
# Apps reach the camera through PipeWire. Firefox/Zen need
# media.webrtc.camera.allow-pipewire = true; Chromium-based browsers need the
# "PipeWire Camera support" flag.
{...}: {
  flake.nixosModules.galaxybook6Camera = {
    config,
    lib,
    pkgs,
    pkgs-unstable,
    ...
  }: let
    src = pkgs.fetchFromGitHub {
      owner = "z4ziggy";
      repo = "galaxybook6-camera";
      rev = "3565d0993e05e7482fc47e30f9c9371fd3d4f341";
      hash = "sha256-Cimchb7KSUqTNTDCRdTHic5qpxyMx4AVXnXf+He6nW0=";
    };

    kernelModules = config.boot.kernelPackages.callPackage ({
      stdenv,
      kernel,
      kernelModuleMakeFlags,
    }:
      stdenv.mkDerivation {
        pname = "sc200pc";
        version = "0.1.0-unstable-2026-11-28-${kernel.version}";
        inherit src;

        nativeBuildInputs = kernel.moduleBuildDependencies;

        # ipu-bridge.c isn't in the kernel headers: take it from this exact
        # kernel's source and add the SSLC2000 entry (as upstream's Makefile).
        postUnpack = ''
          tar -xf ${kernel.src} --strip-components=5 -C $sourceRoot \
            --wildcards '*/drivers/media/pci/intel/ipu-bridge.c'
        '';
        postPatch = ''
          grep -q '"SSLC2000"' ipu-bridge.c || sed -i \
            's|\(ipu_supported_sensors\[\] = {\)|\1\n\t/* SmartSens SC200PC (Samsung Galaxy Book6) */\n\tIPU_SENSOR_CONFIG("SSLC2000", 1, 390000000),|' \
            ipu-bridge.c
          grep -q '"SSLC2000"' ipu-bridge.c
        '';

        makeFlags =
          kernelModuleMakeFlags
          ++ [
            "-C"
            "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "M=$(PWD)"
          ];
        buildFlags = ["modules"];

        installPhase = ''
          runHook preInstall
          install -Dm444 -t $out/lib/modules/${kernel.modDirVersion}/updates sc200pc.ko ipu-bridge.ko
          runHook postInstall
        '';

        meta = {
          description = "SmartSens SC200PC webcam driver for the Samsung Galaxy Book6 (Intel IPU7)";
          homepage = "https://github.com/z4ziggy/galaxybook6-camera";
          license = lib.licenses.gpl2Only;
          platforms = ["x86_64-linux"];
        };
      }) {};

    # Unstable's version, sources and options on stable's recipe and
    # toolchain, so PipeWire (stable glibc) can load it.
    libcamera = pkgs.libcamera.overrideAttrs (old: {
      inherit (pkgs-unstable.libcamera) version src mesonFlags;
      patches = pkgs-unstable.libcamera.patches or [];
      buildInputs = old.buildInputs ++ [pkgs.libyuv pkgs.libglvnd];
      # libcamera only searches its own prefix for tuning files.
      postInstall =
        (old.postInstall or "")
        + ''
          install -Dm444 ${src}/libcamera/sc200pc.yaml $out/share/libcamera/ipa/simple/sc200pc.yaml
        '';
    });
    cfg = config.my.galaxybook6Camera;
  in {
    options.my.galaxybook6Camera = {
      enable = lib.mkEnableOption "the SC200PC webcam driver, libcamera 0.7 and the IPU7 WirePlumber rule";
      libcamera = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = libcamera;
        description = "libcamera >= 0.7 with the SC200PC tuning file; build PipeWire against it when enabled";
      };
    };

    config = lib.mkIf cfg.enable {
      boot.extraModulePackages = [kernelModules];

      # `cam -l` / `cam -c1 -C10` for testing outside PipeWire.
      environment.systemPackages = [libcamera];

      services.pipewire.wireplumber.extraConfig."50-ipu7-hide-v4l2" = {
        "monitor.v4l2.rules" = [
          {
            # The IPU's fixed PCI address on Panther Lake. device.name is
            # matched because the v4l2 cap.* properties aren't set yet when
            # device rules run.
            matches = [{"device.name" = "~v4l2_device.pci-0000_00_05.0*";}];
            actions.update-props."device.disabled" = true;
          }
        ];
      };
    };
  };
}
