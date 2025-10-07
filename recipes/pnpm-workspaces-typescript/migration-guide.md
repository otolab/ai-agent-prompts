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

## 段階的移行手順

### Phase 1: 基本的な移行

#### 1. クリーンアップ
```bash
# 既存のnode_modulesを削除
rm -rf node_modules
rm -rf packages/*/node_modules
rm -f package-lock.json
```

#### 2. pnpm-workspace.yaml作成
```yaml
packages:
  - 'packages/*'
```

#### 3. 初回インストール
```bash
# pnpmで依存関係をインストール
pnpm install

# エラーが出た場合は個別に対処
pnpm install --shamefully-hoist  # 一時的な回避策
```

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
+       with:
+         version: 9

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
-         cache: 'npm'
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
image: node:20

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

### Phase 4: 特殊ケースの対処

#### postinstallスクリプトの移行
```json
{
  "scripts": {
    // npmの場合
    "postinstall": "npm run build --workspace=packages/core",

    // pnpmの場合
    "postinstall": "pnpm --filter @my-org/core build"
  }
}
```

#### グローバルツールの移行
```bash
# npmの場合
npm install -g typescript

# pnpmの場合
pnpm add -g typescript
```

#### npxの代替
```bash
# npmの場合
npx tsc --version

# pnpmの場合
pnpm dlx tsc --version
# または
pnpm exec tsc --version
```

## トラブルシューティング

### 問題1: ピア依存関係の解決失敗
```
ERR_PNPM_PEER_DEP_ISSUES
```

**解決方法**:
```bash
# .npmrcに追加
echo "strict-peer-dependencies=false" >> .npmrc
echo "auto-install-peers=true" >> .npmrc
```

### 問題2: 特定のパッケージが見つからない
```
Cannot find module 'xxx'
```

**解決方法**:
```bash
# 一時的な回避策
pnpm install --shamefully-hoist

# または.npmrcに追加
echo "public-hoist-pattern[]=*eslint*" >> .npmrc
echo "public-hoist-pattern[]=*prettier*" >> .npmrc
```

### 問題3: Changesetとの統合問題
```
Error: You cannot publish over the previously published versions
```

**原因**: Changesetの並列公開とnpmのレースコンディション

**解決方法**:
```json
{
  "scripts": {
    // npmの並列公開（問題あり）
    "changeset:publish": "changeset publish",

    // pnpmの順序公開（解決）
    "changeset:publish": "pnpm publish -r --no-git-checks"
  }
}
```

### 問題4: Docker環境での問題
```dockerfile
# 修正前
FROM node:20
COPY package*.json ./
RUN npm ci --only=production

# 修正後
FROM node:20
RUN npm install -g pnpm
COPY pnpm-lock.yaml package.json ./
RUN pnpm install --frozen-lockfile --prod
```

## パフォーマンス比較

### インストール時間の測定
```bash
# npmの場合
time npm ci
# real 2m30s

# pnpmの場合
time pnpm install --frozen-lockfile
# real 0m45s
```

### ディスク使用量の比較
```bash
# npmの場合
du -sh node_modules
# 850M

# pnpmの場合
du -sh node_modules
# 320M
```

## ロールバック手順

万が一問題が発生した場合のロールバック：

```bash
# 1. pnpm関連ファイルを削除
rm -f pnpm-lock.yaml
rm -f pnpm-workspace.yaml
rm -rf node_modules

# 2. workspace:*記法を元に戻す
# package.jsonを手動で編集

# 3. package-lock.jsonを復元
cp package-lock.json.backup package-lock.json

# 4. npmで再インストール
npm ci
```

## 移行チェックリスト

### 必須項目
- [ ] pnpm-workspace.yamlを作成
- [ ] workspace:*記法に変換
- [ ] package.jsonのスクリプトを更新
- [ ] CI/CDワークフローを更新
- [ ] .gitignoreからpnpm-lock.yamlを削除
- [ ] READMEのインストール手順を更新

### 推奨項目
- [ ] .npmrcを設定
- [ ] prepublishOnlyスクリプトを追加
- [ ] ローカル開発環境の確認
- [ ] チーム全体への周知
- [ ] ドキュメントの更新

### 検証項目
- [ ] `pnpm install`が成功
- [ ] `pnpm build`が成功
- [ ] `pnpm test`が成功
- [ ] CI/CDパイプラインが成功
- [ ] npm公開が成功（該当する場合）

## まとめ

npmからpnpmへの移行は、以下のステップで安全に実行できます：

1. **段階的な移行**: 一度にすべてを変更せず、段階的に進める
2. **workspace:*記法**: 内部パッケージの参照を明確化
3. **CI/CD対応**: GitHub ActionsやGitLab CIの設定を更新
4. **トラブルシューティング**: 問題が発生しても解決策がある
5. **ロールバック可能**: 問題があれば元に戻せる

移行により、ビルド時間の短縮、ディスク容量の削減、より信頼性の高いパッケージ管理が実現できます。