<!--
  Per-slug behavior-to-proof ledger. Copy to specs/<slug>/TEST_MATRIX.md.
  Maps each behavior the work introduces/changes to the proof that it holds.
  Rule: a row is `implemented` ONLY when an evidence artifact exists (a passing
  test, a recorded `### Verify` row in SUMMARY.md, etc.). Do not mark `implemented`
  on belief.
-->

# <slug> — Test Matrix

## Status values

| Status | Meaning |
| --- | --- |
| planned | Accepted as intended behavior, not implemented |
| in_progress | Actively being built |
| implemented | Implemented **and** proof exists |
| changed | Contract changed after earlier implementation |
| retired | No longer part of the contract |

## Matrix

| Behavior | Contract | Unit | Integration | E2E | Status | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| <behavior> | <what it guarantees> | no | no | no | planned | none |

## Evidence rules

- **Unit** — pure domain/application logic.
- **Integration** — backend enforcement, data integrity, provider/job/service contracts.
- **E2E** — user-visible end-to-end flows.
- A row may ship without every column if the SUMMARY explains why (e.g. tiny lane).
- `Evidence` points at the proof: test path, `### Verify` row, or commit sha. Never `none`
  for an `implemented` row.
