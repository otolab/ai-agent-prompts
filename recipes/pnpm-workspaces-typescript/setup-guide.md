# pnpm workspacesとTypeScript Project References設定ガイド

## 概要

このガイドは、pnpm workspacesとTypeScript Project Referencesを正しく連携させ、モノレポ環境でビルドキャッシュが適切に機能するための設定方法を解説します。

## pnpm vs npm workspacesの主な違い

### 利点
- **厳密な依存関係管理**: シンボリックリンクによる効率的な管理
- **ディスク容量の節約**: 重複パッケージの排除
- **高速なインストール**: 並列処理とキャッシュの最適化
- **workspace:*記法のサポート**: より明確な内部パッケージ参照
- **依存順序を考慮した公開**: `pnpm publish -r`で依存関係順に公開

### 注意点
- **厳密なピア依存関係チェック**: 解決できないピア依存関係でエラー
- **Node.jsモジュール解決の厳格性**: 宣言されていない依存関係へのアクセス不可

## 設定手順

### 1. ルートレベルの設定

#### pnpm-workspace.yaml（必須）
```yaml
packages:
  - 'packages/*'
```

**重要**: このファイルがないとpnpm workspacesは機能しません。

#### package.json（ルート）
```json
{
  "name": "my-monorepo",
  "private": true,
  "scripts": {
    "build": "tsc --build",
    "build:all": "pnpm run -r build",
    "clean": "tsc --build --clean",
    "test": "pnpm run -r test",
    "lint": "pnpm run -r lint"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@changesets/cli": "^2.27.0"
  }
}
```

**pnpm特有のポイント**：
- `workspaces`フィールドは不要（pnpm-workspace.yamlを使用）
- `-r`フラグで全ワークスペースでコマンド実行
- `--filter`で特定パッケージを対象に実行可能

#### tsconfig.base.json（ルート）
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,

    // Project References用の必須設定
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "composite": true,
    "incremental": true
  }
}
```

#### tsconfig.json（ルート）
```json
{
  "files": [],
  "include": [],
  "references": [
    { "path": "packages/common" },
    { "path": "packages/core" },
    { "path": "packages/app" }
  ]
}
```

### 2. パッケージレベルの設定

#### ライブラリパッケージ（packages/common）

**package.json**
```json
{
  "name": "@my-org/common",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": ["dist"],
  "scripts": {
    "build": "tsc --build",
    "prepublishOnly": "pnpm build"
  }
}
```

**pnpm特有の追加**：
- `files`フィールドで公開するファイルを明示
- `prepublishOnly`でビルドを保証

**tsconfig.json**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*"],
  "references": []
}
```

#### アプリケーションパッケージ（packages/app）

**package.json**
```json
{
  "name": "@my-org/app",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "dependencies": {
    "@my-org/common": "workspace:*",
    "@my-org/core": "workspace:*"
  },
  "scripts": {
    "build": "tsc --build",
    "start": "node dist/index.js"
  }
}
```

**pnpmの`workspace:*`記法**：
- 内部パッケージへの明確な参照
- 公開時に実際のバージョン番号に自動変換
- npm/yarnとの相互運用性を保証

**tsconfig.json**
```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*"],
  "references": [
    { "path": "../common" },
    { "path": "../core" }
  ]
}
```

## 重要な運用ルール

### インストールとビルド

```bash
# 依存関係のインストール（ルートで実行）
pnpm install

# 開発依存関係を除外してインストール
pnpm install --prod

# ロックファイルから厳密にインストール（CI用）
pnpm install --frozen-lockfile

# 全パッケージのビルド
pnpm build:all

# 特定パッケージのビルド
pnpm --filter @my-org/app build
```

### 依存関係の管理

```bash
# 特定パッケージに依存関係を追加
pnpm add express --filter @my-org/app

# 内部パッケージの依存関係を追加
pnpm add @my-org/common --filter @my-org/app --workspace

# ルートにdevDependenciesを追加
pnpm add -D eslint -w

# 全パッケージの依存関係を更新
pnpm update -r
```

### パッケージ公開

```bash
# changesetの作成
pnpm changeset

# バージョン更新
pnpm changeset version

# 依存順序を考慮した公開
pnpm publish -r --no-git-checks
```

