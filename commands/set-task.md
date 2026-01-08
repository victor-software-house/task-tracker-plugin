---
description: Set the active task for this session's tracking and checkpoints
argument-hint: [task-name or task-number]
allowed-tools: Read, Bash(bash:*, ls:*, mkdir:*, cat:*, echo:*)
---

Set the active task for this session. All checkpoints and tracking will be associated with this task.

**IMPORTANT**: Tasks are NEVER auto-detected. Each session must explicitly set its task because multiple agents may work on different tasks simultaneously.

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
   Use the session_id (available in context) to associate this task with this session.

   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-db.sh set-active-task "[SESSION_ID]" "[TASK-NAME]"`

5. **Initialize tracking files** (if not exist):
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-helper.sh init "local-docs/todo/[TASK]" 2>/dev/null`

6. **Confirm activation and remind about /rename**:

```
✅ TASK SET: [task-name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task directory: local-docs/todo/[task-name]/
Session ID: [session_id truncated]

📋 Commands available:
• /checkpoint    - Save progress checkpoint
• /task-status   - View current status
• /resume-task   - Reload task context

💡 **RECOMMENDED**: Run `/rename [task-name]` to give this session
   a meaningful name that matches your task.
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
