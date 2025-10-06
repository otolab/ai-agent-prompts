#!/bin/bash

# GitHub Issues間の親子関係を設定するスクリプト（単一子Issue用ラッパー）
# 統合版のset-issue-relationships.shを呼び出します
#
# 使用方法: ./set-issue-relationship.sh <repo> <parent-issue-number> <child-issue-number>
# 例: ./set-issue-relationship.sh plaidev/karte-io-systems 130482 134277
#
# 注意: このスクリプトは後方互換性のために残されています。
#       新規利用時はset-issue-relationships.shの使用を推奨します。

set -e

# 引数チェック
if [ $# -ne 3 ]; then
    echo "Usage: $0 <repo> <parent-issue-number> <child-issue-number>"
    echo "Example: $0 plaidev/karte-io-systems 130482 134277"
    echo ""
    echo "Note: This script is maintained for backward compatibility."
    echo "      Consider using set-issue-relationships.sh instead."
    exit 1
fi

# 統合版スクリプトのパスを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIFIED_SCRIPT="$SCRIPT_DIR/set-issue-relationships.sh"

# 統合版スクリプトが存在するか確認
if [ ! -f "$UNIFIED_SCRIPT" ]; then
    echo "Error: Unified script not found at $UNIFIED_SCRIPT"
    exit 1
fi

# 統合版スクリプトを呼び出す
exec "$UNIFIED_SCRIPT" "$@"