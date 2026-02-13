#!/usr/bin/env node
import { McpServer, ResourceTemplate } from '@modelcontextprotocol/sdk/server/mcp.js';
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
  fullContent?: boolean;  // trueの場合、mode_enterでファイル内容を直接出力
}

interface ParsedModeContent {
  metadata: ModeMetadata;
  body: string;
}

interface ParsedMode extends ParsedModeContent {
  filePath: string;
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
        this.availableModes.set(modeName, {
          ...parsed,
          filePath: fullPath
        });
        console.error(`[mode-controller] Loaded mode: ${modeName} from ${fullPath}`);
      }
    }
  }

  private parseModeMd(content: string): ParsedModeContent {
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

  /**
   * @参照を解決してファイル内容を再帰的に読み込む
   * - 参照元の@テキストをmdの内部リンクに置き換え
   * - 同じファイルへの参照は1回だけ展開（重複排除）
   * - 展開内容は---で分割して末尾に追加
   */
  private async resolveReferences(
    content: string,
    baseFilePath: string,
    visitedFiles: Set<string> = new Set()
  ): Promise<string> {
    const refPattern = /(?:^|\s|:)\s*@(\S+)/gm;
    const matches = Array.from(content.matchAll(refPattern));

    if (matches.length === 0) {
      return content;
    }

    const baseDir = path.dirname(baseFilePath);

    // 1. ユニークな参照を解決
    const resolved = new Map<string, { resolvedContent: string; title: string }>();

    for (const match of matches) {
      const refPath = match[1].trim();
      const absolutePath = path.resolve(baseDir, refPath);

      if (resolved.has(absolutePath)) continue;

      if (visitedFiles.has(absolutePath)) {
        console.error(`[mode-controller] Circular reference detected: ${absolutePath}`);
        continue;
      }

      try {
        const refContent = await fs.readFile(absolutePath, 'utf-8');
        const newVisited = new Set(visitedFiles);
        newVisited.add(absolutePath);
        const resolvedContent = await this.resolveReferences(refContent, absolutePath, newVisited);

        // 最初の見出しをタイトルとして抽出
        const titleMatch = resolvedContent.match(/^#\s+(.+)$/m);
        const title = titleMatch ? titleMatch[1].trim() : path.basename(refPath, '.md');

        resolved.set(absolutePath, { resolvedContent, title });
      } catch (error) {
        console.error(`[mode-controller] Failed to read referenced file: ${absolutePath}`, error);
      }
    }

    // 2. @参照テキストをmd内部リンクに置き換え
    let result = content;
    for (const match of matches) {
      const refPath = match[1].trim();
      const absolutePath = path.resolve(baseDir, refPath);
      const ref = resolved.get(absolutePath);
      if (ref) {
        const anchor = this.toAnchor(ref.title);
        result = result.split(`@${refPath}`).join(`[${ref.title}](#${anchor})`);
      }
    }

    // 3. 解決済み内容を---で分割して末尾に追加（重複なし）
    const sections: string[] = [result];
    for (const [, ref] of resolved) {
      sections.push(`\n---\n\n${ref.resolvedContent}`);
    }

    return sections.join('\n');
  }

  private toAnchor(title: string): string {
    return title
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^\w\u3040-\u309f\u30a0-\u30ff\u4e00-\u9fff-]/g, '');
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

      // fullContent: trueの場合は直接コンテンツを出力
      if (mode.metadata.fullContent) {
        const content = await this.resolveReferences(mode.body, mode.filePath);
        results.push(`【${displayName}開始】\n\n${content}`);
      } else {
        // 従来通りファイル読み込みを指示
        results.push(`【${displayName}開始】\n\n${'━'.repeat(60)}\n⚠️ TodoWriteツールで以下のファイルの読み込みを最優先としてスケジュールしてください\n\nこのファイルには作業を正しく効率的に進めるための重要な情報が含まれています。\n読まずに作業を進めると、手戻りや誤った実装につながります。\n\nサマリが存在する場合でも原文を読み直してください。\n${'━'.repeat(60)}\n\nファイル: ${mode.filePath}`);
      }
    }

    if (entered.length === 0) {
      throw new Error(`指定されたモードが見つかりません: ${modes.join(', ')}`);
    }

    // 複数モードの場合は区切り線を入れる
    let result = results.length > 1 ? results.join('\n\n' + '─'.repeat(40) + '\n\n') : results[0];
    result += '\n\n' + this.formatActiveModesStatus();
    return result;
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

      let result = results.length > 1 ? results.join('\n\n' + '─'.repeat(40) + '\n\n') : results[0];
      result += '\n\n' + this.formatActiveModesStatus();
      return result;
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

    let result = results.length > 1 ? results.join('\n\n' + '─'.repeat(40) + '\n\n') : results[0];
    result += '\n\n' + this.formatActiveModesStatus();
    return result;
  }

  async setModes(modeNames: string | string[]): Promise<string> {
    // 配列に正規化
    const modes = Array.isArray(modeNames) ? modeNames : [modeNames];

    // 現在のアクティブモードをクリア
    this.activeModes.clear();

    // 指定されたモードを設定
    const set: string[] = [];
    const notFound: string[] = [];

    for (const modeName of modes) {
      const normalizedName = modeName.toLowerCase();
      const mode = this.availableModes.get(normalizedName);

      if (!mode) {
        notFound.push(modeName);
        continue;
      }

      this.activeModes.add(normalizedName);
      set.push(mode.metadata.displayName || modeName);
    }

    // 結果メッセージ
    let result = '🔄 モード状態を復元しました\n\n';

    if (set.length > 0) {
      result += `アクティブなモード (${set.length}個):\n`;
      for (const displayName of set) {
        result += `  🟢 ${displayName}\n`;
      }
    } else {
      result += 'アクティブなモード: なし\n';
    }

    if (notFound.length > 0) {
      result += `\n⚠️ 見つからなかったモード: ${notFound.join(', ')}`;
    }

    return result;
  }

  private formatActiveModesStatus(): string {
    const activeModes = this.getActiveModes();
    if (activeModes.length === 0) {
      return '現在のアクティブモード: なし';
    }

    const modeNames = activeModes.map(m => m.displayName).join(', ');
    return `現在のアクティブモード (${activeModes.length}個): ${modeNames}`;
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

  async getModeContent(modeName: string): Promise<string | null> {
    const normalizedName = modeName.toLowerCase();
    const mode = this.availableModes.get(normalizedName);
    if (!mode) return null;
    return await this.resolveReferences(mode.body, mode.filePath);
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

  // --modes-pathは必須
  if (modesPaths.length === 0) {
    console.error('[mode-controller] ERROR: --modes-path is required');
    console.error('[mode-controller] Usage: mcp-mode-controller --modes-path /path/to/modes[,/path/to/modes2,...]');
    process.exit(1);
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
        resources: {},
      },
    }
  );

  // mode_enter ツール
  server.registerTool(
    'mode_enter',
    {
      description: '指定した動作モードを開始します（複数指定可能）。利用可能なモードはリソース mode://available で確認できます',
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



  // mode_set ツール
  server.registerTool(
    'mode_set',
    {
      description: 'モード状態を直接設定します（復元専用、ファイル読み込みなし）。現在のアクティブモードを全てクリアし、指定されたモードのみをアクティブにします',
      inputSchema: {
        modes: z.union([
          z.string(),
          z.array(z.string())
        ]).describe('設定するモード名（文字列または配列）例: "foundation" または ["foundation", "issue_tracking"]'),
      },
    },
    async (args: any) => {
      const { modes } = args;
      try {
        const result = await modeController.setModes(modes);
        return {
          content: [
            {
              type: 'text',
              text: result,
            },
          ],
        };
      } catch (error) {
        throw new Error(`モード設定エラー: ${(error as Error).message}`);
      }
    }
  );

  // Resource: mode://available — 利用可能モード一覧
  server.registerResource(
    'available-modes',
    'mode://available',
    {
      title: '利用可能な動作モード一覧',
      description: '利用可能な全モードの名前・表示名・発動条件の一覧',
      mimeType: 'application/json',
    },
    async (uri) => {
      const modes = modeController.getAvailableModes();
      return {
        contents: [
          {
            uri: uri.href,
            text: JSON.stringify(modes, null, 2),
            mimeType: 'application/json',
          },
        ],
      };
    }
  );

  // Resource: mode://mode/{modeName} — 個別モードの内容
  server.registerResource(
    'mode-content',
    new ResourceTemplate('mode://mode/{modeName}', {
      list: async () => {
        const modes = modeController.getAvailableModes();
        return {
          resources: modes.map((mode) => ({
            uri: `mode://mode/${mode.name}`,
            name: mode.displayName,
            description: `モード: ${mode.displayName}`,
            mimeType: 'text/markdown',
          })),
        };
      },
      complete: {
        modeName: async (value: string) => {
          const modes = modeController.getAvailableModes();
          return modes
            .map((m) => m.name)
            .filter((name) => name.toLowerCase().startsWith(value.toLowerCase()));
        },
      },
    }),
    {
      title: 'モード内容',
      description: '指定したモードの詳細内容（@参照解決済み）',
      mimeType: 'text/markdown',
    },
    async (uri, { modeName }) => {
      const content = await modeController.getModeContent(modeName as string);
      if (content === null) {
        throw new Error(`モード '${modeName}' が見つかりません`);
      }
      return {
        contents: [
          {
            uri: uri.href,
            text: content,
            mimeType: 'text/markdown',
          },
        ],
      };
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