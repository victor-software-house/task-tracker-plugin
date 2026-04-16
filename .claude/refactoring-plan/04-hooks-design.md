# Hooks Design

## Hook Configuration

`hooks/hooks.json`:
```json
{
  "description": "Task tracker hooks for context preservation",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/session-start.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "mcp__firecrawl__.*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/warn-firecrawl.sh",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-threshold.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

---

## SessionStart Hook

### Purpose
- Export immutable `TASK_TRACKER_SESSION_ID` to environment
- Initialize session record in SQLite
- Provide initial context about active task

### Implementation

`hooks/scripts/session-start.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_PATH="${PLUGIN_ROOT}/data/task-tracker.db"

# Read input
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // ""')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // ""')

# Exit if no session
[ -z "$session_id" ] && exit 0

# Export session ID to CLAUDE_ENV_FILE (immutable for this session)
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    echo "export TASK_TRACKER_SESSION_ID=\"${session_id}\"" >> "$CLAUDE_ENV_FILE"
    echo "export TASK_TRACKER_DB=\"${DB_PATH}\"" >> "$CLAUDE_ENV_FILE"
fi

# Ensure database and table exist
mkdir -p "$(dirname "$DB_PATH")"
sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    active_task TEXT,
    context_percentage INTEGER DEFAULT 0,
    thresholds_passed TEXT DEFAULT '[]',
    project_dir TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
EOF

# Check if session exists
existing=$(sqlite3 "$DB_PATH" "SELECT active_task FROM sessions WHERE session_id = '$session_id'" 2>/dev/null || echo "")

if [ -z "$existing" ]; then
    # New session - create record
    sqlite3 "$DB_PATH" "INSERT INTO sessions (session_id, project_dir) VALUES ('$session_id', '$project_dir')"
    active_task=""
else
    active_task="$existing"
fi

# Output context
if [ -n "$active_task" ]; then
    cat << EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "additionalContext": "**Task Tracker Active**\n\nCurrent task: \`${active_task}\`\n\nCommands: /checkpoint, /task-status, /set-task <name>"
  }
}
EOF
else
    cat << EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "additionalContext": "**Task Tracker Ready**\n\nNo active task. Use \`/set-task <name>\` to begin tracking.\n\nTask directory: \`local-docs/todo/\`"
  }
}
EOF
fi
```

---

## PreToolUse: Threshold Check (Wildcard)

### Purpose
- Check context usage against thresholds (50%, 75%, 90%)
- Block tool execution if threshold reached but not yet checkpointed
- Force checkpoint discipline

### Threshold Behavior

| Threshold | Trigger Condition | Action |
|-----------|-------------------|--------|
| 50% | `context >= 50 AND 50 NOT IN passed` | Deny + require checkpoint |
| 75% | `context >= 75 AND 75 NOT IN passed` | Deny + require checkpoint |
| 90% | `context >= 90 AND 90 NOT IN passed` | Deny + require checkpoint |

### Checkpoint Requirements

When a threshold is reached, Claude MUST:
1. Read current `local-docs/todo/{task}/00-index.md`
2. Update the document with:
   - Current progress summary
   - Updated next steps
   - Append entry to `## Change History` section
3. Commit changes to git
4. Call `/mark-threshold-passed <threshold>`

### Implementation

`hooks/scripts/check-threshold.sh`:
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_PATH="${PLUGIN_ROOT}/data/task-tracker.db"

# Read input
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // ""')

# Exit silently if no session or no database
[ -z "$session_id" ] && exit 0
[ ! -f "$DB_PATH" ] && exit 0

# Get current state from database
result=$(sqlite3 -separator '|' "$DB_PATH" \
    "SELECT context_percentage, thresholds_passed, active_task FROM sessions WHERE session_id = '$session_id'" \
    2>/dev/null || echo "")

[ -z "$result" ] && exit 0

# Parse result
IFS='|' read -r percentage thresholds_json active_task <<< "$result"

