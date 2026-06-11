# harness-reliability-improvements — Summary

Lane: high-risk
Confidence: medium
Reason: Hard gate — scope touches `.claude/settings.json` (SessionStart hook), `hooks/*` (commit-quality-gate, risk-corroboration), và core skill engines (feature-intake SKILL.md, SUMMARY template); breadth của scope (top-5 vs toàn bộ 9 mục) cần người chốt.
Flags: existing behavior, weak proof (new scripts chưa có test), multi-domain (hooks + templates + skills + docs + CI)
Input-type: harness improvement

> `Lane` drives **ceremony** (how much proof). `Confidence` drives **interruption**
> (whether a human is asked). A hard gate forces `high-risk`. Low confidence or an
> ambiguous direction escalates regardless of lane — see `rules/orchestration.md`.

## What changed

(Chưa thực hiện — đây là intake cho việc lập PLAN.md cải thiện harness theo
`docs/research-harness-req-assessment.md`: hoàn tất chuyển đổi specs/, trả lời Q3 (Affects field
+ PROJECT.md), machine-verified proof (verify-summary), khép vòng tri thức, strict-in-CI,
story-sizing gate, harness-audit.)

### Rationale

Nghiên cứu 2026-06-11 chấm repo trả lời 4/6 câu hỏi REQ.md; các mục cải thiện đã được ưu tiên
sẵn trong doc. Plan này chuyển danh sách ưu tiên đó thành các wave thực thi được, theo đúng
full chain của lane high-risk.

### Alternatives considered

- Làm trực tiếp từng mục không qua PLAN.md — bị loại: scope >3 steps, >2 files, đa wave,
  nhiều mục là Rule-4 (settings.json, hooks/*) bắt buộc gated-execute.

### Deviations

- none

### Verify

| Check | Command | Exit | Notes |
| --- | --- | --- | --- |
| (chưa chạy — sẽ điền trong quá trình thực thi plan) | — | — | — |

### Rollback

- `git revert <sha>` (per-wave; chi tiết per-task ghi trong PLAN.md khi thực thi)

### Harness-Delta

- none
