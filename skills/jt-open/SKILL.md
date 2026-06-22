---
name: jt-open
description: Binds the current chat session to an existing juggle ticket — loads its CONTEXT.md, optionally checks out the ticket's branch in the linked repo, renames the session, and writes a .session pointer so future `jt open <ID>` resumes this exact chat. Use when the user invokes "/jt-open", wants to "point this chat at a ticket", "link this session to a juggle ticket", "claim this conversation for ticket X", or "turn this chat into a jt session".
argument-hint: <TICKET-ID>
allowed-tools: Bash(*) Read Write
---

# jt-open: Point this chat at a juggle ticket

The user invoked this with: $ARGUMENTS

Parse `$ARGUMENTS` for a ticket ID (e.g. `JUD-6321`, `PROJ-1`, `JT-1`). If none provided, ask the user which ticket to bind to.

## Steps

### 0. Resolve tickets directory

```bash
cat ~/.jt-config 2>/dev/null
```

Use the path, or default to `~/juggle-task`. Store as `TICKETS_DIR`.

### 1. Resolve the ticket directory

Look in both active and completed locations:
- `<TICKETS_DIR>/<ID>/CONTEXT.md` (active)
- `<TICKETS_DIR>/completed/<ID>/CONTEXT.md` (archived)

Also try the uppercase variant (`PROJ-123` from `proj-123`). If neither exists, stop and tell the user: "No juggle ticket found for `<ID>`. Run `/jt-init <ID>` first." Optionally list nearby tickets with `ls <TICKETS_DIR>/`.

Store the resolved dir as `TICKET_DIR` and CONTEXT.md path as `CONTEXT_FILE`.

### 2. Read CONTEXT.md

Read `CONTEXT_FILE` in full — you'll need its branch + repo for step 3 and its content for step 5.

Extract:
- `BRANCH` from the `**Working branch**: \`...\`` line (text between backticks)
- `REPO` from the `**Repo**: <path>` line
- `TITLE` from the first `# <ID>: <title> — Agent Context` line (drop the trailing ` — Agent Context`)

### 3. Check out the branch (if repo is clean)

If `REPO` is set, not `(none)`, not `(not in a git repo)`, and the directory exists:

```bash
if git -C "$REPO" diff --quiet 2>/dev/null && git -C "$REPO" diff --cached --quiet 2>/dev/null; then
  git -C "$REPO" fetch origin --quiet 2>/dev/null || true
  git -C "$REPO" checkout "$BRANCH" 2>/dev/null \
    || git -C "$REPO" checkout --track "origin/$BRANCH" 2>/dev/null \
    || echo "Could not switch to $BRANCH (may already be on it)."
else
  echo "Warning: $REPO has uncommitted changes — branch NOT switched. Commit or stash first."
fi
```

Don't fail if checkout doesn't work — note it and continue.

### 4. Bind this session and rename the chat

Detect the engine from env vars, find the rollout file by SESSION_ID, optionally rename the chat (Claude only), then write the 3-line `.session` so `jt open <ID>` resumes THIS conversation next time:

```bash
ENGINE=""
SESSION_ID=""
if [[ -n "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
  ENGINE="claude"; SESSION_ID="$CLAUDE_CODE_SESSION_ID"
elif [[ -n "${CODEX_THREAD_ID:-}" ]]; then
  ENGINE="codex";  SESSION_ID="$CODEX_THREAD_ID"
fi

if [[ -z "$SESSION_ID" ]]; then
  echo "No active session ID env var detected — cannot bind. Are you running inside Claude Code or Codex?"
  exit 0
fi

if [[ "$ENGINE" == "claude" ]]; then
  SESSION_FILE=$(find "$HOME/.claude/projects" -maxdepth 2 -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)
  if [[ -f "$SESSION_FILE" ]]; then
    python3 -c "import json,sys; print(json.dumps({'type':'ai-title','aiTitle':sys.argv[1],'sessionId':sys.argv[2]}))" \
      "$TITLE" "$SESSION_ID" >> "$SESSION_FILE"
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

printf '%s\n%s\n%s\n' "$ENGINE" "$SESSION_DIR" "$SESSION_ID" > "$TICKET_DIR/.session"
```

### 5. Orient the user

Output the ticket's identity + Next Steps so the conversation pivots cleanly to this ticket. Don't dump the full CONTEXT.md — just the essentials:

```
Bound to <ID>: <title>
  Status:      <from CONTEXT.md>
  Branch:      <BRANCH>  (checked out / not switched / warning)
  Repo:        <REPO>
  Engine:      <ENGINE>
  .session →   $TICKET_DIR/.session

Next Steps:
  <bulleted list from CONTEXT.md "Next Steps" section>

This chat is now the active session for <ID>. Next time you run `jt open <ID>` from the terminal, it will resume this conversation.
```

Then **wait for the user's instruction** — do not start working on Next Steps unprompted.
