---
version: __VERSION__
# Latest round — ship checks: report-fresh.sh --since <head>
round: 1
base: <commit the round reviewed from: merge-base with release, or the previous head>
head: <HEAD after the round's fixes and tests, before the report commit>
reviewer: code-review            # code-review | review-agents
effort: high
result: clean                    # clean | fixed | open (findings left for the user)
---

# Code review — __VERSION__

## Round 1 — __DATE__

Range `<base>..<head>` (full | incremental). Reviewer and effort used; how many
findings, how many applied / rejected / escalated / scoped out / deferred; the
final test result (pointer to `test-report.md`).

| ID | Severity | Kind | Where | Finding | Decision | Commit |
|----|----------|------|-------|---------|----------|--------|
| CR-01 | high | correctness | `path/file.ts:42` | … | applied | `abc1234` |
| CR-02 | low | simplification | `path/other.ts:10` | … | rejected — conflicts with D-03 | — |

Kind: `correctness`, `security`, `performance`, `simplification`, `reuse`,
`convention`, `test`. Decision: `applied`, `rejected — <reason>`,
`escalated — <D-NN or decision needed>`, `scope — <question for the PO>`, or
`deferred — <follow-up>`.

**Auto-approved** (only `--approved` runs): CR-… applied without asking.

<!-- Later rounds are appended below as "## Round N — <date>"; the
frontmatter always describes the latest round. -->
