# RedisCloud / GCP Secrets 管理スクリプト集

## 概要
RedisCloudで使用するTLS証明書をGCP Secret Managerから取得・管理するためのスクリプト集です。

## スクリプト一覧

### 1. `fetch_redis_certificates.sh`
GCP Secret Managerから Redis関連の証明書を一括取得するスクリプト。

**使用方法:**
```bash
# 環境変数を使用
source .env
./fetch_redis_certificates.sh

# 引数で指定
./fetch_redis_certificates.sh [project-id] [certs-dir]

# 詳細表示モード
./fetch_redis_certificates.sh -v
```

### 2. `analyze_certificate_groups.sh`
取得した証明書をSHA256ハッシュで分析し、重複を検出するスクリプト。

**使用方法:**
```bash
# 環境変数を使用
source .env
./analyze_certificate_groups.sh

# 引数で指定
./analyze_certificate_groups.sh [certs-dir]
```

### 3. `validate_terraform_certificates.sh`
Terraformファイル（certificates.tf）から証明書を抽出して検証するスクリプト。

**使用方法:**
```bash
# 環境変数を使用
source .env
./validate_terraform_certificates.sh

# 引数で指定
./validate_terraform_certificates.sh [certificates.tf-path]
```

### 4. `check_certificate_updates.sh`
GCP Secretsの更新履歴を確認し、最新の証明書を特定するスクリプト。

**使用方法:**
```bash
# 環境変数を使用
source .env
./check_certificate_updates.sh

# 引数で指定
./check_certificate_updates.sh [project-id]

# 特定期間の更新をチェック
CHECK_PERIOD="2023-10" ./check_certificate_updates.sh
```

## 必要な環境
- Google Cloud SDK (`gcloud`)
- OpenSSL
- bash 4.0以上

## セットアップ

### 環境変数の設定方法

1. **環境変数を直接設定する方法**
   ```bash
   export GCP_PROJECT_EVALUATION="your-evaluation-project-id"
   export CERTS_DIR="./redis_certificates"
   ./fetch_redis_certificates.sh
   ```

2. **コマンドライン引数で指定する方法**
   ```bash
   # 引数で直接指定（環境変数より優先）
   ./fetch_redis_certificates.sh your-project-id ./output-dir
   ```

3. **.envファイルを使用する方法（オプション）**
   ```bash
   # .envファイルを作成して環境変数を定義
   echo 'GCP_PROJECT_EVALUATION="your-project-id"' > .env
   source .env
   ./fetch_redis_certificates.sh
   ```

## 環境変数リスト

### 共通環境変数

| 環境変数 | 必須 | 説明 | デフォルト値 |
|---------|------|------|------------|
| GCP_PROJECT_EVALUATION | △ | Evaluationプロジェクト ID | なし（引数で指定可） |
| GCP_PROJECT_DEVELOP | × | Developプロジェクト ID | なし |

### スクリプト別環境変数

#### fetch_redis_certificates.sh

| 環境変数 | 必須 | 説明 | デフォルト値 |
|---------|------|------|------------|
| GCP_PROJECT_EVALUATION | △ | GCPプロジェクトID | なし（第1引数で指定可） |
| CERTS_DIR | × | 証明書保存先ディレクトリ | ./redis_certificates |
| CERTIFICATE_LIST | × | 取得する証明書名（カンマ区切り） | スクリプト内定義※1 |

#### analyze_certificate_groups.sh

| 環境変数 | 必須 | 説明 | デフォルト値 |
|---------|------|------|------------|
| CERTS_DIR | × | 分析対象ディレクトリ | ./redis_certificates |

#### validate_terraform_certificates.sh

| 環境変数 | 必須 | 説明 | デフォルト値 |
|---------|------|------|------------|
| TF_CERTIFICATES_PATH | × | certificates.tfのパス | ./certificates.tf |
| EXTRACT_DIR | × | 証明書抽出先ディレクトリ | ./extracted_terraform_certs |
| TF_CERT_VARS | × | Terraform変数名（カンマ区切り） | スクリプト内定義※2 |

#### check_certificate_updates.sh

| 環境変数 | 必須 | 説明 | デフォルト値 |
|---------|------|------|------------|
| GCP_PROJECT_EVALUATION | ○ | GCPプロジェクトID | なし（第1引数で指定可） |
| SERVICE_PATTERNS | × | サービス名パターン（カンマ区切り） | スクリプト内定義※3 |
| CHECK_PERIOD | × | 特定期間の更新確認（例: "2023-10"） | なし |

## 証明書の構成
調査により判明した証明書グループ構成：

| グループ | 証明書名 | サービス数 | 有効期限 |
|---------|---------|-----------|----------|
| A | common_certificate | 8 | 2028-09-20 |
| B | admin_certificate | 2 | 2029-01-15 |
| C-I | 個別証明書 | 各1 | 各種 |

## 注意事項
- GCP認証が必要（`gcloud auth login`）
- 適切なプロジェクトへのアクセス権限が必要
- 証明書は機密情報のため、取り扱いに注意

## 関連Issue
- Issue #130482: Redis証明書の統合管理