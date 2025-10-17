#!/bin/bash

# GCP Secretsから Redis関連証明書を取得するスクリプト
# 使用方法: ./fetch_redis_certificates.sh

# 環境変数または引数から設定を取得
PROJECT="${1:-${GCP_PROJECT_EVALUATION}}"
CERTS_DIR="${2:-${CERTS_DIR:-./redis_certificates}}"

# certsディレクトリを作成
mkdir -p "$CERTS_DIR"

# 証明書リストを環境変数から取得（カンマ区切り）
if [ -n "$CERTIFICATE_LIST" ]; then
  IFS=',' read -ra CERTIFICATES <<< "$CERTIFICATE_LIST"
else
  # デフォルトリスト（環境変数が設定されていない場合）
  CERTIFICATES=(
    "dummy"
    # 必要に応じて追加
  )
fi

echo "=== GCP Secretsから証明書を取得開始 ==="
echo "プロジェクト: $PROJECT"
echo "保存先: $CERTS_DIR"
echo ""

# 成功・失敗カウンター
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_CERTS=()

# 各証明書を取得
for cert in "${CERTIFICATES[@]}"; do
  echo -n "[$((SUCCESS_COUNT + FAIL_COUNT + 1))/${#CERTIFICATES[@]}] $cert ... "

  # GCP Secretから取得
  if gcloud secrets versions access latest \
    --secret="$cert" \
    --project="$PROJECT" \
    > "$CERTS_DIR/${cert}.pem" 2>/dev/null; then

    # 証明書として有効か確認
    if openssl x509 -in "$CERTS_DIR/${cert}.pem" -text -noout > /dev/null 2>&1; then
      echo "✓ 取得成功"
      ((SUCCESS_COUNT++))
    else
      echo "✗ 無効な証明書形式"
      rm -f "$CERTS_DIR/${cert}.pem"
      FAILED_CERTS+=("$cert (無効な形式)")
      ((FAIL_COUNT++))
    fi
  else
    echo "✗ 取得失敗"
    rm -f "$CERTS_DIR/${cert}.pem"
    FAILED_CERTS+=("$cert (取得エラー)")
    ((FAIL_COUNT++))
  fi
done

echo ""
echo "=== 取得完了 ==="
echo "成功: $SUCCESS_COUNT / ${#CERTIFICATES[@]}"
echo "失敗: $FAIL_COUNT / ${#CERTIFICATES[@]}"

if [ $FAIL_COUNT -gt 0 ]; then
  echo ""
  echo "=== 失敗した証明書 ==="
  for failed in "${FAILED_CERTS[@]}"; do
    echo "  - $failed"
  done
fi

# 詳細表示はオプション（-v フラグ使用時のみ）
if [[ "$*" == *"-v"* ]]; then
  echo ""
  echo "=== 取得した証明書の詳細 ==="
  for cert_file in "$CERTS_DIR"/*.pem; do
    if [ -f "$cert_file" ]; then
      basename=$(basename "$cert_file")
      echo ""
      echo "--- $basename ---"
      openssl x509 -in "$cert_file" -text -noout 2>/dev/null | grep -E "Subject:|Issuer:|Not After" | head -3
    fi
  done
fi