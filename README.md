# AI Agent Prompts

Claude Code用の個人設定ファイル集

## 概要

Claude Codeのアシスタント動作を制御するプロンプト・設定ファイルを管理するリポジトリ

## 構成

```
.
├── root.md                      # メインエントリーポイント
├── WORK_GUIDELINES.md           # 基本作業フロー・技術環境設定
├── ASSISTANT_MODES.md           # 動作モード定義
├── modes/                       # 各モード仕様ファイル
│   ├── OPERATOR_SYSTEM.md      # オペレータモード
│   ├── TECH_NOTES.md           # コード修正モード
│   ├── ISSUE_TRACKING_MODE.md  # Issue追跡モード
│   ├── KARTE_DEVELOPMENT_MODE.md # KARTE開発モード
│   └── REFLECTION_INSTRUCTIONS.md # 振り返りモード
└── recipes/                     # 開発レシピ・パターン集
```

## 使用方法

`~/.claude/CLAUDE.md`から`root.md`を参照して読み込まれる