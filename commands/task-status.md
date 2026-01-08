---
description: Show current task status, progress, and recent checkpoints
allowed-tools: Read, Bash(bash:*, ls:*, cat:*, head:*, tail:*, wc:*)
---

Display comprehensive status of the active task or specified task.

## Steps

1. **Get active task**:
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-db.sh get-active-task "$(cat /tmp/claude-session-id 2>/dev/null || echo "")" 2>/dev/null || echo ""`

2. **List available tasks** in `local-docs/todo/`:
   !`ls -1 local-docs/todo/ 2>/dev/null | grep -E '^[0-9]{2}-' | grep -v '^previous-' || echo "No tasks found"`

3. **For active task**, display:

   ### Task Overview
   Read and summarize `00-index.md`:
   - Task name and status
   - Current phase/subtask
   - Overall progress percentage
   - Priority and category

   ### Recent Progress
   Read last 3 entries from `CHECKPOINT-LOG.md` (if exists)

   ### File Changes
   Show recent changes from `.changes.log` (if exists):
   !`tail -10 local-docs/todo/[TASK]/.changes.log 2>/dev/null || echo "No changes tracked"`

   ### Operations Log
   Show recent operations from `.operations.log` (if exists):
   !`tail -5 local-docs/todo/[TASK]/.operations.log 2>/dev/null || echo "No operations tracked"`

   ### Session Stats
   Display from context database:
   - Session start time
   - Edits count
   - Last edit file and time
   - Context usage percentage

4. **Format output** as a clear status report:

```
📋 TASK STATUS: [task-name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status: [In Progress/Planning/Blocked/Complete]
Phase:  [Current phase from 00-index.md]
Progress: [X]% complete

📝 LAST CHECKPOINT: [timestamp]
[Summary of last checkpoint]

📂 RECENT CHANGES:
• [file1] - [timestamp]
• [file2] - [timestamp]

🔍 RECENT OPERATIONS:
• [operation1] - [timestamp]
• [operation2] - [timestamp]

📊 SESSION STATS:
• Edits: [count]
• Context: [X]%
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

5. **If no active task**, show list of available tasks and prompt to use `/set-task`.

6. **Recommendations**:
   - If context > 75%: Recommend checkpoint soon
   - If no recent checkpoint: Suggest creating one
   - If task blocked: Show blockers from 00-index.md
