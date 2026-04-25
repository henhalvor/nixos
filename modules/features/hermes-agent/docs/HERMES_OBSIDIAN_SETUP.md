# Hermes Agent + Obsidian Vault — Declarative Setup

This guide explains how Hermes integrates with your Obsidian vault as a memory system, managed entirely through NixOS configuration.

---

## Overview

Hermes is a persistent AI assistant that:
- **Reads from vault files** to understand tasks, decisions, and project state
- **Writes back to vault files** to persist decisions, updates, and logs
- **Survives context loss** because everything important lives in files, not in Claude's context window
- **Never guesses** — always reads the source of truth first

The integration has three layers:
1. **Identity layer** — SOUL.md (your Hermes personality, managed by Nix)
2. **Instructions layer** — AGENTS.md (operational guidelines, managed by Nix)
3. **Memory layer** — ~/Vault (Obsidian vault, auto-initialized by Nix)

---

## Automatic Setup (Nix)

When you rebuild your NixOS host with `sudo nixos-rebuild switch --flake .#<host>`, the following happens automatically:

1. **Vault directories are created:**
   ```
   ~/Vault/
   ├── Agent-Shared/
   │   ├── today.md              ← your task queue
   │   ├── project-state.md      ← active projects
   │   ├── decisions-log.md      ← decision history
   │   ├── user-profile.md       ← stable facts
   │   └── projects/
   │
   └── Agent-Hermes/
       ├── working-context.md    ← current work
       ├── mistakes.md           ← error log
       └── daily/
   ```

2. **Vault files are seeded** with templates if they don't exist (never overwritten if they do).

3. **SOUL.md is installed** to ~/.hermes/SOUL.md (your Hermes identity).

4. **AGENTS.md is registered** with Hermes as a context document.

5. **Permissions are set** correctly (readable/writable by your user).

### Customizing the vault location

To use a different vault path, add to your host configuration:

```nix
my.hermesAgent.vaultPath = "/custom/path/to/vault";
```

Default is `~/Vault`.

---

## Your Vault Files

### Agent-Shared (Layer 1: Invariant Facts)

These files hold facts and metadata that are true for the entire session.

#### user-profile.md

**Purpose:** Stable facts about you that never change (used once per session at boot).

Hermes reads this file once when it boots, never modifies it, and uses it to understand who you are and how to work with you.

```markdown
## Identity
Name: Henrik

## Working style
Prefer short answers. Always explain tradeoffs.

## Tools
Editor: nvim
Shell: zsh
Default code directory: ~/code

## Stable facts
Timezone: Europe/Oslo
Repository root: ~/.dotfiles
```

**Key rule:** Never put tasks here. This is identity only.

#### project-state.md

**Purpose:** High-level status of all active projects (read at boot, updated occasionally).

```markdown
## Active projects
- dotfiles: NixOS configuration and home-manager setup
- hermes-agent: Persistent AI assistant integration

## On hold
(none)

## Completed
(none)
```

**Key rule:** This is status, not tasks. Tasks go in `today.md`.

### Agent-Shared/projects (Layer 1: Project Metadata)

Each project gets its own `PROJECT_CONTEXT.md` file that serves as the entry point for understanding that codebase.

```
Agent-Shared/projects/my-project/PROJECT_CONTEXT.md
```

**Contents:**

```markdown
## Overview
What this project does in 2-3 sentences.

## Codebase Location
~/code/my-project

## Architecture Overview
- Backend: FastAPI
- Frontend: React
- Database: Postgres

## Entry Points
- src/main.py
- src/api/routes.py

## Current Status
Active development on auth module.

## Goals
- [ ] Goal 1
- [ ] Goal 2

## Decisions
- [date] Decision A: Rationale
- [date] Decision B: Rationale

## Next Steps
- Start with Goal 1

## Open Questions
(none)

---
## Working Log
### 2026-04-24
#### Current Task
Working on JWT auth flow.

#### Plan
1. Implement token generation
2. Add refresh endpoint
3. Write tests

#### Last Actions
- Created auth service module
- Added JWT validation middleware

#### Next Step
Add refresh token endpoint
```

**Key rules:**
- Update whenever meaningful project state changes
- Working log section is append-only (never edit past entries)
- Read this before starting work on the project

### Agent-Shared/today.md (Layer 2: Session Work)

