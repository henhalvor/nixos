# OpenCode Agent Orchestra

A multi-agent orchestration system for opencode that enables complex software development workflows through intelligent agent delegation and parallel execution.

> Built upon the foundation of [copilot-orchestra](https://github.com/ShepAlderson/copilot-orchestra) by ShepAlderson. Adapted for opencode.

## Overview

This repository contains custom agent prompts that work together to handle the complete software development lifecycle: **Planning → Implementation → Review → Commit**. The system uses a conductor-delegate pattern where a main orchestrator coordinates specialized subagents to efficiently tackle complex development tasks.

## Architecture

### Primary Agents

- **Orchestrator** (`Orchestrator.md`)
  - **Model:** `github-copilot/claude-sonnet-4.5`
  - Orchestrates the full development lifecycle
  - Delegates to specialized subagents for research, implementation, and review
  - Manages context conservation and parallel execution
  - Handles phase tracking and user approval gates

- **Planner** (`Planner.md`)
  - **Model:** `github-copilot/gpt-5.2`
  - **Tools restricted:** bash disabled
  - Researches requirements and analyzes codebases
  - Writes comprehensive TDD-driven implementation plans
  - Hands off to Orchestrator for execution
  - Supports parallel research across multiple subsystems

### Specialized Subagents

- **Researcher** (`Researcher.md`)
  - **Model:** `github-copilot/gpt-5.2`
  - **Tools restricted:** write, edit, bash disabled
  - Gathers comprehensive context about tasks
  - Can delegate to Scout for large-scope research
  - Returns structured findings to parent agents
  - Supports parallel research across independent subsystems

- **Implementer** (`Implementer.md`)
  - **Model:** `github-copilot/claude-sonnet-4.5`
  - Executes implementation following strict TDD principles
  - Writes tests first, then minimal code to pass
  - Handles linting and formatting
  - Can be invoked in parallel for disjoint features

- **Scout** (`Scout.md`)
  - **Model:** `github-copilot/gemini-3-flash-preview`
  - **Tools restricted:** write, edit, bash disabled
  - Rapid file/usage discovery across codebases
  - Read-only exploration (no edits/commands)
  - Returns structured results with file lists and analysis
  - MANDATORY parallel search strategy (3-10 simultaneous searches)

- **Reviewer** (`Reviewer.md`)
  - **Model:** `github-copilot/gpt-5.2`
  - **Tools restricted:** write, edit, bash disabled
  - Reviews code for correctness, quality, and test coverage
  - Returns structured feedback (APPROVED/NEEDS_REVISION/FAILED)
  - Can be invoked in parallel for independent phases
  - Focus on blocking issues vs nice-to-haves

- **Frontend** (`Frontend.md`)
  - **Model:** `github-copilot/gemini-3-pro-preview`
  - Implements user interfaces, styling, and responsive layouts
  - Expert in modern frontend frameworks and tooling
  - Follows TDD principles for frontend (component tests first)
  - Focuses on accessibility and responsive design

## Key Features

### Context Conservation: The Game Changer

**Why This Matters:** Traditional single-agent approaches force one model to handle everything—research, implementation, review, documentation—all within a limited context window. This quickly exhausts precious tokens on context that could be used for your actual code.

**How This System Solves It:** By delegating tasks to specialized subagents, we radically improve context efficiency:

- **Research agents** (Researcher, Scout) read and analyze large codebases, returning only high-signal summaries—not the raw 50,000 lines of code
- **Implementer agents** focus solely on the files they're modifying, not rereading the entire project architecture
- **Reviewer agents** examine only changed files, not context from the research phase
- **The Orchestrator** orchestrates everything without ever touching the bulk of your codebase

**The Result:** What would take 80-90% of a monolithic agent's context now takes 10-15%, leaving 70-80% more tokens for deeper analysis, better reasoning, and faster iterations.

---

### Parallel Agent Execution
- Launch multiple subagents simultaneously for independent tasks
- Scout: 3-10 parallel searches in first batch
- Researcher: Parallel research across multiple subsystems
- Implementer: Parallel implementation for disjoint features
- Maximum 10 parallel agents per phase

### Test-Driven Development
- Every phase follows red-green-refactor cycle
- Tests written first, run to fail, then minimal code
- Explicit test → code → test steps in all plans
- No manual testing unless explicitly requested

### Structured Planning
- Orchestrator-compatible plan format
- 3-10 incremental, self-contained phases
- Open questions with options/recommendations
- Risk assessment and mitigation strategies

## Installation

1. **Copy agent files to opencode agents directory:**
   ```bash
   # Global location
   ~/.config/opencode/agents/

   # Or per-project
   .opencode/agents/
   ```

2. **Restart opencode** to recognize the new agents

## Usage

### Planning a Feature with Planner

```
@Planner Plan a comprehensive implementation for adding user authentication to the app
```

Planner will:
1. Research the codebase (delegating to Scout/Researcher as needed)
2. Write a detailed TDD plan with 3-10 phases
3. Tell you to invoke Orchestrator to execute

### Executing a Plan with Orchestrator

```
@Orchestrator Implement the plan in plans/user-auth-plan.md
```

Orchestrator will:
1. Review the plan
2. Delegate Phase 1 implementation to Implementer
3. Delegate review to Reviewer
4. Present results and wait for commit approval
5. Continue through all phases

### Direct Research with Researcher

```
@Researcher Research how the database layer is structured
```

Researcher will:
1. Delegate to Scout for file discovery (if >10 files)
2. Analyze key files and patterns
3. Return structured findings

### Quick Exploration with Scout

```
@Scout Find all files related to authentication
```

Scout will:
1. Launch 3-10 parallel searches immediately
2. Read necessary files to confirm relationships
3. Return structured results with file list and analysis

## Workflow Example

```
User: @Planner plan adding a user dashboard feature

Planner:
  ├─ @Scout (find UI components)
  ├─ @Researcher (research data fetching patterns)
  ├─ @Researcher (research state management)
  └─ Writes plan → Tells user to invoke Orchestrator

User: @Orchestrator execute plans/user-dashboard-plan.md

Orchestrator: Phase 1/4 - Test Infrastructure
  └─ @Implementer Implement Phase 1
      ├─ Writes tests (fail)
      ├─ Writes minimal code
      └─ Tests pass ✓

Orchestrator: Reviewing Phase 1
  └─ @Reviewer Review Phase 1
      └─ Status: APPROVED ✓

Orchestrator: Phase 1 complete! [commit message provided]
```

## Configuration

### Plan Directory
Agents check for plan directory configuration:
1. Look for `AGENTS.md` file in workspace
2. Find plan directory specification (e.g., `.sisyphus/plans`)
3. Default to `plans/` if not specified

### Agent File Format

Agents use YAML frontmatter for configuration:

```yaml
---
description: Brief description of what this agent does
mode: subagent  # or 'primary' or 'all'
model: github-copilot/claude-sonnet-4.5
temperature: 0.2
tools:
  write: false
  edit: false
  bash: false
---

[Agent instructions here]
```

### Adding Custom Agents

Create a new file in your agents directory: `YourAgent.md`

```yaml
---
description: Brief description of what this agent does
mode: subagent
model: github-copilot/claude-sonnet-4.5
temperature: 0.2
tools:
  bash: false  # restrict as needed
---

You are a [ROLE] subagent called by a parent agent.

**Your specialty:** [Describe the domain expertise]

**Your scope:** [Define what tasks this agent handles]

**Core workflow:**
1. [Step 1 of your agent's process]
2. [Step 2 of your agent's process]
3. [Return structured findings/results]
```

Then update Orchestrator.md and Planner.md to reference your new agent.

#### Best Practices for Custom Agents

- **Single Responsibility**: Each agent should have one clear domain of expertise
- **Clear Scope**: Define exactly what the agent does and doesn't handle
- **Model Selection**: Choose the right model for the task (Sonnet for complex reasoning, Flash for speed, GPT for research)
- **Tool Minimalism**: Only enable tools the agent actually needs
- **Return Format**: Always return structured findings (not raw dumps)
- **Parallel-Aware**: Consider if your agent can run in parallel with others

#### Example Custom Agents

- **Security-Auditor**: Reviews code for vulnerabilities, dependency issues, auth flaws
- **Performance-Analyzer**: Profiles code, identifies bottlenecks, suggests optimizations
- **API-Designer**: Reviews/designs REST/GraphQL APIs, ensures consistency
- **Documentation-Writer**: Generates comprehensive docs from code
- **Migration-Expert**: Handles database migrations, version upgrades, refactoring

## Best Practices

1. **Use Planner for complex features** - Let it research and plan before implementation
2. **Leverage parallel execution** - Invoke multiple Scouts/Researchers for large tasks
3. **Trust the TDD workflow** - Each phase is self-contained with tests
4. **Review before proceeding** - Check completed phases before moving forward
5. **Commit frequently** - After each approved phase
6. **Delegate appropriately** - Let subagents handle heavy lifting

## License

MIT License

## Acknowledgments

This project builds upon the excellent work of:
- **[copilot-orchestra](https://github.com/ShepAlderson/copilot-orchestra)** by [ShepAlderson](https://github.com/ShepAlderson) - Foundation and concept for multi-agent orchestration
- **[oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)** by [code-yeongyu](https://github.com/code-yeongyu) - Inspiration for agent naming conventions and templates

---

**Note:** These agents are designed to work together. While individual agents can be used standalone, the full power comes from Orchestrator coordinating the complete workflow with intelligent delegation and parallel execution.
