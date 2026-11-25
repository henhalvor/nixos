# Global instructions for coding agents (Claude Code, Codex, OpenCode, Pi)
# Agents run commands in non-interactive shells, where direnv's prompt hook
# never fires, so project flake dev shells must be entered explicitly.
# Template B2: HM-only
{ self, ... }:
{
  flake.nixosModules.agentInstructions =
    { ... }:
    {
      home-manager.sharedModules = [ self.homeModules.agentInstructions ];
    };

  flake.homeModules.agentInstructions =
    { ... }:
    let
      instructions = ''
        # Global agent instructions

        ## Nix dev shells and direnv

        Most projects define their toolchain in a Nix flake dev shell that
        direnv loads through an `.envrc`. Your shell commands run in
        non-interactive shells, where direnv never activates on its own, so
        the project's tools are missing or the wrong versions unless you
        enter the dev shell yourself.

        - If the project root has an `.envrc`, run build, test, lint, format,
          and project tool commands through it:
          `direnv exec . <command>` (for example `direnv exec . cargo test`).
        - Run `direnv exec` from the project root, or pass the root path
          instead of `.`.
        - If direnv reports that the `.envrc` is blocked, stop and ask the
          user to run `direnv allow`. Do not run `direnv allow` yourself.
        - If there is a `flake.nix` with a dev shell but no `.envrc`, use
          `nix develop -c <command>`.
        - Do not install project dependencies globally (npm -g, pip --user,
          cargo install, mise use --global) to work around a missing tool.
          The flake is the source of truth; add the tool there instead.
        - The first activation after `flake.lock` changes can take minutes
          while Nix builds. Wait for it rather than falling back to global
          tools.
      '';
    in
    {
      home.file = {
        ".claude/CLAUDE.md".text = instructions;
        ".codex/AGENTS.md".text = instructions;
        ".config/opencode/AGENTS.md".text = instructions;
        ".pi/agent/AGENTS.md".text = instructions;
      };
    };
}
