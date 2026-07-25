# functions.zsh - shell functions and helpers, kept separate from zshrc so they
# can be sourced in isolation by the test suite (see test/functions.test.zsh).
# Sourced from zshrc; contains no interactive-only setup, so it is safe to load
# in a non-interactive test shell with `claude` stubbed.

# Claude Code defaults: opus 4.8 (1M context) + medium effort. Pass extra flags to override.
claude() {
  command claude --model 'claude-opus-4-8[1m]' --effort medium "$@"
}
alias claude-high='command claude --model "claude-opus-4-8[1m]" --effort xhigh'
# claude-cheap: opus 4.6 opt-in cost mode. 4.6's old tokenizer uses up to ~35% fewer
# input tokens than 4.8 for the same fixed text - only worth it for high-volume,
# single-shot, large-fixed-input, non-fast workloads. For bulk cost-sensitive work,
# consider sonnet 4.6 ($3/$15) instead.
alias claude-cheap='command claude --model "claude-opus-4-6[1m]" --effort medium'

# _set_terminal_title <title> - set the terminal tab title via an OSC escape
# sequence, but only when stdout is a real terminal so the control bytes never
# leak into pipes or logs. Shared by the launchers below.
_set_terminal_title() {
  [[ -t 1 ]] && printf '\033]0;%s\007' "$1"
}

# prbatch [claude-args...] - launch Claude Code in a tab pinned to the title
# "PR Code Reviews". Intended for the tab that runs `claude agents` as the
# control tower over a batch of autonomous PR-review sessions.
#
# Why pin manually: Claude auto-titles each tab with a rolling conversation
# summary, so sibling Claude tabs drift and look alike. A fixed title keeps the
# control-tower tab findable in the tab bar. CLAUDE_CODE_DISABLE_TERMINAL_TITLE
# stops Claude from overwriting it; it is scoped to the claude invocation so it
# does not disable titles for later shell commands. `-n` can't help here: `claude
# agents` has no --name flag, so the manual escape sequence is the only way to
# label this tab.
#
# The Agent View is global (one shared supervisor); to see only one project's
# sessions, scope the viewer: `claude agents --cwd <path>`.
# e.g. prbatch    or    prbatch --resume
prbatch() {
  _set_terminal_title 'PR Code Reviews'
  CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 claude "$@"
}

# cw <branch> [session-name] - start claude in a new worktree
# cw chore/remove-grafanallm-dep
# cw chore/remove-grafanallm-dep "947 remove grafana llm"
cw() {
  if [[ -z "$1" ]]; then
    echo "usage: cw <branch> [session-name]" >&2
    return 1
  fi
  # Name the session after the worktree (or an explicit session name). Claude
  # drives the terminal tab title from --name and keeps it in sync with /rename,
  # so we let it own the title rather than pinning one with a printf escape +
  # CLAUDE_CODE_DISABLE_TERMINAL_TITLE (which froze the tab and blocked /rename).
  #
  # NOTE (VSCode): the tab only shows this if settings.json has
  # "terminal.integrated.tabs.title": "${sequence}". The default "${process}"
  # ignores the OSC title and renders the claude binary basename (its version).
  # If worktree tabs regress to a version number, that setting was dropped.
  claude --worktree "$1" -n "${2:-$1}"
}
