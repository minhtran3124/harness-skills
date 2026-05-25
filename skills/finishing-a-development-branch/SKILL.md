---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Present options → Execute choice → Clean up.

**Announce at start:** "I'm using the finishing-a-development-branch skill to complete this work."

## The Process

### Step 1: Verify Tests

Invoke the **test-runner** sub-agent to run the test suite. Pass it the list of files changed on the current branch so it can target the minimal relevant test set.

#### 1a. Identify changed files

```bash
git diff --name-only $(git merge-base HEAD main)...HEAD -- '*.py'
```

Use these paths to determine which test files to run (e.g. changes to `app/repositories/user.py` → run `tests/repositories/test_user.py`).

#### 1b. Run tests

Launch the **test-runner** sub-agent with the targeted test files:

```bash
cd apps/api && python -m pytest <test_files> -x --tb=short -q
```

If no matching test files are found, fall back to the full suite:

```bash
cd apps/api && python -m pytest -x --tb=short -q
```

#### 1c. Report results

Present a structured summary:

```
Test Report
───────────────────────────────
Result:  ✅ N passed / ❌ N failed
Files:   tests/path/to/test_file.py, ...
Runner:  test-runner sub-agent
───────────────────────────────
```

#### 1d. Handle failures

- **All pass** → proceed to Step 2.
- **Failures** → report the tracebacks, attempt to fix the failing code, then re-invoke the test-runner to confirm the fix. Repeat up to **2 retries**. If tests still fail after retries, stop and ask the user how to proceed (fix manually, skip tests, or abort).

Do NOT skip this step. Never push code with failing tests.

### Step 2: Determine Base Branch

```bash
# Try common base branches
git merge-base HEAD main 2>/dev/null
```

Or ask: "This branch split from main - is that correct?"

### Step 3: Present Options

If the base branch is not mentioned in chat, auto assume it's `main`.

Present exactly these 4 options:

```
Implementation complete. What would you like to do?

1. Push to <current_branch>
2. Push and create a PR against <base_branch>
3. Keep the branch as-is (I'll handle it later)
4. Discard this work

Which option?
```

**Don't add explanation** - keep options concise.

### Step 4: Execute Choice

#### Option 1: Push

1. **Mark the plan shipped** — run Step 5. If a plan matches this branch, stage and commit it: `git add specs/<slug>/PLAN.md && git commit -m "chore(specs): mark <slug> plan shipped"`. If no plan matches, skip silently.
2. Push to remote: `git push -u github <current_branch>`.
3. Confirm: "Pushed to `<current_branch>`. Done."

#### Option 2: Push and create PR

1. Execute Option 1 (push).
2. Invoke the **create-pr** skill to generate `PR_TEMPLATE.md`.
3. Create the PR using `gh pr create` against `<base_branch>`, using the generated template content for the body.
4. Return the PR URL to the user.

#### Option 3: Keep as-is

1. Confirm: "Branch left as-is. You can resume later."
2. Do nothing else.

#### Option 4: Discard work

1. **Ask for explicit confirmation**: "This will discard all uncommitted changes. Are you sure? (yes/no)"
2. Only on "yes": `git checkout -- . && git clean -fd`
3. Confirm: "Changes discarded."

### Step 5: Mark the plan shipped (Options 1 & 2 only)

Runs as the first action of Option 1 (and therefore Option 2, which executes Option 1). **Skip for Option 3** (keep as-is) and **Option 4** (discard) — that work is not shipped.

> Why this step exists: `status:` in `specs/<slug>/PLAN.md` records the plan lifecycle (`proposed` → `active` at execution start → `shipped` here). This is the **`shipped`** transition — the signal a later reviewer reads to know the feature landed. The edit auto-re-renders `PLAN.html` via `render-plan-on-write.sh`. Leaving it stale on ship is the root cause of status drift across `specs/`.

#### 5a. Resolve the plan for this branch

```bash
branch=$(git branch --show-current)
slug=${branch#*/}                       # strip feat/ | fix/ | chore/ prefix
ls specs/"$slug"/PLAN.md 2>/dev/null || ls specs/*/PLAN.md
```

- Exact match → use `specs/<slug>/PLAN.md`.
- No exact match → pick the `specs/*/PLAN.md` whose frontmatter `slug:` or title best matches the branch. If ambiguous, ask the user which plan this branch implements.
- No plan at all → **skip Step 5** (don't block the push).

#### 5b. Set status + append log

In the resolved `PLAN.md`:

1. Set the frontmatter to `status: shipped`. Canonical values are **only** `proposed | active | paused | shipped` — never invent others (`complete`, `done`, `ready-for-execution` are invalid and get silently dropped by the renderer).
2. Append one entry to the `## Status Log` (or numbered `## N. Status Log`) section, using today's date:

   ```markdown
   - YYYY-MM-DD — shipped via `<branch>` (PR #NNN for Option 2)
   ```

This edit is committed in Option 1 step 1 (so it ships with the push / lands in the PR).

## Quick Reference

| Step | Action | Blocker? |
|------|--------|----------|
| 1 | Run tests | Yes — must pass to proceed |
| 2 | Detect base branch | No — default to `main` |
| 3 | Present 4 options | Yes — wait for user choice |
| 4 | Execute chosen option (no auto-commit) | No |
| 5 | Mark plan `shipped` + log (Options 1 & 2 only) | No — skip if no plan matches |

## Red Flags

**Never:**
- Push code with failing tests
- Force-push (`--force`) without explicit user request
- Use `git add -A` or `git add .` (may include secrets or junk files)
- Skip the confirmation prompt on Option 4 (discard)
- Amend an existing commit — always create a new one

**Always:**
- Run tests before presenting options
- Stage files by name, not by wildcard
- Ask for confirmation before any destructive action
- Show the PR URL after creation
- Default to `main` as base branch when not specified
- Set the matching plan's `status: shipped` before pushing (Options 1 & 2), using only canonical status values

## Integration

### Skills

- **create-pr** skill — creates a PR template and fills it with the current branch

### Sub Agents

- **test-runner** sub-agent — runs tests and reports results
