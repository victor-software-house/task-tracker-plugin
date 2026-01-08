# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Claude Code plugin for tracking task progress and preserving context between session compactions. It integrates with a `local-docs/todo/` workflow to ensure context is never lost during long sessions.

## Development

### Testing Changes

No build system - all files are interpreted directly:
- Shell scripts: `bash -n scripts/*.sh` for syntax check
- JSON files: `jq . hooks/hooks.json` for validation
- Commands/Skills: Markdown files with YAML frontmatter

After changes, restart Claude Code or use `claude --debug` to test hooks.

### Making Scripts Executable

```bash
chmod +x scripts/*.sh hooks/scripts/*.sh
```

## Architecture

### Plugin Structure

```
.claude-plugin/plugin.json  # Plugin manifest (name, version, metadata)
hooks/hooks.json            # Hook definitions (event → script/prompt mappings)
hooks/scripts/              # Shell scripts executed by hooks
scripts/                    # Utility scripts (database, checkpoint, status)
commands/                   # Slash commands (markdown with YAML frontmatter)
skills/                     # Skills (markdown with semantic triggers)
```

### Data Flow

1. **SessionStart hook** → Detects active task from `local-docs/todo/`, initializes session in database
2. **PostToolUse hook** (Edit/Write) → Logs file changes to `.changes.log` in active task directory
3. **PreToolUse hook** (firecrawl) → Warns about token-heavy operations at high context usage
4. **PreCompact hook** → Mandates checkpoint creation before context compaction
5. **Status line script** → Reads context window from Claude, stores in database, outputs colored percentage

### Session Database

Location: `~/.cache/task-tracker/sessions.json`

JSON key-value store keyed by session_id, tracking:
- Active task name
- Context window usage percentage
- Edit counts and last modified file
- Session timestamps

Operations via `scripts/context-db.sh`:
- `get/set/update <session_id>` - Basic CRUD
- `get-active-task/set-active-task <session_id>` - Task management
- `get-threshold <session_id>` - Context usage percentage

### Hook Input/Output Contract

All hooks receive JSON on stdin with session context:
```json
{
  "session_id": "...",
  "cwd": "/path/to/project",
  "tool_name": "Edit",
  "tool_input": {...}
}
```

Command hooks output JSON:
```json
{
  "continue": true,
  "systemMessage": "..."
}
```

### Command Frontmatter

Commands use YAML frontmatter for configuration:
```yaml
---
description: Brief description
argument-hint: [arg description]
allowed-tools: Read, Write, Bash(pattern:*)
---
```

The `!`command`` syntax in command markdown triggers bash execution.

## Key Files

| File | Purpose |
|------|---------|
| `scripts/context-db.sh` | Session state persistence using jq |
| `scripts/checkpoint-helper.sh` | CHECKPOINT-LOG.md file operations |
| `scripts/status-line.sh` | Status bar output with colored context percentage |
| `hooks/hooks.json` | All hook event bindings |
| `hooks/scripts/session-start.sh` | Session initialization and task detection |
| `hooks/scripts/track-change.sh` | File change logging to task directory |

## Expected Task Directory Structure

The plugin expects tasks in the project's `local-docs/todo/`:
```
local-docs/todo/
├── 01-task-name/
│   ├── 00-index.md           # Required - task overview
│   ├── CHECKPOINT-LOG.md     # Created by plugin
│   ├── .changes.log          # Auto-tracked file changes
│   └── .operations.log       # Auto-tracked operations
└── previous-01-*/            # Archived tasks (ignored)
```

## Context Thresholds

| Usage | Status Line Color | Behavior |
|-------|-------------------|----------|
| 0-50% | Green | Normal |
| 50-75% | Yellow | Info notes |
| 75-90% | Orange | Checkpoint recommended |
| 90%+ | Red | Urgent checkpoint |
| PreCompact | N/A | Mandatory checkpoint prompt |
