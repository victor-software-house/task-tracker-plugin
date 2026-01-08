---
description: Resume a task by loading its full context from 00-index.md and checkpoints
argument-hint: [task-name or task-number]
allowed-tools: Read, Bash(bash:*, ls:*, cat:*, head:*, tail:*)
---

Resume work on a task by loading its complete context. This is essential after context compaction or session restart.

## Steps

1. **Identify task to resume**:

   If $ARGUMENTS provided:
   - If numeric (e.g., "01", "02"): Find task starting with that number
   - If name: Find task matching pattern

   If no argument:
   - Show available tasks: !`ls -1 local-docs/todo/ 2>/dev/null | grep -E '^[0-9]{2}-' | grep -v '^previous-'`
   - Prompt user to select

2. **Locate task directory**:
   !`ls -d local-docs/todo/$1* 2>/dev/null || ls -d local-docs/todo/*$1* 2>/dev/null | head -1`

3. **Load complete context**:

   ### Task Overview (00-index.md)
   Read and internalize the full task index:
   @local-docs/todo/[TASK]/00-index.md

   Key elements to extract:
   - Current status
   - Task breakdown and phases
   - Dependencies
   - Completed vs pending items
   - Risk factors

   ### Last Checkpoint (CHECKPOINT-LOG.md)
   Read the most recent checkpoint entry:
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/checkpoint-helper.sh last "local-docs/todo/[TASK]" 2>/dev/null`

   Extract:
   - What was accomplished
   - Current state
   - Next steps
   - Any blockers or issues

   ### Recent Changes (.changes.log)
   Review recent file modifications:
   !`tail -20 local-docs/todo/[TASK]/.changes.log 2>/dev/null || echo "No changes tracked"`

   ### Phase Documents
   If current phase identified, read the relevant phase document:
   @local-docs/todo/[TASK]/[current-phase].md

4. **Set as active task**:
   !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-db.sh set-active-task "$(cat /tmp/claude-session-id 2>/dev/null || echo "default")" "[TASK]"`

5. **Report context loaded**:

```
📋 RESUMED TASK: [task-name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ Context Loaded:
• Task overview from 00-index.md
• Last checkpoint: [timestamp]
• Recent changes: [count] files

📍 CURRENT STATE:
[Summary from last checkpoint or 00-index.md]

📋 NEXT STEPS:
1. [First action from checkpoint/index]
2. [Second action]
3. [Third action]

💡 Ready to continue. Use /checkpoint to save progress.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

6. **Provide orientation**:
   - Summarize where the task left off
   - Highlight any blockers or dependencies
   - Suggest immediate next action
   - Note any time-sensitive items

This command is critical for context recovery after compaction. Always read and internalize all available context before proceeding with work.
