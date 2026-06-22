---
name: jt-update
description: Updates CONTEXT.md for the current ticket with what was accomplished in this session, appends to the session log, and updates INDEX.md. Use when the user invokes "/jt-update", wants to "save session context", "checkpoint this session", "log what was done", "record session progress", or "update CONTEXT.md before finishing".
allowed-tools: Bash(*) Read Write Edit
---

# jt-update: Save Session Context

## Resolve tickets directory

Run: `cat ~/.jt-config 2>/dev/null`

Use the path from the file as `TICKETS_DIR`. If missing or empty, fall back to `~/juggle-task`.

## Detect current ticket

Run `git branch --show-current`. Extract the ticket ID by finding any `[a-z]+-[0-9]+` segment (case-insensitive), e.g. `proj-123`, `feat-42`. Normalize to uppercase (e.g. `my-branch/proj-123-my-feature` → `PROJ-123`).

Verify `<TICKETS_DIR>/<ID>/` exists. If not, tell the user to run `jt init <ID>` (terminal) or `/jt-init <ID>` (Claude skill) first.

If no ticket ID can be determined from the branch, ask: "Which ticket are you updating? (e.g. PROJ-123)"

## Gather session info

If the user described what was done in their invocation message (`$ARGUMENTS`), use that directly — do not ask again. Otherwise ask:
- "What did you accomplish in this session?"
- "What are the next steps?"
- "Any blockers or open questions?" (optional)

Get current datetime: `date "+%Y-%m-%d %H:%M"`

## Read CONTEXT.md

Read `<TICKETS_DIR>/<ID>/CONTEXT.md` in full before editing.

## Update CONTEXT.md

Edit `<TICKETS_DIR>/<ID>/CONTEXT.md` with these changes:

1. Update **"Last updated"** to the current datetime.

2. Update **"Status"** if the user mentioned a status change (e.g. now blocked, now in review).

3. **Prepend** a new entry under "What Has Been Done" (most recent first):
   ```
   ### <today> (Session: <short description or 'unnamed'>)
   - <bullet for each thing accomplished>
   - Files modified: <list key files touched>
   ```

4. **Replace** the "Next Steps" section with the updated list from the user.

5. **Update** "Current Blockers" if changed.

6. **Update** "Key Files" table if new important files were mentioned.

7. **Append** a row to the "Session Log" table:
   ```
   | <today> | <short description> | <1-sentence summary of what was done> |
   ```

## Update INDEX.md

Read `<TICKETS_DIR>/INDEX.md`. Find the row for `<ID>` and update:
- The **Status** column if changed
- The **Last Session** column to today's date

## Archive if the ticket is now done

If the new Status is one of `archived`, `closed`, `done`, `cancelled`, `completed`, `duplicate` (case-insensitive) AND the ticket dir is not already under `completed/`, move it:

```bash
mkdir -p "<TICKETS_DIR>/completed"
mv "<TICKETS_DIR>/<ID>" "<TICKETS_DIR>/completed/<ID>"
```

Also remove the ticket's row from `<TICKETS_DIR>/INDEX.md` (active list). The completed ticket is still accessible via `jt open <ID>` and `jt ls --all`.

## Save session for resume

Find the session rollout by ID across whichever engine (Claude Code or Codex) is running, read its real `cwd` from the JSONL, and write a 3-line `.session` file so `jt open` resumes from the right project with the right CLI.

```bash
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

## Confirm to user

```
Context saved for <ID>.
  File: <TICKETS_DIR>/<ID>/CONTEXT.md
  Next steps recorded: <N> items

To resume later:
  jt open <ID>
```
