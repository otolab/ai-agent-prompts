#!/bin/bash

# 取得した証明書をSHA256ハッシュで分析し、重複を検出するスクリプト
# 使用方法: ./analyze_certificate_groups.sh [certs_dir]

# 環境変数または引数から設定を取得
CERTS_DIR="${1:-${CERTS_DIR:-./redis_certificates}}"

echo "=== Redis証明書グループ分析 ==="
echo "分析対象: $CERTS_DIR"
echo ""

if [ ! -d "$CERTS_DIR" ]; then
  echo "エラー: ディレクトリが存在しません: $CERTS_DIR"
  exit 1
fi

# 一時ファイルでハッシュとメタデータを収集
HASH_FILE=$(mktemp) || { echo "エラー: 一時ファイルを作成できません" >&2; exit 1; }
trap "rm -f $HASH_FILE" EXIT

echo "証明書を分析中..."
echo ""

# 各証明書のSHA256ハッシュを計算
for cert_file in "$CERTS_DIR"/*.pem; do
  if [ -f "$cert_file" ]; then
    basename=$(basename "$cert_file" .pem)
    hash=$(openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | cut -d'=' -f2)
    if [ -n "$hash" ]; then
      echo "$hash:$basename" >> "$HASH_FILE"
    fi
  fi
done

# ファイルが見つからない場合
if [ ! -s "$HASH_FILE" ]; then
  echo "警告: 証明書ファイル (*.pem) が見つかりません"
  rm -f "$HASH_FILE"
  exit 1
fi

# 重複をチェックしてグループ化
echo "=== 証明書グループ分析結果 ==="
echo "実行日時: $(date)"
echo ""

# ハッシュごとにグループ化して表示
sort "$HASH_FILE" | awk -F: '
{
  hash=$1
  name=$2
  if (hash in groups) {
    groups[hash] = groups[hash] ", " name
    count[hash]++
  } else {
    groups[hash] = name
    count[hash] = 1
  }
}
END {
  # グループをサイズ順にソート
  for (h in count) {
    sizes[count[h]] = sizes[count[h]] " " h
  }

  # 大きいグループから表示
  group_letter = 65  # ASCII 'A'

  for (size=20; size>=2; size--) {
    if (size in sizes) {
      n = split(sizes[size], hashes, " ")
      for (i=1; i<=n; i++) {
        if (hashes[i] != "") {
          hash = hashes[i]
          printf "グループ %c: %s\n", group_letter, groups[hash]
          printf "  SHA256: %s\n", hash
          printf "  サービス数: %d\n", count[hash]
          printf "\n"
          group_letter++
        }
      }
    }
  }

  # 個別の証明書を表示
  if (1 in sizes) {
    print "=== 個別証明書（グループなし） ==="
    n = split(sizes[1], hashes, " ")
    for (i=1; i<=n; i++) {
      if (hashes[i] != "") {
        hash = hashes[i]
        printf "- %s\n", groups[hash]
        printf "  SHA256: %s...\n", substr(hash, 1, 16)
        printf "\n"
      }
    }
  }
}'

# 各グループの詳細情報を表示
echo ""
echo "=== グループ詳細情報 ==="
echo ""

# グループごとに代表証明書の情報を表示
sort "$HASH_FILE" | awk -F: '
{
  hash=$1
  name=$2
  if (!(hash in seen)) {
    seen[hash] = name
    count[hash] = 1
  } else {
    count[hash]++
  }
}
END {
  group_letter = 65  # ASCII 'A'
  for (h in count) {
    if (count[h] >= 2) {
      printf "グループ %c 代表証明書情報:\n", group_letter
      print "  代表: " seen[h] ".pem"
      group_letter++
    }
  }
}' | while IFS= read -r line; do
  echo "$line"
  if [[ "$line" == *"代表:"* ]]; then
    cert_name=$(echo "$line" | sed 's/.*代表: //')
    if [ -f "$CERTS_DIR/$cert_name" ]; then
      # 証明書の詳細情報を表示
      not_after=$(openssl x509 -in "$CERTS_DIR/$cert_name" -noout -enddate 2>/dev/null | sed 's/notAfter=//')
      subject=$(openssl x509 -in "$CERTS_DIR/$cert_name" -noout -subject 2>/dev/null | sed 's/subject=//')
      echo "  有効期限: $not_after"
      echo "  Subject: $subject"
      echo ""
    fi
  fi
done

# 統計情報
total_certs=$(wc -l < "$HASH_FILE")
unique_count=$(cut -d: -f1 "$HASH_FILE" | sort -u | wc -l)

echo ""
echo "=== サマリー ==="
echo "総証明書数: $total_certs"
echo "ユニーク証明書数: $unique_count"
if [ $total_certs -gt 0 ]; then
  echo "重複率: $(( (total_certs - unique_count) * 100 / total_certs ))%"
fi