# Hooks - Claude Codeフック集

Claude Codeのセッションやツール実行時に自動的に実行されるフックスクリプト集です。

## 利用可能なフック

### start-session.js
**イベント**: SessionStart
**目的**: セッション開始時に動作モードの設定を促す

セッション開始時にmode_listの実行と適切なモードの有効化を促します。
セッションのソースタイプ（startup/resume/clear/compact）に応じて適切な指示を提供します。
これにより、コンテキストリセット後も一貫した作業スタイルを維持できます。

### post-tool-use.sh
**イベント**: PostToolUse (Bashツール限定)
**目的**: cdコマンド実行後の現在ディレクトリをコンテキストに追加

Bashツールで`cd`コマンドが実行された際に、移動後の現在ディレクトリを`[cwd: /path/to/dir]`形式で
コンテキストに追加します。これにより、ディレクトリ移動の追跡が容易になります。

## フックの仕組み

### 実行フロー
1. Claude Codeが特定のイベント（SessionStart、PostToolUse等）を検出
2. `~/.claude/settings.json`のmatcherパターンに一致するか確認
3. 一致した場合、指定されたコマンドを実行
4. フックスクリプトがJSON形式で追加コンテキストを出力
5. Claude Codeがコンテキストを会話に追加

### JSON出力形式
```json
{
  "hookSpecificOutput": {
    "hookEventName": "EventName",
    "additionalContext": "追加するテキスト"
  }
}
```

## 新規フックの作成方法

### 1. スクリプトの作成
```bash
cat > hooks/my-hook.sh << 'EOF'
#!/bin/bash
echo '{
  "hookSpecificOutput": {
    "hookEventName": "MyEvent",
    "additionalContext": "カスタムメッセージ"
  }
}'
EOF
```

### 2. 実行権限の付与
```bash
chmod +x hooks/my-hook.sh
```

### 3. settings.jsonへの登録
```json
"EventName": [
  {
    "matcher": "パターン",
    "hooks": [
      {
        "type": "command",
        "command": "~/Develop/otolab/ai-agent-prompts/hooks/my-hook.sh"
      }
    ]
  }
]
```

## 環境変数

フックスクリプト内で利用可能な環境変数（イベントによって異なる）：

### PostToolUse
- `CLAUDE_CODE_TOOL_NAME` - 実行されたツール名（例: "Bash", "Read", "Write"）
- `CLAUDE_CODE_TOOL_PARAMS` - ツールパラメータ（JSON文字列）
- `CLAUDE_CODE_TOOL_RESULT` - ツール実行結果（利用可能な場合）

## デバッグ方法

### ログファイルへの出力
```bash
#!/bin/bash
# デバッグ情報をログファイルに記録
echo "$(date): Hook executed" >> /tmp/hook-debug.log
echo "Tool: $CLAUDE_CODE_TOOL_NAME" >> /tmp/hook-debug.log
```

### 環境変数の確認
```bash
#!/bin/bash
# すべての環境変数を記録
env > /tmp/hook-env.txt
```

## ベストプラクティス

1. **軽量に保つ**: フックの実行時間を最小限に
2. **エラーハンドリング**: 失敗してもセッションを妨げない
3. **条件分岐**: 必要な場合のみ出力を生成
4. **ログ記録**: デバッグ用のログは別ファイルに

## 注意事項

- フックスクリプトの出力はJSON形式である必要があります
- 不正なJSON出力はエラーになる可能性があります
- matcherパターンは正確に設定してください
- 設定変更後はClaude Codeの再起動が必要です

---
**作成**: 2025年10月6日