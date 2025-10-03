#!/bin/bash

# GitHub CI エラーチェックスクリプト
# 使用例:
#   ./check-ci-errors.sh                    # 現在のブランチのPRのエラー概要を表示
#   ./check-ci-errors.sh 123                # PR #123のエラー概要を表示
#   ./check-ci-errors.sh --details "Test"   # 現在のブランチの"Test"ジョブの詳細を表示
#   ./check-ci-errors.sh 123 --details "Test"  # PR #123の"Test"ジョブの詳細を表示
#   ./check-ci-errors.sh 123 --repo owner/repo  # 特定リポジトリのPR #123を確認
#   ./check-ci-errors.sh --repo owner/repo 123 --details "Test"  # 複数オプションの組み合わせ

set -e

# 色付き出力用の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 引数処理
PR_NUMBER=""
DETAILS_MODE=false
JOB_NAME=""
SPECIFIED_REPO=""

# 引数をパース
while [[ $# -gt 0 ]]; do
    case $1 in
        --details)
            DETAILS_MODE=true
            JOB_NAME="$2"
            shift 2
            ;;
        --repo)
            SPECIFIED_REPO="$2"
            shift 2
            ;;
        *)
            if [[ -z "$PR_NUMBER" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
                PR_NUMBER="$1"
            fi
            shift
            ;;
    esac
done

# PR番号が指定されていない場合、現在のブランチから取得
if [[ -z "$PR_NUMBER" ]]; then
    echo -e "${BLUE}現在のブランチからPR番号を取得中...${NC}"
    PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")

    if [[ -z "$PR_NUMBER" ]]; then
        echo -e "${RED}エラー: PR番号を取得できません。PR番号を指定するか、PRが存在するブランチで実行してください。${NC}"
        exit 1
    fi
fi

# リポジトリを決定（--repoオプションが優先、なければ現在のディレクトリから取得）
if [[ -n "$SPECIFIED_REPO" ]]; then
    REPO="$SPECIFIED_REPO"
    echo -e "${BLUE}指定リポジトリ: ${REPO}${NC}"
else
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "")
    if [[ -z "$REPO" ]]; then
        echo -e "${YELLOW}警告: リポジトリを自動検出できません。--repo オプションを使用してください。${NC}"
        echo -e "${BLUE}例: $0 123 --repo owner/repo${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}PR #${PR_NUMBER} のCIステータスを確認中...${NC}\n"

# 詳細モードの場合
if $DETAILS_MODE; then
    if [[ -z "$JOB_NAME" ]]; then
        echo -e "${RED}エラー: --details オプションにはジョブ名を指定してください${NC}"
        echo "例: $0 --details \"Test\""
        exit 1
    fi

    echo -e "${YELLOW}ジョブ '${JOB_NAME}' の詳細ログを取得中...${NC}"
    echo -e "${BLUE}※ ログはファイルに保存され、そのパスとサイズが表示されます${NC}\n"

    # チェックからRUN URL取得（タブ区切りで処理）
    TEMP_CHECK=$(mktemp)
    gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null > "$TEMP_CHECK" || true

    # 完全一致でジョブを検索
    RUN_URL=""
    MATCHED_JOB=""

    while IFS=$'\t' read -r job_name status duration url _; do
        if [[ "$job_name" == "$JOB_NAME" ]]; then
            RUN_URL="$url"
            MATCHED_JOB="$job_name"
            break
        fi
    done < "$TEMP_CHECK"

    if [[ -z "$RUN_URL" ]]; then
        echo -e "${RED}エラー: ジョブ '${JOB_NAME}' が見つかりません${NC}"
        echo -e "\n利用可能なジョブ:"
        cut -f1 "$TEMP_CHECK" | sort -u | while read -r job; do
            echo -e "  - \"${job}\""
        done
        rm -f "$TEMP_CHECK"
        exit 1
    fi

    rm -f "$TEMP_CHECK"

    # CIサービスを判定
    if [[ "$RUN_URL" =~ circleci.com ]] || [[ "$RUN_URL" =~ app.circleci.com ]]; then
        echo -e "${YELLOW}⚠️  CircleCIのジョブは詳細ログ取得に対応していません${NC}"
        echo -e "${BLUE}CircleCI URL: ${RUN_URL}${NC}"
        echo -e "\n${YELLOW}ブラウザで直接確認してください:${NC}"
        echo -e "  ${BLUE}${RUN_URL}${NC}"
        exit 0
    elif [[ ! "$RUN_URL" =~ github.com/.*/actions ]]; then
        echo -e "${YELLOW}⚠️  GitHub Actions以外のCIサービスは詳細ログ取得に対応していません${NC}"
        echo -e "${BLUE}CI URL: ${RUN_URL}${NC}"
        echo -e "\n${YELLOW}ブラウザで直接確認してください:${NC}"
        echo -e "  ${BLUE}${RUN_URL}${NC}"
        exit 0
    fi

    # URLからRUN IDを抽出
    RUN_ID=$(echo "$RUN_URL" | grep -oE '[0-9]+' | tail -2 | head -1)

    if [[ -z "$RUN_ID" ]]; then
        echo -e "${RED}エラー: RUN IDを取得できません${NC}"
        exit 1
    fi

    echo -e "${BLUE}Run ID: ${RUN_ID}${NC}\n"

    # 失敗したログを取得してtmpファイルに保存
    echo -e "${YELLOW}失敗したステップのログをファイルに保存中...${NC}\n"

    # 一時ファイルを作成（macOS対応: XXXXXXは末尾に必要）
    LOG_FILE=$(mktemp /tmp/gh-ci-error-XXXXXX)

    # ログを取得してファイルに保存
    gh run view "$RUN_ID" --log-failed > "$LOG_FILE" 2>&1
    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 0 ]]; then
        # ファイルサイズと行数を取得
        FILE_SIZE=$(ls -lh "$LOG_FILE" | awk '{print $5}')
        LINE_COUNT=$(wc -l < "$LOG_FILE")

        echo -e "${GREEN}✅ ログを正常に取得しました${NC}"
        echo -e "${BLUE}📊 統計情報:${NC}"
        echo -e "  - 行数: ${LINE_COUNT} 行"
        echo -e "  - サイズ: ${FILE_SIZE}"
        echo -e "  - 保存先: ${LOG_FILE}"
        echo ""
        echo -e "${YELLOW}💡 ログを確認するコマンド:${NC}"
        echo -e "  ${BLUE}cat \"$LOG_FILE\"              ${NC}# 全体を表示"
        echo -e "  ${BLUE}head -100 \"$LOG_FILE\"        ${NC}# 最初の100行"
        echo -e "  ${BLUE}grep -A5 -B5 ERROR \"$LOG_FILE\"${NC}# エラー箇所の前後5行"
        echo -e "  ${BLUE}less \"$LOG_FILE\"              ${NC}# ページャーで閲覧"
        echo ""

        # ファイル削除コマンドを表示
        echo -e "${BLUE}🗑️  使用後の削除:${NC}"
        echo -e "  ${BLUE}rm \"$LOG_FILE\"${NC}"
    else
        echo -e "\n${RED}エラー: ログの取得に失敗しました (終了コード: $EXIT_CODE)${NC}"

        # エラー内容もファイルに保存されている可能性があるので確認
        if [[ -s "$LOG_FILE" ]]; then
            FILE_SIZE=$(ls -lh "$LOG_FILE" | awk '{print $5}')
            LINE_COUNT=$(wc -l < "$LOG_FILE")
            echo -e "${YELLOW}エラー情報がファイルに保存されています:${NC}"
            echo -e "  - 行数: ${LINE_COUNT} 行"
            echo -e "  - サイズ: ${FILE_SIZE}"
            echo -e "  - 保存先: ${LOG_FILE}"
            echo ""
            echo -e "${YELLOW}エラー内容のプレビュー:${NC}"
            head -20 "$LOG_FILE"
        else
            rm -f "$LOG_FILE"
        fi

        echo -e "\n${YELLOW}ヒント: 'gh run view $RUN_ID' コマンドを直接実行してみてください${NC}"
    fi

