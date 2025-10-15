#!/bin/bash

# デバッグ: 実行条件を記録
echo "[DEBUG] SessionStart triggered at: $(date '+%Y-%m-%d %H:%M:%S')" >&2
echo "[DEBUG] Event: ${CLAUDE_EVENT:-unknown}" >&2
echo "[DEBUG] PID: $$, PPID: $PPID" >&2
echo "[DEBUG] Args: $@" >&2

# プラグインルートディレクトリを取得（環境変数があれば使用、なければ相対パスから計算）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(realpath "$0")))}"

# Base message - using actual line breaks for better readability
BASE_MESSAGE="ToDoリストを再構築してください。作業環境の再構築が最優先です。ユーザからの新しい指示を最後に置きます。
1. @${PLUGIN_ROOT}/prompts/root.md、@${PLUGIN_ROOT}/prompts/principles.mdを再読込して原則を確認します
2. 継続作業について確認し、プロジェクトのCLAUDE.mdやAGENTS.mdなど関連する資料を再読込し、実行計画を立てます
3. @${PLUGIN_ROOT}/prompts/ASSISTANT_MODES.mdで動作モードを確認。必要な資料を再読み込みします"

# Check if .serena directory exists
if [ -d ".serena" ]; then
    MESSAGE="${BASE_MESSAGE}
.serenaディレクトリが存在します。Serenaのアクティベートを行ってください。準備ができてからユーザのリクエストや続きの作業に対応してください。"
else
    MESSAGE="${BASE_MESSAGE}
準備ができてからユーザのリクエストや続きの作業に対応してください。"
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