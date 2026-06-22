---
name: jt-ls
description: Lists all active juggle tickets (with title and last-updated date), optionally including completed/archived tickets. Use when the user invokes "/jt-ls", wants to "list juggle tickets", "show open tickets", "see active work", "what tickets do I have", or any equivalent phrasing.
argument-hint: [--all]
allowed-tools: Bash(*) Read
---

# jt-ls: List juggle tickets

The user invoked this with: $ARGUMENTS

If `$ARGUMENTS` contains `--all`, also include completed/archived tickets.

## Steps

### 0. Resolve tickets directory

```bash
cat ~/.jt-config 2>/dev/null
```

Use the path, or default to `~/juggle-task`. Store as `TICKETS_DIR`.

### 1. Walk ticket dirs

Active tickets live at `<TICKETS_DIR>/<ID>/CONTEXT.md`. Completed (archived) tickets live at `<TICKETS_DIR>/completed/<ID>/CONTEXT.md`.

Skip directories named `projects` or `completed` themselves (they're the parents, not tickets).

For each CONTEXT.md, extract:
- **ID**: `basename "$(dirname <path>)"`
- **Title**: first `# <ID>: <title> — Agent Context` line, with the `<ID>: ` prefix and ` — Agent Context` suffix stripped
- **Status**: line matching `**Status**: <value>` (lowercased, no spaces)
- **Last updated**: line matching `**Last updated**: <value>`
- **Project**: line matching `**Project**: [<id>](...)` — extract just `<id>` if present
- **Completed?**: parent dir == `completed`

If `--all` was NOT passed, filter out tickets whose status is in `{archived, closed, done, cancelled, canceled, completed, duplicate}` (case-insensitive) — these are terminal states.

### 2. Print a table

Output a clean monospace table:

```
TICKET          TITLE                                     PROJECT        LAST UPDATED
------          -----                                     -------        ------------
JUD-6321        Define Judgment Event Identifier          EPIC-1         2026-05-19 12:48
JUD-6404        Build JudgmentHub broker                  EPIC-1         2026-05-20
JT-1            Build Juggle-Task                                         2026-05-13 17:42
```

Truncate title to 40 chars. If a ticket is from `completed/`, append `  (completed)` to its title (only relevant with `--all`).

Sort: active tickets first, then completed (when `--all`). Within each group, by last-updated descending.

If no tickets match, say so: "No active tickets. (Try `/jt-ls --all` to include completed.)" or, when `--all` and empty: "No tickets found at `<TICKETS_DIR>`. Run `/jt-init <ID>` to create one."

### 3. Wait

Don't take further action — just show the list and stop.
