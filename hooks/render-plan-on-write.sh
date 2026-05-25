#!/bin/bash
# PostToolUse(Write|Edit): auto-render specs/<slug>/PLAN.md -> PLAN.html (deterministic, no LLM).
# Non-blocking: every edge case exits 0. Won't loop (it writes PLAN.html, not PLAN.md).

command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

INPUT=$(cat /dev/stdin)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE" ] && exit 0

# Only act on a PLAN.md under specs/
case "$FILE" in
  */specs/*/PLAN.md|specs/*/PLAN.md) ;;
  *) exit 0 ;;
esac
[ -f "$FILE" ] || exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"
[ -z "$REPO_DIR" ] && REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RENDER="$REPO_DIR/skills/visual-planner/render_plan.py"
[ -f "$RENDER" ] || exit 0

OUT=$(python3 "$RENDER" "$FILE" 2>&1)
if [ $? -eq 0 ]; then
  HTML=$(printf '%s' "$OUT" | grep -oE '/[^ ]*PLAN\.html' | head -1)
  jq -cn --arg h "$HTML" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("🖼️ PLAN.html auto-rendered: " + $h)}}'
else
  jq -cn --arg o "$OUT" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:("⚠️ PLAN.html render failed:\n" + $o)}}'
fi
exit 0
