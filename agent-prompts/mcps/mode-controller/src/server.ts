#!/usr/bin/env node
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as yaml from 'js-yaml';

interface ModeMetadata {
  mode: string;
  displayName: string;
  autoTrigger?: string[];
  exitMessage?: string;
}

interface ParsedMode {
  metadata: ModeMetadata;
  body: string;
}

class ModeController {
  private activeModes: Set<string> = new Set();
  private modesPaths: string[];
  private availableModes: Map<string, ParsedMode> = new Map();

  constructor(modesPaths: string[]) {
    this.modesPaths = modesPaths;
  }

  async initialize(): Promise<void> {
    console.error(`[mode-controller] Initializing with modes paths: ${this.modesPaths.join(', ')}`);
    await this.loadModes();
  }

  private async loadModes(): Promise<void> {
    for (const modesPath of this.modesPaths) {
      try {
        // ディレクトリが存在するかチェック
        try {
          await fs.access(modesPath);
        } catch {
          console.error(`[mode-controller] Directory not found, skipping: ${modesPath}`);
          continue;
        }

        // 再帰的にmdファイルを探索
        await this.loadModesFromDir(modesPath);
      } catch (error) {
        console.error(`[mode-controller] Error loading modes from ${modesPath}: ${error}`);
        // エラーが発生しても他のディレクトリの処理は続行
        continue;
      }
    }
  }

