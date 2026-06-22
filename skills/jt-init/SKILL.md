---
name: jt-init
description: Creates a juggle ticket context directory, fetches issue details (from Linear or manually), populates README.md and CONTEXT.md templates, and creates or checks out the git branch. Use when the user invokes "/jt-init", wants to "start work on a ticket", "initialize ticket context", "set up a juggle ticket", or provides a ticket ID or issue tracker URL.
argument-hint: <TICKET-ID or issue URL>
allowed-tools: Bash(*) Read Write mcp__claude_ai_Linear__get_issue
---

# jt-init: Initialize Ticket Context

The user invoked this with: $ARGUMENTS

Parse `$ARGUMENTS` to extract a ticket ID. Accept any of these formats:
- Plain ID: `PROJ-123`, `FEAT-42`, `#99`
- Linear URL: `https://linear.app/<org>/issue/PROJ-123/some-title` — extract the segment matching `[A-Z]+-[0-9]+` from the URL path
- GitHub Issues URL: extract the issue number

Also parse an optional `--project <id>` flag — if present, capture the value as `PROJECT_ID` and remove it from the rest of the argument processing.

If no ticket argument provided, ask the user for a ticket ID or URL.

## Steps

### 0. Resolve tickets directory

Run: `cat ~/.jt-config 2>/dev/null`

- If the file exists and has a non-empty path, use that as `TICKETS_DIR`.
- If the file is missing or empty, ask the user:

  > "Where would you like to store your juggle ticket directories?
  > Press Enter to use the default (`~/juggle-task`), or type an absolute path."

  Use `~/juggle-task` if they press Enter. Expand `~` to the full home path.
  Save the chosen path:
  ```bash
  echo "<chosen-path>" > ~/.jt-config
  mkdir -p <chosen-path>
  ```

### 1. Confirm the repo for this ticket

Run: `git rev-parse --show-toplevel 2>/dev/null`

Show the result to the user and ask them to confirm or override:

> "Which repo should this ticket's branch live in?
> Detected: `<result>` (or 'not in a git repo' if none found)
> Press Enter to use it, or type an absolute path (or 'none' to skip branch management):"

Use the confirmed path as `REPO_ROOT`. If the user enters 'none' or leaves it blank with no detected repo, set `REPO_ROOT` to `(none)` and skip steps 9 (branch creation) and the `**Repo**` / `**Working branch**` fields in CONTEXT.md.

### 2. Fetch ticket details

**Try Linear first**: call `mcp__claude_ai_Linear__get_issue` with the ticket ID. If it succeeds, use: title, description, priority.name, status (state name), url, gitBranchName.

**If Linear is unavailable or the fetch fails**, ask the user:
- "What's the ticket title?"
- "Brief description (optional):"

Set priority and status to `(unknown)`, url to the argument if it was a URL.

### 2.5. Link to a project (optional)

If `PROJECT_ID` was already captured from the `--project <id>` flag, skip the prompt and use it.

Otherwise, list existing projects:
```bash
ls -1 <TICKETS_DIR>/projects/ 2>/dev/null
```

Show the list (with titles read from each `PROJECT.md` first line) and ask:

> "Link this ticket to a project? Options:
>  - Enter to skip (no project link)
>  - Type an existing project ID (e.g. EPIC-1)
>  - Type a new project ID to create it inline"

Handle the response:
- Empty / skip: set `PROJECT_ID=""` and proceed
- Existing ID: verify `<TICKETS_DIR>/projects/<PROJECT_ID>/PROJECT.md` exists, capture it
- New ID: invoke the `/jt-project-init` flow inline (steps 4-7 of that skill) to create the project dir + PROJECT.md, then capture the ID

### 3. Determine branch name

- If Linear returned `gitBranchName`, use it directly.
- Otherwise construct: `<username>/jt-<ID-lowercased>-<slug>` where slug is the title lowercased, spaces → hyphens, non-alphanumeric removed, truncated to 40 chars.
- Get username with `git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-'`.

### 4. Check if ticket dir exists

If `<TICKETS_DIR>/<ID>/` already exists, stop and tell the user — they should use `jt open <ID>` to resume work on it.

```bash
mkdir -p <TICKETS_DIR>/<ID>
```

### 5. Write README.md

Write `<TICKETS_DIR>/<ID>/README.md`:

```markdown
# <ID>: <title>

| Field | Value |
|-------|-------|
| **URL** | <url or "(none)"> |
| **Priority** | <priority> |
| **Status** | <status> |
| **Branch** | `<branch-name>` |
| **Created** | <today YYYY-MM-DD> |
| **Repo** | <REPO_ROOT> |

## Description

<description, first 500 chars>

## Sessions

| Date | Session Name | Notes |
|------|-------------|-------|
| <today> | Initial setup | jt-init run |

## Quick Resume

`jt open <ID>`
```

### 6. Write CONTEXT.md

Write `<TICKETS_DIR>/<ID>/CONTEXT.md`. This is the key file — populate "What This Ticket Is About" as 2-4 plain prose sentences from the description.

If `PROJECT_ID` is set, include the project directive line and the `**Project**` field. If not set, omit both lines entirely.

