# Mode Controller MCP Server

AIアシスタントの動作モードを管理・制御するMCPサーバーです。

## 概要

Mode Controllerは、AIアシスタントの動作モードをMarkdownファイルで定義し、MCPツールを通じて動的に切り替えることができるサーバーです。YAMLフロントマターによるメタデータ定義をサポートし、柔軟なモード管理を実現します。

## 機能

- **複数モード同時管理**: 複数のモードを同時にアクティブ化可能
- **モードの動的切り替え**: mode_enter/mode_exitツールでモードを切り替え
- **YAMLフロントマターサポート**: モードのメタデータ（表示名、自動トリガー条件、終了メッセージ、fullContent等）を定義
- **fullContent機能**: mode_enterでファイル内容を直接出力（`fullContent: true`）
- **@参照の自動解決**: モード定義内の`@`参照を再帰的に読み込んで結合
- **モード一覧表示**: 利用可能なモードと詳細情報の表示
- **状態管理**: 複数のアクティブモードの状態を管理・表示

## インストール

### npmパッケージから（推奨）

```bash
# npxで自動インストール＆実行（MCP設定で使用）
npx -y @otolab/mcp-mode-controller --modes-path /path/to/modes
```

### ソースからビルド

```bash
# 依存関係のインストール
npm install

# ビルド
npm run build
```

## 使用方法

### MCP設定

Claude Codeプラグインの `.mcp.json` に以下の設定を追加：

#### npxを使用（推奨）

```json
{
  "mcpServers": {
    "mode-controller": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@otolab/mcp-mode-controller",
        "--modes-path",
        "${CLAUDE_PLUGIN_ROOT}/prompts/modes,${CLAUDE_PLUGIN_ROOT}/../products"
      ]
    }
  }
}
```

**注意**: `--modes-path`は**必須**パラメータです。カンマ区切りで複数のディレクトリを指定できます。

#### ローカルビルドを使用

```json
{
  "mcpServers": {
    "mode-controller": {
      "type": "stdio",
      "command": "node",
      "args": [
        "${CLAUDE_PLUGIN_ROOT}/mcps/mode-controller/dist/server.js",
        "--modes-path",
        "${CLAUDE_PLUGIN_ROOT}/prompts/modes"
      ]
    }
  }
}
```

### モードファイルの作成

モードファイルは`--modes-path`で指定したディレクトリに配置します。サブディレクトリも再帰的に探索されます。

#### YAMLフロントマター付きモード

```markdown
---
mode: specification_research
displayName: 仕様調査モード
autoTrigger:
  - 仕様理解が必要な時
  - 作業前調査
  - API仕様確認
exitMessage: |
  調査結果に基づいて次の作業を進めてください。
  必要に応じて追加調査を検討してください。
---

# 仕様調査モード

## 目的
プロジェクトの仕様や実装を深く理解するための調査モード

## 実行内容
- ドキュメントの体系的な読み込み
- コードベースの構造理解
- API仕様の確認
```

#### fullContent機能を使用したモード

```markdown
---
mode: env_setup
displayName: 環境セットアップモード
fullContent: true  # mode_enterでファイル内容を直接出力
exitMessage: 環境セットアップが完了しました。
---

# 環境セットアップモード

セッション開始時・コンテキスト圧縮後の環境再構築を行うモードです。

@principles.md
@work_guidelines.md
@../../snippets/README.md

（@で始まる行は参照ファイルとして自動的に読み込まれ、結合されます）
```

#### シンプルなモード（メタデータなし）

```markdown
# 基本モード

このモードは基本的な作業を行うためのモードです。
メタデータがない場合、ファイル名がモード名として使用されます。
```

## MCPツール

### mode_enter

モードを開始します（複数同時指定可能）。

**動作**:
- `fullContent: false`（デフォルト）: モード定義ファイルの読み込み指示を返す
- `fullContent: true`: ファイル内容を直接出力（@参照も自動解決）

```typescript
// 引数
{
  modes: string | string[]  // モード名（文字列または配列）
}

// 使用例
mode_enter({ modes: "specification_research" })                      // 単一モード
mode_enter({ modes: ["specification_research", "tech_notes"] })      // 複数モード同時開始
mode_enter({ modes: "env_setup" })                                   // fullContent: true のモード

// 出力例（fullContent: false）
【仕様調査モード開始】

以下のモード定義に従って動作してください：

ファイル: /path/to/prompts/modes/SPECIFICATION_RESEARCH_MODE.md

※このファイルを読み込んで内容を確認してください

// 出力例（fullContent: true）
【環境セットアップモード開始】

============================================================
ファイル: /path/to/prompts/modes/ENV_SETUP_MODE.md
============================================================

# 環境セットアップモード

セッション開始時・コンテキスト圧縮後の環境再構築を行うモードです。

（モードの内容がここに直接展開される）

============================================================
ファイル: /path/to/prompts/principles.md
============================================================

（@参照で指定されたファイルの内容も自動的に結合される）
```

**fullContent: false の利点**:
- トークン効率: 会話履歴に全文ではなくパス情報のみが残る
- 確実性: Readツールによる明示的なファイル読み込み
- 柔軟性: ファイル更新が即座に反映される

