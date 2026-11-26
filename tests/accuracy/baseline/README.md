<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# Scorer baselines

One committed measurement per gate alias and effort, produced by
`../bcs-accuracy-score.sh` over the labelled corpus in `tests/fixtures/`.
A change to the checker prompt, the standard, or the default effort is judged
against these numbers, not against memory.

| File | What it is |
|------|------------|
| `<alias>_<effort>.json` | Aggregate precision / recall / F1, clean false positives, stability, per-rule recall and per-rule false positives, plus the `bcs` version, model, effort and run count |
| `<alias>_<effort>.tsv` | Per (fixture, rule) hit-rate over the repetitions |

## Status

| Alias / effort | Backend | State |
|----------------|---------|-------|
| `gpt5-mini` / `medium` | OpenAI | ✓ measured 2026-09-18, `bcs` 2.0.2, 41 fixtures × 3 runs, model `gpt-5-mini` |
| `flash` / `medium` | Google | ✗ not run. The key's free tier allows 20 requests per model per day; one pass of the corpus needs 41 and a baseline needs 123 |
| `haiku` / `medium` | Anthropic | ✓ measured 2026-09-18, `bcs` 2.0.2, 41 fixtures × 3 runs, model `claude-haiku-4-5` |
| `sonnet` / `medium` | Anthropic | ✓ measured 2026-09-18, `bcs` 2.0.2, 41 fixtures × 3 runs, model `claude-sonnet-5`. 122 of 123 scored; 1 inconclusive |
| `sonnet` / **`high`** | Anthropic | ✓ **refreshed 2026-09-19 for 2.0.8**, 43 fixtures × 3 runs, model `claude-sonnet-5`. 125 of 129 scored; 4 inconclusive. **The default configuration on the dev box** (production has no `/etc/bcs.conf`, so it runs `-e medium`). The JSON records `bcs_version` 2.0.7 because the run finished minutes before the version string was bumped; the code measured is the 2.0.8 content |
| `qwen-small` / `medium` | Ollama | ✗ not run. No Ollama runs were made; note that the `num_ctx` fix in 2.0.2 has itself not been exercised against a live server |

Each JSON carries both `model` (the alias as typed) and `model_id` (the
canonical ID the checks actually ran against, read back from the checker's own
JSON envelope). Compare on `model_id`: an alias is not portable. On the
measuring host `/etc/bcs.conf` mapped `sonnet` to `claude-sonnet-5` while
`bcs`'s built-in map said `claude-sonnet-4-6` (the built-in has been
`claude-sonnet-5-5` since 2.0.11), so a baseline recording only `sonnet` could
be refreshed elsewhere against a different model under the same filename.

The JSON also carries `models`, every model id the checks ran on with its count,
because `bcs` re-reads the alias on every call: on 2026-11-26 an alias edited
mid-run split a 129-check baseline across `claude-sonnet-5` and
`claude-sonnet-5-5` while `model_id` named the first. More than one model now
labels the report `mixed` and fails the run (the reports are still written).
Measure with a canonical id (`-m claude-sonnet-5-5`, the measuring model since
2026-11-26), which no alias can redirect.

The earlier `gpt5-mini` / `low` baseline (recall 1.000, clean FP 0, stability
1.000) has been deleted rather than kept for comparison. It was measured while
`bcs check` still sent each fixture's `bcs-fixture-expect:` header to the
model, so it recorded how well the checker reads an answer it was given. The
same configuration blind scored recall 0.546 and 51 clean false positives.
Numbers taken before 2026-09-18 are not comparable with these.

## What the 2.0.8 refresh moved

Same model, same effort, same scorer; the corpus grew from 41 fixtures to 43
and was repaired throughout.

| Metric | 2.0.4 baseline | 2.0.8 baseline |
|--------|---------------:|---------------:|
| Recall | 0.971 | 0.973 |
| Precision | 0.459 | **0.893** |
| F1 | 0.624 | 0.931 |
| Stability | 0.943 | 0.946 |
| Spurious findings per clean run | 1.533 (23 in 15) | **0.000 (0 in 14)** |

Recall barely moved, which is the point: the repairs were not meant to make
the checker find more, but to stop the corpus charging it for findings that
were **correct**. Thirteen fixtures carried a second real defect beside the
planted one, and two more rule pairs let one defect be cited under either of
two codes. Precision nearly doubling, and the clean corpus going from 23
spurious findings to none, is that accounting error being removed -- not the
checker improving.

Read recall as the checker's signal and the clean-fixture rate as its noise.
Precision on violation fixtures still mixes in genuine secondary findings, so
it remains the weakest of the three numbers even now.

## Effort: `medium` against `high` on the default model

