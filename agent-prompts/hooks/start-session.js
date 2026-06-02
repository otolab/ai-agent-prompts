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
          '新しいセッションです。',
          'このセッションではアシスタント動作モードを使用します。',
          'mode-controllerのリソース mode://available でモード一覧を確認し、状況に応じて適切なモードを有効・無効化してください。',
        ].join('\n'));
        break;

      case 'resume':
        lines.push([
          '中断していたセッションを再開します。',
          '最優先で以下の作業を行ってください。',
          '',
          '- コンテキストから最新のアクティブモードリストを検索する',
          '- mode_set()を実行してモードをMCPメモリに復元する',
        ].join('\n'));
        break;

      case 'clear':
        lines.push([
          'コンテキストがクリアされました。',
          'アクティブなモードをすべて解除してください。',
          'mode-controllerのリソース mode://available でモード一覧を確認し、これからの作業で必要に応じて有効化してください。',
        ].join('\n'));
        break;

      case 'compact':
        lines.push([
          'さて、要約された情報から作業を開始ですね。',
          'まずは作業の準備から始めましょう。',
          '',
          'あなたが今持っている情報はサマリです。',
          'サマリは作業の「続き」を知るには十分ですが、',
          '判断の根拠や文脈のニュアンスは失われています。',
          '',
          '急ぐ必要はありません。',
          '「サマリで作業を続行できる」ことと',
          '「サマリだけで作業すべき」は別のことです。',
          '',
          '作業を再開する前に：',
          '- アシスタント動作モードをmode_statusで確認し、mode-controllerのリソース mode://available でモード一覧と原文を確認してください',
          '- 作業中のファイルがあれば、サマリではなく原文を読み直してください',
          '- 「自分が何を忘れているか」がわからない状態であることを自覚してください',
        ].join('\n'));
        break;

      default:
        lines.push([
          `セッションが開始されました (source: ${source})。`,
          'mode-controllerのリソース mode://available でモード一覧を確認し、状況に応じて適切なモードを有効・無効化してください。',
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
