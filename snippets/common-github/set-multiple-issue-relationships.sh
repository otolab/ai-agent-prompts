#!/bin/bash

# 複数のGitHub Issues間の親子関係を一括設定するスクリプト
# 使用方法: ./set-multiple-issue-relationships.sh <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]
# 例: ./set-multiple-issue-relationships.sh plaidev/karte-io-systems 130482 134277 134278

set -e

# 引数チェック
if [ $# -lt 3 ]; then
    echo "Usage: $0 <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]"
    echo "Example: $0 plaidev/karte-io-systems 130482 134277 134278"
    exit 1
fi

REPO="$1"
PARENT_ISSUE="$2"
shift 2  # 最初の2つの引数を削除

echo "Repository: $REPO"
echo "Parent Issue: #$PARENT_ISSUE"
echo "Child Issues: #$@"
echo

# 親IssueのNode IDを取得
echo "Fetching parent issue node ID..."
PARENT_NODE_ID=$(gh issue view "$PARENT_ISSUE" --repo "$REPO" --json id --jq '.id')
if [ -z "$PARENT_NODE_ID" ]; then
    echo "Error: Could not fetch parent issue #$PARENT_ISSUE"
    exit 1
fi
echo "Parent node ID: $PARENT_NODE_ID"
echo

# 各子Issueに対して関係を設定
SUCCESS_COUNT=0
FAIL_COUNT=0

for CHILD_ISSUE in "$@"; do
    echo "----------------------------------------"
    echo "Processing child issue #$CHILD_ISSUE..."

    # 子IssueのNode IDを取得
    CHILD_NODE_ID=$(gh issue view "$CHILD_ISSUE" --repo "$REPO" --json id --jq '.id' 2>/dev/null)
    if [ -z "$CHILD_NODE_ID" ]; then
        echo "❌ Error: Could not fetch issue #$CHILD_ISSUE"
        ((FAIL_COUNT++))
        continue
    fi
    echo "Child node ID: $CHILD_NODE_ID"

    # GraphQL mutationを実行
    echo "Setting relationship..."
    RESULT=$(gh api graphql \
      --raw-field query='
        mutation addSubIssue($issueId: ID!, $subIssueId: ID!) {
          addSubIssue(input: {issueId: $issueId, subIssueId: $subIssueId}) {
            issue {
              number
            }
            subIssue {
              number
            }
          }
        }' \
      -F issueId="$PARENT_NODE_ID" \
      -F subIssueId="$CHILD_NODE_ID" \
      --header 'GraphQL-Features: sub_issues' 2>&1)

    if [ $? -eq 0 ] && ! echo "$RESULT" | grep -q '"errors"'; then
        echo "✅ Successfully set #$CHILD_ISSUE as sub-issue of #$PARENT_ISSUE"
        ((SUCCESS_COUNT++))
    else
        echo "❌ Failed to set relationship for #$CHILD_ISSUE"
        echo "$RESULT" | jq '.errors' 2>/dev/null || echo "$RESULT"
        ((FAIL_COUNT++))
    fi
done

echo
echo "========================================"
echo "Summary:"
echo "  Successful: $SUCCESS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo "========================================"

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi