# Task Tracker Plugin - Development Guide

## Project Overview

Claude Code plugin for tracking task progress and preserving context between session compactions.

## Architecture

### Directory Structure

```
task-tracker/
├── .claude-plugin/plugin.json   # Plugin manifest
├── commands/                    # Slash commands (/checkpoint, /set-task, etc.)
├── hooks/
│   ├── hooks.json              # Hook configuration
│   └── scripts/                # Hook implementation scripts
├── scripts/                    # Utility scripts (context-db, checkpoint-helper)
└── skills/                     # Skills for progress-tracking, context-preservation
```

### Key Design Principles

1. **Explicit Task Setting**: Tasks are NEVER auto-detected. Each session must explicitly set its task via `/set-task` because multiple agents may work on different tasks simultaneously.

2. **Session Isolation**: Each session has a unique `session_id` (provided by Claude Code in hook input). This is the key for all session-specific data.

3. **Portable Paths**: Always use `${CLAUDE_PLUGIN_ROOT}` in hooks and commands for file references.

## Development

### Testing Hooks

```bash
# Test with debug output
claude --debug --plugin-dir ~/.claude/plugins/task-tracker

# Validate hook scripts
bash -n hooks/scripts/*.sh
```

### Key Files

| File | Purpose |
|------|---------|
| `scripts/context-db.sh` | Session key-value store |
| `scripts/checkpoint-helper.sh` | CHECKPOINT-LOG.md operations |
| `hooks/hooks.json` | Hook event configuration |

### Hook Events Used

- **SessionStart**: Initialize session, remind about `/set-task`
- **PreToolUse**: Warn before expensive firecrawl operations
- **PostToolUse**: Track file changes (Edit/Write)
- **PreCompact**: Critical checkpoint before context compaction
- **Stop**: Remind to save progress

## Code Style

- Shell scripts: Use `set -euo pipefail`, quote all variables
- Always validate `session_id` from hook input
- Use `jq` for JSON parsing in scripts
- Keep hooks fast (< 5 second timeout for most)

## Pull Request Guidelines

- Create feature branches from `main`
- Test hooks locally before submitting
- Include test plan in PR description
- Update README.md if adding new features