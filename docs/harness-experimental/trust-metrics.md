# Trust Metrics Ledger

Per-task ledger of how the harness classified and verified autonomous work. Appended by the
orchestrator at the DONE disclosure of each task (see `skills/feature-intake/SKILL.md` →
Guardrails). Read alongside `specs/<slug>/SUMMARY.md` — the ledger is the cross-task trend
line; the SUMMARY is the per-task record.

Purpose: calibrate autonomy over time. If under-classification recurs (lane below what the
diff tripped), tighten; if escalations keep resolving as "proceed unchanged", loosen.

## Ledger

| Date | Slug | Lane | Confidence | Flags | Escalated | Outcome | Notes |
|---|---|---|---|---|---|---|---|
| 2026-06-11 | p1-doc-truth | normal | high | none | no | shipped (`3798ab3`) | docs/config truthfulness fixes from harness audit |
| 2026-06-11 | p2-doc-cleanup | normal | high | none | no | shipped | remaining phantom-reference cleanup + this ledger scaffold |
