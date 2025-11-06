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
          '📋 **Session Setup - 新規セッション開始**',
          '',
          '作業環境をセットアップします。',
          'TodoWriteツールで以下のタスクをリストの最初に追加してください：',
          '',
          '1. mode_list()を実行して利用可能なモードを確認する',
          '2. 適切なモードを有効化する',
          '',
          'これらは作業開始前の準備ステップです。',
        ].join('\n'));
        break;

      case 'resume':
        lines.push([
          '📋 **Session Setup - セッション再開**',
          '',
          '中断していたセッションを再開します。',
          'TodoWriteツールで以下のタスクをリストの最初に追加してください：',
          '',
          '1. コンテキストから最新のアクティブモードリストを検索する',
          '2. mode_set()を実行してモードをMCPメモリに復元する',
          '',
          'これらは作業再開前の準備ステップです。',
        ].join('\n'));
        break;

      case 'clear':
        lines.push([
          '📋 **Session Setup - モードクリア後**',
          '',
          'アシスタント動作モードがクリアされました。',
          'TodoWriteツールで以下のタスクをリストの最初に追加してください：',
          '',
          '1. mode_show()を実行してモードドキュメントを再読み込みする',
          '',
          'これは作業継続前の準備ステップです。',
        ].join('\n'));
        break;

      case 'compact':
        lines.push([
          '📋 **Session Setup - コンテキスト圧縮後の再開**',
          '',
          'コンテキストが圧縮されました。モード状態を復元します。',
          'TodoWriteツールで以下のタスクをリストの最初に追加してください：',
          '',
          '1. mode_show()を実行してモード状態を復元する',
          '',
          'これは作業継続前の準備ステップです。',
          '',
          '💡 ヒント: mode_show()は「サマリが存在する場合でも原文を読み直す」指示を含んでいます。',
        ].join('\n'));
        break;

      default:
        lines.push([
          '📋 **Session Setup**',
          '',
          `セッションが開始されました (source: ${source})。`,
          'TodoWriteツールで以下のタスクをリストの最初に追加してください：',
          '',
          '1. mode_list()を実行する',
        ].join('\n'));
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
