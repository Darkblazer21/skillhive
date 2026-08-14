#!/usr/bin/env bash
#
# hooks/pre-commit-review.sh
#
# ─────────────────────────────────────────────────────────────────────────
# WHAT
#   Fast pre-commit guardrail - blocks commits only on:
#     1. Hardcoded secrets in the staged diff (A07)
#
#   `.env.example`, `.env.sample`, and `docker-compose*.yml` are
#   excluded from this check - by convention these hold placeholder or
#   local-dev-only values (e.g. `postgres:postgres@localhost`), never a
#   real secret. A real `.env` is not excluded and stays fully scanned.
#
#   This is intentionally NOT a full OWASP review. The full checklist
#   (A01–A10) is deferred to the /security-review command (run manually
#   or in CI on the PR), where it has the full diff context and won't
#   slow down every micro-commit. See security-owasp/SKILL.md § "Review
#   scope - match the diff surface" for the rationale.
#
#   Commit-message format is NOT checked here - Git only exposes the
#   commit message to the `commit-msg` hook, not `pre-commit` (the
#   message doesn't exist yet at this stage). That check lives in the
#   companion hook `hooks/commit-msg-review.sh`.
#
#   No agent is invoked here - grep + regex are faster and more
#   deterministic for the check that matters before every commit.
#
# WHEN
#   Fires on the "before commit" event, installed as `.git/hooks/pre-commit`.
#   Never invoked manually - use /security-review for the full OWASP pass
#   instead.
#
# WHO
#   Uses security-owasp A07 (secrets) as reference. No agent required
#   for this fast path.
#
# BEHAVIOR / BLOCKING RULE
#   - Exit code 0  -> commit proceeds.
#   - Exit code != 0 -> commit is aborted; blocking points are printed
#     to stderr.
#   - This hook only reviews. It never modifies the diff to "fix" a
#     blocking point itself.
#
# PREREQUISITES
#   - OpenCode CLI must be installed for /security-review (not needed
#     for this hook itself - all checks here are plain bash).
#
# INSTALLATION
#   This hook must be installed as `.git/hooks/pre-commit`. It is one of
#   two companion hooks - see `hooks/commit-msg-review.sh` for the
#   commit-message format check, installed as `.git/hooks/commit-msg`.
#   Both must be installed for full coverage; installing only this one
#   still gives you the secrets check.
#
# PORTABILITY
#   This script contains zero harness-specific code. It runs as a plain
#   pre-commit hook in git (via .git/hooks/pre-commit), and the same
#   logic works regardless of Claude Code / Codex CLI / OpenCode.
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────
# CHECK - Secrets in staged diff (OWASP A07)
# ─────────────────────────────────────────────────────────────────────────
# Looks for high-signal patterns that indicate a secret or credential
# was added to version control. This is a fast grep pass, not a
# guarantee of no secrets - the full /security-review command runs a
# deeper check before merge.
#
# Files that exist BY CONVENTION to hold placeholder/local-dev values
# (never a real secret - that's their entire purpose) are excluded from
# this check. A real `.env` is not on this list and stays fully
# scanned - it should also be gitignored, which is a separate control,
# not a substitute for this one.
TEMPLATE_PATH_REGEX='(^|/)(\.env\.example|\.env\.sample|docker-compose(\.[a-zA-Z0-9_-]+)?\.ya?ml)$'

STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACM)"
SCAN_FILES="$(echo "$STAGED_FILES" | grep -vE "$TEMPLATE_PATH_REGEX" || true)"

if [[ -z "$SCAN_FILES" ]]; then
  exit 0
fi

DIFF="$(git diff --cached -- $(echo "$SCAN_FILES" | tr '\n' ' '))"

if [[ -z "$DIFF" ]]; then
  exit 0
fi

SECRET_PATTERNS=(
  # Constraint on every pattern below: it must not match its own
  # literal source text, since this file is itself committed to every
  # project that includes hooks/ - a pattern permissive enough to match
  # its own regex syntax (e.g. an earlier version of the postgresql://
  # rule) blocks the hook from ever committing itself. Sanity-check any
  # new/edited pattern with:
  #   echo '<pattern>' | grep -nP -- '<pattern>'   # must NOT match
  'password\s*[:=]\s*["'\''"].+["'\''"]'
  'api[_-]?key\s*[:=]\s*["'\''"].+["'\''"]'
  'secret\s*[:=]\s*["'\''"].+["'\''"]'
  'token\s*[:=]\s*["'\''"].+["'\''"]'
  '-----BEGIN\s+(RSA|EC|DSA|PGP|OPENSSH)\s+PRIVATE\s+KEY-----'
  'ghp_[A-Za-z0-9]{36}'
  'gho_[A-Za-z0-9]{36}'
  'sk-[A-Za-z0-9]{20,}'
  'postgresql://[A-Za-z0-9_.-]+:[^@]+@'
  'AKIA[0-9A-Z]{16}'
)

BLOCKED=0

for pattern in "${SECRET_PATTERNS[@]}"; do
  if echo "$DIFF" | grep -nP -- "$pattern" | grep -v '^---' | grep -v '^\+\+\+' > /dev/null 2>&1; then
    echo "pre-commit-review: BLOCKED - possible hardcoded secret detected (pattern: ${pattern})" >&2
    echo "pre-commit-review: Run /security-review to investigate or confirm it is a false positive." >&2
    BLOCKED=1
  fi
done

# ─────────────────────────────────────────────────────────────────────────
# EXIT
# ─────────────────────────────────────────────────────────────────────────
if [[ "$BLOCKED" -eq 1 ]]; then
  echo "" >&2
  echo "Fix the points above and re-commit. This hook never auto-fixes." >&2
  echo "For a full OWASP review, run /security-review (or the equivalent" >&2
  echo "command for your harness) before merging." >&2
  exit 1
fi

exit 0