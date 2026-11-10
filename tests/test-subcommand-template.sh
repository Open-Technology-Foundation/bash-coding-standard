#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# test-subcommand-template.sh - Tests for bcs template subcommand
set -euo pipefail
shopt -s inherit_errexit
#shellcheck source-path=SCRIPTDIR source=test-helpers.sh
source "$(dirname "$0")"/test-helpers.sh

echo 'Testing: template subcommand'

# Test: minimal template
begin_test 'minimal template generates output'
output=$("$BCS_CMD" template -t minimal 2>/dev/null)
assert_matches "$output" '#!/(usr/)?bin/(env )?bash' 'has shebang' || true

begin_test 'minimal template has #fin'
assert_contains "$output" '#fin' 'has end marker' || true

# Test: basic template
begin_test 'basic template generates output'
output=$("$BCS_CMD" template -t basic 2>/dev/null)
assert_contains "$output" 'set -euo pipefail' 'has strict mode' || true

# Test: complete template
begin_test 'complete template generates output'
output=$("$BCS_CMD" template -t complete 2>/dev/null)
assert_contains "$output" '_msg()' 'has messaging function' || true
assert_contains "$output" 'main "$@"' 'has main invocation' || true

# Test: library template
begin_test 'library template generates output'
output=$("$BCS_CMD" template -t library 2>/dev/null)
assert_contains "$output" 'declare -fx' 'has function export' || true

# Test: name substitution
begin_test 'name substitution works'
output=$("$BCS_CMD" template -t minimal -n myapp 2>/dev/null)
assert_contains "$output" 'myapp' 'name substituted' || true

# Test: description substitution
begin_test 'description substitution works'
output=$("$BCS_CMD" template -t basic -d 'My cool app' 2>/dev/null)
assert_contains "$output" 'My cool app' 'description substituted' || true

# Test: version substitution
begin_test 'version substitution works'
output=$("$BCS_CMD" template -t basic -V '2.5.0' 2>/dev/null)
assert_contains "$output" '2.5.0' 'version substituted' || true

# Test: output to file
begin_test 'output to file works'
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT
"$BCS_CMD" template -t minimal -o "$temp_file" -f 2>/dev/null
output=$(< "$temp_file")
assert_matches "$output" '#!/(usr/)?bin/(env )?bash' 'file has shebang' || true

# Test: executable flag
begin_test 'executable flag works'
temp_file2=$(mktemp)
trap 'rm -f "$temp_file" "$temp_file2"' EXIT
"$BCS_CMD" template -t minimal -o "$temp_file2" -xf 2>/dev/null
if [[ -x "$temp_file2" ]]; then
  printf '  %s✓%s file is executable\n' "$GREEN" "$NC"
  TESTS_PASSED+=1
else
  printf '  %s✗%s file is not executable\n' "$RED" "$NC"
  TESTS_FAILED+=1
fi

# Test: default type is basic
begin_test 'default template type is basic'
default_output=$("$BCS_CMD" template 2>/dev/null)
assert_contains "$default_output" 'set -euo pipefail' 'default has strict mode (basic)' || true

# Test: file overwrite protection
begin_test 'refuses overwrite without -f'
overwrite_file=$(mktemp)
echo 'existing content' > "$overwrite_file"
assert_fails 'overwrite blocked' "$BCS_CMD" template -t minimal -o "$overwrite_file" || true
rm -f "$overwrite_file"

# Test: name derived from output filename
begin_test 'name from output filename'
name_file=$(mktemp -d)/deploy.sh
output=$("$BCS_CMD" template -t minimal -o "$name_file" 2>/dev/null)
name_content=$(< "$name_file")
assert_contains "$name_content" 'deploy' 'name derived from filename' || true
rm -rf "$(dirname "$name_file")"

# Test: no leftover placeholders in output
for ttype in minimal basic complete library; do
  begin_test "no placeholders in $ttype template"
  tpl_output=$("$BCS_CMD" template -t "$ttype" -n test -d 'desc' 2>/dev/null)
  assert_not_contains "$tpl_output" '{{' "no {{ in $ttype output" || true
done

# Test: all template types produce genuinely shellcheck-clean output.
# Scaffold-variable findings (SC2034/SC2155) are handled by inline
# `#shellcheck disable=` directives in the templates themselves, so the
# generated script must pass a plain `shellcheck -x` with no exclusions.
for ttype in minimal basic complete library; do
  begin_test "$ttype template passes shellcheck"
  sc_file=$(mktemp --suffix=.sh)
  "$BCS_CMD" template -t "$ttype" -n testscript -o "$sc_file" -f 2>/dev/null
  if shellcheck -x "$sc_file" 2>/dev/null; then
    printf '  %s✓%s %s shellcheck clean\n' "$GREEN" "$NC" "$ttype"
    TESTS_PASSED+=1
  else
    printf '  %s✗%s %s shellcheck has findings\n' "$RED" "$NC" "$ttype"
    shellcheck -x "$sc_file" 2>&1 | head -20
    TESTS_FAILED+=1
  fi
  rm -f "$sc_file"
