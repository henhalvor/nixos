# AGENTS.md — Project Context & Workflow Instructions

This file contains project-specific context and operational guidelines for Hermes. It complements SOUL.md (persistent personality) with task-level and project-level instructions.

## Obsidian Vault Structure

All persistent state lives in **~/Vault** as plain markdown files. The vault is ground truth—never guess when you can read.

```
~/Vault/
├── Agent-Shared/
│   ├── today.md              ← your task queue (only tasks)
│   ├── project-state.md      ← high-level status of all active projects
│   ├── decisions-log.md      ← append-only log of decisions
│   ├── user-profile.md       ← stable facts about the user (never tasks)
│   └── projects/
│       └── <project-name>/
│           └── PROJECT_CONTEXT.md
│
└── Agent-Hermes/
    ├── working-context.md    ← what you are doing RIGHT NOW
    ├── mistakes.md           ← append-only error log
    └── daily/
        └── YYYY-MM-DD.md     ← session history (append only)
```

## Read Rules

Before acting, check the relevant file:

| Situation | File to read |
|---|---|
| User asks "what do I need to do" | `today.md` |
| Starting work on a project | `PROJECT_CONTEXT.md` for that project |
| User asks about a past decision | `decisions-log.md` |
| Context feels uncertain | `working-context.md` |
| Starting a coding task | `PROJECT_CONTEXT.md` → then codebase |

**Never guess. Always read first.**

## Write Rules

### When to write what

| Trigger | Action |
|---|---|
| Starting a task | Update `working-context.md` |
| Working on a project | Update `PROJECT_CONTEXT.md` |
| Making a decision | Append to `decisions-log.md` |
| Hitting an error | Append to `mistakes.md` |
| Completing a task | Mark `[x]` in `today.md`, update `working-context.md`, update daily log |
| User adds a new task | Add to `today.md` |
| End of session | Update daily log with summary, completed tasks, decisions |

### What NOT to write

- Never store tasks in `user-profile.md`
- Never store personal facts in `today.md`
- Never edit past entries in append-only files (`decisions-log.md`, `mistakes.md`, daily logs)
- Never store temporary state in Layer 1 (`user-profile.md`, `project-state.md`)

## Boot Sequence

Run this at the **start of every session** without exception:

1. Read `Agent-Shared/user-profile.md`
2. Read `Agent-Shared/project-state.md`
3. Read `Agent-Shared/today.md`
4. Read `Agent-Hermes/working-context.md`
5. Read `Agent-Hermes/daily/YYYY-MM-DD.md` (today's log, if it exists)

Report back: "Booted. Active tasks: [...]. Currently working on: [...]."

If any file is missing, report it and ask whether to create it from the template.

## Task Format

`today.md` must always use this format:

```markdown
## Tasks Today
- [ ] Task description
- [x] Completed task (mark done, do not delete)

## Scheduled
- HH:MM Event name
```

No alternatives. Completed tasks are marked `[x]`, never deleted.

## Project Context Format

Each `projects/<name>/PROJECT_CONTEXT.md` must contain:

```markdown
## Overview

## Codebase Location

## Architecture Overview

## Entry Points

## Current Status

## Goals

## Decisions

## Next Steps

## Open Questions

---
## Working Log (append below)
### YYYY-MM-DD
#### Current Task
#### Plan
#### Last Actions
#### Next Step
```

## Response Style

- **Terminal-first.** No unnecessary markdown decorations.
- **Status in one line:** "Done. Updated today.md and working-context.md."
- **When booting:** Compact summary, not a wall of text.
- **When unsure:** One sentence admission + one specific question.

## Failure Recovery

If you lose context mid-session:

1. Run the BOOT SEQUENCE
2. Report what you recovered
3. Ask the user to confirm before continuing

If a vault file is missing:

1. Say which file is missing
2. Offer to create it from the template
3. Do not proceed with guesses

If you made a mistake:

1. Append to `mistakes.md`: date, what happened, correct action
2. Fix the mistake
3. Report what you did

## Key Principles

- **The vault is the brain, not your context window.** Everything important lives in files.
- **Predictable structure.** Follow the schema exactly; do not improvise.
- **Append-only for history.** Never edit past entries in logs.
- **Layer separation.** Keep user facts, project state, and tasks in their designated files.
- **No guessing.** Always read before acting.
