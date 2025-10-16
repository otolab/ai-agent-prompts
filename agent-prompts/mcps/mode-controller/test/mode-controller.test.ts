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

  describe('mode_list', () => {
    it('利用可能なモード一覧を取得できる', async () => {
      const response = await tester.callTool('mode_list', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const result = response.result;
      expect(result).toBeDefined();
      expect(result.content).toBeInstanceOf(Array);
      expect(result.content[0].type).toBe('text');

      const text = result.content[0].text;
      expect(text).toContain('利用可能な動作モード');
      expect(text).toContain('test_mode_with_metadata');
      expect(text).toContain('test_mode_without_metadata');
    });
  });

  describe('mode_enter', () => {
    it('メタデータ付きモードを開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: 'test_mode_with_metadata'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）開始】');
      expect(text).toContain('YAMLフロントマターの処理をテスト');
    });

    it('メタデータなしモードを開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: 'test_mode_without_metadata'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【test_mode_without_metadata開始】');
      expect(text).toContain('メタデータがなくても正しく動作');
    });

    it('複数のモードを同時に開始できる', async () => {
      const response = await tester.callTool('mode_enter', {
        modes: ['test_mode_with_metadata', 'test_mode_without_metadata']
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）開始】');
      expect(text).toContain('【test_mode_without_metadata開始】');
      expect(text).toContain('────────────────────────────────────────'); // 区切り線
    });

    it('存在しないモードはエラーになる', async () => {
      const response = await tester.callTool('mode_enter', { modes: 'non_existent' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true); // エラーでもsuccessはtrue
      expect(response.result.isError).toBe(true);

      const text = response.result.content[0].text;
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

      const text = response.result.content[0].text;
      expect(text).toContain('現在のモード: なし');
      expect(text).toContain('待機中');
    });

    it('単一モード設定時のステータスを確認できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      const response = await tester.callTool('mode_status', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('アクティブなモード (1個)');
      expect(text).toContain('テストモード（メタデータ付き）');
    });

    it('複数モード設定時のステータスを確認できる', async () => {
      // 複数モードを開始
      await tester.callTool('mode_enter', {
        modes: ['test_mode_with_metadata', 'test_mode_without_metadata']
      });

      const response = await tester.callTool('mode_status', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('アクティブなモード (2個)');
      expect(text).toContain('テストモード（メタデータ付き）');
      expect(text).toContain('test_mode_without_metadata');
    });
  });

  describe('mode_show', () => {
    it('アクティブなモードの内容を再表示できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      // モードの内容を再表示
      const response = await tester.callTool('mode_show', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）（現在アクティブ）】');
      expect(text).toContain('YAMLフロントマターの処理をテスト');
    });

    it('特定のモードの内容を表示できる', async () => {
      // 複数モードを開始
      await tester.callTool('mode_enter', {
        modes: ['test_mode_with_metadata', 'test_mode_without_metadata']
      });

      // 特定のモードを指定して表示
      const response = await tester.callTool('mode_show', {
        mode: 'test_mode_without_metadata'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【test_mode_without_metadata（現在アクティブ）】');
      expect(text).toContain('メタデータがなくても正しく動作');
    });

    it('モード未設定時の表示処理', async () => {
      // モードを終了してから表示を試みる
      await tester.callTool('mode_exit', {});

      const response = await tester.callTool('mode_show', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('現在アクティブなモードはありません');
    });
  });

  describe('mode_exit', () => {
    it('全アクティブモードを終了できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      // モードを終了（引数なし）
      const response = await tester.callTool('mode_exit', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
      expect(text).toContain('メタデータが正しく処理されました');
    });

    it('特定のモードを指定して終了できる', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      // 同じモードを指定して終了
      const response = await tester.callTool('mode_exit', { modes: 'test_mode_with_metadata' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
    });

    it('複数モードを同時に終了できる', async () => {
      // 複数モードを開始
      await tester.callTool('mode_enter', {
        modes: ['test_mode_with_metadata', 'test_mode_without_metadata']
      });

      // 複数モードを指定して終了
      const response = await tester.callTool('mode_exit', {
        modes: ['test_mode_with_metadata', 'test_mode_without_metadata']
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【テストモード（メタデータ付き）終了】');
      expect(text).toContain('【test_mode_without_metadata終了】');
      expect(text).toContain('────────────────────────────────────────'); // 区切り線
    });

    it('異なるモードを指定した場合はエラー', async () => {
      // モードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      // 異なるモードを指定して終了
      const response = await tester.callTool('mode_exit', { modes: 'test_mode_without_metadata' });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('モード \'test_mode_without_metadata\' は現在アクティブではありません');
    });

    it('モード未設定時の終了処理', async () => {
      // 前のテストでモードが残っている可能性があるので、まず終了
      await tester.callTool('mode_exit', {});

      // 改めて終了を試みる
      const response = await tester.callTool('mode_exit', {});

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('現在アクティブなモードはありません');
    });
  });

  describe('モードの切り替え', () => {
    it('モードを追加できる', async () => {
      // 最初のモードを開始
      await tester.callTool('mode_enter', { modes: 'test_mode_with_metadata' });

      // 別のモードを追加（両方アクティブになる）
      const response = await tester.callTool('mode_enter', {
        modes: 'test_mode_without_metadata'
      });

      expect(response).toBeDefined();
      expect(response.success).toBe(true);

      const text = response.result.content[0].text;
      expect(text).toContain('【test_mode_without_metadata開始】');

      // ステータス確認（両方のモードがアクティブ）
      const statusResponse = await tester.callTool('mode_status', {});
      const statusText = statusResponse.result.content[0].text;
      expect(statusText).toContain('アクティブなモード (2個)');
      expect(statusText).toContain('test_mode_with_metadata');
      expect(statusText).toContain('test_mode_without_metadata');
    });
  });
});