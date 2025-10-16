import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    testTimeout: 30000,  // MCPサーバー起動に時間がかかる場合を考慮
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/**',
        'dist/**',
        'test/**',
        'test-modes/**',
        '*.config.ts'
      ]
    }
  }
});