**Purpose:** Your task queue for the current day.

**Format (strict):**

```markdown
## Tasks Today
- [ ] Task one description
- [ ] Task two description
- [x] Completed task (mark done, do not delete)

## Scheduled
- 14:00 Meeting name
- 16:30 Call with person
```

**Key rules:**
- Only tasks go here — no project context, no decisions
- Completed tasks are marked `[x]`, never deleted
- No alternative formats

### Agent-Shared/decisions-log.md (Layer 3: Append-Only History)

**Purpose:** Authoritative record of decisions made.

```markdown
# Decisions Log

### 2026-04-24
- **Decision:** Use Obsidian vault for Hermes memory instead of Redis
  - **Rationale:** Simpler, no external dependency, queryable as plain text
  - **Tradeoff:** Slightly slower lookups, but acceptable for this workload

### 2026-04-23
- **Decision:** Move to NixOS for all infrastructure
  - **Rationale:** Declarative, reproducible, version-controlled
  - **Tradeoff:** Learning curve, but long-term gain in maintainability
```

**Key rules:**
- Append-only: never edit or delete past entries
- Include rationale and tradeoffs for each decision
- Hermes can explain past decisions by reading this file

### Agent-Hermes (Layer 2: Session Context)

These files track your current session and Hermes' immediate state. They can be overwritten freely.

#### working-context.md

**Purpose:** What you're doing RIGHT NOW (updated whenever Hermes switches tasks).

```markdown
# Working Context

## Current Task
Setting up Hermes + Obsidian integration

## What I'm doing
- Reading vault structure from system prompt
- Creating AGENTS.md template
- Updating Nix config to auto-initialize vault

## Last Update
2026-04-24 14:30

## Next Action
Test the vault initialization with nixos-rebuild
```

**Key rule:** Overwrite freely, update whenever switching tasks or scope changes.

#### mistakes.md (Layer 3: Append-Only History)

**Purpose:** Append-only log of errors and corrections (used for failure recovery).

```markdown
# Mistakes Log

### 2026-04-24 14:15
**Mistake:** Tried to write to `user-profile.md` from working context
**What went wrong:** Violated layer separation; user-profile is read-only by Hermes
**Correction:** Used `working-context.md` instead
**Lesson:** Layer 1 files are invariant; only Layers 2-3 get writes

### 2026-04-20 10:30
**Mistake:** Edited a past entry in `decisions-log.md`
**What went wrong:** Broke append-only semantics; historical record now unreliable
**Correction:** Re-added the entry as a new append with correction note
**Lesson:** Append-only files are immutable; corrections are new appends, not rewrites
```

**Key rule:** Append-only: never edit past entries. Corrections are new appends.

### Agent-Hermes/daily/ (Layer 3: Append-Only History)

Session logs live in `Agent-Hermes/daily/YYYY-MM-DD.md`.

```markdown
# 2026-04-24 Session Log

## Session Summary
Implemented Hermes + Obsidian declarative integration.

## Tasks Completed
- [x] Extracted SOUL.md from system prompt
- [x] Created AGENTS.md template
- [x] Updated Nix config for vault initialization
- [x] Updated setup guide

## Decisions Made
- Store vault in ~/Vault (user-accessible location)
- Make AGENTS.md a managed document in Hermes
- Auto-seed vault on first nixos-rebuild

## Mistakes
(none)

## Next Session
- Test vault initialization
- Configure Obsidian to point at ~/Vault
- Run boot sequence manually to validate
```

**Key rule:** Append-only. One log per calendar day.

---

## Hermes Boot Sequence

Hermes runs this automatically at the start of **every session**:

1. Read `Agent-Shared/user-profile.md`
2. Read `Agent-Shared/project-state.md`
3. Read `Agent-Shared/today.md`
4. Read `Agent-Hermes/working-context.md`
5. Read `Agent-Hermes/daily/YYYY-MM-DD.md` (if it exists)

Then reports: "Booted. 3 tasks open. Currently working on: auth refactor."

If any file is missing, it says so and offers to create it from the template.

---

## When to Read (During the Session)

Before acting, always check the relevant file:

| Situation | File to read |
|---|---|
| User asks "what do I need to do" | `today.md` |
| Starting work on a project | `PROJECT_CONTEXT.md` for that project |
| User asks about a past decision | `decisions-log.md` |
| Context feels uncertain | `working-context.md` |
| Starting a coding task | `PROJECT_CONTEXT.md` → then read codebase |

