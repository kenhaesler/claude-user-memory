#!/usr/bin/env bash
# auto-format.sh
# PostToolUse hook: Automatically format code after Write/Edit operations
# This ensures consistent code style across all files.
# Claude Code passes hook input as JSON on stdin. Keep positional-argument
# support so the script remains easy to test manually.

FILE_PATH="${1:-}"  # Path to file that was just written/edited
HOOK_INPUT=""

if [ -z "$FILE_PATH" ] && [ ! -t 0 ]; then
    HOOK_INPUT="$(cat)"
fi

if [ -z "$FILE_PATH" ] && [ -n "$HOOK_INPUT" ]; then
    if command -v python3 >/dev/null 2>&1; then
        FILE_PATH=$(printf '%s' "$HOOK_INPUT" | python3 -c 'import json,sys; data=json.load(sys.stdin); ti=data.get("tool_input",{}); print(ti.get("file_path") or ti.get("path") or "")' 2>/dev/null || true)
    elif command -v python >/dev/null 2>&1; then
        FILE_PATH=$(printf '%s' "$HOOK_INPUT" | python -c 'import json,sys; data=json.load(sys.stdin); ti=data.get("tool_input",{}); print(ti.get("file_path") or ti.get("path") or "")' 2>/dev/null || true)
    fi
fi

[ -z "$FILE_PATH" ] && exit 0

# Only format code files (not markdown, json, etc.)
case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx)
        if command -v prettier &> /dev/null; then
            prettier --write "$FILE_PATH" 2>/dev/null || true
            echo "✨ Auto-formatted: $FILE_PATH"
        fi
        ;;
    *.py)
        if command -v black &> /dev/null; then
            black "$FILE_PATH" 2>/dev/null || true
            echo "✨ Auto-formatted: $FILE_PATH"
        fi
        ;;
    *.go)
        if command -v gofmt &> /dev/null; then
            gofmt -w "$FILE_PATH" 2>/dev/null || true
            echo "✨ Auto-formatted: $FILE_PATH"
        fi
        ;;
    *.rs)
        if command -v rustfmt &> /dev/null; then
            rustfmt "$FILE_PATH" 2>/dev/null || true
            echo "✨ Auto-formatted: $FILE_PATH"
        fi
        ;;
esac

exit 0  # Never block on formatting
