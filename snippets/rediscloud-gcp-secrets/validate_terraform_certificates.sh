#!/bin/bash

# Terraformファイル（certificates.tf）から証明書を抽出して検証するスクリプト
# 使用方法: ./validate_terraform_certificates.sh [certificates.tf のパス]

# 環境変数または引数から設定を取得
TF_FILE="${1:-${TF_CERTIFICATES_PATH:-./certificates.tf}}"
EXTRACT_DIR="${EXTRACT_DIR:-./extracted_terraform_certs}"

# 色付き出力用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Terraform証明書検証スクリプト ==="
echo "入力ファイル: $TF_FILE"
echo ""

if [ ! -f "$TF_FILE" ]; then
  echo -e "${RED}エラー: ファイルが存在しません: $TF_FILE${NC}"
  exit 1
fi

# 抽出ディレクトリを作成
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

# 証明書変数名のリスト（環境変数から取得または デフォルト値）
if [ -n "$TF_CERT_VARS" ]; then
  IFS=',' read -ra CERT_VARS <<< "$TF_CERT_VARS"
else
  CERT_VARS=("dummy")
fi

echo "証明書を抽出中..."
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0
NOT_FOUND_COUNT=0

# 各証明書を抽出して検証
for cert_var in "${CERT_VARS[@]}"; do
  echo -n "[$cert_var] "

  # awkを使って証明書を抽出
  awk "
    /^[[:space:]]*${cert_var}[[:space:]]*=.*<<EOT/ {
      found=1
      next
    }
    found && /^EOT$/ {
      exit
    }
    found {
      print
    }
  " "$TF_FILE" > "$EXTRACT_DIR/${cert_var}.pem"

  if [ -s "$EXTRACT_DIR/${cert_var}.pem" ]; then
    # 証明書として有効かチェック
    if openssl x509 -in "$EXTRACT_DIR/${cert_var}.pem" -text -noout > /dev/null 2>&1; then
      # 有効期限を確認
      not_after=$(openssl x509 -in "$EXTRACT_DIR/${cert_var}.pem" -noout -enddate 2>/dev/null | sed 's/notAfter=//')

      # 期限切れチェック
      if openssl x509 -in "$EXTRACT_DIR/${cert_var}.pem" -checkend 0 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 有効${NC} (期限: $not_after)"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}✗ 期限切れ${NC} ($not_after)"
        ((FAIL_COUNT++))
      fi
    else
      echo -e "${RED}✗ 無効な証明書形式${NC}"
      ((FAIL_COUNT++))
    fi
  else
    echo -e "${YELLOW}- 見つからない${NC}"
    ((NOT_FOUND_COUNT++))
    rm -f "$EXTRACT_DIR/${cert_var}.pem"
  fi
done

# サマリー
echo ""
echo "=== 検証サマリー ==="
echo -e "有効: ${GREEN}$SUCCESS_COUNT${NC}"
echo -e "無効/期限切れ: ${RED}$FAIL_COUNT${NC}"
echo -e "見つからない: ${YELLOW}$NOT_FOUND_COUNT${NC}"
echo "合計: $((SUCCESS_COUNT + FAIL_COUNT + NOT_FOUND_COUNT))"

# 重複チェック
echo ""
echo "=== 重複証明書チェック ==="

# SHA256でグループ化
HASH_FILE=$(mktemp) || { echo "エラー: 一時ファイルを作成できません" >&2; exit 1; }
trap "rm -f $HASH_FILE" EXIT

for cert_file in "$EXTRACT_DIR"/*.pem; do
  if [ -f "$cert_file" ] && openssl x509 -in "$cert_file" -text -noout > /dev/null 2>&1; then
    cert_name=$(basename "$cert_file" .pem)
    hash=$(openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | cut -d'=' -f2)
    echo "$hash:$cert_name" >> "$HASH_FILE"
  fi
done

# 重複をチェック
if [ -s "$HASH_FILE" ]; then
  sort "$HASH_FILE" | awk -F: '
  {
    hash=$1
    name=$2
    if (hash in seen) {
      seen[hash] = seen[hash] ", " name
      dup[hash] = 1
    } else {
      seen[hash] = name
    }
  }
  END {
    found=0
    for (h in dup) {
      found=1
      print "⚠ 同一証明書が複数の変数で使用されています:"
      print "  SHA256: " substr(h, 1, 16) "..."
      print "  変数: " seen[h]
      print ""
    }
    if (found == 0) {
      print "✓ 重複する証明書はありません"
    }
  }'
else
  echo "検証可能な証明書がありません"
fi

echo ""
echo "抽出した証明書: $EXTRACT_DIR/"