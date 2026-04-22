#!/bin/bash
# SessionStart Hook - Initialize session tracking and remind about task setup
# IMPORTANT: Never auto-detect tasks - multiple agents may work on different tasks simultaneously

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_SCRIPT="${PLUGIN_ROOT}/scripts/context-db.sh"

# Read input from stdin
input=$(cat)

# session_id is ALWAYS provided by Claude Code in hook input
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
  "project_dir": "$project_dir",
  "session_id": "$session_id"
}
EOF

# Check if this session already has an active task set
active_task=$("$DB_SCRIPT" get-active-task "$session_id" 2>/dev/null || echo "")

# Build system message
if [ -n "$active_task" ]; then
  # Task already set for this session
  cat << EOF
{
  "continue": true,
  "systemMessage": "📋 **Task Tracker Active**\\n\\n**Session**: \`${session_id:0:12}...\`\\n**Active Task**: \`${active_task}\`\\n\\nCommands: \`/checkpoint\`, \`/task-status\`, \`/resume-task\`\\n\\n💡 Use \`/rename <task-name>\` to give this session a meaningful name."
}
EOF
else
  # No task set - remind user to set one explicitly
  cat << EOF
{
  "continue": true,
  "systemMessage": "📋 **Task Tracker Ready**\\n\\n**Session**: \`${session_id:0:12}...\`\\n\\nNo active task set. To start tracking:\\n1. \`/set-task <task-name>\` - Set the task you're working on\\n2. \`/rename <task-name>\` - Give this session a meaningful name\\n\\n⚠️ Tasks are NOT auto-detected. Each session must explicitly set its task."
}
EOF
fi
