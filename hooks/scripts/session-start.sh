#!/bin/bash
# SessionStart Hook - Initialize session and inject task context
# Reads active task and provides context to Claude

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_SCRIPT="${PLUGIN_ROOT}/scripts/context-db.sh"
CHECKPOINT_SCRIPT="${PLUGIN_ROOT}/scripts/checkpoint-helper.sh"

# Read input from stdin
input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // ""')

# Use project_dir if available, otherwise cwd
base_dir="${project_dir:-$cwd}"

# Initialize session in database
timestamp=$(date +%s)
"$DB_SCRIPT" update "$session_id" <<EOF
{
  "started_at": $timestamp,
  "cwd": "$cwd",
  "project_dir": "$project_dir"
}
EOF

# Try to find active task
todo_dir="${base_dir}/local-docs/todo"
active_task=""
task_context=""

if [ -d "$todo_dir" ]; then
  # Check if there's a saved active task for this session
  saved_task=$("$DB_SCRIPT" get-active-task "$session_id" 2>/dev/null || echo "")

  if [ -n "$saved_task" ] && [ -d "${todo_dir}/${saved_task}" ]; then
    active_task="$saved_task"
  else
    # Find most recently modified task directory
    task_path=$("$CHECKPOINT_SCRIPT" find-task "$todo_dir" 2>/dev/null || echo "")
    if [ -n "$task_path" ] && [ -d "$task_path" ]; then
      active_task=$(basename "$task_path")
      "$DB_SCRIPT" set-active-task "$session_id" "$active_task"
    fi
  fi

  # Load task context if found
  if [ -n "$active_task" ]; then
    index_file="${todo_dir}/${active_task}/00-index.md"
    checkpoint_file="${todo_dir}/${active_task}/CHECKPOINT-LOG.md"

    if [ -f "$index_file" ]; then
      # Read first 100 lines of index for context (avoid huge files)
      task_overview=$(head -100 "$index_file")
    fi

    if [ -f "$checkpoint_file" ]; then
      # Get last checkpoint entry
      last_checkpoint=$("$CHECKPOINT_SCRIPT" last "${todo_dir}/${active_task}" 2>/dev/null || echo "")
    fi
  fi
fi

# Build system message
if [ -n "$active_task" ]; then
  cat << EOF
{
  "continue": true,
  "systemMessage": "📋 **Active Task Detected**: \`${active_task}\`\n\nTask tracking is enabled. Use \`/checkpoint\` to save progress, \`/task-status\` to view current state.\n\nTo switch tasks: \`/set-task <task-name>\`"
}
EOF
else
  cat << EOF
{
  "continue": true,
  "systemMessage": "📋 **Task Tracker**: No active task detected in \`local-docs/todo/\`.\n\nTo start tracking a task, use \`/set-task <task-name>\` or create a task directory following the TODO-WORKFLOW.md convention."
}
EOF
fi
