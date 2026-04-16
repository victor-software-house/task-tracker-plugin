# Database Schema

## MCP Server Configuration

### Option 1: Official SQLite MCP Server (Recommended)

`.mcp.json`:
```json
{
  "mcpServers": {
    "task-tracker-db": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sqlite",
        "--db-path",
        "${CLAUDE_PLUGIN_ROOT}/data/task-tracker.db"
      ],
      "env": {}
    }
  }
}
```

**Pros**:
- Official Anthropic implementation
- Well-maintained
- Standard SQLite operations

**Tools provided**:
- `read_query` - Execute SELECT queries
- `write_query` - Execute INSERT/UPDATE/DELETE
- `create_table` - Create new tables
- `list_tables` - List all tables
- `describe_table` - Get table schema

### Option 2: Alternative SQLite MCP Servers

If the official server has limitations:

```json
{
  "mcpServers": {
    "task-tracker-db": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-sqlite-tools",
        "--db",
        "${CLAUDE_PLUGIN_ROOT}/data/task-tracker.db"
      ]
    }
  }
}
```

---

## Schema Design

### Table: `sessions`

```sql
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    active_task TEXT,
    context_percentage INTEGER DEFAULT 0,
    thresholds_passed TEXT DEFAULT '[]',  -- JSON array: [50, 75, 90]
    project_dir TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_sessions_updated ON sessions(updated_at);
```

### Field Descriptions

| Field | Type | Description | Mutability |
|-------|------|-------------|------------|
| `session_id` | TEXT | Unique session identifier from Claude | Immutable (PK) |
| `active_task` | TEXT | Current task name (e.g., "01-feature") | Mutable via /set-task |
| `context_percentage` | INTEGER | Last known context usage (0-100) | Updated by status line |
| `thresholds_passed` | TEXT | JSON array of passed thresholds | Updated on checkpoint |
| `project_dir` | TEXT | Project root path | Set on session start |
| `created_at` | INTEGER | Unix timestamp of session creation | Immutable |
| `updated_at` | INTEGER | Unix timestamp of last update | Auto-updated |

---

## SQL Operations

### Session Start - Initialize/Load

```sql
-- Check if session exists
SELECT * FROM sessions WHERE session_id = ?;

-- If not exists, create
INSERT INTO sessions (session_id, project_dir)
VALUES (?, ?);

-- If exists, load current state
SELECT active_task, context_percentage, thresholds_passed
FROM sessions WHERE session_id = ?;
```

### Status Line - Update Metrics

```sql
UPDATE sessions
SET context_percentage = ?,
    updated_at = strftime('%s', 'now')
WHERE session_id = ?;
```

### Threshold Check

```sql
SELECT context_percentage, thresholds_passed
FROM sessions
WHERE session_id = ?;
```

### Mark Threshold Passed

```sql
UPDATE sessions
SET thresholds_passed = json_insert(thresholds_passed, '$[#]', ?),
    updated_at = strftime('%s', 'now')
WHERE session_id = ?;
```

### Set Active Task

```sql
UPDATE sessions
SET active_task = ?,
    thresholds_passed = '[]',  -- Reset thresholds on task change
    updated_at = strftime('%s', 'now')
WHERE session_id = ?;
```

### Get Active Task

```sql
SELECT active_task FROM sessions WHERE session_id = ?;
```

### Cleanup Old Sessions (Optional Maintenance)

```sql
DELETE FROM sessions
WHERE updated_at < strftime('%s', 'now') - 86400 * 7;  -- 7 days
```

---

## Database Location

**Path**: `${CLAUDE_PLUGIN_ROOT}/data/task-tracker.db`

**Rationale**:
- Inside plugin directory for portability
- `data/` subdirectory keeps it organized
- SQLite file created automatically if not exists

**Git ignore**: Add to `.gitignore`:
```
/data/
```

---

## Migration from Current System

### Data to Migrate

From `~/.cache/task-tracker/sessions.json`:
- `active_task` per session
- Nothing else (context data was redundant)

### Migration Script (One-time)

```bash
#!/bin/bash
# migrate-to-sqlite.sh

OLD_DB="${HOME}/.cache/task-tracker/sessions.json"
NEW_DB="${CLAUDE_PLUGIN_ROOT}/data/task-tracker.db"

if [ -f "$OLD_DB" ]; then
    echo "Migrating from JSON to SQLite..."

    # Create table
    sqlite3 "$NEW_DB" "CREATE TABLE IF NOT EXISTS sessions (...)"

    # Extract and insert each session
    jq -r 'to_entries[] | [.key, .value.active_task] | @tsv' "$OLD_DB" | \
    while IFS=$'\t' read -r sid task; do
        sqlite3 "$NEW_DB" "INSERT OR IGNORE INTO sessions (session_id, active_task) VALUES ('$sid', '$task')"
    done

    echo "Migration complete. Old file preserved at: $OLD_DB"
fi
```

---

## Initialization (First Run)

The SessionStart hook should create the table if it doesn't exist:

```bash
# In session-start.sh
sqlite3 "$DB_PATH" << 'EOF'
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    active_task TEXT,
    context_percentage INTEGER DEFAULT 0,
    thresholds_passed TEXT DEFAULT '[]',
    project_dir TEXT,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
EOF
```

Or via MCP tool call from Claude during first use.
