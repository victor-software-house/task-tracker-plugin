# Commands Design

## Command Overview

| Command | Purpose | Key Actions |
|---------|---------|-------------|
| `/set-task` | Set active task | Update DB, reset thresholds, init todo if needed, commit |
| `/checkpoint` | Manual checkpoint | Update todo, add to history, commit |
| `/task-status` | Show current state | Query DB, display info |
| `/mark-threshold-passed` | Mark threshold done | Update DB thresholds_passed |
| `/install-statusline` | Install status line | Copy config to project |

---

## /set-task

### Purpose
Set the active task for tracking. Resets threshold tracking.

### Frontmatter
```yaml
---
description: Set the active task for tracking and checkpoints
argument-hint: <task-name>
allowed-tools: Read, Write, Bash(git:*, ls:*, mkdir:*)
---
```

### Steps

1. **Validate argument provided**
   - If no argument: list available tasks in `local-docs/todo/`

2. **Find matching task**
   - Numeric (01, 02): match `local-docs/todo/{num}-*`
   - Name: match `local-docs/todo/*{name}*`

3. **If task exists**:
   ```sql
   UPDATE sessions
   SET active_task = '{task}',
       thresholds_passed = '[]',
       updated_at = strftime('%s', 'now')
   WHERE session_id = '{TASK_TRACKER_SESSION_ID}';
   ```

4. **If task doesn't exist**:
   - Offer to create:
     ```
     local-docs/todo/{NN}-{name}/
     local-docs/todo/{NN}-{name}/00-index.md
     ```
   - Create with template
   - Commit to git:
     ```bash
     git add local-docs/todo/{task}/
     git commit -m "task: initialize {task}"
     ```

5. **Confirm activation**:
   ```
   ✅ Active task: {task}

   Thresholds reset. Checkpoints will trigger at 50%, 75%, 90%.

   Commands:
   • /checkpoint - Save progress
   • /task-status - View status
   ```

### Template for 00-index.md

```markdown
# {Task Name}

## Overview

[Brief description of the task]

## Goals

- [ ] Goal 1
- [ ] Goal 2
- [ ] Goal 3

## Progress

[Current progress summary - updated at each checkpoint]

## Next Steps

1. [Next action item]
2. [Following action item]

## Change History

### {date} - Task Created
- Initial task setup
```

---

## /checkpoint

### Purpose
Manually create a checkpoint. Updates todo entrypoint and commits.

### Frontmatter
```yaml
---
description: Create a checkpoint - update todo and commit
argument-hint: [optional summary]
allowed-tools: Read, Write, Edit, Bash(git:*)
---
```

### Steps

1. **Get active task from database**
   ```sql
   SELECT active_task FROM sessions WHERE session_id = ?;
   ```

2. **Verify task directory exists**
   - `local-docs/todo/{task}/00-index.md`

3. **Read current 00-index.md**

4. **Update the document**:
   - Refresh `## Progress` section with current state
   - Update `## Next Steps` with remaining work
   - Append to `## Change History`:
     ```markdown
     ### {timestamp} - Manual Checkpoint
     - {summary from argument or auto-generated}
     - [Key accomplishments since last update]
     - [Current state and blockers]
     ```

5. **Commit changes**:
   ```bash
   git add local-docs/todo/{task}/00-index.md
   git commit -m "checkpoint: {summary or 'manual checkpoint'}"
   ```

6. **Confirm**:
   ```
   ✅ Checkpoint saved for: {task}

   Updated:
   • Progress summary
   • Next steps
   • Change history

   Committed: {commit hash}
   ```

---

## /task-status

### Purpose
Display current task tracking status.

### Frontmatter
```yaml
---
description: Show current task tracking status
allowed-tools: Read, Bash(sqlite3:*)
---
```

### Steps

1. **Query database**:
   ```sql
   SELECT active_task, context_percentage, thresholds_passed, updated_at
   FROM sessions WHERE session_id = ?;
   ```

2. **Display status**:
   ```
   📊 Task Tracker Status
   ━━━━━━━━━━━━━━━━━━━━━━

   Session: {session_id}
   Active Task: {task or "None"}
   Context: {percentage}%

   Thresholds:
   • 50%: {✅ passed | ⏳ pending}
   • 75%: {✅ passed | ⏳ pending}
   • 90%: {✅ passed | ⏳ pending}

   Last Updated: {timestamp}
   ```

3. **If task set, show todo path**:
   ```
   Todo: local-docs/todo/{task}/00-index.md
   ```

---

## /mark-threshold-passed

### Purpose
Mark a context threshold as passed (called after checkpoint).

### Frontmatter
```yaml
---
description: Mark a threshold as passed after checkpoint
argument-hint: <threshold: 50|75|90>
allowed-tools: Bash(sqlite3:*)
---
```

### Steps

1. **Validate argument**: Must be 50, 75, or 90

2. **Update database**:
   ```sql
   UPDATE sessions
   SET thresholds_passed = json_insert(thresholds_passed, '$[#]', {threshold}),
       updated_at = strftime('%s', 'now')
   WHERE session_id = ?;
   ```

3. **Confirm**:
   ```
   ✅ Threshold {threshold}% marked as passed.

   Tool calls will now proceed until the next threshold.
   ```

---

## /install-statusline

### Purpose
Install the task tracker status line to the current project.

### Frontmatter
```yaml
---
description: Install task tracker status line to current project
allowed-tools: Read, Write, Bash(cat:*)
---
```

### Steps

1. **Check if `.claude/settings.json` exists**:
   - If not, create it

2. **Read existing settings**

3. **Add/update statusLine config**:
   ```json
   {
     "statusLine": {
       "script": "{PLUGIN_PATH}/scripts/status-line.sh"
     }
   }
   ```

4. **Write updated settings**

5. **Confirm**:
   ```
   ✅ Status line installed!

   The status line will show:
   • Context usage percentage (colored by threshold)
   • Active task name

   Restart Claude Code to activate.
   ```

---

## Commands Removed

| Command | Reason |
|---------|--------|
| `/resume-task` | Unnecessary; task persists in DB |

---

## Notes on Git Integration

All commands that modify `local-docs/todo/` MUST commit changes:

```bash
# Pattern for all todo modifications
git add local-docs/todo/{task}/
git commit -m "{type}: {message}"
```

Commit message types:
- `task:` - Task creation/modification
- `checkpoint:` - Progress checkpoint
- `threshold:` - Threshold-triggered update
