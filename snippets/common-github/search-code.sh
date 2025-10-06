#!/bin/bash

# GitHub Code Search with REST API
# Uses gh command for authentication and API queries
# Supports automatic pagination and line number detection from fragments

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

GitHub code search with automatic pagination and line number detection.

Options:
    -r, --repo OWNER/REPO    Repository to search in (default: current repository)
    -o, --org ORGANIZATION   Organization to search in (cannot be used with --repo)
    -l, --limit NUMBER       Maximum number of results (default: 10, no upper limit)
    -f, --format FORMAT      Output format: table, json, tsv (default: table)
    -s, --show-fragments     Show code fragments in results
    -L, --locate-lines       Attempt to locate line numbers from fragments
    -h, --help              Show this help message

Examples:
    # Search in current repository (top 10 results)
    $(basename "$0") "function authenticate"

    # Search in specific repository with fragments
    $(basename "$0") -r "owner/repo" -s "TODO"

    # Search in entire organization
    $(basename "$0") -o "myorg" "security vulnerability"

    # Get more results (automatic pagination)
    $(basename "$0") -r "owner/repo" -l 250 "error handling"

    # Get results in JSON format
    $(basename "$0") -f json "class.*Controller"

Notes:
    - Requires gh CLI to be installed and authenticated
    - Automatically handles pagination for results > 100
    - When using --locate-lines, Python 3 is required
    - GitHub API limits total search results to 1000
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
ORG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            REPO="$2"
            shift 2
            ;;
        -o|--org)
            ORG="$2"
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

# repoとorgが同時に指定されている場合はエラー
if [[ -n "$REPO" && -n "$ORG" ]]; then
    error "Cannot specify both --repo and --org options. Use one or the other."
fi

# 検索対象を決定
if [[ -n "$ORG" ]]; then
    # Organization全体を検索
    echo "Searching in organization: $ORG" >&2
    SEARCH_SCOPE="org:$ORG"
elif [[ -n "$REPO" ]]; then
    # 指定されたリポジトリを検索
    echo "Searching in repository: $REPO" >&2
    SEARCH_SCOPE="repo:$REPO"
else
    # デフォルト: 現在のリポジトリを検索
    if git rev-parse --git-dir > /dev/null 2>&1; then
        REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || {
            error "Could not determine current repository. Please specify with -r or -o option."
        }
        echo "Searching in repository: $REPO" >&2
        SEARCH_SCOPE="repo:$REPO"
    else
        error "Not in a git repository. Please specify repository with -r or organization with -o option."
    fi
fi

echo "Query: $SEARCH_QUERY" >&2
echo "" >&2

# REST API用のクエリを構築
FULL_QUERY="$SEARCH_SCOPE $SEARCH_QUERY"

# URLエンコード（簡易版）
ENCODED_QUERY=$(echo "$FULL_QUERY" | jq -Rr @uri)

# 最初のページを取得して総件数を確認
FIRST_PAGE=$(gh api --header "Accept: application/vnd.github.text-match+json" "/search/code?q=${ENCODED_QUERY}&per_page=100&page=1" 2>/dev/null) || {
    error "Failed to execute code search. Check your gh authentication and permissions."
}

# 結果をチェック
CODE_COUNT=$(echo "$FIRST_PAGE" | jq -r '.total_count')
if [[ "$CODE_COUNT" == "0" || "$CODE_COUNT" == "null" ]]; then
    echo "No results found for query: $SEARCH_QUERY" >&2
    exit 0
fi

# 必要なページ数を計算（最大1000件のAPI制限を考慮）
MAX_AVAILABLE=$CODE_COUNT
if [[ $MAX_AVAILABLE -gt 1000 ]]; then
    MAX_AVAILABLE=1000
fi

ITEMS_TO_FETCH=$LIMIT
if [[ $ITEMS_TO_FETCH -gt $MAX_AVAILABLE ]]; then
    ITEMS_TO_FETCH=$MAX_AVAILABLE
fi

PAGES_NEEDED=$(( (ITEMS_TO_FETCH + 99) / 100 ))

# 結果表示のメッセージを生成
if [[ $CODE_COUNT -gt $LIMIT ]]; then
    if [[ $CODE_COUNT -gt 1000 ]]; then
        echo "Found $CODE_COUNT total results (showing top $LIMIT of first 1000 - GitHub API limit)" >&2
    else
        echo "Found $CODE_COUNT total results (showing top $LIMIT)" >&2
    fi
elif [[ $CODE_COUNT -eq $LIMIT ]]; then
    echo "Found exactly $CODE_COUNT results" >&2
else
    echo "Found $CODE_COUNT total results (showing all)" >&2
fi
echo "" >&2

# 複数ページの結果を収集
if [[ $PAGES_NEEDED -eq 1 ]]; then
    # 1ページのみの場合
    ALL_ITEMS=$(echo "$FIRST_PAGE" | jq '.items')
else
    # 複数ページの場合
    echo "Fetching results from $PAGES_NEEDED pages..." >&2

    # 最初のページのitemsを保存
    ALL_ITEMS=$(echo "$FIRST_PAGE" | jq '.items')

    # 2ページ目以降を取得
    for ((page=2; page<=PAGES_NEEDED; page++)); do
        echo "  Fetching page $page/$PAGES_NEEDED..." >&2
        PAGE_DATA=$(gh api --header "Accept: application/vnd.github.text-match+json" "/search/code?q=${ENCODED_QUERY}&per_page=100&page=${page}" 2>/dev/null) || {
            echo "  Warning: Failed to fetch page $page" >&2
            break
        }

        # 新しいitemsを既存のものに追加
        PAGE_ITEMS=$(echo "$PAGE_DATA" | jq '.items')
        ALL_ITEMS=$(echo "$ALL_ITEMS $PAGE_ITEMS" | jq -s 'add')
    done
    echo "" >&2
fi

# 指定された件数に制限
ALL_ITEMS=$(echo "$ALL_ITEMS" | jq ".[:$LIMIT]")

# 最終的なレスポンスオブジェクトを構築
RESPONSE=$(jq -n --argjson items "$ALL_ITEMS" --argjson total "$CODE_COUNT" '{total_count: $total, items: $items}')

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