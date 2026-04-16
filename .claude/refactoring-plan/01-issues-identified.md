# Issues Identified in Current Plugin

## Critical Issues

### 1. Session ID Handling

**Current**: Session ID extracted from stdin in each hook; `set-task.md` references non-existent `/tmp/claude-session-id`

**Problem**:
- Session ID unavailable to commands
- Workaround doesn't work
- No persistence across sessions

**Fix**: Use `CLAUDE_ENV_FILE` in SessionStart to export `TASK_TRACKER_SESSION_ID` as immutable environment variable

### 2. Task Auto-Detection

**Current**: `session-start.sh` finds most recently modified task directory

**Problem**:
- Breaks concurrency: multiple agents working on different tasks conflict
- Violates explicit task management principle
- Unpredictable behavior

**Fix**: Remove auto-detection entirely; require explicit `/set-task`

### 3. No Proper Database

**Current**: JSON file at `~/.cache/task-tracker/sessions.json` with manual jq operations

**Problem**:
- Not transactional
- Race conditions possible
- Manual file locking required
- Not MCP-native

**Fix**: Use SQLite MCP server (`@modelcontextprotocol/server-sqlite`)

---

## Redundancies

### 4. Context Metrics Storage

**Current**: `context-db.sh` stores `context_usage`, `context_window_size`, `percentage`

**Problem**: This data is provided fresh on every status line invocation

**Fix**: Don't store metrics that are provided fresh; calculate inline

### 5. get-threshold Function

**Current**: Calculates context percentage from stored database values

**Problem**: Data already provided in hook/status-line input

**Fix**: Remove; calculate directly from input

### 6. Status Line Database Writes

**Current**: Stores context data for later retrieval

**Problem**: Status line receives fresh data each time; no retrieval needed by status line itself

**Fix**: Status line updates only usage metrics for threshold tracking; does not store context data

---

## Format Issues

### 7. SessionStart Output Format

**Current**: Uses `systemMessage` for context injection

**Spec**: Should use `hookSpecificOutput.additionalContext` for SessionStart

**Fix**: Update output format to match specification

### 8. Timestamp Type in track-change.sh

**Current**: Line 57: `"last_edit_time": $timestamp` where timestamp is string

**Problem**: JSON expects number for timestamp

**Fix**: Remove track-change.sh; use database timestamps instead

---

## Unnecessary Components

### 9. Log Files

**Current**: Multiple log files (`.changes.log`, `.operations.log`)

**Problem**:
- Duplicates database audit capability
- No structured querying
- Clutters task directory

**Fix**: Remove log files; use database with timestamps for auditing

### 10. Edit Tracking Counters

**Current**: Stored in database per session via `track-change.sh`

**Problem**: Low value; complicates architecture

**Fix**: Remove `track-change.sh` and `PostToolUse` hook for Edit/Write

### 11. context-db.sh Script

**Current**: 77-line bash script for JSON manipulation

**Problem**:
- Reinvents database poorly
- Error-prone jq operations
- No concurrent access safety

**Fix**: Delete entirely; use SQLite MCP server

---

## Simplification Opportunities

| Current Component | Lines | Replacement |
|-------------------|-------|-------------|
| `scripts/context-db.sh` | 77 | SQLite MCP server |
| `hooks/scripts/track-change.sh` | 62 | Delete (use DB timestamps) |
| `hooks/scripts/pre-firecrawl.sh` | 81 | Simplified version |
| `.changes.log` files | N/A | Delete |
| `.operations.log` files | N/A | Delete |

**Total lines removed**: ~220+ lines of bash
**New dependencies**: SQLite MCP server (official, maintained)