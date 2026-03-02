#!/usr/bin/env bash
# metrics/tracker.sh
# Track workflow metrics for continuous improvement

set -e

METRICS_FILE=".claude/metrics/data.json"
METRICS_DIR=".claude/metrics"

# Create metrics directory and file if they don't exist
mkdir -p "$METRICS_DIR"
if [ ! -f "$METRICS_FILE" ]; then
    cat > "$METRICS_FILE" << 'EOF'
{
  "version": "1.0",
  "sessions": [],
  "summary": {
    "total_workflows": 0,
    "successful_workflows": 0,
    "failed_workflows": 0,
    "total_self_corrections": 0,
    "avg_research_score": 0,
    "avg_plan_score": 0,
    "patterns_captured": 0
  }
}
EOF
fi

# Function to record workflow start
record_workflow_start() {
    local workflow_id="$1"
    local feature_name="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Implementation: Add to sessions array
    echo "📊 Workflow started: $workflow_id"
    echo "   Feature: $feature_name"
    echo "   Time: $timestamp"
}

# Function to record phase completion
record_phase() {
    local workflow_id="$1"
    local phase="$2"  # research, planning, implementation
    local score="$3"
    local duration="$4"

    echo "📈 Phase complete: $phase"
    echo "   Score: $score"
    echo "   Duration: ${duration}s"
}

# Function to record workflow completion
record_workflow_complete() {
    local workflow_id="$1"
    local status="$2"  # success or failure
    local self_corrections="$3"

    echo "✅ Workflow $status: $workflow_id"
    echo "   Self-corrections: $self_corrections"

    # Update summary stats in JSON
    if [ ! -f "$METRICS_FILE" ]; then
        echo "⚠️  Metrics file not found, skipping update"
        return
    fi

    if command -v jq &>/dev/null; then
        local inc_total=1
        local inc_success=0
        local inc_failed=0
        if [ "$status" = "success" ]; then
            inc_success=1
        else
            inc_failed=1
        fi
        local tmp_file="${METRICS_FILE}.tmp"
        jq ".summary.total_workflows += $inc_total |
            .summary.successful_workflows += $inc_success |
            .summary.failed_workflows += $inc_failed |
            .summary.total_self_corrections += ${self_corrections:-0}" \
            "$METRICS_FILE" > "$tmp_file" && mv "$tmp_file" "$METRICS_FILE"
    elif command -v python3 &>/dev/null; then
        python3 -c "
import json
with open('$METRICS_FILE', 'r') as f:
    data = json.load(f)
data['summary']['total_workflows'] += 1
if '$status' == 'success':
    data['summary']['successful_workflows'] += 1
else:
    data['summary']['failed_workflows'] += 1
data['summary']['total_self_corrections'] += int('${self_corrections:-0}')
with open('$METRICS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
    else
        echo "⚠️  No jq or python3 available, skipping JSON update"
    fi
}

# Function to generate metrics report
generate_report() {
    echo "📊 Metrics Report"
    echo "================"
    echo ""

    if [ ! -f "$METRICS_FILE" ]; then
        echo "No metrics data available yet."
        return
    fi

    # Parse JSON and display metrics
    local TOTAL SUCCESSFUL FAILED CORRECTIONS AVG_RESEARCH AVG_PLAN PATTERNS

    if command -v jq &>/dev/null; then
        TOTAL=$(jq '.summary.total_workflows' "$METRICS_FILE")
        SUCCESSFUL=$(jq '.summary.successful_workflows' "$METRICS_FILE")
        FAILED=$(jq '.summary.failed_workflows' "$METRICS_FILE")
        CORRECTIONS=$(jq '.summary.total_self_corrections' "$METRICS_FILE")
        AVG_RESEARCH=$(jq '.summary.avg_research_score' "$METRICS_FILE")
        AVG_PLAN=$(jq '.summary.avg_plan_score' "$METRICS_FILE")
        PATTERNS=$(jq '.summary.patterns_captured' "$METRICS_FILE")
    elif command -v python3 &>/dev/null; then
        TOTAL=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['total_workflows'])")
        SUCCESSFUL=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['successful_workflows'])")
        FAILED=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['failed_workflows'])")
        CORRECTIONS=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['total_self_corrections'])")
        AVG_RESEARCH=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['avg_research_score'])")
        AVG_PLAN=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['avg_plan_score'])")
        PATTERNS=$(python3 -c "import json; print(json.load(open('$METRICS_FILE'))['summary']['patterns_captured'])")
    else
        TOTAL=$(grep -o '"total_workflows": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        SUCCESSFUL=$(grep -o '"successful_workflows": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        FAILED=$(grep -o '"failed_workflows": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        CORRECTIONS=$(grep -o '"total_self_corrections": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        AVG_RESEARCH=$(grep -o '"avg_research_score": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        AVG_PLAN=$(grep -o '"avg_plan_score": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
        PATTERNS=$(grep -o '"patterns_captured": [0-9]*' "$METRICS_FILE" | grep -o '[0-9]*')
    fi

    # Calculate success rate
    local RATE="N/A"
    if [ "${TOTAL:-0}" -gt 0 ] 2>/dev/null; then
        if command -v awk &>/dev/null; then
            RATE=$(awk "BEGIN {printf \"%.0f%%\", (${SUCCESSFUL:-0}/${TOTAL}) * 100}")
        fi
    fi

    # Calculate avg corrections per workflow
    local AVG_CORR="N/A"
    if [ "${TOTAL:-0}" -gt 0 ] 2>/dev/null; then
        if command -v awk &>/dev/null; then
            AVG_CORR=$(awk "BEGIN {printf \"%.1f\", ${CORRECTIONS:-0}/${TOTAL}}")
        fi
    fi

    echo "Workflows:"
    echo "  Total: ${TOTAL:-0}"
    echo "  Successful: ${SUCCESSFUL:-0}"
    echo "  Failed: ${FAILED:-0}"
    echo "  Success Rate: $RATE"
    echo ""
    echo "Quality Scores:"
    echo "  Avg Research Score: ${AVG_RESEARCH:-0}"
    echo "  Avg Plan Score: ${AVG_PLAN:-0}"
    echo ""
    echo "Self-Corrections:"
    echo "  Total: ${CORRECTIONS:-0}"
    echo "  Avg per workflow: $AVG_CORR"
    echo ""
    echo "Knowledge:"
    echo "  Patterns Captured: ${PATTERNS:-0}"
}

# Main command dispatcher
case "${1:-help}" in
    "start")
        record_workflow_start "$2" "$3"
        ;;
    "phase")
        record_phase "$2" "$3" "$4" "$5"
        ;;
    "complete")
        record_workflow_complete "$2" "$3" "$4"
        ;;
    "report")
        generate_report
        ;;
    "help"|*)
        cat << EOF
Usage: $0 <command> [args]

Commands:
  start <workflow-id> <feature-name>
    Record workflow start

  phase <workflow-id> <phase-name> <score> <duration>
    Record phase completion (research, planning, implementation)

  complete <workflow-id> <status> <self-corrections>
    Record workflow completion (status: success|failure)

  report
    Generate metrics report

Examples:
  $0 start wf-001 "Add Redis caching"
  $0 phase wf-001 research 85 120
  $0 phase wf-001 planning 88 180
  $0 phase wf-001 implementation 100 300
  $0 complete wf-001 success 1
  $0 report
EOF
        ;;
esac
