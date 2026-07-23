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
work="$(mktemp -d)"
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

# Load the real functions with a clean environment.
load_real() { unset CLAUDE_CODE_DISABLE_TERMINAL_TITLE; source "$functions_file"; }

# load_real, then stub the collaborators for the launcher tests.
reset_env() {
  rm -f "$work/claude_args" "$work/claude_disable"
  load_real
  _set_terminal_title() { print -rn -- $'\033]0;'"$1"$'\007'; }  # emit unconditionally
  claude() {
    print -r -- "$*"                                     > "$work/claude_args"
    print -r -- "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}" > "$work/claude_disable"
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
assert_eq       "branch+name: title is session name" "$(osc 'my session')" "$(<$work/out)"
assert_eq       "branch+name: args passed"           "--worktree feat/foo -n my session" "$(<$work/claude_args)"
assert_eq       "branch+name: claude sees disable=1" "1" "$(<$work/claude_disable)"
assert_eq       "branch+name: no leak to parent shell" "" "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}"

reset_env
cw "feat/bar" > "$work/out"
assert_eq       "branch only: title falls back to branch" "$(osc 'feat/bar')" "$(<$work/out)"
assert_eq       "branch only: no -n flag"                 "--worktree feat/bar" "$(<$work/claude_args)"

# --- prbatch ---
print -- "prbatch:"

reset_env
prbatch --resume > "$work/out"
assert_eq       "title pinned to PR Code Reviews" "$(osc 'PR Code Reviews')" "$(<$work/out)"
assert_eq       "extra args passed through"       "--resume" "$(<$work/claude_args)"
assert_eq       "claude sees disable=1"           "1" "$(<$work/claude_disable)"
assert_eq       "no leak to parent shell"         "" "${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-}"

# --- summary ---
print -- ""
print -- "$tests_run run, $tests_failed failed"
(( tests_failed == 0 ))
