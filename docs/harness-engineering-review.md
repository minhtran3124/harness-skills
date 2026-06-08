# Xây dựng Claude Code bằng Harness Engineering — Bài đánh giá

> Nguồn: ["Building Claude Code with Harness Engineering"](https://levelup.gitconnected.com/building-claude-code-with-harness-engineering-d2e8c0da85f0) (Level Up Coding / Medium)
> Mã nguồn tham khảo: `FareedKhan-dev/claude-code-from-scratch` (23 thành phần được xây dựng tăng dần)
> Ngày đánh giá: 2026-06-08

---

## 1. Tóm tắt (TL;DR)

Bài viết lập luận rằng thành công nhanh chóng của Claude Code **không đến từ một model tốt hơn hay prompt tốt hơn, mà từ "một harness phù hợp bao quanh một model phù hợp."** *Harness engineering* là bộ môn xây dựng **môi trường bao quanh** một model AI — vòng lặp, các công cụ (tool), việc quản lý ngữ cảnh, và cơ chế kiểm soát quyền — chứ không phải bản thân model.

Luận điểm cốt lõi: một harness tốt *"trao cho model đúng những công cụ nó cần, không thừa, và kiểm soát chính xác những gì nó được phép làm với chúng."* Trí tuệ nằm ở model; **sự an toàn, sự tập trung và độ bền nằm ở harness.**

**Bốn nguyên tắc nền tảng:**

| # | Nguyên tắc | Ý nghĩa |
|---|-----------|---------|
| 1 | **Model tự chủ (autonomy)** | Model đưa ra mọi quyết định; harness chỉ thực thi, không rẽ nhánh dựa trên đầu ra của model. |
| 2 | **Hành động qua công cụ** | Mọi hành động đều đi qua các lệnh gọi tool có kiểu (typed) và được kiểm tra theo schema. |
| 3 | **Ngữ cảnh được quản lý** | Những gì model thấy đều được chọn lọc, nén lại và chèn vào có chủ đích — không tích lũy một cách mù quáng. |
| 4 | **Quyền khai báo (declarative)** | Kiểm soát truy cập nằm trong cấu hình, không nằm trong các câu lệnh `if` thủ tục. |

---

## 2. Chi tiết — Năm thành phần kiến trúc

### 2.1 Vòng lặp chính đơn luồng (Single-Threaded Master Loop)
Một chu trình **tri giác → hành động → quan sát** không trạng thái (stateless):
1. Gọi model với lịch sử hội thoại hiện tại.
2. Thực thi các tool được yêu cầu thông qua registry điều phối (dispatch).
3. Đưa kết quả trở lại làm ngữ cảnh cho lượt tiếp theo.
4. Kết thúc khi `stop_reason ≠ "tool_use"` (model đã có câu trả lời cuối cùng).

Vòng lặp **giống hệt nhau bất kể độ phức tạp của tác vụ** — toàn bộ trí tuệ nằm ở model, không nằm ở vòng lặp.

### 2.2 Registry điều phối công cụ có kiểu (Typed Tool Dispatch Registry)
Một dictionary ánh xạ tên tool → hàm xử lý (handler).
- **Không có logic điều kiện:** `output = handler(tool_input)`.
- Mở rộng được mà không cần đụng tới vòng lặp chính.
- **Mô tả tool chính là chỉ dẫn, không phải tài liệu** — chúng ràng buộc hành vi của model hiệu quả hơn là việc nhắc nhở bằng prompt.
- Handler **trả về chuỗi, không bao giờ ném lỗi** — lỗi trở thành quan sát để model phản ứng.
- Ví dụ: `bash`, `read`, `write`, `edit`, `grep`, `glob`, `revert`.

### 2.3 Lớp quản lý ngữ cảnh (Context Management Layer)
Ba cơ chế ngăn ngữ cảnh suy giảm qua các phiên làm việc dài:

- **Nạp skill theo nhu cầu (progressive disclosure):** system prompt chỉ chứa mô tả *một dòng* của mỗi skill; hướng dẫn đầy đủ chỉ được nạp khi model gọi `load_skill()`. Một danh mục trăm skill chỉ tốn *hàng trăm* token, không phải hàng nghìn.
- **Nén ba lớp (tự kích hoạt khi dùng ~92% ngữ cảnh):**
  - Tin nhắn gần đây giữ nguyên văn (bộ nhớ làm việc).
  - Tin nhắn cũ được tóm tắt qua một lệnh gọi API riêng.
  - Bản tóm tắt được lưu vào `.agent_memory.md` để khôi phục phiên.
- **Đồ thị tác vụ dựa trên file:** một cấu trúc JSON lưu trữ phụ thuộc/trạng thái/độ ưu tiên của tác vụ, tồn tại qua sự cố crash và cho phép phối hợp đa agent qua các chuyển trạng thái nguyên tử (atomic), được bảo vệ bằng lock.

### 2.4 Kiểm soát quyền dựa trên luật (Rule-Based Permission Governance)
Ba mức đánh giá:
- **Luôn từ chối** — các mẫu nguy hiểm (ví dụ `rm -rf /`).
- **Luôn cho phép** — các thao tác an toàn đã biết.
- **Cần người dùng phê duyệt** — yêu cầu sự đồng ý rõ ràng trước khi thực thi.

Được hỗ trợ bởi một **event bus vòng đời** để các hook bên ngoài có thể quan sát hoặc chặn mọi lệnh gọi tool.

### 2.5 Lớp phối hợp đa agent (Multi-Agent Coordination Layer)
- **Cô lập ngữ cảnh subagent:** các agent con tạm thời chạy trong ngữ cảnh mới; chỉ bản tóm tắt cuối cùng được trả về, loại bỏ các lượt đọc/grep trung gian để agent cha giữ đúng mức trừu tượng.
- **Ủy thác cho đồng đội bất đồng bộ:** các chuyên gia thường trực (explorer, writer) nhận tác vụ qua **hộp thư JSONL** và tích lũy ngữ cảnh codebase theo thời gian.
- **Giao thức điều khiển bằng FSM:** máy trạng thái (`IDLE → REQUEST → WAIT → RESPOND`) điều phối việc trao đổi giữa các agent.
- **Cô lập bằng git worktree:** các tác vụ song song chạy trong các worktree riêng, loại bỏ xung đột ở cấp file.

### 2.6 Các mẫu (pattern) xuyên suốt

| Pattern | Tác dụng |
|---|---|
| **Lập kế hoạch TodoWrite** | Model gọi `todo_write()` với danh sách bước đầy đủ, thực thi theo thứ tự, gọi `todo_update()` sau mỗi bước; kế hoạch được chèn lại như một nhắc nhở hệ thống để chống lệch hướng. Ngôn ngữ mệnh lệnh mạnh ("ALWAYS call todo_write") hiệu quả hơn các gợi ý nhẹ nhàng. |
| **Progressive disclosure** | Khám phá skill theo metadata trước + chèn toàn văn theo nhu cầu. |
| **Thực thi tác vụ nền** | Các luồng daemon đẩy các bài test/build dài ra khỏi vòng lặp chính; thông báo hoàn thành đến dưới dạng tin nhắn người dùng được chèn vào. Thời gian thực bị giới hạn bởi thao tác chậm nhất, không phải tổng. |
| **Đồng đội thường trực** | Lead ghi tác vụ vào hộp thư đến của đồng đội; đồng đội chạy vòng lặp agent đầy đủ và trả về qua hộp thư phản hồi — hoàn toàn bất đồng bộ. |

### 2.7 Tăng cường cho môi trường production (ngoài các ví dụ giảng dạy)
Streaming token thời gian thực · hơn 18 tool · quyền khai báo bằng YAML · lưu trữ phiên (resume/fork) · prompt caching & tối ưu KV · runtime MCP cho tool bên ngoài · hộp thư Redis pub/sub (thay JSONL ở quy mô lớn) · xử lý các tình huống biên nâng cao của worktree.

---

## 3. Đề xuất — Ánh xạ vào repo harness-skills của *chúng ta*

Bài viết mô tả, từ những nguyên lý đầu tiên, đúng kiến trúc mà repo này đã vận hành dưới dạng **skills + rules + hooks**. Việc ánh xạ ra giúp vừa xác nhận điểm mạnh vừa lộ ra các khoảng trống cụ thể.

### 3.1 Những điểm đã đồng nhất ✅
| Khái niệm trong bài | Tương đương trong repo |
|---|---|
| Quyền khai báo | Cấu hình `settings.json` + `settings.local.json` |
| Event bus vòng đời / chặn mọi lệnh gọi tool | `hooks/` (PreToolUse/PostToolUse) đăng ký trong `settings.json` |
| Cô lập ngữ cảnh subagent, chỉ trả về tóm tắt | Hợp đồng subagent trong `rules/orchestration.md` (tóm tắt 150–300 từ, "không dump file thô") |
| Cô lập git worktree | Skill `/using-git-worktrees` |
| Đồ thị tác vụ / lập kế hoạch | Định dạng task XML trong `specs/<slug>/PLAN.md` + wave parallelism |
| Progressive disclosure của skill | `skills/<name>/SKILL.md` nạp khi gọi `/skill`; `skills/README.md` làm chỉ mục |
| Mức quyền + hard gate | Lane của `feature-intake` + `risk-corroboration.sh` |

### 3.2 Các khoảng trống đáng cân nhắc
1. **Nén ngữ cảnh / `.agent_memory.md`.** Cơ chế tự nén ở ~92% + một file bộ nhớ có thể khôi phục trong bài tương ứng với `specs/STATE.md` của ta, nhưng của ta *chỉ chạy lúc kết thúc phiên* (`state-breadcrumb.sh`), không phải là một trigger nén trực tiếp. Cân nhắc biến giao thức "chụp snapshot khi ngân sách <40%" (đã được gợi ý trong `orchestration.md`) thành một hook/skill thực sự.
2. **"Mô tả tool chính là chỉ dẫn."** Đáng để rà soát lại các trường `description:` trong front-matter của `SKILL.md` dưới góc nhìn này — chúng là thứ *duy nhất* được nạp cho tới khi skill được gọi, nên cần đọc như chỉ dẫn định tuyến, không phải tóm tắt.
3. **Hộp thư đồng đội bất đồng bộ (JSONL/Redis).** Ta có subagent `Agent(...)` và `SendMessage`, nhưng chưa có mẫu chuyên gia thường trực tích lũy ngữ cảnh. Ưu tiên thấp, nhưng việc tách explorer/writer có thể gợi ý cho một đồng đội `Explore` sống lâu phục vụ công việc trên repo lớn.
4. **Thông báo tác vụ nền.** Harness của ta đã tự gọi lại khi tác vụ nền hoàn thành; "hoàn thành → tin nhắn người dùng được chèn" của bài là cùng ý tưởng — không cần làm gì, chỉ xác nhận thiết kế.
5. **Giao thức agent điều khiển bằng FSM.** Cơ chế phối hợp của ta là văn xuôi theo luật, không phải máy trạng thái tường minh. Có lẽ *không* đáng hình thức hóa ở quy mô của ta, nhưng ghi nhận đây là một non-goal có chủ đích thì sạch sẽ hơn để ngầm định.

### 3.3 Bước tiếp theo đề xuất
Đây là một sản phẩm **kiến thức/quyết định**, không phải code. Nếu có hành động nào trong §3.2 (đặc biệt mục 1–2) được triển khai, hãy chạy `/compound` để kết tinh quyết định vào `docs/solutions/`. Nếu không, bài đánh giá này đứng như một tài liệu tham khảo.

> ⚠️ Lưu ý: nội dung được trích xuất qua một bản mirror Freedium và được model tóm tắt. Hãy kiểm chứng các chi tiết cụ thể (con số "1 tỷ USD / sáu tháng", ngưỡng nén chính xác) với bài gốc trước khi trích dẫn ra bên ngoài.
