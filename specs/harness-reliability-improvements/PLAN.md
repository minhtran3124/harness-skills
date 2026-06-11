---
slug: harness-reliability-improvements
status: active
owner: Minh Tran
created: 2026-06-11
---

# Harness Reliability Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use subagent-driven-development (hoặc executing-plans ở
> session song song) để thực thi plan này task-by-task.

**Goal:** Thực thi 6 mục ưu tiên của `docs/research-harness-req-assessment.md` — hoàn tất chuyển
đổi `specs/`, trả lời Q3 (Affects + PROJECT.md), chuyển proof sang machine-verified, khép vòng
tri thức, và bật strict mode trong CI.

**Architecture:** Mỗi cải thiện đi theo tiền lệ sẵn có của repo: convention markdown → script
exit-code (`check_plan_format.py` là khuôn), hook bash có test hành vi trong `tests/hooks/`,
mọi thay đổi hook/settings phải giữ doc-truth lint xanh (bảng hook CLAUDE.md ↔ `settings.json`).
Sửa **source tree** (root `hooks/`, `settings.json`, `skills/`) — KHÔNG đụng `.claude/` local
(bản deploy do người chạy `deploy-harness.sh`).

**Tech Stack:** Bash (hooks, khuôn `tests/hooks/*.test.sh`), Python 3 + pytest (scripts, khuôn
`check_plan_format.py`/`test_check_plan_format.py`), GitHub Actions (`harness-ci.yml`).

---

## 1. Motivation

Nghiên cứu 2026-06-11 (`docs/research-harness-req-assessment.md`) kết luận: repo trả lời tốt
4/6 câu hỏi REQ.md nhưng (a) Q3 "product contract nào bị ảnh hưởng?" không có cơ chế nào trả lời,
(b) proof là self-reported (cột Exit gõ tay, không re-run), (c) vòng tri thức bán-khép (pull-only),
(d) việc bỏ `specs/` khỏi gitignore (06-11) mới xong một nửa — 10 slug chưa commit, 2+ doc còn
khẳng định ngược, (e) hai gate chủ lực fail-open mặc định (quyết định keep-warn có chủ đích —
con đường nâng là CI trước, local sau).

## 2. Non-goals

- **KHÔNG** lật quyết định keep-warn: `REQUIRE_VERIFY` / `RISK_CORROBORATION_STRICT` mặc định
  **giữ 0 ở local**. Plan chỉ bật strict trong CI; bật local là quyết định riêng sau khi có số
  liệu vỡ qua ledger vài tuần.
- **KHÔNG** làm mục 7–9 của research doc (story-sizing gate, `harness-audit.sh`, VERSION/CHANGELOG)
  — defer sang plan sau.
- **KHÔNG** đụng `.claude/` local (memory rule: chỉ người chạy `deploy-harness.sh`).
- **KHÔNG** xây registry contract mới — Q3 giải bằng field `Affects:` + điền `PROJECT.md`, đúng
  kết luận research ("không cần xây hệ thống mới").
- **KHÔNG** thêm `--all` cho verify-summary (footgun side-effect đã được research cảnh báo — YAGNI).

## 3. Success Criteria

1. `git ls-files specs/ | grep -c SUMMARY.md` ≥ 10; `specs/**/PLAN.html` bị ignore; không doc
   tracked nào còn khẳng định "specs/ gitignored / never committed".
2. `skills/xia2/PROJECT.md` hết placeholder — PROJECT-CONFIG-GATE của `/xia2` đi qua được với
   dữ liệu thật của repo này.
3. `templates/SUMMARY.template.md` có field `Affects:`; `/feature-intake` emit nó; ledger có cột
   tương ứng.
4. `scripts/verify_summary.py` chạy lại bảng `### Verify` và ghi đè Exit bằng exit code thật;
   `commit-quality-gate.sh` (khi `REQUIRE_VERIFY=1`) gọi nó thay vì grep sự hiện diện.
