#!/usr/bin/env bash
# run-autonomous.sh - Autonomous Mode Task Runner
# Main execution script for unattended Claude Code operation
# Part of Agentic Substrate v4.2

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${AUTONOMOUS_CONFIG:-$SCRIPT_DIR/autonomous-config.json}"
CIRCUIT_BREAKER="${SCRIPT_DIR}/../validators/circuit-breaker.sh"
LOG_DIR=""
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
TASK_ID=""
DRY_RUN=false

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [INFO]  $1"; }
log_warn()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [WARN]  $1"; }
log_error() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [ERROR] $1" >&2; }
log_ok()    { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [OK]    $1"; }

# Parse JSON with python3
json_get() {
    local file="$1" path="$2"
    python3 -c "
import json, sys
with open('$file') as f:
    data = json.load(f)
keys = '$path'.split('.')
for k in keys:
    if isinstance(data, list):
        data = data[int(k)]
    else:
        data = data[k]
if isinstance(data, (dict, list)):
    print(json.dumps(data))
elif isinstance(data, bool):
    print('true' if data else 'false')
else:
    print(data)
" 2>/dev/null
}

# Parse JSON array as newline-separated values
json_array() {
    local file="$1" path="$2"
    python3 -c "
import json
with open('$file') as f:
    data = json.load(f)
keys = '$path'.split('.')
for k in keys:
    if isinstance(data, list):
        data = data[int(k)]
    else:
        data = data[k]
if isinstance(data, list):
    for item in data:
        print(item)
" 2>/dev/null
}

usage() {
    cat << 'EOF'
Autonomous Mode Task Runner - Agentic Substrate v4.2

Usage: run-autonomous.sh [OPTIONS] [TASK_ID]

Arguments:
  TASK_ID          Run a specific task by ID (from autonomous-config.json)
                   If omitted, runs all enabled tasks sequentially

Options:
  --config FILE    Path to config file (default: autonomous-config.json)
  --dry-run        Show what would be executed without running
  --list-tasks     List all configured tasks
  --help           Show this help message

Environment Variables:
  AUTONOMOUS_CONFIG    Path to config file (overridden by --config)
  ANTHROPIC_API_KEY    API key (or use secure storage configured by setup-vm.sh)

Examples:
  run-autonomous.sh                          # Run all enabled tasks
  run-autonomous.sh self-improve             # Run specific task
  run-autonomous.sh --dry-run self-improve   # Preview without executing
  run-autonomous.sh --list-tasks             # Show available tasks
EOF
    exit 0
}

# ============================================================================
# PREFLIGHT CHECKS
# ============================================================================

preflight() {
    log_info "Running preflight checks..."

    # Check config file
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    # Check python3 (required for JSON parsing)
    if ! command -v python3 &>/dev/null; then
        log_error "python3 is required for autonomous mode"
        exit 1
    fi

    # Check claude CLI
    if ! command -v claude &>/dev/null; then
        log_error "Claude CLI not found. Install: curl -fsSL https://claude.ai/install.sh | bash"
        exit 1
    fi

    # Check API key
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        local key_file="/home/claude-agent/.config/claude-agent/api-key"
        if [ -f "$key_file" ]; then
            export ANTHROPIC_API_KEY
            ANTHROPIC_API_KEY="$(cat "$key_file")"
            log_info "API key loaded from secure storage"
        else
            log_error "ANTHROPIC_API_KEY not set and no secure key file found"
            log_error "Set via environment or run setup-vm.sh to configure secure storage"
            exit 1
        fi
    fi

    # Check circuit breaker
    if [ -f "$CIRCUIT_BREAKER" ]; then
        if ! bash "$CIRCUIT_BREAKER" "autonomous" "check" 2>/dev/null; then
            log_error "Circuit breaker is OPEN. Too many consecutive failures."
            log_error "Investigate failures, then reset: bash $CIRCUIT_BREAKER autonomous reset"
            exit 1
        fi
    fi

    # Setup log directory
    LOG_DIR=$(json_get "$CONFIG_FILE" "logging.log_dir" 2>/dev/null || echo "/var/log/claude-agent")
    mkdir -p "$LOG_DIR" 2>/dev/null || {
        LOG_DIR="/tmp/claude-agent-logs"
        mkdir -p "$LOG_DIR"
        log_warn "Cannot write to configured log dir, using $LOG_DIR"
    }

    log_ok "Preflight checks passed"
}

# ============================================================================
# TASK EXECUTION
# ============================================================================

get_task_count() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
print(len(data.get('tasks', [])))
"
}

get_task_field() {
    local index="$1" field="$2"
    json_get "$CONFIG_FILE" "tasks.$index.$field"
}

list_tasks() {
    local count
    count=$(get_task_count)
    echo "Configured Tasks ($count):"
    echo "========================="
    for ((i = 0; i < count; i++)); do
        local id name enabled
        id=$(get_task_field "$i" "id")
        name=$(get_task_field "$i" "name")
        enabled=$(get_task_field "$i" "enabled")
        local status="DISABLED"
        [ "$enabled" = "true" ] && status="ENABLED"
        printf "  %-20s %-30s [%s]\n" "$id" "$name" "$status"
    done
}

