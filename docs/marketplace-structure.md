# マーケットプレイス構造ドキュメント

## 正しいマーケットプレイス構造

Claude Codeのプラグインマーケットプレイスは、以下の構造を持つ必要があります：

```
marketplace-repo/                    # マーケットプレイスリポジトリ
├── .claude-plugin/
│   └── marketplace.json            # マーケットプレイス定義
├── plugin-1/                       # プラグインディレクトリ
│   ├── .claude-plugin/
│   │   └── plugin.json            # プラグインマニフェスト
│   ├── commands/                  # コマンド
│   ├── hooks/                     # フック
│   └── ...
└── plugin-2/                       # 別のプラグイン
    └── ...
```

## ai-agent-promptsの構造変更案

### 現在の構造（誤り）
```
ai-agent-prompts/                   # プラグインとして構成
├── .claude-plugin/
│   ├── plugin.json                # プラグインマニフェスト
│   └── marketplace.json            # マーケットプレイス定義（混在）
├── commands/
├── hooks/
└── ...
```

### 正しい構造（推奨）
```
ai-agent-prompts/                   # マーケットプレイスとして構成
├── .claude-plugin/
│   └── marketplace.json            # マーケットプレイス定義のみ
└── personal-settings/              # プラグインディレクトリ
    ├── .claude-plugin/
    │   └── plugin.json            # プラグインマニフェスト
    ├── commands/                  # コマンド
    │   └── advisory.md
    ├── hooks/                     # フック
    │   ├── hooks.json
    │   ├── start-session.sh
    │   └── post-tool-use.sh
    ├── docs/                      # ドキュメント（参照用）
    │   ├── root.md
    │   ├── principles.md
    │   └── WORK_GUIDELINES.md
    └── modes/                     # モード定義
        └── ...
```

## 移行手順

### 1. ディレクトリ構造の再編成

```bash
# プラグインディレクトリを作成
mkdir personal-settings
mkdir personal-settings/.claude-plugin

# プラグインマニフェストを移動
mv .claude-plugin/plugin.json personal-settings/.claude-plugin/

# コンポーネントを移動
mv commands personal-settings/
mv hooks personal-settings/
mv modes personal-settings/
mv principles.md personal-settings/docs/
mv root.md personal-settings/docs/
mv WORK_GUIDELINES.md personal-settings/docs/
```

### 2. マーケットプレイス定義の更新

`.claude-plugin/marketplace.json`:
```json
{
  "name": "otolab",
  "owner": {
    "name": "otolab"
  },
  "plugins": [
    {
      "name": "personal-settings",
      "source": "./personal-settings",
      "description": "AI Agent個人作業指針とカスタムコマンド集",
      "version": "1.0.0",
      "author": {
        "name": "otolab"
      },
      "keywords": [
        "ai-agent",
        "claude-code",
        "japanese",
        "guidelines"
      ]
    }
  ]
}
```

### 3. プラグインマニフェストの調整

`personal-settings/.claude-plugin/plugin.json`:
```json
{
  "name": "personal-settings",
  "version": "1.0.0",
  "description": "AI Agent個人作業指針とカスタムコマンド集",
  "author": {
    "name": "otolab"
  },
  "homepage": "https://github.com/otolab/ai-agent-prompts",
  "repository": "https://github.com/otolab/ai-agent-prompts",
  "license": "MIT",
  "keywords": [
    "ai-agent",
    "claude-code",
    "prompts",
    "guidelines",
    "japanese"
  ],
  "hooks": "./hooks/hooks.json"
}
```

## インストール方法

### GitHubから（公開後）
```bash
# マーケットプレイスを追加
/plugin marketplace add otolab/ai-agent-prompts

# プラグインをインストール
/plugin install personal-settings@otolab
```

### ローカルから
```bash
# マーケットプレイスを追加
/plugin marketplace add /path/to/ai-agent-prompts

# プラグインをインストール
/plugin install personal-settings@otolab
```

## 利点

1. **標準準拠**: Claude Codeのマーケットプレイス仕様に完全準拠
2. **拡張性**: 同じマーケットプレイスに複数のプラグインを追加可能
3. **配布性**: GitHubでの公開により`otolab/ai-agent-prompts`として簡単にアクセス可能
4. **管理性**: マーケットプレイスとプラグインの責任分離が明確

## 今後の拡張例

```
ai-agent-prompts/                   # otolabマーケットプレイス
├── .claude-plugin/
│   └── marketplace.json
├── personal-settings/              # 個人設定プラグイン
├── japanese-commands/              # 日本語コマンド集プラグイン
├── development-tools/              # 開発ツールプラグイン
└── team-guidelines/                # チームガイドラインプラグイン
```

---
**作成**: 2025年10月15日