# harness-adoptions-execution — Summary

Lane: normal
Confidence: high
Reason: Selected subset (tracks 1, 2, 6, 7) contains no hard-gate work — no settings.json, hooks/, or auth changes; Track 1 touches review skill prompts (normal), Tracks 2/6 are doc/rule edits (tiny), Track 7 adds new benchmark content only.
Flags: none
Affects: agents/, skills/correctness-review, skills/intent-review, rules/behavior.md, skills/README.md, benchmarks/ (new)
Input-type: harness improvement

> `Lane` drives **ceremony** (how much proof). `Confidence` drives **interruption**
> (whether a human is asked). A hard gate forces `high-risk`. Low confidence or an
> ambiguous direction escalates regardless of lane — see `rules/orchestration.md`.

### Intent

> create plan for all first. and I will make decision for next step

> now make the sub plan for 1, 2, 6, 7 now

(Selection refers to the decision matrix of `specs/harness-comparison-adoptions/PLAN.md`:
Track 1 = read-only review agents, Track 2 = `not_observed != absent` rule, Track 6 =
integration evidence-tier table, Track 7 = review-chain micro-benchmark. Upstream original
intent is recorded verbatim in `specs/harness-comparison-adoptions/SUMMARY.md`.)

## What changed

Execution sub-plan derived from the master plan for the four user-selected tracks.
Tracks 3, 4, 5, 8, 9 remain deferred in the master plan (status: proposed).

### Rationale

The user selected a subset; a dedicated spec keeps the executable plan clean (3 waves, no
deferred-task noise) while the master plan stays the umbrella record of all 9 ideas.

### Alternatives considered

- Mark unselected tracks "deferred" inside the master PLAN.md — rejected: executors key on
  specs/<slug>/PLAN.md running all tasks; a separate spec avoids accidental scope.

### Deviations

- none

### Verify

| Check | Command | Exit | Notes |
| --- | --- | --- | --- |
| Plan format | `python3 scripts/check_plan_format.py specs/harness-adoptions-execution/PLAN.md` | — | run after PLAN.md written |

### Rollback

- `git revert <sha>` per task commit (all work is additive docs/prompts/fixtures)

### Harness-Delta

- none
