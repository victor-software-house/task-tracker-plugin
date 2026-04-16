# New Architecture

## Core Data Model

```
┌─────────────────────────────────────────────────────────────┐
│                     TASK TRACKER PLUGIN                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  IMMUTABLE (set once per session)                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ TASK_TRACKER_SESSION_ID                              │   │
│  │ - Exported to CLAUDE_ENV_FILE in SessionStart        │   │
│  │ - Unique identifier for this session                 │   │
│  │ - Persists across compactions within same session    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  MUTABLE (changes via /set-task, /checkpoint)               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ SQLite Database (via MCP)                            │   │
│  │ - active_task: current task name                     │   │
│  │ - context_percentage: last known usage               │   │
│  │ - thresholds_passed: [50, 75, 90] tracking          │   │
│  │ - timestamps: created_at, updated_at                 │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Session Start

```
Claude Code starts session
        │
        ▼
SessionStart hook receives JSON:
{
  "session_id": "abc123",
  "cwd": "/path/to/project",
  ...
}
        │
        ▼
Export to CLAUDE_ENV_FILE:
  TASK_TRACKER_SESSION_ID=abc123
        │
        ▼
Query SQLite: SELECT * FROM sessions WHERE session_id = ?
        │
        ├── EXISTS: Load active_task, thresholds_passed
        │
        └── NOT EXISTS: INSERT new session record
        │
        ▼
Output hookSpecificOutput.additionalContext:
  "Active task: {task} | Use /set-task to change"
```

### 2. Status Line Update (Every Prompt)

```
Status line receives JSON:
{
  "session_id": "...",
  "context_window": {
    "current_usage": {"input_tokens": N},
    "context_window_size": M
  }
}
        │
        ▼
Calculate percentage: N * 100 / M
        │
        ▼
SQLite UPDATE: SET context_percentage = ?, updated_at = NOW()
        │
        ▼
SQLite SELECT: active_task
        │
        ▼
Output: "ctx:65% task:01-feature"
```

### 3. PreToolUse Threshold Check (Every Tool Call)

```
PreToolUse hook receives JSON:
{
  "session_id": "...",
  "tool_name": "Edit",
  ...
}
        │
        ▼
SQLite SELECT: context_percentage, thresholds_passed
        │
        ▼
Check thresholds: [50, 75, 90]
        │
        ├── percentage >= threshold AND threshold NOT IN passed
        │           │
        │           ▼
        │   Return: permissionDecision = "deny"
        │   Reason: "Checkpoint required at {threshold}%"
        │
        └── All thresholds passed OR below next threshold
                    │
                    ▼
            Return: continue = true
```

### 4. Checkpoint Trigger Flow

```
Threshold reached (e.g., 75%)
        │
        ▼
PreToolUse denies with reason:
  "Context at 75%. Update todo before proceeding."
        │
        ▼
Claude reads current 00-index.md
        │
        ▼
Claude updates 00-index.md:
  - Refresh progress summary
  - Update next steps
  - Add to ## Change History appendix
        │
        ▼
Claude commits changes:
  git add local-docs/todo/{task}/00-index.md
  git commit -m "checkpoint: 75% context threshold"
        │
        ▼
Claude calls: /mark-threshold-passed 75
        │
        ▼
SQLite UPDATE: thresholds_passed = thresholds_passed || [75]
        │
        ▼
Next tool call proceeds normally
```

### 5. Task Change Flow

```
User: /set-task 02-new-feature
        │
        ▼
Validate: local-docs/todo/02-new-feature/ exists
        │
        ├── EXISTS:
        │   SQLite UPDATE: active_task = "02-new-feature"
        │   Reset thresholds_passed = []
        │
        └── NOT EXISTS:
            Create directory structure
            Create 00-index.md template
            git add && git commit
            SQLite UPDATE: active_task = "02-new-feature"
        │
        ▼
Output confirmation
```

## Component Responsibilities

| Component | Responsibility | Does NOT Do |
|-----------|----------------|-------------|
| **SessionStart hook** | Export session_id to env; init DB record | Auto-detect task |
| **Status line** | Update context_percentage in DB; display | Store context data |
| **PreToolUse (*)** | Check thresholds; deny if checkpoint needed | Log operations |
| **PreToolUse (firecrawl)** | Warn about token consumption | Block operations |
| **SQLite MCP** | Store session state; provide fast queries | N/A |
| **/set-task** | Change active task; reset thresholds | Auto-detect |
| **/checkpoint** | Update todo; commit to git; mark threshold | Store in log files |

## Directory Structure (Simplified)

```
task-tracker-plugin/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json                    # SQLite MCP server config
├── hooks/
│   ├── hooks.json
│   └── scripts/
│       ├── session-start.sh
│       └── check-threshold.sh   # Replaces pre-firecrawl.sh
├── scripts/
│   ├── status-line.sh
│   └── install-statusline.sh    # NEW: helper to install
├── commands/
│   ├── set-task.md
│   ├── checkpoint.md
│   ├── task-status.md
│   └── mark-threshold-passed.md # NEW: mark threshold done
└── skills/
    └── ... (unchanged)
```

## Files to Delete

- `scripts/context-db.sh`
- `hooks/scripts/track-change.sh`
- `hooks/scripts/pre-firecrawl.sh` (replaced by check-threshold.sh)
- `commands/resume-task.md` (unnecessary with DB)
