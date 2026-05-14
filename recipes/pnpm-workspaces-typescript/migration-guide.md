# npmからpnpmへの移行ガイド

## 移行の動機

### なぜpnpmを選ぶか
- **パフォーマンス**: インストール速度が2-3倍高速
- **ディスク容量**: 重複排除により50-70%削減
- **信頼性**: 厳密な依存関係管理で「動作するはずなのに動かない」を防止
- **モノレポ対応**: workspace機能が標準搭載

### 移行タイミングの判断
以下の場合は移行を推奨：
- モノレポでパッケージ間の依存関係が複雑
- CI/CDのインストール時間を短縮したい
- npm公開時のレースコンディションに悩んでいる
- node_modulesのサイズが問題になっている
- git worktreeやAIコーディングエージェントの並列実行を行う

## 事前準備

### 1. 現状の確認
```bash
# 現在の依存関係ツリーを記録
npm list --depth=0 > npm-dependencies.txt

# package-lock.jsonのバックアップ
cp package-lock.json package-lock.json.backup

# 現在のスクリプトを確認
npm run
```

### 2. pnpmのインストール
```bash
# npm経由でインストール
npm install -g pnpm

# または、スタンドアロンインストール
curl -fsSL https://get.pnpm.io/install.sh | sh -
```

### 3. バージョン選択

| バージョン | enableGlobalVirtualStore | Node.js要件 |
|-----------|------------------------|-------------|
| v10.12+ | opt-in（実験的） | Node 18+ |
| v11+ | グローバルインストールでデフォルト有効、プロジェクトはopt-in | Node 22+ |

git worktreeやマルチエージェント開発を行う場合は`enableGlobalVirtualStore`の有効化を推奨。v10.12+で利用可能。v11はNode 22+必須のため、CI環境のNode.jsバージョンと合わせて判断する。

## 段階的移行手順

### Phase 1: 基本的な移行

#### 1. クリーンアップ
```bash
rm -rf node_modules
rm -rf packages/*/node_modules
rm -f package-lock.json
```

#### 2. pnpm-workspace.yaml作成
```yaml
packages:
  - 'packages/*'

# git worktree / マルチエージェント開発向け（v10.12+）
# enableGlobalVirtualStore: true
```

#### 3. 初回インストールとPhantom Dependencies検出

pnpm移行で最も頻出する問題が**Phantom Dependencies（幽霊依存関係）**。npmのフラットなnode_modules構造では推移的依存関係を暗黙的にimportできるが、pnpmの厳密な依存管理ではpackage.jsonに宣言されていない依存は解決できなくなる。

```bash
# まず通常インストールを試す
pnpm install

# エラーが出る場合、一時的にshamefully-hoistでインストールし検出に進む
pnpm install --shamefully-hoist
```

**TypeScript（ESM）の検出**:
```bash
tsc --noEmit --no-bail 2>&1 | grep "Cannot find module"
```

**CommonJS形式の検出**:
```bash
pnpm dlx knip --include=unlisted,unresolved
```

検出された依存関係は明示的に各パッケージの`package.json`へ追加する。`shamefully-hoist`は一時的な回避策であり、最終的には解消を目指す。

