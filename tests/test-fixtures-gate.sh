#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-fixtures-gate.sh - The accuracy gate must not pass on a dead backend
#
# Drives test-check-fixtures.sh and accuracy/bcs-accuracy-score.sh through
# their command seams (BCS_FIXTURES_CMD, BCS_SCORE_CMD) with a stub checker
# that replays canned outcomes. `curl` and `claude` are exported shell
# functions and every API key is a dummy, so no backend is ever contacted.
set -euo pipefail
shopt -s inherit_errexit nullglob

declare -rx PATH=~/.local/bin:/usr/local/bin:/usr/bin:/bin

#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: fixtures gate and accuracy scorer'

declare -- SANDBOX='' OUT=''
declare -i RC=0

trap '[[ -z $SANDBOX ]] || rm -rf -- "$SANDBOX"' EXIT
SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}"/bcs-gate.XXXXXX) \
  || { >&2 echo 'Failed to create sandbox directory'; exit 1; }
declare -r STUB="$SANDBOX"/stub-bcs ARGV_LOG="$SANDBOX"/argv.log

# Stub checker: logs its argv, then replays the outcome named by STUB_MODE.
cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$STUB_ARGV_LOG"
declare -r FIXTURE=${!#}

# expected -> the fixture's codes from the sidecar manifest, one per line
expected() {
  local -- rel=${FIXTURE##*/fixtures/}
  awk -F'\t' -v k="$rel" '$1 == k {print $2}' "${FIXTURE%"$rel"}"EXPECT.tsv \
    | grep -oE 'BCS[0-9]{4}'
}

emit_findings() {
  local -- code
  while IFS= read -r code; do
    printf '[ERROR] %s line 1: stub finding\n' "$code"
  done < <(expected ||:)
  exit 1
}

case ${STUB_MODE:-findings} in
  empty)    exit 0 ;;
  timeout)  exit 124 ;;
  apierror) >&2 echo 'bcs: ✗ OpenAI API error (HTTP 401)'; exit 5 ;;
  mixed)    if [[ ${FIXTURE##*/} == 01-* ]]; then exit 124; fi
            emit_findings ;;
  miss)     # BCS0000 is not a real code; the gate only greps BCS[0-9]{4}, so
            # this is a conclusive answer that cannot match any expected set.
            if [[ " ${STUB_MISS:-} " == *" ${FIXTURE##*/} "* ]]; then
              printf '[WARN] BCS0000 line 1: stub finding that misses the plant\n'
              exit 0
            fi
            emit_findings ;;
  json)     echo '{"source":"bcs","meta":{},"comments":[]}' ;;
  jsonfp)   # Every expected code, plus one the fixture never planted. BCS1203
            # is a real style rule that none of the fixtures used here expect,
            # so it lands in the false-positive tally on every single run.
            { expected ||:; echo BCS1203; } \
              | jq -R -s -c '{source: "bcs", meta: {},
                   comments: (split("\n") | map(select(. != "")
                              | {bcsCode: ., line: 1, level: "error"}))}' ;;
  jsonmodel|jsonmixed)
            # Every expected code, under a named model. jsonmixed answers for
            # fixture 01-* as a second model, as an alias edited mid-run would.
            m=model-a
            [[ $STUB_MODE == jsonmixed && ${FIXTURE##*/} == 01-* ]] && m=model-b ||:
            { expected ||:; } \
              | jq -R -s -c --arg m "$m" '{source: "bcs", meta: {model: $m},
                   comments: (split("\n") | map(select(. != "")
                              | {bcsCode: ., line: 1, level: "error"}))}' ;;
  jsonfind) { expected ||:; } \
              | jq -R -s -c '{source: "bcs", meta: {},
                   comments: (split("\n") | map(select(. != "")
                              | {bcsCode: ., line: 1, level: "error"}))}' ;;
  *)        emit_findings ;;
esac
STUB
chmod -- +x "$STUB"

# Reachability mocks, imported by the child bash. curl answers the Ollama
# /api/tags probe; claude only has to exist for `command -v`.
curl() { ((${MOCK_OLLAMA_UP:-0})); }
claude() { :; }
declare -fx curl claude