5. SessionStart hook nạp INDEX + critical-patterns khi kho có dữ liệu, im lặng khi rỗng;
   bảng hook CLAUDE.md khớp `settings.json` (doc-truth lint xanh).
6. CI có strict gate chạy trên PR diff với `REQUIRE_VERIFY=1` + `RISK_CORROBORATION_STRICT=1`.
7. `bash scripts/run-tests.sh` xanh toàn bộ — **gate chính thức là CI (ubuntu + macos)**;
   ở local, settings-wiring test chỉ xanh sau khi human chạy `deploy-harness.sh` đồng bộ
   `.claude/` (xem escalation của task 3.1).

## 4. Tasks

### Wave 1 — Hoàn tất chuyển đổi specs/ + nền tảng Q3 (4 task song song, file disjoint)

#### Task 1.1 — Ignore PLAN.html dẫn xuất + commit specs/ lần đầu

```xml
<task id="1.1" wave="1">
  <files>.gitignore</files>
  <action>Thêm vào .gitignore (thay chỗ dòng `#specs/` đã comment): `specs/**/PLAN.html` và
  `specs/**/.plan-review.json` — artifact dẫn xuất build lại được từ PLAN.md qua render_plan.py,
  commit chúng chỉ tạo diff HTML nhiễu. Sau đó `git add specs/ .gitignore` và commit lần đầu
  (toàn bộ slug hiện có — 11 slug kể cả slug của plan này — + STATE.md + README.md; PLAN.html
  bị loại tự động). Lưu ý: thực thi trên branch của worktree, không commit thẳng main
  (branch-guard sẽ warn).</action>
  <verify>git check-ignore -q specs/p3-hook-fixes/PLAN.html && git ls-files specs/ | grep -q "SUMMARY.md"</verify>
  <done>specs/ được track (SUMMARY/PLAN.md/STATE.md), PLAN.html + sidecar review bị ignore</done>
