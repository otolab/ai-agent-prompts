---
mode: issue_tracking
displayName: Issue追跡モード
autoTrigger:
  - Issue番号受信時（#123, Issue 456等）
  - ユーザとの対話で作業Issueが明確になった時
exitMessage: |
  Issue追跡モードを終了しました。
  作業内容はIssueコメントに記録されています。
---

# Issue追跡モード

## 概要

GitHub Issueベースで作業進捗を管理し、透明性を保って記録するモードです。
Issue番号受信時に自動発動し、作業内容をコメントで体系的に管理します。

## 発動条件

- Issue番号を受信した時：
  - `#123`
  - `Issue 456`
- ユーザのとの対話で作業Issueが明確になったとき

## 核心原則

### 目的の優先
- **Issueで最も優先するのは目的である**
- 解決方法や作業手順は手段に過ぎない
- 最適な方法を探求し、必要に応じて手段を見直す
- アプローチ変更は作業ログとして簡潔に記載

### 作業完了の判定
- **修正の完了** ≠ **作業の完了** ≠ **目的の達成**
- 完了には実動作確認や関係者承認が必要

## 動作フロー

### 1. Issue情報取得
- `gh issue view --comments` でIssue詳細を取得
- 既存コメントも取得、ラベル、アサイン状況を確認
- 関連PRの確認と類似Issue検索

### 2. 現状分析と作業計画
- Issue内容の要約と理解
- 既存進捗コメントから現在状況を把握
- 必要な作業項目の特定と依存関係確認

### 3. 作業準備
- 現在のブランチの確認
- 必要なら最新のdefaultブランチを取得して作業ブランチ作成

### 4. 作業実行
- 特定された作業の実行
- TodoListでの進捗管理
- 必要に応じた追加調査

### 5. 進捗記録
- 既存の投稿済みコメントを確認
- 適切なスタイル選択（メモ/報告）
  - メモの使用を主とすること
  - 書き方に関しては「コメントスタイル」参照

### 6. 完了処理
- 次のアクション明確化
- 適切なラベル更新
- 関連Issue/PRとの紐づけ

## コメントスタイル

### メモスタイル（発見・気づきの即座記録）
- **用途**: 作業中の発見や問題の記録。主にこちらを使う
- **形式**: 簡潔、単一内容に集中、ヘッダ行不要
- **例**:
  ```markdown
  *🤖 by Claude Code*

  APIエンドポイント `/api/users` で500エラーが発生。
  ログ確認の結果、データベース接続タイムアウトが原因。
  ```

### 報告スタイル（包括的な状況報告）
- **用途**: 作業セッション完了時の総合報告など。ユーザから要望があったときのみ
- **形式**: 複数項目を体系的に整理
- **例**:
  ```markdown
  *🤖 by Claude Code*

  ## 📊 作業完了報告

  ### 実行内容
  - APIエラーの原因調査完了
  - 修正案の検討と実装

  ### 結果
  - 500エラーの根本原因特定
  - 接続プール設定の最適化

  ### 次のアクション
  - [ ] Staging環境での動作検証
  - [ ] Production環境への展開準備
  ```

## 基本動作

### GitHub操作（必須: 身元明示）
**すべてのGitHubコメント（Issue、PR、レビュー）で冒頭に `*🤖 by Claude Code*` を記載**

- Issue番号判明時点で即座に内容確認
- `gh issue view --comments`, `gh pr view --comments`を活用
- 明確な関係性記述（depends on, relates to, refs等）

### コミット・PR作業
- ブランチ名: `feature/123/issue-description-1`
  - ブランチ作成は最新のdevelop/main/masterから分岐する
- 安全なコミット: 個別ファイル追加、予期しない変更の確認
  - `git add -A` は禁止。`git add .`もなるべく使わない
- PR説明文: Issue要約を含む自動生成
  - `refs #番号` で作業Issue番号を記載
  - 自動closeは行わない

### PR作成基準
- **原則**: マージ可能な完全な状態でPRを作成
- **完全性の定義**:
  - 計画した全機能の実装完了
  - ローカルテストパス
  - Lint/型チェック通過
  - CI全項目グリーン
- **レビュー用PR**: ユーザ明示的指示時のみ（WIP/Draft等明記）
- **詳細チェックリスト**: `TECH_NOTES.md`参照

## 他モードとの連携
- **コード修正モード**: ファイル編集時の詳細記録
- **振り返りモード**: 作業後の改善活動
- **KARTE開発モード**: システム固有のワークフロー

## 技術的詳細

### 主要コマンド
- `gh issue view --comments <number>` - Issue詳細取得
- `gh issue comment <number>` - コメント追加
- `gh pr list --search="<query>"` - 関連PR検索

### PRレビューコメントの取得と返信

#### 未解決コメントの取得
```bash
# 未解決のみ取得（推奨）
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

#### 返信フォーマット
**状況別：**
- **修正完了**: `*🤖 by Claude Code*\n\n修正済み: [内容]`
- **確認中**: `*🤖 by Claude Code*\n\n確認中: [質問内容]`
- **保留**: `*🤖 by Claude Code*\n\n別PRで対応: Issue #XX`

### Git操作の安全性
詳細は `TECH_NOTES.md` を参照：
- 編集ファイルの事前明確化
- 個別ファイル追加（`git add -A` 禁止）
- 予期しない変更への対処

---
**作成**: 2025年7月31日  
**最終更新**: 2025年8月12日（重複削除、重要度による階層化）