# Exit if no active task
[ -z "$active_task" ] && exit 0

# Parse thresholds already passed
thresholds_passed=$(echo "$thresholds_json" | jq -r '.[]' 2>/dev/null | tr '\n' ',' || echo "")

# Check each threshold
for threshold in 50 75 90; do
    if [ "$percentage" -ge "$threshold" ]; then
        # Check if this threshold already passed
        if [[ ! ",$thresholds_passed," =~ ",$threshold," ]]; then
            # Threshold reached but not passed - DENY
            cat << EOF
{
  "hookSpecificOutput": {
    "permissionDecision": "deny",
    "permissionDecisionReason": "**Checkpoint Required: ${threshold}% Context Usage**

Context usage has reached ${percentage}%. Before proceeding, you MUST:

1. **Read** the current task entrypoint:
   \`local-docs/todo/${active_task}/00-index.md\`

2. **Update** the document:
   - Refresh the progress summary with current state
   - Update next steps based on what's been accomplished
   - Add entry to \`## Change History\` section:
     \`\`\`
     ### $(date '+%Y-%m-%d %H:%M') - ${threshold}% Checkpoint
     - [Summary of progress since last checkpoint]
     - [Key decisions made]
     - [Current blockers or questions]
     \`\`\`

3. **Commit** the changes:
   \`\`\`bash
   git add local-docs/todo/${active_task}/00-index.md
   git commit -m \"checkpoint: ${threshold}% context threshold\"
   \`\`\`

4. **Mark threshold passed**:
   \`/mark-threshold-passed ${threshold}\`

After completing these steps, your tool call will proceed."
  }
}
EOF
            exit 0
        fi
    fi
done

# All thresholds passed or below threshold - allow
echo '{"continue": true}'
```

---

## PreToolUse: Firecrawl Warning

### Purpose
- Warn about token-heavy operations
- Does NOT block (informational only)
- Reminder to document findings afterward

### Implementation

`hooks/scripts/warn-firecrawl.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Read input
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -c '.tool_input // {}')

# Extract operation details
url=$(echo "$tool_input" | jq -r '.url // .urls[0] // ""')
query=$(echo "$tool_input" | jq -r '.query // ""')

# Build description
if [ -n "$query" ]; then
    desc="search: \"${query}\""
elif [ -n "$url" ]; then
    # Truncate long URLs
    [ ${#url} -gt 60 ] && url="${url:0:57}..."
    desc="$url"
else
    desc="operation"
fi

# Output warning (does not block)
cat << EOF
{
  "continue": true,
  "systemMessage": "**Firecrawl Operation**: \`${tool_name}\` - ${desc}\n\nThis operation consumes significant tokens. Document key findings afterward using \`/checkpoint\` if important."
}
EOF
```

---

## PostToolUse Fallback (If PreToolUse Deny Doesn't Work)

If `permissionDecision: "deny"` in PreToolUse doesn't effectively block operations, use PostToolUse with `decision: "block"`:

`hooks/scripts/check-threshold-post.sh`:
```bash
#!/bin/bash
# PostToolUse fallback - use if PreToolUse deny doesn't work

set -euo pipefail

# ... same logic as check-threshold.sh ...

# Instead of permissionDecision: deny, use:
cat << EOF
{
  "decision": "block",
  "reason": "Checkpoint required at ${threshold}%...",
  "hookSpecificOutput": {
    "additionalContext": "Tool execution completed but checkpoint is required before continuing."
  }
}
EOF
```

Alternative `hooks.json` using PostToolUse:
```json
{
  "PostToolUse": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/check-threshold-post.sh",
          "timeout": 5
        }
      ]
    }
  ]
}
```

---

## Hooks Removed

| Hook | Reason |
|------|--------|
| `PostToolUse` for Edit/Write | Replaced by database timestamps; no log files |
| `PreCompact` prompt | Threshold system handles this better |
| `Stop` prompt | Unnecessary with proper checkpoint discipline |