done

# Test: help line counts match actual templates
begin_test 'help line counts match actual templates'
declare -i line_mismatches=0
declare -Ar expected_lines=([minimal]=18 [basic]=47 [complete]=119 [library]=48)
for ttype in minimal basic complete library; do
  actual_lines=$("$BCS_CMD" template -t "$ttype" 2>/dev/null | wc -l)
  expected=${expected_lines[$ttype]}
  # Allow ±15% tolerance for ~ prefix
  low=$((expected * 85 / 100))
  high=$((expected * 115 / 100))
  if ((actual_lines < low || actual_lines > high)); then
    printf '    %s: expected ~%d, got %d\n' "$ttype" "$expected" "$actual_lines"
    line_mismatches+=1
  fi
done
assert_equal 0 "$line_mismatches" 'help line counts match actual templates' || true

# Test: invalid template type
begin_test 'rejects invalid template type'
assert_fails 'rejects bogus type' "$BCS_CMD" template -t bogus || true

# Test: help
begin_test 'template -h shows help'
output=$("$BCS_CMD" template -h 2>/dev/null)
assert_contains "$output" 'bcs template' 'help has command name' || true

# Test: '&' / backslash in a value is inserted literally, not as matched text
# (patsub_replacement guard, T-28)
begin_test 'ampersand in name inserted literally'
out=$("$BCS_CMD" template -t basic -n 'A&B' -d 'plain' 2>/dev/null)
assert_contains "$out" 'A&B' 'literal ampersand preserved' || true
assert_not_contains "$out" 'A{{NAME}}B' 'ampersand not expanded to matched text' || true

# Test: library template sanitizes a non-identifier name (T-07a)
begin_test 'library name sanitized to a valid identifier'
lib=$("$BCS_CMD" template -t library -n 'my.tool' 2>/dev/null)
assert_contains "$lib" 'my_tool_VERSION' 'dot replaced with underscore' || true
assert_not_contains "$lib" 'my.tool_VERSION' 'invalid identifier not emitted' || true
lib_file=$(mktemp --suffix=.sh)
printf '%s\n' "$lib" > "$lib_file"
assert_success 'sanitized library parses' bash -n "$lib_file"
rm -f "$lib_file"

# Test: BCS1002 placement in the shipped templates.
# The suite checked the templates with shellcheck only, which knows nothing of
# BCS, so `basic` shipped for months running realpath under the caller's PATH.
# BCS1002 requires PATH above the metadata block -- SCRIPT_PATH=$(realpath ...)
# is normally a script's first external command -- and exempts sourced
# libraries, which must not clobber their caller's PATH.
for ttype in minimal basic complete library; do
  begin_test "BCS1002 placement in $ttype template"
  tpl_output=$("$BCS_CMD" template -t "$ttype" -n testscript -d 'desc' 2>/dev/null)
  # ||: on both: no match is an ordinary outcome here (minimal runs no external
  # command; library sets no PATH), and grep's exit 1 would otherwise abort the
  # suite under pipefail before print_summary ever runs.
  path_ln=$(grep -nE '^declare -rx PATH=' <<< "$tpl_output" | head -1 | cut -d: -f1) ||:
  ext_ln=$(grep -nE '\$\((realpath|readlink|dirname|basename|date|uname)' <<< "$tpl_output" \
             | head -1 | cut -d: -f1) ||:
  if [[ $ttype == library ]]; then
    assert_equal '' "$path_ln" 'a sourced library sets no PATH (BCS1002 exemption)' || true
  elif [[ -z $ext_ln ]]; then
    assert_equal '' "$path_ln" "$ttype runs no external command, so needs no PATH" || true
  else
    assert_not_empty "$path_ln" "$ttype runs an external command and sets PATH" || true
    [[ -z $path_ln || -z $ext_ln ]] \
      || assert_lt "$path_ln" "$ext_ln" "$ttype sets PATH above its first external command"
  fi
done

