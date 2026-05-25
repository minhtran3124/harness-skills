---
name: xia2
description: Portable research-first feature discovery — investigates what exists locally, upstream on GitHub, and in version-matched official docs before any implementation. Reads project-specific signal mappings from PROJECT.md (sibling file). Use before adding new features, capabilities, or integrations to answer what already exists and what is the lightest credible path forward.
allowed-tools: Glob, Grep, Read, Write, WebSearch, WebFetch, Bash(git log *), Bash(git show *), Bash(cat *), Bash(ls *)
---

# Xia2 — Research-First Feature Discovery (Portable)

Portable version of `xia`. Universal logic lives here in `SKILL.md`; project-specific signal mappings live in `PROJECT.md` (sibling file). Same skill works across projects by swapping `PROJECT.md`.

Answer five foundational questions before any implementation begins:

1. **What is this repo really?** Detect the actual tech stack from manifests, configs, and lockfiles — never guess from folder names or branding.
2. **What already exists locally?** Search for reusable code, abstractions, and extension points before proposing anything new.
3. **What does the ecosystem already support?** Check upstream GitHub repositories for established patterns that match the need.
4. **What do the current official docs actually recommend?** Query version-matched documentation, not generic web results.
5. **What is the lightest credible path from here?** Recommend: reuse existing > adapt upstream > use built-in > build from scratch.

<HARD-GATE>
Do NOT write code, edit files, or scaffold anything until the research brief is complete and delivered to the user. The brief is the deliverable — not implementation. This gate applies regardless of how simple the feature seems. If the user explicitly says "skip research" or "just implement it", note the waiver at the top of your response and proceed — but do not waive it yourself.

**Even when waived,** run the Decision Procedure mentally and surface any Deep signal that fired as a one-line risk warning at the top of your response (e.g., *"Note: this is a schema/migration change (Deep) — destructive operations like DROP COLUMN cannot be undone."*). The waiver covers the research workflow, not the duty to flag known risks.
</HARD-GATE>

<PROJECT-CONFIG-GATE>
Before classifying any prompt, read `PROJECT.md` (sibling of this file) for project-specific signal mappings: high-blast files, dependency manifests, shared contracts, session primitives, auth surfaces, knowledge bases, and entry-point patterns.

If `PROJECT.md` is **missing**, **incomplete** (required sections empty), or **stale** (references non-existent files): **halt and instruct the user** to bootstrap one via `/bootstrap-xia2` (auto-scan helper) or by copying `PROJECT.template.md`. Do **not** proceed with classification using guessed mappings — the Decision Procedure depends on these.
</PROJECT-CONFIG-GATE>

---

## Depth Modes

Choose depth from **concrete signals**, not gut feel. Do not estimate "implementation time" before research — that is circular.

**Decision procedure (in order):**

1. Check **Deep** signals — *any one* triggers Deep.
2. If not Deep, check **Quick** conditions — *all must hold* to qualify as Quick.
3. Otherwise, choose **Standard**.

| Mode | Conditions | Coverage | Worked example |
|---|---|---|---|
| **Deep** *(any one triggers)* | • Schema or migration change<br>• Touches a high-blast-radius file *(see `PROJECT.md > High-Blast-Radius Files`)*<br>• New external integration (third-party SDK, payment, auth, AI provider, broker, message queue, etc.)<br>• New runtime dependency added to a manifest *(see `PROJECT.md > Dependency Manifests`)*<br>• Changes a shared runtime configuration contract *(see `PROJECT.md > Shared Runtime Contracts`)*<br>• Changes auth flow or transaction/session-scoping rules *(see `PROJECT.md > Auth Surfaces` and `Session/Transaction Primitives`)* | Wide local coverage + multiple upstream repos + official changelogs + explicit risk analysis | *"Add a new column to a model and write the migration"* — schema change triggers Deep regardless of column type. |
| **Quick** *(all must hold)* | • No Deep signal triggered<br>• Touches ≤1 file **AND** adds no new public callable in a shared module (data access layer, service, helper, calculation that callers will use)<br>• No new dependency<br>• No public API contract change *(see `PROJECT.md > Public API Contract Types`)*<br>• Not inside any entry point *(see `PROJECT.md > Entry Point Patterns`)* | Local artifact scan + brief local search | *Add a debug `__repr__`/`Display`/`toString` to an internal model; tweak a log prefix string; reword a static template.* |
| **Standard** *(default)* | Anything not qualifying as Deep or Quick | Full local mapping + upstream patterns + version-matched docs | *"Add rate limiting to the API endpoints"* — new middleware, possibly new dep, no schema change, no high-blast-radius file. |

**Signals can be explicit or implicit.** A Deep signal triggers whether the prompt names it directly or implies it through a description:

- *Explicit* — prompt names the file path, dep name, or system (e.g., *"edit `<path listed in PROJECT.md>`"* or *"add `library-x` to the manifest"*).
- *Implicit* — description maps to a known high-blast-radius file (e.g., *"tweak the connection-pool retry"* → file under `PROJECT.md > High-Blast-Radius Files`); a chosen library forces a new dep (e.g., *"add Library X as the Y backend"* → not stdlib, requires a manifest entry); a single-line config change alters a shared contract (e.g., *"change the default model"* → contract listed in `PROJECT.md > Shared Runtime Contracts`).

