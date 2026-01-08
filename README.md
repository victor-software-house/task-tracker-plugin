# Task Tracker Plugin for Claude Code

Track task progress and preserve context between session compactions. This plugin integrates with the `local-docs/todo/` workflow to ensure context is never lost.

## Features

### Hooks

- **SessionStart**: Automatically detects and loads active task context
- **PreToolUse (firecrawl)**: Warns before expensive token-consuming operations
- **PostToolUse (Edit/Write)**: Tracks file changes for progress monitoring
- **PreCompact**: Prompts for checkpoint before context compaction
- **Stop**: Reminds to save progress before session ends

### Commands

| Command | Description |
|---------|-------------|
| `/checkpoint [summary]` | Save progress checkpoint to active task |
| `/task-status` | Show current task status and recent progress |
| `/resume-task [name]` | Resume a task by loading its full context |
| `/set-task [name]` | Set the active task for tracking |

### Skills

- **progress-tracking**: Best practices for documenting progress
- **context-preservation**: Strategies for preserving context before compaction

## Installation

### Option 1: Symlink (Recommended for Development)

```bash
ln -s ~/.claude/plugins/task-tracker ~/.claude-plugin
```

### Option 2: Direct Plugin Directory

The plugin is already installed at `~/.claude/plugins/task-tracker`. Claude Code will discover it automatically if you have plugin auto-discovery enabled.

### Option 3: CLI Flag

```bash
claude --plugin-dir ~/.claude/plugins/task-tracker
```

## Configuration

### Status Line (Optional)

To display context usage percentage and active task in your status line, add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "script": "~/.claude/plugins/task-tracker/scripts/status-line.sh"
  }
}
```

The status line shows:
- `ctx:X%` - Current context window usage (color-coded)
- `task:name` - Currently active task

### Context Thresholds

The plugin uses these thresholds for warnings:

| Context % | Behavior |
|-----------|----------|
| 0-50% | Normal operation (green) |
| 50-75% | Informational notes (yellow) |
| 75-90% | Checkpoint recommended (orange) |
| 90%+ | Urgent checkpoint needed (red) |
| PreCompact | Mandatory checkpoint prompt |

## Directory Structure

The plugin expects tasks in `local-docs/todo/` following this structure:

```
local-docs/todo/
├── 01-task-name/
│   ├── 00-index.md           # Task overview (required)
│   ├── 01-phase-one.md       # Phase documentation
│   ├── CHECKPOINT-LOG.md     # Progress checkpoints (auto-created)
│   ├── .changes.log          # File change tracking (auto-created)
│   └── .operations.log       # Operation tracking (auto-created)
├── 02-another-task/
└── previous-01-[archived]/   # Completed/archived tasks
```

## Usage Examples

### Starting Work on a Task

```bash
# Set active task
/set-task 01-feature-implementation

# Or by name
/set-task feature-implementation
```

### Creating Checkpoints

```bash
# With summary
/checkpoint Completed API endpoint implementation, tests passing

# Interactive (prompts for details)
/checkpoint
```

### Checking Status

```bash
/task-status
```

### Resuming After Context Loss

```bash
/resume-task 01-feature-implementation
```

## Files Created

The plugin creates/uses these files in each task directory:

| File | Purpose |
|------|---------|
| `CHECKPOINT-LOG.md` | Timestamped progress entries |
| `.changes.log` | Auto-tracked file modifications |
| `.operations.log` | Auto-tracked expensive operations |

## Session Database

Context usage and task state are stored in:
```
~/.cache/task-tracker/sessions.json
```

This enables context percentage tracking across hook invocations.

## Integration with TODO-WORKFLOW.md

This plugin is designed to work with the workflow defined in `local-docs/todo/TODO-WORKFLOW.md`:

- Sequential task execution: `01-* → 02-* → 03-*`
- Incremental commits after each subtask
- Context recovery via `00-index.md` and `CHECKPOINT-LOG.md`

## Troubleshooting

### Hooks Not Firing

1. Verify plugin is loaded: `/plugins`
2. Check hook syntax: `claude --debug`
3. Ensure scripts are executable: `chmod +x ~/.claude/plugins/task-tracker/**/*.sh`

### Task Not Detected

1. Verify task directory exists in `local-docs/todo/`
2. Check `00-index.md` exists in task directory
3. Use `/set-task` to manually set active task

### Context Database Issues

Reset the database:
```bash
rm ~/.cache/task-tracker/sessions.json
```

## Development

To modify the plugin:

1. Edit files in `~/.claude/plugins/task-tracker/`
2. Restart Claude Code to reload hooks
3. Test with `claude --debug`

## License

MIT
