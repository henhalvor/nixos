# Oh My Pi — coding agent with role-based model routing
# Template D: HM feature + standalone package
{ self, ... }:
{
  flake.nixosModules.ohMyPi =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.ohMyPi ];
    };

  flake.homeModules.ohMyPi =
    { pkgs, ... }:
    let
      configFormat = pkgs.formats.yaml { };
    in
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.omp ];

      # Authentication and session state remain mutable in agent.db. API keys are
      # supplied through the shell environment by the secrets module.
      # home.file.".omp/agent/config.yml".source = configFormat.generate "omp-config.yml" {
      #   modelRoles = {
      #     default = "openai-codex/gpt-5.6-terra:medium";
      #     smol = "deepseek/deepseek-v4-flash:high";
      #     tiny = "deepseek/deepseek-v4-flash:high";
      #     commit = "deepseek/deepseek-v4-flash:high";
      #     task = "openai-codex/gpt-5.6-terra:medium";
      #     slow = "openai-codex/gpt-5.6-sol:high";
      #     plan = "openai-codex/gpt-5.6-sol:high";
      #     designer = "openai-codex/gpt-5.6-sol:medium";
      #     vision = "openai-codex/gpt-5.6-terra:medium";
      #     advisor = "deepseek/deepseek-v4-pro:high";
      #   };
      #
      #   cycleOrder = [
      #     "smol"
      #     "default"
      #     "slow"
      #   ];
      #
      #   advisor.enabled = false;
      #
      #   # Updates are handled by changing the pinned version and hashes below.
      #   startup.checkUpdate = false;
      # };
    };

  # Standalone: nix run .#omp
  perSystem =
    { pkgs, ... }:
    let
      version = "17.2.2";
      release =
        {
          x86_64-linux = {
            asset = "omp-linux-x64";
            hash = "sha256-MG9VVjfWPc7YDP+y/pCNp+BUOJ+FjAcfMEvBfj7WIt4=";
          };
          aarch64-linux = {
            asset = "omp-linux-arm64";
            hash = "sha256-BE5AXcNA0YYroaY00g7FxgCkDg7yQiG72z2zc7H+OtU=";
          };
        }
        .${pkgs.stdenv.hostPlatform.system};
    in
    {
      packages.omp = pkgs.stdenvNoCC.mkDerivation {
        pname = "oh-my-pi";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${release.asset}";
          inherit (release) hash;
        };

        dontUnpack = true;
        dontPatchELF = true;

        installPhase = ''
          runHook preInstall
          install -Dm755 "$src" "$out/bin/omp"
          runHook postInstall
        '';

        meta = {
          description = "Coding agent CLI with role-based model routing";
          homepage = "https://omp.sh";
          license = pkgs.lib.licenses.mit;
          mainProgram = "omp";
          platforms = [
            "x86_64-linux"
            "aarch64-linux"
          ];
          sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
        };
      };
    };
}
