# プラグインリファレンス

> スキーマ、CLIコマンド、コンポーネント仕様を含む、Claude Codeプラグインシステムの完全な技術リファレンス。

<Tip>
  実践的なチュートリアルと実用的な使用方法については、[プラグイン](/ja/docs/claude-code/plugins)を参照してください。チームやコミュニティ全体でのプラグイン管理については、[プラグインマーケットプレイス](/ja/docs/claude-code/plugin-marketplaces)を参照してください。
</Tip>

このリファレンスは、コンポーネントスキーマ、CLIコマンド、開発ツールを含む、Claude Codeプラグインシステムの完全な技術仕様を提供します。

## プラグインコンポーネントリファレンス

このセクションでは、プラグインが提供できる4つのタイプのコンポーネントについて説明します。

### コマンド

プラグインは、Claude Codeのコマンドシステムとシームレスに統合されるカスタムスラッシュコマンドを追加します。

**場所**: プラグインルートの`commands/`ディレクトリ

**ファイル形式**: フロントマターを含むMarkdownファイル

プラグインコマンドの構造、呼び出しパターン、機能の詳細については、[プラグインコマンド](/ja/docs/claude-code/slash-commands#plugin-commands)を参照してください。

### エージェント

プラグインは、適切な場合にClaudeが自動的に呼び出すことができる特定のタスク用の専門サブエージェントを提供できます。

**場所**: プラグインルートの`agents/`ディレクトリ

**ファイル形式**: エージェントの機能を説明するMarkdownファイル

**エージェント構造**:

```markdown  theme={null}
---
description: このエージェントが専門とすること
capabilities: ["task1", "task2", "task3"]
---

# エージェント名

エージェントの役割、専門知識、Claudeがいつそれを呼び出すべきかの詳細な説明。

## 機能
- エージェントが得意とする特定のタスク
- 別の専門的な機能
- このエージェントを他のエージェントと比較していつ使用するか

## コンテキストと例
このエージェントをいつ使用すべきか、どのような種類の問題を解決するかの例を提供します。
```

**統合ポイント**:

* エージェントは`/agents`インターフェースに表示されます
* Claudeはタスクコンテキストに基づいてエージェントを自動的に呼び出すことができます
* エージェントはユーザーが手動で呼び出すことができます
* プラグインエージェントは組み込みのClaudeエージェントと連携して動作します

### フック

プラグインは、Claude Codeイベントに自動的に応答するイベントハンドラーを提供できます。

**場所**: プラグインルートの`hooks/hooks.json`、またはplugin.jsonでのインライン

**形式**: イベントマッチャーとアクションを含むJSON設定

**フック設定**:

```json  theme={null}
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format-code.sh"
          }
        ]
      }
    ]
  }
}
```

**利用可能なイベント**:

* `PreToolUse`: Claudeがツールを使用する前
* `PostToolUse`: Claudeがツールを使用した後
* `UserPromptSubmit`: ユーザーがプロンプトを送信したとき
* `Notification`: Claude Codeが通知を送信するとき
* `Stop`: Claudeが停止を試みるとき
* `SubagentStop`: サブエージェントが停止を試みるとき
* `SessionStart`: セッションの開始時
* `SessionEnd`: セッションの終了時
* `PreCompact`: 会話履歴が圧縮される前

**フックタイプ**:

* `command`: シェルコマンドまたはスクリプトを実行
* `validation`: ファイル内容またはプロジェクト状態を検証
* `notification`: アラートまたはステータス更新を送信

### MCPサーバー

プラグインは、Claude Codeを外部ツールやサービスと接続するためのModel Context Protocol（MCP）サーバーをバンドルできます。

**場所**: プラグインルートの`.mcp.json`、またはplugin.jsonでのインライン

**形式**: 標準MCPサーバー設定

**MCPサーバー設定**:

```json  theme={null}
{
  "mcpServers": {
    "plugin-database": {
      "command": "${CLAUDE_PLUGIN_ROOT}/servers/db-server",
      "args": ["--config", "${CLAUDE_PLUGIN_ROOT}/config.json"],
      "env": {
        "DB_PATH": "${CLAUDE_PLUGIN_ROOT}/data"
      }
    },
    "plugin-api-client": {
      "command": "npx",
      "args": ["@company/mcp-server", "--plugin-mode"],
      "cwd": "${CLAUDE_PLUGIN_ROOT}"
    }
  }
}
```

**統合動作**:

* プラグインMCPサーバーは、プラグインが有効になったときに自動的に開始されます
* サーバーはClaudeのツールキットで標準MCPツールとして表示されます
* サーバー機能はClaudeの既存ツールとシームレスに統合されます
* プラグインサーバーはユーザーMCPサーバーとは独立して設定できます

***

## プラグインマニフェストスキーマ

`plugin.json`ファイルは、プラグインのメタデータと設定を定義します。このセクションでは、サポートされているすべてのフィールドとオプションについて説明します。

### 完全なスキーマ

```json  theme={null}
{
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": {
    "name": "Author Name",
    "email": "author@example.com",
    "url": "https://github.com/author"
  },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/author/plugin",
  "license": "MIT",
  "keywords": ["keyword1", "keyword2"],
  "commands": ["./custom/commands/special.md"],
  "agents": "./custom/agents/",
  "hooks": "./config/hooks.json",
  "mcpServers": "./mcp-config.json"
}
```

### 必須フィールド

| フィールド  | タイプ    | 説明                    | 例                    |
| :----- | :----- | :-------------------- | :------------------- |
| `name` | string | 一意の識別子（ケバブケース、スペースなし） | `"deployment-tools"` |

### メタデータフィールド

| フィールド         | タイプ    | 説明             | 例                                                  |
| :------------ | :----- | :------------- | :------------------------------------------------- |
| `version`     | string | セマンティックバージョン   | `"2.1.0"`                                          |
| `description` | string | プラグインの目的の簡潔な説明 | `"Deployment automation tools"`                    |
| `author`      | object | 作成者情報          | `{"name": "Dev Team", "email": "dev@company.com"}` |
| `homepage`    | string | ドキュメントURL      | `"https://docs.example.com"`                       |
| `repository`  | string | ソースコードURL      | `"https://github.com/user/plugin"`                 |
| `license`     | string | ライセンス識別子       | `"MIT"`, `"Apache-2.0"`                            |
| `keywords`    | array  | 発見タグ           | `["deployment", "ci-cd"]`                          |

### コンポーネントパスフィールド

| フィールド        | タイプ            | 説明                 | 例                                       |
| :----------- | :------------- | :----------------- | :-------------------------------------- |
| `commands`   | string\|array  | 追加のコマンドファイル/ディレクトリ | `"./custom/cmd.md"` または `["./cmd1.md"]` |
| `agents`     | string\|array  | 追加のエージェントファイル      | `"./custom/agents/"`                    |
| `hooks`      | string\|object | フック設定パスまたはインライン設定  | `"./hooks.json"`                        |
| `mcpServers` | string\|object | MCP設定パスまたはインライン設定  | `"./mcp.json"`                          |

### パス動作ルール

**重要**: カスタムパスはデフォルトディレクトリを補完します - 置き換えるものではありません。

* `commands/`が存在する場合、カスタムコマンドパスに加えて読み込まれます
* すべてのパスはプラグインルートからの相対パスで、`./`で始まる必要があります
* カスタムパスからのコマンドは同じ命名と名前空間ルールを使用します
* 柔軟性のために複数のパスを配列として指定できます

**パスの例**:

```json  theme={null}
{
  "commands": [
    "./specialized/deploy.md",
    "./utilities/batch-process.md"
  ],
  "agents": [
    "./custom-agents/reviewer.md",
    "./custom-agents/tester.md"
  ]
}
```

### 環境変数

**`${CLAUDE_PLUGIN_ROOT}`**: プラグインディレクトリの絶対パスが含まれます。インストール場所に関係なく正しいパスを確保するために、フック、MCPサーバー、スクリプトでこれを使用してください。

```json  theme={null}
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/process.sh"
          }
        ]
      }
    ]
  }
}
```

***

## プラグインディレクトリ構造

### 標準プラグインレイアウト

完全なプラグインは次の構造に従います：

```
enterprise-plugin/
├── .claude-plugin/           # メタデータディレクトリ
│   └── plugin.json          # 必須: プラグインマニフェスト
├── commands/                 # デフォルトコマンド場所
│   ├── status.md
│   └──  logs.md
├── agents/                   # デフォルトエージェント場所
│   ├── security-reviewer.md
│   ├── performance-tester.md
│   └── compliance-checker.md
├── hooks/                    # フック設定
│   ├── hooks.json           # メインフック設定
│   └── security-hooks.json  # 追加フック
├── .mcp.json                # MCPサーバー定義
├── scripts/                 # フックとユーティリティスクリプト
│   ├── security-scan.sh
│   ├── format-code.py
│   └── deploy.js
├── LICENSE                  # ライセンスファイル
└── CHANGELOG.md             # バージョン履歴
```

<Warning>
  `.claude-plugin/`ディレクトリには`plugin.json`ファイルが含まれています。他のすべてのディレクトリ（commands/、agents/、hooks/）は、`.claude-plugin/`内ではなく、プラグインルートにある必要があります。
</Warning>

### ファイル場所リファレンス

| コンポーネント     | デフォルト場所                      | 目的                    |
| :---------- | :--------------------------- | :-------------------- |
| **マニフェスト**  | `.claude-plugin/plugin.json` | 必須メタデータファイル           |
| **コマンド**    | `commands/`                  | スラッシュコマンドMarkdownファイル |
| **エージェント**  | `agents/`                    | サブエージェントMarkdownファイル  |
| **フック**     | `hooks/hooks.json`           | フック設定                 |
| **MCPサーバー** | `.mcp.json`                  | MCPサーバー定義             |

***

## デバッグと開発ツール

### デバッグコマンド

`claude --debug`を使用してプラグイン読み込みの詳細を確認します：

```bash  theme={null}
claude --debug
```

これは以下を表示します：

* どのプラグインが読み込まれているか
* プラグインマニフェストのエラー
* コマンド、エージェント、フックの登録
* MCPサーバーの初期化

### 一般的な問題

| 問題            | 原因                         | 解決策                                            |
| :------------ | :------------------------- | :--------------------------------------------- |
| プラグインが読み込まれない | 無効な`plugin.json`           | JSON構文を検証                                      |
| コマンドが表示されない   | 間違ったディレクトリ構造               | `commands/`がルートにあることを確認、`.claude-plugin/`内ではない |
| フックが発火しない     | スクリプトが実行可能でない              | `chmod +x script.sh`を実行                        |
| MCPサーバーが失敗    | `${CLAUDE_PLUGIN_ROOT}`が不足 | すべてのプラグインパスに変数を使用                              |
| パスエラー         | 絶対パスが使用されている               | すべてのパスは相対パスで`./`で始まる必要がある                      |

***

## 配布とバージョニングリファレンス

### バージョン管理

プラグインリリースにはセマンティックバージョニングに従ってください：

```json  theme={null}

## 関連項目

- [プラグイン](/ja/docs/claude-code/plugins) - チュートリアルと実用的な使用方法
- [プラグインマーケットプレイス](/ja/docs/claude-code/plugin-marketplaces) - マーケットプレイスの作成と管理
- [スラッシュコマンド](/ja/docs/claude-code/slash-commands) - コマンド開発の詳細
- [サブエージェント](/ja/docs/claude-code/sub-agents) - エージェント設定と機能
- [フック](/ja/docs/claude-code/hooks) - イベント処理と自動化
- [MCP](/ja/docs/claude-code/mcp) - 外部ツール統合
- [設定](/ja/docs/claude-code/settings) - プラグインの設定オプション
```