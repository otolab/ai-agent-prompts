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

# GraphQLクエリを構築
# リポジトリ指定を含む検索クエリを構築
FULL_QUERY="repo:$REPO $SEARCH_QUERY"

# GraphQLクエリ
read -r -d '' GRAPHQL_QUERY << EOF || true
{
  search(query: "$FULL_QUERY", type: CODE, first: $LIMIT) {
    codeCount
    edges {
      node {
        ... on Blob {
          repository {
            nameWithOwner
          }
          path
          url
          text
        }
      }
      textMatches {
        fragment
        property
        highlights {
          text
          beginIndice
          endIndice
        }
      }
    }
  }
}
EOF

# GraphQLクエリを実行
RESPONSE=$(gh api graphql -f query="$GRAPHQL_QUERY" 2>/dev/null) || {
    error "Failed to execute GraphQL query. Check your gh authentication and permissions."
}

# 結果をチェック
CODE_COUNT=$(echo "$RESPONSE" | jq -r '.data.search.codeCount')
if [[ "$CODE_COUNT" == "0" ]]; then
    echo "No results found for query: $SEARCH_QUERY" >&2
    exit 0
fi

echo "Found $CODE_COUNT total results (showing up to $LIMIT)" >&2
echo "" >&2

# 結果を処理
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    # JSON形式で出力
    echo "$RESPONSE" | jq '.data.search.edges'
elif [[ "$OUTPUT_FORMAT" == "tsv" ]]; then
    # TSV形式で出力
    echo -e "Repository\tPath\tURL"
    echo "$RESPONSE" | jq -r '.data.search.edges[] |
        [.node.repository.nameWithOwner, .node.path, .node.url] | @tsv'

    if [[ "$SHOW_FRAGMENTS" == "true" ]]; then
        echo "" >&2
        echo "=== Fragments ===" >&2
        echo "$RESPONSE" | jq -r '.data.search.edges[] |
            "File: \(.node.path)",
            (.textMatches[] | "  Fragment: \(.fragment)")'
    fi
else
    # テーブル形式で出力（デフォルト）
    echo "$RESPONSE" | jq -r '.data.search.edges[] |
        "Repository: \(.node.repository.nameWithOwner)",
        "Path: \(.node.path)",
        "URL: \(.node.url)",
        ""'

    if [[ "$SHOW_FRAGMENTS" == "true" ]]; then
        echo "=== Code Fragments ===" >&2
        echo "$RESPONSE" | jq -r '.data.search.edges[] |
            "File: \(.node.path)",
            (.textMatches[] |
                "  Fragment: \(.fragment | gsub("\n"; "\\n") | .[0:200])"
            ),
            ""'
    fi
fi

# 行番号の特定を試みる
if [[ "$LOCATE_LINES" == "true" ]]; then
    # Pythonスクリプトのパスを取得
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PYTHON_SCRIPT="$SCRIPT_DIR/locate_lines_from_fragment.py"

    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        echo "" >&2
        echo "Warning: Python script for line location not found at: $PYTHON_SCRIPT" >&2
        echo "Creating the Python helper script..." >&2

        # Pythonヘルパースクリプトを作成
        cat > "$PYTHON_SCRIPT" << 'PYTHON_EOF'
#!/usr/bin/env python3

import json
import sys
import re
from typing import List, Dict, Any, Optional, Tuple

def find_fragment_in_text(fragment: str, full_text: str) -> List[Tuple[int, str]]:
    """
    Find fragment in full text and return line numbers with matched lines.
    """
    # Normalize whitespace for matching
    fragment_normalized = re.sub(r'\s+', ' ', fragment.strip())

    lines = full_text.split('\n')
    matches = []

    # Try to find exact matches first
    for i, line in enumerate(lines, 1):
        line_normalized = re.sub(r'\s+', ' ', line.strip())
        if fragment_normalized in line_normalized:
            matches.append((i, line))

    # If no exact matches, try to find partial matches
    if not matches:
        fragment_words = fragment_normalized.split()
        if len(fragment_words) > 3:
            # Try matching with first and last few words
            start_pattern = ' '.join(fragment_words[:3])
            end_pattern = ' '.join(fragment_words[-3:])

            for i, line in enumerate(lines, 1):
                line_normalized = re.sub(r'\s+', ' ', line.strip())
                if start_pattern in line_normalized or end_pattern in line_normalized:
                    matches.append((i, line))

    return matches

def process_search_results(data: Dict[str, Any]) -> None:
    """
    Process GitHub code search results and locate line numbers from fragments.
    """
    edges = data.get('data', {}).get('search', {}).get('edges', [])

    for edge in edges:
        node = edge.get('node', {})
        text_matches = edge.get('textMatches', [])

        if not text_matches:
            continue

        repo = node.get('repository', {}).get('nameWithOwner', '')
        path = node.get('path', '')
        url = node.get('url', '')
        full_text = node.get('text', '')

        if not full_text:
            print(f"\nFile: {repo}/{path}")
            print(f"URL: {url}")
            print("Warning: Full text not available")
            continue

        print(f"\nFile: {repo}/{path}")
        print(f"URL: {url}")

        for match in text_matches:
            fragment = match.get('fragment', '')
            if not fragment:
                continue

            print(f"\nFragment: {fragment[:100]}...")

            # Find line numbers
            line_matches = find_fragment_in_text(fragment, full_text)

            if line_matches:
                print("Located at lines:")
                for line_num, line_text in line_matches[:5]:  # Show max 5 matches
                    # Construct GitHub URL with line number
                    line_url = f"{url}#L{line_num}"
                    print(f"  Line {line_num}: {line_text[:80]}...")
                    print(f"  URL: {line_url}")
            else:
                print("  Could not locate exact line numbers")

def main():
    # Read JSON from stdin
    try:
        data = json.load(sys.stdin)
        process_search_results(data)
    except json.JSONDecodeError as e:
        print(f"Error parsing JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
PYTHON_EOF
        chmod +x "$PYTHON_SCRIPT"
    fi

    # Pythonスクリプトを実行
    echo "" >&2
    echo "=== Locating Line Numbers ===" >&2
    echo "$RESPONSE" | python3 "$PYTHON_SCRIPT"
fi