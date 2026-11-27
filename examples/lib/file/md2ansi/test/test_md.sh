#!/usr/bin/env bash
# Tests for md — pagination wrapper around md2ansi
# This file is sourced by run_tests

test_section "md (pagination wrapper)"

# --------------------------------------------------------------------------------
# Version / help: md answers these itself rather than passing them to md2ansi

output=$(./md --version 2>&1)
assert_equals "md 1.0.0" "$output" "md --version reports the wrapper's own version"
assert_exit_code 0 "./md --version" "md --version exits 0"

output=$(./md --help 2>&1)
assert_contains "$output" "Wrapper for md2ansi" "md --help shows the wrapper's own usage"
assert_exit_code 0 "./md --help" "md --help exits 0"

# --------------------------------------------------------------------------------
# Stdin pipeline (less -F auto-quits on short input when stdout is not a tty)

output=$(echo "# Hello" | ./md 2>&1)
assert_contains "$output" "Hello" "md stdin pipeline renders"

output=$(printf '# Hi' | ./md 2>&1)
assert_exit_code 0 "printf '# Hi' | ${PROJECT_DIR}/md" "md stdin-only invocation exits 0"

# --------------------------------------------------------------------------------
# File argument

output=$(./md README.md 2>&1)
assert_not_empty "$output" "md README.md produces output"
assert_contains "$output" "md2ansi" "md README.md contains expected content"

# --------------------------------------------------------------------------------
# Error propagation from md2ansi

assert_exit_code 3 "./md /nonexistent/file.md 2>&1" "md propagates exit 3 on missing file"

# --------------------------------------------------------------------------------
# LESS env var is exported by the wrapper (verify via static grep — sourcing
# would run the pipeline)

assert_contains "$(grep -E '^export LESS' md)" "-FXRS" "md exports LESS=-FXRS"

#fin
