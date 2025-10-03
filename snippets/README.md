# Snippets - 再利用可能なスクリプト・ツール集

様々なプロジェクトで再利用可能な汎用的なスクリプト集です。

## 利用可能なスニペット

### [common-github/](common-github/) - GitHub関連の共通スクリプト
- `set-issue-relationship.sh` - GitHub Issues間の親子関係を設定
- `set-multiple-issue-relationships.sh` - 一つの親Issueに複数の子Issueを一括設定
- `check-ci-errors.sh` - GitHub CI/CDのエラーチェックと詳細表示

### [rediscloud-gcp-secrets/](rediscloud-gcp-secrets/) - RedisCloud証明書管理
- `fetch_redis_certificates.sh` - GCP Secret Managerから証明書を一括取得
- `analyze_certificate_groups.sh` - 証明書の重複検出とSHA256ハッシュ分析
- `validate_terraform_certificates.sh` - Terraformファイルの証明書検証
- `check_certificate_updates.sh` - 証明書の更新履歴とバージョン確認

## その他

- **[スニペット作成ガイドライン](CONTRIBUTING.md)** - 新規スニペット追加時の規約
- 各スニペットの詳細は各ディレクトリ内のREADME.mdを参照

---
**作成**: 2025年9月26日
**最終更新**: 2025年10月1日