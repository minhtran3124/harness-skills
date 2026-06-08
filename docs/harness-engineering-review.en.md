# Building Claude Code with Harness Engineering — Review

> Source: ["Building Claude Code with Harness Engineering"](https://levelup.gitconnected.com/building-claude-code-with-harness-engineering-d2e8c0da85f0) (Level Up Coding / Medium)
> Reference implementation: `FareedKhan-dev/claude-code-from-scratch` (23 progressively-built components)
> Reviewed: 2026-06-08
> Vietnamese version: [`harness-engineering-review.md`](./harness-engineering-review.md)

---

## 1. Summary (TL;DR)

The article argues that Claude Code's rapid success came **not from a better model or better prompts, but from "the right harness around the right model."** *Harness engineering* is the discipline of building the **environment surrounding** an AI model — the loop, the tools, the context curation, and the permission governance — rather than the model itself.

The core claim: a good harness *"gives the model precisely the tools it needs, nothing more, and governs exactly what it is allowed to do with them."* Intelligence lives in the model; **safety, focus, and durability live in the harness.**

**Four foundational principles:**

| # | Principle | Meaning |
|---|-----------|---------|
| 1 | **Model autonomy** | The model makes all decisions; the harness executes without branching on model output. |
| 2 | **Tool-mediated action** | Every action flows through typed, schema-validated tool calls. |
| 3 | **Managed context** | What the model sees is curated, compressed, and deliberately injected — never blindly accumulated. |
| 4 | **Declarative permissions** | Access control lives in configuration, not procedural `if` statements. |

---

## 2. Detail — The Five Architecture Components

### 2.1 Single-Threaded Master Loop
A stateless **perception → action → observation** cycle:
1. Call the model with the current conversation history.
2. Execute any requested tools via a dispatch registry.
3. Feed results back as context for the next turn.
4. Terminate when `stop_reason ≠ "tool_use"` (model reached a final answer).

The loop is **identical regardless of task complexity** — all intelligence is in the model, none in the loop.

### 2.2 Typed Tool Dispatch Registry
A dictionary mapping tool name → handler function.
- **Zero conditional logic:** `output = handler(tool_input)`.
- Extensible without touching the core loop.
- **Tool descriptions are instructions, not docs** — they constrain model behavior more effectively than behavioral prompting.
- Handlers **return strings, never raise** — errors become observations the model can react to.
- Examples: `bash`, `read`, `write`, `edit`, `grep`, `glob`, `revert`.

### 2.3 Context Management Layer
Three mechanisms prevent context-window degradation over long sessions:

- **On-demand skill loading (progressive disclosure):** the system prompt carries only *one-line* skill descriptions; full instructions load only when the model calls `load_skill()`. A hundred-skill catalog costs *hundreds* of tokens, not thousands.
- **Three-layer compression (auto-triggers ~92% context usage):**
  - Recent messages kept verbatim (working memory).
  - Older messages summarized via a dedicated API call.
  - Summary persisted to `.agent_memory.md` for session recovery.
- **File-based task graph:** a persistent JSON structure of task dependencies/status/priority that survives crashes and enables multi-agent coordination via atomic, lock-protected state transitions.

### 2.4 Rule-Based Permission Governance
Three evaluation tiers:
- **Always deny** — dangerous patterns (e.g. `rm -rf /`).
- **Always allow** — known-safe operations.
- **User-gated approval** — explicit consent before execution.

Backed by a **lifecycle event bus** so external hooks can observe or intercept every tool call.

### 2.5 Multi-Agent Coordination Layer
- **Subagent context isolation:** ephemeral children run in fresh contexts; only the final summary crosses back, discarding intermediate reads/greps so the parent stays at the right abstraction level.
- **Async teammate delegation:** persistent specialists (explorer, writer) receive tasks via **JSONL mailboxes** and accumulate codebase context over time.
- **FSM-governed protocols:** state machines (`IDLE → REQUEST → WAIT → RESPOND`) govern inter-agent messaging.
- **Git worktree isolation:** parallel tasks run in separate worktrees, eliminating file-level conflicts.

### 2.6 Key Patterns (cross-cutting)

| Pattern | What it does |
|---|---|
| **TodoWrite planning** | Model calls `todo_write()` with a full step list, executes in order, calls `todo_update()` after each; plan is re-injected as a system reminder to prevent drift. Strong imperative language ("ALWAYS call todo_write") beats soft suggestions. |
| **Progressive disclosure** | Metadata-first skill discovery + on-demand full-text injection. |
| **Background task execution** | Daemon threads push long tests/builds off the main loop; completion notifications arrive as injected user messages. Wall time bounded by the slowest op, not the sum. |
| **Persistent teammates** | Lead writes tasks to a teammate inbox; teammate runs a full agent loop and returns via a response mailbox — fully async. |

### 2.7 Production Hardening (beyond the teaching examples)
Real-time token streaming · 18+ tools · YAML declarative permissions · session persistence (resume/fork) · prompt caching & KV optimization · MCP runtime for external tools · Redis pub/sub mailboxes (replacing JSONL at scale) · advanced worktree edge-case handling.

---

## 3. Suggestions — How this maps to *our* harness-skills repo

The article describes, from first principles, the same architecture this repo already operationalizes as **skills + rules + hooks**. Mapping it out surfaces both validation and concrete gaps.

### 3.1 Where we already align ✅
| Article concept | Our equivalent |
|---|---|
| Declarative permissions | `settings.json` + `settings.local.json` permission config |
| Lifecycle event bus / intercept every tool call | `hooks/` (PreToolUse/PostToolUse) wired in `settings.json` |
| Subagent context isolation, final-summary-only | `rules/orchestration.md` subagent contract (150–300 word summaries, "no raw file dumps") |
| Git worktree isolation | `/using-git-worktrees` skill |
| File-based task graph / planning | `specs/<slug>/PLAN.md` XML task format + wave parallelism |
| Progressive disclosure of skills | `skills/<name>/SKILL.md` loaded on `/skill` invocation; `skills/README.md` as the index |
| Permission tiers + hard gates | `feature-intake` lanes + `risk-corroboration.sh` |

### 3.2 Concrete gaps worth considering
1. **Context compression / `.agent_memory.md`.** The article's auto-compression at ~92% usage + a recoverable memory file maps to our `specs/STATE.md` breadcrumb, but ours is *session-end only* (`state-breadcrumb.sh`), not a live compression trigger. Consider a documented "snapshot at <40% budget" protocol (already hinted in `orchestration.md`) made into an actual hook/skill.
2. **"Tool descriptions as instructions."** Worth auditing our `SKILL.md` front-matter `description:` fields against this lens — they are the *only* thing loaded until invocation, so they should read as routing instructions, not summaries.
3. **Async teammate mailboxes (JSONL/Redis).** We have `Agent(...)` subagents and `SendMessage`, but no persistent specialist-with-accumulating-context pattern. Low priority, but the explorer/writer split could inform a long-lived `Explore` teammate for big-repo work.
4. **Background task notifications.** Our harness already re-invokes on background completion; the article's "completion → injected user message" is the same idea — no action needed, just confirms the design.
5. **FSM-governed agent protocols.** Our orchestration is rule-prose, not an explicit state machine. Probably *not* worth formalizing for our scale, but noting it as a deliberate non-goal is cleaner than leaving it implicit.

### 3.3 Recommended next step
This is a **knowledge/decision artifact**, not code. If any of §3.2 (esp. items 1–2) is acted on, run `/compound` to crystallize the decision into `docs/solutions/`. Otherwise this review stands as a reference doc.

> ⚠️ Caveat: content was extracted via a Freedium mirror and summarized by a model. Verify specifics (the "$1B / six months" figure, exact compression threshold) against the original before citing externally.