# run_child SCRIPT STUB_MODE [VAR=value ...] [-- script args...]
# Runs SCRIPT with a scrubbed environment; fills RC and OUT.
run_child() {
  local -- script=$1 mode=$2; shift 2
  local -a env_args=() script_args=()
  while (($#)); do
    if [[ $1 == -- ]]; then shift; script_args=("$@"); break; fi
    env_args+=("$1"); shift
  done
  : > "$ARGV_LOG"
  RC=0
  env -u BCS_SKIP_FIXTURES -u BCS_FIXTURES_REQUIRE_BACKEND -u BCS_FIXTURES_MODEL \
      -u BCS_FIXTURES_JSON -u BCS_SCORE_MODEL -u OPENAI_API_KEY -u GOOGLE_API_KEY \
      -u GEMINI_API_KEY -u ANTHROPIC_API_KEY -u MOCK_OLLAMA_UP \
      BCS_FIXTURES_CMD="$STUB" BCS_SCORE_CMD="$STUB" \
      STUB_MODE="$mode" STUB_ARGV_LOG="$ARGV_LOG" "${env_args[@]}" \
      bash "$script" "${script_args[@]}" &>"$SANDBOX"/out || RC=$?
  OUT=$(< "$SANDBOX"/out)
}
run_gate() { run_child "$TEST_DIR"/test-check-fixtures.sh "$@"; }

declare -a FIXTURES=("$TEST_DIR"/fixtures/*.sh)
declare -ri FIXTURE_COUNT=${#FIXTURES[@]}

# ---- Inconclusive fixtures are not passes ----
begin_test 'every fixture empty'
run_gate empty OPENAI_API_KEY=test-openai
assert_equal 1 "$RC" 'all empty output -> suite fails' ||:
assert_contains "$OUT" "$FIXTURE_COUNT inconclusive" 'all empty output -> counted inconclusive' ||:

begin_test 'every fixture times out'
run_gate timeout OPENAI_API_KEY=test-openai
assert_equal 1 "$RC" 'all rc 124 -> suite fails' ||:
assert_contains "$OUT" "$FIXTURE_COUNT inconclusive" 'all rc 124 -> counted inconclusive' ||:

begin_test 'every fixture hits a backend error'
run_gate apierror OPENAI_API_KEY=test-openai
assert_equal 1 "$RC" 'all rc 5 -> suite fails' ||:
assert_contains "$OUT" "$FIXTURE_COUNT inconclusive" 'all rc 5 -> counted inconclusive' ||:
assert_not_contains "$OUT" 'missing:' 'backend error is not reported as a finding regression' ||:

begin_test 'healthy backend'
run_gate findings OPENAI_API_KEY=test-openai
assert_equal 0 "$RC" 'expected findings -> suite passes' ||:
assert_contains "$OUT" "$FIXTURE_COUNT passed, 0 failed" 'expected findings -> every fixture passed' ||:

begin_test 'one inconclusive fixture'
run_gate mixed OPENAI_API_KEY=test-openai
assert_equal 0 "$RC" 'one inconclusive -> suite still passes' ||:
assert_contains "$OUT" "$((FIXTURE_COUNT - 1)) passed, 0 failed" 'one inconclusive -> not counted as passed' ||:
assert_contains "$OUT" '1 inconclusive' 'one inconclusive -> reported' ||:
run_gate mixed OPENAI_API_KEY=test-openai BCS_FIXTURES_REQUIRE_BACKEND=1
assert_equal 1 "$RC" 'one inconclusive + REQUIRE_BACKEND=1 -> suite fails' ||:

# ---- Probe order: API keys, then Ollama, then the CLI ----
begin_test 'probe order'
run_gate findings OPENAI_API_KEY=k GOOGLE_API_KEY=k ANTHROPIC_API_KEY=k MOCK_OLLAMA_UP=1
assert_contains "$OUT" 'using backend: openai' 'all reachable -> openai' ||:
assert_contains "$(< "$ARGV_LOG")" '-m gpt5-mini' 'openai -> gpt5-mini' ||:
run_gate findings GOOGLE_API_KEY=k ANTHROPIC_API_KEY=k MOCK_OLLAMA_UP=1
assert_contains "$OUT" 'using backend: google' 'no openai key -> google' ||:
run_gate findings GEMINI_API_KEY=k
assert_contains "$OUT" 'using backend: google' 'GEMINI_API_KEY alone -> google' ||:
run_gate findings ANTHROPIC_API_KEY=k MOCK_OLLAMA_UP=1
assert_contains "$OUT" 'using backend: anthropic' 'anthropic key only -> anthropic' ||:
run_gate findings MOCK_OLLAMA_UP=1
assert_contains "$OUT" 'using backend: ollama' 'no keys, Ollama up -> ollama' ||:
run_gate findings
assert_contains "$OUT" 'using backend: claude' 'no keys, Ollama down -> CLI' ||:

begin_test 'BCS_FIXTURES_MODEL'
run_gate findings OPENAI_API_KEY=k BCS_FIXTURES_MODEL=flash
assert_equal "$FIXTURE_COUNT" "$(grep -c -- '-m flash ' "$ARGV_LOG" ||:)" \
  'BCS_FIXTURES_MODEL=flash honoured for every fixture, whatever was probed' ||:

# ---- Scorer: every repetition must bypass the result cache ----
begin_test 'accuracy scorer'
run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh json -- \
  -m gpt5-mini -n 2 -o "$SANDBOX"/score "${FIXTURES[0]}" "${FIXTURES[1]}"
assert_equal 0 "$RC" 'scorer runs against the stub' ||:
assert_equal 4 "$(wc -l < "$ARGV_LOG")" 'scorer: 2 fixtures x 2 runs = 4 checker calls' ||:
assert_equal 4 "$(grep -c -- '--no-cache' "$ARGV_LOG" ||:)" 'scorer: every call passes --no-cache' ||:
# Machine-readable report: what a committed baseline is made of
run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh jsonfind -- \
  -m gpt5-mini -e low -n 2 -o "$SANDBOX"/score "${FIXTURES[0]}" "${FIXTURES[1]}" \
  "$TEST_DIR"/fixtures/clean/01-greet.sh
declare -r SCORE_JSON="$SANDBOX"/score/accuracy-gpt5-mini-low.json
assert_file_exists "$SCORE_JSON" 'scorer writes accuracy-<model>-<effort>.json' ||:
assert_equal 'gpt5-mini low 2' "$(jq -r '"\(.model) \(.effort) \(.runs)"' "$SCORE_JSON" 2>/dev/null ||:)" \
  'JSON report: model, effort, runs' ||:
assert_equal '4 0 true true' "$(jq -r '"\(.tp) \(.fn) \(.recall == 1) \(.f1 == 1)"' "$SCORE_JSON" 2>/dev/null ||:)" \
  'JSON report: every expected code found -> tp=4 fn=0 recall=1 f1=1' ||:
assert_equal '0 2' "$(jq -r '"\(.clean_fp) \(.clean_runs)"' "$SCORE_JSON" 2>/dev/null ||:)" \
  'JSON report: clean fixture runs counted, no false positives' ||:
assert_equal 2 "$(jq -r '.per_rule | length' "$SCORE_JSON" 2>/dev/null ||:)" \
  'JSON report: per-rule recall for both expected codes' ||:
assert_matches "$(jq -r '.bcs_version' "$SCORE_JSON" 2>/dev/null ||:)" '^[0-9]+\.[0-9]+\.[0-9]+' \
  'JSON report: records the bcs version it scored' ||:
assert_equal 0 "$(jq -r '.fp_per_rule | length' "$SCORE_JSON" 2>/dev/null ||:)" \
  'JSON report: nothing spurious reported -> empty fp_per_rule' ||:

# Which codes are false-positive, not merely how many. FP was a bare count
# until 2026-09-18, so a precision shift could be observed and never explained.
begin_test 'accuracy scorer: false positives are tallied by code'
run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh jsonfp -- \
  -m gpt5-mini -e high -n 2 -o "$SANDBOX"/score "${FIXTURES[0]}" "${FIXTURES[1]}" \
  "$TEST_DIR"/fixtures/clean/01-greet.sh
declare -r FP_JSON="$SANDBOX"/score/accuracy-gpt5-mini-high.json
assert_equal '6 2' "$(jq -r '"\(.fp) \(.clean_fp)"' "$FP_JSON" 2>/dev/null ||:)" \
  'aggregate FP unchanged by the tally: 3 fixtures x 2 runs, 2 of them clean' ||:
assert_equal 1 "$(jq -r '.fp_per_rule | length' "$FP_JSON" 2>/dev/null ||:)" \
  'one code accounts for every false positive' ||:
assert_equal '6 2' "$(jq -r '"\(.fp_per_rule.BCS1203.total) \(.fp_per_rule.BCS1203.clean)"' \
  "$FP_JSON" 2>/dev/null ||:)" 'BCS1203 tallied 6 times, 2 of them on clean/' ||:
assert_contains "$(< "$SANDBOX"/score/accuracy-gpt5-mini-high.md)" 'False positives by rule' \
  'markdown report gains the false-positive table' ||:
# ... and which fixture each came from. A bare per-code tally cost an
# experiment three times over in September 2026: the code was known, the file
# it fired on was not, so the run had to be repeated to find out.
assert_equal 3 "$(jq -r '.fp_per_rule.BCS1203.fixtures | length' "$FP_JSON" 2>/dev/null ||:)" \
  'the three fixtures are named beside the code' ||:
assert_equal 2 "$(jq -r '.fp_per_rule.BCS1203.fixtures["clean/01-greet.sh"]' \
  "$FP_JSON" 2>/dev/null ||:)" 'clean/01-greet.sh drew it on both runs' ||:
assert_contains "$(< "$SANDBOX"/score/accuracy-gpt5-mini-high.md)" 'clean/01-greet.sh' \
  'markdown names the fixture too' ||:
assert_contains "$(< "$SANDBOX"/score/accuracy-gpt5-mini-high.md)" '| BCS1203 | 6 | 2 |' \
  'markdown table carries the per-code counts' ||:

# The model of every check, not only the first. A conf alias edited mid-run
# split a 129-check baseline across two models on 2026-11-26 while the report
# named one.
begin_test 'accuracy scorer: the model of every check is recorded'
run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh jsonmodel -- \
  -m pinned -e low -n 2 -o "$SANDBOX"/score "${FIXTURES[0]}" "${FIXTURES[1]}"
declare -r MODEL_JSON="$SANDBOX"/score/accuracy-pinned-low.json
assert_equal 0 "$RC" 'one model -> the run passes' ||:
assert_equal 'model-a 4 1' \
  "$(jq -r -- '"\(.model_id) \(.models["model-a"]) \(.models | length)"' "$MODEL_JSON" 2>/dev/null ||:)" \
  'model_id, and every check counted under it' ||:

begin_test 'accuracy scorer: a run split across models fails, labelled mixed'
run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh jsonmixed -- \
  -m drifting -e low -n 2 -o "$SANDBOX"/score "${FIXTURES[0]}" "${FIXTURES[1]}"
declare -r MIXED_JSON="$SANDBOX"/score/accuracy-drifting-low.json
assert_equal 1 "$RC" 'two models -> the run fails' ||:
assert_file_exists "$MIXED_JSON" 'the paid-for report is still written' ||:
assert_equal 'mixed 2 2' \
  "$(jq -r -- '"\(.model_id) \(.models["model-a"]) \(.models["model-b"])"' "$MIXED_JSON" 2>/dev/null ||:)" \
  'labelled mixed, with both models counted' ||:
assert_contains "$OUT" 'model-a x2, model-b x2' 'the failure names both models' ||:
assert_contains "$(< "$SANDBOX"/score/accuracy-drifting-low.md)" 'Models seen' \
  'markdown lists the models too' ||:

run_child "$TEST_DIR"/accuracy/bcs-accuracy-score.sh json OPENAI_API_KEY=k MOCK_OLLAMA_UP=1 -- \
  -n 1 -o "$SANDBOX"/score "${FIXTURES[0]}"
assert_contains "$OUT" 'backend=openai' 'scorer probe: API key wins over Ollama and CLI' ||:

# ---- Failure budget ----
# The gate runs each fixture once, so a clean sweep is a conjunction of 30
# probabilistic events and a red run is expected even from a healthy checker.
# Misses are forgiven up to BCS_FIXTURES_MAX_FAIL, and always named.
declare -r MISS1='01-missing-strict-mode.sh'
declare -r MISS2="$MISS1 02-undeclared-local.sh"
declare -r MISS3="$MISS2 03-string-not-array.sh"

begin_test 'two misses are within the default budget'
run_gate miss OPENAI_API_KEY=k STUB_MISS="$MISS2"
assert_equal 0 "$RC" 'suite is green at 2 misses (default budget 2)' ||:
assert_contains "$OUT" 'within the budget of 2' 'says the misses were forgiven' ||:
assert_contains "$OUT" '01-missing-strict-mode.sh' 'names the first missed fixture' ||:
assert_contains "$OUT" '02-undeclared-local.sh' 'names the second missed fixture' ||:

begin_test 'three misses exceed the default budget'
run_gate miss OPENAI_API_KEY=k STUB_MISS="$MISS3"
assert_equal 1 "$RC" 'suite is red at 3 misses' ||:
assert_contains "$OUT" 'over the budget of 2' 'says the budget was exceeded' ||:
assert_contains "$OUT" '03-string-not-array.sh' 'names the third missed fixture' ||:

begin_test 'BCS_FIXTURES_MAX_FAIL=0 demands a clean sweep'
run_gate miss OPENAI_API_KEY=k STUB_MISS="$MISS1" BCS_FIXTURES_MAX_FAIL=0
assert_equal 1 "$RC" 'one miss is red when the budget is 0' ||:
assert_contains "$OUT" 'over the budget of 0' 'reports the zero budget' ||:

begin_test 'a clean sweep needs no forgiveness'
run_gate findings OPENAI_API_KEY=k
assert_equal 0 "$RC" 'suite is green with no misses' ||:
assert_not_contains "$OUT" 'the budget of' 'budget is silent when nothing missed' ||:

print_summary 'fixtures-gate'
#fin
