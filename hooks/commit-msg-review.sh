#!/usr/bin/env bash
#
# hooks/commit-msg-review.sh
#
# ─────────────────────────────────────────────────────────────────────────
# WHAT
#   Fast commit-msg guardrail - blocks commits only on:
#     1. Commit message not matching Conventional Commits format
#
#   This is intentionally NOT a full OWASP review. The full checklist
#   (A01–A10) is deferred to the /security-review command. See
#   security-owasp/SKILL.md § "Review scope - match the diff surface"
#   for the rationale.
#
#   Secrets scanning is NOT done here - that's the companion hook
#   `hooks/pre-commit-review.sh`, which runs earlier in the commit
#   lifecycle (Git's `pre-commit` event) with access to the staged diff.
#
#   No agent is invoked here - a single regex is faster and more
#   deterministic than an agent call for this check.
#
# WHEN
#   Fires on the "commit-msg" event, installed as `.git/hooks/commit-msg`.
#   This is the only Git hook that receives the path to the commit
#   message file as $1 - `pre-commit` does not, which is why this check
#   was split out of the old combined pre-commit-review.sh into its own
#   hook rather than kept as a same-hook fallback on `.git/COMMIT_EDITMSG`
#   (that fallback silently read the *previous* commit's message when
#   installed only as `pre-commit`).
#
# WHO
#   Uses git-conventions (commit format) as reference. No agent required
#   for this fast path.
#
# BEHAVIOR / BLOCKING RULE
#   - Exit code 0  -> commit proceeds.
#   - Exit code != 0 -> commit is aborted; blocking points are printed
#     to stderr.
#   - This hook only reviews. It never modifies the commit message to
#     "fix" a blocking point itself.
#
# INSTALLATION
#   This hook must be installed as `.git/hooks/commit-msg` (Git passes
#   the commit-message file path as $1 to this event - never to
#   `pre-commit`). It is one of two companion hooks - see
#   `hooks/pre-commit-review.sh` for the secrets check, installed as
#   `.git/hooks/pre-commit`. Both must be installed for full coverage.
#
# PORTABILITY
#   This script contains zero harness-specific code. It runs as a plain
#   commit-msg hook in git (via .git/hooks/commit-msg), and the same
#   logic works regardless of Claude Code / Codex CLI / OpenCode.
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────
# CHECK - Commit message format (Conventional Commits)
# ─────────────────────────────────────────────────────────────────────────
COMMIT_MSG_FILE="${1:?commit-msg-review: missing commit message file path (expected as \$1, the way Git passes it to the commit-msg hook)}"

if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
  echo "commit-msg-review: commit message file not found: ${COMMIT_MSG_FILE}" >&2
  exit 1
fi

COMMIT_MSG="$(head -1 "$COMMIT_MSG_FILE")"

BLOCKED=0

# Valid types: feat fix refactor test docs chore style perf ci build revert
if ! echo "$COMMIT_MSG" | grep -qP '^(feat|fix|refactor|test|docs|chore|style|perf|ci|build|revert)(\([a-z0-9_.-]+\))?:\s'; then
  echo "commit-msg-review: BLOCKED - commit message does not match Conventional Commits format" >&2
  echo "  Expected: <type>(<scope>): <description>" >&2
  echo "  Got:      ${COMMIT_MSG}" >&2
  echo "  Valid types: feat fix refactor test docs chore style perf ci build revert" >&2
  BLOCKED=1
fi

# ─────────────────────────────────────────────────────────────────────────
# EXIT
# ─────────────────────────────────────────────────────────────────────────
if [[ "$BLOCKED" -eq 1 ]]; then
  echo "" >&2
  echo "Fix the commit message above and re-commit. This hook never" >&2
  echo "auto-fixes." >&2
  exit 1
fi

exit 0