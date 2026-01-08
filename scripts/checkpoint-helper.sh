#!/bin/bash
# Checkpoint Helper - Creates checkpoint entries in task's CHECKPOINT-LOG.md
# Usage: checkpoint-helper.sh <command> [args]
#   append <task_dir> <message>  - Append checkpoint entry
#   init <task_dir>              - Initialize checkpoint log
#   read <task_dir>              - Read checkpoint log
#   last <task_dir>              - Get last checkpoint entry

set -euo pipefail

command="${1:-}"
task_dir="${2:-}"
message="${3:-}"

# Validate task directory
validate_task_dir() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    echo "Error: Task directory not found: $dir" >&2
    exit 1
  fi
  if [ ! -f "$dir/00-index.md" ]; then
    echo "Error: Not a valid task directory (missing 00-index.md): $dir" >&2
    exit 1
  fi
}

case "$command" in
  append)
    [ -z "$task_dir" ] || [ -z "$message" ] && { echo "Error: task_dir and message required" >&2; exit 1; }
    validate_task_dir "$task_dir"

    log_file="${task_dir}/CHECKPOINT-LOG.md"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Initialize log if doesn't exist
    if [ ! -f "$log_file" ]; then
      task_name=$(basename "$task_dir")
      cat > "$log_file" << EOF
# Checkpoint Log: ${task_name}

Timestamped progress entries for context preservation.

---

EOF
    fi

    # Append entry
    cat >> "$log_file" << EOF

## ${timestamp}

${message}

EOF

    echo "Checkpoint saved to: $log_file"
    ;;

  init)
    [ -z "$task_dir" ] && { echo "Error: task_dir required" >&2; exit 1; }
    validate_task_dir "$task_dir"

    log_file="${task_dir}/CHECKPOINT-LOG.md"
    task_name=$(basename "$task_dir")

    cat > "$log_file" << EOF
# Checkpoint Log: ${task_name}

Timestamped progress entries for context preservation.

---

EOF
    echo "Initialized: $log_file"
    ;;

  read)
    [ -z "$task_dir" ] && { echo "Error: task_dir required" >&2; exit 1; }
    validate_task_dir "$task_dir"

    log_file="${task_dir}/CHECKPOINT-LOG.md"
    if [ -f "$log_file" ]; then
      cat "$log_file"
    else
      echo "No checkpoint log found for this task."
    fi
    ;;

  last)
    [ -z "$task_dir" ] && { echo "Error: task_dir required" >&2; exit 1; }
    validate_task_dir "$task_dir"

    log_file="${task_dir}/CHECKPOINT-LOG.md"
    if [ -f "$log_file" ]; then
      # Extract last entry (from last ## timestamp to end)
      awk '/^## [0-9]{4}-[0-9]{2}-[0-9]{2}/ { found=1; entry="" } found { entry = entry $0 "\n" } END { printf "%s", entry }' "$log_file"
    else
      echo "No checkpoint log found."
    fi
    ;;

  find-task)
    # Find the most recently modified task directory
    todo_dir="${2:-local-docs/todo}"
    if [ -d "$todo_dir" ]; then
      # Find directories matching NN-* pattern, exclude previous-*
      find "$todo_dir" -maxdepth 1 -type d -name '[0-9][0-9]-*' ! -name 'previous-*' -exec stat -f '%m %N' {} \; 2>/dev/null | \
        sort -rn | head -1 | cut -d' ' -f2-
    fi
    ;;

  *)
    echo "Usage: checkpoint-helper.sh <append|init|read|last|find-task> [args]" >&2
    exit 1
    ;;
esac
