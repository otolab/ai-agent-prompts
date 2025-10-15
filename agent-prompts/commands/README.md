# Claude Code カスタムコマンド集

このディレクトリには、Claude Code用のカスタムコマンド定義を管理しています。

## 利用可能なコマンド

### `/advisory` - アドバイザリーモード
前提を疑い、作業の問題点を客観的に発見するコマンド。
- 基本: `/advisory` - 基本的な前提チェック
- 詳細: `/advisory deep` - Toulminモデルによる論理検証を含む

## セットアップ方法

このリポジトリはClaude Codeプラグインとして構成されています。

### プラグインとしてインストール
```bash
# Claude Codeのプラグインディレクトリにクローンまたはリンク
ln -sfn $(pwd) ~/.claude/plugins/ai-agent-prompts

# または直接クローン
git clone https://github.com/otolab/ai-agent-prompts ~/.claude/plugins/ai-agent-prompts
```

### レガシー方法（プラグイン非対応環境）
```bash
# コマンドディレクトリへのシンボリックリンク
ln -sfn $(pwd)/commands ~/.claude/commands
```

## コマンドの追加方法
1. `commands/` ディレクトリに新しい `.md` ファイルを作成
2. コマンドの実行内容を記述
3. `.claude/commands/` にリンクまたはコピー
4. このREADMEに説明を追加

---
**作成**: 2025年10月15日