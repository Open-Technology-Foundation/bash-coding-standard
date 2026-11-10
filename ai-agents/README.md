# AI Tooling for the Bash Coding Standard

**Agents, slash commands, and rule snapshots that turn BCS into an AI-assisted workflow**

**Version:** 1.0.0
**Last updated:** 2026-04-13

## What This Is

`ai-agents/` is the enforcement layer for the [Bash Coding Standard](../data/BASH-CODING-STANDARD.md). It bundles conversational agents, slash-command macros, and policy rule snapshots that drop into Claude Code, opencode, or codex so any AI session you run becomes BCS-aware.

This README is the narrative introduction. For the flat machine-readable file index -- every agent, every command, every rule listed by name -- see [AGENTS.md](AGENTS.md). The two files are complementary: AGENTS.md tells you *what* is in the package; this README tells you *why* it exists and *how* to use it.

## Why It Exists

BCS is 98 enforceable rules (plus 12 section overviews -- 110 codes total) of static text. Reading the standard does not enforce it, and neither does quoting it at an AI. Two existing tools close that gap:

- `bcscheck` -- the on-demand AI compliance checker that scores a script against the full standard.
- `ai-agents/` -- the package in this directory, which wires BCS knowledge directly into everyday AI sessions so enforcement happens *while you write*, not only at check time.

The enforcement chain:

```
BCS document  →  bcscheck binary  →  ai-agents/ package  →  your AI session
   (rules)        (on-demand audit)    (always-on context)    (writes the code)
```

## Three Component Types

The package separates artifacts by semantics, not by topic. Each type has a different role and a different frontmatter schema.

### Agents (`agents/`)

Conversational personas loaded on demand. Agents are discursive -- they hold state across a multi-turn exchange, can call any tool the parent session allows, and behave like a specialist you hand off a task to. Frontmatter schema:

```yaml
---
name: shellcheck-fixer
description: |
  One-paragraph trigger description with example user prompts...
color: cyan
---
```

### Commands (`commands/`)

Slash-prefixed one-shot macros. Commands are narrow, sandboxed, and executed immediately -- not a conversation. Unlike agents, they declare an `allowed-tools` whitelist so the harness enforces the sandbox even if the macro tries to reach wider. Frontmatter schema:

```yaml
---
description: One-line summary shown in the slash menu
argument-hint: <file>
allowed-tools: ["Bash", "Read"]
---
```

Commands use `$ARGUMENTS` to receive user input and return a single structured response.

### Rules (`rules/`)

Plain markdown snapshots of policy documents -- BCS location search order, KISS principles, git commit authorship, security policy, documentation conventions, target environment. No frontmatter. The AI tool loads these as always-on context so every session starts with the same guardrails.

## Worked Example: The BCS Workflow

End-to-end flow for "write a new deployment script":

```bash
# 1. Scaffold a BCS-compliant skeleton
/scaffold basic deploy "Sync BCS repo to production servers"

# 2. Open the generated deploy file and fill in main() with your rsync/ssh logic.
#    The scaffold already has strict mode, metadata, and the 13-step skeleton.

# 3. Check it against the standard, in-session (the bcscheck skill)
bcscheck deploy

# 4. If shellcheck warnings surface, hand them to the dedicated fixer
/fix-shellcheck deploy

# 5. Re-check, then commit
bcscheck deploy
```

The slash commands delegate to `bcs template` and `shellcheck` under the hood, and the `bcscheck` skill reads the standard itself -- you stay in the AI session, the tooling stays honest, and the BCS rules travel with every step.

## Installation

From the BCS repo root, install into whichever AI tool you use:

```bash
# Claude Code
cp -r ai-agents/agents/*   ~/.claude/agents/
cp -r ai-agents/commands/* ~/.claude/commands/
cp -r ai-agents/rules/*    ~/.claude/rules/

# opencode (sst) -- no rules/ subdir; treat ai-agents/rules/ as reference
cp -r ai-agents/agents/*   ~/.config/opencode/agents/
cp -r ai-agents/commands/* ~/.config/opencode/commands/

# codex (OpenAI) -- use ai-agents/AGENTS.md as project-context file
```

For the full per-tool matrix, the symlink alternative (updates track the repo), and codex caveats, see [AGENTS.md](AGENTS.md#installation).

## Inventory

Filenames and one-line descriptions for every agent, command, and rule live in [AGENTS.md](AGENTS.md). That file is the canonical index; this README intentionally does not duplicate it.

## Extending the Package

### Adding a New Agent

1. Create `agents/<name>.md` with the frontmatter skeleton:
   ```yaml
   ---
   name: <name>
   description: |
     One paragraph on when to use this agent. Include 2-3
     <example>...</example> blocks showing user prompts and the
     assistant's trigger response.
   color: cyan
   ---
   ```
2. Keep `<name>` lowercase-kebab-case; it must match the filename.
3. Body: a system prompt in the second person ("You are a ...") with clear procedure, rules, and escalation hints.
4. Add a one-line entry to [AGENTS.md](AGENTS.md) under `## Agents Index`.

### Adding a New Command

1. Create `commands/<name>.md` with:
   ```yaml
   ---
   description: One-line summary
   argument-hint: <type> <name> [description]
   allowed-tools: ["Bash", "Read", "Edit"]
   ---
   ```
2. Use `$ARGUMENTS` in the body to reference user input. If a required argument is missing, ask the user -- never guess.
3. Keep `allowed-tools` as tight as possible. A read-only reporter needs `["Bash", "Read"]`, not the full toolset.
4. Add a one-line entry to [AGENTS.md](AGENTS.md) under `## Commands Index`.

### Adding a New Rule

1. Create `rules/<topic>.md` as plain markdown -- no frontmatter.
2. Keep the rule file a snapshot of a single policy concern. Do not mix topics.
3. Add a one-line entry to [AGENTS.md](AGENTS.md) under `## Rules Index`.

### Load-Bearing Convention

Every BCS-touching agent and command **must**:

- Call `bcscheck`, never `bcs check` directly. The shim reads `~/.config/bcs/bcs.conf` so the user's configured defaults win.
- Never hard-code `-m`, `-e`, or `-s`. Defer to config. Override only when the user explicitly asks for a different model, effort, or strict mode in the same turn.
- Preserve the BCS code on every reported finding so the user can look it up in `BASH-CODING-STANDARD.md`.

Hard-coded model names in these files silently break every user who has configured their own defaults. Don't do it.

## See Also

- [../README.md](../README.md) -- top-level BCS project README
- [../data/BASH-CODING-STANDARD.md](../data/BASH-CODING-STANDARD.md) -- the standard itself (98 enforceable rules + 12 section overviews across 12 sections)
- [../bcscheck](../bcscheck) -- the AI-powered compliance checker these tools shell out to
- [AGENTS.md](AGENTS.md) -- flat machine-readable inventory of every file in this package
