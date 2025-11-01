# search-docs プラグイン

Claude Codeから直接search-docsを利用するためのMCPサーバープラグインです。

## 概要

このプラグインは、`@search-docs/mcp-server`を提供し、Claude Codeとsearch-docsサーバを接続して、会話から直接ドキュメント検索を実行できるようにします。

## 提供機能

### MCPツール

#### 1. `mcp__plugin_search-docs_search-docs__search`
文書をベクトル検索します。

**パラメータ**:
- `query` (string, 必須): 検索クエリ
- `depth` (number | number[], オプション): 検索深度（0-3）
- `limit` (number, オプション): 結果数制限（デフォルト: 10）
- `includeCleanOnly` (boolean, オプション): Clean状態のみ検索

**使用例**:
```
query: "Vector検索の実装方法"
depth: 1
limit: 5
```

#### 2. `mcp__plugin_search-docs_search-docs__get_document`
文書の内容を取得します。

**パラメータ**:
- `path` (string, 必須): 文書パス

**使用例**:
```
path: "docs/architecture.md"
```

#### 3. `mcp__plugin_search-docs_search-docs__index_status`
インデックスの状態を確認します。

**パラメータ**: なし

## セットアップ

### 前提条件

- Node.js 18.0.0以上
- search-docsサーバがインストールされていること（MCPサーバーが自動起動します）

### インストール

このプラグインは、otolab AIエージェントプラグインマーケットプレイスの一部として提供されています。

プロジェクトのルートディレクトリで以下を実行：

```bash
# プラグインマーケットプレイスを有効化
# （既にotolabマーケットプレイスを追加済みの場合は不要）
```

### 自動起動機能

v1.0.1以降、MCP Serverは自動的にsearch-docsサーバを起動します。

**動作**:
1. MCP Server起動時にサーバへの接続を試みる
2. サーバが起動していない場合、自動的にサーバを起動
3. サーバが起動したら接続を確立

これにより、手動でサーバを起動する必要がなくなりました。

## 使用方法

### 基本的な検索

Claude Codeで以下のように指示します：

```
"Vector検索について調べてください"
```

アシスタントが自動的に`search`ツールを使用して検索を実行します。

### ドキュメント取得

```
"docs/architecture.mdの内容を表示してください"
```

アシスタントが`get_document`ツールを使用してドキュメントを取得します。

### インデックス状態確認

```
"search-docsのインデックス状態を確認してください"
```

アシスタントが`index_status`ツールを使用して状態を確認します。

## 設定

### プロジェクト設定

各プロジェクトのルートディレクトリに`.search-docs.json`を配置することで、search-docsサーバの設定をカスタマイズできます。

`.search-docs.json`が存在しない場合は、デフォルト設定（`localhost:24280`）を使用します。

### MCP設定

このプラグインの`.mcp.json`：

```json
{
  "mcpServers": {
    "search-docs": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@search-docs/mcp-server"
      ]
    }
  }
}
```

## トラブルシューティング

### サーバに接続できない

**エラー**: `Failed to connect to search-docs server`

**通常は不要**: MCP Serverはサーバを自動起動します。

**手動で確認する場合**:

```bash
# search-docs CLIをインストール
npx -y @search-docs/cli server status

# 必要に応じて手動起動
npx -y @search-docs/cli server start
```

### 設定ファイルが見つからない

MCP Serverはプロジェクトディレクトリの`.search-docs.json`を読み込みます。

ファイルが存在しない場合はデフォルト設定を使用します（問題ありません）。

## 関連リンク

- npmパッケージ: [@search-docs/mcp-server](https://www.npmjs.com/package/@search-docs/mcp-server)
- 関連パッケージ:
  - `@search-docs/client`: JSON-RPCクライアント
  - `@search-docs/server`: 検索サーバ
  - `@search-docs/cli`: CLIツール

## バージョン

現在のバージョン: 1.0.14

## ライセンス

MIT