**Rule:** Never guess when you can read.

---

## When to Write

| Trigger | File | Action |
|---|---|---|
| Starting a task | `working-context.md` | Update current task |
| Working on a project | `PROJECT_CONTEXT.md` | Update status/notes |
| Making a decision | `decisions-log.md` | Append new decision (with rationale) |
| Hitting an error | `mistakes.md` | Append error + correction |
| Completing a task | `today.md` + others | Mark `[x]`, update working context, log session |
| User adds a new task | `today.md` | Add to task list |
| End of session | `daily/YYYY-MM-DD.md` | Append summary + completed tasks |

---

## Manual Vault Setup (If Needed)

If for some reason the automatic Nix setup doesn't run, you can seed the vault manually:

```bash
mkdir -p ~/Vault/Agent-Shared/projects
mkdir -p ~/Vault/Agent-Hermes/daily

# Create the files with the templates shown above
touch ~/Vault/Agent-Shared/{today,project-state,decisions-log,user-profile}.md
touch ~/Vault/Agent-Hermes/{working-context,mistakes}.md

# Set permissions
chmod -R u+rw,g-rwx,o-rwx ~/Vault
```

---

## Obsidian Setup

1. Launch Obsidian
2. Click "Open folder as vault"
3. Select `~/Vault`
4. (Optional) Install the Obsidian Templater plugin for faster file creation

Now you can browse your vault directly in Obsidian while Hermes reads/writes the same files.

---

## SOUL.md vs AGENTS.md

### SOUL.md (Durable Personality)

**Location:** `~/.hermes/SOUL.md` (managed by Nix)

**Purpose:** Hermes' core personality and communication style.

**Content examples:**
- Tone: pragmatic, direct
- Style: concise, terminal-friendly
- Behavior: memory-driven, never guess

**Scope:** Stable across all projects and conversations.

**Read frequency:** Once per startup.

**Edit:** Rarely. Only when you want to change who Hermes fundamentally is.

### AGENTS.md (Project Instructions)

**Location:** Stored in Hermes documents; lives at `~/.hermes/documents/AGENTS.md` (managed by Nix)

**Purpose:** Operational guidelines and project-specific context.

**Content examples:**
- Vault structure and layer rules
- Read rules and write rules
- Boot sequence
- Task format specification
- Project context template

**Scope:** Specific to how you use Hermes + vault in this setup.

**Read frequency:** Boot sequence, then referenced as needed.

**Edit:** When operational procedures change (rarely).

---

## Troubleshooting

**Vault files not created on rebuild?**
→ Check that you've imported the hermesAgent NixOS module in your host configuration.

**Hermes can't read the vault?**
→ Verify permissions: `ls -la ~/Vault/Agent-Shared/`
→ Make sure the vault directory path is correct in your Nix config.

**Obsidian shows stale data?**
→ Obsidian caches. Close and reopen the vault if you see stale content.

**Layer separation error?**
→ Check `mistakes.md` for the specific error.
→ Common issue: trying to write tasks to `user-profile.md`. Use `today.md` instead.

**Hermes forgot something mid-session?**
→ Say "re-boot" or "refresh context". Hermes will re-read all boot files.

---

## Key Principles

1. **The vault is the brain.** Everything important lives in files.
2. **Layers are sacred.** Layer 1 = invariant facts. Layer 2-3 = session work and history.
3. **Append-only is immutable.** Once written to decisions-log, mistakes, or daily logs, entries never change.
4. **Read before acting.** Hermes never guesses; it always checks the vault first.
5. **No context window = no memory.** Files survive model changes, context resets, and session breaks.

---

## Design Notes

This system is built on one core principle: **the vault is the agent's brain, not the language model's context window.**

Why? Because:
- Context windows reset between sessions
- Models can be swapped without losing state
- Multiple agents can share state via the same vault
- You can audit everything by reading markdown files
- The agent degrades gracefully — if it loses context, it boots from files and recovers

The result is a system that is:
- **Reliable:** No silent failures or forgotten state
- **Debuggable:** Everything is readable markdown
- **Portable:** Works across different models and interfaces
- **Auditable:** Complete record of decisions and actions
