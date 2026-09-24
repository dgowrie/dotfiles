#!/usr/bin/env zsh
# Tests for shell/functions.zsh. Run: zsh test/functions.test.zsh
#
# Strategy: source functions.zsh in isolation, then override collaborators so
# nothing launches and effects are observable:
#   - `claude` is stubbed to record the args and env it was called with.
#   - `_set_terminal_title` is stubbed to emit unconditionally, so the chosen
#     title is observable even though the real helper gates on [[ -t 1 ]] and
#     the test's stdout is a file, not a TTY. The real helper's gate is covered
#     by its own section below.
# Functions are invoked with stdout redirected to a FILE (not a pipe) so they
# run in THIS shell and the parent-scope effects (or absence of them) are visible.

emulate -L zsh

script_dir="${${(%):-%x}:A:h}"
functions_file="${script_dir:h}/shell/functions.zsh"

typeset -g tests_run=0 tests_failed=0
# Explicit template: portable across GNU and every BSD/macOS mktemp.
work="$(mktemp -d "${TMPDIR:-/tmp}/functions-test.XXXXXX")"
[[ -d "$work" ]] || { print -u2 -- "FATAL: could not create temp dir"; exit 1; }
trap 'rm -rf "$work"' EXIT

# --- tiny assertion helpers ---
pass() { tests_run=$((tests_run + 1)); print -r -- "  ok   - $1"; }
fail() {
  tests_run=$((tests_run + 1)); tests_failed=$((tests_failed + 1))
  print -r -- "  FAIL - $1"
  [[ -n "${2:-}" ]] && print -r -- "         expected: $2"
  [[ -n "${3:-}" ]] && print -r -- "         actual:   $3"
}
assert_eq()       { [[ "$2" == "$3" ]] && pass "$1" || fail "$1" "$2" "$3"; }
assert_contains() { [[ "$3" == *"$2"* ]] && pass "$1" || fail "$1" "*$2*" "$3"; }

osc() { print -rn -- $'\033]0;'"$1"$'\007'; }  # expected title escape sequence
# Render an argv as one line per argument, so assertions verify argument
# boundaries (e.g. a session name with spaces stays a single argument) rather
# than a space-joined blob where "a b" and "a" "b" look identical.
argv() { print -rl -- "$@"; }

# Load the real functions with a clean environment.
load_real() { unset CLAUDE_CODE_DISABLE_TERMINAL_TITLE; source "$functions_file"; }

# load_real, then stub the collaborators for the launcher tests.
reset_env() {
  rm -f "$work/claude_args" "$work/claude_disable"
  load_real
  _set_terminal_title() { print -rn -- $'\033]0;'"$1"$'\007'; }  # emit unconditionally
  claude() {
    print -rl -- "$@"                                    > "$work/claude_args"
    print -r  -- "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" > "$work/claude_disable"
  }
}

# --- _set_terminal_title (real helper: TTY gate) ---
print -- "_set_terminal_title:"

load_real
_set_terminal_title "anything" > "$work/out"   # stdout is a file, not a TTY
assert_eq "suppressed when stdout is not a TTY" "" "$(<$work/out)"

# --- cw ---
print -- "cw:"

reset_env
cw > "$work/out" 2>"$work/err" && rc=0 || rc=$?
assert_eq        "no args returns 1"              "1" "$rc"
assert_contains  "no args prints usage to stderr" "usage: cw <branch>" "$(<$work/err)"
[[ ! -f "$work/claude_args" ]] && pass "no args does not launch claude" \
  || fail "no args does not launch claude" "claude not called" "claude called"

reset_env
cw "feat/foo" "my session" > "$work/out"
assert_eq       "branch+name: no title emitted (claude owns it)" "" "$(<$work/out)"
assert_eq       "branch+name: session name passed as one arg" "$(argv --worktree feat/foo -n 'my session')" "$(<$work/claude_args)"
assert_eq       "branch+name: does not disable claude's title" "" "$(<$work/claude_disable)"
assert_eq       "branch+name: no leak to parent shell" "" "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}"

reset_env
cw "feat/bar" > "$work/out"
assert_eq       "branch only: no title emitted (claude owns it)" "" "$(<$work/out)"
assert_eq       "branch only: name defaults to branch"    "$(argv --worktree feat/bar -n feat/bar)" "$(<$work/claude_args)"

# --- prbatch ---
print -- "prbatch:"

reset_env
prbatch --resume > "$work/out"
assert_eq       "title pinned to PR Code Reviews" "$(osc 'PR Code Reviews')" "$(<$work/out)"
assert_eq       "extra args passed through"       "$(argv --resume)" "$(<$work/claude_args)"
assert_eq       "claude sees disable=1"           "1" "$(<$work/claude_disable)"
assert_eq       "no leak to parent shell"         "" "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}"

# --- claude launchers ---
# All three launchers invoke `command claude`, which bypasses shell functions
# and aliases, so the reset_env `claude()` stub cannot observe them. Intercept
# at the PATH level instead: a fake `claude` binary records the argv it was
# given, one per line, so model/effort flags and forwarded args are all visible.
print -- "claude launchers:"

launcher_bin="$work/bin"
mkdir -p "$launcher_bin"
print -r -- '#!/bin/sh'                                                 > "$launcher_bin/claude"
print -r -- 'for a in "$@"; do printf "%s\n" "$a"; done > "$FAKE_CLAUDE_ARGS"' >> "$launcher_bin/claude"
chmod +x "$launcher_bin/claude"

# Real functions + aliases (no claude() stub); fake claude first on PATH so
# `command claude` resolves to it. Aliases are invoked via eval so alias
# expansion happens at runtime, after functions.zsh has defined them.
launcher_env() {
  load_real
  export FAKE_CLAUDE_ARGS="$work/launch_args"
  rm -f "$FAKE_CLAUDE_ARGS"
  path=("$launcher_bin" $path)
}

launcher_env
claude one "two three" > "$work/out"
assert_eq "claude: opus 5.5 [1m] at high, args forwarded" \
  "$(argv --model 'claude-opus-5-5[1m]' --effort high one 'two three')" "$(<$work/launch_args)"

launcher_env
eval 'claude-high one "two three"' > "$work/out"
assert_eq "claude-high: opus 5.5 [1m] at xhigh, args forwarded" \
  "$(argv --model 'claude-opus-5-5[1m]' --effort xhigh one 'two three')" "$(<$work/launch_args)"

launcher_env
eval 'claude-cheap one "two three"' > "$work/out"
assert_eq "claude-cheap: opus 4.8 [1m] at medium, args forwarded" \
  "$(argv --model 'claude-opus-4-8[1m]' --effort medium one 'two three')" "$(<$work/launch_args)"

# cw calls bare `claude` (the launcher function), not `command claude`, so a
# real invocation inherits the default model/effort. The cw section above uses
# the reset_env stub and cannot see that; assert the full chain here against the
# real launcher: model/effort prepended, then cw's own --worktree/-n arguments.
launcher_env
cw feat/foo "my session" > "$work/out"
assert_eq "cw: passes through the real claude launcher (opus 5.5 [1m] at high) then worktree+name" \
  "$(argv --model 'claude-opus-5-5[1m]' --effort high --worktree feat/foo -n 'my session')" "$(<$work/launch_args)"

# --- summary ---
print -- ""
print -- "$tests_run run, $tests_failed failed"
(( tests_failed == 0 ))
