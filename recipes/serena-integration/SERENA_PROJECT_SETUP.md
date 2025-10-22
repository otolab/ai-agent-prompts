# プロジェクトにSerenaを導入するレシピ

## 目的
コードベースの解析・編集ツールSerenaをプロジェクトに導入し、Claude Codeでの開発効率を大幅に向上させる

## 前提条件
- Claude Code (Claude Desktop)がインストール済み
- `uv` (Python package manager)がインストール済み
- プロジェクトがGit管理されている（推奨）
- Git（ローカルクローン版を使用する場合）

## 手順

### 1. 初期設定（全プロジェクト共通・初回のみ）

#### 1.1 グローバル設定ファイルの作成・編集
```bash
# 設定ファイルを作成（初回実行時に自動生成される）
uv run serena config edit
```

#### 1.2 ブラウザ自動起動の無効化（任意）
`~/.serena/serena_config.yml` を編集：
```yaml
# ダッシュボード機能は有効のまま、ブラウザ自動起動のみ無効化
web_dashboard: true                  # ダッシュボード機能自体（有効推奨）
web_dashboard_open_on_launch: false  # 起動時の自動ブラウザ起動（無効推奨）
```

**メモ**: ダッシュボードは `http://localhost:24282/dashboard/index.html` で手動アクセス可能

### 2. プロジェクトへの導入

#### 2.1 プロジェクトディレクトリへ移動
```bash
cd /path/to/your/project
```

#### 2.2 Claude Codeへの統合

**方法A: リモートリポジトリから直接実行（簡単）**
```bash
# IDEアシスタントコンテキストで、現在のプロジェクトを自動アクティベート
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server \
  --context ide-assistant \
  --project $(pwd) \
  --enable-web-dashboard true \
  --enable-web-dashboard-open-on-launch false
```

**方法B: ローカルにクローンしたSerenaを使用（推奨・高速）**
```bash
# 1. Serenaをローカルにクローン（初回のみ）
git clone https://github.com/oraios/serena ~/tools/serena

# 2. Claude Codeに追加（クローンしたディレクトリを指定）
claude mcp add serena -- uv run --directory ~/tools/serena \
  serena start-mcp-server \
  --context ide-assistant \
  --project $(pwd) \
  --enable-web-dashboard true \
  --enable-web-dashboard-open-on-launch false
```

**メリット**:
- 方法A: セットアップが簡単、常に最新版
- 方法B: 起動が高速、オフラインでも使用可能、カスタマイズ可能

**オプション説明**:
- `--context ide-assistant`: Claude Code用に最適化された設定
- `--project $(pwd)`: 現在のディレクトリを自動アクティベート（毎回の手動アクティベート不要）
- `--enable-web-dashboard-open-on-launch false`: ブラウザ自動起動を無効化

#### 2.3 大規模プロジェクトの場合（推奨）
```bash
# プロジェクトのインデックスを作成（初回の処理速度が大幅に向上）
uvx --from git+https://github.com/oraios/serena serena project index
```

### 3. プロジェクト固有の設定（任意）

#### 3.1 プロジェクト設定ファイルの確認・編集
`.serena/project.yml` が自動生成されます。必要に応じて編集：

```yaml
# 言語設定（自動検出されるが、必要なら変更）
language: typescript  # python, go, rust, java, php, ruby等

# プロジェクト名（アクティベート時に使用）
project_name: "my-awesome-project"

# 除外設定
ignore_all_files_in_gitignore: true  # .gitignoreを尊重
ignored_paths:                        # 追加の除外パス
  - "build/"
  - "dist/"
  - "*.generated.ts"

# セキュリティ設定
read_only: false  # true にすると読み取り専用モード

# プロジェクト固有の初期プロンプト（任意）
initial_prompt: |
  このプロジェクトは〇〇システムです。
  主要な技術スタック: React, TypeScript, Node.js
  コーディング規約: ESLint設定に従う
```

### 3.5 ローカルSerenaの更新（方法Bを使用している場合）
```bash
# Serenaの更新
cd ~/tools/serena
git pull origin main
```

### 4. 使用方法

#### 4.1 基本的な使い方
Claude Codeで以下のように指示：
- 「このファイルの〇〇関数を修正して」
- 「〇〇クラスの使用箇所を全て確認」
- 「型定義を追加して」

#### 4.2 手動アクティベート（--projectオプション未使用の場合）
```
# 初回
"Activate the project /path/to/project"

# 2回目以降（プロジェクト名で指定可能）
"Activate the project my-awesome-project"
```

#### 4.3 ダッシュボードへのアクセス
ブラウザで以下にアクセス：
- `http://localhost:24282/dashboard/index.html`
- 複数インスタンス起動時: ポート24283, 24284...

## 期待する成果

- **トークン効率の大幅改善**: ファイル全体を読む必要がなくなる
- **精度の向上**: シンボル単位での正確な編集
- **処理速度の向上**: インデックスによる高速検索
- **IDE相当の機能**: リファレンス検索、シンボル検索等

## 注意点・制約

### セッション管理
- 新しいClaude Codeセッションでは再度MCPサーバーが起動される
- `--project`オプション使用時は自動アクティベートされる
- コンテキスト圧縮後も設定は維持される

### パフォーマンス
- 初回実行時は言語サーバーの起動に時間がかかる場合がある
- 大規模プロジェクトではインデックス作成を強く推奨
- `node_modules`等は自動的に除外される

### トラブルシューティング
- **ダッシュボードが開かない**: 手動で `http://localhost:24282/dashboard/index.html` にアクセス
- **プロジェクトが認識されない**: `.serena/project.yml` の存在を確認
- **処理が遅い**: `serena project index` を実行
- **複数インスタンス**: ダッシュボードでプロセス管理可能

## 高度な設定

### 複数プロジェクトの管理
`~/.serena/serena_config.yml` に自動登録される：
```yaml
projects:
  - /path/to/project1
  - /path/to/project2
  - /path/to/project3
```

### カスタムコンテキスト・モード
```bash
# カスタムコンテキストやモードを指定
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena \
  serena start-mcp-server \
  --context custom-context.yaml \
  --mode interactive,editing
```

### Docker経由での実行（実験的）
```bash
docker run --rm -i --network host \
  -v /path/to/projects:/workspaces/projects \
  ghcr.io/oraios/serena:latest \
  serena start-mcp-server --transport stdio
```

## 関連レシピ
- [npm-workspaces-typescript](../npm-workspaces-typescript/setup-guide.md) - モノレポ環境での設定
- [document-code-test](../document-code-test/DOCUMENT_CODE_TEST_SYNC.md) - ドキュメント同期戦略

---

**作成日**: 2025年10月22日
**作成者**: Claude Code Assistant
**バージョン**: 1.0.0

**参考資料**:
- [Serena公式リポジトリ](https://github.com/oraios/serena)
- [Serena README](https://github.com/oraios/serena/blob/main/README.md)
- 調査レポート: `serena-investigation-report` (Serenaメモリ内)