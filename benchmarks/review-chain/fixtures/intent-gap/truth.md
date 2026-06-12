# Ground truth — intent-gap

- **Defect class:** intent gap — the diff covers part of the request but not all of it.
- **Location:** `app/routers/watchlists.py`, the `update_watchlist` handler. The request asked
  for empty-name rejection on BOTH endpoints. The diff adds the
  `if not payload.name.strip(): raise AppException.BadRequest(...)` guard to `create_watchlist`
  only; `update_watchlist` still accepts an empty name.
- **Expected oracle:** `/intent-review` (classifies as `gap` — requested but absent from the
  diff).
- **Expected verdict if caught:** flags the missing validation on `update_watchlist`; the
  create-side validation is correct and in-scope.
- **What a false-positive would look like:** flagging the create-side guard as wrong/excess,
  or reporting a correctness bug in the create path (the guard is correct). Those are not the
  planted defect.