| | recall | precision | F1 | clean FP | stability | wall |
|---|---:|---:|---:|---:|---:|---:|
| `sonnet -e medium` | 0.924 | 0.548 | 0.688 | 17 / 17 | 0.943 | ~35 min |
| `sonnet -e high` | **0.971** | 0.459 | 0.624 | 23 / 15 | 0.943 | ~117 min |

`high` is the default from 2026-09-19 (`BCS_EFFORT` in `/etc/bcs.conf`). The
gain is not run-to-run noise: stability is identical at 0.943, no rule
regressed, and the improvement traces to four named rules — BCS0110 and
BCS1005 rose from 0.667 to 1.000, BCS1104 from 0.000 to 0.667, BCS0106 from
0.000 to 0.333. BCS1104 had been 0-of-9 across all three `-e medium`
baselines and was suspected of being a corpus defect; it is an effort effect.
BCS0106 stays capped near zero for a mechanical reason — the checker never
sees the script's real filename.

The cost is 3.3× the wall time and roughly half again the noise on compliant
files. The choice follows this project's stated priority: recall over
precision, because a false positive costs a glance and a missed core
violation ships. Re-argue it on measurement, not preference.

The three `medium` baselines carry no `fp_per_rule` map: the scorer counted false
positives without recording which codes they were until `bcs` 2.0.4, so the
committed artefacts cannot say *why* the corpus repairs cut Anthropic false
positives by roughly three quarters and left OpenAI's alone. `sonnet_high` is the first that answers it; those three cannot be made to.

## Refreshing a baseline

```bash
./tests/accuracy/bcs-accuracy-score.sh -m gpt5-mini -e medium -n 3 -o /tmp/score
jq . /tmp/score/accuracy-gpt5-mini-medium.json > tests/accuracy/baseline/gpt5-mini_medium.json
cp /tmp/score/accuracy-gpt5-mini-medium.tsv tests/accuracy/baseline/gpt5-mini_medium.tsv
```

Every check the scorer makes passes `--no-cache`, so each repetition is a fresh
LLM round-trip. Refresh only on purpose, in a commit of its own, and say in the
message what changed and why the new numbers are acceptable.

## Comparing a run against a baseline

```bash
jq -n --slurpfile b tests/accuracy/baseline/gpt5-mini_medium.json \
      --slurpfile r /tmp/score/accuracy-gpt5-mini-medium.json '
  ["recall", "f1", "precision", "clean_fp_rate", "stability"] | map(
    {metric: ., baseline: $b[0][.], run: $r[0][.], delta: ($r[0][.] - $b[0][.])})'
```

Recall and the clean false-positive rate are the trustworthy signals. The
checker is an LLM, so expect run-to-run movement: treat ±0.05 in precision or
F1 as noise. A fall in recall is a regression to explain.

Aggregate precision (0.770 `haiku`, 0.566 `gpt5-mini`, 0.548 `sonnet`)
understates the checker: every *extra* finding on a violation fixture counts as
a false positive, and many are genuine secondary issues the fixture did not
plant. Read it as a verbosity signal, not as accuracy.

The clean false-positive rate is the honest measure of noise, because a clean
fixture has no true finding to report: **1** finding in 18 runs for `haiku`, 5
in 18 for `gpt5-mini`, **17 in 17** for `sonnet`. The three lie on a
recall/noise curve -- `sonnet` has the best recall (0.924) and by far the most
noise, `haiku` the least of both.

Because `sonnet` is `bcs check`'s default model, that last figure is the one to
know: about one spurious finding per compliant file, 17x `haiku`'s rate. Prefer
a cheaper alias for anything that blocks a commit.

All three were retaken on 2026-09-18 after two corpus defects were fixed: the
pragma blinding emptied each `bcs-fixture-*` line instead of substituting a
bare `#`, wedging two consecutive blank lines into every fixture and provoking
a correct BCS1203 finding about a defect no fixture contains; and clean fixture
06 carried a bare `#shellcheck disable=SC2015` with no reason, a real BCS1206
violation the scorer was counting against the checker. **Nothing measured
before 2026-09-18 is comparable with these.** Baselines taken before the labels
moved to `tests/fixtures/EXPECT.tsv` (2026-09-19, bcs 2.0.8) also showed the
model two extra header lines per fixture, the blinded pragmas as bare `#`
comments, which drew BCS1202 now and then; line numbers in their findings are
two higher than in the files as they now stand. See
[`../LLM-ACCURACY.md`](../LLM-ACCURACY.md) for what the fixes changed.

See [`../LLM-ACCURACY.md`](../LLM-ACCURACY.md) for the per-rule comparison, and
for why a rule that a cheap model misses is not thereby a bad rule.
