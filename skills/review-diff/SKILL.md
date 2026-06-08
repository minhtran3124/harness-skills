---
name: review-diff
description: Use when you want to visualize what changed before review or PR — generates a Markdown review file with C4 architecture diagrams and a code walkthrough of the current git diff. Not a correctness review; for bug-hunting use /code-review.
allowed-tools: Bash(git *), Bash(mkdir *), Read, Glob, Grep, Write, Edit
---

# PR Review Markdown Generator

Generate a Markdown review file for the current uncommitted git changes (or a specified PR). Save it to `.review/review.md`.

## What to produce

The file must contain three sections:

### 1. System Architecture Diagram (C4 Container Level)

A single Mermaid flowchart showing the system architecture with the changed/new components highlighted:

- Use `flowchart TD` (top-down) for the diagram
- Show the request flow from user through frontend to backend
- Group unchanged peer components into a single summary node (e.g. "Other 5 scenarios")
- Highlight changed components with dark green fill/border for dark theme: `fill:#0d3320,stroke:#238636,stroke-width:3px,color:#aff0b5`
- Highlight new components with dark green fill/border and a green circle emoji prefix: `fill:#0d3320,stroke:#238636,stroke-width:3px,color:#aff0b5`
- Highlight data sources read by new code with dark blue: `fill:#0d2044,stroke:#388bfd,stroke-width:2px,color:#79c0ff`
- Include a legend below the diagram

### 2. Component Detail Flowchart

A Mermaid flowchart showing the internal logic flow of the changed component:

- Show the decision tree / branching logic
- Mark new code paths with dark green and green circle emoji: `fill:#0d3320,stroke:#238636,stroke-width:2px,color:#aff0b5`
- Mark removed paths with dark red dashed and red circle emoji: `fill:#3d0f14,stroke:#da3633,stroke-width:2px,stroke-dasharray:5 5,color:#ffa198`
- Mark unchanged paths with dark grey: `fill:#1c1c1c,stroke:#555,color:#aaa`
- Add a description table below the diagram explaining each node

### 3. Code Walkthrough

For each logical chunk of the change:
- A narrative paragraph explaining what the code does and why
- An inline diff block using standard markdown diff syntax (` ```diff `)

## Diagram guidelines

Keep Mermaid node labels SHORT (under 25 characters) to prevent text truncation. Use the description table below each diagram for detailed explanations. Avoid `\n` for line breaks in labels — use single-line text or unicode separators like `·` or `‹›`.

Always include this Mermaid init for dark theme rendering:
```
%%{init: {'theme': 'dark', 'flowchart': {'useMaxWidth': true}} }%%
```

## Steps

1. Run `git diff HEAD` and `git diff --stat HEAD` to understand the changes
2. Read the changed files and their surrounding architecture (imports, callers, class hierarchy)
3. Create `.review/` directory if it doesn't exist
4. Remove existing `.review/review.md` if it exists (clean file before generating)
5. Generate `.review/review.md` with all three sections
6. Verify the Mermaid code blocks are well-formed and node labels are under 25 characters

## Arguments

- `$ARGUMENTS` — optional: a git ref, PR number, or branch name to diff against (defaults to uncommitted changes vs HEAD)