# ai-agent-prompts インストールガイド

このドキュメントでは、`otolab`マーケットプレイスからプラグインをインストールする方法を説明します。

## 方法1: GitHubから直接インストール（推奨）

```bash
# 1. Claude Codeを起動
claude

# 2. otolabマーケットプレイスを追加
/plugin marketplace add otolab/ai-agent-prompts

# 3. 必要なプラグインをインストール
/plugin install agent-prompts@otolab  # 基本設定（推奨）
/plugin install recipes@otolab        # 開発レシピ（オプション）
/plugin install snippets@otolab       # スクリプト集（オプション）

# 4. Claude Codeを再起動して有効化
```

## 方法2: ローカルマーケットプレイスとして追加

開発中やカスタマイズ版を使用する場合：

```bash
# 1. Claude Codeを起動
claude

# 2. ローカルマーケットプレイスを追加
/plugin marketplace add /path/to/ai-agent-prompts

# 3. プラグインをインストール
/plugin install agent-prompts@otolab  # 基本設定
/plugin install recipes@otolab        # レシピ（オプション）
/plugin install snippets@otolab       # スクリプト（オプション）

# 4. Claude Codeを再起動
```


## インストール確認

インストール後、以下のコマンドで確認できます：

```bash
# インストールされたプラグインを確認
/plugin

# 利用可能なコマンドを確認
/help

# アドバイザリーコマンドを実行
/advisory
```

## 提供される機能

### agent-prompts プラグイン
- **コマンド**
  - `/advisory` - アドバイザリーモード（前提を疑い、作業の問題点を客観的に発見）
  - `/advisory deep` - Toulminモデルによる詳細な論理検証
- **フック**
  - SessionStart - セッション開始時の初期化処理
  - PostToolUse - Bashコマンド実行後の処理
- **作業指針**
  - 日本語ベースの作業原則
  - 複数の動作モード（オペレータ、技術、Issue追跡など）

### recipes プラグイン
- npm/pnpm workspacesセットアップガイド
- TypeScript環境構築レシピ
- テスト戦略とパターン

### snippets プラグイン
- GitHub操作自動化スクリプト
- CI/CDエラーチェックツール
- 証明書管理ユーティリティ

## トラブルシューティング

### プラグインが表示されない場合

1. マーケットプレイスが正しく追加されているか確認：
   ```bash
   /plugin marketplace list
   ```

2. プラグインの状態を確認：
   ```bash
   /plugin
   ```

3. Claude Codeを完全に再起動：
   - Claude Codeを終了
   - 再度起動

### コマンドが動作しない場合

1. プラグインが有効になっているか確認：
   ```bash
   /plugin enable ai-agent-prompts@otolab-marketplace
   ```

2. コマンドファイルが正しい場所にあるか確認：
   ```bash
   ls commands/
   ```

## アンインストール

プラグインを個別に削除する場合：

```bash
/plugin uninstall agent-prompts@otolab
/plugin uninstall recipes@otolab
/plugin uninstall snippets@otolab
```

マーケットプレイス自体を削除する場合：

```bash
/plugin marketplace remove otolab
```

## 更新

プラグインを更新する場合：

```bash
# 1. 現在のバージョンをアンインストール
/plugin uninstall agent-prompts@otolab

# 2. マーケットプレイスを更新
/plugin marketplace update otolab

# 3. 再インストール
/plugin install agent-prompts@otolab
```

---
**作成**: 2025年10月15日