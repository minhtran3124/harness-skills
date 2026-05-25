#!/bin/bash
# UserPromptSubmit hook: warn when an implementation-intent prompt has no plan referenced.
# Non-blocking — injects additionalContext, never denies.

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // ""')
WORD_COUNT=$(printf '%s' "$PROMPT" | wc -w)

IS_IMPL=0
printf '%s' "$PROMPT" | grep -qiE '\b(add|implement|refactor|build|create|fix|change|improve|migrat|integrat)\b' && IS_IMPL=1

HAS_PLAN=0
printf '%s' "$PROMPT" | grep -qiE 'specs/|\bplan\b' && HAS_PLAN=1

if [ "$WORD_COUNT" -gt 6 ] && [ "$IS_IMPL" -eq 1 ] && [ "$HAS_PLAN" -eq 0 ]; then
  jq -cn '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: "Implementation-intent request with no plan referenced. Run /feature-intake to set the lane. Tiny lane → proceed with a direct edit (no confirmation needed). Normal/high-risk → produce a plan first. Pause for the human only if the direction is ambiguous, confidence is low, or a hard gate fires (auth/authz/data-loss/migration/audit/external-provider/public-contract/high-blast file)."
    }
  }'
fi
