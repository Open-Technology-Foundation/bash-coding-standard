#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# bcs-accuracy-score.sh - Score `bcs check` against the labelled fixture corpus.
#
# Turns the accuracy *collector* (bcs-check-accuracy.sh, which only dumps model
# output) into a *scorer*: it parses `bcs check -j` findings against each
# fixture's entry in tests/fixtures/EXPECT.tsv to compute precision / recall / F1
# (aggregate and per-rule), and re-runs every fixture N times to report a
# run-to-run stability score -- quantifying the LLM checker's non-determinism.
#
# Corpus (relative to repo root):
#   tests/fixtures/*.sh              violation fixtures (one core rule each)
#   tests/fixtures/probabilistic/*.sh  scored, not gated (recommended-tier, or core rules cheap models miss)
#   tests/fixtures/clean/*.sh        compliant scripts -- ANY finding is a FP
#
# Scoring (per fixture, per run, against the manifest's expected code set):
#   TP = reported codes that were expected
#   FP = reported codes that were NOT expected  (all findings on clean fixtures)
#   FN = expected codes that were NOT reported
# Precision = TP/(TP+FP)   Recall = TP/(TP+FN)   F1 = 2PR/(P+R)
#
# NOTE: on violation fixtures, "FP" includes *extra* findings that may well be
# real secondary issues -- so read precision off the clean fixtures, which have
# no true findings. Recall is the trustworthy signal on violation fixtures.
#
# Environment / flags:
#   -m MODEL  / BCS_SCORE_MODEL    pin model alias (skips backend sniff)
#   -e EFFORT / BCS_SCORE_EFFORT   effort level (default: low)
#   -n RUNS   / BCS_SCORE_RUNS     repetitions per fixture (default: 3)
#   -o DIR    / BCS_SCORE_OUTDIR   report output dir (default: this script's dir)
#   BCS_FIXTURES_REQUIRE_BACKEND=1 fail instead of skip when no backend reachable
#   BCS_SCORE_CMD                  checker to run instead of ../../bcs (test seam)
#   trailing args = explicit fixture paths to score (default: whole corpus)
set -euo pipefail
shopt -s inherit_errexit shift_verbose extglob nullglob

# ~/.local/bin first: the Claude CLI backend is probed with `command -v claude`.
declare -rx PATH="$HOME"/.local/bin:/usr/local/bin:/usr/bin:/bin

declare -- SCRIPT_PATH
SCRIPT_PATH=$(realpath -- "$0")
declare -r SCRIPT_PATH
declare -r SCRIPT_DIR=${SCRIPT_PATH%/*}
declare -r SCRIPT_NAME=${SCRIPT_PATH##*/}
declare -r VERSION='1.0.0'

declare -- PROJECT_DIR
PROJECT_DIR=$(realpath -- "$SCRIPT_DIR/../..")
declare -r PROJECT_DIR
declare -r BCS_CMD=${BCS_SCORE_CMD:-"$PROJECT_DIR"/bcs}
declare -r FIXTURES_DIR="$PROJECT_DIR"/tests/fixtures
declare -r MANIFEST="$FIXTURES_DIR"/EXPECT.tsv

# Tunables (env defaults; CLI flags override).
declare -- MODEL=${BCS_SCORE_MODEL:-}
declare -- EFFORT=${BCS_SCORE_EFFORT:-low}
# Validated, never assigned straight into `declare -i`: an integer assignment
# evaluates its value as arithmetic, so an unchecked `BASH_VERSINFO[$(cmd)]`
# would run cmd. _int NAME VALUE validates, then assigns.
declare -i RUNS=3
declare -- OUT_DIR=${BCS_SCORE_OUTDIR:-$SCRIPT_DIR}
declare -i TIMEOUT_S=150
declare -i REQUIRE_BACKEND=0

# Colors (stderr is the message channel).
if [[ -t 2 ]]; then
  declare -r RED=$'\033[0;31m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m'
  declare -r CYAN=$'\033[0;36m' BOLD=$'\033[1m' NC=$'\033[0m'
else
  declare -r RED='' GREEN='' YELLOW='' CYAN='' BOLD='' NC=''
fi

