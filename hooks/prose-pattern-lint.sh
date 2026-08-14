#!/usr/bin/env bash
#
# hooks/prose-pattern-lint.sh
#
# ─────────────────────────────────────────────────────────────────────────
# WHAT
#   Fast pre-commit guardrail - blocks commits only on mechanically
#   detectable AI writing tics in staged deliverable text:
#     1. Em dash used as a systematic substitute for normal punctuation
#     2. An explicit list of banned hollow phrases (any single occurrence)
#     3. Emoji used as a list-bullet marker (any single occurrence)
#     4. Structural tics repeated 2+ times in the same diff: the
#        "it's not just X, it's Y" reversal, school-essay transitions
#        used as default paragraph openers, hollow three-item triads
#
#   This is layer 2 of a three-layer mechanism - see
#   prose-conventions/SKILL.md § "How this plugs into the rest of the
#   workflow" for layers 1 and 3. Layer 1 (the skill, loaded at
#   generation time) avoids most tics before they're written; this hook
#   catches only what slips past it, through pattern-matching alone - no
#   agent, no reasoning, no hallucination risk. Layer 3 (Design Critic,
#   extended scope) covers what neither of the first two can: a
#   paragraph that reads as generic with no single isolatable tell,
#   judged only on high-stakes deliverables (portfolio, Flagship tier).
#
#   Single occurrences of a *structural* tic (triad, reversal,
#   transition-as-opener) are never blocked here - one instance can be a
#   legitimate stylistic choice; it is the repetition across the same
#   diff that is the mechanical signal this hook is built to catch.
#   Banned phrases and emoji-as-bullet are the exception: any single
#   occurrence blocks, because there is no legitimate version of either.
#
# WHEN
#   Fires on the "before commit" event, installed as `.git/hooks/
#   pre-commit`, alongside the existing `pre-commit-review.sh` (secrets)
#   - both run at the same event and are independent, non-overlapping
#   checks. Only runs against staged files whose extension marks them as
#   deliverable prose (`.md`, `.mdx`, `.html`, `.txt`) - this is
#   deliberately broad (design briefs, portfolio content, client copy,
#   any agent/skill documentation) rather than scoped only to
#   `design/**`, per prose-conventions' own scope: any agent writing text
#   meant for a human, not only Design Director.
#
# WHO
#   Uses prose-conventions (the tic list and the alternative for each) as
#   reference. No agent required for this fast path - that is the whole
#   point of layer 2.
#
# BEHAVIOR / BLOCKING RULE
#   - Exit code 0  -> commit proceeds.
#   - Exit code != 0 -> commit is aborted; blocking points are printed
#     to stderr.
#   - This hook only reviews. It never rewrites the flagged text itself.
#   - Checks run against the staged diff's *added* lines only, with
#     fenced code blocks (``` ... ```) stripped first, so code samples
#     inside documentation are never scanned as prose.
#
# PREREQUISITES
#   - `grep -P` (PCRE) support, already assumed elsewhere in this repo's
#     hooks (see pre-commit-review.sh). The emoji-range check additionally
#     needs a UTF-8 locale available as `C.utf8` for the `\x{...}`
#     codepoint syntax to resolve multi-byte characters correctly - on a
#     system without it, that single check silently won't fire; the
#     other three checks are plain byte-level patterns and are
#     unaffected.
#
# INSTALLATION
#   This hook must be installed as `.git/hooks/pre-commit`. It is a
#   companion to `hooks/pre-commit-review.sh` (secrets) and
#   `hooks/commit-msg-review.sh` (commit message format) - all three can
#   coexist as the same `pre-commit`/`commit-msg` hooks; none overlaps
#   another's check.
#
# PORTABILITY
#   This script contains zero harness-specific code. It runs as a plain
#   pre-commit hook in git (via .git/hooks/pre-commit), and the same
#   logic works regardless of Claude Code / Codex CLI / OpenCode.
# ─────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────
# SETUP - collect staged deliverable-text files and their added lines
# ─────────────────────────────────────────────────────────────────────────
PROSE_EXT_REGEX='\.(md|mdx|html|txt)$'

mapfile -t PROSE_FILES < <(git diff --cached --name-only --diff-filter=ACM | grep -E "$PROSE_EXT_REGEX" || true)

if [[ "${#PROSE_FILES[@]}" -eq 0 ]]; then
  exit 0
fi

# Added lines only (diff '+' lines, header excluded), fenced code blocks
# stripped so code samples are never scanned as prose.
ADDED_TEXT="$(
  { git diff --cached -- "${PROSE_FILES[@]}" \
      | grep -E '^\+' \
      | grep -vE '^\+\+\+' \
      | sed 's/^\+//' \
      | awk '/^```/ { in_block = !in_block; next } !in_block { print }'
  } || true
)"

if [[ -z "$ADDED_TEXT" ]]; then
  exit 0
fi

BLOCKED=0

# ─────────────────────────────────────────────────────────────────────────
# CHECK 1 - Em dash as a systematic substitute for normal punctuation
# ─────────────────────────────────────────────────────────────────────────
EM_DASH_COUNT="$( { LC_ALL=C.utf8 grep -oP '\x{2014}' <<< "$ADDED_TEXT" 2>/dev/null || true; } | wc -l | tr -d ' ')"
WORD_COUNT="$(wc -w <<< "$ADDED_TEXT" | tr -d ' ')"

