---
slug: correctness-review-scorer
status: shipped
owner: Minh Tran
created: 2026-06-09
lang: vi
---

# Correctness review có chấm điểm tin cậy (find→score→threshold kiểu Boris)

> **Cho Claude:** SUB-SKILL BẮT BUỘC: dùng `subagent-driven-development` (hoặc `executing-plans`)
> để thực thi plan này theo từng task. Plan này **chỉ sửa skill prompt docs** — không có app code,
> không pytest. Mỗi `<verify>` là một assertion bằng `grep`; exit 0 = pass.

**Mục tiêu:** Chèn tầng **score → threshold** giữa correctness reviewer (FIND) và phần phân loại
D/E + fix-loop, để các finding high-recall được lọc precision *trước* khi vào việc sửa — đây là
tầng còn thiếu khiến một reviewer đối kháng không làm ngập implementer bằng false positive.

**Nguồn thiết kế:** phân tích trong hội thoại (Boris `/code-review` vs Every `/ce-code-review`).
Không có `design.md` / `research-brief.md` riêng — thiết kế đã đặc tả đủ bên dưới; đây là thay đổi
prose tự chứa cho một skill đã ship.

## 1. Động cơ

Correctness reviewer (ship ở PR #6) cố ý **high-recall**: "nghi ngờ thì cứ FLAG". Hiện mọi finding
được flag đi thẳng vào fix-loop (D) và residual gate (E) — **không có tầng lọc precision**, nên
implementer có thể đuổi theo false positive. `/code-review` của Boris giải đúng việc này bằng cách
**tách sinh-lỗi khỏi lọc-lỗi**: finder độc lập sinh ứng viên, rồi một scorer model-rẻ **riêng** chấm
mỗi finding 0–100 theo rubric verbatim, và bỏ mọi thứ dưới ngưỡng (Boris dùng 80).

Plan này thêm tầng score→threshold đó. Reviewer vẫn high-recall; precision được ép ở hạ nguồn. Kết
quả: giữ được tính đối kháng mà không trả "thuế noise".

## 2. Không nằm trong phạm vi (Non-goals)

- **Cross-persona agreement** (tín hiệu tin cậy của Every — ≥2 lăng kính độc lập cùng đồng ý). Ta
  đang có *một* correctness reviewer, nên agreement không có gì để "đồng ý" với nhau. Đây là
  follow-up tự nhiên **sau khi** đã có multi-lens fan-out; ghi nhận làm alternative (§3) và hoãn.
  Plan này chỉ làm biến thể **independent-scorer**.
- **Multi-lens / finder song song** — thay đổi lớn hơn, ngoài phạm vi.
- **B — feature-intake flag → reviewer-persona mapping** — vẫn hoãn (đụng `skills/feature-intake/`,
  high-blast).
- Không đụng `settings.json` / hook / cấu hình model.

## 3. Quyết định — independent scorer vs cross-persona agreement

**Đã chọn: independent scorer kiểu Boris.** Lý do: tầng FIND của ta là một reviewer, không phải
một panel; confidence dựa trên agreement cần ≥2 lăng kính mà ta chưa có. Independent scorer hợp với
kiến trúc hiện tại và là cơ chế precision rẻ hơn, đơn giản hơn.

**Alternative (hoãn): cross-persona agreement.** Tăng confidence khi ≥2 lăng kính độc lập cùng flag
một finding. Bắt được điểm mù của scorer tốt hơn, nhưng cần multi-lens fan-out (thay đổi lớn hơn).
Xem lại khi cái đó tồn tại; hai cách có thể kết hợp (agreement *rồi* scorer).

## 4. Tiêu chí thành công

1. Có file mới `correctness-scorer-prompt.md`: chấm mỗi candidate finding **0–100** theo **rubric
   verbatim**, chạy trên **model rẻ**, trong **context độc lập** (chỉ thấy claim + diff, KHÔNG thấy
   lập luận của finder).
2. Các mốc rubric tường minh (0 / 25 / 50 / 75 / 100), điều chỉnh theo bối cảnh của ta — finding bị
   chấm thấp nếu là pre-existing, nằm trên dòng không sửa, hoặc đã bị CI/hooks bắt (`ruff`,
   `commit-quality-gate`, `risk-corroboration`).
3. **Ngưỡng 80** lọc finding: chỉ `≥80` mới vào phân loại D (severity×Rule) và fix-loop. Giá trị
   ngưỡng nêu một lần và ghi rõ là **điều chỉnh được**.
4. Finding bị bỏ (`<80`) **không biến mất âm thầm** — ghi `advisory` trong `SUMMARY.md` (nhất quán
   với nguyên tắc "nothing silently dropped" của E), không escalate.
5. `correctness-reviewer-prompt.md` (FIND) ghi rõ output là *candidate findings chờ chấm điểm* và
   được dặn **giữ high-recall / không tự kiểm duyệt** (scorer lo precision).
6. `SKILL.md` mục "Final Adversarial Correctness Review" ghi đúng thứ tự pipeline:
   FIND → SCORE → THRESHOLD(≥80) → D phân loại → E residual/fix-loop.

## 5. Tasks

### Task 1 — Tạo scorer prompt template

```xml
<task id="1">
  <files>skills/subagent-driven-development/correctness-scorer-prompt.md</files>
  <action>Tạo prompt template mới cho tầng SCORE. Nó dispatch một agent model-RẺ trong context ĐỘC
  LẬP: input là một candidate finding (claim + file:line) cộng diff/files — KHÔNG có lập luận của
  finder. Agent chấm finding 0–100 theo rubric verbatim này: 0 = false positive / pre-existing /
  không nằm trên dòng đã sửa; 25 = có thể thật, chưa kiểm chứng; 50 = thật nhưng nhỏ hoặc hiếm;
  75 = rất tự tin, thật và sẽ xảy ra trong thực tế; 100 = chắc chắn, code xác nhận. Dặn: chấm 0 nếu
  linter/typechecker/CI hoặc một hook sẵn có (`ruff-on-edit`, `commit-quality-gate`,
  `risk-corroboration`) đã bắt, hoặc nếu nằm trên dòng diff không sửa. Trả `score` (0–100) + một
  dòng lý do cho mỗi finding. Theo cấu trúc/tông của các `*-prompt.md` cùng thư mục. Ghi rõ ngưỡng
  mặc định 80 (điều chỉnh được) và việc chấm điểm độc lập với severity.</action>
  <verify>cd /Users/minhtran/Documents/minhtran3124/developer/harness-skills && f=skills/subagent-driven-development/correctness-scorer-prompt.md && test -f "$f" && grep -q "0–100\|0-100" "$f" && grep -q "80" "$f" && grep -Eqi "cheap|fast|haiku|rẻ" "$f" && grep -Eqi "independent|độc lập" "$f" && grep -q "commit-quality-gate" "$f"</verify>
  <done>Scorer template tồn tại: rubric 0–100, model rẻ, context độc lập, ngưỡng 80, biết né CI/hook.</done>
</task>
```

### Task 2 — Tầng FIND: gắn nhãn output là candidate, giữ high-recall

```xml
<task id="2">
  <files>skills/subagent-driven-development/correctness-reviewer-prompt.md</files>
  <action>Thêm một ghi chú ngắn "## Confidence scoring (next stage)" gần Report format: các finding
  reviewer này phát ra là CANDIDATE mà một scorer model-rẻ riêng (`./correctness-scorer-prompt.md`)
  sẽ chấm 0–100; chỉ `≥80` mới vào fix-loop. Dặn finder vì thế GIỮ HIGH-RECALL — không tự kiểm
  duyệt hay lọc trước các finding chưa chắc, vì precision được ép ở hạ nguồn. Không đổi phần
  bug-class hunt hay mindset đối kháng hiện có. Chỉ thêm, surgical.</action>
  <verify>cd /Users/minhtran/Documents/minhtran3124/developer/harness-skills && f=skills/subagent-driven-development/correctness-reviewer-prompt.md && grep -qi "confidence scoring" "$f" && grep -q "correctness-scorer-prompt.md" "$f" && grep -Eqi "high.recall|do not self-censor|candidate" "$f"</verify>
  <done>FIND prompt trỏ tới scorer, gắn nhãn finding là candidate, nhấn mạnh high recall.</done>
</task>
```

### Task 3 — Wire SKILL.md: FIND → SCORE → THRESHOLD → D → E

```xml
<task id="3">
  <files>skills/subagent-driven-development/SKILL.md</files>
  <action>Trong mục "## Final Adversarial Correctness Review", chèn tầng SCORE→THRESHOLD GIỮA bước
  find và phân loại hai trục (D). Ghi rõ thứ tự pipeline: FIND (candidate high-recall) → SCORE
  (model rẻ, `./correctness-scorer-prompt.md`, mỗi finding 0–100) → THRESHOLD (bỏ `<80`) →
  D (severity×Rule) → E (residual gate + fix-loop). Ghi rõ finding bị bỏ (`<80`) được ghi `advisory`
  trong `SUMMARY.md` (không escalate, không biến mất âm thầm). Ghi ngưỡng (80) điều chỉnh được. Thêm
  scorer template vào danh sách "Prompt Templates". Giữ edit surgical.</action>
  <verify>cd /Users/minhtran/Documents/minhtran3124/developer/harness-skills && f=skills/subagent-driven-development/SKILL.md && grep -q "correctness-scorer-prompt.md" "$f" && grep -Eqi "score|0–100|0-100" "$f" && grep -q "80" "$f" && grep -qi "advisory" "$f"</verify>
  <done>SKILL.md ghi FIND→SCORE→THRESHOLD→D→E và liệt kê scorer template; nêu xử lý advisory.</done>
</task>
```

### Task 4 — Lint nhất quán

```xml
<task id="4">
  <files>skills/subagent-driven-development/SKILL.md, skills/subagent-driven-development/correctness-reviewer-prompt.md, skills/subagent-driven-development/correctness-scorer-prompt.md</files>
  <action>Kiểm tra các tham chiếu chéo resolve được và câu chuyện ngưỡng/thứ tự nhất quán trên cả ba
  file. Không kỳ vọng edit trừ khi lint fail.</action>
  <verify>cd /Users/minhtran/Documents/minhtran3124/developer/harness-skills && d=skills/subagent-driven-development && grep -q "correctness-scorer-prompt.md" "$d/SKILL.md" && grep -q "correctness-scorer-prompt.md" "$d/correctness-reviewer-prompt.md" && test -f "$d/correctness-scorer-prompt.md"</verify>
  <done>Cả ba file tham chiếu scorer; không có đường dẫn treo.</done>
</task>
```

## 6. Rủi ro

- **Hiệu chỉnh ngưỡng.** 80 là số của Boris cho PR bot; bối cảnh của ta (gate pre-merge,
  recall-first) có thể muốn thấp hơn. Nêu như điểm khởi đầu + điều chỉnh được — tune sau lần dùng
  thực tế đầu tiên.
- **Chi phí.** SCORE thêm một lần gọi model rẻ cho mỗi candidate finding. Chấp nhận được (model rẻ,
  chỉ khi reviewer có finding), nhưng ghi chú trong SKILL.md.
- **Phụ thuộc PR #6.** Correctness reviewer (FIND) phải tồn tại. PR #6 đã ship nhưng chưa merge —
  branch việc này chồng lên `feat/correctness-review-upgrade` (stacked) hoặc off `main` sau khi #6
  merge. Quyết ở thời điểm thực thi.
- **Hai bản skill + site deploy.** Sau merge: re-sync bản `.claude/skills/` đã deploy, và cập nhật
  guide/deck của `harness-skills-deploy` (thêm tầng SCORE vào mô tả pipeline) — cùng follow-through
  như PR #6.

## 7. Status Log

- 2026-06-09 — Plan drafted (status: proposed). Awaiting execution-mode choice.
