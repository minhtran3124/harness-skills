#!/bin/bash
# PreToolUse hook: block git commit/push if untracked .py files exist.
# Prevents CI failures from missing imports.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')

case "$CMD" in
  *"git commit"*|*"git push"*)
    FILES=$(git ls-files --others --exclude-standard 2>/dev/null | grep -E '\.py$' | grep -v '/\.claude/')
    if [ -n "$FILES" ]; then
      jq -cn --arg f "$FILES" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: ("Untracked .py not staged (would break CI imports):\n" + $f + "\n\nRun: git add <files> — or gitignore if intentional.")
        }
      }'
    fi
    ;;
esac