# ---- messaging (BCS standard) ----
_msg() {
  local -- kind=${FUNCNAME[1]} color='' icon=''
  case $kind in
    info)    color=$CYAN;   icon='◉' ;;
    success) color=$GREEN;  icon='✓' ;;
    warn)    color=$YELLOW; icon='▲' ;;
    error)   color=$RED;    icon='✗' ;;
    *)       ;;                     # unknown caller: plain, uncoloured
  esac
  printf '%s%s%s %s\n' "$color" "$icon" "$NC" "$*" >&2
}
info()    { _msg "$@"; }
success() { _msg "$@"; }
warn()    { _msg "$@"; }
error()   { _msg "$@"; }
die() {
  local -i rc=$1; shift
  [[ -n $* ]] && error "$*" ||:
  exit "$rc"
}
# _int NAME VALUE -- validate, then assign. Never let an unvalidated value
# reach a `declare -i` variable: the shell evaluates an integer assignment as
# arithmetic, so `BASH_VERSINFO[$(cmd)]` would run cmd.
_int() {
  [[ $2 =~ ^[0-9]+$ ]] || die 22 "$1 must be a whole number, got ${2@Q}"
  printf -v "$1" '%s' "$2"
}

noarg() {
  (($# > 1)) || die 22 "Option ${1@Q} requires an argument"
  [[ ${2:0:1} != '-' ]] || die 22 "Option ${1@Q} requires an argument"
}

# ---- helpers ----
# Clean, sorted, unique BCS codes from a whitespace/newline blob.
_codes() { printf '%s\n' "$1" | grep -oE 'BCS[0-9]{4}' | sort -u || true; }
# True if newline-list $1 contains code $2.
_has() { [[ $'\n'"$1"$'\n' == *$'\n'"$2"$'\n'* ]]; }
# Filesystem-safe slug for a model name.
_slug() { local -- s=$1; s=${s//\//_}; s=${s//:/_}; printf '%s' "$s"; }

# Mirror test-check-fixtures.sh probe order, fastest first:
# openai → google → anthropic → ollama → claude (CLI).
probe_backend() {
  [[ -n ${OPENAI_API_KEY:-} ]] && { echo openai; return 0; } ||:
  [[ -n ${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}} ]] && { echo google; return 0; } ||:
  [[ -n ${ANTHROPIC_API_KEY:-} ]] && { echo anthropic; return 0; } ||:
  local -- host=${OLLAMA_HOST:-localhost:11434}
  curl -sf --connect-timeout 2 --max-time 5 "http://$host/api/tags" &>/dev/null \
    && { echo ollama; return 0; } ||:
  command -v claude &>/dev/null && { echo claude; return 0; } ||:
  return 1
}
# Cheapest model alias for a probed backend.
pick_model() {
  case $1 in
    claude)    echo claude-code:haiku ;;
    ollama)    echo "${BCS_FIXTURES_MODEL:-qwen-small}" ;;
    openai)    echo gpt5-mini ;;
    google)    echo flash-lite ;;
    anthropic) echo haiku ;;
    *)         echo haiku ;;
  esac
}

# ---- scoring state (global: populated by main(), read by _emit_reports()) ----
declare -i TP=0 FP=0 FN=0 INCONCLUSIVE=0 SCORED=0 CLEAN_FP=0 CLEAN_RUNS=0
# The canonical model the checks actually ran against, read back from the first
# successful check's JSON envelope. MODEL holds the alias as typed, and an alias
# is not portable: bcs.conf can remap one (MODEL_ALIASES[sonnet]=claude-sonnet-5
# on the measuring host against claude-sonnet-4-6 built in), so a baseline
# recording only the alias cannot be reproduced or compared.
declare -- MODEL_ID=''
# Every check's model, counted. Reading only the first check's was not enough:
# bcs re-reads bcs.conf on every call, so an alias edited mid-run (2026-11-26,
# sonnet moved from claude-sonnet-5 to claude-sonnet-5-5 inside a 129-check
# baseline) splits one report across two models while it names one. More than
# one model labels the report "mixed" and fails the run; pass a canonical id
# with -m to pin it.
declare -A MODEL_RUNS=()
declare -A PAIR_HITS=() PAIR_RUNS=() CODE_HIT=() CODE_TOT=()
# Which codes the checker reported that the fixture did not plant, and how
# often. FP was only ever a count, so a precision change could be seen but
# never explained: the corpus repairs of 2026-09-18 cut Anthropic false
# positives by three quarters and left OpenAI's alone, and no committed
# artefact could say which rules moved. comm already computes the list on the
# way to `wc -l`; these keep it. FP_CLEAN is the same tally restricted to
# clean/, where every report is by definition wrong.
declare -A FP_CODE=() FP_CLEAN=()
# Same tally again, keyed 'CODE|fixture': which file drew the code, not only
# how often. Without it a precision shift names a rule but not the script that
# moved it, and the run has to be repeated to find out.
declare -A FP_WHERE=()

