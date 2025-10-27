#!/bin/bash

# プラグインルートディレクトリを取得（環境変数があれば使用、なければ相対パスから計算）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $(realpath "$0")))}"

# Base message - using actual line breaks for better readability
MESSAGE="以下の作業環境の再構築を最優先で行ってください。完了後に継続作業やユーザからの新しい指示を実行します。\n
0. ユーザ指示やTODOリストがあればメモとして書き出し、以下の作業を環境構築作業としてスケジュールする\n
1. ${PLUGIN_ROOT}/prompts/root.mdと指定された関連ファイルを読み込む\n
2. アシスタント動作モードを再設定\n"

if [ -d ".serena" ]; then
    MESSAGE="${MESSAGE}2-1. .serenaディレクトリが存在します。Serenaのアクティベートを行ってください。\n"
fi

MESSAGE="${MESSAGE}3. 継続作業、ユーザのリクエストについて確認\n
4. 作業計画やメモを再読み込み。環境の再整備のために読み込んだファイルの一覧を出力\n
5. 必要に応じてTODOを再構築・作業を開始する"

# Use jq to properly encode JSON with multi-line strings
jq -n \
  --arg message "$MESSAGE" \
  '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $message
    }
  }'