# Test: BCS0403 readonly-after-parse in the templates that parse options.
# BCS0403's own `# correct` example freezes the parsed flags once the loop ends
# ("# Make parsed variables readonly"), and a blind audit of the generated
# `basic` script reported BCS0403 in 3 runs of 3. `minimal` parses nothing and
# `library` is sourced, so neither owes a readonly.
declare -Ar parsed_flags=([minimal]='' [basic]='VERBOSE' [complete]='VERBOSE DEBUG PROMPT' [library]='')
declare -- flags='' ro_ln='' last_assign_ln=''
for ttype in minimal basic complete library; do
  begin_test "BCS0403 readonly-after-parse in $ttype template"
  tpl_output=$("$BCS_CMD" template -t "$ttype" -n testscript -d 'desc' 2>/dev/null)
  flags=${parsed_flags[$ttype]}
  # ||: throughout: no match is an ordinary outcome for the templates that
  # parse nothing, and grep's exit 1 would abort the suite under pipefail.
  ro_ln=$(grep -nE '^[[:space:]]*readonly ' <<< "$tpl_output" | head -1 | cut -d: -f1) ||:
  if [[ -z $flags ]]; then
    assert_equal '' "$ro_ln" "$ttype parses no option, so owes no readonly" || true
    continue
  fi
  assert_contains "$tpl_output" "readonly $flags" "$ttype freezes $flags after parsing" || true
  # The readonly must follow the last assignment: freezing a flag the loop has
  # yet to set would make that case arm fail at runtime.
  last_assign_ln=$(grep -nE "^[[:space:]]*(${flags// /|})=[01]" <<< "$tpl_output" \
                     | tail -1 | cut -d: -f1) ||:
  [[ -z $ro_ln || -z $last_assign_ln ]] \
    || assert_gt "$ro_ln" "$last_assign_ln" "$ttype freezes them after the parse loop"
done

# tpl_rc ARGS... -> exit status of `bcs template ARGS...`
tpl_rc() {
  local -i rc=0
  "$BCS_CMD" template "$@" &>/dev/null || rc=$?
  echo "$rc"
}

begin_test 'rejects a template type that is not one type'
assert_equal 22 "$(tpl_rc -t 'minimal basic')" "-t 'minimal basic' -> invalid argument (22)" || true

# The three values are written into shell source: -n and -V inside single
# quotes, -d into a comment line and into the help heredoc, which is unquoted.
# A value that would end the context it lands in used to inject code into the
# generated script, or make its --help die. It is refused instead.
begin_test 'refuses values that would break the generated source'
assert_equal 22 "$(tpl_rc -t basic -V "1.0'; id; echo '")" 'single quote in -V -> exit 22' || true
assert_equal 22 "$(tpl_rc -t minimal -n "x'; id; echo '")" 'single quote in -n -> exit 22' || true
assert_equal 22 "$(tpl_rc -t minimal -d $'one\ntwo')" 'newline in -d -> exit 22' || true
#shellcheck disable=SC2016  # the dollar sign is the literal value under test
assert_equal 22 "$(tpl_rc -t complete -d 'Costs $5')" 'dollar in -d -> exit 22' || true
#shellcheck disable=SC2016  # the backquotes are the literal value under test
assert_equal 22 "$(tpl_rc -t complete -d 'run `id`')" 'backquote in -d -> exit 22' || true
assert_equal 22 "$(tpl_rc -t complete -d 'a\\b')" 'doubled backslash in -d -> exit 22' || true
#shellcheck disable=SC1003  # the value under test really does end in a backslash
assert_equal 22 "$(tpl_rc -t complete -d 'ends with \')" 'trailing backslash in -d -> exit 22' || true

# The values are substituted one after another, so a placeholder carried
# inside one value would be replaced by the next and land in the wrong context.
begin_test 'refuses a value that carries a placeholder'
assert_equal 22 "$(tpl_rc -t basic -n '{{DESCRIPTION}}' -d "x'; id; echo '")" \
  'description smuggled into the name -> exit 22' || true
#shellcheck disable=SC2016  # the command substitution is the literal value under test
assert_equal 22 "$(tpl_rc -t complete -d '{{VERSION}}' -V '$(id)')" \
  'version smuggled into the description -> exit 22' || true

# Only `complete` writes the description into text the shell expands. In the
# other templates it is a comment, where a dollar sign is inert and always worked.
begin_test 'a dollar sign in a comment-only description is accepted'
for ttype in minimal basic library; do
  #shellcheck disable=SC2016  # the dollar sign is the literal value under test
  out=$("$BCS_CMD" template -t "$ttype" -n demo -d 'Back up $HOME nightly' 2>/dev/null) || out=''
  #shellcheck disable=SC2016  # as above
  assert_contains "$out" '# Back up $HOME nightly' "$ttype keeps the description verbatim" || true
done

begin_test 'the refusal names the value at fault'
out=$("$BCS_CMD" template -t basic -o "$temp_file.it's.sh" 2>&1) || true
assert_contains "$out" 'Script name' 'a name taken from -o is called the script name' || true
assert_not_contains "$out" 'ersion' 'the version is not blamed' || true

