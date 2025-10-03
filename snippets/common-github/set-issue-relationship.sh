#!/bin/bash

# GitHub Issues間の親子関係を設定するスクリプト
# 使用方法: ./set-issue-relationship.sh <repo> <parent-issue-number> <child-issue-number>
# 例: ./set-issue-relationship.sh plaidev/karte-io-systems 130482 134277

set -e

# 引数チェック
if [ $# -ne 3 ]; then
    echo "Usage: $0 <repo> <parent-issue-number> <child-issue-number>"
    echo "Example: $0 plaidev/karte-io-systems 130482 134277"
    exit 1
fi

REPO="$1"
PARENT_ISSUE="$2"
CHILD_ISSUE="$3"

echo "Setting relationship: Issue #$PARENT_ISSUE (parent) <- Issue #$CHILD_ISSUE (child)"
echo "Repository: $REPO"
echo

# 親IssueのNode IDを取得
echo "Fetching parent issue node ID..."
PARENT_NODE_ID=$(gh issue view "$PARENT_ISSUE" --repo "$REPO" --json id --jq '.id')
if [ -z "$PARENT_NODE_ID" ]; then
    echo "Error: Could not fetch parent issue #$PARENT_ISSUE"
    exit 1
fi
echo "Parent node ID: $PARENT_NODE_ID"

# 子IssueのNode IDを取得
echo "Fetching child issue node ID..."
CHILD_NODE_ID=$(gh issue view "$CHILD_ISSUE" --repo "$REPO" --json id --jq '.id')
if [ -z "$CHILD_NODE_ID" ]; then
    echo "Error: Could not fetch child issue #$CHILD_ISSUE"
    exit 1
fi
echo "Child node ID: $CHILD_NODE_ID"

# GraphQL mutationを実行
echo
echo "Setting sub-issue relationship..."
RESULT=$(gh api graphql \
  --raw-field query='
    mutation addSubIssue($issueId: ID!, $subIssueId: ID!) {
      addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
        issue {
          title
          number
        }
        subIssue {
          title
          number
        }
      }
    }' \
  -F issueId="$PARENT_NODE_ID" \
  -F subIssueId="$CHILD_NODE_ID" \
  --header 'GraphQL-Features: sub_issues' 2>&1) || {
    echo "Error executing GraphQL mutation:"
    echo "$RESULT"
    exit 1
}

# 結果を解析して表示
if echo "$RESULT" | grep -q '"errors"'; then
    echo "Error setting relationship:"
    echo "$RESULT" | jq '.errors'
    exit 1
else
    echo "Success! Relationship created:"
    echo "$RESULT" | jq '.data.addSubIssue'
    echo
    echo "✅ Issue #$CHILD_ISSUE is now a sub-issue of Issue #$PARENT_ISSUE"
fi