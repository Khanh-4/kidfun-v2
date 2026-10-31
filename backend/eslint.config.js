const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',
      globals: { ...globals.node },
    },
    rules: {
      // catch bỏ qua lỗi là chủ ý ở nhiều chỗ (non-critical); `next` phải giữ để
      // Express nhận ra error handler 4 tham số; tham số `_x` = cố ý không dùng.
      'no-unused-vars': ['error', { caughtErrors: 'none', argsIgnorePattern: '^_|^next$' }],
      'no-empty': ['error', { allowEmptyCatch: true }],
    },
  },
  {
    files: ['tests/**/*.js'],
    languageOptions: { globals: { ...globals.jest } },
  },
];