if [[ "$WORD_COUNT" -gt 0 ]]; then
  # More than ~1 em dash per 120 added words, and more than 3 in
  # absolute terms, is treated as systematic substitution rather than
  # occasional legitimate emphasis or a genuine aside.
  DENSITY_THRESHOLD=$(( WORD_COUNT / 120 + 1 ))
  if [[ "$EM_DASH_COUNT" -gt "$DENSITY_THRESHOLD" ]] && [[ "$EM_DASH_COUNT" -gt 3 ]]; then
    echo "prose-pattern-lint: BLOCKED - em dash used ${EM_DASH_COUNT} times across ${WORD_COUNT} added words" >&2
    echo "  This reads as a default substitute for normal punctuation rather" >&2
    echo "  than occasional emphasis. See prose-conventions.md §1." >&2
    BLOCKED=1
  fi
fi

# ─────────────────────────────────────────────────────────────────────────
# CHECK 2 - Explicit banned phrase list (any single occurrence blocks -
# there is no legitimate version of these)
# ─────────────────────────────────────────────────────────────────────────
BANNED_PHRASES=(
  "it is important to note that"
  "il est important de noter que"
  "innovative and powerful solution"
  "solution innovante et puissante"
  "cutting-edge solution"
  "solution de pointe"
  "game-changing"
)

for phrase in "${BANNED_PHRASES[@]}"; do
  if grep -qiF -- "$phrase" <<< "$ADDED_TEXT"; then
    echo "prose-pattern-lint: BLOCKED - banned hollow phrase found: \"${phrase}\"" >&2
    echo "  See prose-conventions.md §6 for what to write instead." >&2
    BLOCKED=1
  fi
done

# ─────────────────────────────────────────────────────────────────────────
# CHECK 3 - Emoji used as a list-bullet marker (any occurrence blocks -
# this never substitutes for real typographic hierarchy)
# ─────────────────────────────────────────────────────────────────────────
if LC_ALL=C.utf8 grep -qP '^[[:space:]]*[-*>]?[[:space:]]*[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}][[:space:]]' <<< "$ADDED_TEXT" 2>/dev/null; then
  echo "prose-pattern-lint: BLOCKED - emoji used as a list marker instead of real typographic hierarchy" >&2
  echo "  See prose-conventions.md §5." >&2
  BLOCKED=1
fi

# ─────────────────────────────────────────────────────────────────────────
# CHECK 4 - Structural tics: one instance can be legitimate style; two
# or more in the same diff is the repeated pattern this hook exists to
# catch (see prose-conventions.md §2-4 for the alternative to each)
# ─────────────────────────────────────────────────────────────────────────
NOT_JUST_COUNT="$(grep -ciP "(it'?s|ce n'?est) (not|pas) (just|juste)\b.{0,40}(it'?s|c'?est)\b" <<< "$ADDED_TEXT" 2>/dev/null || true)"
NOT_JUST_COUNT="${NOT_JUST_COUNT:-0}"
if [[ "$NOT_JUST_COUNT" -ge 2 ]]; then
  echo "prose-pattern-lint: BLOCKED - \"it's not just X, it's Y\" structure repeated ${NOT_JUST_COUNT} times" >&2
  echo "  See prose-conventions.md §2." >&2
  BLOCKED=1
fi

TRANSITION_COUNT="$(grep -ciP '^[[:space:]]*(en outre|de plus|furthermore|moreover)\b' <<< "$ADDED_TEXT" 2>/dev/null || true)"
TRANSITION_COUNT="${TRANSITION_COUNT:-0}"
if [[ "$TRANSITION_COUNT" -ge 2 ]]; then
  echo "prose-pattern-lint: BLOCKED - school-essay transition used as a default paragraph opener ${TRANSITION_COUNT} times" >&2
  echo "  See prose-conventions.md §4." >&2
  BLOCKED=1
fi

TRIAD_COUNT="$(grep -ciP '\b\w+, \w+,? (et|and) \w+\b' <<< "$ADDED_TEXT" 2>/dev/null || true)"
TRIAD_COUNT="${TRIAD_COUNT:-0}"
if [[ "$TRIAD_COUNT" -ge 2 ]]; then
  echo "prose-pattern-lint: BLOCKED - three-item rhetorical triad pattern (e.g. \"fast," >&2
  echo "  reliable, and scalable\") repeated ${TRIAD_COUNT} times with no specific content" >&2
  echo "  behind each term. See prose-conventions.md §3." >&2
  BLOCKED=1
fi

# ─────────────────────────────────────────────────────────────────────────
# EXIT
# ─────────────────────────────────────────────────────────────────────────
if [[ "$BLOCKED" -eq 1 ]]; then
  echo "" >&2
  echo "Fix the points above and re-commit. This hook never auto-fixes." >&2
  echo "For judgment calls this hook can't make mechanically (does a" >&2
  echo "paragraph just read as generic?), run /design-review or" >&2
  echo "/portfolio-review - that is layer 3 of this mechanism, not this hook." >&2
  exit 1
fi

exit 0