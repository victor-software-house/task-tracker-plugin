#!/bin/bash
# PostToolUse Hook - Track file changes for progress monitoring
# Lightweight tracking of Edit/Write operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_SCRIPT="${PLUGIN_ROOT}/scripts/context-db.sh"

# Read input from stdin
input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // ""')
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -c '.tool_input // {}')
cwd=$(echo "$input" | jq -r '.cwd // ""')

# Get active task
active_task=$("$DB_SCRIPT" get-active-task "$session_id" 2>/dev/null || echo "")

# Extract file path
file_path=$(echo "$tool_input" | jq -r '.file_path // .path // ""')

# Skip if no active task
[ -z "$active_task" ] && exit 0

# Get todo directory
todo_dir="${cwd}/local-docs/todo"
task_dir="${todo_dir}/${active_task}"

# Skip if task directory doesn't exist
[ ! -d "$task_dir" ] && exit 0

# Make path relative to cwd if possible
if [[ "$file_path" == "$cwd"* ]]; then
  rel_path="${file_path#$cwd/}"
else
  rel_path="$file_path"
fi

# Track the change
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
changes_file="${task_dir}/.changes.log"

echo "[${timestamp}] ${tool_name}: ${rel_path}" >> "$changes_file"

# Update session stats in database
current_data=$("$DB_SCRIPT" get "$session_id")
edits_count=$(echo "$current_data" | jq -r '.edits_count // 0')
edits_count=$((edits_count + 1))

"$DB_SCRIPT" update "$session_id" <<EOF
{
  "edits_count": $edits_count,
  "last_edit": "$rel_path",
  "last_edit_time": $timestamp
}
EOF

# Silent success - don't interrupt flow
exit 0
