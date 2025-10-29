#!/bin/bash

# プラグインルートディレクトリを取得（環境変数があれば使用、なければ相対パスから計算）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(realpath "$0")))}"

# Base message - using actual line breaks for better readability
MESSAGE="最優先で以下の環境構築を行ってください。\n
0. 現在有効なユーザ指示やTODOリストがあればメモとして書き出し、代わりに以下の環境構築作業をスケジュールする\n
1. **${PLUGIN_ROOT}/prompts/root.md を読み込み、指示に従う**\n
2. アシスタント動作モードを再設定\n"

if [ -d ".serena" ]; then
    MESSAGE="${MESSAGE}2-1. Serenaのアクティベート\n"
fi

MESSAGE="${MESSAGE}3. 継続作業、ユーザのリクエストの内容を確認\n
4. タスクの作業計画やメモを再読み込み\n
5. 環境の再整備のために読み込んだファイルの一覧を出力\n
6. 必要に応じてTODOを再構築・作業を開始する"

# Use jq to properly encode JSON with multi-line strings
jq -n \
  --arg message "$MESSAGE" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $message
    }
  }'