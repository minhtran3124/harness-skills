#!/bin/bash
# Integration test for scripts/deploy-harness.sh — covers migrate_plugin_shipped, the only
# destructive path in the plugin-packaging change. A (re-)deploy must PRUNE harness-owned
# skills/agents that an older flat install left in the target .claude/, while PRESERVING
# foreign user-installed entries, and still deploy the governance layer.
source "$(dirname "$0")/../lib.sh"

DEPLOY="$ROOT/scripts/deploy-harness.sh"

t "deploy prunes harness-owned skills/agents, preserves foreign entries, deploys governance"
tgt=$(mktemp -d); _CLEANUP_DIRS+=("$tgt")

# Simulate a prior flat install: harness-owned + foreign entries already under .claude/.
mkdir -p "$tgt/.claude/skills/compound"               # harness-owned (exists in ROOT/skills/)
echo x > "$tgt/.claude/skills/compound/SKILL.md"
mkdir -p "$tgt/.claude/skills/zzz-foreign-skill"      # foreign (NOT in ROOT/skills/)
echo x > "$tgt/.claude/skills/zzz-foreign-skill/SKILL.md"
mkdir -p "$tgt/.claude/agents"
echo x > "$tgt/.claude/agents/coding.md"              # harness-owned (exists in ROOT/agents/)
echo x > "$tgt/.claude/agents/zzz-foreign-agent.md"   # foreign

bash "$DEPLOY" --target "$tgt" >/dev/null 2>&1; rc=$?

if [ "$rc" -eq 0 ] \
   && [ ! -e "$tgt/.claude/skills/compound" ] \
   && [ -d "$tgt/.claude/skills/zzz-foreign-skill" ] \
   && [ ! -e "$tgt/.claude/agents/coding.md" ] \
   && [ -e "$tgt/.claude/agents/zzz-foreign-agent.md" ] \
   && [ -d "$tgt/.claude/hooks" ] && [ -f "$tgt/.claude/settings.json" ]; then
  pass
else
  fail "rc=$rc — skills:[$(ls "$tgt/.claude/skills" 2>/dev/null | tr '\n' ' ')] agents:[$(ls "$tgt/.claude/agents" 2>/dev/null | tr '\n' ' ')]"
fi

finish