Treat implicit signals the same as explicit ones — what matters is the underlying change, not whether the prompt names it. **If an implicit signal is uncertain, treat it as an uncertain signal and apply Tiebreaker #1 (→ Standard).**

**Tiebreakers (read in order):**

1. **If you cannot map to a mode in ~10 seconds with concrete signals, choose Standard.** Do not reason your way into Quick to save time.
2. **User urgency does not raise depth.** "It's important" / "ASAP" is not a Deep signal.
3. **Prompt brevity does not lower depth.** A one-line request can still be Deep.
4. **If the user explicitly requests a depth, honor it** — but if their request conflicts with a Deep signal, surface the conflict before proceeding.

---

## Mandatory Workflow Sequence

Execute in this order. Do not skip or reorder steps.

### Step 1 — Check for Research Waiver
If the user explicitly waived research, note it and stop the workflow. (HARD-GATE still requires surfacing Deep signals as risk warnings — see HARD-GATE block above.)

### Step 2 — Read the Repo Contract

**Sub-step 2a — Load `PROJECT.md` (REQUIRED)**

Read `PROJECT.md` (sibling of this `SKILL.md`). Verify required sections are present and non-empty:
- `High-Blast-Radius Files`
- `Dependency Manifests`
- `Shared Runtime Contracts`
- `Session/Transaction Primitives`
- `Public API Contract Types`
- `Entry Point Patterns`

Optional but recommended sections: `Auth Surfaces`, `Knowledge Bases`, `Recent Decisions Folder`.

If any required section is missing or empty, **halt** and instruct the user to run `/bootstrap-xia2` (auto-scan helper) or copy `PROJECT.template.md` and fill in the gaps. Do not proceed with guessed mappings.

**Sub-step 2b — Read project contract docs**

Read the universal contract docs (if present at the repo root):
- `AGENTS.md`, `CLAUDE.md`, `README.md`

Then read the project-specific docs listed in `PROJECT.md > Knowledge Bases`.

If the project tracks solved problems or decisions in a knowledge base folder, search for prior solutions in this domain using INDEX-first lookup:
1. If the knowledge base declares an **Index file** in `PROJECT.md > Knowledge Bases`: read that file first (single read, O(1)) — it summarises all entries with module, tags, and applicable context. Scan for domain matches in-memory.
2. If the knowledge base declares a **Critical patterns file**: read it regardless of domain — these are high-value learnings that apply broadly.
3. From Index matches, read at most **3 solution files**, prioritised by recency (most recent first per Index order). If more than 3 match, note remaining paths as `[Skipped — see Index]` in the brief without reading them.
4. **Fallback only** (if no Index file is declared in `PROJECT.md`): use grep with the search keys from `PROJECT.md > Knowledge Bases`, then read at most 3 results.

Treat any entries flagged as low-confidence (or equivalent project-specific stale marker) as unverified — cross-check against current code before acting.

This tells you constraints, conventions, and what the team has already decided.

**Depth re-evaluation gate:** After reading docs, re-run the Decision Procedure with the new evidence. Do not stay locked to the initial choice. **Depth only moves up, never down** — fresh evidence cannot make a feature simpler than the prompt suggested.

- **Upgrade to Deep** if docs surface any Deep signal not visible from the prompt alone:
  - Knowledge base documents a prior migration or schema change in the same module
  - Docs name a high-blast-radius file (per `PROJECT.md`) as in-scope
  - Docs mention a new external integration or new dependency would be required
  - Docs reveal a shared contract or session primitive (per `PROJECT.md`) is involved
- **Upgrade to Standard** if docs break any Quick condition:
  - Docs reveal the change must touch >1 file
  - Docs reveal a public API contract type (per `PROJECT.md`) is on the path
  - Docs reveal an entry-point pattern (per `PROJECT.md`) is in scope
- **Treat low-confidence docs as unverified** — they may be stale. A low-confidence doc cannot, by itself, justify upgrading depth; cross-check against current code first.

Announce the upgrade: *"Upgrading depth to [mode] based on [specific signal] from [doc path]."*

### Step 2.5 — Scan Recent Decisions (conditional)

If `PROJECT.md > Recent Decisions Folder` is set (not `none`), scan that folder for in-progress decisions on the same domain. This prevents re-researching something already decided.

```bash
# Substitute <decisions-path> and <lookback> from PROJECT.md
ls -1t <decisions-path>/ 2>/dev/null | head -<lookback>
```

For each recent directory, check for relevant files:

```bash
grep -rl "<domain>" <decisions-path>/ --include="*.md" 2>/dev/null | sort -r | head -10
```

If relevant docs found:
- Read them
- Note decisions made, alternatives ruled out, constraints identified
- Label as `Local (decisions)` in the brief

