---
description: Set the active task for tracking and checkpoints
argument-hint: [task-name or task-number]
allowed-tools: Read, Bash(bash:*, ls:*, mkdir:*, cat:*, echo:*)
---

Set the active task for this session. All checkpoints and tracking will be associated with this task.

## Steps

1. **List available tasks**:
   !`ls -1 local-docs/todo/ 2>/dev/null | grep -E '^[0-9]{2}-' | grep -v '^previous-' || echo "No tasks found"`

2. **If $ARGUMENTS provided**:

   Find matching task:
   - If numeric (e.g., "01", "02"): !`ls -d local-docs/todo/$1-* 2>/dev/null | head -1`
   - If name: !`ls -d local-docs/todo/*$1* 2>/dev/null | head -1`

   Validate task exists:
   - Check directory exists
   - Check 00-index.md exists

3. **If no argument provided**:

   Show task selection:
   ```
   📋 AVAILABLE TASKS:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   For each task, show:
   - Task number and name
   - Status (from 00-index.md if readable)
   - Brief description

   Prompt: "Enter task number or name to activate:"

4. **Set active task in database**:
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-db.sh set-active-task "$(cat /tmp/claude-session-id 2>/dev/null || echo "default")" "[TASK-NAME]"`

5. **Initialize tracking files** (if not exist):

   Create CHECKPOINT-LOG.md if missing:
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-helper.sh init "local-docs/todo/[TASK]" 2>/dev/null`

6. **Confirm activation**:

```
✅ ACTIVE TASK SET: [task-name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task directory: local-docs/todo/[task-name]/
Checkpoint log: CHECKPOINT-LOG.md

📋 Commands available:
• /checkpoint    - Save progress checkpoint
• /task-status   - View current status
• /resume-task   - Reload task context

💡 Use /checkpoint regularly to preserve context.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

7. **If task doesn't exist**, offer to create:

   ```
   ⚠️  Task not found: [name]

   Would you like to create a new task?
   This will create:
   • local-docs/todo/[NN]-[name]/
   • local-docs/todo/[NN]-[name]/00-index.md
   • local-docs/todo/[NN]-[name]/CHECKPOINT-LOG.md

   Follow TODO-WORKFLOW.md conventions for task structure.
   ```

8. **Edge cases**:
   - If `local-docs/todo/` doesn't exist, guide user to create it
   - If multiple matches, show disambiguation options
   - If task is archived (previous-*), warn user
