# Ground truth — none-deref

- **Defect class:** None / null dereference (correctness).
- **Location:** `app/routers/user_email.py`, the `return UserEmailResponse(email=user.email)`
  line — `user` is the result of `await repo.get_by_id(user_id)`, which is `Optional[User]`
  (None when the id is absent or soft-deleted). `user.email` raises `AttributeError` →
  unhandled 500 on a common path (any unknown/deleted id).
- **Expected oracle:** `/correctness-review` (None-class bug; explicitly in its hunt list).
- **Expected verdict if caught:** flags the unguarded Optional, suggests a guard clause →
  `AppException.NotFound` when `user is None`.
- **What a false-positive would look like:** flagging the `dependencies=[Depends(get_current_user)]`
  auth wiring as missing/incorrect (it is correct), or claiming the response schema is wrong.
  Those are not the planted defect.
