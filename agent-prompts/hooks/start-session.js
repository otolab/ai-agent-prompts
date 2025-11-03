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
          '⚠️ **REQUIRED STEPS - Complete before proceeding:**',
          '',
          '[ ] Execute **mode_list()**',
          '[ ] Enable appropriate modes',
          '',
          '**Do not start other work until these steps are completed.**',
        ].join('\n'));
        break;

      case 'resume':
        lines.push([
          '⚠️ **REQUIRED STEPS - Complete before proceeding:**',
          '⚠️ **必須手順 - 他の作業より優先して完了してください：**',
          '',
          '[ ] 1. Search context for the latest active mode list',
          '[ ] 2. Execute **mode_set()** to restore modes to MCP memory',
          '',
          '**Do not start other work until these steps are completed.**',
          '**これらが完了するまで、他の作業を開始しないでください。**',
        ].join('\n'));
        break;

      case 'clear':
        lines.push([
          '⚠️ **REQUIRED STEPS - Complete before proceeding:**',
          '',
          '[ ] Execute **mode_show()** to reload mode documents',
          '',
          '**Do not start other work until this step is completed.**',
        ].join('\n'));
        break;

      case 'compact':
        lines.push([
          '⚠️ **REQUIRED STEPS - Complete before proceeding:**',
          '⚠️ **必須手順 - 他の作業より優先して完了してください：**',
          '',
          '[ ] Execute **mode_show()** to restore the mode state',
          '[ ] **mode_show()** で状態を復元してください',
          '',
          '**Do not start other work until this step is completed.**',
          '**これが完了するまで、他の作業を開始しないでください。**',
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
