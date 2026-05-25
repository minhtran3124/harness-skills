#!/bin/bash
# PostToolUse hook: auto-run pytest when a test file is edited or written.
# Non-blocking — always exits 0. Prints feedback to STDERR.
# No set -e: this hook handles errors explicitly and never blocks.

# Parse the file path from stdin JSON (Edit and Write both have tool_input.file_path)
INPUT=$(cat /dev/stdin)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Skip if no file path extracted or jq failed
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only act on Python test files under tests/
if [[ "$FILE_PATH" != */tests/* ]] || [[ "$FILE_PATH" != *.py ]]; then
  exit 0
fi

# Only act on files matching test_*.py pattern
BASENAME=$(basename "$FILE_PATH")
if [[ "$BASENAME" != test_*.py ]]; then
  exit 0
fi

# Resolve the API directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
API_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Verify the test file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Run pytest on the specific test file — lightweight flags, no coverage
echo "[AUTO-TEST] Running: $BASENAME" >&2
OUTPUT=$(cd "$API_DIR" && python -m pytest "$FILE_PATH" -x -q --tb=short --no-header --no-cov -p no:cacheprovider 2>&1) || true
RESULT=$?

# Show compact output (last 15 lines to capture summary + any failures)
echo "$OUTPUT" | tail -15 >&2

if [[ $RESULT -eq 0 ]]; then
  echo "[AUTO-TEST] PASSED" >&2
else
  echo "[AUTO-TEST] FAILED (exit code $RESULT)" >&2
fi

# Always exit 0 — this hook is informational, never blocks
exit 0
