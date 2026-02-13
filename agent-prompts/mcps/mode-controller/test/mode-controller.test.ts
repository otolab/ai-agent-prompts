import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { createMCPTester, MCPServiceE2ETester } from '@coeiro-operator/mcp-debug';
import * as path from 'path';

describe('Mode Controller MCP Server', () => {
  let tester: MCPServiceE2ETester;
  const testModesPath = path.join(process.cwd(), 'test-modes');

  beforeAll(async () => {
    // MCPサーバーを起動
    tester = await createMCPTester({
      serverPath: path.join(process.cwd(), 'dist/server.js'),
      args: [
        '--modes-path',
        testModesPath
      ],
      env: {
        ...process.env,
        NODE_ENV: 'test'
      }
    });
  });

  afterAll(async () => {
    // サーバーを停止
    if (tester) {
      await tester.stop();
    }
  });

  describe('mode_enter', () => {
    it('メタデータ付きモードを開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: 'test_with_meta'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）開始】');
      expect(text).toContain('ファイル:');
    });

    it('メタデータなしモードを開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: 'test_without_meta'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【test_mode_without_metadata開始】');
      expect(text).toContain('ファイル:');
    });

    it('複数のモードを同時に開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: ['test_with_meta', 'test_without_meta']
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）開始】');
      expect(text).toContain('【test_mode_without_metadata開始】');
      expect(text).toContain('────────────────────────────────────────'); // 区切り線
    });

    it('存在しないモードはエラーになる', async () => {
      const response = await tester.callTool('mode_enter', { modes: 'non_existent' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true); // エラーでもsuccessはtrue
      expect((response.result as any).isError).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('モード \'non_existent\' が見つかりません');
    });
  });

  describe('mode_status', () => {
    it('モード未設定時のステータスを確認できる', async () => {
      // 先に終了してから状態確認
      await tester.callTool('mode_exit', {});

      const response = await tester.callTool('mode_status', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('現在のモード: なし');
    });

    it('単一モード設定時のステータスを確認できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      const response = await tester.callTool('mode_status', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('アクティブなモード (1個)');
      expect(text).toContain('テストモード（メタデータ付き）');
    });

    it('複数モード設定時のステータスを確認できる', async () => {
      // 複数モードを開始
      await tester.callTool('mode_enter', {
        modes: ['test_with_meta', 'test_without_meta']
      });

      const response = await tester.callTool('mode_status', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('アクティブなモード (2個)');
      expect(text).toContain('テストモード（メタデータ付き）');
      expect(text).toContain('test_mode_without_metadata');
    });
  });

  describe('mode_exit', () => {
    it('全アクティブモードを終了できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      // モードを終了（引数なし）
      const response = await tester.callTool('mode_exit', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
      expect(text).toContain('メタデータが正しく処理されました');
    });

    it('特定のモードを指定して終了できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      // 同じモードを指定して終了
      const response = await tester.callTool('mode_exit', { modes: 'test_with_meta' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
    });

    it('複数モードを同時に終了できる', async () => {
      // 複数モードを開始
      await tester.callTool('mode_enter', {
        modes: ['test_with_meta', 'test_without_meta']
      });

      // 複数モードを指定して終了
      const response = await tester.callTool('mode_exit', {
        modes: ['test_with_meta', 'test_without_meta']
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
      expect(text).toContain('【test_mode_without_metadata終了】');
      expect(text).toContain('────────────────────────────────────────'); // 区切り線
    });

    it('異なるモードを指定した場合はエラー', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      // 異なるモードを指定して終了
      const response = await tester.callTool('mode_exit', { modes: 'test_without_meta' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('モード \'test_without_meta\' は現在アクティブではありません');
    });

    it('モード未設定時の終了処理', async () => {
      // 前のテストでモードが残っている可能性があるので、まず終了
      await tester.callTool('mode_exit', {});

      // 改めて終了を試みる
      const response = await tester.callTool('mode_exit', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('現在アクティブなモードはありません');
    });
  });

  describe('モードの切り替え', () => {
    it('モードを追加できる', async () => {
      // 最初のモードを開始
      await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      // 別のモードを追加（両方アクティブになる）
      const response = await tester.callTool('mode_enter', {
        modes: 'test_without_meta'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      expect(text).toContain('【test_mode_without_metadata開始】');

      // ステータス確認（両方のモードがアクティブ）
      const statusResponse = await tester.callTool('mode_status', {});
      const statusText = (statusResponse.result as any).content[0].text;
      expect(statusText).toContain('アクティブなモード (2個)');
      expect(statusText).toContain('テストモード（メタデータ付き）');
      expect(statusText).toContain('test_mode_without_metadata');
    });
  });

  describe('fullContent機能', () => {
    it('fullContent: trueの場合、mode_enterでファイル内容を直接出力', async () => {
      // fullContent: trueのモードを開始
      const response = await tester.callTool('mode_enter', { modes: 'test_env_setup' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      // モード開始メッセージ
      expect(text).toContain('【テスト環境セットアップモード開始】');
      // ファイル内容が直接出力されている
      expect(text).toContain('このモードはfullContent機能と@参照解決機能のテスト用です');
      // ファイル読み込み指示ではない
      expect(text).not.toContain('TodoWriteツールで以下のファイルの読み込みを最優先');
    });

    it('@参照が解決されて参照ファイルの内容も出力される', async () => {
      // fullContent: trueのモードを開始（@参照を含む）
      const response = await tester.callTool('mode_enter', { modes: 'test_env_setup' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      // 元のファイル内容
      expect(text).toContain('このモードはfullContent機能と@参照解決機能のテスト用です');
      // 参照ファイルの内容（---で分割されている）
      expect(text).toContain('この内容は@参照によって読み込まれます');
    });

    it('fullContent: falseまたは未指定の場合、従来通りファイル読み込み指示を出力', async () => {
      // fullContent未指定のモードを開始
      const response = await tester.callTool('mode_enter', { modes: 'test_with_meta' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;
      // ファイル読み込み指示
      expect(text).toContain('TodoWriteツールで以下のファイルの読み込みを最優先');
      // ファイル内容は出力されない
      expect(text).not.toContain('YAMLフロントマターの処理をテスト');
    });

    it('ENV_SETUP_MODEの実際の出力を確認（デバッグ用）', async () => {
      // ENV_SETUP_MODEを開始
      const response = await tester.callTool('mode_enter', { modes: 'test_real_env_setup' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      // 実際の出力を表示
      const text = (response.result as any).content[0].text;
      console.log('\n========================================');
      console.log('ENV_SETUP_MODE 実際の出力');
      console.log('========================================');
      console.log(text);
      console.log('========================================\n');
    });

    it('様々な@参照パターンが検出される', async () => {
      // 参照パターンテストモードを開始
      const response = await tester.callTool('mode_enter', { modes: 'test_ref_patterns' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = (response.result as any).content[0].text;

      // 元のファイル内容
      expect(text).toContain('様々な@参照パターンのテスト用です');

      // 参照ファイルの内容が読み込まれている（---で分割）
      expect(text).toContain('この内容は@参照によって読み込まれます');

      console.log('\n========================================');
      console.log('参照パターンテスト 出力');
      console.log('========================================');
      console.log(text);
      console.log('========================================\n');
    });
  });

  describe('resources', () => {
    it('resources/listでリソース一覧を取得できる', async () => {
      const response = await tester.sendRequest('resources/list', {}) as any;

      expect(response).toBeDefined();

      const resources = response.resources;
      expect(resources).toBeInstanceOf(Array);
      expect(resources.length).toBeGreaterThan(0);

      // mode://available が含まれる
      const availableResource = resources.find((r: any) => r.uri === 'mode://available');
      expect(availableResource).toBeDefined();

      // 動的リソースのリスト（各モード）
      const modeResources = resources.filter((r: any) => r.uri.startsWith('mode://mode/'));
      expect(modeResources.length).toBeGreaterThan(0);
    });

    it('mode://availableで利用可能モード一覧をJSON取得できる', async () => {
      const response = await tester.sendRequest('resources/read', { uri: 'mode://available' }) as any;

      expect(response).toBeDefined();

      const contents = response.contents;
      expect(contents).toBeInstanceOf(Array);
      expect(contents[0].uri).toBe('mode://available');

      const modes = JSON.parse(contents[0].text);
      expect(modes).toBeInstanceOf(Array);
      expect(modes.length).toBeGreaterThan(0);

      // 各モードにname, displayNameがある
      const mode = modes[0];
      expect(mode).toHaveProperty('name');
      expect(mode).toHaveProperty('displayName');
    });

    it('mode://mode/{modeName}でモード内容を取得できる', async () => {
      const response = await tester.sendRequest('resources/read', { uri: 'mode://mode/test_with_meta' }) as any;

      expect(response).toBeDefined();

      const contents = response.contents;
      expect(contents).toBeInstanceOf(Array);
      expect(contents[0].uri).toBe('mode://mode/test_with_meta');
      expect(contents[0].text).toContain('YAMLフロントマターの処理をテスト');
    });

    it('fullContentモードの@参照が解決される', async () => {
      const response = await tester.sendRequest('resources/read', { uri: 'mode://mode/test_env_setup' }) as any;

      expect(response).toBeDefined();

      const text = response.contents[0].text;
      // @参照が解決されている
      expect(text).toContain('この内容は@参照によって読み込まれます');
    });

    it('存在しないモードでエラーが返る', async () => {
      await expect(
        tester.sendRequest('resources/read', { uri: 'mode://mode/non_existent' })
      ).rejects.toThrow();
    });
  });
});
