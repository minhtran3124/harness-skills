#!/bin/bash
# PostToolUse hook: auto-run the project's tests when a test file is edited or written.
# Ecosystem-aware — the harness is applied across projects, so the runner is detected
# from the edited file, not hard-coded:
#   Python  test_*.py / *_test.py            → pytest (python3 fallback; --no-cov only
#                                              when pytest-cov is installed)
#   JS/TS   *.test.* / *.spec.* / __tests__/ → vitest / jest / `npm test` — resolved from
#                                              the nearest package.json
#   Go      *_test.go                        → go test . (from the file's directory)
# Per-project override (e.g. in settings.json "env"):
#   AUTO_TEST_CMD='<command> {file}'  — replaces the detected runner for recognized
#                                       test files; {file} expands to the edited path.
#   AUTO_TEST_PATTERN='<glob>'        — with AUTO_TEST_CMD, extends coverage to an
#                                       ecosystem not listed above by matching the edited
#                                       file's basename (single glob, e.g. '*_spec.rb').
# Non-blocking — always exits 0. Prints feedback to STDERR.
# No set -e: this hook handles errors explicitly and never blocks.

# Parse the file path from stdin JSON (Edit and Write both have tool_input.file_path)
INPUT=$(cat /dev/stdin)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Skip if no file path extracted, jq failed, or the file does not exist
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")
FILE_DIR=$(dirname "$FILE_PATH")

# ---- classify: is this a test file, and which ecosystem? ----
ECO=""
if [[ -n "${AUTO_TEST_CMD:-}" && -n "${AUTO_TEST_PATTERN:-}" ]]; then
  # Custom ecosystem: the project declares its own test-file pattern + command
  case "$BASENAME" in
    ${AUTO_TEST_PATTERN}) ECO="custom" ;;
    *) exit 0 ;;
  esac
else
  case "$BASENAME" in
    test_*.py|*_test.py)                                          ECO="python" ;;
    *.test.js|*.test.jsx|*.test.ts|*.test.tsx)                    ECO="js" ;;
    *.spec.js|*.spec.jsx|*.spec.ts|*.spec.tsx)                    ECO="js" ;;
    *_test.go)                                                    ECO="go" ;;
    *.js|*.jsx|*.ts|*.tsx)
      case "$FILE_PATH" in
        */__tests__/*) ECO="js" ;;
        *) exit 0 ;;
      esac ;;
    *) exit 0 ;;
  esac
fi

# ---- find the project root: nearest ancestor holding one of the marker files ----
find_up() { # find_up <start-dir> <marker>...
  local d="$1"; shift
  while [[ "$d" != "/" && -n "$d" ]]; do
    local m
    for m in "$@"; do
      [[ -e "$d/$m" ]] && { echo "$d"; return 0; }
    done
    d=$(dirname "$d")
  done
  return 1
}

# ---- resolve the run directory + command ----
RUN_DIR="$FILE_DIR"
CMD=""
if [[ -n "${AUTO_TEST_CMD:-}" ]]; then
  # Per-project override beats detection. {file} expands to the edited file's path.
  CMD=${AUTO_TEST_CMD//\{file\}/"$FILE_PATH"}
  RUN_DIR=$(find_up "$FILE_DIR" package.json pyproject.toml go.mod .git) || RUN_DIR="$FILE_DIR"
else
  case "$ECO" in
    python)
      RUN_DIR=$(find_up "$FILE_DIR" pyproject.toml pytest.ini setup.cfg requirements.txt) || RUN_DIR="$FILE_DIR"
      PY_BIN="python"
      command -v python >/dev/null 2>&1 || PY_BIN="python3"
      COV_FLAG=""
      "$PY_BIN" -c 'import pytest_cov' 2>/dev/null && COV_FLAG="--no-cov"
      CMD="\"$PY_BIN\" -m pytest \"$FILE_PATH\" -x -q --tb=short --no-header $COV_FLAG -p no:cacheprovider"
      ;;
    js)
      RUN_DIR=$(find_up "$FILE_DIR" package.json) || exit 0
      PKG="$RUN_DIR/package.json"
      if jq -e '(.devDependencies.vitest // .dependencies.vitest)' "$PKG" >/dev/null 2>&1; then
        CMD="npx vitest run \"$FILE_PATH\""
      elif jq -e '(.devDependencies.jest // .dependencies.jest)' "$PKG" >/dev/null 2>&1; then
        CMD="npx jest \"$FILE_PATH\""
      elif jq -e '.scripts.test' "$PKG" >/dev/null 2>&1; then
        CMD="npm test --silent -- \"$FILE_PATH\""
      else
        exit 0  # no detectable runner — stay silent rather than guess
      fi
      ;;
    go)
      # `go test` resolves the module itself; run the file's package from its own dir
      CMD="go test ."
      ;;
  esac
fi
[[ -z "$CMD" ]] && exit 0

# ---- run + report ----
echo "[AUTO-TEST] ($ECO) Running: $BASENAME" >&2
OUTPUT=$(cd "$RUN_DIR" && eval "$CMD" 2>&1)
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
