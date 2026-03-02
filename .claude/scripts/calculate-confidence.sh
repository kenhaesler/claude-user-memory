#!/usr/bin/env bash
# calculate-confidence.sh
# Bayesian confidence calculation for pattern-recognition skill
# Formula: confidence = base_confidence * time_decay * evidence_factor
#
# Usage: ./calculate-confidence.sh <successes> <total_uses> <days_since_last_use>
# Output: confidence score (0.00-1.00) and level (HIGH/MEDIUM/LOW)

set -e

SUCCESSES="${1:-0}"
TOTAL_USES="${2:-0}"
DAYS_SINCE_USE="${3:-0}"

# Validate inputs
if [ "$TOTAL_USES" -eq 0 ]; then
    echo "0.00 LOW"
    exit 0
fi

# 1. Base confidence (success rate)
# Using bc for floating point, with awk fallback
calc() {
    if command -v bc &>/dev/null; then
        echo "$1" | bc -l 2>/dev/null
    elif command -v awk &>/dev/null; then
        awk "BEGIN {printf \"%.4f\", $1}"
    elif command -v python3 &>/dev/null; then
        python3 -c "print(f'{$1:.4f}')"
    else
        echo "0.0000"
    fi
}

BASE_CONFIDENCE=$(calc "$SUCCESSES / $TOTAL_USES")

# 2. Time decay factor
if [ "$DAYS_SINCE_USE" -gt 180 ]; then
    TIME_DECAY="0.5"
elif [ "$DAYS_SINCE_USE" -gt 90 ]; then
    TIME_DECAY="0.75"
else
    TIME_DECAY="1.0"
fi

# 3. Evidence factor (sample size requirement)
if [ "$TOTAL_USES" -lt 3 ]; then
    EVIDENCE="0.5"
elif [ "$TOTAL_USES" -lt 5 ]; then
    EVIDENCE="0.75"
else
    EVIDENCE="1.0"
fi

# Calculate final confidence
CONFIDENCE=$(calc "$BASE_CONFIDENCE * $TIME_DECAY * $EVIDENCE")

# Classify confidence level
# Compare using awk for portability
LEVEL=$(awk "BEGIN {
    c = $CONFIDENCE + 0;
    if (c >= 0.80) print \"HIGH\";
    else if (c >= 0.50) print \"MEDIUM\";
    else print \"LOW\";
}")

# Format to 2 decimal places
FORMATTED=$(awk "BEGIN {printf \"%.2f\", $CONFIDENCE + 0}")

echo "$FORMATTED $LEVEL"
