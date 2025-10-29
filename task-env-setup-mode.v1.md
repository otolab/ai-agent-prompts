# ENV_SETUP_MODE作成とmode-controller機能拡張

## 作業概要
セッション開始時・compact後の環境再構築用モードの作成と、mode-controllerに直接コンテンツ表示・@参照解決機能を追加

## 作業項目

### 1. ENV_SETUP_MODE作成
- [ ] `agent-prompts/prompts/modes/ENV_SETUP_MODE.md` 作成
- [ ] メタデータに `fullContent: true` を設定
- [ ] モード内容の定義
  - root.mdとprinciples.mdの表示指示
  - mode_listの表示指示
  - start-session.shの現在の出力内容を含む

### 2. mode-controller機能拡張

#### 2.1 メタデータ対応
- [ ] `ModeMetadata`インターフェースに`fullContent?: boolean`を追加
- [ ] YAMLフロントマターでの読み込み対応

#### 2.2 直接コンテンツ表示機能
- [ ] `mode_enter`でメタデータを確認
- [ ] `fullContent: true`の場合、ファイル内容を直接出力
- [ ] 出力フォーマット設計（セクション区切りなど）

#### 2.3 @参照の再帰的解決
- [ ] ファイル内容から`@`で始まるパスを検出する正規表現実装
- [ ] 相対パス解決のロジック実装
- [ ] 再帰的にファイルを読み込む関数実装
- [ ] 循環参照の検出・防止
- [ ] concat出力の実装

### 3. テスト
- [ ] ENV_SETUP_MODEの動作確認
- [ ] fullContent機能のテスト
- [ ] @参照解決のテスト（単一・複数・ネスト）
- [ ] 循環参照のエラーハンドリング確認

### 4. ドキュメント更新
- [ ] mode-controller README.md更新
- [ ] fullContent機能の説明追加
- [ ] @参照機能の説明追加

### 5. リリース
- [ ] バージョン更新（0.1.3 → 0.1.4）
- [ ] ビルド＆テスト実行
- [ ] npm publish
- [ ] git commit & push

## 技術仕様メモ

### @参照の仕様
- 形式: `@パス` （例: `@principles.md`, `@../../snippets/README.md`）
- パス解決: 現在のファイルからの相対パス
- 出力形式:
  ```
  === ファイル名 ===
  （内容）

  === 参照先ファイル1 ===
  （内容）

  === 参照先ファイル2 ===
  （内容）
  ```

### メタデータ追加
```yaml
---
mode: env_setup
displayName: 環境セットアップモード
fullContent: true  # 直接コンテンツを表示
---
```

## 優先順位
1. ENV_SETUP_MODE作成（基本版、@参照なし）
2. mode-controller fullContent対応
3. @参照解決機能実装
4. テスト・ドキュメント・リリース
