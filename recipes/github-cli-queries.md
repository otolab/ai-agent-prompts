# GitHub CLI GraphQLクエリ集

## PRレビューコメントの取得（解決状態付き）

レビューコメントとその解決状態を取得するGraphQLクエリ：

```bash
gh api graphql -f query='
  {
    repository(owner: "otolab", name: "sebas-chan") {
      pullRequest(number: 21) {
        reviewThreads(last: 30) {
          nodes {
            id
            isResolved
            isOutdated
            resolvedBy {
              login
            }
            comments(last: 10) {
              nodes {
                id
                body
                author {
                  login
                }
                path
                position
                createdAt
              }
            }
          }
        }
      }
    }
  }'
```

### クエリの説明

- `reviewThreads`: PRのレビューコメントスレッドを取得
- `isResolved`: コメントが解決済みかどうか
- `isOutdated`: コメントが古くなっているか（コードが変更されている）
- `resolvedBy`: 解決したユーザー情報
- `comments`: スレッド内のコメント一覧
- `path`: コメントが付けられたファイルパス
- `position`: コメントの位置

### 使用例

特定のPRのレビューコメントを確認：
```bash
# owner、name、PR番号を適宜変更
gh api graphql -f query='...' | jq '.data.repository.pullRequest.reviewThreads.nodes'
```

未解決のコメントのみをフィルタ：
```bash
gh api graphql -f query='...' | jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
```