run_task() {
    local task_index="$1"
    local task_id task_name task_prompt task_max_turns task_max_budget

    task_id=$(get_task_field "$task_index" "id")
    task_name=$(get_task_field "$task_index" "name")
    task_prompt=$(get_task_field "$task_index" "prompt")
    task_max_turns=$(get_task_field "$task_index" "max_turns" 2>/dev/null || echo "20")
    task_max_budget=$(get_task_field "$task_index" "max_budget_usd" 2>/dev/null || echo "5.00")

    log_info "=========================================="
    log_info "Task: $task_name ($task_id)"
    log_info "Max turns: $task_max_turns | Max budget: \$$task_max_budget"
    log_info "=========================================="

    # Get global limits
    local global_max_turns global_max_budget
    global_max_turns=$(json_get "$CONFIG_FILE" "safety.max_turns_global" 2>/dev/null || echo "30")
    global_max_budget=$(json_get "$CONFIG_FILE" "safety.max_budget_usd_global" 2>/dev/null || echo "10.00")

    # Use the more restrictive limit
    local effective_turns effective_budget
    effective_turns=$(python3 -c "print(min($task_max_turns, $global_max_turns))")
    effective_budget=$(python3 -c "print(min($task_max_budget, $global_max_budget))")

    # Get mode
    local mode
    mode=$(json_get "$CONFIG_FILE" "mode" 2>/dev/null || echo "safe")

    # Get model
    local model fallback_model
    model=$(json_get "$CONFIG_FILE" "model.primary" 2>/dev/null || echo "claude-sonnet-4-6")
    fallback_model=$(json_get "$CONFIG_FILE" "model.fallback" 2>/dev/null || echo "claude-sonnet-4-6")

    # Get working directory
    local workdir
    workdir=$(json_get "$CONFIG_FILE" "working_directory" 2>/dev/null || echo "$(pwd)")

    # Get system prompt file
    local system_prompt
    system_prompt=$(json_get "$CONFIG_FILE" "system_prompt_file" 2>/dev/null || echo "")
    if [ -z "$system_prompt" ]; then
        system_prompt="$SCRIPT_DIR/CLAUDE-autonomous.md"
    fi

    # Check git clean requirement
    local require_clean
    require_clean=$(json_get "$CONFIG_FILE" "safety.require_git_clean_before_run" 2>/dev/null || echo "true")
    if [ "$require_clean" = "true" ] && [ -d "$workdir/.git" ]; then
        cd "$workdir"
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            log_error "Working directory has uncommitted changes and require_git_clean_before_run=true"
            log_error "Commit or stash changes before running autonomous mode"
            return 1
        fi
    fi

    # Build the claude command
    local -a cmd=(claude -p --output-format json --no-session-persistence)

    # Model selection
    cmd+=(--model "$model")
    if [ -n "$fallback_model" ]; then
        cmd+=(--fallback-model "$fallback_model")
    fi

    # Turn and budget limits
    cmd+=(--max-turns "$effective_turns")
    cmd+=(--max-budget-usd "$effective_budget")

    # System prompt
    if [ -f "$system_prompt" ]; then
        cmd+=(--system-prompt-file "$system_prompt")
    fi

    # Permission model
    if [ "$mode" = "unsafe" ]; then
        cmd+=(--dangerously-skip-permissions)
        log_warn "Running in UNSAFE mode (--dangerously-skip-permissions)"
    else
        # Build --allowedTools from config
        local allowed_tools
        allowed_tools=$(json_array "$CONFIG_FILE" "safety.allowed_tools" | paste -sd ',' -)
        if [ -n "$allowed_tools" ]; then
            cmd+=(--allowedTools "$allowed_tools")
        fi

        # Build --disallowedTools from config
        local disallowed_tools
        disallowed_tools=$(json_array "$CONFIG_FILE" "safety.disallowed_tools" | paste -sd ',' -)
        if [ -n "$disallowed_tools" ]; then
            cmd+=(--disallowedTools "$disallowed_tools")
        fi
    fi

    # Log the command (without sensitive data)
    log_info "Command: ${cmd[*]} '<prompt>'"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would execute task: $task_id"
        log_info "[DRY RUN] Prompt: $task_prompt"
        return 0
    fi

    # Execute
    local output_file="$LOG_DIR/run-${RUN_ID}-${task_id}.json"
    local exit_code=0

    cd "$workdir"
    if "${cmd[@]}" "$task_prompt" > "$output_file" 2>>"$LOG_DIR/run-${RUN_ID}-${task_id}.stderr.log"; then
        log_ok "Task completed successfully: $task_id"
        exit_code=0
    else
        exit_code=$?
        log_error "Task failed with exit code $exit_code: $task_id"
    fi

    # Record circuit breaker state
    if [ -f "$CIRCUIT_BREAKER" ]; then
        if [ $exit_code -eq 0 ]; then
            bash "$CIRCUIT_BREAKER" "autonomous" "success" 2>/dev/null || true
        else
            bash "$CIRCUIT_BREAKER" "autonomous" "fail" 2>/dev/null || true
        fi
    fi

    # Handle git operations
    local auto_commit auto_push branch_strategy
    auto_commit=$(json_get "$CONFIG_FILE" "safety.auto_commit" 2>/dev/null || echo "true")
    auto_push=$(json_get "$CONFIG_FILE" "safety.auto_push" 2>/dev/null || echo "false")
    branch_strategy=$(json_get "$CONFIG_FILE" "safety.branch_strategy" 2>/dev/null || echo "autonomous/run-{timestamp}")

    if [ "$auto_commit" = "true" ] && [ -d "$workdir/.git" ]; then
        cd "$workdir"
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            # Create branch if strategy requires it
            if [ "$branch_strategy" != "main" ]; then
                local branch_name="${branch_strategy//\{timestamp\}/$RUN_ID}"
                git checkout -b "$branch_name" 2>/dev/null || true
            fi

            git add -A 2>/dev/null || true
            git commit -m "autonomous($task_id): Run $RUN_ID

Task: $task_name
Mode: $mode
Turns: $effective_turns | Budget: \$$effective_budget

Co-Authored-By: Claude <noreply@anthropic.com>" 2>/dev/null || true
            log_ok "Changes committed for task: $task_id"

            if [ "$auto_push" = "true" ]; then
                git push origin HEAD 2>/dev/null || {
                    log_warn "Auto-push failed (manual push required)"
                }
            fi
        else
            log_info "No changes to commit for task: $task_id"
        fi
    fi

    # Generate run report
    log_info "Output saved to: $output_file"

    return $exit_code
}

