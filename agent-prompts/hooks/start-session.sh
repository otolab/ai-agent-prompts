#!/bin/bash

# Base message - using actual line breaks for better readability
MESSAGE="新しいセッションが始まりました。TODOやユーザ指示を実行する前に **mode_list()** を実行して下さい"

if [ -d ".serena" ]; then
    MESSAGE="${MESSAGE}\n完了後に、Serenaのアクティベートを行ってください\n"
fi

# Use jq to properly encode JSON with multi-line strings
jq -n \
  --arg message "$MESSAGE" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $message
    }
  }'