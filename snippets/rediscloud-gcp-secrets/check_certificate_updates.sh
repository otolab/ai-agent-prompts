#!/bin/bash

# GCP Secretsの更新履歴を確認し、最新の証明書を特定するスクリプト
# 使用方法: ./check_certificate_updates.sh [project-id]

# 環境変数または引数から設定を取得
PROJECT="${1:-${GCP_PROJECT_EVALUATION}}"
if [ -z "$PROJECT" ]; then
  echo "エラー: GCP_PROJECT_EVALUATIONが設定されていません" >&2
  echo "使用方法: GCP_PROJECT_EVALUATION=your-project ./check_certificate_updates.sh" >&2
  echo "    または: ./check_certificate_updates.sh your-project" >&2
  exit 1
fi

echo "=== GCP Secrets 証明書更新履歴 ==="
echo "プロジェクト: $PROJECT"
echo "確認日時: $(date)"
echo ""

# Redis関連のシークレット一覧を取得
echo "Redis関連のシークレットを検索中..."
SECRETS=$(gcloud secrets list --project="$PROJECT" --format="value(name)" --filter="name:redis OR name:redislab" 2>/dev/null)

if [ -z "$SECRETS" ]; then
  echo "Redis関連のシークレットが見つかりません"
  exit 1
fi

# 証明書タイプを判定する関数
get_cert_type() {
  local secret_name=$1
  if [[ "$secret_name" == *"_ca"* ]]; then
    echo "CA証明書"
  elif [[ "$secret_name" == *"_private"* ]] || [[ "$secret_name" == *"_key"* ]]; then
    echo "秘密鍵"
  elif [[ "$secret_name" == *"_password"* ]] || [[ "$secret_name" == *"_pass"* ]]; then
    echo "パスワード"
  elif [[ "$secret_name" == *"_crt"* ]] || [[ "$secret_name" == *"_cert"* ]] || [[ "$secret_name" == *"_user"* ]]; then
    echo "クライアント証明書"
  else
    echo "不明"
  fi
}

# 更新情報を一時ファイルに保存
TEMP_FILE=$(mktemp) || { echo "エラー: 一時ファイルを作成できません" >&2; exit 1; }
trap "rm -f $TEMP_FILE" EXIT

echo "更新履歴を取得中..."
for secret in $SECRETS; do
  # 最新バージョンの情報を取得
  latest_info=$(gcloud secrets versions list "$secret" \
    --project="$PROJECT" \
    --format="value(name,createTime,state)" \
    --limit=1 2>/dev/null)

  if [ -n "$latest_info" ]; then
    version=$(echo "$latest_info" | cut -f1)
    create_time=$(echo "$latest_info" | cut -f2)
    state=$(echo "$latest_info" | cut -f3)
    cert_type=$(get_cert_type "$secret")

    # タイムスタンプを秒に変換（ソート用）
    timestamp=$(date -d "$create_time" +%s 2>/dev/null || echo "0")

    echo -e "$timestamp\t$create_time\t$secret\t$version\t$state\t$cert_type" >> "$TEMP_FILE"
  fi
done

# 更新日時でソート（新しい順）
echo ""
echo "=== 最近更新された証明書（上位20件） ==="
echo ""
printf "%-20s %-50s %-8s %-10s %-20s\n" "更新日時" "シークレット名" "Ver" "状態" "タイプ"
echo "--------------------------------------------------------------------------------"

sort -rn "$TEMP_FILE" | head -20 | while IFS=$'\t' read -r timestamp create_time secret version state cert_type; do
  # 日付をフォーマット
  formatted_date=$(echo "$create_time" | cut -d'T' -f1)
  printf "%-20s %-50s %-8s %-10s %-20s\n" "$formatted_date" "$secret" "v$version" "$state" "$cert_type"
done

# 証明書グループごとの最新更新を表示
echo ""
echo "=== サービス別の最新更新 ==="
echo ""

# 主要なサービスパターン（環境変数から取得可能）
if [ -n "$SERVICE_PATTERNS" ]; then
  IFS=',' read -ra services <<< "$SERVICE_PATTERNS"
else
  services=(
    "rewrite"
    "voc"
    "speak"
    "miru"
    "mila"
    "session"
    "evaluation"
    "jobflow"
    "datahub"
    "issues"
    "signals"
    "mirror"
  )
fi

for service in "${services[@]}"; do
  latest=$(grep -i "$service" "$TEMP_FILE" | grep "クライアント証明書" | sort -rn | head -1)
  if [ -n "$latest" ]; then
    create_time=$(echo "$latest" | cut -f2)
    secret=$(echo "$latest" | cut -f3)
    version=$(echo "$latest" | cut -f4)
    formatted_date=$(echo "$create_time" | cut -d'T' -f1)
    printf "%-15s: %-50s (v%-3s) %s\n" "$service" "$secret" "$version" "$formatted_date"
  fi
done

# 統計情報
echo ""
echo "=== 統計情報 ==="
total_secrets=$(wc -l < "$TEMP_FILE")
client_certs=$(grep -c "クライアント証明書" "$TEMP_FILE")
ca_certs=$(grep -c "CA証明書" "$TEMP_FILE")
private_keys=$(grep -c "秘密鍵" "$TEMP_FILE")
passwords=$(grep -c "パスワード" "$TEMP_FILE")

echo "総シークレット数: $total_secrets"
echo "  - クライアント証明書: $client_certs"
echo "  - CA証明書: $ca_certs"
echo "  - 秘密鍵: $private_keys"
echo "  - パスワード: $passwords"

# 特定期間の更新を表示（オプション）
if [ -n "$CHECK_PERIOD" ]; then
  echo ""
  echo "=== $CHECK_PERIOD の証明書更新 ==="
  period_updates=$(grep "$CHECK_PERIOD" "$TEMP_FILE" | grep "クライアント証明書")
  if [ -n "$period_updates" ]; then
    echo "$period_updates" | while IFS=$'\t' read -r timestamp create_time secret version state cert_type; do
      formatted_date=$(echo "$create_time" | cut -d'T' -f1)
      printf "  %s: %s (v%s)\n" "$formatted_date" "$secret" "$version"
    done
  else
    echo "  該当なし"
  fi
fi