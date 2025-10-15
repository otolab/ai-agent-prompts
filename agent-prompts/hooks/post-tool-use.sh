#!/bin/bash

# PostToolUse hook for Bash tool
# 1. Adds current working directory to context when cd command is executed
# 2. Warns about git add -A/. without git status in the same command

# Function to output JSON response
output_json() {
    local additional_context="$1"
    if [ -n "$additional_context" ]; then
        cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "$additional_context"
  }
}
EOF
    fi
}

# Check if this is a Bash tool call
if [ "$CLAUDE_CODE_TOOL_NAME" == "Bash" ]; then
    # Extract the command from JSON params
    COMMAND=$(echo "$CLAUDE_CODE_TOOL_PARAMS" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

    # Collect all messages to output
    MESSAGES=""

    # Check if cd command was executed
    if echo "$COMMAND" | grep -q "cd[[:space:]]"; then
        # Get current working directory
        CWD=$(pwd)
        # Add to messages
        if [ -z "$MESSAGES" ]; then
            MESSAGES="[cwd: $CWD]"
        else
            MESSAGES="${MESSAGES}
[cwd: $CWD]"
        fi
    fi

    # Check if git add -A or git add . was executed
    if echo "$COMMAND" | grep -q "git[[:space:]]\+add[[:space:]]\+\(-A\|\.\)" ; then
        # Check if git status is also in the same command (e.g., git add -A && git status)
        if ! echo "$COMMAND" | grep -q "git[[:space:]]\+status"; then
            # Count modified files
            if git rev-parse --git-dir > /dev/null 2>&1; then
                MODIFIED_COUNT=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
                WARNING="[git] ⚠️ ${MODIFIED_COUNT}個のファイルが対象 (git add -A/.) - git statusで内容を確認してください"
                if [ -z "$MESSAGES" ]; then
                    MESSAGES="$WARNING"
                else
                    MESSAGES="${MESSAGES}
${WARNING}"
                fi
            fi
        fi
    fi

    # Output combined messages
    if [ -n "$MESSAGES" ]; then
        output_json "$MESSAGES"
    fi
fi