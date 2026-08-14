#!/usr/bin/env bash
#
# hooks/install.sh
#
# Installs every hook in this folder correctly, including the case where
# more than one script reacts to the same git event (pre-commit). Git
# only allows a single file named `.git/hooks/pre-commit` - this script
# writes that single file as a dispatcher that calls every pre-commit
# check in this folder in sequence, rather than one script silently
# overwriting another.
#
# Run once per repo, from the repo root:
#   bash hooks/install.sh
#
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_SRC="$REPO_ROOT/hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

if [[ ! -d "$HOOKS_SRC" ]]; then
  echo "install.sh: no hooks/ folder found at $HOOKS_SRC" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────
# pre-commit dispatcher - calls every *-review.sh / *-lint.sh script
# meant for this event, in a fixed, predictable order. Add a new
# pre-commit-type check by dropping it in hooks/ and adding its name to
# PRE_COMMIT_CHECKS below - never by copying it directly over
# .git/hooks/pre-commit, which would silently replace this dispatcher.
# ─────────────────────────────────────────────────────────────────────────
PRE_COMMIT_CHECKS=(
  "pre-commit-review.sh"
  "prose-pattern-lint.sh"
)

{
  echo '#!/usr/bin/env bash'
  echo 'set -e'
  echo 'REPO_ROOT="$(git rev-parse --show-toplevel)"'
  for check in "${PRE_COMMIT_CHECKS[@]}"; do
    echo "if [[ -f \"\$REPO_ROOT/hooks/$check\" ]]; then"
    echo "  \"\$REPO_ROOT/hooks/$check\" || exit 1"
    echo "fi"
  done
} > "$HOOKS_DST/pre-commit"
chmod +x "$HOOKS_DST/pre-commit"
echo "installed: .git/hooks/pre-commit -> dispatches to ${PRE_COMMIT_CHECKS[*]}"

# ─────────────────────────────────────────────────────────────────────────
# commit-msg - only one check today, direct copy is safe. If a second
# commit-msg-type check is ever added, apply the same dispatcher pattern
# as above instead of overwriting.
# ─────────────────────────────────────────────────────────────────────────
if [[ -f "$HOOKS_SRC/commit-msg-review.sh" ]]; then
  cp "$HOOKS_SRC/commit-msg-review.sh" "$HOOKS_DST/commit-msg"
  chmod +x "$HOOKS_DST/commit-msg"
  echo "installed: .git/hooks/commit-msg -> commit-msg-review.sh"
fi

echo "done."