#!/bin/bash
# PreToolUse Hook for Firecrawl operations
# Auto-documents the intention before expensive token-consuming operations
# Then allows the operation to proceed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DB_SCRIPT="${PLUGIN_ROOT}/scripts/context-db.sh"
CHECKPOINT_SCRIPT="${PLUGIN_ROOT}/scripts/checkpoint-helper.sh"

# Read input from stdin
input=$(cat)

session_id=$(echo "$input" | jq -r '.session_id // ""')
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
tool_input=$(echo "$input" | jq -c '.tool_input // {}')
cwd=$(echo "$input" | jq -r '.cwd // ""')

# Get active task
active_task=$("$DB_SCRIPT" get-active-task "$session_id" 2>/dev/null || echo "")

# Extract search/scrape details for logging
url=$(echo "$tool_input" | jq -r '.url // .urls[0] // ""')
query=$(echo "$tool_input" | jq -r '.query // ""')
limit=$(echo "$tool_input" | jq -r '.limit // ""')

# Build operation description
operation_desc="$tool_name"
if [ -n "$query" ]; then
  operation_desc="${operation_desc}: query=\"${query}\""
elif [ -n "$url" ]; then
  # Truncate URL if too long
  if [ ${#url} -gt 80 ]; then
    url="${url:0:77}..."
  fi
  operation_desc="${operation_desc}: ${url}"
fi

# Get current context percentage
context_pct=$("$DB_SCRIPT" get-threshold "$session_id" 2>/dev/null || echo "0")

# Log the operation intent
timestamp=$(date '+%Y-%m-%d %H:%M:%S')

# If we have an active task, auto-document
if [ -n "$active_task" ]; then
  todo_dir="${cwd}/local-docs/todo"
  task_dir="${todo_dir}/${active_task}"

  if [ -d "$task_dir" ]; then
    # Record in operations log (lightweight tracking)
    ops_file="${task_dir}/.operations.log"
    echo "[${timestamp}] ${operation_desc} (context: ${context_pct}%)" >> "$ops_file"
  fi
fi

# Provide context-aware message
if [ "$context_pct" -ge 75 ]; then
  cat << EOF
{
  "continue": true,
  "systemMessage": "⚠️ **High Context Usage (${context_pct}%)**: About to execute \`${tool_name}\` which consumes significant tokens.\n\n**Before proceeding**, briefly document:\n- What you're searching for and why\n- What insights you expect to gain\n\nThis context will help if compaction occurs. Operation will proceed automatically."
}
EOF
elif [ "$context_pct" -ge 50 ]; then
  cat << EOF
{
  "continue": true,
  "systemMessage": "📊 **Context at ${context_pct}%**: Executing \`${tool_name}\`. Consider documenting key findings afterward using \`/checkpoint\`."
}
EOF
else
  # Low context usage, proceed silently
  cat << EOF
{
  "continue": true
}
EOF
fi
