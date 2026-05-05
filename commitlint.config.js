// Conventional Commits config for Azure Launchpad.
// Used by .github/workflows/commitlint.yml and pre-commit's conventional-pre-commit hook.
// Reference: https://github.com/conventional-changelog/commitlint

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      ['feat', 'fix', 'docs', 'chore', 'refactor', 'test', 'ci', 'build', 'perf', 'style', 'revert'],
    ],
    'subject-case': [0],
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
    'header-max-length': [2, 'always', 120],
  },
};
