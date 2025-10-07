# AI Agent Prompts セットアップガイド

このリポジトリを使用してClaude Codeをカスタマイズするための設定方法を説明します。

## 基本設定

### 1. リポジトリのクローン

```bash
git clone https://github.com/[your-username]/ai-agent-prompts.git ~/Develop/otolab/ai-agent-prompts
```

### 2. Claude Code設定ファイルの編集

`~/.claude/settings.json`を編集して、必要なフックを設定します。

#### 基本的な設定例

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "~/Develop/otolab/ai-agent-prompts/hooks/start-session.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/Develop/otolab/ai-agent-prompts/hooks/post-tool-use.sh"
          }
        ]
      }
    ]
  }
}
```

## フック機能

### 利用可能なフック

#### SessionStart
- **目的**: セッション開始時にroot.mdや作業指針を自動的に読み込む
- **ファイル**: `hooks/start-session.sh`
- **matcher**: `".*"` (すべてのセッション)

#### PostToolUse
- **目的**: Bashツールでcdコマンド実行後に現在のディレクトリをコンテキストに追加
- **ファイル**: `hooks/post-tool-use.sh`
- **matcher**: `"Bash"` (Bashツールのみ)
- **出力形式**: `[cwd: /path/to/dir]`

### フックの追加方法

1. `hooks/`ディレクトリに新しいシェルスクリプトを作成
2. 実行権限を付与: `chmod +x hooks/your-hook.sh`
3. `~/.claude/settings.json`にフック設定を追加
4. Claude Codeを再起動して設定を反映

### フックスクリプトの作成規約

フックスクリプトは以下の形式でJSONを出力する必要があります：

```bash
#!/bin/bash
echo '{
  "hookSpecificOutput": {
    "hookEventName": "YourEventName",
    "additionalContext": "追加するコンテキスト情報"
  }
}'
```

## カスタマイズ

### 作業指針の編集

個人の作業スタイルに合わせて以下のファイルを編集できます：

- `root.md` - 基本原則とエントリーポイント
- `principles.md` - 作業原則の詳細
- `WORK_GUIDELINES.md` - 具体的な作業ガイドライン
- `ASSISTANT_MODES.md` - 動作モードの定義

### スニペットの追加

`snippets/`ディレクトリに再利用可能なスクリプトを配置できます。
詳細は`snippets/CONTRIBUTING.md`を参照してください。

## トラブルシューティング

### フックが動作しない場合

1. **権限の確認**: スクリプトに実行権限があるか確認
   ```bash
   ls -la hooks/
   ```

2. **パスの確認**: `~/.claude/settings.json`のパスが正しいか確認

3. **再起動**: Claude Codeを再起動して設定を反映

4. **ログの確認**: フックスクリプト内でデバッグ出力を追加
   ```bash
   echo "Debug: Hook executed" >> /tmp/hook-debug.log
   ```

### 環境変数

フックスクリプト内で利用可能な環境変数（PostToolUseの場合）：
- `CLAUDE_CODE_TOOL_NAME` - 実行されたツール名
- `CLAUDE_CODE_TOOL_PARAMS` - ツールのパラメータ（JSON形式）

## 注意事項

- フックの設定変更後はClaude Codeの再起動が必要です
- matcherはツール名や条件に応じて適切に設定してください
- フックスクリプトは軽量に保ち、実行時間を最小限にしてください

---
**作成**: 2025年10月6日