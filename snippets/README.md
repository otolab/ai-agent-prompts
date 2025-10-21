# Snippets - 再利用可能なスクリプト集

プロジェクト横断で利用可能な汎用スクリプト。詳細は各ディレクトリのREADME.mdを参照。

## [common-github/](common-github/) - GitHub操作

- **set-issue-relationships.sh** - Issue親子関係の設定（単一/複数子Issue対応）
- **search-code.sh** - コード検索（自動ページネーション、行番号特定、100件以上対応）
- **check-ci-errors.sh** - PR CI状態の確認とエラーログ取得

## [rediscloud-gcp-secrets/](rediscloud-gcp-secrets/) - RedisCloud証明書管理

- **fetch_redis_certificates.sh** - GCP Secret Managerから証明書一括取得
- **analyze_certificate_groups.sh** - 証明書重複検出とSHA256分析
- **validate_terraform_certificates.sh** - Terraform証明書検証
- **check_certificate_updates.sh** - 証明書更新履歴確認

---
詳細・使用例: 各ディレクトリのREADME.md | 新規追加: [CONTRIBUTING.md](CONTRIBUTING.md)