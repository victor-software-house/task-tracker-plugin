---
description: Save current progress checkpoint to active task's log
argument-hint: [optional: brief summary]
allowed-tools: Read, Write, Bash(bash:*, cat:*, date:*, echo:*)
---

Create a checkpoint entry for the active task. This preserves context that would be lost during compaction.

## Steps

1. **Identify active task**:
   Check session database: !`bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-db.sh get-active-task "$(cat /tmp/claude-session-id 2>/dev/null || echo "")" 2>/dev/null || echo ""`

   If no active task found, check for task directories:
   !`ls -1 local-docs/todo/ 2>/dev/null | grep -E '^[0-9]{2}-' | grep -v '^previous-' | head -5`

2. **If active task exists**, create checkpoint with:
   - **Timestamp**: Current date/time
   - **Summary**: $ARGUMENTS (if provided) or prompt for summary
   - **Progress**: What has been accomplished since last checkpoint
   - **Insights**: Key decisions, discoveries, or context
   - **Next Steps**: Immediate next actions
   - **Context**: Any important state or dependencies

3. **Write to CHECKPOINT-LOG.md** in task directory using this format:

```markdown
## YYYY-MM-DD HH:MM:SS

### Summary
[Brief summary of checkpoint]

### Progress Since Last Checkpoint
- [Completed item 1]
- [Completed item 2]

### Key Insights & Decisions
- [Decision or discovery 1]
- [Decision or discovery 2]

### Current State
[Description of where things stand]

### Next Steps
1. [Next action 1]
2. [Next action 2]
```

4. **If no summary provided** ($ARGUMENTS is empty):
   - Review recent conversation context
   - Summarize accomplishments and current state
   - Prompt user to confirm or modify before saving

5. **After saving**, report:
   - Checkpoint file location
   - Current context window usage (if available)
   - Recommendation for next checkpoint timing

If no active task is set, guide user to use `/set-task` first.
