#!/bin/bash
# Context Database - Fast key-value store for session context tracking
# Usage: context-db.sh <command> [args]
#   get <session_id>           - Get session data
#   set <session_id> <json>    - Set session data
#   update <session_id>        - Update from stdin (JSON)
#   get-threshold <session_id> - Get current context usage percentage
#   cleanup                    - Remove old sessions (>24h)

set -euo pipefail

DB_DIR="${HOME}/.cache/task-tracker"
DB_FILE="${DB_DIR}/sessions.json"

# Ensure database exists
mkdir -p "$DB_DIR"
[ -f "$DB_FILE" ] || echo '{}' > "$DB_FILE"

command="${1:-}"
session_id="${2:-}"

case "$command" in
  get)
    [ -z "$session_id" ] && { echo "{}"; exit 0; }
    jq -r --arg sid "$session_id" '.[$sid] // {}' "$DB_FILE"
    ;;

  set)
    json="${3:-}"
    [ -z "$session_id" ] || [ -z "$json" ] && { echo "Error: session_id and json required" >&2; exit 1; }
    jq --arg sid "$session_id" --argjson data "$json" '.[$sid] = $data' "$DB_FILE" > "${DB_FILE}.tmp"
    mv "${DB_FILE}.tmp" "$DB_FILE"
    ;;

  update)
    [ -z "$session_id" ] && { echo "Error: session_id required" >&2; exit 1; }
    json=$(cat)
    jq --arg sid "$session_id" --argjson data "$json" '.[$sid] = (.[$sid] // {}) * $data' "$DB_FILE" > "${DB_FILE}.tmp"
    mv "${DB_FILE}.tmp" "$DB_FILE"
    ;;

  get-threshold)
    [ -z "$session_id" ] && { echo "0"; exit 0; }
    session_data=$(jq -r --arg sid "$session_id" '.[$sid] // {}' "$DB_FILE")
    current=$(echo "$session_data" | jq -r '.context_usage.input_tokens // 0')
    max=$(echo "$session_data" | jq -r '.context_window_size // 200000')
    if [ "$max" -gt 0 ]; then
      echo "scale=0; $current * 100 / $max" | bc
    else
      echo "0"
    fi
    ;;

  get-active-task)
    [ -z "$session_id" ] && { echo ""; exit 0; }
    jq -r --arg sid "$session_id" '.[$sid].active_task // ""' "$DB_FILE"
    ;;

  set-active-task)
    task="${3:-}"
    [ -z "$session_id" ] && { echo "Error: session_id required" >&2; exit 1; }
    jq --arg sid "$session_id" --arg task "$task" '.[$sid].active_task = $task' "$DB_FILE" > "${DB_FILE}.tmp"
    mv "${DB_FILE}.tmp" "$DB_FILE"
    ;;

  cleanup)
    # Remove sessions older than 24 hours
    cutoff=$(date -v-24H +%s 2>/dev/null || date -d '24 hours ago' +%s)
    jq --argjson cutoff "$cutoff" 'to_entries | map(select(.value.last_updated // 0 > $cutoff)) | from_entries' "$DB_FILE" > "${DB_FILE}.tmp"
    mv "${DB_FILE}.tmp" "$DB_FILE"
    ;;

  *)
    echo "Usage: context-db.sh <get|set|update|get-threshold|get-active-task|set-active-task|cleanup> [args]" >&2
    exit 1
    ;;
esac
