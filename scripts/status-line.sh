#!/bin/bash
# Status Line Script for Task Tracker
# Captures context window usage and stores in session database
# Also displays context usage percentage and active task in status line
#
# To use: Add to ~/.claude/settings.json:
# "statusLine": {
#   "script": "~/.claude/plugins/task-tracker/scripts/status-line.sh"
# }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_SCRIPT="${SCRIPT_DIR}/context-db.sh"

# Read input JSON from stdin
input=$(cat)

# Extract session info
session_id=$(echo "$input" | jq -r '.session_id // ""')
context_window=$(echo "$input" | jq -c '.context_window // {}')
cwd=$(echo "$input" | jq -r '.cwd // ""')

# Skip if no session
[ -z "$session_id" ] && exit 0

# Extract context metrics
current_usage=$(echo "$context_window" | jq -c '.current_usage // {}')
context_window_size=$(echo "$context_window" | jq -r '.context_window_size // 200000')
input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')

# Calculate percentage
if [ "$context_window_size" -gt 0 ]; then
  percentage=$((input_tokens * 100 / context_window_size))
else
  percentage=0
fi

# Get active task from database
active_task=$("$DB_SCRIPT" get-active-task "$session_id" 2>/dev/null || echo "")

# Store context data in database
timestamp=$(date +%s)
"$DB_SCRIPT" update "$session_id" <<EOF
{
  "context_usage": $current_usage,
  "context_window_size": $context_window_size,
  "percentage": $percentage,
  "cwd": "$cwd",
  "last_updated": $timestamp
}
EOF

# Determine color based on percentage
# Green (0-50%), Yellow (50-75%), Orange (75-90%), Red (90%+)
if [ "$percentage" -lt 50 ]; then
  color="\033[38;2;152;195;121m"  # Green
elif [ "$percentage" -lt 75 ]; then
  color="\033[38;2;229;192;123m"  # Yellow
elif [ "$percentage" -lt 90 ]; then
  color="\033[38;2;209;154;102m"  # Orange
else
  color="\033[38;2;224;108;117m"  # Red
fi
reset="\033[0m"

# Build status line
status_parts=()

# Context percentage with color
status_parts+=("${color}ctx:${percentage}%${reset}")

# Active task (if set)
if [ -n "$active_task" ]; then
  task_color="\033[38;2;198;160;246m"  # Purple
  status_parts+=("${task_color}task:${active_task}${reset}")
fi

# Output status line (space-separated)
echo -e "${status_parts[*]}"
