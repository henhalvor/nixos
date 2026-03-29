# Claude Code — AI assistant config (CLAUDE.md)
# Source: home/modules/applications/claude-code.nix
{ self, ... }: {
  flake.nixosModules.claudeCode = { ... }: {
    home-manager.sharedModules = [ self.homeModules.claudeCode ];
  };

  flake.homeModules.claudeCode = { ... }: {
    home.file.".claude/CLAUDE.md".text = ''
      ## Communication
      - Be extremely concise. Sacrifice grammar for brevity.
      - Output terse, information-dense responses.
      - No unnecessary pleasantries or verbose explanations.
      - Be brutally honest, even if it means being direct and blunt or critical.

      ## Planning
      For complex/multi-step tasks, create structured plans with these stages:

      ### 1. Requirements Clarification
      - Ask targeted questions about ambiguities, edge cases, nuances
      - Identify gaps in specifications
      - Challenge assumptions if needed

      ### 2. Architecture Design (when applicable)
      - Outline technical approach and design decisions
      - Identify key components and their interactions
      - Note tradeoffs between approaches

      ### 3. Implementation Breakdown
      - Break into concrete, sequential steps
      - Estimate scope/complexity per step

      ### 4. Unresolved Questions
      - End each plan with bulleted list of unresolved questions (if any)

      ## Git Workflow

      ### Branch Naming
      **Format:** type/description
      **Types:** feature, bugfix, hotfix, refactor, docs, test, chore

      ### Commit Messages
      **Format:** Conventional Commits
      - Subject: imperative mood, lowercase, no period, max 50 chars
      - Body: explain why, not what (when needed)
      - Always use heredoc for multi-line commits
    '';
  };
}
