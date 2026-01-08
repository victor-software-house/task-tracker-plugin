---
name: Progress Tracking
description: This skill should be used when the user asks about "tracking task progress", "checkpoint best practices", "incremental commits", "task documentation", "progress logging", "work tracking", or needs guidance on how to document progress in local-docs/todo/ directories, create effective checkpoint entries, or maintain task state across sessions.
version: 1.0.0
---

# Progress Tracking for Task Management

## Overview

Effective progress tracking preserves context, enables recovery after compaction, and maintains continuity across sessions. This skill provides patterns for documenting progress in the `local-docs/todo/` workflow.

## Core Principles

### Incremental Documentation

Document progress in small, frequent checkpoints rather than large batches:

- **After each subtask**: Create checkpoint noting completion
- **Before expensive operations**: Document intent and expected outcomes
- **When making decisions**: Record rationale and alternatives considered
- **After research**: Capture key findings and implications

### Context-Rich Checkpoints

Each checkpoint should contain enough context for full recovery:

1. **What was done**: Concrete accomplishments since last checkpoint
2. **Why it was done**: Rationale behind decisions
3. **Current state**: Where things stand right now
4. **Next steps**: Immediate actions to continue
5. **Blockers**: Any obstacles or dependencies

### Checkpoint Entry Format

```markdown
## YYYY-MM-DD HH:MM:SS

### Summary
[One-line summary of this checkpoint]

### Progress Since Last Checkpoint
- Completed [specific task/subtask]
- Implemented [feature/fix]
- Researched [topic] - found [key insight]

### Key Insights & Decisions
- Decided to use [approach] because [rationale]
- Discovered that [finding] which means [implication]
- Changed strategy from [old] to [new] due to [reason]

### Current State
[Description of where the work stands]
- Files modified: [list]
- Tests status: [passing/failing/pending]
- Dependencies: [resolved/pending]

### Next Steps
1. [Immediate next action]
2. [Following action]
3. [Third priority]

### Context to Preserve
[Any context that would be lost without explicit documentation]
- Working hypothesis: [...]
- Temporary workaround: [...]
- Investigation path: [...]
```

## Tracking Patterns

### For Code Changes

When modifying code, track:

- **Files touched**: Full paths with brief change descriptions
- **Patterns applied**: Design patterns or refactoring types used
- **Test implications**: Which tests affected or needed
- **Dependencies**: Any new dependencies or removals

### For Research Tasks

When investigating or researching:

- **Sources consulted**: URLs, documentation, files read
- **Key findings**: Distilled insights (not raw data)
- **Dead ends**: Approaches tried and rejected (with reasons)
- **Conclusions**: Actionable takeaways

### For Debugging

When debugging issues:

- **Symptoms**: What was observed
- **Hypotheses**: What was suspected
- **Investigation steps**: What was checked
- **Root cause**: What was found
- **Fix applied**: What was changed

## Integration with TODO-WORKFLOW.md

Follow the established workflow conventions:

### Sequential Execution

Tasks execute in order: `01-* → 02-* → 03-*`

Track which subtask is current and what's next.

### File Structure

```
local-docs/todo/NN-task-name/
├── 00-index.md           # Task overview (update status here)
├── 01-phase-one.md       # Phase documentation
├── 02-phase-two.md
├── CHECKPOINT-LOG.md     # Progress checkpoints
├── .changes.log          # Auto-tracked file changes
└── .operations.log       # Auto-tracked operations
```

### Commit Policy

Commit after each subtask completion:

```bash
git -C local-docs commit -m "checkpoint: [task] - [brief description]"
```

## Best Practices

### Do

- Create checkpoints at natural stopping points
- Include enough context for a fresh session to continue
- Note any temporary state or workarounds
- Record failed approaches to avoid repeating them
- Update 00-index.md status when phases complete

### Don't

- Wait until end of session to checkpoint
- Include raw data dumps (summarize instead)
- Skip documenting "obvious" decisions
- Let checkpoints become stale
- Forget to update task status

## Recovery Usage

After session restart or compaction:

1. Run `/resume-task [name]` to load context
2. Read CHECKPOINT-LOG.md for recent progress
3. Review 00-index.md for overall status
4. Continue from documented next steps

## Commands Available

- `/checkpoint [summary]` - Create progress checkpoint
- `/task-status` - View current task state
- `/resume-task [name]` - Load task context
- `/set-task [name]` - Set active task
