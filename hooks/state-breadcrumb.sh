#!/usr/bin/env bash
# SessionEnd hook: appends a dated breadcrumb entry to specs/STATE.md
# under the "## Session End Log" section. Idempotent per session_id.
# NEVER blocks: all errors result in silent exit 0.

set +e
set +u
set +o pipefail

# Rule 10: never write to stderr, never exit non-zero.
exec 2>/dev/null

# --- Read stdin JSON (if any) ---
STDIN_JSON=""
if [ ! -t 0 ]; then
    STDIN_JSON=$(cat 2>/dev/null || echo "")
fi

# Rule 2: jq missing -> silent exit 0.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# --- Rule 3: extract fields (// empty fallback) ---
SESSION_ID=$(printf '%s' "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null)
MATCHER_VALUE=$(printf '%s' "$STDIN_JSON" | jq -r '.matcher_value // empty' 2>/dev/null)
TRANSCRIPT_PATH=$(printf '%s' "$STDIN_JSON" | jq -r '.transcript_path // empty' 2>/dev/null)
CWD=$(printf '%s' "$STDIN_JSON" | jq -r '.cwd // empty' 2>/dev/null)

# No session_id -> nothing to log.
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

# --- Rule 4: resolve STATE.md ---
STATE_FILE=""
_candidates=()

if [ -n "$CLAUDE_PROJECT_DIR" ]; then
    _candidates+=("$CLAUDE_PROJECT_DIR/specs/STATE.md")
    _candidates+=("$CLAUDE_PROJECT_DIR/apps/api/specs/STATE.md")
fi

# Fallback when CLAUDE_PROJECT_DIR is unset: use stdin cwd.
if [ -z "$CLAUDE_PROJECT_DIR" ] && [ -n "$CWD" ]; then
    _candidates+=("$CWD/specs/STATE.md")
    _candidates+=("$CWD/apps/api/specs/STATE.md")
fi

for _c in "${_candidates[@]}"; do
    if [ -n "$_c" ] && [ -f "$_c" ]; then
        STATE_FILE="$_c"
        break
    fi
done

if [ -z "$STATE_FILE" ]; then
    exit 0
fi

# --- Rule 5: idempotency ---
if grep -qF "session_id: $SESSION_ID" "$STATE_FILE" 2>/dev/null; then
    exit 0
fi

# --- Rule 6: safe computations ---
LAST_COMMIT="n/a"
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
    _commit=$(cd "$CWD" 2>/dev/null && git log -1 --oneline 2>/dev/null)
    if [ -n "$_commit" ]; then
        LAST_COMMIT="$_commit"
    fi
fi

TURNS=0
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    _turns=$(grep -c '"role": "user"' "$TRANSCRIPT_PATH" 2>/dev/null)
    if [ -n "$_turns" ] && [ "$_turns" -ge 0 ] 2>/dev/null; then
        TURNS="$_turns"
    fi
fi

# --- Rule 7: ISO timestamp ---
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
if [ -z "$TS" ]; then
    exit 0
fi

# --- Rule 8: ensure "## Session End Log" section exists ---
if ! grep -qF "## Session End Log" "$STATE_FILE" 2>/dev/null; then
    # Append header with a blank line before it.
    {
        printf '\n## Session End Log\n'
    } >> "$STATE_FILE" 2>/dev/null || exit 0
fi

# --- Rule 9: append entry block ---
{
    printf '\n### %s\n' "$TS"
    printf -- '- session_id: %s\n' "$SESSION_ID"
    printf -- '- exit: %s\n' "$MATCHER_VALUE"
    printf -- '- last_commit: %s\n' "$LAST_COMMIT"
    printf -- '- user_turns: %s\n' "$TURNS"
    printf '\n'
} >> "$STATE_FILE" 2>/dev/null || exit 0

exit 0