  private async loadModesFromDir(dirPath: string): Promise<void> {
    const entries = await fs.readdir(dirPath, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dirPath, entry.name);

      if (entry.isDirectory()) {
        // サブディレクトリを再帰的に探索
        await this.loadModesFromDir(fullPath);
      } else if (entry.isFile() && entry.name.endsWith('.md')) {
        // mdファイルを処理
        const content = await fs.readFile(fullPath, 'utf-8');
        const parsed = this.parseModeMd(content);

        // フロントマターがない、またはmodeフィールドがない場合はスキップ
        if (!parsed.metadata || !parsed.metadata.mode) {
          console.error(`[mode-controller] Skipping ${fullPath}: no valid mode metadata found`);
          continue;
        }

        // displayNameがない場合はmodeフィールドを使用
        if (!parsed.metadata.displayName) {
          parsed.metadata.displayName = parsed.metadata.mode;
        }

        const modeName = parsed.metadata.mode.toLowerCase();
        this.availableModes.set(modeName, parsed);
        console.error(`[mode-controller] Loaded mode: ${modeName} from ${fullPath}`);
      }
    }
  }

  private parseModeMd(content: string): ParsedMode {
    const match = content.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
    if (match) {
      try {
        const metadata = yaml.load(match[1]) as ModeMetadata;
        const body = match[2];
        // modeフィールドが存在する場合のみ有効なモードとして返す
        if (metadata && metadata.mode) {
          return { metadata, body };
        }
      } catch (e) {
        // YAMLパースエラーの場合はメタデータなしとして扱う
        console.error(`[mode-controller] YAML parse error: ${e}`);
      }
    }
    // フロントマターがない、またはmodeフィールドがない場合は空のメタデータを返す
    return { metadata: {} as ModeMetadata, body: content };
  }

  async enterMode(modeNames: string | string[]): Promise<string> {
    // 配列に正規化
    const modes = Array.isArray(modeNames) ? modeNames : [modeNames];
    const results: string[] = [];
    const entered: string[] = [];

    for (const modeName of modes) {
      const mode = this.availableModes.get(modeName.toLowerCase());
      if (!mode) {
        if (modes.length === 1) {
          throw new Error(`モード '${modeName}' が見つかりません。利用可能なモード: ${this.getAvailableModeNames().join(', ')}`);
        }
        results.push(`⚠️ モード '${modeName}' が見つかりません`);
        continue;
      }

      const normalizedName = modeName.toLowerCase();
      this.activeModes.add(normalizedName);
      const displayName = mode.metadata.displayName || modeName;
      entered.push(displayName);
      results.push(`【${displayName}開始】\n\n${mode.body}`);
    }

    if (entered.length === 0) {
      throw new Error(`指定されたモードが見つかりません: ${modes.join(', ')}`);
    }

    // 複数モードの場合は区切り線を入れる
    if (results.length > 1) {
      return results.join('\n\n' + '─'.repeat(40) + '\n\n');
    }
    return results[0];
  }

  async exitMode(modeNames?: string | string[]): Promise<string> {
    // モードが指定されていない場合は全て終了
    if (!modeNames) {
      if (this.activeModes.size === 0) {
        return '現在アクティブなモードはありません。';
      }

      const results: string[] = [];
      for (const modeName of this.activeModes) {
        const mode = this.availableModes.get(modeName);
        const displayName = mode?.metadata.displayName || modeName;
        const exitMessage = mode?.metadata.exitMessage || `${displayName}を終了しました。`;
        results.push(`【${displayName}終了】\n\n${exitMessage}`);
      }
      this.activeModes.clear();

      if (results.length > 1) {
        return results.join('\n\n' + '─'.repeat(40) + '\n\n');
      }
      return results[0];
    }

    // 配列に正規化
    const modes = Array.isArray(modeNames) ? modeNames : [modeNames];
    const results: string[] = [];
    const exited: string[] = [];

    for (const modeName of modes) {
      const normalizedName = modeName.toLowerCase();
      if (!this.activeModes.has(normalizedName)) {
        if (modes.length === 1) {
          return `モード '${modeName}' は現在アクティブではありません。`;
        }
        results.push(`⚠️ モード '${modeName}' はアクティブではありません`);
        continue;
      }

      const mode = this.availableModes.get(normalizedName);
      const displayName = mode?.metadata.displayName || modeName;
      const exitMessage = mode?.metadata.exitMessage || `${displayName}を終了しました。`;

      this.activeModes.delete(normalizedName);
      exited.push(displayName);
      results.push(`【${displayName}終了】\n\n${exitMessage}`);
    }

    if (exited.length === 0) {
      return `指定されたモードはアクティブではありません: ${modes.join(', ')}`;
    }

    if (results.length > 1) {
      return results.join('\n\n' + '─'.repeat(40) + '\n\n');
    }
    return results[0];
  }

  async showCurrentMode(modeName?: string): Promise<string> {
    if (this.activeModes.size === 0) {
      return '現在アクティブなモードはありません。';
    }

    // 特定のモードが指定された場合
    if (modeName) {
      const normalizedName = modeName.toLowerCase();
      if (!this.activeModes.has(normalizedName)) {
        return `モード '${modeName}' は現在アクティブではありません。`;
      }

      const mode = this.availableModes.get(normalizedName);
      if (!mode) {
        return 'モード情報が見つかりません。';
      }

      const displayName = mode.metadata.displayName || modeName;
      return `【${displayName}（現在アクティブ）】\n\n${mode.body}`;
    }

    // 全てのアクティブモードを表示
    const results: string[] = [];
    for (const activeMode of this.activeModes) {
      const mode = this.availableModes.get(activeMode);
      if (mode) {
        const displayName = mode.metadata.displayName || activeMode;
        results.push(`【${displayName}（現在アクティブ）】\n\n${mode.body}`);
      }
    }

    if (results.length > 1) {
      return results.join('\n\n' + '─'.repeat(40) + '\n\n');
    }
    return results[0];
  }

  getActiveModes(): Array<{ mode: string; displayName: string }> {
    const modes: Array<{ mode: string; displayName: string }> = [];
    for (const modeName of this.activeModes) {
      const mode = this.availableModes.get(modeName);
      modes.push({
        mode: modeName,
        displayName: mode?.metadata.displayName || modeName
      });
    }
    return modes;
  }

  getAvailableModes(): Array<{ name: string; displayName: string; triggers?: string[] }> {
    return Array.from(this.availableModes.entries()).map(([name, mode]) => ({
      name,
      displayName: mode.metadata.displayName || name,
      triggers: mode.metadata.autoTrigger
    }));
  }

  private getAvailableModeNames(): string[] {
    return Array.from(this.availableModes.keys());
  }
}

// コマンドライン引数の解析
function parseArgs(): { modesPaths: string[] } {
  const args = process.argv.slice(2);
  const modesPaths: string[] = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--modes-path' && args[i + 1]) {
      // カンマ区切りで複数パスを指定可能
      const paths = args[i + 1].split(',').map(p => path.resolve(p.trim()));
      modesPaths.push(...paths);
      i++;
    }
  }

  // デフォルトパスを設定
  if (modesPaths.length === 0) {
    modesPaths.push(
      path.join(process.cwd(), 'prompts/modes'),
      path.join(process.cwd(), 'products')
    );
  }

  return { modesPaths };
}