```markdown
# <ID>: <title> — Agent Context

> Read this before resuming work. Any agent picking up this ticket should start here.
> This ticket is part of project [<PROJECT_ID>](../projects/<PROJECT_ID>/PROJECT.md) — read PROJECT.md first for the bigger picture and sibling tickets.

## Current State

**Status**: in-progress
**Last updated**: <today YYYY-MM-DD>
**Working branch**: `<branch-name>`
**Repo**: <REPO_ROOT>
**Project**: [<PROJECT_ID>](../projects/<PROJECT_ID>/PROJECT.md)

## What This Ticket Is About

<2-4 sentence plain-prose summary of the ticket>

## What Has Been Done

### <today> (Session: initial)
- Ticket initialized with jt-init
- Branch created: `<branch-name>`

## Key Decisions Made

(none yet)

## Current Blockers

(none)

## Key Files

| File | Role |
|------|------|
| (to be filled as work progresses) | |

## Next Steps

1. [ ] Read the full ticket description and form an implementation plan
2. [ ] Create IMPLEMENTATION.md with the approach

## Open Questions

(none yet)

## Session Log

| Date | Session Name | Summary |
|------|-------------|---------|
| <today> | initial | jt-init — ticket created |
```

### 7. Write IMPLEMENTATION.md stub

Write `<TICKETS_DIR>/<ID>/IMPLEMENTATION.md`:

```markdown
# <ID>: Implementation Plan

Created: <today>
Ticket: <url>

## Approach

(to be filled)

## Steps

- [ ] Define approach
- [ ] Identify files to modify
- [ ] Implement
- [ ] Test

## Files to Modify

| File | Change |
|------|--------|
| (to be filled) | |
```

### 8. Update INDEX.md (and PROJECT.md if linked)

Read `<TICKETS_DIR>/INDEX.md`. Append a new table row:

```
| [<ID>](./<ID>/README.md) | <title> | <branch-name> | in-progress | <today YYYY-MM-DD> |
```

If `PROJECT_ID` is set, also append a row to `<TICKETS_DIR>/projects/<PROJECT_ID>/PROJECT.md`'s **Tickets** table:

```
| [<ID>](../../<ID>/README.md) | <title> | in-progress | <today YYYY-MM-DD> |
```

If INDEX.md does not exist, create it:
```markdown
# Juggle Tickets

| Ticket | Title | Branch | Status | Last Session |
|--------|-------|--------|--------|--------------|
| [<ID>](./<ID>/README.md) | <title> | <branch-name> | in-progress | <today> |
```

### 9. Create or check out the git branch

```bash
cd <REPO_ROOT>
git fetch origin --quiet 2>/dev/null || true
```

Check which case applies:
- Branch exists locally → `git checkout <branch-name>`
- Branch exists on origin only → `git checkout --track origin/<branch-name>`
- Branch does not exist → `git checkout -b <branch-name>`

If `REPO_ROOT` is `(not in a git repo)`, skip this step and note it in the report.

### 10. Rename this session and save session for resume

Save the active session's project dir + UUID + engine so `jt open` can resume it later. Works for both Claude Code and Codex.

The session file path can't be derived from `pwd` — when the agent is opened at a workspace parent and you `cd` into a subdir, `pwd` differs from the project dir registered for the session. Find the session rollout by SESSION_ID across both possible homes, then read the real `cwd` from the JSONL.

For Claude only: append an `ai-title` record so the chat is named after the ticket. (Codex doesn't have an equivalent — it auto-derives `thread_name` from the conversation.)

```bash
# Detect engine via the env vars each CLI exposes
ENGINE=""
SESSION_ID=""
if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  ENGINE="claude"; SESSION_ID="$CLAUDE_CODE_SESSION_ID"
elif [[ -n "${CODEX_THREAD_ID:-}" ]]; then
  ENGINE="codex";  SESSION_ID="$CODEX_THREAD_ID"
fi

if [[ -n "$SESSION_ID" ]]; then
  if [[ "$ENGINE" == "claude" ]]; then
    SESSION_FILE=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
    if [[ -f "$SESSION_FILE" ]]; then
      python3 -c "import json,sys; print(json.dumps({'type':'ai-title','aiTitle':sys.argv[1],'sessionId':sys.argv[2]}))" \
        "<ID>: <title>" "$SESSION_ID" >> "$SESSION_FILE"
    fi
  else
    SESSION_FILE=$(find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "rollout-*${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
  fi

  SESSION_DIR=""
  if [[ -f "$SESSION_FILE" ]]; then
    SESSION_DIR=$(python3 -c "
import json
with open('$SESSION_FILE') as f:
    for line in f:
        try:
            d = json.loads(line)
            cwd = d.get('cwd') or d.get('payload', {}).get('cwd')
            if cwd:
                print(cwd); break
        except: pass" 2>/dev/null)
  fi
  [[ -z "$SESSION_DIR" ]] && SESSION_DIR="$(pwd)"
  printf '%s\n%s\n%s\n' "$ENGINE" "$SESSION_DIR" "$SESSION_ID" > "<TICKETS_DIR>/<ID>/.session"
fi
```

### 11. Report to user

```
<ID> initialized.
  Title:   <title>
  Branch:  <branch-name> (checked out)
  Dir:     <TICKETS_DIR>/<ID>/

Files created:
  <TICKETS_DIR>/<ID>/README.md
  <TICKETS_DIR>/<ID>/CONTEXT.md
  <TICKETS_DIR>/<ID>/IMPLEMENTATION.md

Next: run /jt-update at the end of this session to save context.
```