参考: [レガシー Monorepo を安全かつ素早く pnpm workspace に移行する方法](https://tech.plaid.co.jp/monorepo-pnpm-workspace-migration)（PLAID社、13パッケージ/約500ファイルのKARTE APIモノレポ移行事例）

#### 4. package.jsonスクリプトの更新
```diff
{
  "scripts": {
-   "install:all": "npm install",
+   "install:all": "pnpm install",
-   "build:all": "npm run build --workspaces",
+   "build:all": "pnpm run -r build",
-   "test:all": "npm test --workspaces",
+   "test:all": "pnpm run -r test"
  }
}
```

#### 5. コマンドの置き換え
```bash
# postinstall
# npm: npm run build --workspace=packages/core
# pnpm: pnpm --filter @my-org/core build

# グローバルツール
# npm: npm install -g typescript
# pnpm: pnpm add -g typescript

# npx → pnpm dlx / pnpm exec
# npm: npx tsc --version
# pnpm: pnpm dlx tsc --version
```

### Phase 2: workspace記法の変換

#### 内部パッケージ参照の更新

**変換前（npm）**:
```json
{
  "dependencies": {
    "@my-org/common": "*",
    "@my-org/core": "^1.0.0"
  }
}
```

**変換後（pnpm）**:
```json
{
  "dependencies": {
    "@my-org/common": "workspace:*",
    "@my-org/core": "workspace:*"
  }
}
```

#### 自動変換スクリプト
```javascript
// convert-to-workspace.js
const fs = require('fs');
const path = require('path');

function convertPackageJson(filePath) {
  const pkg = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const workspacePackages = ['@my-org/common', '@my-org/core', '@my-org/app'];

  ['dependencies', 'devDependencies'].forEach(depType => {
    if (pkg[depType]) {
      workspacePackages.forEach(name => {
        if (pkg[depType][name]) {
          pkg[depType][name] = 'workspace:*';
        }
      });
    }
  });

  fs.writeFileSync(filePath, JSON.stringify(pkg, null, 2));
}

// 実行
convertPackageJson('./packages/app/package.json');
```

### Phase 3: CI/CD環境の更新

#### GitHub Actions
```diff
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

+     - name: Setup pnpm
+       uses: pnpm/action-setup@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
-         node-version: '20'
-         cache: 'npm'
+         node-version: '22'
+         cache: 'pnpm'

      - name: Install dependencies
-       run: npm ci
+       run: pnpm install --frozen-lockfile

      - name: Build
-       run: npm run build
+       run: pnpm build
```

#### GitLab CI
```diff
-image: node:20
+image: node:22

+before_script:
+  - npm install -g pnpm
+  - pnpm config set store-dir .pnpm-store

cache:
  paths:
-   - node_modules/
+   - .pnpm-store/

install:
  script:
-   - npm ci
+   - pnpm install --frozen-lockfile

test:
  script:
-   - npm test
+   - pnpm test
```

## トラブルシューティング

### ピア依存関係の解決失敗
```
ERR_PNPM_PEER_DEP_ISSUES
```

```bash
# .npmrcに追加
echo "strict-peer-dependencies=false" >> .npmrc
echo "auto-install-peers=true" >> .npmrc
```

### 特定パッケージのホイスト要求

一部のツール（eslint、prettier等）がホイストされた依存に依存する場合:

```bash
# .npmrcで特定パターンのみホイスト
echo "public-hoist-pattern[]=*eslint*" >> .npmrc
echo "public-hoist-pattern[]=*prettier*" >> .npmrc
```

### preserveSymlinksとpnpmの競合

レガシー設定で`preserveSymlinks: true`を使っている場合、pnpmのシンボリックリンクベースのnode_modules構造と競合する。

- `preserveSymlinks`を`false`に変更
- CommonJSをimportしているパッケージがある場合は`vite-plugin-commonjs`等で対処

### pnpm --filterの静かな失敗

`pnpm --filter`でパターンがマッチしない場合、デフォルトではエラーにならず静かに成功する。CIで意図しないスキップが発生する原因になる。

```bash
pnpm --filter "@my-org/app" --fail-if-no-match build
```

### Changesetとの統合問題
```
Error: You cannot publish over the previously published versions
```

Changesetの並列公開とnpmのレースコンディション。pnpmの順序公開で解決:
```json
{
  "scripts": {
    "changeset:publish": "pnpm publish -r --no-git-checks"
  }
}
```

### Docker環境での問題
```dockerfile
FROM node:22
RUN npm install -g pnpm
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/*/package.json ./packages/
RUN pnpm install --frozen-lockfile --prod
```

## enableGlobalVirtualStoreの活用

git worktreeやAIコーディングエージェントの並列実行環境では、`enableGlobalVirtualStore`の有効化を推奨。同一の依存ツリーを持つworktree間でnode_modulesを共有し、2つ目以降のworktreeではシンボリックリンク作成のみで`pnpm install`が完了する。

```yaml
# pnpm-workspace.yaml
enableGlobalVirtualStore: true
```

## パフォーマンス比較

### インストール時間
```bash
# npm
time npm ci          # real 2m30s

# pnpm
time pnpm install --frozen-lockfile  # real 0m45s
```

### ディスク使用量
```bash
# npm
du -sh node_modules  # 850M

# pnpm
du -sh node_modules  # 320M
```

## ロールバック手順

```bash
# 1. pnpm関連ファイルを削除
rm -f pnpm-lock.yaml
rm -f pnpm-workspace.yaml
rm -rf node_modules

# 2. workspace:*記法を元に戻す（package.jsonを手動で編集）

# 3. package-lock.jsonを復元
cp package-lock.json.backup package-lock.json

# 4. npmで再インストール
npm ci
```

## 移行チェックリスト

### 必須
- [ ] pnpm-workspace.yamlを作成
- [ ] Phantom Dependenciesを検出・解消
- [ ] workspace:*記法に変換
- [ ] package.jsonのスクリプトを更新
- [ ] CI/CDワークフローを更新
- [ ] .gitignoreにpnpm-lock.yamlが含まれていないことを確認
- [ ] READMEのインストール手順を更新

### 推奨
- [ ] .npmrcを設定（ピア依存関係、ホイストパターン）
- [ ] enableGlobalVirtualStoreの有効化を検討
- [ ] `--fail-if-no-match`をCIスクリプトに追加
- [ ] チーム全体への周知

### 検証
- [ ] `pnpm install`が成功
- [ ] `pnpm build`が成功
- [ ] `pnpm test`が成功
- [ ] CI/CDパイプラインが成功
- [ ] npm公開が成功（該当する場合）
