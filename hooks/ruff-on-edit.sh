#!/bin/bash
# PostToolUse hook: run ruff --fix + ruff format on any edited .py file.
# Non-blocking — always exits 0.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty')

case "$FILE" in
  *.py)
    [ -f "$FILE" ] && { ruff check --fix "$FILE"; ruff format "$FILE"; } >/dev/null 2>&1 || true
    ;;
esac