async function main() {
  const { modesPaths } = parseArgs();

  // モードコントローラーの初期化
  const modeController = new ModeController(modesPaths);
  await modeController.initialize();

  // MCPサーバーの初期化
  const server = new McpServer(
    {
      name: 'mode-controller',
      version: '1.0.0',
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // mode_enter ツール
  server.registerTool(
    'mode_enter',
    {
      description: '指定した動作モードを開始します（複数指定可能）。使用前に必ずmode_listで利用可能なモードを確認してください',
      inputSchema: {
        modes: z.union([
          z.string(),
          z.array(z.string())
        ]).describe('開始するモード名（文字列または配列）例: "specification_research" または ["specification_research", "tech_notes"]'),
      },
    },
    async (args: any) => {
      const { modes } = args;
      try {
        const result = await modeController.enterMode(modes);
        return {
          content: [
            {
              type: 'text',
              text: result,
            },
          ],
        };
      } catch (error) {
        throw new Error(`モード開始エラー: ${(error as Error).message}`);
      }
    }
  );

  // mode_exit ツール
  server.registerTool(
    'mode_exit',
    {
      description: 'アクティブなモードを終了します（複数指定可能）',
      inputSchema: {
        modes: z.union([
          z.string(),
          z.array(z.string())
        ]).optional().describe('終了するモード名（省略時は全モード終了）例: "specification_research" または ["specification_research", "tech_notes"]'),
      },
    },
    async (args: any) => {
      const { modes } = args;
      try {
        const result = await modeController.exitMode(modes);
        return {
          content: [
            {
              type: 'text',
              text: result,
            },
          ],
        };
      } catch (error) {
        throw new Error(`モード終了エラー: ${(error as Error).message}`);
      }
    }
  );

  // mode_status ツール
  server.registerTool(
    'mode_status',
    {
      description: '現在のモード状態を確認します',
      inputSchema: {},
    },
    async () => {
      const activeModes = modeController.getActiveModes();

      let statusText = '📊 モード状態\n\n';
      if (activeModes.length > 0) {
        statusText += `アクティブなモード (${activeModes.length}個):\n`;
        for (const mode of activeModes) {
          statusText += `  🟢 ${mode.displayName} (${mode.mode})\n`;
        }
      } else {
        statusText += `現在のモード: なし\n`;
        statusText += `状態: ⭕ 待機中`;
      }

      return {
        content: [
          {
            type: 'text',
            text: statusText,
          },
        ],
      };
    }
  );

  // mode_list ツール
  server.registerTool(
    'mode_list',
    {
      description: '利用可能な動作モード一覧を表示します',
      inputSchema: {},
    },
    async () => {
      const modes = modeController.getAvailableModes();

      let listText = '📋 利用可能な動作モード\n\n';

      for (const mode of modes) {
        listText += `• ${mode.displayName} (${mode.name})\n`;
        if (mode.triggers && mode.triggers.length > 0) {
          listText += `  発動条件: ${mode.triggers.join(', ')}\n`;
        }
      }

      if (modes.length === 0) {
        listText += '利用可能なモードがありません。';
      }

      return {
        content: [
          {
            type: 'text',
            text: listText,
          },
        ],
      };
    }
  );

  // mode_show ツール
  server.registerTool(
    'mode_show',
    {
      description: 'アクティブなモードの内容を表示します',
      inputSchema: {
        mode: z.string().optional().describe('表示するモード名（省略時は全アクティブモード）'),
      },
    },
    async (args: any) => {
      const { mode } = args;
      try {
        const result = await modeController.showCurrentMode(mode);
        return {
          content: [
            {
              type: 'text',
              text: result,
            },
          ],
        };
      } catch (error) {
        throw new Error(`モード表示エラー: ${(error as Error).message}`);
      }
    }
  );

  // サーバーの起動
  const transport = new StdioServerTransport();
  console.error('[mode-controller] Starting MCP server...');
  await server.connect(transport);
  console.error('[mode-controller] MCP server started');
}

main().catch(error => {
  console.error('[mode-controller] Server error:', error);
  process.exit(1);
});