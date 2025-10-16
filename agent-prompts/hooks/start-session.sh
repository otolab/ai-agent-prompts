#!/bin/bash

# プラグインルートディレクトリを取得（環境変数があれば使用、なければ相対パスから計算）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(realpath "$0")))}"

# Base message - using actual line breaks for better readability
BASE_MESSAGE="作業環境の再構築を最優先で行ってください。完了後に継続作業やユーザからの新しい指示を実行します。\n
1. ${PLUGIN_ROOT}/prompts/root.mdと指定された関連ファイルを読み込む\n
2. 動作モードを確認。必要な資料を追加で読み込む\n
3. 継続作業について確認し、プロジェクトのCLAUDE.mdやAGENTS.mdなど関連する資料を再読込、TODOを再構築\n
4. ユーザのメッセージを確認して実行"

# Check if .serena directory exists
if [ -d ".serena" ]; then
    MESSAGE="${BASE_MESSAGE}\n
5. .serenaディレクトリが存在します。Serenaのアクティベートを行ってください。準備ができてからユーザのリクエストや続きの作業に対応してください。"
else
    MESSAGE="${BASE_MESSAGE}\n
5. 準備ができてからユーザのリクエストや続きの作業に対応してください。"
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