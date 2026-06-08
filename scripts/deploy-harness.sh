#!/bin/bash
# Clone the Claude Code setup from the repo root (the source) into .claude/, which is where
# Claude Code actually loads project skills, agents, and hooks. The root dirs stay the source
# of truth; .claude/ is a derived copy (gitignored).
#
# Idempotent — supports both a FIRST-TIME install and a RE-SYNC (update). Re-run after editing
# anything under skills/ agents/ hooks/ rules/ settings.json.
#
# Usage:  bash scripts/deploy-harness.sh
set -e

ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/.." && pwd))"
cd "$ROOT"

# ---------- styling (colors only on a TTY) ----------
if [ -t 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
  G=$'\033[32m'; C=$'\033[36m'; Y=$'\033[33m'; M=$'\033[35m'
else
  B=; D=; R=; G=; C=; Y=; M=
fi
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# step "label" command...  → animate a spinner, run the work, replace with a ✓
step() {
  local label="$1"; shift
  if [ -t 1 ]; then
    local i frame
    for i in 1 2 3 4 5 6 7 8; do
      frame="${SPIN[$(((i-1)%${#SPIN[@]}))]}"
      printf "\r  ${C}%s${R}  %s" "$frame" "$label"
      sleep 0.045
    done
    "$@"
    printf "\r  ${G}✓${R}  %s%*s\n" "$label" 6 ""
  else
    "$@"
    printf "  - %s\n" "$label"
  fi
}
trap 'printf "\r  '"$([ -t 1 ] && printf '\033[31m')"'✗'"$([ -t 1 ] && printf '\033[0m')"'  step failed\n" >&2' ERR

# ---------- work units ----------
prep_dir()        { mkdir -p .claude; }
# Merge-sync source dir $1 into .claude/$1. Only entries the harness ships are
# removed + recopied; foreign entries already in .claude/$1 (e.g. skills the user
# installed separately) are left untouched. A wholesale `rm -rf .claude/$1` would
# delete those non-harness entries — this is deliberately per-entry instead.
copy_dir()        {
  mkdir -p ".claude/$1"
  for entry in "$1"/* "$1"/.[!.]*; do
    [ -e "$entry" ] || continue
    rm -rf ".claude/$1/$(basename "$entry")"
    cp -R "$entry" ".claude/$1/"
  done
}
strip_archive()   { rm -rf .claude/skills/_archive; }   # archived skills must not register as live
derive_settings() {
  # Point relative hook commands at the deployed .claude/ copies via $CLAUDE_PROJECT_DIR so they
  # resolve from any launch directory. Absolute / $-prefixed commands are left untouched.
  jq '.hooks |= with_entries(.value |= map(.hooks |= map(.command |= (
        if (startswith("$") or startswith("/")) then . else "$CLAUDE_PROJECT_DIR/.claude/" + . end
      ))))' settings.json > .claude/settings.json
}

# ---------- mode detection: first install vs re-sync ----------
if [ -d .claude ] && [ -e .claude/settings.json ]; then
  MODE="update";  MODE_LABEL="Re-syncing harness (update)"; MODE_EMOJI="🔄"
else
  MODE="install"; MODE_LABEL="First-time install";          MODE_EMOJI="✨"
fi

printf "\n  ${B}${M}🧙 claude-skills harness${R} ${D}→ .claude/${R}\n"
printf "  ${MODE_EMOJI}  ${B}%s${R}\n\n" "$MODE_LABEL"

# ---------- pipeline ----------
step "Preparing ${B}.claude/${R}"            prep_dir
for d in skills agents hooks rules templates; do
  [ -e "$d" ] || continue
  step "Syncing ${B}$d/${R}"                 copy_dir "$d"
done
step "Stripping archived skills"             strip_archive
step "Deriving ${B}settings.json${R} ${D}(hook paths)${R}" derive_settings

# ---------- summary ----------
SK=$(ls -d .claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
AG=$(ls .claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
HK=$(ls .claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')
RL=$(ls .claude/rules/*.md 2>/dev/null | wc -l | tr -d ' ')

printf "\n  ${G}${B}✓ Harness deployed${R}  ${D}(%s)${R}\n" "$MODE"
printf "  ${D}├─${R} 🎯 skills    ${B}%s${R}\n" "$SK"
printf "  ${D}├─${R} 🤖 agents    ${B}%s${R}\n" "$AG"
printf "  ${D}├─${R} 🪝 hooks     ${B}%s${R}\n" "$HK"
printf "  ${D}└─${R} 📜 rules     ${B}%s${R}  ${D}(+ settings.json)${R}\n" "$RL"
printf "\n  ${Y}↻ Restart Claude Code in this repo so it loads them.${R}\n\n"
