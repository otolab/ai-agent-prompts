#!/bin/bash

# GitHub Code Search with GraphQL API
# Uses gh command for authentication and GraphQL queries
# Searches code and identifies line numbers from fragments

set -euo pipefail

# デフォルト値
LIMIT=10
OUTPUT_FORMAT="table"
SHOW_FRAGMENTS=false
LOCATE_LINES=false

# 使用方法を表示
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <search_query>

GitHub code search using GraphQL API with line number detection from fragments.

Options:
    -r, --repo OWNER/REPO    Repository to search in (default: current repository)
    -l, --limit NUMBER       Maximum number of results (default: 10, max: 100)
    -f, --format FORMAT      Output format: table, json, tsv (default: table)
    -s, --show-fragments     Show code fragments in results
    -L, --locate-lines       Attempt to locate line numbers from fragments
    -h, --help              Show this help message

Examples:
    # Search in current repository
    $(basename "$0") "function authenticate"

    # Search in specific repository with fragments
    $(basename "$0") -r "owner/repo" -s "TODO"

    # Search and locate line numbers
    $(basename "$0") -r "owner/repo" -L "error handling"

    # Get results in JSON format
    $(basename "$0") -f json "class.*Controller"

Notes:
    - Requires gh CLI to be installed and authenticated
    - When using --locate-lines, Python 3 is required
    - Search query follows GitHub code search syntax
EOF
    exit 0
}

# エラーハンドリング
error() {
    echo "Error: $1" >&2
    exit 1
}

# 引数をパース
SEARCH_QUERY=""
REPO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -l|--limit)
            LIMIT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -s|--show-fragments)
            SHOW_FRAGMENTS=true
            shift
            ;;
        -L|--locate-lines)
            LOCATE_LINES=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            SEARCH_QUERY="$1"
            shift
            ;;
    esac
done

# 検索クエリが指定されているか確認
if [[ -z "$SEARCH_QUERY" ]]; then
    error "Search query is required. Use -h for help."
fi

# リポジトリが指定されていない場合、現在のリポジトリを取得
if [[ -z "$REPO" ]]; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
            error "Could not determine current repository. Please specify with -r option."
        }
    else
        error "Not in a git repository. Please specify repository with -r option."
    fi
fi

echo "Searching in repository: $REPO" >&2
echo "Query: $SEARCH_QUERY" >&2
echo "" >&2

# REST API用のクエリを構築
FULL_QUERY="repo:$REPO $SEARCH_QUERY"

# URLエンコード（簡易版）
ENCODED_QUERY=$(echo "$FULL_QUERY" | jq -Rr @uri)

# GitHub REST APIでコード検索を実行
RESPONSE=$(gh api "/search/code?q=${ENCODED_QUERY}&per_page=${LIMIT}" 2>/dev/null) || {
    error "Failed to execute code search. Check your gh authentication and permissions."
}

# 結果をチェック
CODE_COUNT=$(echo "$RESPONSE" | jq -r '.total_count')
if [[ "$CODE_COUNT" == "0" || "$CODE_COUNT" == "null" ]]; then
    echo "No results found for query: $SEARCH_QUERY" >&2
    exit 0
fi

echo "Found $CODE_COUNT total results (showing up to $LIMIT)" >&2
echo "" >&2

# 結果を処理
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    # JSON形式で出力
    echo "$RESPONSE" | jq '.items'
elif [[ "$OUTPUT_FORMAT" == "tsv" ]]; then
    # TSV形式で出力
    echo -e "Repository\tPath\tURL"
    echo "$RESPONSE" | jq -r '.items[] |
        [.repository.full_name, .path, .html_url] | @tsv'

    if [[ "$SHOW_FRAGMENTS" == "true" ]]; then
        echo "" >&2
        echo "=== Fragments ===" >&2
        echo "$RESPONSE" | jq -r '.items[] |
            "File: \(.path)",
            (.text_matches[]? | "  Fragment: \(.fragment)")'
    fi
else
    # テーブル形式で出力（デフォルト）
    echo "$RESPONSE" | jq -r '.items[] |
        "Repository: \(.repository.full_name)",
        "Path: \(.path)",
        "URL: \(.html_url)",
        ""'

    if [[ "$SHOW_FRAGMENTS" == "true" ]]; then
        echo "=== Code Fragments ===" >&2
        echo "$RESPONSE" | jq -r '.items[] |
            "File: \(.path)",
            (.text_matches[]? |
                "  Fragment: \(.fragment | gsub("\n"; "\\n") | .[0:200])"
            ),
            ""'
    fi
fi

# 行番号の特定を試みる
if [[ "$LOCATE_LINES" == "true" ]]; then
    echo "" >&2
    echo "=== Locating Line Numbers ===" >&2

    # 各ファイルのコンテンツを取得して行番号を特定
    echo "$RESPONSE" | jq -c '.items[]' | while read -r item; do
        REPO_NAME=$(echo "$item" | jq -r '.repository.full_name')
        FILE_PATH=$(echo "$item" | jq -r '.path')
        FILE_URL=$(echo "$item" | jq -r '.html_url')
        SHA=$(echo "$item" | jq -r '.sha')

        echo "" >&2
        echo "Processing: $REPO_NAME/$FILE_PATH" >&2

        # ファイルの完全な内容を取得
        FILE_CONTENT=$(gh api "/repos/$REPO_NAME/contents/$FILE_PATH" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null) || {
            echo "  ⚠️  Could not fetch file content" >&2
            continue
        }

        # text_matchesからfragmentを取得して処理
        echo "$item" | jq -r '.text_matches[]? | .fragment' | while IFS= read -r fragment; do
            if [[ -z "$fragment" ]]; then
                continue
            fi

            # fragmentの最初の行で検索
            FRAGMENT_PREVIEW=$(echo "$fragment" | head -1 | cut -c1-60)
            echo "  Fragment: $FRAGMENT_PREVIEW..." >&2

            # ファイル内容から行番号を検索
            LINE_NUM=0
            FOUND=false

            while IFS= read -r line; do
                LINE_NUM=$((LINE_NUM + 1))

                # 正規化して比較（空白を統一）
                NORMALIZED_LINE=$(echo "$line" | tr -s ' ' | tr -d '\r')
                NORMALIZED_FRAGMENT=$(echo "$fragment" | head -1 | tr -s ' ' | tr -d '\r')

                if [[ "$NORMALIZED_LINE" == *"$NORMALIZED_FRAGMENT"* ]]; then
                    echo "  📍 Found at line $LINE_NUM: $FILE_URL#L$LINE_NUM" >&2
                    FOUND=true
                    break
                fi
            done <<< "$FILE_CONTENT"

            if [[ "$FOUND" == "false" ]]; then
                echo "  ❌ Could not locate exact line number" >&2
            fi
        done
    done

    exit 0
fi