</task>
```

#### Task 1.2 — Sửa các doc còn khẳng định "specs/ gitignored"

```xml
<task id="1.2" wave="1">
  <files>CLAUDE.md, rules/plan-format.md, skills/README.md, skills/writing-plans/SKILL.md, skills/visual-planner/SKILL.md</files>
  <action>Cập nhật mọi claim về policy cũ sang policy mới: "specs/ được track; riêng PLAN.html
  và .plan-review.json (artifact dẫn xuất) bị ignore". Cụ thể: CLAUDE.md mục Gotchas dòng
  "specs/ is fully gitignored ... nothing is committed"; rules/plan-format.md:125 ("plans are not
  browsable across machines" — giờ browsable được); skills/README.md và writing-plans/SKILL.md
  ("specs/, which is never committed"); visual-planner/SKILL.md ("Local-only output" — PLAN.html
  vẫn local-only, sửa câu cho rõ là CHỈ PLAN.html, không phải cả specs/). KHÔNG sửa các câu nói
  riêng về PLAN.html untracked (phrasing "untracked" giữ nguyên) — chúng vẫn đúng. Lưu ý các
  claim nằm SAU backtick (ví dụ "`specs/` is fully gitignored") nên grep không được neo
  khoảng-trắng ngay sau "specs/". Quét xác nhận bằng lệnh verify trước khi kết thúc.</action>
  <verify>! grep -rniE "fully gitignored|local-only \(gitignored\)|is never committed|not browsable across machines" CLAUDE.md rules/ skills/ templates/</verify>
  <done>Không file tracked nào còn mô tả specs/ là gitignored/never-committed; mô tả PLAN.html untracked vẫn nguyên</done>
</task>
```

#### Task 1.3 — Điền xia2/PROJECT.md cho chính repo này

```xml
<task id="1.3" wave="1">
  <files>skills/xia2/PROJECT.md</files>
  <action>Điền template theo cấu trúc sẵn có (giữ nguyên heading), dữ liệu thật của repo:
  Identity (Name: harness-skills; Stack: Bash hooks + Python 3 scripts + Markdown skills,
  GitHub Actions CI; Repo root: ../../). High-Blast-Radius Files: settings.json (hook
  registration), hooks/*.sh (auto-run mọi session), skills/visual-planner/render_plan.py (core
  skill engine), templates/SUMMARY.template.md (schema machine-read bởi risk-corroboration +
  ledger), scripts/run-tests.sh (CI contract). Shared contracts: SUMMARY header 4-field
  (Lane/Confidence/Reason/Flags) — grep bởi risk-corroboration.sh; cột ledger
  docs/harness-experimental/trust-metrics.md; hook exit-code contract (0 pass / 2 block);
  bảng hook CLAUDE.md ↔ settings.json (doc-truth lint). Test command: bash scripts/run-tests.sh.
  Solutions index: docs/solutions/INDEX.md. Tham chiếu chéo: sau task này chạy lại
  tests/structural/ nếu PROJECT.md là input của depth-classifier (theo maintenance discipline
  của skills/README.md). PROJECT.md có ~20 placeholder dạng &lt;...&gt; rải khắp file (không chỉ
  3 dòng Identity) — phải điền hoặc xoá TẤT CẢ, kể cả section Session-artifacts (dòng 85–87)
  và các placeholder chứa "e.g."; verify quét cả hai dạng. Hai quy ước khi điền để không
  false-positive verify: (1) viết tham chiếu slug dạng `specs/*/SUMMARY.md`, KHÔNG dùng
  `specs/&lt;slug&gt;/`; (2) các grep-key example dạng `module: &lt;domain&gt;` (dòng ~75) là hướng dẫn
  chứ không phải placeholder — viết lại theo dạng backtick/không-ngoặc-nhọn thay vì xoá.</action>
  <verify>! grep -qiE '<[a-z][a-z _+-]*>|<[^>]*e\.g\.[^>]*>' skills/xia2/PROJECT.md</verify>
  <done>PROJECT.md hết placeholder (toàn file, không riêng Identity); /xia2 PROJECT-CONFIG-GATE pass với high-blast list thật</done>
</task>
```

#### Task 1.4 — Field `Affects:` (trả lời Q3) vào template + intake + ledger

```xml
<task id="1.4" wave="1">
  <files>templates/SUMMARY.template.md, skills/feature-intake/SKILL.md, docs/harness-experimental/trust-metrics.md</files>
  <action>(a) templates/SUMMARY.template.md: thêm dòng `Affects: <contract/module bị ảnh hưởng,
  từ danh sách High-Blast/Shared-Contracts của PROJECT.md, hoặc tên module; 'none' nếu không>`
  ngay sau dòng Flags; cập nhật comment đầu file từ "four header fields" thành "five header
  fields". (b) skills/feature-intake/SKILL.md: Step 2 thêm chỉ dẫn "đối chiếu diff dự kiến với
  High-Blast Files + Shared Contracts trong PROJECT.md để gọi tên contract bị ảnh hưởng";
  Step 6 emit statement thêm dòng `Affects:`. (c) trust-metrics.md: thêm cột `Affects` vào
  header bảng (sau cột Lane), backfill TẤT CẢ dòng dữ liệu hiện có bằng `-` (hiện 8 dòng —
  đếm lại lúc thực thi, ledger đang được append liên tục; một dòng lệch số cột là vỡ bảng
  machine-read). Giữ schema cột là contract — ghi chú trong header ledger rằng cột này là
  machine-read.</action>
  <verify>grep -q "^Affects:" templates/SUMMARY.template.md && grep -q "Affects" skills/feature-intake/SKILL.md && head -20 docs/harness-experimental/trust-metrics.md | grep -q "Affects"</verify>
  <done>Q3 có chỗ đứng cấu trúc: intake hỏi, SUMMARY ghi, ledger query được theo contract</done>
</task>
```

### Wave 2 — Scripts mới + test (2 task song song, file disjoint; chưa wire vào gate)

#### Task 2.1 — `scripts/verify_summary.py`: re-run bảng Verify, ghi exit code thật

```xml
<task id="2.1" wave="2">
  <files>scripts/verify_summary.py, scripts/test_verify_summary.py</files>
  <action>Viết theo khuôn check_plan_format.py (+ test theo test_check_plan_format.py). TDD:
  viết test trước, chạy fail, rồi implement. Hành vi: `python3 scripts/verify_summary.py <slug>`
  (1) parse bảng dưới `### Verify` trong specs/<slug>/SUMMARY.md; (2) bỏ qua dòng placeholder
  (Command là `—`, `<command>`, hoặc rỗng); (3) chạy từng Command bằng bash từ repo root,
  timeout 60s/lệnh; (4) GHI ĐÈ cột Exit bằng exit code thật + thêm/refresh dòng
  `Verified: <ISO-8601>` ngay dưới bảng; (5) exit 1 nếu bất kỳ lệnh nào fail HOẶC exit khai ≠
  exit thật (in cặp claimed/actual), exit 0 nếu tất cả khớp và pass. Thêm mode `--check`:
  so sánh không ghi đè (cho hook/CI dùng). KHÔNG có --all (footgun side-effect). Timeout phải
  inject được (`--timeout <giây>`, default 60) để test case timeout dùng giá trị ~1s thay vì
  đốt 60s thật — verify của chính task này phải dưới 60s. Test cases tối thiểu: bảng pass-khớp
  → exit 0 + Verified line; lệnh fail → exit 1; khai 0 nhưng thật 1 → exit 1 + thông báo
  mismatch; placeholder-only → exit 0 kèm cảnh báo "no checks ran"; timeout (--timeout 1) →
  exit 1; --check không sửa file (so sánh content trước/sau).</action>
  <verify>python3 -m pytest scripts/test_verify_summary.py -x -q</verify>
  <done>Proof chuyển từ assertion sang fact: cột Exit do máy ghi, mismatch bị bắt, có timestamp</done>
</task>
```

#### Task 2.2 — `hooks/session-knowledge.sh`: nạp tri thức lúc SessionStart (chưa đăng ký)

```xml
<task id="2.2" wave="2">
  <files>hooks/session-knowledge.sh, tests/hooks/session-knowledge.test.sh</files>
  <action>Viết hook SessionStart theo khuôn JSON-output của scope-gate.sh (additionalContext)
  và nếp phòng thủ của state-breadcrumb.sh (never block, mọi nhánh exit 0). Hành vi:
  (1) coi kho là RỖNG khi: INDEX.md không tồn tại, HOẶC bảng Entries chỉ có dòng placeholder
  `_(empty...)_` (format bootstrap), HOẶC header dạng "0 entries" không kèm dòng dữ liệu nào
  (format rebuild của compound/SKILL.md:387) — cả HAI format rỗng đều phải im lặng exit 0;
  (2) nếu có entry (lưu ý: INDEX hiện ĐÃ có 2 entry sau dogfood 06-11, hook sẽ emit ngay từ
  ngày wire — cap là tầng kiểm soát token chính): emit additionalContext gồm bảng INDEX (tối đa
  30 dòng đầu) + nội dung docs/solutions/critical-patterns.md (tối đa 40 dòng; quá thì chỉ lấy
  các heading); kèm 1 dòng nguồn "[session-knowledge] docs/solutions/ — đọc full file khi liên
  quan". Hook này KHÔNG được đăng ký trong task này — wiring là Rule-4, tách sang task 3.1.
  Test cases: cả 2 format rỗng → stdout rỗng + exit 0; INDEX thiếu → exit 0; có entry → JSON
  hợp lệ chứa tên entry; INDEX dài → bị cắt đúng ngưỡng; critical-patterns >40 dòng → chỉ
  headings.</action>
  <verify>bash tests/hooks/session-knowledge.test.sh</verify>
  <done>Hook tồn tại, test xanh, im lặng khi kho rỗng — sẵn sàng wire ở wave 3</done>
</task>
```

### Wave 3 — Wiring Rule-4 (2 task song song, file disjoint; mỗi task ghi Rollback vào SUMMARY)

#### Task 3.1 — Đăng ký SessionStart hook + cập nhật bảng hook CLAUDE.md

```xml
<task id="3.1" wave="3">
  <files>settings.json, CLAUDE.md</files>
  <action>Rule-4 (đã được người duyệt scope tại intake 2026-06-11 — AskUserQuestion: "Có — đưa
  vào plan"). (a) settings.json: thêm trigger "SessionStart" gọi hooks/session-knowledge.sh
  (theo đúng shape các entry hiện có). (b) CLAUDE.md bảng Hooks: thêm dòng
  `session-knowledge.sh | SessionStart | Nạp INDEX + critical-patterns vào context khi kho có
  dữ liệu; im lặng khi rỗng | ✅` — doc-truth lint sẽ fail nếu bảng và settings.json lệch nhau,
  nên hai file này phải sửa trong CÙNG task. Ghi vào specs/<slug>/SUMMARY.md mục Rollback:
  `git revert <sha task này>` (gỡ đăng ký + dòng bảng cùng lúc). Verify CHỈ gồm check phía
  root: (a) KHÔNG dùng full suite — task 3.2 cùng wave đang sửa hooks/commit-quality-gate.sh
  (flake); (b) KHÔNG dùng tests/scripts/settings-wiring.test.sh ở local — test đó so root
  settings.json với bản deploy .claude/settings.json, mà đồng bộ .claude/ là việc của NGƯỜI
  (memory rule: không tự chạy deploy-harness.sh) → local sẽ đỏ một cách tất định cho tới khi
  deploy. Kết thúc task bằng escalation tường minh trong SUMMARY: "human chạy
  scripts/deploy-harness.sh để sync .claude/, sau đó chạy tests/scripts/settings-wiring.test.sh
  + full suite". CI không bị ảnh hưởng (.claude/ untracked → check tự skip).</action>
  <verify>jq -e . settings.json >/dev/null && bash scripts/lint-doc-truth.sh</verify>
  <done>Hook wired phía root; doc-truth lint xanh; rollback 1 lệnh + escalation deploy được ghi trong SUMMARY; settings-wiring test xanh sau khi human deploy (CI là gate chính thức)</done>
</task>
```

#### Task 3.2 — Nâng `commit-quality-gate.sh`: REQUIRE_VERIFY=1 gọi verify_summary --check

```xml
<task id="3.2" wave="3">
  <files>hooks/commit-quality-gate.sh, tests/hooks/commit-quality-gate.test.sh</files>
  <action>Rule-4 (hooks/*). Trong nhánh `REQUIRE_VERIFY=1` hiện có (quanh dòng 71–81): sau check
  sự-hiện-diện của `### Verify` hiện tại, thêm bước gọi `python3 scripts/verify_summary.py
  --check <slug>` (resolve slug bằng đúng logic tìm SUMMARY mà hook đang dùng); exit code ≠ 0 →
  block với message nêu rõ mismatch claimed/actual. Hai ràng buộc: (1) MẶC ĐỊNH REQUIRE_VERIFY=0
  giữ nguyên — quyết định keep-warn không bị lật; (2) khi python3 không có trên PATH → degrade
  về check grep cũ kèm warning (không block vì thiếu interpreter — fail-open có chủ đích, theo
  nếp `|| true` đã có). Cập nhật test: case REQUIRE_VERIFY=1 + bảng Verify khớp → pass;
  REQUIRE_VERIFY=1 + Exit khai sai → block; REQUIRE_VERIFY=0 → không đổi hành vi (regression);
  python3 vắng (PATH rỗng giả lập) → warn nhưng không block. Ghi Rollback vào SUMMARY.</action>
  <verify>bash tests/hooks/commit-quality-gate.test.sh</verify>
  <done>Khi opt-in REQUIRE_VERIFY=1, proof được máy re-run thay vì tin lời khai; default không đổi</done>
</task>
```

### Wave 4 — Strict mode trong CI

#### Task 4.1 — CI strict gate trên PR diff

```xml
<task id="4.1" wave="4">
  <files>scripts/ci-strict-gate.sh, tests/scripts/ci-strict-gate.test.sh, .github/workflows/harness-ci.yml</files>
  <action>(a) scripts/ci-strict-gate.sh: nhận base ref (default origin/main), lấy
  `git diff --name-only <base>...HEAD`; nếu diff chạm hard-gate paths — TÁI DÙNG đúng pattern
  đã fix-precision của risk-corroboration.sh:71
  (`(^|/)settings\.json$|^hooks/|(^|/)\.claude/hooks/|render_plan\.py$`, vốn đã loại trừ
  tests/hooks/ theo bài học false-positive trong ledger) MỞ RỘNG thêm `^templates/` (phần mở
  rộng có chủ đích, không có trong hook gốc — ghi comment nói rõ) — thì yêu cầu: tồn tại
  specs/*/SUMMARY.md thay đổi trong diff có `Lane: high-risk` VÀ ≥1 dòng Verify non-placeholder;
  đồng thời chạy `python3 scripts/verify_summary.py --check <slug>` cho các slug có SUMMARY
  thay đổi. Script TỰ implement các check này (không shell-out sang hook — hook đọc staged
  diff, CI không có); strict semantics nằm trong script, không nằm ở env. Vi phạm → exit 1 +
  in từng thiếu sót. Diff không chạm hard-gate → exit 0 im lặng. (b) Test: fixture repo tạm
  với các case — diff lành → 0; diff chạm hooks/ không có SUMMARY → 1; có SUMMARY lane thấp →
  1; đầy đủ → 0; diff chỉ chạm tests/hooks/ → 0 (case false-positive). (c) harness-ci.yml:
  thêm JOB riêng "strict-gate" (không phải step trong job cũ — cần checkout riêng với
  fetch-depth: 0 để diff được với base) có `if: github.event_name == 'pull_request'`, chạy
  scripts/ci-strict-gate.sh với base = origin/${{ github.base_ref }}. Đây là tầng "bật strict
  trong CI trước" — local default giữ nguyên; số liệu vỡ đọc từ CI history + ledger trước khi
  cân nhắc bật local.</action>
  <verify>bash tests/scripts/ci-strict-gate.test.sh</verify>
  <done>PR chạm hard-gate path mà thiếu SUMMARY high-risk + Verify thật sẽ đỏ CI; local không đổi</done>
</task>
```

## 5. Risks

| Risk | Mitigation |
|---|---|
| Sửa `settings.json`/`hooks/*` là high-blast (tự áp dụng cho chính repo) | Mỗi task Rule-4 (3.1, 3.2) ghi Rollback 1-lệnh vào SUMMARY trước khi done; CI chạy cùng suite trên ubuntu+macos |
| `verify_summary.py` chạy lệnh có side-effect | Chỉ chạy slug được chỉ định, không `--all`; comment trong template yêu cầu lệnh Verify idempotent/read-only |
| SessionStart hook tốn token nền mỗi phiên | Kho ĐÃ có 2 entry (dogfood 06-11) → hook emit ngay từ ngày wire; tầng kiểm soát chính là cap 30+40 dòng + nhánh im lặng cho cả 2 format rỗng |
| CI strict gate false-positive (tiền lệ: regex bắt nhầm `tests/hooks/`) | Tái dùng pattern đã fix-precision của `risk-corroboration.sh`; case test riêng cho `tests/hooks/` |
| Doc-truth lint đỏ nếu bảng hook và settings.json sửa lệch wave | 3.1 gộp cả hai file trong một task — không bao giờ lệch commit |
| Commit specs/ lần đầu kéo theo nội dung nhạy cảm cũ trong 10 slug | Trước `git add specs/`, quét nhanh secrets bằng đúng pattern của commit-quality-gate (hook cũng sẽ tự chạy khi commit) |

## 6. Status Log

- 2026-06-11 — Plan created (intake: Lane high-risk, Confidence medium → scope narrowed by human:
  top 1–6 + SessionStart hook; defer story-sizing/harness-audit/VERSION).