else
    # 概要モード（デフォルト）
    echo -e "${YELLOW}=== CI チェック概要 ===${NC}\n"

    # チェック結果を一時ファイルに保存
    TEMP_FILE=$(mktemp)
    gh pr checks "$PR_NUMBER" --repo "$REPO" 2>/dev/null > "$TEMP_FILE" || true

    # 失敗したチェックを抽出して表示
    FAILED_COUNT=0
    PASSED_COUNT=0
    FAILED_JOBS=()

    while IFS=$'\t' read -r job_name status duration url _; do
        if [[ "$status" == "fail" ]]; then
            echo -e "${RED}❌ FAILED: ${job_name}${NC}"
            FAILED_JOBS+=("$job_name")
            FAILED_COUNT=$((FAILED_COUNT + 1))
        elif [[ "$status" == "pass" ]]; then
            PASSED_COUNT=$((PASSED_COUNT + 1))
        fi
    done < "$TEMP_FILE"

    echo -e "\n${YELLOW}=== サマリー ===${NC}"
    echo -e "${GREEN}✅ 成功: ${PASSED_COUNT}${NC}"
    echo -e "${RED}❌ 失敗: ${FAILED_COUNT}${NC}"

    if [[ $FAILED_COUNT -gt 0 ]]; then
        echo -e "\n${YELLOW}💡 ヒント:${NC}"
        echo "失敗したジョブの詳細ログを確認するには、以下のコマンドを実行してください:"
        echo ""
        for job in "${FAILED_JOBS[@]}"; do
            echo -e "  ${BLUE}$0 $PR_NUMBER --details \"${job}\"${NC}"
        done
        echo ""
        echo -e "${YELLOW}※ --details オプションで失敗したステップの詳細ログをファイルに保存します${NC}"
        echo -e "${YELLOW}   保存されたファイルのパスとサイズが表示され、任意のエディタで確認できます${NC}"
    fi

    rm -f "$TEMP_FILE"
fi

echo ""