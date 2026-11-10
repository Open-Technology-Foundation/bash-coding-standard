<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
# Continuous Integration & Local Hooks

How to gate code on BCS in CI and at commit/push time. Two layers:

1. **Fast, free, deterministic** — `shellcheck` + the BCS test suite. Runs on
   every push/PR with no API keys.
2. **Slow, paid, probabilistic** — `bcs check` (the LLM grader). Run it
   deliberately: at pre-push locally, or as a manual CI job.

> ◉ The flagship `bcs check` is an LLM and is non-deterministic. Treat it as a
> reviewer, not a unit test. The repo ships an accuracy scorer
> (`tests/accuracy/bcs-accuracy-score.sh`) precisely so you can measure its
> precision/recall before trusting it as a gate.

## GitHub Actions

### `ci.yml` — push / PR (no secrets)

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs on `ubuntu-24.04`
(Bash 5.2) and:

- installs `shellcheck` + `jq`;
- `shellcheck -x` over `bcs`, the shims, every test, every fixture, and the
  accuracy scripts;
- runs `./tests/test-self-compliance.sh` (the "bcs obeys its own standard" invariant);
- runs `make test-fast` (`BCS_SKIP_FIXTURES=1 ./tests/run-all-tests.sh`).

It sets `BCS_SKIP_FIXTURES=1`, so the one LLM-dependent suite
(`test-check-fixtures.sh`) skips cleanly — **no API keys, no cost, no flakiness**.
A fork with zero secrets goes green.

### `accuracy.yml` — manual, secret-gated

[`.github/workflows/accuracy.yml`](../.github/workflows/accuracy.yml) is
`workflow_dispatch` only. Add one of `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or
`GOOGLE_API_KEY` to the repo secrets, then dispatch it (optionally choosing
model/effort/runs). It runs the scorer over the labelled corpus and uploads the
`accuracy-*.tsv` / `accuracy-*.md` reports as build artifacts. With no backend
secret it fails fast (it is `BCS_FIXTURES_REQUIRE_BACKEND=1`), telling you the
dispatch was misconfigured.

## Local pre-commit hooks

[pre-commit](https://pre-commit.com) wiring. Pair a **fast** shellcheck hook at
the commit stage with the **slow** `bcs check` hook at the push stage.

`.pre-commit-config.yaml` in your project:

```yaml
repos:
  # Fast, deterministic — runs on every commit.
  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.10.0
    hooks:
      - id: shellcheck
        args: [-x]

  # Slow, LLM-graded — runs only on push.
  - repo: https://github.com/Open-Technology-Foundation/bash-coding-standard
    rev: v2.0.9   # pin a tag
    hooks:
      - id: bcs-check        # bcs check --strict --tier core, per changed shell file
        # args: [--model, haiku]   # uncomment to pin a cheap model
```

Install both stages:

```bash
pip install pre-commit          # or: pipx install pre-commit
pre-commit install                              # commit-stage hooks (shellcheck)
pre-commit install --hook-type pre-push         # push-stage hook (bcs-check)
```

Now `shellcheck` runs on each commit, and the BCS LLM gate runs once per push
over the shell files you changed. Requires `bcs` on `PATH` (`sudo make install`)
and a configured backend (`~/.config/bcs/bcs.conf`).

## Backend cost & latency

`bcs check` latency and price depend on backend, model alias, effort, and file
size. Rough per-file figures at `-e low` (your mileage will vary; the default
`-e medium` is roughly 3x these):

| Backend | Cheapest alias | Per-file latency | Cost | Notes |
|---------|----------------|------------------|------|-------|
| Google | `flash-lite` | ~5–10s | very low / free tier | Free tier rate-limits bursts |
| Anthropic | `haiku` | ~5–15s | low | Reliable; needs `ANTHROPIC_API_KEY` |
| OpenAI | `gpt5-mini` | ~10–20s | low | Needs `OPENAI_API_KEY` |
| Ollama | `qwen-small` | ~5–30s | free (local compute) | Quality varies by local model |
| Claude Code CLI | `claude-code:haiku` | ~15–25s | per your Claude plan | No API key; needs `claude` on PATH |

Measured on the labelled corpus (17-90 line scripts) at the default
`-e medium`, 2026-09-18, averaged over 123-check baselines: `gpt5-mini` about
12 s per check, `sonnet` (`claude-sonnet-5`) about 17 s, `haiku`
(`claude-haiku-4-5`) about 26 s. The ordering is not a typo: the small model is
the slow one here. The two take different thinking shapes -- `sonnet-5` gets
`thinking: adaptive`, `haiku-4-5` gets a fixed `budget_tokens` of 2000 from the
effort scale -- which is the likely cause but has not been isolated. The
Anthropic backend sends the standard with `cache_control: ephemeral`, so after
the first call of a session the system prompt is billed as a cache read rather
than fresh input.

Effort scales latency and cost up sharply: `-e high`/`xhigh`/`max` and larger
models (`sonnet`, `opus`, `gpt5`, `pro`) can take **30–600s** per file. For a
pre-push gate, use the cheapest alias with `--tier core` at the default
`-e medium`, so only correctness-critical rules block the push.

▲ Pick the alias on the clean false-positive rate, not on recall. Measured
2026-09-18 over six compliant fixtures, three runs each: `haiku` 1 spurious
finding in 18 runs, `gpt5-mini` 5 in 18, `sonnet` 17 in 17. `sonnet` is the
default model and the noisiest by a wide margin -- excellent for a review a
human reads, wrong for a hook that blocks a push.

▲ Do not gate on `-e low`. It runs with no thinking budget, so the model prints
findings it has not reasoned through. Measured on `gpt5-mini`, 2026-09-17, this
exact recipe (`--strict --tier core`) blocked the push on a *compliant*
243-line script in 5 of 5 runs at `-e low` (3.7 s each) and in 0 of 5 at
`-e medium` (17.2 s each).

That was first explained as a length effect -- short scripts being safe -- but
the explanation was wrong. The fixture gate passed at `-e low` only because
every fixture still named its own expected rule in a header comment that
reached the model. With that leak closed (2026-09-18), `-e low` recalls 0.546
of the planted rules against 0.794 at `-e medium`, and raises 51 spurious
findings on the compliant corpus against 10. The gate now runs at the default
effort like everything else.

Those header comments are gone entirely as of 2026-09-19: the labels live in
`tests/fixtures/EXPECT.tsv` and `bcs check` sends the script exactly as it is
on disk. Nothing has to be hidden, and the two blanked comment lines the
blinding used to leave behind -- which drew style findings of their own --
went with them.

## Quantify before you trust

Before relying on `bcs check` as a hard gate, measure it on your chosen backend.
The labelled corpus holds short scripts (17–90 lines), so also run the gate's
own command a few times on a real, compliant script of yours and count the
false exit 1s: the corpus cannot show you that failure mode.

```bash
./tests/accuracy/bcs-accuracy-score.sh -m haiku -e medium -n 3
```

Read recall (planted-violation detection) and the clean-fixture false-positive
rate from the generated `accuracy-haiku-medium.md`. See
[`tests/accuracy/README.md`](../tests/accuracy/README.md).

#fin
