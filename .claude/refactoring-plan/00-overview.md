# Task Tracker Plugin Refactoring Plan

## Goals

1. **Proper session persistence**: Use `CLAUDE_ENV_FILE` to export immutable `TASK_TRACKER_SESSION_ID`
2. **Concurrency support**: Remove task auto-detection; require explicit `/set-task`
3. **Lightweight MCP database**: Use SQLite MCP server for fast, local persistence
4. **Clean architecture**: Eliminate redundancies, use provided context data
5. **Intelligent checkpointing**: Threshold-based checkpoint triggers with full todo updates
6. **Audit trail**: Database timestamps replace log files

## Key Principles

| Principle | Description |
|-----------|-------------|
| **Immutable Session ID** | `TASK_TRACKER_SESSION_ID` persists across sessions, set once in `SessionStart` |
| **Mutable Task** | Task name can change freely via `/set-task` |
| **Database as source of truth** | SQLite MCP server stores task, metrics, timestamps |
| **Status line = metrics updater** | Sole purpose: update context usage in database |
| **Threshold-triggered checkpoints** | At 50%, 75%, 90%: force full todo review and update |
| **Git integration** | Commit todo changes after each update |

## Architecture Summary

```
SessionStart hook
├── Export TASK_TRACKER_SESSION_ID to CLAUDE_ENV_FILE (immutable)
├── Initialize session record in SQLite (if new)
└── Output context with current task state

PreToolUse hooks
├── Firecrawl-specific: warn about token consumption
└── Wildcard (*): check context threshold, trigger checkpoint if needed

Status line script
├── Read context_window from stdin
├── Update usage metrics in SQLite via MCP
└── Output colored percentage + task name

/set-task command
├── Update active_task in SQLite
├── Initialize todo structure if needed
└── Commit initial todo to git

/checkpoint command
├── Review and update todo entrypoint (00-index.md)
├── Append to change history section
└── Commit changes to git
```

## Files Overview

| Document | Content |
|----------|---------|
| `01-issues-identified.md` | Current plugin issues and redundancies |
| `02-architecture.md` | New architecture with data flow |
| `03-db-schema.md` | SQLite schema and MCP server config |
| `04-hooks-design.md` | Hook implementations (PreToolUse, SessionStart) |
| `05-commands.md` | Updated command specifications |
| `06-implementation-checklist.md` | Step-by-step implementation tasks |