**Stop condition:** If a decision doc fully answers the research question, note this in the brief and skip Steps 5-6 unless the user requests a second opinion.

If `PROJECT.md > Recent Decisions Folder` is `none`, skip this step.

### Step 3 — Map the Repo from Real Artifacts
Detect the actual stack from manifests and configs — never infer from directory names.

Common manifests by ecosystem:
- Python: `pyproject.toml`, `requirements*.txt`, `setup.cfg`, `Pipfile`
- Node: `package.json`, `pnpm-lock.yaml`, `tsconfig.json`
- Rust: `Cargo.toml`, `Cargo.lock`
- Go: `go.mod`, `go.sum`
- Java/Kotlin: `pom.xml`, `build.gradle*`
- Ruby: `Gemfile`, `Gemfile.lock`
- DB/infra: `alembic/`, `migrations/`, `docker-compose.yml`, `*.env.example`
- CI/CD: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`

Record: primary language + runtime, frameworks/platforms, relevant packages, detectable versions.

### Step 4 — Search Locally for Reuse
Use `Glob` and `Grep` to find existing code before proposing anything new:
- Existing abstractions, base classes, or extension points
- Similar patterns already implemented elsewhere
- Relevant tests that document existing behavior
- Config or feature flags that might already expose the capability

**Stop local search only when artifacts confirm absence** — not when the first search comes up empty.

### Step 5 — Check Upstream Patterns (Standard + Deep only)
After the local picture is clear, search GitHub for established patterns:
- Use `WebSearch` with queries like: `site:github.com <framework> <feature> implementation`
- Target repositories using the same stack and versions
- Look for: existing libraries, common patterns, reference implementations
- Label all upstream findings as `Upstream`

Treat upstream search as best-effort — a failed search does not block the brief.

### Step 6 — Check Official Docs (Standard + Deep only)
After targeting specific stack/versions, query version-matched documentation:
- Use `WebSearch` or `WebFetch` with explicit version constraints
- Check the official docs for the detected version, not "latest stable"
- Look for: built-in capabilities that already support the feature, recommended APIs, deprecation notices
- Label all doc findings as `Docs`

### Step 7 — Save and Deliver the Research Brief
Fill the template in `references/research-brief-template.md` with all findings, then:

1. **Save** the completed brief to `<spec-dir>/research-brief.md` — where `<spec-dir>` is the spec directory passed by the caller (e.g., `specs/YYYY-MM-DD/<topic>/`). If no spec directory was passed, save to `specs/research-brief.md` as fallback.
2. **Deliver** the brief in the conversation so the caller has immediate context.

Do NOT write code or edit any file other than `research-brief.md`.

---

## Tool Routing

| Task | Tool | Query pattern |
|---|---|---|
| Find manifests/configs | `Glob` | `pyproject.toml`, `requirements*.txt`, `package.json`, `Cargo.toml`, `go.mod` |
| Search local code | `Grep` | Pattern-match across source files |
| Read source files | `Read` | Direct file read |
| Scan recent decisions | `Bash(ls *)` + `Grep` | Substitute path from `PROJECT.md > Recent Decisions Folder` |
| Upstream GitHub patterns | `WebSearch` | `site:github.com <stack> <feature> example` |
| Official documentation | `WebSearch` | `<library> <version> <feature> site:<official-domain>` |
| Specific doc pages | `WebFetch` | Direct URL from known official source |
| Git history for context | `Bash(git log *)` | `git log --oneline --follow -- <path>` |

**Evidence labeling — required on every finding:**
- `Local` — found in this repository
- `Upstream` — found in external GitHub repo
- `Docs` — from official versioned documentation
- `Inference` — reasoned from available evidence (weakest — flag explicitly)

---

## Guardrails

- **Never proceed without `PROJECT.md`** — the Decision Procedure depends on project-specific mappings. Halt and request bootstrap if missing or incomplete.
- **Never guess the stack** from folder names, repo name, or branding — always verify from manifests.
- **Never stop local search early** — absent evidence is not proof of absence. Search multiple patterns before concluding something doesn't exist locally.
- **Always explain why alternatives lost** — if you recommend building over reuse, state why reuse was ruled out with evidence.
- **Version discipline** — extract actual versions from manifests or lockfiles. Never default to "latest stable" when you can read the real version.
- **Research before code** — do not interleave discovery with implementation. The brief comes first, always.
- **When docs conflict with local behavior** — surface both findings side-by-side. Do not privilege authority over observed reality.

---

## Arguments

- `$ARGUMENTS` — optional: the feature or capability to research. If omitted, ask the user to describe what they want to add before starting.
- Depth mode can be specified: `quick`, `standard`, or `deep` (default: `standard`).

---

## See also

- `PROJECT.md` — per-project signal mappings (required).
- `PROJECT.template.md` — blank template for new projects.
- `/bootstrap-xia2` — auto-scan helper that bootstraps `PROJECT.md` from a repo scan.
- `tests/structural/` — Decision Procedure regression tests against current `PROJECT.md`.
- `tests/behavioural/` — pressure scenarios validating HARD-GATE adherence.