## CI/CD設定

### GitHub Actions設定例

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup pnpm
        uses: pnpm/action-setup@v4
        with:
          version: 9

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build packages
        run: pnpm build:all

      - name: Run tests
        run: pnpm test
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. peer dependenciesエラー

**問題**：
```
 ERR_PNPM_PEER_DEP_ISSUES  Unmet peer dependencies
```

**解決**：
```bash
# .npmrcに追加
echo "auto-install-peers=true" >> .npmrc

# または明示的にインストール
pnpm add react --filter @my-org/app
```

#### 2. workspace:*が解決されない

**問題**：
```
Cannot find module '@my-org/common'
```

**解決**：
1. pnpm-workspace.yamlが存在することを確認
2. ルートで`pnpm install`を実行
3. node_modules/.pnpmにシンボリックリンクが作成されているか確認

#### 3. ビルドキャッシュが効かない

**問題**：
TypeScriptが毎回全ファイルを再コンパイル

**解決**：
```bash
# キャッシュをクリア
pnpm exec tsc --build --clean

# tsconfig.jsonの依存関係を確認
# package.jsonとtsconfig.jsonのreferencesが一致しているか確認
```

#### 4. CI環境でのインストール失敗

**問題**：
```
ENOENT: no such file or directory, open 'pnpm-lock.yaml'
```

**解決**：
- pnpm-lock.yamlをgitignoreしない
- `--frozen-lockfile`フラグを使用

#### 5. npm公開時のworkspace:*エラー

**問題**：
```
npm ERR! Invalid version: "workspace:*"
```

**解決**：
`pnpm publish`を使用（自動的にバージョンに変換される）

### 移行時の注意点

#### npmからの移行
```bash
# 1. 既存のnode_modulesとpackage-lock.jsonを削除
rm -rf node_modules package-lock.json
rm -rf packages/*/node_modules

# 2. pnpm-workspace.yamlを作成
echo "packages:\n  - 'packages/*'" > pnpm-workspace.yaml

# 3. workspace:*記法に変換
# package.jsonで "^1.0.0" → "workspace:*" に変更

# 4. pnpmでインストール
pnpm install

# 5. .gitignoreを更新
echo "pnpm-lock.yaml" >> .gitignore  # 削除（コミットする）
```

#### CI/CDワークフローの更新
- `npm ci` → `pnpm install --frozen-lockfile`
- `npm run` → `pnpm run`
- `npm install -g` → `pnpm add -g`
- キャッシュキーを`package-lock.json` → `pnpm-lock.yaml`に変更

## ベストプラクティス

### 1. ルートpackage.jsonの整理
```json
{
  "private": true,
  "scripts": {
    "build": "tsc --build",
    "build:all": "pnpm run -r build",
    "test": "pnpm run -r test",
    "lint": "pnpm run -r lint",
    "changeset": "changeset",
    "changeset:version": "changeset version",
    "changeset:publish": "pnpm publish -r --no-git-checks"
  },
  "devDependencies": {
    // 全パッケージ共通の開発ツールのみ
  }
}
```

### 2. パッケージレベルのスクリプト
```json
{
  "scripts": {
    "build": "tsc --build",
    "test": "vitest",
    "lint": "eslint src",
    "prepublishOnly": "pnpm build"
  }
}
```

### 3. 依存関係の階層化
- ルート: 開発ツール（TypeScript, ESLint, Vitest等）
- パッケージ: 実行時依存関係のみ
- workspace:*で内部依存関係を明示

### 4. .npmrcの設定
```ini
# pnpm特有の設定
shamefully-hoist=false
auto-install-peers=true
strict-peer-dependencies=false

# パフォーマンス設定
package-import-method=copy
prefer-frozen-lockfile=true
```

## まとめ

pnpm workspacesとTypeScript Project Referencesの連携において重要なポイント：

1. **pnpm-workspace.yamlが必須**
2. **workspace:*記法で内部パッケージを明確に参照**
3. **pnpm publish -rで依存順序を考慮した公開**
4. **--frozen-lockfileでCI環境での再現性を保証**
5. **prepublishOnlyスクリプトでビルドを保証**

これらの設定により、高速で信頼性の高いモノレポ環境を構築できます。