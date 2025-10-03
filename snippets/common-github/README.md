# GitHub Issue管理スクリプト集

GitHubのIssue管理を効率化するためのスクリプト集です。

## スクリプト一覧

### set-issue-relationship.sh

GitHub Issues間の親子関係を設定するスクリプトです。

#### 使用方法
```bash
./set-issue-relationship.sh <repo> <parent-issue-number> <child-issue-number>
```

#### 例
```bash
./set-issue-relationship.sh plaidev/karte-io-systems 130482 134277
```

#### 必要な権限
- リポジトリへの読み取りアクセス
- GraphQL APIの使用権限

#### 注意事項
- このスクリプトはGitHub GraphQLの`sub_issues`機能を使用します（プレビュー機能）
- `GraphQL-Features: sub_issues`ヘッダーが必要です
- 親子関係は一方向のみ（子から親への参照）

### set-multiple-issue-relationships.sh

一つの親Issueに対して複数の子Issueを一括で設定するスクリプトです。

#### 使用方法
```bash
./set-multiple-issue-relationships.sh <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]
```

#### 例
```bash
# Issue #130482を親として、#134277と#134278を子Issueとして設定
./set-multiple-issue-relationships.sh plaidev/karte-io-systems 130482 134277 134278
```

#### 出力例
```
Repository: plaidev/karte-io-systems
Parent Issue: #130482
Child Issues: #134277 #134278

Fetching parent issue node ID...
Parent node ID: I_kwDOCWB66M6QGj9C

----------------------------------------
Processing child issue #134277...
Child node ID: I_kwDOCWB66M6QpH7V
Setting relationship...
✅ Successfully set #134277 as sub-issue of #130482

----------------------------------------
Processing child issue #134278...
Child node ID: I_kwDOCWB66M6QpH7W
Setting relationship...
✅ Successfully set #134278 as sub-issue of #130482

========================================
Summary:
  Successful: 2
  Failed: 0
========================================
```

### check-ci-errors.sh

GitHub PRのCIチェック結果を確認・分析するスクリプトです。

#### 使用方法
```bash
# 現在のブランチのPRのCI状態を確認
./check-ci-errors.sh

# 特定のPRのCI状態を確認
./check-ci-errors.sh <pr-number>

# 特定のジョブの詳細ログを表示
./check-ci-errors.sh [pr-number] --details "Job Name"
```

#### 例
```bash
# PR #104のCI状態を確認
./check-ci-errors.sh 104

# PR #104のTestジョブの詳細を表示
./check-ci-errors.sh 104 --details "Test"

# 現在のブランチのE2E Testsジョブの詳細を表示
./check-ci-errors.sh --details "E2E Tests"
```

#### 出力例

**概要モード（デフォルト）**
```
PR #104 のCIステータスを確認中...

=== CI チェック概要 ===

❌ FAILED: Test
❌ FAILED: E2E Tests

=== サマリー ===
✅ 成功: 5
❌ 失敗: 2

💡 ヒント:
失敗したジョブの詳細ログを確認するには、以下のコマンドを実行してください:
  ./check-ci-errors.sh 104 --details "Test"
  ./check-ci-errors.sh 104 --details "E2E Tests"

※ --details オプションで失敗したステップの詳細ログをファイルに保存します
   保存されたファイルのパスとサイズが表示され、任意のエディタで確認できます
```

**詳細モード（--details）**
```
PR #104 のCIステータスを確認中...

ジョブ 'Test' の詳細ログを取得中...
※ ログはファイルに保存され、そのパスとサイズが表示されます

Run ID: 1234567890

失敗したステップのログをファイルに保存中...

✅ ログを正常に取得しました
📊 統計情報:
  - 行数: 2345 行
  - サイズ: 156K
  - 保存先: /tmp/gh-ci-error-abc123.log

💡 ログを確認するコマンド:
  cat "/tmp/gh-ci-error-abc123.log"               # 全体を表示
  head -100 "/tmp/gh-ci-error-abc123.log"         # 最初の100行
  grep -A5 -B5 ERROR "/tmp/gh-ci-error-abc123.log" # エラー箇所の前後5行
  less "/tmp/gh-ci-error-abc123.log"               # ページャーで閲覧

🗑️  使用後の削除:
  rm "/tmp/gh-ci-error-abc123.log"
```

#### 機能
- **概要モード（デフォルト）**: 全CIチェックの成功/失敗数を表示
- **詳細モード（--details）**: 特定ジョブの失敗ログをファイルに保存
  - 大きなログファイルも扱えるよう、一時ファイルに保存
  - ファイルパス、サイズ、行数を表示
  - ログ確認用のコマンド例を提示
- **自動PR検出**: PR番号省略時は現在のブランチから自動検出
- **色付き出力**: 成功は緑、失敗は赤、情報は青で表示

#### 必要な環境
- GitHub CLI (`gh`) がインストール済み
- リポジトリへの読み取りアクセス権限
- PR作成済みのブランチ（PR番号省略時）

## トラブルシューティング

### エラー: "Your token has not been granted the required scopes"
GitHub CLIの認証トークンに必要なスコープが付与されていません。以下のコマンドで再認証してください：
```bash
gh auth refresh -h github.com -s read:project,write:project
```

### エラー: "Field 'addSubIssue' doesn't exist on type 'Mutation'"
この機能はまだプレビュー段階のため、一部の環境では利用できない可能性があります。

### エラー: "Could not fetch issue"
指定されたIssue番号が存在しないか、アクセス権限がありません。

## 参考情報

- [GitHub GraphQL API Documentation](https://docs.github.com/en/graphql)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- サブIssue機能は現在プレビュー段階です。将来的に仕様が変更される可能性があります。