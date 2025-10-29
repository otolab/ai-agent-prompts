#!/bin/bash

# プラグインルートディレクトリを取得（環境変数があれば使用、なければ相対パスから計算）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(realpath "$0")))}"

# Base message - using actual line breaks for better readability
MESSAGE="最優先で **mode_enter(env_setup)** を実行し指示に従ってください。\n"

if [ -d ".serena" ]; then
    MESSAGE="${MESSAGE}完了後に、Serenaのアクティベートを行ってください\n"
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