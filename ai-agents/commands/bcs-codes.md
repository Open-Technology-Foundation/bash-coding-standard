---
description: List BCS rule codes with titles, optionally filtered by section number or keyword
argument-hint: "[section-number | keyword]"
allowed-tools: ["Bash", "Grep"]
---

# BCS Codes Listing

List all BCS (Bash Coding Standard) rule codes.

## Behaviour

**No arguments:** List every BCS code and title.
```bash
bcs codes
```

**Numeric argument** (e.g. `/bcs-codes 5`): Filter to codes from that section. Sections
are numbered 01-12 and are zero-padded in BCS codes, so section 5 becomes prefix `BCS05`.
```bash
bcs codes | grep -E '^BCS0?5'
```

**Keyword argument** (e.g. `/bcs-codes shellcheck`): Case-insensitive substring match
against titles.
```bash
bcs codes | grep -i "$ARGUMENTS"
```

## Output Format

```
BCS#### <Title>
BCS#### <Title>
...

Total: <count> codes (filtered from <authoritative-total>)
```

## Rules

- The authoritative total is whatever `bcs codes | wc -l` reports. Never hard-code the
  count in your response -- always derive it from the command.
- Each code is backed by a section file under `data/NN-section.md`. If the user wants the
  full rule text, point them at:
  ```bash
  bcs display <section-number>
  ```
- If the filter returns zero matches, say so explicitly and suggest alternatives (e.g.
  "no codes match `fooo`; did you mean `foo`?").

## Out of Scope

- Interpreting rules for the user -- that is the job of `/audit-bash` and the `bcscheck` skill.
- Writing code -- this command is listing-only.
