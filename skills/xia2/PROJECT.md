# xia2 — Project Configuration

This file provides project-specific signal mappings consumed by `xia2/SKILL.md`. It is a reusable template — regenerate it per project.

> **Maintenance:** auto-scan via `/bootstrap-xia2` (init or update mode), then human-review. Re-validate after major architectural changes.

---

## Project identity

Describe what this project is and how to locate it.

- **Name:** <your project name>
- **Stack:** <language + framework + key infra, e.g. Python 3.12 + FastAPI + PostgreSQL + Redis>
- **Repo root (relative to this file):** <relative path that resolves to the app root, e.g. `../../../`>

---

## High-Blast-Radius Files

List the files that, when touched, force **Deep** review regardless of how small the change appears — e.g. your DB session manager, core service modules, or any single file many features depend on.

- `app/services/<core_service>.py` — central service many features route through
- `app/repositories/<critical_repo>/` — high-volume data-access subtree
- `app/database/<session_manager>.py` — connection pool / session scoping; affects every DB call

> Add new entries when a single file becomes a bottleneck for many features. An empty list means the Deep override loses a key signal.

---

## Dependency Manifests

Name the files that declare dependencies, and which ones should trigger Deep when changed.

- `<runtime manifest>` (e.g. `requirements.txt`, `pyproject.toml`) — runtime deps; **adding entries triggers Deep**
- `<test-only manifest>` (e.g. `requirements-test.txt`) — test deps; does **not** trigger Deep on its own

---

## Shared Runtime Contracts

Configuration objects, modules, or protocol shapes whose contract change affects many call sites.

- `<AppConfig object>` (in `app/config/<config>.py`) — central settings consumed across the app (model/feature flags, limits, timeouts); document where defaults come from
- **<streaming or event protocol>** (event shapes in `app/utils/<protocol>.py`) — message/event shapes consumed by clients; list the event types

---

## Session/Transaction Primitives

Functions/methods that scope DB sessions or transactions. **Changing scoping rules triggers Deep.**

- `<request_session_dep>()` (in `app/database/<session_manager>.py`) — request-scoped session via dependency injection; for HTTP request handlers
- `<isolated_session>()` (in `app/database/<session_manager>.py`) — isolated session for background/long-running tasks
- **Project rule:** state the rule for which primitive each context must use, and note that switching primitives between contexts is a Deep change.

---

## Auth Surfaces

Files implementing the authentication flow. **Changes here trigger Deep.**

- `app/middleware/` (token validation / auth provider integration)
- `<current_user_dependency>` (used to guard protected routes at the router level)

---

## Knowledge Bases

Files to read at Step 2b in addition to AGENTS.md/CLAUDE.md/README.md.

- `<architecture doc>` (e.g. `.claude/rules/architecture.md`) — authoritative architecture reference (layers, models, services)
- `<engineering guidelines>` (e.g. `.claude/rules/guidelines.md`) — code style, error handling, async, testing
- `<solved-problems folder>` (e.g. `docs/solutions/`) — solved problems with metadata
  - **Index:** read the index file first (single read, O(1)); fallback grep keys like `module: <domain>`, `affects.*<file>`
  - **Critical patterns:** a patterns file always read regardless of domain
  - **Stale marker:** define what marks an entry unverified (e.g. `confidence: low` or missing `confirmed_at`)

---

## Recent Decisions Folder

Where recent design/decision records live, and how far back to look.

- **Path:** <e.g. `specs/`>
- **Schema:** <how subfolders are organized, e.g. date-based `YYYY-MM-DD/`>
- **Lookback:** <window in days, e.g. 60 days>

---

## Public API Contract Types

For the Quick condition: changes to these break the contract → fail Quick.

- Router/endpoint signatures (in `app/routers/`)
- Response schema models (in `app/schemas/`)
- Published event/protocol shapes (in `app/utils/<protocol>.py`)

---

## Entry Point Patterns

For the Quick condition: any change inside these is **NOT** Quick.

- `app/routers/` — HTTP route handlers
- Middleware registration in `app/main.py`
- Background/worker services: `<list your background service dirs>`
- Lifespan/startup hooks (e.g. `app/services/lifespan.py`)

---

## Notes for maintainers

- **High-blast list is the highest-leverage signal** — keep it current as new bottlenecks emerge.
- **Shared config contract evolves** — when adding new fields to a central config object, treat it as a Deep change since downstream defaults rely on it.
- **Client-consumed protocols** — adding new event types to a protocol consumed by clients is Deep (clients must handle them).
