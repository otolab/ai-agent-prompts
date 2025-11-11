# GitHub操作スクリプト集

GitHubのIssue管理とコード検索を効率化するためのスクリプト集です。

## スクリプト一覧

### set-issue-relationships.sh

GitHub Issues間の親子関係を設定するスクリプトです。単一または複数の子Issueに対応しています。

#### 使用方法
```bash
./set-issue-relationships.sh <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]
```

#### 例
```bash
# 単一の子Issue
./set-issue-relationships.sh owner/repo 130482 134277

# 複数の子Issue
./set-issue-relationships.sh owner/repo 130482 134277 134278 134279
```

#### 必要な権限
- リポジトリへの読み取りアクセス
- GraphQL APIの使用権限

#### 注意事項
- このスクリプトはGitHub GraphQLの`sub_issues`機能を使用します（プレビュー機能）
- `GraphQL-Features: sub_issues`ヘッダーが必要です
- 親子関係は一方向のみ（子から親への参照）

#### 出力例
```
Repository: owner/repo
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

### search-code.sh

GitHub REST APIを使用してコード検索を行い、自動ページネーション対応で100件以上の結果も取得可能なスクリプトです。

#### 使用方法
```bash
./search-code.sh [OPTIONS] <search_query>
```

#### オプション
- `-r, --repo OWNER/REPO`: 検索対象リポジトリ（省略時は現在のリポジトリ）
- `-o, --org ORGANIZATION`: 検索対象Organization（--repoと同時使用不可）
- `-l, --limit NUMBER`: 最大結果数（デフォルト: 10、上限なし、自動ページネーション）
- `-f, --format FORMAT`: 出力形式（table, json, tsv。デフォルト: table）
- `-s, --show-fragments`: コードfragmentを表示
- `-L, --locate-lines`: fragmentから行番号を特定
- `-h, --help`: ヘルプを表示

#### 例
```bash
# 現在のリポジトリで検索（上位10件）
./search-code.sh "function authenticate"

# 特定リポジトリでfragment付きで検索
./search-code.sh -r "owner/repo" -s "TODO"

# Organization全体で検索
./search-code.sh -o "myorg" "security vulnerability"

# 100件以上の結果を取得（自動ページネーション）
./search-code.sh -r "owner/repo" -l 250 "error handling"

# 行番号を特定して検索
./search-code.sh -r "owner/repo" -L "async function"

# JSON形式で結果を取得
./search-code.sh -f json "class.*Controller"
```

#### 行番号特定機能
`--locate-lines`オプションを使用すると、検索結果のfragmentから実際のファイル内の行番号を特定します。

**特定方法**:
1. 完全一致: fragmentとファイル内容の正規化後の完全一致
2. 複数行マッチング: fragmentが複数行の場合、最初の行から順次マッチング
3. ファジーマッチング: 類似度スコアによる近似マッチ（80%以上の類似度）
4. キーワードマッチング: 重要な識別子（class名、function名など）による特定

**出力例**:
```
============================================================
Repository: owner/repo
File: src/auth/authenticator.js
URL: https://github.com/owner/repo/blob/main/src/auth/authenticator.js

📝 Fragment 1: function authenticate(username, password) {\\n  if (!username || !pass...
   Highlights: authenticate, username, password

📍 Located at:
   Line 42 ✓✓✓: function authenticate(username, password) {
   → https://github.com/owner/repo/blob/main/src/auth/authenticator.js#L42
```

#### 必要な環境
- GitHub CLI (`gh`) がインストール済みで認証済み
- 検索対象リポジトリへの読み取りアクセス権限
- Python 3（`--locate-lines`オプション使用時）

#### 技術詳細
- GitHub REST API（`/search/code`エンドポイント）を使用
- **自動ページネーション**: 100件を超える結果は複数ページを自動取得
- API制限: 最大1000件まで取得可能（GitHub APIの仕様）
- 検索結果にはfragmentのみが含まれ、直接の行番号は取得できません
- `--locate-lines`オプション使用時は、各ファイルの完全な内容を`/repos/{owner}/{repo}/contents/{path}`から取得
- fragmentとファイル内容を照合して行番号を特定
- 検索クエリはGitHubのコード検索構文に従います

### locate_lines_from_fragment.py

`search-code.sh`の補助スクリプトで、REST API検索結果のfragmentから実際の行番号を特定します。

#### 単体での使用方法
```bash
gh api "/search/code?q=query" | python3 locate_lines_from_fragment.py
```

注意: REST APIはファイル内容を含まないため、行番号の正確な特定にはファイル内容の別途取得が必要です。

#### 機能
- 正規化による空白の差異を吸収
- 複数行fragmentの連続性チェック
- ファジーマッチングによる近似一致検出
- 信頼度スコアの表示（✓✓✓: 90%以上、✓✓: 70-90%、✓: 70%未満）

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

## GitHub APIの活用Tips

### Issue/PRコメントの直接取得

GitHubのコメントURLから直接コメント内容を取得する方法：

```bash
# コメントURLの例: https://github.com/owner/repo/issues/123#issuecomment-3336557377
# issuecomment-の後の数字（3336557377）がコメントID

# gh APIでコメントを取得
gh api /repos/owner/repo/issues/comments/3336557377

# 特定のフィールドのみ取得
gh api /repos/owner/repo/issues/comments/3336557377 --jq '.body'

# コメントの作成者と内容を取得
gh api /repos/owner/repo/issues/comments/3336557377 --jq '{author: .user.login, body: .body}'
```

**注意事項**:
- URLの`#issuecomment-`の後の数字がコメントIDです
- PRのコメントも同じ方法で取得可能（issues/commentsエンドポイントを使用）
- リポジトリへの読み取りアクセス権限が必要

### PRレビューコメントの取得と返信

PRのレビューコメント（コードレビュー）を取得し、返信する方法：

#### 未解決レビューコメントの取得

```bash
# 未解決のレビューコメントのみ取得（推奨）
gh api graphql -f query='{
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: PR_NUMBER) {
      reviewThreads(last: 30) {
        nodes {
          id
          path
          line
          isResolved
          comments(last: 1) {
            nodes {
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' | jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | {id, path, comment: .comments.nodes[0].body}'
```

#### レビューコメントへの返信

```bash
# レビューコメントスレッドに返信
gh api graphql -f query='
mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: "THREAD_ID",
    body: "*🤖 by Claude Code*\n\n修正済み: [具体的な修正内容]"
  }) {
    comment { id }
  }
}'
```

#### 返信フォーマット例

状況に応じた返信例：

```bash
# 修正完了時
"*🤖 by Claude Code*\n\n修正済み: [具体的な修正内容]"

# 確認中の場合
"*🤖 by Claude Code*\n\n確認中: [質問内容]"

# 別PRで対応する場合
"*🤖 by Claude Code*\n\n別PRで対応: Issue #XX"
```

**注意事項**:
- すべてのGitHubコメント（Issue、PR、レビュー）で冒頭に `*🤖 by Claude Code*` を記載して身元を明示
- `THREAD_ID`はGraphQL APIで取得したレビュースレッドのID
- レビューコメントはIssueコメントとは異なるAPIエンドポイントを使用

## 参考情報

- [GitHub GraphQL API Documentation](https://docs.github.com/en/graphql)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- サブIssue機能は現在プレビュー段階です。将来的に仕様が変更される可能性があります。