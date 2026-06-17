---
name: jt-sync
description: Refreshes ticket statuses from Linear and moves terminal tickets to a `completed/` subdirectory. Use when the user invokes "/jt-sync", wants to "sync ticket statuses from Linear", "refresh which tickets are still active", "check Linear for closed tickets", or after closing/reopening issues in Linear. Also runs in the background after `jt ls` / `jt open` (TTL-gated).
allowed-tools: Bash(*) Read Write Edit mcp__claude_ai_Linear__get_issue
---

# jt-sync: Refresh ticket statuses from Linear

Run silently — don't ask the user any questions. Print only the final summary at the end.

## Steps

### 0. Resolve tickets directory

Run: `cat ~/.jt-config 2>/dev/null`. Use the path, or default to `~/juggle-task`. Store as `TICKETS_DIR`.

### 1. Collect all tickets (active + completed)

```bash
shopt -s nullglob
find "$TICKETS_DIR" -maxdepth 3 -name CONTEXT.md -type f 2>/dev/null
```

For each CONTEXT.md, determine:
- The ticket dir: `$(dirname <path>)`
- The ticket ID: `$(basename $(dirname <path>))`
- Whether it's currently archived: parent dir == `completed`
- The Linear URL (from CONTEXT.md or README.md if present): grep `https://linear.app/.*/issue/`

Skip tickets that don't have a Linear URL (no way to sync them).

### 2. Check each ticket against Linear

For each ticket with a Linear URL, call `mcp__claude_ai_Linear__get_issue` with its ticket ID.

Map Linear `state.type` to local Status:
- `started` / `unstarted` / `backlog` / `triage` → leave local Status as-is (or set to `in-progress` if currently archived locally)
- `completed` / `cancelled` → set local Status to `archived`

### 3. For each status change, update the ticket

**If Linear shows terminal (completed/cancelled) and ticket is NOT in `completed/`**:
- Update `**Status**: archived` in CONTEXT.md and README.md
- Move the directory: `mv "$TICKETS_DIR/<ID>" "$TICKETS_DIR/completed/<ID>"` (create `completed/` if missing)
- Remove the ticket's row from `<TICKETS_DIR>/INDEX.md` (the active list)

**If Linear shows active and ticket IS in `completed/`**:
- Update `**Status**: in-progress` in CONTEXT.md and README.md
- Move back: `mv "$TICKETS_DIR/completed/<ID>" "$TICKETS_DIR/<ID>"`
- Re-append the row to INDEX.md (use the row template from `/jt-init` step 8 — ID, title, branch, status, today's date)

### 4. Report a one-line summary

Output ONLY the summary, nothing else:

```
jt-sync: <N> active, <M> archived (<X> moved this run).
```

If nothing changed, say so:

```
jt-sync: <N> active, <M> archived (no changes).
```
