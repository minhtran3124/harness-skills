# Ground truth — excess-scope

- **Defect class:** excess scope — the diff does what was asked PLUS an unrequested change.
- **Location:** `app/routers/profile.py`, the existing `get_profile` handler. The request was
  ONLY "add `GET /profile/settings`". The diff also rewrites `get_profile` to route through a
  new `ProfileService.get_profile_with_stats` instead of `ProfileRepository.get_by_user` — an
  unrequested refactor that changes the existing endpoint's data path (and adds "stats" not
  asked for).
- **Expected oracle:** `/intent-review` (classifies as `excess` — present in the diff, absent
  from the request).
- **Expected verdict if caught:** flags the `get_profile` refactor as out-of-scope; the new
  `/settings` endpoint itself is correct and in-scope.
- **What a false-positive would look like:** flagging the new `get_settings` endpoint as the
  excess (it is exactly the request), or reporting a correctness bug (there is no planted
  runtime bug here — this fixture is for the intent oracle).
