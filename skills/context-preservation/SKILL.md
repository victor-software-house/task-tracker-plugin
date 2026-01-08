---
name: Context Preservation
description: This skill should be used when the user asks about "context compaction", "preserving context", "session summarization", "avoiding context loss", "pre-compaction checkpoints", "context window management", or needs guidance on documenting context before compaction occurs, managing large context windows, or recovering from context loss.
version: 1.0.0
---

# Context Preservation Before Compaction

## Overview

Context compaction occurs when the conversation exceeds the context window limit. During compaction, the conversation is summarized, and detailed context can be lost. This skill provides strategies for preserving critical context before compaction.

## Understanding Context Compaction

### What Happens During Compaction

1. **Trigger**: Context window reaches capacity (~200K tokens)
2. **Process**: Earlier conversation is summarized/compressed
3. **Result**: Detailed context from early messages is lost
4. **Risk**: Important decisions, research findings, and state information may be forgotten

### Warning Signs

- Large codebase explorations
- Extensive web research (firecrawl operations)
- Multiple file reads and edits
- Long conversations with many tool calls

## Pre-Compaction Preservation Strategy

### Before Expensive Operations

When about to perform token-heavy operations:

1. **Document intent**: What are you trying to achieve?
2. **Record hypotheses**: What do you expect to find?
3. **Note current state**: Where does the work stand?
4. **Save progress**: Create checkpoint if significant work done

### PreCompact Hook Behavior

When PreCompact triggers, immediately:

1. **Summarize accomplishments**: What has been done?
2. **Capture insights**: What important things were learned?
3. **Document decisions**: What choices were made and why?
4. **Record next steps**: What should happen next?
5. **Note dependencies**: What context is needed to continue?

### Checkpoint Content for Compaction

Create a comprehensive checkpoint with:

```markdown
## Pre-Compaction Checkpoint: YYYY-MM-DD HH:MM:SS

### Session Summary
[High-level summary of this entire session's work]

### Key Accomplishments
1. [Major accomplishment 1]
2. [Major accomplishment 2]
3. [Major accomplishment 3]

### Critical Decisions Made
- **Decision**: [What was decided]
  **Rationale**: [Why this choice]
  **Alternatives Rejected**: [What else was considered]

### Research Findings
- **Topic**: [What was researched]
  **Finding**: [Key insight]
  **Source**: [Where found]
  **Implication**: [What it means for the work]

### Current Work State
- **Active file(s)**: [Files being worked on]
- **Pending changes**: [Uncommitted work]
- **Test status**: [Pass/fail/pending]
- **Blockers**: [Any obstacles]

### Context Required for Continuation
[Specific context that MUST be preserved]
- Variable states: [...]
- Working assumptions: [...]
- Temporary workarounds: [...]

### Next Session Should
1. [First action to take]
2. [Second action]
3. [Third action]

### Files Modified This Session
- `path/to/file1.ts` - [brief description]
- `path/to/file2.ts` - [brief description]
```

## Token-Heavy Operations

### Web Research (Firecrawl)

Before `firecrawl_scrape`, `firecrawl_search`, `firecrawl_crawl`:

1. **Document search goal**: What are you looking for?
2. **Note expected sources**: What sites/topics?
3. **Record what you already know**: Current understanding
4. **Plan extraction**: What specific info needed?

After research:
1. **Summarize findings immediately**: Don't let raw data sit
2. **Extract actionable insights**: What matters for the task?
3. **Discard noise**: Don't preserve unnecessary detail

### Large File Operations

When reading many files:

1. **Purpose**: Why reading these files?
2. **Findings**: Key takeaways from each
3. **Patterns**: Recurring themes across files
4. **Relevance**: How findings relate to task

### Extended Debugging

When debugging consumes tokens:

1. **Problem statement**: What's broken?
2. **Investigation path**: What was checked?
3. **Findings**: What was discovered?
4. **Current hypothesis**: What's suspected now?

## Recovery After Compaction

If compaction has occurred:

1. **Read CHECKPOINT-LOG.md**: Get latest checkpoint
2. **Read 00-index.md**: Understand task state
3. **Review .changes.log**: See recent file changes
4. **Check git log**: Verify committed work

Use `/resume-task` command to automate this recovery.

## Threshold-Based Alerts

The task-tracker plugin monitors context usage:

| Threshold | Action |
|-----------|--------|
| 50% | Informational note on firecrawl ops |
| 75% | Warning with checkpoint recommendation |
| 90% | Urgent checkpoint prompt |
| PreCompact | Mandatory checkpoint creation |

## Best Practices

### Do

- Create checkpoints before expensive operations
- Summarize research immediately after completing it
- Keep checkpoint entries focused and actionable
- Include enough context for cold-start recovery
- Note file paths and line numbers for code references

### Don't

- Wait for compaction to happen before documenting
- Include raw web scrape output in checkpoints
- Assume context will be preserved automatically
- Skip checkpoints for "quick" research tasks
- Leave critical decisions undocumented

## Integration Commands

- `/checkpoint` - Manual checkpoint creation
- `/task-status` - View current context state
- `/resume-task` - Recover after compaction
- `/set-task` - Initialize task tracking

## Context Window Monitoring

The status line (when configured) shows:
- `ctx:X%` - Current context usage percentage
- `task:name` - Active task name

Colors indicate urgency:
- 🟢 Green (0-50%): Normal operation
- 🟡 Yellow (50-75%): Consider checkpointing
- 🟠 Orange (75-90%): Checkpoint recommended
- 🔴 Red (90%+): Checkpoint urgently needed
