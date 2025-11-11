#!/bin/bash

# GitHub Issues間の親子関係を設定するスクリプト（統合版）
# 単一または複数の子Issueに対応
#
# 使用方法:
#   ./set-issue-relationships.sh <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]
#
# 例:
#   単一の子Issue: ./set-issue-relationships.sh owner/repo 130482 134277
#   複数の子Issue: ./set-issue-relationships.sh owner/repo 130482 134277 134278 134279

set -e

# 引数チェック
if [ $# -lt 3 ]; then
    echo "Usage: $0 <repo> <parent-issue-number> <child-issue-number1> [child-issue-number2 ...]"
    echo ""
    echo "Examples:"
    echo "  Single child:    $0 owner/repo 100 101"
    echo "  Multiple children: $0 owner/repo 100 101 102 103"
    exit 1
fi

REPO="$1"
PARENT_ISSUE="$2"
shift 2  # 最初の2つの引数を削除

echo "Repository: $REPO"
echo "Parent Issue: #$PARENT_ISSUE"

# 各Issue番号に#を付けて表示
CHILD_ISSUES_DISPLAY=""
for issue in "$@"; do
    CHILD_ISSUES_DISPLAY="${CHILD_ISSUES_DISPLAY}#$issue "
done
echo "Child Issues: ${CHILD_ISSUES_DISPLAY}"
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

# 単一の子Issueの場合はよりシンプルなメッセージも表示
if [ $SUCCESS_COUNT -eq 1 ] && [ $FAIL_COUNT -eq 0 ] && [ $# -eq 1 ]; then
    echo
    echo "✅ Issue #$1 is now a sub-issue of Issue #$PARENT_ISSUE"
fi

if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi