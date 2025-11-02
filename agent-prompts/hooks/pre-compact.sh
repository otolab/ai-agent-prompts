#!/bin/bash

# コンテキスト圧縮前のモード状態復元

MESSAGE="⚠️ コンテキスト圧縮前の処理\n\n"
MESSAGE="${MESSAGE}以下の手順を実行してください：\n"
MESSAGE="${MESSAGE}1. コンテキストから最新のアクティブなモードリストを検索\n"
MESSAGE="${MESSAGE}2. mode_setツールで状態を保存（MCPオンメモリに保存）\n\n"
MESSAGE="${MESSAGE}※ この処理により、compact後もMCPサーバーのモード状態が保持されます\n\n"

MESSAGE="${MESSAGE}⚠️ コンテキスト圧縮完了後の処理\n\n"
MESSAGE="${MESSAGE}以下の手順をTODOの最初に追加してください：\n"
MESSAGE="${MESSAGE}1. **mode_show()** を実行してモード文書を再読み込み\n\n"
MESSAGE="${MESSAGE}※ 保存されたモードの状態を復元します。"

# Use jq to properly encode JSON with multi-line strings
jq -n \
  --arg message "$MESSAGE" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreCompact",
      additionalContext: $message
    }
  }'
