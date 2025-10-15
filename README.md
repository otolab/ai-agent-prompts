# AI Agent Prompts

Claude Code用のプラグインマーケットプレイス - AI Agent向けのプロンプト・スクリプト・レシピ集

## 概要

Claude Codeのアシスタント動作を制御するプロンプト・設定ファイル、カスタムコマンド、開発レシピ、スクリプト集を提供するマーケットプレイスリポジトリ

## インストール

詳細は[INSTALL.md](INSTALL.md)を参照してください。

### クイックインストール

```bash
# マーケットプレイスを追加
/plugin marketplace add otolab/ai-agent-prompts

# プラグインをインストール（必要なものを選択）
/plugin install agent-prompts@otolab  # 基本設定（推奨）
/plugin install recipes@otolab        # 開発レシピ（オプション）
/plugin install snippets@otolab       # スクリプト集（オプション）
```

## 提供プラグイン

### 1. agent-prompts（基本設定）
- **カスタムコマンド**:
  - `/advisory` - 前提を疑い、作業の問題点を客観的に発見
- **フック**:
  - SessionStart - 自動的にプラグイン内ファイルを読み込み指示
  - PostToolUse - Bashコマンド実行後の処理
- **作業指針**: 日本語ベースの作業原則、動作モード定義
- **動作モード**: オペレータ、技術、Issue追跡、振り返りなど

### 2. recipes（開発レシピ）
- npm/pnpm workspacesのセットアップ
- TypeScript環境構築
- テスト戦略とパターン
- ドキュメント・コード・テストの同期手法

### 3. snippets（スクリプト集）
- GitHub操作スクリプト（Issue管理、CI/CD）
- RedisCloud証明書管理
- 汎用的な自動化ツール

## 構成

```
.
├── .claude-plugin/
│   └── marketplace.json         # マーケットプレイス定義
├── agent-prompts/               # メインプラグイン
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── commands/                # カスタムコマンド
│   │   └── advisory.md
│   ├── hooks/                   # イベントフック
│   │   ├── hooks.json
│   │   ├── start-session.sh
│   │   └── post-tool-use.sh
│   ├── prompts/                 # 基本原則と指針
│   │   ├── root.md
│   │   ├── principles.md
│   │   ├── WORK_GUIDELINES.md
│   │   └── ASSISTANT_MODES.md
│   └── modes/                   # 動作モード定義
│       ├── OPERATOR_SYSTEM.md
│       ├── TECH_NOTES.md
│       ├── ISSUE_TRACKING_MODE.md
│       ├── ADVISORY_MODE.md
│       └── REFLECTION_INSTRUCTIONS.md
├── recipes/                     # 開発レシピプラグイン
│   └── .claude-plugin/
│       └── plugin.json
├── snippets/                    # スクリプト集プラグイン
│   └── .claude-plugin/
│       └── plugin.json
└── hooks -> agent-prompts/hooks  # 互換性のためのシンボリックリンク
```