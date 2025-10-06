#!/bin/bash

echo '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "作業開始前にroot.mdを含む作業に必要な資料を読み直してください。その後動作モード確認。プロジェクトのCLAUDE.mdやAGENTS.mdも再読込します。準備ができてからユーザのリクエストや続きの作業に対応してください。"
  }
}'