show_help() {
  cat <<HELP
${BOLD}$SCRIPT_NAME$NC v$VERSION - Score bcs check accuracy (precision/recall/F1 + stability)

${BOLD}Usage:$NC $SCRIPT_NAME [OPTIONS] [FIXTURE...]

${BOLD}Options:$NC
  -m, --model MODEL   Model alias/id (default: cheapest reachable backend)
  -e, --effort LEVEL  Effort: min|low|medium|high|xhigh|max (default: low)
  -n, --runs N        Repetitions per fixture for stability (default: 3)
  -o, --output DIR    Report output directory (default: alongside this script)
  -h, --help          Show this help

With no FIXTURE arguments, scores the whole corpus under tests/fixtures/
(violation + probabilistic/ + clean/). Skips gracefully when no LLM backend
is reachable (set BCS_FIXTURES_REQUIRE_BACKEND=1 to fail instead).

${BOLD}Outputs (in --output dir):$NC
  accuracy-<model>-<effort>.tsv   per (fixture,code) hit-rates
  accuracy-<model>-<effort>.md    precision/recall/F1 + stability summary
  accuracy-<model>-<effort>.json  the same numbers, machine-readable (baselines)
HELP
}

main() {
  # Environment overrides, validated (see _int).
  _int RUNS "${BCS_SCORE_RUNS:-$RUNS}"
  _int TIMEOUT_S "${BCS_SCORE_TIMEOUT:-$TIMEOUT_S}"
  _int REQUIRE_BACKEND "${BCS_FIXTURES_REQUIRE_BACKEND:-$REQUIRE_BACKEND}"
  readonly TIMEOUT_S REQUIRE_BACKEND

  local -a rest=()
  while (($#)); do case $1 in
    -m|--model)   noarg "$@"; shift; MODEL=$1 ;;
    -e|--effort)  noarg "$@"; shift; EFFORT=$1 ;;
    -n|--runs)    noarg "$@"; shift; _int RUNS "$1" ;;
    -o|--output)  noarg "$@"; shift; OUT_DIR=$1 ;;
    -h|--help)    show_help; return 0 ;;
    --)           shift; rest+=("$@"); break ;;
    -*)           die 22 "Invalid option ${1@Q}" ;;
    *)            rest+=("$1") ;;
  esac; shift; done
  set -- "${rest[@]}"
  readonly EFFORT RUNS OUT_DIR

  command -v jq &>/dev/null || die 18 'jq is required'
  command -v timeout &>/dev/null || die 18 'timeout (coreutils) is required'
  [[ -x $BCS_CMD ]] || die 3 "bcs CLI not found at ${BCS_CMD@Q}"
  ((RUNS >= 1)) || die 22 "runs must be >= 1 (got $RUNS)"

  # Resolve model: pinned wins; otherwise sniff a reachable backend.
  local -- backend='(pinned)'
  if [[ -z $MODEL ]]; then
    backend=$(probe_backend) ||:
    if [[ -z $backend ]]; then
      ((REQUIRE_BACKEND)) \
        && die 1 'no LLM backend available (BCS_FIXTURES_REQUIRE_BACKEND=1)' ||:
      warn 'no LLM backend reachable — skipping accuracy scoring'
      exit 0
    fi
    MODEL=$(pick_model "$backend")
  fi
  readonly MODEL

  # Build corpus.
  local -a fixtures=()
  if (($#)); then
    fixtures=("$@")
  else
    fixtures=("$FIXTURES_DIR"/*.sh "$FIXTURES_DIR"/probabilistic/*.sh \
              "$FIXTURES_DIR"/clean/*.sh)
  fi
  local -a corpus=()
  local -- f
  for f in "${fixtures[@]}"; do [[ -f $f ]] && corpus+=("$f") ||:; done
  ((${#corpus[@]})) || die 3 'no fixtures found'

  mkdir -p -- "$OUT_DIR" || die 1 "Cannot create ${OUT_DIR@Q}"
  info "model=$MODEL backend=$backend effort=$EFFORT runs=$RUNS fixtures=${#corpus[@]}"

  # Precompute expected sets. A fixture is "clean" only if it lives under
  # clean/ (deliberately empty codes field). A fixture with NO expected code that
  # is not under clean/ is mislabeled -- scoring it as clean would silently
  # flip its real detections from TP to FP -- so exclude it with a warning.
  local -A EXP=() IS_CLEAN=()
  local -- expected
  local -a scorable=()
  for f in "${corpus[@]}"; do
    expected=$(awk -F'\t' -v k="${f##*/fixtures/}" '$1 == k {print $2}' "$MANIFEST" \
      | grep -oE 'BCS[0-9]{4}' | sort -u || true)
    EXP[$f]=$expected
    if [[ $f == */clean/* ]]; then
      IS_CLEAN[$f]=1; scorable+=("$f")
    elif [[ -n $expected ]]; then
      IS_CLEAN[$f]=0; scorable+=("$f")
    else
      warn "no expected code in ${MANIFEST##*/} and not in clean/: ${f##*/} -- excluded from scoring"
    fi
  done
  corpus=("${scorable[@]}")
  ((${#corpus[@]})) || die 3 'no scorable fixtures (none has an expected code in the manifest)'

  # Per-run scratch (accumulators are module globals, reset at declaration).
  local -i run i_tp i_fp i_fn
  local -- json reported code pair fp_list model

  for ((run=1; run<=RUNS; run+=1)); do
    info "run $run/$RUNS ..."
    for f in "${corpus[@]}"; do
      # --no-cache: every repetition must be a fresh LLM round-trip. Served
      # from the result cache, runs 2..N would replay run 1 and stability
      # would read 1.0 whatever the model did.
      json=$(timeout "$TIMEOUT_S" "$BCS_CMD" check -j --no-cache -m "$MODEL" \
        -e "$EFFORT" --quiet -- "$f" 2>/dev/null) || true
      if [[ -z $json ]] || ! jq -e 'has("comments")' <<<"$json" &>/dev/null; then
        INCONCLUSIVE+=1
        warn "inconclusive: ${f##*/} (run $run) — empty/invalid backend output"
        continue
      fi
      SCORED+=1
      # Suppressed: a checker too old to carry .meta.model, or any jq hiccup,
      # leaves MODEL_ID empty and the report says "unknown" -- the scoring run
      # itself does not depend on it, so failing here must not abort a baseline.
      model=$(jq -r '.meta.model // empty' <<<"$json" 2>/dev/null) ||:
      if [[ -n $model ]]; then
        MODEL_RUNS[$model]=$(( ${MODEL_RUNS[$model]:-0} + 1 ))
        [[ -n $MODEL_ID ]] || MODEL_ID=$model
      fi
      reported=$(jq -r '.comments[].bcsCode // empty' <<<"$json" 2>/dev/null \
        | grep -oE 'BCS[0-9]{4}' | sort -u || true)
      expected=${EXP[$f]}
      i_tp=$(comm -12 <(_codes "$expected") <(_codes "$reported") | wc -l)
      i_fn=$(comm -23 <(_codes "$expected") <(_codes "$reported") | wc -l)
      # Tally the false positives by code and count them in the same pass, so
      # the count and the histogram can never disagree. A `wc -l` here would
      # read 1 for the empty list that `comm` prints as nothing.
      # ||: because comm exits non-zero only on a read error here, and both
      # operands are already-materialised shell strings: nothing left to fail.
      fp_list=$(comm -13 <(_codes "$expected") <(_codes "$reported")) ||:
      i_fp=0
      while IFS= read -r code; do
        [[ -n $code ]] || continue
        i_fp+=1
        FP_CODE[$code]=$(( ${FP_CODE[$code]:-0} + 1 ))
        pair="$code|${f##*/fixtures/}"
        FP_WHERE[$pair]=$(( ${FP_WHERE[$pair]:-0} + 1 ))
        ((IS_CLEAN[$f])) && FP_CLEAN[$code]=$(( ${FP_CLEAN[$code]:-0} + 1 )) ||:
      done <<< "$fp_list"
      TP=$((TP + i_tp)); FP=$((FP + i_fp)); FN=$((FN + i_fn))
      if ((IS_CLEAN[$f])); then CLEAN_FP=$((CLEAN_FP + i_fp)); CLEAN_RUNS+=1; fi
      while IFS= read -r code; do
        [[ -n $code ]] || continue
        pair="$f|$code"
        PAIR_RUNS[$pair]=$(( ${PAIR_RUNS[$pair]:-0} + 1 ))
        CODE_TOT[$code]=$(( ${CODE_TOT[$code]:-0} + 1 ))
        if _has "$reported" "$code"; then
          PAIR_HITS[$pair]=$(( ${PAIR_HITS[$pair]:-0} + 1 ))
          CODE_HIT[$code]=$(( ${CODE_HIT[$code]:-0} + 1 ))
        fi
      done < <(_codes "$expected")
    done
  done

  # The reports are written either way (the checks are paid for); a mix is
  # then a failed run, so it cannot pass as one model's baseline.
  local -- models_seen=''
  local -a seen=()
  if ((${#MODEL_RUNS[@]} > 1)); then
    MODEL_ID=mixed
    readarray -t seen < <(for model in "${!MODEL_RUNS[@]}"; do
                            printf '%s x%d\n' "$model" "${MODEL_RUNS[$model]}"
                          done | sort)
    printf -v models_seen '%s, ' "${seen[@]}"
  fi

  _emit_reports

  [[ -z $models_seen ]] \
    || die 1 "Checks ran on ${#MODEL_RUNS[@]} models (${models_seen%, }); the report is labelled mixed. Pass a canonical model id with -m"

  # CI gate: a reachable-but-unproductive backend (everything timed out or came
  # back inconclusive) must fail loudly when a backend is required, rather than
  # passing as an all-zero "perfect" score.
  if ((REQUIRE_BACKEND)) && ! ((SCORED)); then
    die 1 'no conclusive fixture-runs despite BCS_FIXTURES_REQUIRE_BACKEND=1'
  fi
}

# Render TSV + markdown from the accumulator state (called from main scope).
_emit_reports() {
  local -- slug tsv md json ts
  slug=$(_slug "$MODEL")
  tsv="$OUT_DIR/accuracy-$slug-$EFFORT.tsv"
  md="$OUT_DIR/accuracy-$slug-$EFFORT.md"
  json="$OUT_DIR/accuracy-$slug-$EFFORT.json"
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  # Every model the checks ran on, with its count: one row for a pinned run.
  local -- models_md='' models_tsv='' m
  for m in "${!MODEL_RUNS[@]}"; do
    models_md+="\`$m\` x${MODEL_RUNS[$m]}, "
    models_tsv+=$(printf '%s\t%s' "$m" "${MODEL_RUNS[$m]}")$'\n'
  done
  models_md=${models_md%, }

  # Aggregate precision/recall/F1.
  local -- precision recall f1
  read -r precision recall f1 < <(awk -v tp="$TP" -v fp="$FP" -v fn="$FN" 'BEGIN{
    p=(tp+fp>0)?tp/(tp+fp):0; r=(tp+fn>0)?tp/(tp+fn):0;
    f=(p+r>0)?2*p*r/(p+r):0; printf "%.3f %.3f %.3f\n", p, r, f }')

  # Per-(fixture,code) stability rows + counts.
  local -i total_pairs=0 stable_pairs=0
  local -- rows='' key fixb code hr st pr ph
  for key in "${!PAIR_RUNS[@]}"; do
    total_pairs+=1
    pr=${PAIR_RUNS[$key]}; ph=${PAIR_HITS[$key]:-0}
    hr=$(awk -v h="$ph" -v n="$pr" 'BEGIN{printf "%.3f", (n>0)?h/n:0}')
    if [[ $hr == 1.000 || $hr == 0.000 ]]; then st=yes; stable_pairs+=1; else st=no; fi
    fixb=${key%%|*}; fixb=${fixb##*/}; code=${key##*|}
    rows+=$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$fixb" "$code" "$pr" "$ph" "$hr" "$st")$'\n'
  done
  # With no expected (fixture,code) pairs (e.g. all runs inconclusive) there is
  # nothing to be stable about; report n/a rather than a misleading 1.000.
  local -- stability
  if ((total_pairs)); then
    stability=$(awk -v s="$stable_pairs" -v t="$total_pairs" 'BEGIN{printf "%.3f", s/t}')
  else
    stability='n/a'
  fi

  # Write TSV (sorted by fixture then code).
  { printf 'fixture\tcode\truns\thits\thitrate\tstable\n'
    [[ -n $rows ]] && printf '%s' "$rows" | sort ||:
  } > "$tsv"

  # Per-rule recall table (sorted by code); rule_tsv feeds the JSON report.
  local -- rule_table='' rule_tsv='' c hit tot rr
  while IFS= read -r c; do
    [[ -n $c ]] || continue
    hit=${CODE_HIT[$c]:-0}; tot=${CODE_TOT[$c]}
    rr=$(awk -v h="$hit" -v t="$tot" 'BEGIN{printf "%.3f", (t>0)?h/t:0}')
    rule_table+=$(printf '| %s | %s | %s | %s |' "$c" "$hit" "$tot" "$rr")$'\n'
    rule_tsv+=$(printf '%s\t%s\t%s\t%s' "$c" "$hit" "$tot" "$rr")$'\n'
  done < <(printf '%s\n' "${!CODE_TOT[@]}" | sort)

  # False positives by code, commonest first, with the clean/ share broken out;
  # fp_tsv feeds the JSON report.
  # The fourth TSV field carries the per-fixture breakdown as space-separated
  # 'name:count' pairs -- fixture paths hold neither spaces nor colons, so jq
  # can split it back apart downstream.
  local -- fp_table='' fp_tsv='' fc ftot fclean fwhere fwjson k
  while IFS= read -r fc; do
    [[ -n $fc ]] || continue
    ftot=${FP_CODE[$fc]}; fclean=${FP_CLEAN[$fc]:-0}
    fwhere='' fwjson=''
    while IFS= read -r k; do
      [[ -n $k ]] || continue
      fwhere+="${fwhere:+, }${k#*|} x${FP_WHERE[$k]}"
      fwjson+="${fwjson:+ }${k#*|}:${FP_WHERE[$k]}"
    done < <(for k in "${!FP_WHERE[@]}"; do
               [[ ${k%%|*} == "$fc" ]] || continue
               printf '%s\t%s\n' "${FP_WHERE[$k]}" "$k"
             done | sort -k1,1nr -k2,2 | cut -f2)
    fp_table+=$(printf '| %s | %s | %s | %s |' "$fc" "$ftot" "$fclean" "$fwhere")$'\n'
    fp_tsv+=$(printf '%s\t%s\t%s\t%s' "$fc" "$ftot" "$fclean" "$fwjson")$'\n'
  done < <(for fc in "${!FP_CODE[@]}"; do
             printf '%s\t%s\n' "${FP_CODE[$fc]}" "$fc"
           done | sort -k1,1nr -k2,2 | cut -f2)
  [[ -n $fp_table ]] || fp_table='| _none_ | 0 | 0 | |'$'\n'

  # Clean-fixture false-positive rate.
  local -- clean_rate
  clean_rate=$(awk -v fp="$CLEAN_FP" -v n="$CLEAN_RUNS" \
    'BEGIN{printf "%.3f", (n>0)?fp/n:0}')

  # Write markdown report.
  cat > "$md" <<MD
<!-- SPDX-License-Identifier: GPL-3.0-or-later -->
# BCS Check Accuracy Report

| Field | Value |
|-------|-------|
| Generated | $ts |
| Model alias | \`$MODEL\` |
| Model (resolved) | \`${MODEL_ID:-unknown}\` |
| Models seen | ${models_md:-unknown} |
| Effort | \`$EFFORT\` |
| Runs per fixture | $RUNS |
| Conclusive fixture-runs | $SCORED |
| Inconclusive (empty/timeout) | $INCONCLUSIVE |

## Aggregate

| Metric | Value |
|--------|-------|
| True positives  (TP) | $TP |
| False positives (FP) | $FP |
| False negatives (FN) | $FN |
| **Precision** TP/(TP+FP) | **$precision** |
| **Recall** TP/(TP+FN) | **$recall** |
| **F1** | **$f1** |

> On violation fixtures, FP includes extra findings that may be genuine
> secondary issues. The clean-fixture rate below is the trustworthy
> false-positive signal; recall is the trustworthy detection signal.

## False positives on clean fixtures

| Metric | Value |
|--------|-------|
| Spurious findings on clean fixtures | $CLEAN_FP |
| Clean fixture-runs | $CLEAN_RUNS |
| Avg spurious findings per clean run | $clean_rate |

## False positives by rule

| Code | Reported, not planted | of which on clean/ | Where |
|------|----------------------:|-------------------:|-------|
${fp_table%$'\n'}

> On a violation fixture an extra finding may be a genuine secondary defect the
> fixture did not declare -- two such were confirmed and repaired in September
> 2026. On a clean fixture it cannot be: the last column is noise, full stop.

## Stability (run-to-run determinism)

| Metric | Value |
|--------|-------|
| Expected (fixture,code) pairs | $total_pairs |
| Deterministic pairs (hit-rate 0.0 or 1.0) | $stable_pairs |
| **Stability score** | **$stability** |

A stability score below 1.0 means at least one expected rule was reported on
some runs and missed on others — the non-determinism this report quantifies.
Per-pair hit-rates are in \`${tsv##*/}\`.

## Per-rule recall

| Code | Hits | Runs | Recall |
|------|------|------|--------|
$rule_table
MD

  # Machine-readable report: the form a baseline is committed in (see
  # baseline/README.md) and what a later run is compared against. The bcs
  # version is read from the script text; asking the checker would cost a call.
  local -- bcs_version
  bcs_version=$(grep -m1 -oE '^declare -r VERSION=[0-9.]+' "$PROJECT_DIR"/bcs) ||:
  jq -n \
    --arg generated "$ts" --arg bcs_version "${bcs_version##*=}" \
    --arg model "$MODEL" --arg model_id "$MODEL_ID" --arg models "$models_tsv" \
    --arg effort "$EFFORT" --arg stability "$stability" \
    --arg rules "$rule_tsv" \
    --arg fp_rules "$fp_tsv" \
    --argjson runs "$RUNS" --argjson scored "$SCORED" --argjson inconclusive "$INCONCLUSIVE" \
    --argjson tp "$TP" --argjson fp "$FP" --argjson fn "$FN" \
    --argjson precision "$precision" --argjson recall "$recall" --argjson f1 "$f1" \
    --argjson clean_fp "$CLEAN_FP" --argjson clean_runs "$CLEAN_RUNS" \
    --argjson clean_fp_rate "$clean_rate" \
    '{generated: $generated, bcs_version: $bcs_version, model: $model,
      model_id: (if $model_id == "" then null else $model_id end),
      models: ($models | split("\n") | map(select(. != "") | split("\t")
               | {key: .[0], value: (.[1] | tonumber)}) | from_entries),
      effort: $effort,
      runs: $runs, scored: $scored, inconclusive: $inconclusive,
      tp: $tp, fp: $fp, fn: $fn, precision: $precision, recall: $recall, f1: $f1,
      clean_fp: $clean_fp, clean_runs: $clean_runs, clean_fp_rate: $clean_fp_rate,
      stability: ($stability | tonumber? // null),
      per_rule: ($rules | split("\n") | map(select(. != "") | split("\t")
                 | {key: .[0], value: {hits: (.[1] | tonumber), runs: (.[2] | tonumber),
                                       recall: (.[3] | tonumber)}}) | from_entries),
      fp_per_rule: ($fp_rules | split("\n") | map(select(. != "") | split("\t")
                 | {key: .[0], value: {total: (.[1] | tonumber),
                                       clean: (.[2] | tonumber),
                                       fixtures: ((.[3] // "") | split(" ")
                                         | map(select(. != "") | split(":")
                                           | {key: .[0], value: (.[1] | tonumber)})
                                         | from_entries)}}) | from_entries)}' \
    > "$json" || die 1 "Failed to write ${json@Q}"

  success "Wrote $md"
  success "Wrote $tsv"
  success "Wrote $json"
  # No conclusive runs means the metrics above are all zero by default, not by
  # measurement -- say so loudly so an unreachable/timed-out backend is not
  # mistaken for a perfect score.
  ((SCORED)) || warn 'no conclusive fixture-runs (backend unreachable or all timed out); metrics are NOT meaningful'
  # Console one-liner.
  printf '%sprecision=%s recall=%s F1=%s stability=%s clean-FP/run=%s%s\n' \
    "$BOLD" "$precision" "$recall" "$f1" "$stability" "$clean_rate" "$NC" >&2
}

main "$@"
#fin