# ============================================================================
# NOTIFICATION
# ============================================================================

send_notification() {
    local status="$1" message="$2"
    local notify_enabled
    notify_enabled=$(json_get "$CONFIG_FILE" "notifications.enabled" 2>/dev/null || echo "false")

    if [ "$notify_enabled" != "true" ]; then
        return 0
    fi

    local method
    method=$(json_get "$CONFIG_FILE" "notifications.method" 2>/dev/null || echo "none")

    case "$method" in
        webhook)
            local url
            url=$(json_get "$CONFIG_FILE" "notifications.webhook_url" 2>/dev/null || echo "")
            if [ -n "$url" ]; then
                curl -s -X POST "$url" \
                    -H "Content-Type: application/json" \
                    -d "{\"status\":\"$status\",\"message\":\"$message\",\"run_id\":\"$RUN_ID\"}" \
                    2>/dev/null || log_warn "Webhook notification failed"
            fi
            ;;
        file)
            local nfile
            nfile=$(json_get "$CONFIG_FILE" "notifications.notification_file" 2>/dev/null || echo "/var/log/claude-agent/notifications.log")
            echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$status] $message" >> "$nfile" 2>/dev/null || true
            ;;
        *)
            ;;
    esac
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --config)     CONFIG_FILE="$2"; shift 2 ;;
            --dry-run)    DRY_RUN=true; shift ;;
            --list-tasks) preflight; list_tasks; exit 0 ;;
            --help|-h)    usage ;;
            -*)           log_error "Unknown option: $1"; usage ;;
            *)            TASK_ID="$1"; shift ;;
        esac
    done

    preflight

    local task_count overall_status=0
    task_count=$(get_task_count)

    if [ "$task_count" -eq 0 ]; then
        log_warn "No tasks configured"
        exit 0
    fi

    log_info "Run ID: $RUN_ID"
    log_info "Config: $CONFIG_FILE"
    log_info "Tasks: $task_count configured"

    # Run tasks
    for ((i = 0; i < task_count; i++)); do
        local id enabled
        id=$(get_task_field "$i" "id")
        enabled=$(get_task_field "$i" "enabled")

        # If specific task requested, skip others
        if [ -n "$TASK_ID" ] && [ "$id" != "$TASK_ID" ]; then
            continue
        fi

        # Skip disabled tasks (unless specifically requested)
        if [ "$enabled" != "true" ] && [ -z "$TASK_ID" ]; then
            log_info "Skipping disabled task: $id"
            continue
        fi

        if ! run_task "$i"; then
            overall_status=1
            send_notification "failure" "Task $id failed in run $RUN_ID"

            # Check if circuit breaker opened
            if [ -f "$CIRCUIT_BREAKER" ]; then
                if ! bash "$CIRCUIT_BREAKER" "autonomous" "check" 2>/dev/null; then
                    log_error "Circuit breaker opened. Stopping all tasks."
                    send_notification "circuit_breaker" "Circuit breaker opened after task $id"
                    break
                fi
            fi
        else
            send_notification "success" "Task $id completed in run $RUN_ID"
        fi
    done

    if [ $overall_status -eq 0 ]; then
        log_ok "All tasks completed successfully"
    else
        log_error "One or more tasks failed"
    fi

    exit $overall_status
}

main "$@"
