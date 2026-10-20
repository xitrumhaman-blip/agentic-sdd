# commitlint and the `improve` type

Agentic SDD adds the Conventional Commits type `improve` (improvement → Z
digit, see `sdd-conventions.md`). `@commitlint/config-conventional` does not
list it, so a repo that uses that preset rejects `improve: …` commits in its
commit-msg hook and in CI — usually discovered only at the first improvement
version.

Check: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/commitlint-check.sh"`.

Fix: extend `type-enum` with `improve`, keeping the preset's types. Pick the
snippet matching the config format, merge it into the existing config (do not
replace other rules), and commit it as `build: allow the improve commit type`.

`commitlint.config.js` / `.cjs` (CommonJS):

```js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'build', 'chore', 'ci', 'docs', 'feat', 'fix', 'improve',
      'perf', 'refactor', 'revert', 'style', 'test',
    ]],
  },
};
```

`commitlint.config.mjs` / `.ts` (ESM):

```js
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'build', 'chore', 'ci', 'docs', 'feat', 'fix', 'improve',
      'perf', 'refactor', 'revert', 'style', 'test',
    ]],
  },
};
```

`.commitlintrc.yml`:

```yaml
extends:
  - '@commitlint/config-conventional'
rules:
  type-enum:
    - 2
    - always
    - [build, chore, ci, docs, feat, fix, improve, perf, refactor, revert, style, test]
```

`.commitlintrc.json` or the `commitlint` key of `package.json`:

```json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "type-enum": [2, "always", ["build", "chore", "ci", "docs", "feat", "fix", "improve", "perf", "refactor", "revert", "style", "test"]]
  }
}
```

After the change, run the check again; with commitlint installed it asks
commitlint itself (`node_modules/.bin/commitlint`).