**fullContent: true の利点**:
- 確実性重視: mode_enter実行だけで全内容が読み込まれる
- @参照の自動解決: 関連ファイルを自動的に結合（フルパス表示で明確）
- セットアップ用途: 環境構築時など確実に読み込みたい場合に最適
- ファイルパス表示: すべてのファイルのフルパスが明示される

### mode_exit

アクティブなモードを終了します（複数同時指定可能）。

```typescript
// 引数
{
  modes?: string | string[]  // 終了するモード名（省略時は全モード終了）
}

// 使用例
mode_exit({})                                          // 全アクティブモードを終了
mode_exit({ modes: "specification_research" })              // 特定のモードを終了
mode_exit({ modes: ["specification_research", "tech_notes"] })  // 複数モードを同時終了
```

### mode_show

モードの内容を表示します。モードの指示内容を確認したい時や、コンテキスト圧縮後にモード内容を再確認する時に使用します。

**動作**: モード定義の全文とファイルパスを返します。

**重要**: モード名が指定された場合、アクティブ状態に関係なくそのモードの内容を表示します。

```typescript
// 引数
{
  mode?: string  // 表示するモード名（省略時は全アクティブモード）
}

// 使用例
mode_show({})                         // 全アクティブモードの内容を表示
mode_show({ mode: "specification_research" })  // 特定のモードの内容を表示（非アクティブでも可）

// 出力例（アクティブなモード）
【仕様調査モード（現在アクティブ）】

ファイル: /path/to/prompts/modes/SPECIFICATION_RESEARCH_MODE.md

# 仕様調査モード
...（モード内容）

// 出力例（非アクティブなモード）
【技術メモモード（非アクティブ）】

ファイル: /path/to/prompts/modes/TECH_NOTES.md

# 技術メモモード
...（モード内容）

// 出力例（複数モード）
【仕様調査モード（現在アクティブ）】

ファイル: /path/to/prompts/modes/SPECIFICATION_RESEARCH_MODE.md

# 仕様調査モード
...（モード内容）

────────────────────────────────────────

【コード修正モード（現在アクティブ）】

ファイル: /path/to/prompts/modes/CODE_REVIEW_MODE.md

# コード修正モード
...（モード内容）
```

**用途**:
- モード内容の再確認
- コンテキスト圧縮後の復元
- デバッグ・トラブルシューティング

### mode_status

現在のモード状態を確認します。

```typescript
// 引数なし
mode_status({})

// 出力例（単一モード）
📊 モード状態

アクティブなモード (1個):
  🟢 仕様調査モード (specification_research)

// 出力例（複数モード）
📊 モード状態

アクティブなモード (2個):
  🟢 仕様調査モード (specification_research)
  🟢 コード修正モード (tech_notes)

// 出力例（モード未設定）
📊 モード状態

現在のモード: なし
状態: ⭕ 待機中
```

### mode_list

利用可能なモード一覧を表示します。

```typescript
// 引数なし
mode_list({})
```

## 複数モード同時実行

Mode Controllerは複数のモードを同時にアクティブ化できます。これにより、異なる側面の指示を組み合わせて作業を進めることが可能です。

### 使用例

```javascript
// 複数モードを同時に開始
mode_enter({ modes: ["specification_research", "tech_notes"] })

// 現在のステータスを確認
mode_status()
// → アクティブなモード (2個)

// 特定のモードの内容だけを確認
mode_show({ mode: "specification_research" })

// 特定のモードだけを終了
mode_exit({ modes: "specification_research" })

// 残りのモードも終了
mode_exit()
```

### 利点

- **柔軟な作業スタイル**: 調査モードとコード修正モードを同時に有効化
- **段階的な管理**: 必要に応じてモードを追加・削除
- **明確な状態把握**: どのモードがアクティブか常に確認可能

## 開発

### テスト

```bash
# テストの実行
npm test

# ウォッチモードでテスト
npm run test:watch

# カバレッジレポート生成
npm run test:coverage
```

### ビルド

```bash
# TypeScriptのビルド
npm run build

# ウォッチモードでビルド
npm run dev
```

## ディレクトリ構造

```
mode-controller/
├── src/
│   └── server.ts         # MCPサーバー実装
├── test/
│   └── mode-controller.test.ts  # E2Eテスト
├── test-modes/           # テスト用モードファイル
│   ├── test_mode_with_metadata.md
│   └── test_mode_without_metadata.md
├── dist/                 # ビルド出力
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

## 技術仕様

- **MCP SDK**: `@modelcontextprotocol/sdk ^1.17.0`
- **YAMLパーサー**: `js-yaml ^4.1.0`
- **スキーマ検証**: `zod ^3.22.0`
- **テスト**: `vitest ^3.2.4` + `@coeiro-operator/mcp-debug`

## メタデータスキーマ

YAMLフロントマターで定義可能なフィールド：

| フィールド | 型 | 説明 |
|----------|---|------|
| mode | string | モードID（省略時はファイル名を使用） |
| displayName | string | 表示名 |
| autoTrigger | string[] | 自動起動条件のリスト |
| exitMessage | string | モード終了時のメッセージ |

## ライセンス

プロジェクトのライセンスに準拠