
{ config, pkgs, unstable, ... }:

{
  # Your existing config...
  
  # home.packages = with pkgs; [
  #   unstable.claude-code
  # ];

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
    - Use AskUserQuestion for multiple related clarifications

    ### 2. Architecture Design (when applicable)
    - Outline technical approach and design decisions
    - Identify key components and their interactions
    - Note tradeoffs between approaches

    ### 3. Implementation Breakdown
    - Break into concrete, sequential steps
    - Use TodoWrite to track stages
    - Estimate scope/complexity per step

    ### 4. Unresolved Questions
    - End each plan with bulleted list of unresolved questions (if any)
    - Keep questions extremely terse

    ## Git Workflow

    ### Branch Naming
    **Format:** `type/description`
    **Types:** `feature`, `bugfix`, `hotfix`, `refactor`, `docs`, `test`, `chore`
    **Examples:**
    - `feature/user-auth`
    - `bugfix/login-redirect`
    - `refactor/api-client`

    ### Commit Messages
    **Format:** Conventional Commits
    ```
    type(scope): subject

    body (optional)

    🤖 Generated with [Claude Code](https://claude.com/claude-code)

    Co-Authored-By: Claude <noreply@anthropic.com>
    ```

    **Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `ci`
    **Examples:**
    - `feat(auth): add OAuth2 login`
    - `fix(api): handle rate limit errors`
    - `refactor(db): migrate to connection pool`

    **Rules:**
    - Subject: imperative mood, lowercase, no period, max 50 chars
    - Body: explain why, not what (when needed)
    - Always use heredoc for multi-line commits

    ## GitHub (gh CLI)

    ### Issue Creation
    Create issues via `gh issue create` when:
    - User explicitly requests
    - Task is complex with multiple unknowns
    - Need to track feature before implementation

    **Format:**
    ```bash
    gh issue create --title "type: concise description" --body "$(cat <<'EOF'
    ## Problem
    [What needs to be solved]

    ## Proposed Solution
    [High-level approach]

    ## Acceptance Criteria
    - [ ] Criterion 1
    - [ ] Criterion 2
    EOF
    )"
    ```

    ### Pull Requests
    For features, use `gh pr create`:
    ```bash
    gh pr create --title "type: description" --body "$(cat <<'EOF'
    ## Summary
    - Bullet 1
    - Bullet 2

    ## Changes
    - Change 1
    - Change 2

    ## Test Plan
    - [ ] Test 1
    - [ ] Test 2

    🤖 Generated with [Claude Code](https://claude.com/claude-code)
    EOF
    )"
    ```

    ### Other gh Operations
    - View PRs: `gh pr list`, `gh pr view <number>`
    - View issues: `gh issue list`, `gh issue view <number>`
    - PR comments: `gh api repos/{owner}/{repo}/pulls/{number}/comments`
    - Always prefer `gh` over manual web interaction

    ## Documentation

    ### Context Summaries
    After completing implementation or significant changes, create context doc to bring LLMs/users up to speed.

    **When to create:**
    - After completing features/refactors
    - After fixing complex bugs
    - When user requests
    - Before switching contexts on long-running work

    **Format:** Create `CONTEXT.md` or `docs/changes-YYYY-MM-DD.md`

    **Structure:**
    ```markdown
    # Context: [Feature/Change Name]

    ## Summary
    [1-2 sentence overview of what was done]

    ## Files Changed
    - `path/to/file.ts` - [what changed]
    - `path/to/other.ts` - [what changed]

    ## Key Changes
    - **Change 1**: Rationale and impact
    - **Change 2**: Rationale and impact

    ## Architecture/Design Decisions
    - Decision: Why this approach over alternatives

    ## Dependencies Added/Changed
    - `package@version` - Why added

    ## Testing
    - What was tested
    - Edge cases covered

    ## Known Issues/TODOs
    - [ ] Issue 1
    - [ ] Issue 2

    ## Context for LLMs
    [Any specific context that helps LLMs understand the codebase state]
    ```

    **Rules:**
    - Be concise but complete
    - Include file paths with line refs where relevant
    - Explain *why*, not just *what*
    - Structure for quick scanning
    - Don't create unless requested or truly necessary

  '';

  
}
