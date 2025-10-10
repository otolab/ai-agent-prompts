#!/bin/bash

# Base message
BASE_MESSAGE="初期状態を整えるために、環境として与えられたコンテキストを揃えることを最初に目指してください。ToDoとして順番に行うとよいでしょう。作業開始前にroot.md、principles.mdを含む作業に必要な資料を読み直してください。その後動作モード確認。プロジェクトのCLAUDE.mdやAGENTS.mdも再読込します。"

# Check if .serena directory exists
if [ -d ".serena" ]; then
    MESSAGE="${BASE_MESSAGE} .serenaディレクトリが存在します。Serenaのアクティベートを行ってください。準備ができてからユーザのリクエストや続きの作業に対応してください。"
else
    MESSAGE="${BASE_MESSAGE} 準備ができてからユーザのリクエストや続きの作業に対応してください。"
fi

echo '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "'"$MESSAGE"'"
  }
}'