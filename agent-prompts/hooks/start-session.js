#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// 標準入力からJSONを読み取る
let inputData = '';

process.stdin.on('data', (chunk) => {
  inputData += chunk;
});

process.stdin.on('end', () => {
  try {
    const hookData = JSON.parse(inputData);
    const source = hookData.source || 'unknown';

    // sourceに応じたメッセージを構築
    const lines = [
      '═══════════════════════════════════════════'
    ];

    switch (source) {
      case 'startup':
        lines.push([
          '⚠️ **To start work in the correct context, execute these steps:**',
          '',
          '* **mode_list()** を実行します',
          '* 適切なモードを有効にします',
        ].join('\n'));
        break;

      case 'resume':
        lines.push([
          '⚠️ **To continue work in the correct context, execute these steps:**',
          '⚠️ **継続作業を正しいコンテキストの中で実行するために、次の手順を実行してください：**',
          '',
          '1. コンテキストから最新のアクティブなモードリストを検索',
          '2. **mode_set()** ツールでモードの状態を保存（MCPオンメモリに保存）',
        ].join('\n'));
        break;

      case 'clear':
        lines.push([
          '⚠️ **To continue work in the correct context, execute these steps:**',
          '',
          '* **mode_show()** を実行してモード文書を再読み込みします',
        ].join('\n'));
        break;

      case 'compact':
        lines.push([
          '⚠️ **To continue work in the correct context, execute these steps:**',
          '⚠️ **継続作業を正しいコンテキストの中で実行するために、次の手順を実行してください：**',
          '',
          '* Execute **mode_show()** to restore the mode state',
          '* **mode_show()** で状態を復元してください',
        ].join('\n'));
        break;

      default:
        lines.push(`セッションが開始されました (source: ${source})。**mode_list()** を実行します。`);
        break;
    }

    // .serenaディレクトリのチェック
    const serenaPath = path.join(process.cwd(), '.serena');
    if (fs.existsSync(serenaPath) && fs.statSync(serenaPath).isDirectory()) {
      lines.push('* Serenaのアクティベートを行ってください');
    }

    lines.push('═══════════════════════════════════════════');

    // JSON出力
    const output = {
      hookSpecificOutput: {
        hookEventName: 'SessionStart',
        additionalContext: lines.join('\n')
      }
    };

    console.log(JSON.stringify(output, null, 2));
  } catch (error) {
    console.error('Error processing hook input:', error.message);
    process.exit(1);
  }
});
