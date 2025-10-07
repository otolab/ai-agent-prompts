# pnpm workspaces × TypeScript × Changeset設定ガイド

モノレポ環境での最適な技術スタック構成について解説しています。

## 技術スタックの組み合わせ

### pnpm × TypeScript × Changeset
この3つの組み合わせにより、以下を実現します：

- **pnpm workspaces**: 高速で効率的なパッケージ管理
- **TypeScript Project References**: インクリメンタルビルドとキャッシュ最適化
- **Changeset**: セマンティックバージョニングと自動リリース

### なぜこの組み合わせか

#### 1. 開発効率の向上
- pnpmの高速インストール（npm比2-3倍）
- TypeScriptのインクリメンタルビルド
- Changesetによる自動バージョン管理

#### 2. 信頼性の確保
- pnpmの厳密な依存関係管理
- TypeScriptの型安全性
- Changesetによるリリース履歴の追跡

#### 3. npm公開の安全性
- pnpmの`workspace:*`記法で内部依存を明確化
- `pnpm publish -r`で依存順序を考慮した公開
- Changesetでバージョン衝突を防止

### クイックスタート

```bash
# pnpmのインストール
npm install -g pnpm

# プロジェクトの初期化
pnpm init
echo "packages:\n  - 'packages/*'" > pnpm-workspace.yaml

# TypeScriptとChangesetのセットアップ
pnpm add -D typescript @changesets/cli -w
pnpm changeset init

# 基本スクリプトの設定
npm pkg set scripts.build="tsc --build"
npm pkg set scripts.changeset="changeset"
npm pkg set scripts.version="changeset version"
npm pkg set scripts.publish="pnpm publish -r --no-git-checks"
```

### 典型的なプロジェクト構造

```
my-monorepo/
├── pnpm-workspace.yaml     # pnpm workspace設定
├── tsconfig.json           # TypeScript Project References
├── .changeset/
│   └── config.json        # Changeset設定
├── packages/
│   ├── common/
│   │   ├── package.json   # "name": "@my-org/common"
│   │   └── tsconfig.json
│   └── app/
│       ├── package.json   # "dependencies": {"@my-org/common": "workspace:*"}
│       └── tsconfig.json  # "references": [{"path": "../common"}]
└── package.json           # "private": true
```

## 詳細ドキュメント

- @setup-guide.md - 基本設定と構築手順
- @migration-guide.md - npmからpnpmへの移行ガイド
- @publishing-guide.md - パッケージ公開とリリースフロー

## よくある質問

### Q: npmやyarnからの移行は難しい？
A: `migration-guide.md`に段階的な移行手順があります。workspace記法の変換が主な作業です。

### Q: Changesetは必須？
A: 必須ではありませんが、複数パッケージのバージョン管理が格段に楽になります。

### Q: TypeScript Project Referencesの設定は複雑？
A: package.jsonの依存関係とtsconfig.jsonのreferencesを同期させるだけです。

## 実装例

このレシピを実際に適用したプロジェクト：
- [coeiro-operator](https://github.com/otolab/coeiro-operator) - 音声合成オペレータシステム

## トラブルシューティングのヒント

- **npm公開が失敗**: `workspace:*`が残っていないか確認
- **ビルドが遅い**: tsconfig.jsonのreferencesが正しいか確認
- **changesetがない警告**: PR作成前に`pnpm changeset`を実行