# An empty name is an empty identifier prefix in the library template, whose
# functions would then be called _msg, _error ... in the shell that sources it.
# The directory below does not exist, so nothing is written either way.
begin_test 'refuses an empty or reserved name'
assert_equal 22 "$(tpl_rc -t library -o "$temp_file".d/.sh)" 'a name derived as empty -> exit 22' || true
assert_equal 22 "$(tpl_rc -t library -n BASH)" 'library name BASH (BASH_VERSION is taken) -> exit 22' || true

# Only what would break the generated source is refused.
begin_test 'harmless values are accepted'
out=$("$BCS_CMD" template -t basic -n demo -d 'Expand {{VAR}} tokens in config files' 2>/dev/null) || out=''
assert_contains "$out" '# Expand {{VAR}} tokens in config files' 'braces that are no placeholder' || true
assert_equal 0 "$(tpl_rc -t minimal -V "1.0'rc")" 'a quote in -V where the template has no version' || true

# In the help heredoc of `complete` a backslash is live only before $, a
# backquote or another backslash, and a $ only when something follows it that
# could start an expansion. Descriptions like these always worked and must.
begin_test 'complete accepts what is inert in its help text'
for desc in 'Convert \r\n line endings to \n' 'Join C:\tmp files' 'Price list in US$ (monthly)' 'Totals in US$'; do
  if [[ $(tpl_rc -t complete -n demo -d "$desc" -o "$temp_file" -f) == 0 ]]; then
    out=$(bash -- "$temp_file" --help 2>&1) || out="--help failed: $out"
    assert_contains "$out" "-- $desc" "help shows ${desc@Q} verbatim" || true
  else
    assert_equal 0 22 "${desc@Q} is accepted" || true
  fi
done

# A range such as A-Z takes in accented letters where the locale collates, so
# the library-name sanitiser must work on bytes too. Needs a UTF-8 locale other
# than C.UTF-8; skipped without one.
begin_test 'library name is reduced to ASCII in a collating locale'
utf8_locale=$(locale -a 2>/dev/null | grep -i -E '^[a-z]{2}_[A-Z]{2}\.utf-?8$' | head -n 1) || utf8_locale=''
if [[ -n $utf8_locale ]]; then
  out=$(LC_ALL=$utf8_locale "$BCS_CMD" template -t library -n 'żółw' 2>/dev/null) || out=''
  assert_equal 1 "$(LC_ALL=C grep -c -- '^\[\[ ! -v [A-Za-z0-9_]*_VERSION \]\]' <<< "$out" || true)" \
    "fence variable is an ASCII identifier under $utf8_locale" || true
  # a C1 control character is one character there, and no byte of it is a C0 control
  assert_equal 22 "$(LC_ALL=$utf8_locale tpl_rc -t basic -d $'clear\xc2\x9b2J')" \
    'a C1 control character -> exit 22' || true
else
  printf '  %s◉%s no collating UTF-8 locale installed -- skipping\n' "$CYAN" "$NC"
fi

# The checks must see bytes, as the shell that later reads the file does. In a
# double-byte locale a lead byte would otherwise hide the brace or the quote
# that follows it. Needs localedef and the GBK charmap; skipped without them.
begin_test 'validation is byte-wise, whatever the locale'
locale_dir=$temp_file.loc
if command -v localedef >/dev/null && mkdir -- "$locale_dir" \
    && localedef -f GBK -i zh_CN "$locale_dir"/zh_CN.GBK &>/dev/null; then
  gbk_rc() {
    local -i rc=0
    LOCPATH=$locale_dir LC_ALL=zh_CN.GBK "$BCS_CMD" template "$@" &>/dev/null || rc=$?
    echo "$rc"
  }
  assert_equal 22 "$(gbk_rc -t basic -n $'\x81{{DESCRIPTION}}' -d "x'; id; echo '")" \
    'a lead byte does not hide a placeholder' || true
  #shellcheck disable=SC2016  # the backquotes are the literal value under test
  assert_equal 22 "$(gbk_rc -t complete -n demo -d $'\x81`id;\x81`')" \
    'lead bytes do not hide a pair of backquotes' || true
else
  printf '  %s◉%s localedef or the GBK charmap not available -- skipping\n' "$CYAN" "$NC"
fi
rm -rf -- "$locale_dir"

# Reuses $temp_file, which the EXIT trap above already removes.
begin_test 'ordinary punctuation still generates a working script'
assert_equal 0 "$(tpl_rc -t complete -n demo -d "Deploy the app's config & more (v2)" \
  -V 1.2.3-rc1 -o "$temp_file" -f)" 'the script is generated' || true
declare -i help_rc=0
out=$(bash -- "$temp_file" --help 2>&1) || help_rc=$?
assert_equal 0 "$help_rc" 'its --help exits 0' || true
assert_contains "$out" "Deploy the app's config & more (v2)" 'description shown by --help' || true
assert_contains "$out" 1.2.3-rc1 'version shown by --help' || true

print_summary 'template'
#fin
