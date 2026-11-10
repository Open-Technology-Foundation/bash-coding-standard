# AI Agents, Commands, and Rules for BCS

A bundled package of agents, slash-commands, and rule snapshots for Bash programmers working with the **Bash Coding Standard (BCS)**. Drop these into `~/.claude/`, `~/.codex/`, or `~/.config/opencode/` to give any AI sessions BCS-aware bash tooling.

**Version:** 1.0.0
**Last updated:** 2026-04-13
**Parent standard:** [BASH-CODING-STANDARD.md](../data/BASH-CODING-STANDARD.md)

## Purpose

The BCS repo ships 105 rules across 12 sections governing Bash 5.2+ script authorship. This `ai-agents/` package extends the standard with AI tooling -- agents and commands that understand BCS, plus a snapshot of the rule files needed for them to operate correctly. Together they turn BCS from a document into an enforceable workflow.

## Installation

From the BCS repo root, copy into the AI tool of your choice:

```bash
# Claude Code
cp -r ai-agents/agents/*   ~/.claude/agents/
cp -r ai-agents/commands/* ~/.claude/commands/
cp -r ai-agents/rules/*    ~/.claude/rules/

# opencode (sst)
cp -r ai-agents/agents/*   ~/.config/opencode/agents/
cp -r ai-agents/commands/* ~/.config/opencode/commands/
# opencode has no rules/ subdir; treat ai-agents/rules/ as reference docs

# codex (OpenAI)
# Codex's agent/command subdir conventions are not yet documented publicly.
# Use ai-agents/AGENTS.md as a project-context file alongside
# ~/.codex/config.toml; consult https://github.com/openai/codex for updates.
```

Or symlink the whole tree into Claude Code if you want updates to track the repo:

```bash
ln -s "$PWD"/ai-agents/agents/*   ~/.claude/agents/
ln -s "$PWD"/ai-agents/commands/* ~/.claude/commands/
ln -s "$PWD"/ai-agents/rules/*    ~/.claude/rules/
```

## Agents Index

- `bash-expert.md` -- Bash script analysis, optimization, and BCS-compliant development
- `documentation-writer.md` -- Generate comprehensive documentation for code, projects, or systems
- `script-scaffolder.md` -- Scaffold new BCS-compliant scripts via `bcs template`
- `shellcheck-fixer.md` -- Fix SC#### warnings using BCS-compliant remediation patterns

## Commands Index

- `audit-bash.md` -- `/audit-bash` -- BCS compliance auditing for Bash codebases
- `bcs-codes.md` -- `/bcs-codes` -- List BCS rule codes, optionally filtered by section or keyword
- `fix-shellcheck.md` -- `/fix-shellcheck` -- Fix SC#### warnings per BCS remediation patterns
- `purpose-functionality-usage.md` -- `/pfu` -- Determine purpose and usage of a script or codebase
- `scaffold.md` -- `/scaffold` -- Scaffold a new BCS-compliant script via `bcs template`
- `update-docs.md` -- `/update-docs` -- Update external documentation files
- `update-internal-docs.md` -- `/update-internal-docs` -- Update script internal comments, help, messages

## Rules Index

- `bash-coding-standard.md` -- BCS pointer and location search order
- `coding-principles.md` -- KISS philosophy
- `documentation.md` -- README policy and icon standards
- `environment.md` -- Target platform (Ubuntu 24.04+, Bash 5.2+)
- `git-commits.md` -- Git authorship and conventional-commit guidance
- `security.md` -- Critical security policies

## See Also

- [BASH-CODING-STANDARD.md](../data/BASH-CODING-STANDARD.md) -- the standard itself
- [bcscheck](../bcscheck) -- AI-powered BCS compliance checker
- [Claude Code documentation](https://docs.claude.com/en/docs/claude-code/)
- [Claude Code](https://claude.ai/code)
